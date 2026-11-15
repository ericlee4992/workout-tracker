import Foundation
import SwiftData

/// Tester feedback 02 (D89), codex-review-02: New Gym's Add as ONE save. The gym — and, when asked, the remembered
/// selection (D1) — are written in an isolated context and saved together; a failed save rolls that context back and
/// rethrows, so nothing is left pending in the screen's context: Cancel after a failure leaves no gym behind, a retry
/// makes exactly one, and the stored selection never differs from what the screen shows. Isolated, like
/// `AIRoutinePersistence`, so the rollback cannot touch the user's other unsaved edits.
@MainActor
enum GymCreation {
    /// Creates the gym and returns its id. `selecting`: also remember it as the selected gym (D1) in the same save.
    /// `save` exists for tests (a failing save); production uses the context's own.
    @discardableResult
    static func create(name: String, city: String?, defaultUnit: WeightUnit?, selecting: Bool,
                       in container: ModelContainer, at date: Date = .now,
                       save: (ModelContext) throws -> Void = { try $0.save() }) throws -> UUID {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let gym = Gym(name: name, city: city, defaultUnit: defaultUnit)
        do {
            context.insert(gym)
            if selecting {
                let preferences = try AppPreferences.canonical(in: context)
                preferences.selectedGymID = gym.id
                preferences.updatedAt = date
            }
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
        return gym.id
    }
}
