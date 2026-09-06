import Foundation

/// Scanner accuracy, ticket 05 — what Claude says a name plate prints.
///
/// The LLM-as-plate-reader experiment (2026-09-06, 41 corpus plates) showed
/// Claude reading the brand on every logo-only plate Vision garbled, producing
/// no junk lines and inventing no model names; through the app's OWN matcher
/// it took top-1 8 → 10 of 12 with zero wrong preselections. So the model
/// transcribes and nothing more: this value goes through `CatalogMatcher.rank`
/// exactly as a Vision reading does, D33 still decides what preselects, and
/// the confirm tap stays. The model never picks a catalog row.
struct PlateTranscription: Equatable {
    enum Confidence: String, Decodable {
        case high, medium, low
    }

    /// Manufacturer as printed, or as recognised from its logo.
    var brand: String?
    /// The model or machine name as printed — never a guess (the prompt
    /// forbids it, and the experiment confirmed the model obeys: TIBIA stayed
    /// TIBIA, a Swedish placard stayed Swedish).
    var model: String?
    /// The plate's identifying text, top of the plate first — what the
    /// experiment's harness fed the matcher.
    var lines: [String]
    var confidence: Confidence

    /// The reading the matcher ranks: the lines, top-first, as the harness
    /// used them; when the model gave no lines but did name a brand or model,
    /// those, in plate order.
    var labelReading: LabelReading {
        let texts = lines.map(\.trimmed).filter { !$0.isEmpty }
        if !texts.isEmpty { return LabelReading.lines(texts) }
        return LabelReading.lines([brand, model].compactMap { $0?.trimmed }.filter { !$0.isEmpty })
    }
}

extension PlateTranscription: Decodable {
    private enum CodingKeys: String, CodingKey {
        case brand, model, lines, confidence
    }

    /// Tolerant of the fields the schema makes optional or that a future
    /// prompt might drop: a missing `lines` is empty, an unknown confidence
    /// is `low`. Only the shape itself (an object) is required.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        lines = try container.decodeIfPresent([String].self, forKey: .lines) ?? []
        let raw = try container.decodeIfPresent(String.self, forKey: .confidence) ?? ""
        confidence = Confidence(rawValue: raw) ?? .low
    }
}

/// Why an ask did not produce a transcription. Every case is user-facing:
/// the sheet shows the description and leaves the on-device results as they
/// were (fail closed — nothing is retried in the background).
enum PlateTranscriptionError: Error, Equatable, LocalizedError {
    case offline
    case timedOut
    /// The key was rejected (401/403).
    case unauthorized
    /// The model declined (`stop_reason: "refusal"`).
    case refused
    /// Any other HTTP or transport failure.
    case unavailable(status: Int)
    /// A 2xx whose body was not the structured reading asked for.
    case malformed

    var errorDescription: String? {
        switch self {
        case .offline: "Ask AI needs a connection — you look offline."
        case .timedOut: "Ask AI took too long. Try again when the signal is better."
        case .unauthorized: "Ask AI's key was rejected. Check it in Settings."
        case .refused: "AI declined to read this photo."
        case .unavailable(let status): "Ask AI is unavailable right now (\(status))."
        case .malformed: "AI's answer could not be read."
        }
    }
}

/// A Messages API reply, reduced to the one text block a structured-output
/// request produces. Shared by every Ask AI call (tickets 05 and 06): an
/// error object, a refusal and a missing block map to the same errors
/// whatever was asked.
enum MessagesReply {
    static func text(from data: Data) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlateTranscriptionError.malformed
        }
        if object["type"] as? String == "error" {
            throw PlateTranscriptionAPI.error(status: 0, body: data)
        }
        if object["stop_reason"] as? String == "refusal" {
            throw PlateTranscriptionError.refused
        }
        guard let content = object["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String
        else {
            throw PlateTranscriptionError.malformed
        }
        return text
    }
}

/// The Anthropic Messages API request and response for one plate, as pure
/// data: the network layer (`AnthropicPlateTranscriber`) only moves bytes,
/// so the shape can be unit-tested without a key.
///
/// Proxy-shaped on purpose: the endpoint is a parameter, and the key travels
/// as a header the caller supplies. The developer's own phone uses a key
/// from the keychain (D53); anyone else needs a proxy in front of this,
/// which is then a different `endpoint` and a different header value, not a
/// different request.
enum PlateTranscriptionAPI {
    static let defaultEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    /// Sonnet, the user's choice for cost (~0.7¢ a plate in the experiment).
    static let defaultModel = "claude-sonnet-5"
    static let apiVersion = "2023-06-01"

    /// The experiment's prompt, verbatim: transcribe, never guess.
    static let prompt = """
        This is a photo of a gym strength machine's name plate or badge. Transcribe only what \
        identifies the machine: the manufacturer (brand) and the model or machine name, exactly as \
        printed. If the brand appears only as a logo you recognise, give the brand name. Ignore \
        usage instructions, warnings, serial numbers, part numbers, URLs, phone numbers and load \
        ratings. If there is no plate or nothing identifying, return nulls and an empty list. \
        Do not guess a model that is not printed.
        """

    /// Structured output: the reply IS this object. (`brand_from_logo_only`
    /// from the experiment is gone — it was false on every plate, a wordmark
    /// reads as text to the model.)
    static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "brand": ["type": ["string", "null"],
                      "description": "Manufacturer as printed, or as recognised from its logo; null if none is visible."],
            "model": ["type": ["string", "null"],
                      "description": "The machine's model/name as printed on the plate; null if none."],
            "lines": ["type": "array", "items": ["type": "string"],
                      "description": "The plate's identifying text, top of plate first: brand line, model line, model code if printed. No instructions, warnings, serial numbers, URLs or load ratings."],
            "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
        ],
        "required": ["brand", "model", "lines", "confidence"],
        "additionalProperties": false,
    ]

    /// The JSON body for one plate crop.
    static func requestBody(jpeg: Data, model: String = defaultModel) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "output_config": [
                "effort": "low",
                "format": ["type": "json_schema", "schema": schema],
            ],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg",
                                "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": prompt],
                ],
            ]],
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    /// A 2xx body → the transcription. A refusal, an error object or an
    /// unexpected shape each become the matching `PlateTranscriptionError`.
    static func parse(_ data: Data) throws -> PlateTranscription {
        let text = try MessagesReply.text(from: data)
        guard let json = text.data(using: .utf8),
              let transcription = try? JSONDecoder().decode(PlateTranscription.self, from: json)
        else {
            throw PlateTranscriptionError.malformed
        }
        return transcription
    }

    /// A non-2xx status (or an error object) → the error the sheet shows.
    /// The API's own error type decides "your key" vs "not now".
    static func error(status: Int, body: Data) -> PlateTranscriptionError {
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let type = (object?["error"] as? [String: Any])?["type"] as? String
        if status == 401 || status == 403 || type == "authentication_error" || type == "permission_error" {
            return .unauthorized
        }
        return .unavailable(status: status)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
