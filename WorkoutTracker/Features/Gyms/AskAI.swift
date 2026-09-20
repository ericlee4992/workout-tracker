import Foundation

/// Historical plate-reader compatibility for the explicit on-device scanner's test fixtures.
/// Production AI recognition is IdentifyEquipmentSheet → TerraClient (D56); no Anthropic key is read.
protocol PlateTranscriber: Sendable {
    func transcribe(jpeg: Data) async throws -> PlateTranscription
}

/// Ticket 06: which of the app's exercises a new machine serves.
protocol ExerciseProposer: Sendable {
    func propose(plate: PlateDescription, candidates: [ExerciseCandidate]) async throws -> [ExerciseProposal]
}

/// The Messages API over `URLSession`: one POST, bytes in, bytes out. Every
/// Ask AI feature shares it; the request and reply shapes are the pure
/// `…API` enums, unit-tested without a key. The endpoint is a parameter so
/// a proxy is a configuration, not a rewrite.
struct AnthropicMessagesClient: Sendable {
    /// How the caller is identified: Anthropic's own header for the
    /// developer's key, or a bearer token for a proxy in front of the API
    /// (codex-review-05: "a proxy is a config change" has to include the
    /// header, not just the URL).
    enum Credential: Sendable, Equatable {
        case apiKey(String)
        case bearer(String)
    }

    let credential: Credential
    var endpoint: URL = PlateTranscriptionAPI.defaultEndpoint
    /// The experiment's calls took 2–3 s; a gym's signal is worse than a desk's.
    static let timeout: TimeInterval = 8

    /// The request as it goes on the wire — pure, so the headers are pinned
    /// by a unit test.
    func request(for body: Data) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(PlateTranscriptionAPI.apiVersion, forHTTPHeaderField: "anthropic-version")
        switch credential {
        case .apiKey(let key): request.setValue(key, forHTTPHeaderField: "x-api-key")
        case .bearer(let token): request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    func send(_ body: Data) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request(for: body))
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dnsLookupFailed,
                 .cannotFindHost, .cannotConnectToHost, .internationalRoamingOff, .dataNotAllowed:
                throw PlateTranscriptionError.offline
            case .timedOut:
                throw PlateTranscriptionError.timedOut
            default:
                throw PlateTranscriptionError.unavailable(status: error.code.rawValue)
            }
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PlateTranscriptionAPI.error(status: http.statusCode, body: data)
        }
        return data
    }
}

struct AnthropicPlateTranscriber: PlateTranscriber {
    let client: AnthropicMessagesClient
    var model: String = PlateTranscriptionAPI.defaultModel

    func transcribe(jpeg: Data) async throws -> PlateTranscription {
        try PlateTranscriptionAPI.parse(
            await client.send(PlateTranscriptionAPI.requestBody(jpeg: jpeg, model: model)))
    }
}

struct AnthropicExerciseProposer: ExerciseProposer {
    let client: AnthropicMessagesClient
    var model: String = PlateTranscriptionAPI.defaultModel

    func propose(plate: PlateDescription, candidates: [ExerciseCandidate]) async throws -> [ExerciseProposal] {
        try ExerciseProposalAPI.parse(
            await client.send(ExerciseProposalAPI.requestBody(plate: plate, candidates: candidates, model: model)),
            candidates: candidates)
    }
}

/// Who answers an ask, and whether one is possible at all.
enum AskAI {
    /// UI-test stand-in: a stub transcriber and a stub key, so the sheet's
    /// Ask AI path runs end to end in the Simulator with no key and no
    /// network. Obeys the fixture rule (`WorkoutTrackerStore.fixtureIsEnabled`).
    static let fixtureArgument = "-uiTestAskAI"
    /// With the fixture: the ask fails as if offline / as a refusal.
    static let offlineArgument = "-uiTestAskAIOffline"
    static let refusedArgument = "-uiTestAskAIRefused"
    static let timeoutArgument = "-uiTestAskAITimeout"
    /// With the fixture: the ask takes a few seconds, so a rescan or a
    /// dismissal can be driven while it is in flight.
    static let slowArgument = "-uiTestAskAISlow"

    static var fixtureIsEnabled: Bool {
        WorkoutTrackerStore.fixtureIsEnabled(fixtureArgument)
    }

    /// True when the sheet may offer the button: a key is stored (or the
    /// fixture stands in for one).
    static var isAvailable: Bool { AskAIKeyStore.read() != nil || fixtureIsEnabled }

    static var transcriber: PlateTranscriber? {
        if fixtureIsEnabled { return StubPlateTranscriber(failure: stubFailure) }
        return nil // Replaced by consent-gated IdentifyEquipmentSheet; no legacy network calls.
    }

    /// Ticket 06: the create-new sheet's "Suggest exercises with AI".
    static var proposer: ExerciseProposer? {
        if fixtureIsEnabled { return StubExerciseProposer(failure: stubFailure) }
        guard let key = AskAIKeyStore.read() else { return nil }
        return TerraExerciseProposer(client: TerraClient(key: key))
    }

    private static var stubFailure: PlateTranscriptionError? {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(offlineArgument) ? .offline
            : arguments.contains(refusedArgument) ? .refused
            : arguments.contains(timeoutArgument) ? .timedOut : nil
    }

    /// The stubs' latency: long enough under `-uiTestAskAISlow` to rescan
    /// through it. Throws on cancellation, as the real request does.
    static func stubDelay() async throws {
        await MainActor.run { AskAIFixtureLedger.calls += 1 }
        let slow = ProcessInfo.processInfo.arguments.contains(slowArgument)
        try await Task.sleep(for: .milliseconds(slow ? 4_000 : 300))
    }
}

/// Under `-uiTestAskAI`: how many calls the stubs have taken — the
/// "counting client" that proves no call happens before the on-device read
/// failed to place the plate, and one tap is one call.
@MainActor
enum AskAIFixtureLedger {
    static var calls = 0
}

/// The fixture's answer: what the experiment's stub-worthy plate came back
/// as — a Cybex Eagle NX Overhead Press, a real seeded row, read with the
/// brand the brandless fixture plate lacks.
struct StubPlateTranscriber: PlateTranscriber {
    let failure: PlateTranscriptionError?

    func transcribe(jpeg: Data) async throws -> PlateTranscription {
        try await AskAI.stubDelay()
        if let failure { throw failure }
        return PlateTranscription(
            brand: "Cybex", model: "Eagle NX Overhead Press",
            lines: ["Cybex", "Eagle NX Overhead Press"], confidence: .high)
    }
}

/// The fixture's proposal: the seeded exercise the fixture machine really
/// serves (Machine Shoulder Press for an overhead press), picked from the
/// list it was SENT — so the stub can only ever answer with a real id.
struct StubExerciseProposer: ExerciseProposer {
    let failure: PlateTranscriptionError?

    func propose(plate: PlateDescription, candidates: [ExerciseCandidate]) async throws -> [ExerciseProposal] {
        try await AskAI.stubDelay()
        if let failure { throw failure }
        let pick = candidates.first { $0.name == "Machine Shoulder Press" } ?? candidates.first
        return pick.map { [ExerciseProposal(id: $0.id, reason: "The plate says OVERHEAD PRESS.")] } ?? []
    }
}

/// Compatibility for manual catalog creation: the remaining exercise suggestion also uses Terra.
struct TerraExerciseProposer: ExerciseProposer {
    let client: TerraClient
    func propose(plate: PlateDescription, candidates: [ExerciseCandidate]) async throws -> [ExerciseProposal] {
        guard !candidates.isEmpty else { return [] }
        let text = "Plate: \(plate.brand) \(plate.model) \(plate.lines.joined(separator: " / "))\n" + candidates.map { "\($0.id) | \($0.name)" }.joined(separator: "\n")
        let data = try await client.complete(instructions: ExerciseProposalAPI.prompt, input: text,
            schema: ExerciseProposalAPI.schema(candidateIDs: candidates.map(\.id.uuidString)), name: "exercise_proposals")
        let wrapped = try JSONSerialization.data(withJSONObject: ["content": [["type": "text", "text": String(decoding: data, as: UTF8.self)]]])
        return try ExerciseProposalAPI.parse(wrapped, candidates: candidates)
    }
}
