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

    @Test func theRequestCarriesThePlateAndTheListAndConstrainsIdsToIt() throws {
        let body = try ExerciseProposalAPI.requestBody(plate: plate, candidates: candidates)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try #require(object["messages"] as? [[String: Any]])
        let content = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(content.count == 1 && content[0]["type"] as? String == "text", "text only — no image")
        let text = try #require(content[0]["text"] as? String)
        #expect(text.contains("brand: Cybex"))
        #expect(text.contains("Eagle NX Overhead Press"))
        #expect(text.contains("\(shoulder.id.uuidString) | Machine Shoulder Press | Shoulders"))
        #expect(text.contains("\(row.id.uuidString) | Seated Row | -"))

        let output = try #require(object["output_config"] as? [String: Any])
        let format = try #require(output["format"] as? [String: Any])
        let schema = try #require(format["schema"] as? [String: Any])
        let properties = try #require(schema["properties"] as? [String: Any])
        let proposals = try #require(properties["proposals"] as? [String: Any])
        let items = try #require(proposals["items"] as? [String: Any])
        let itemProperties = try #require(items["properties"] as? [String: Any])
        let idField = try #require(itemProperties["exercise_id"] as? [String: Any])
        #expect(Set(idField["enum"] as? [String] ?? []) == Set(candidates.map(\.id.uuidString)))
    }

    private func reply(_ proposals: [[String: Any]]) -> Data {
        let inner = try! JSONSerialization.data(withJSONObject: ["proposals": proposals])
        let object: [String: Any] = [
            "type": "message", "stop_reason": "end_turn",
            "content": [["type": "text", "text": String(decoding: inner, as: UTF8.self)]],
        ]
        return try! JSONSerialization.data(withJSONObject: object)
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

    @Test func refusalsAndErrorsAreTheSameAsForATranscription() {
        let refusal: [String: Any] = ["type": "message", "stop_reason": "refusal", "content": []]
        #expect(throws: PlateTranscriptionError.refused) {
            try ExerciseProposalAPI.parse(try JSONSerialization.data(withJSONObject: refusal), candidates: candidates)
        }
        #expect(throws: PlateTranscriptionError.malformed) {
            try ExerciseProposalAPI.parse(Data("{}".utf8), candidates: candidates)
        }
    }

    @Test func theStubOnlyEverAnswersFromTheListItWasSent() async throws {
        let stub = StubExerciseProposer(failure: nil)
        let proposals = try await stub.propose(plate: plate, candidates: candidates)
        #expect(proposals.map(\.id) == [shoulder.id])
        #expect(try await stub.propose(plate: plate, candidates: []).isEmpty)
        #expect(AskAI.proposer == nil, "no key → no proposer, like no transcriber")
    }
}
