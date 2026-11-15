import Foundation
import Testing
@testable import WorkoutTracker

/// Scanner accuracy, ticket 06 — the exercise proposal is a pick from the
/// list the app sent, validated on the way back, never free text.
struct ExerciseProposalTests {
    private let shoulder = ExerciseCandidate(id: UUID(), name: "Machine Shoulder Press", muscleGroup: "Shoulders")
    private let chest = ExerciseCandidate(id: UUID(), name: "Seated Chest Press", muscleGroup: "Chest")
    private let row = ExerciseCandidate(id: UUID(), name: "Seated Row", muscleGroup: nil)
    private var candidates: [ExerciseCandidate] { [shoulder, chest, row] }
    private let plate = PlateDescription(brand: "Cybex", model: "Eagle NX Overhead Press", lines: ["Cybex", "Eagle NX Overhead Press"])

    /// The server's `model-exercises` result object, as `AIServerClient.complete` hands it over (its `result`).
    private func reply(_ proposals: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["proposals": proposals])
    }

    @Test func parsesInOrderAndKeepsReasons() throws {
        let data = reply([
            ["exercise_id": shoulder.id.uuidString, "reason": "The plate says Overhead Press."],
            ["exercise_id": chest.id.uuidString.lowercased(), "reason": " Converging press arms. "],
        ])
        let proposals = try ExerciseProposalAPI.parse(data, candidates: candidates)
        #expect(proposals == [
            ExerciseProposal(id: shoulder.id, reason: "The plate says Overhead Press."),
            ExerciseProposal(id: chest.id, reason: "Converging press arms."),
        ])
    }

    @Test func anIdNotInTheListIsDroppedAndARepeatKeepsItsFirstPlace() throws {
        let data = reply([
            ["exercise_id": UUID().uuidString, "reason": "invented"],
            ["exercise_id": row.id.uuidString, "reason": "first"],
            ["exercise_id": row.id.uuidString, "reason": "again"],
            ["exercise_id": "not-a-uuid", "reason": "junk"],
        ])
        let proposals = try ExerciseProposalAPI.parse(data, candidates: candidates)
        #expect(proposals == [ExerciseProposal(id: row.id, reason: "first")])
    }

    @Test func anEmptyListIsAnEmptyAnswerNotAnError() throws {
        #expect(try ExerciseProposalAPI.parse(reply([]), candidates: candidates).isEmpty)
    }

    @Test func theListIsCapped() throws {
        let many = (0..<10).map { ExerciseCandidate(id: UUID(), name: "Exercise \($0)", muscleGroup: nil) }
        let data = reply(many.map { ["exercise_id": $0.id.uuidString, "reason": "r"] })
        #expect(try ExerciseProposalAPI.parse(data, candidates: many).count == ExerciseProposalAPI.maximumProposals)
    }

    @Test func aReplyThatIsNotTheProposalObjectIsMalformed() {
        for body in ["{}", "[]", "not json", #"{"proposals": "none"}"#] {
            #expect(throws: AskAIError.malformed, "\(body)") {
                try ExerciseProposalAPI.parse(Data(body.utf8), candidates: candidates)
            }
        }
    }

    @MainActor @Test func theStubOnlyEverAnswersFromTheListItWasSent() async throws {
        let stub = StubExerciseProposer(failure: nil)
        let proposals = try await stub.propose(plate: plate, candidates: candidates)
        #expect(proposals.map(\.id) == [shoulder.id])
        #expect(try await stub.propose(plate: plate, candidates: []).isEmpty)
        #expect(AskAI.proposer(AccountStore(client: nil)) == nil, "signed out → no proposer (ticket 06)")
    }

    /// Outside the fixture a suggestion needs a signed-in account; the unit test process has neither.
    @MainActor @Test func signedOutMeansNoSuggestion() {
        #expect(AskAI.fixtureIsEnabled == false)
        #expect(AskAI.isAvailable(AccountStore(client: nil)) == false)
    }

    @Test func aFailedSuggestionSaysWhy() {
        #expect(AskAIError.offline.localizedDescription == "Ask AI needs a connection — you look offline.")
        #expect(AskAIError.malformed.localizedDescription == "The answer could not be read.")
    }
}
