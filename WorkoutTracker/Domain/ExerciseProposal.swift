import Foundation

/// Scanner accuracy, ticket 06 — on the create-new path, the AI proposes
/// which of the app's OWN exercises a new machine serves.
///
/// The catalog already lists exercises per row for known machines; a plate
/// that reads "Ground Base Combo Incline" or "Plate Loaded Squat Press" is
/// obvious to a model that has read it, and the answer is a pick from a list
/// the app supplies — never free text. Text only: no image is involved and
/// D34 is untouched. One tap, one call, fail closed, the user owns the ticks.
/// The server's `model-exercises` flow owns the prompt, schema and model (D60);
/// the app keeps validating the reply against the list it sent.
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

    /// The reply, validated against what was sent: an id not in the list is
    /// dropped (the server's schema already forbids it — belt and braces), a
    /// repeat keeps its first position, and the list is capped. Order is the
    /// model's: most likely first. `data` is the flow's result object, `{"proposals": [{"exercise_id", "reason"}]}`.
    static func parse(_ data: Data, candidates: [ExerciseCandidate]) throws -> [ExerciseProposal] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["proposals"] as? [[String: Any]]
        else { throw AskAIError.malformed }
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

/// Why a suggestion produced nothing, from the stub (`-uiTestAskAI…`) or an unreadable reply; the server's own
/// failures arrive as `AIServerError`. Every case is user-facing: the sheet shows the description and keeps the
/// user's ticks as they were (fail closed — nothing is retried in the background).
enum AskAIError: Error, Equatable, LocalizedError {
    case offline
    case timedOut
    /// The model declined.
    case refused
    /// A reply that was not the structured answer asked for.
    case malformed

    var errorDescription: String? {
        switch self {
        case .offline: "Ask AI needs a connection — you look offline."
        case .timedOut: "Ask AI took too long. Try again when the signal is better."
        case .refused: "Couldn't read this photo."
        case .malformed: "The answer could not be read."
        }
    }
}
