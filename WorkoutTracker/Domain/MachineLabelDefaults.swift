import Foundation

// What a machine should be called when its model is picked. Pure: no UI, no
// SwiftData — CLAUDE.md keeps fallback selection in `Domain/` and unit-tested,
// and this is a fallback selection (codex-review, standards finding 1).

enum MachineLabelDefaults {

    /// The label to offer for a machine whose model serves `exerciseNames`.
    ///
    /// The **movement**, when the model serves exactly one: the machine row
    /// already prints "Life Fitness Insignia Series Chest Press" underneath, so
    /// naming the machine after its model says the same thing twice and leaves
    /// the row saying nothing about what you do on it (user, 2026-08-12).
    ///
    /// A station serving five movements has no single answer, so it keeps the
    /// model name — inventing one would be a guess the user has to undo.
    static func label(
        modelName: String, exerciseNames: [String]
    ) -> String {
        guard exerciseNames.count == 1,
              let movement = exerciseNames.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !movement.isEmpty
        else { return modelName }
        return movement
    }
}
