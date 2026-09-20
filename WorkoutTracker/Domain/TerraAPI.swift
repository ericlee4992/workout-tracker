import Foundation

/// Shared private-trial transport. Credentials are supplied at the edge, never persisted here.
/// A public release must replace device-held developer credentials with a metered backend.
struct TerraClient: Sendable {
    let key: String
    var session: URLSession = .shared
    static let model = "gpt-5.6-terra"

    func request(instructions: String, input: String, schema: [String: Any], name: String,
                 jpeg: Data? = nil) throws -> URLRequest {
        var content: [[String: Any]] = [["type": "input_text", "text": input]]
        if let jpeg {
            content.append(["type": "input_image", "image_url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())", "detail": "high"])
        }
        let body: [String: Any] = [
            "model": Self.model, "store": false, "instructions": instructions,
            "reasoning": ["effort": "medium"], "max_output_tokens": 8000,
            "input": [["role": "user", "content": content]],
            "text": ["format": ["type": "json_schema", "name": name, "strict": true, "schema": schema]]
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func complete(instructions: String, input: String, schema: [String: Any], name: String,
                  jpeg: Data? = nil) async throws -> Data {
        try Task.checkCancellation()
        let request = try request(instructions: instructions, input: input, schema: schema, name: name, jpeg: jpeg)
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError { throw Self.transportError(error) }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw TerraError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw Self.statusError(response.statusCode)
        }
        return try Self.output(from: data)
    }

    static func statusError(_ status: Int) -> TerraError {
        switch status {
        case 401, 403: .message("Check your OpenAI key and model access in Settings.")
        case 429: .message("OpenAI usage is limited. Check API credits or try again later.")
        default: .message("OpenAI is unavailable (\(status)). Try again later.")
        }
    }
    static func transportError(_ error: URLError) -> any Error {
        if error.code == .cancelled { return CancellationError() }
        return TerraError.message(error.code == .timedOut ? "OpenAI took too long. Try again." : "Could not reach OpenAI. Check your connection or continue manually.")
    }

    static func output(from data: Data) throws -> Data {
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              response["status"] as? String == "completed",
              let output = response["output"] as? [[String: Any]] else { throw TerraError.invalidResponse }
        let contents = output.flatMap { $0["content"] as? [[String: Any]] ?? [] }
        if contents.contains(where: { $0["type"] as? String == "refusal" }) {
            throw TerraError.message("AI could not help with this request. Change the request or continue manually.")
        }
        let texts = contents.filter { $0["type"] as? String == "output_text" }.compactMap { $0["text"] as? String }
        guard texts.count == 1, let text = texts.first, let result = text.data(using: .utf8) else { throw TerraError.invalidResponse }
        return result
    }
}

enum TerraError: LocalizedError {
    case message(String)
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .message(let text): text
        case .invalidResponse: "AI returned an incomplete or invalid result. Try again or continue manually."
        }
    }
}

enum AISchema {
    static let string: [String: Any] = ["type": "string"]
    static let integer: [String: Any] = ["type": "integer"]
    static let number: [String: Any] = ["type": "number"]
    static func object(_ properties: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": properties, "required": properties.keys.sorted(), "additionalProperties": false]
    }
    static func array(_ items: [String: Any]) -> [String: Any] { ["type": "array", "items": items] }
    static func text<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }
}
