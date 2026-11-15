import Foundation

/// Ticket 06: which of the app's exercises a new machine serves. Production answers come from the server's
/// `model-exercises` flow (`ServerExerciseProposer`, D60); a stub stands in under the UI-test fixtures.
protocol ExerciseProposer: Sendable {
    func propose(plate: PlateDescription, candidates: [ExerciseCandidate]) async throws -> [ExerciseProposal]
}

/// Who answers "Suggest exercises with AI", and whether one is possible at all.
enum AskAI {
    /// UI-test stand-in: stub answers, so the New Model sheet's suggestion runs end
    /// to end in the Simulator signed out and with no network. Obeys the fixture
    /// rule (`WorkoutTrackerStore.fixtureIsEnabled`).
    static let fixtureArgument = "-uiTestAskAI"
    /// With the fixture: the suggestion fails as if offline / as a refusal / timed out.
    static let offlineArgument = "-uiTestAskAIOffline"
    static let refusedArgument = "-uiTestAskAIRefused"
    static let timeoutArgument = "-uiTestAskAITimeout"
    /// With the fixture: the suggestion takes a few seconds, so a dismissal can be
    /// driven while it is in flight.
    static let slowArgument = "-uiTestAskAISlow"

    static var fixtureIsEnabled: Bool {
        WorkoutTrackerStore.fixtureIsEnabled(fixtureArgument)
    }

    /// True when a suggestion can be sent: signed in (ticket 06, D60), or
    /// a fixture stands in.
    @MainActor static func isAvailable(_ account: AccountStore) -> Bool {
        fixtureIsEnabled || TerraAccess.ready(account)
    }

    /// Ticket 06: the create-new sheet's "Suggest exercises with AI" —
    /// through the server for the signed-in session (public beta 06).
    @MainActor static func proposer(_ account: AccountStore) -> ExerciseProposer? {
        if fixtureIsEnabled || TerraAccess.fixture { return StubExerciseProposer(failure: stubFailure) }
        return TerraAccess.client(account).map(ServerExerciseProposer.init(client:))
    }

    private static var stubFailure: AskAIError? {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(offlineArgument) ? .offline
            : arguments.contains(refusedArgument) ? .refused
            : arguments.contains(timeoutArgument) ? .timedOut : nil
    }

    /// The stub's latency: long enough under `-uiTestAskAISlow` to act while it
    /// is in flight. Throws on cancellation, as the real request does.
    static func stubDelay() async throws {
        let slow = ProcessInfo.processInfo.arguments.contains(slowArgument)
        try await Task.sleep(for: .milliseconds(slow ? 4_000 : 300))
    }
}

/// The fixture's proposal: the seeded exercise the fixture machine really
/// serves (Machine Shoulder Press for an overhead press), picked from the
/// list it was SENT — so the stub can only ever answer with a real id.
struct StubExerciseProposer: ExerciseProposer {
    let failure: AskAIError?

    func propose(plate: PlateDescription, candidates: [ExerciseCandidate]) async throws -> [ExerciseProposal] {
        try await AskAI.stubDelay()
        if let failure { throw failure }
        let pick = candidates.first { $0.name == "Machine Shoulder Press" } ?? candidates.first
        return pick.map { [ExerciseProposal(id: $0.id, reason: "The plate says OVERHEAD PRESS.")] } ?? []
    }
}

/// The server's `model-exercises` flow: the plate and the app's list in, ids from that list out — then the same
/// parse as ever (unknown and repeated ids dropped, at most six), whatever the server checked.
struct ServerExerciseProposer: ExerciseProposer {
    let client: AIServerClient
    func propose(plate: PlateDescription, candidates: [ExerciseCandidate]) async throws -> [ExerciseProposal] {
        guard !candidates.isEmpty else { return [] }
        let data = try await client.complete(.modelExercises,
                                             json: AIServerClient.modelExercisesBody(plate: plate, candidates: candidates))
        return try ExerciseProposalAPI.parse(data, candidates: candidates)
    }
}
