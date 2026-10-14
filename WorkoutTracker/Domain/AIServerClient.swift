import Foundation
import Security

/// Public beta ticket 06 (app half): the three AI flows go to the app's server, signed in (D60). The server owns each
/// flow's instructions, schema, model and limits (server/README → AI); the app sends only the flow's input and keeps
/// validating every reply exactly as before — the server is not trusted to have checked anything.
enum AIFlow: String, CaseIterable, Sendable {
    case scanMachine = "scan-machine"
    case routineWeek = "routine-week"
    case modelExercises = "model-exercises"

    /// The plural noun in "You've used today's 60 machine scans." (the profile's tile titles, lowercased).
    var noun: String {
        switch self {
        case .scanMachine: "machine scans"
        case .routineWeek: "template weeks"
        case .modelExercises: "exercise suggestions"
        }
    }
}

/// `POST /v1/ai/{flow}` with the session; the answer's `result` (the model's JSON, checked by the server against the
/// app's own bounds) comes back as bytes for the caller's decoder and validation. Nothing here logs the token, the
/// input or the reply.
struct AIServerClient: Sendable {
    let baseURL: URL
    let token: String
    var session: URLSession = .shared
    /// Called with the refused session on a 401, so the app signs out (feedback does the same).
    var onUnauthorized: @Sendable (String) -> Void = { _ in }
    /// Longer than the server's own 60 s OpenAI deadline, so its `ai_timeout` arrives rather than ours.
    static let timeout: TimeInterval = 75

    // MARK: Inputs (server/README → AI)

    /// Scan Machine: the seeded exercises and the one re-encoded JPEG.
    static func scanBody(exercises: [(id: UUID, name: String, loadType: String)], jpeg: Data) -> [String: Any] {
        ["exercises": exercises.map { ["id": $0.id.uuidString, "name": $0.name, "loadType": $0.loadType] },
         "jpeg": jpeg.base64EncodedString()]
    }

    /// New Model: the plate as typed and read, and the app's exercise list.
    static func modelExercisesBody(plate: PlateDescription, candidates: [ExerciseCandidate]) -> [String: Any] {
        ["plate": ["brand": plate.brand, "model": plate.model, "lines": plate.lines],
         "candidates": candidates.map { candidate -> [String: Any] in
             var row: [String: Any] = ["id": candidate.id.uuidString, "name": candidate.name]
             if let group = candidate.muscleGroup { row["muscleGroup"] = group }
             return row
         }]
    }

    func request(_ flow: AIFlow, body: Data) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "v1/ai/\(flow.rawValue)"))
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }

    func complete(_ flow: AIFlow, json: [String: Any]) async throws -> Data {
        guard let body = try? JSONSerialization.data(withJSONObject: json) else { throw AIServerError.rejected("encoding") }
        return try await complete(flow, body: body)
    }

    func complete(_ flow: AIFlow, encodable: some Encodable) async throws -> Data {
        guard let body = try? JSONEncoder().encode(encodable) else { throw AIServerError.rejected("encoding") }
        return try await complete(flow, body: body)
    }

    func complete(_ flow: AIFlow, body: Data) async throws -> Data {
        try Task.checkCancellation()
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request(flow, body: body)) }
        catch let error as URLError { throw Self.transportError(error) }
        try Task.checkCancellation()
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw AIServerError.invalid }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if (200..<300).contains(status) {
            guard let result = object?["result"] as? [String: Any],
                  let bytes = try? JSONSerialization.data(withJSONObject: result) else { throw AIServerError.invalid }
            return bytes
        }
        let code = object?["error"] as? String
        if status == 401 { onUnauthorized(token) }
        if status == 429 && code == "ai_limit" {
            // The limit and the reset time come from the usage endpoint; without them the line still reads.
            let usage = await self.usage()
            throw AIServerError.limit(flow, usage?.flows[flow.rawValue]?.limit, resetsAt: usage?.resetsAt ?? AIResetCopy.nextReset())
        }
        throw Self.error(status: status, code: code, flow: flow)
    }

    private func usage() async -> AccountClient.Usage? {
        var client = AccountClient(baseURL: baseURL)
        client.session = session
        return try? await client.usage(token: token)
    }

    static func error(status: Int, code: String?, flow: AIFlow) -> AIServerError {
        switch (status, code) {
        case (401, _): .signedOut
        case (429, "ai_limit"): .limit(flow, nil, resetsAt: AIResetCopy.nextReset())
        case (429, "ai_attempts"): .attempts(resetsAt: AIResetCopy.nextReset())
        case (429, _): .busy
        case (503, "ai_paused"): .paused
        case (503, "ai_timeout"), (504, _), (408, _): .timedOut
        case (502, "ai_refused"): .refused
        case (502, "ai_invalid"): .invalid
        case (500..., _): .unavailable
        default: .rejected(code ?? "status_\(status)")
        }
    }

    static func transportError(_ error: URLError) -> any Error {
        switch error.code {
        case .cancelled: CancellationError()
        case .timedOut: AIServerError.timedOut
        default: AIServerError.offline
        }
    }
}

/// Why an AI request did not answer, in the words the app shows. Every case leaves the manual path open.
enum AIServerError: LocalizedError, Equatable {
    /// 401: the session is unknown or expired (the phone is then signed out), or there is no session.
    case signedOut
    /// 429 `ai_limit`: today's successes are used up. The limit is the server's, when known.
    case limit(AIFlow, Int?, resetsAt: Date)
    /// 429 `ai_attempts`: twice the limit in attempts, mostly failures.
    case attempts(resetsAt: Date)
    /// 429 `ai_busy`: every remaining slot is held by a request still running.
    case busy
    /// 503 `ai_paused`: the off switch, for everyone or this account.
    case paused
    case offline
    case timedOut
    /// 5xx other than the above: OpenAI or the server failing.
    case unavailable
    /// 502 `ai_refused`: the model declined.
    case refused
    /// 502 `ai_invalid`, or a reply the app itself refuses.
    case invalid
    /// 400/413: the server refused the request's shape — a bug in the app, not the tester's doing.
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in to use AI."
        case .limit(let flow, let limit, let resetsAt):
            "You've used today's \(limit.map { "\($0) " } ?? "")\(flow.noun). They \(AIResetCopy.reset(at: resetsAt))."
        case .attempts(let resetsAt):
            "Too many AI tries today. Try again after \(AIResetCopy.clock(resetsAt, zone: .current)) or continue manually."
        case .busy: "Another AI request is still running. Try again in a moment."
        case .paused: "AI is paused right now. You can continue manually."
        case .offline: "Could not reach the server. Check your connection or continue manually."
        case .timedOut: "AI took too long. Try again."
        case .unavailable: "AI is unavailable right now. Try again later."
        case .refused: "AI could not help with this request. Change the request or continue manually."
        case .invalid: "AI returned an incomplete or invalid result. Try again or continue manually."
        case .rejected: "AI couldn't take this request. Continue manually."
        }
    }
}

/// The developer's old OpenAI key (D53–D58, before ticket 06) in this phone's keychain: removed once at launch, so no
/// key is left on any phone after the update.
enum LegacyOpenAIKey {
    static func purge() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "workouttracker") + ".askai",
                       kSecAttrAccount as String: "openai-api-key"] as CFDictionary)
    }
}

/// The daily limits reset at midnight in New York (the server's day). Said as "midnight" where the phone's clock agrees,
/// else as the local time ("9:00 PM") — a tester in another time zone sees when it actually happens.
enum AIResetCopy {
    static let serverZone = TimeZone(identifier: "America/New_York")!

    /// The next New York midnight after `now` — what the server's `resetsAt` says, for when it is not at hand.
    static func nextReset(after now: Date = .now) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = serverZone
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
    }

    /// "reset at midnight" / "reset at 9:00 PM".
    static func reset(at date: Date, zone: TimeZone = .current) -> String { "reset at \(clock(date, zone: zone))" }

    /// The profile's and Ask AI's "Resets at midnight" / "Resets at 9:00 PM".
    static func resets(at date: Date, zone: TimeZone = .current) -> String { "Resets at \(clock(date, zone: zone))" }

    static func clock(_ date: Date, zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        if parts.hour == 0 && parts.minute == 0 { return "midnight" }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return date.formatted(style)
    }
}
