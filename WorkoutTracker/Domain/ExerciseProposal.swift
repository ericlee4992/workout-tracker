import Foundation

/// Scanner accuracy, ticket 06 — on the create-new path, Claude proposes
/// which of the app's OWN exercises a new machine serves.
///
/// The catalog already lists exercises per row for known machines; a plate
/// that reads "Ground Base Combo Incline" or "Plate Loaded Squat Press" is
/// obvious to a model that has read it, and the answer is a pick from a list
/// the app supplies — never free text. Text only: the reading exists by the
/// time this runs, so no image is involved and D34 is untouched. Same rules
/// as D53 otherwise: one tap, one call, fail closed, the user owns the ticks.
struct ExerciseCandidate: Equatable {
    let id: UUID
    let name: String
    let muscleGroup: String?
}

/// What the plate said, as the request describes it.
struct PlateDescription: Equatable {
    var brand: String
    var model: String
    var lines: [String]
}

struct ExerciseProposal: Equatable {
    let id: UUID
    let reason: String
}

enum ExerciseProposalAPI {
    /// At most this many ticks are proposed; a station serves a few
    /// movements, not a dozen.
    static let maximumProposals = 6

    static let prompt = """
        A gym strength machine's name plate has been read. Below is the plate, then a list of the \
        exercises this app knows, one per line as id | name | muscle group. Decide which of THESE \
        exercises the machine serves. Return only ids from the list, most likely first, at most six, \
        each with a one-line reason. If the plate does not say what the machine does and the name \
        does not make it clear, return an empty list rather than guessing.
        """

    /// The id field may only take one of the ids that were sent.
    static func schema(candidateIDs: [String]) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "proposals": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "exercise_id": ["type": "string", "enum": candidateIDs],
                            "reason": ["type": "string"],
                        ],
                        "required": ["exercise_id", "reason"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["proposals"],
            "additionalProperties": false,
        ]
    }

    static func requestBody(
        plate: PlateDescription, candidates: [ExerciseCandidate],
        model: String = PlateTranscriptionAPI.defaultModel
    ) throws -> Data {
        var text = prompt + "\n\nPLATE\n"
        text += "brand: \(plate.brand.isEmpty ? "(not printed)" : plate.brand)\n"
        text += "model: \(plate.model.isEmpty ? "(not printed)" : plate.model)\n"
        text += "lines: " + (plate.lines.isEmpty ? "(none)" : plate.lines.joined(separator: " / ")) + "\n"
        text += "\nEXERCISES\n"
        text += candidates.map { "\($0.id.uuidString) | \($0.name) | \($0.muscleGroup ?? "-")" }
            .joined(separator: "\n")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "output_config": [
                "effort": "low",
                "format": ["type": "json_schema", "schema": schema(candidateIDs: candidates.map(\.id.uuidString))],
            ],
            "messages": [["role": "user", "content": [["type": "text", "text": text]]]],
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    /// The reply, validated against what was sent: an id not in the list is
    /// dropped (the schema's enum already forbids it — belt and braces), a
    /// repeat keeps its first position, and the list is capped. Order is the
    /// model's: most likely first.
    static func parse(_ data: Data, candidates: [ExerciseCandidate]) throws -> [ExerciseProposal] {
        let text = try MessagesReply.text(from: data)
        guard let json = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let raw = object["proposals"] as? [[String: Any]]
        else { throw PlateTranscriptionError.malformed }
        let known = Dictionary(candidates.map { ($0.id.uuidString.lowercased(), $0.id) }) { first, _ in first }
        var seen: Set<UUID> = []
        var proposals: [ExerciseProposal] = []
        for entry in raw {
            guard let idText = entry["exercise_id"] as? String,
                  let id = known[idText.lowercased()],
                  !seen.contains(id)
            else { continue }
            seen.insert(id)
            proposals.append(ExerciseProposal(
                id: id, reason: (entry["reason"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)))
            if proposals.count == maximumProposals { break }
        }
        return proposals
    }
}
