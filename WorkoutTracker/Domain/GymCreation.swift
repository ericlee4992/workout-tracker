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

extension GymCreation {
    struct Missing: Error, LocalizedError {
        var errorDescription: String? { "The new gym could not be found." }
    }

    /// The created gym in the screen's context. Throws instead of answering nil: a gym that was saved but cannot be
    /// handed back is an error to show and retry, not "nothing there" (codex-review-02 R2-1).
    static func resolve(_ id: UUID, in context: ModelContext) throws -> Gym {
        guard let gym = try context.fetch(FetchDescriptor<Gym>(predicate: #Predicate { $0.id == id })).first else {
            throw Missing()
        }
        return gym
    }
}

/// One New Gym sheet's Add (codex-review-02 R2-1): the gym is created at most once, then handed back. If the hand-back
/// fails after the save, Save again resolves the SAME gym rather than making another.
struct GymAddAttempt {
    private(set) var committedID: UUID?

    mutating func run<Result>(create: () throws -> UUID, resolve: (UUID) throws -> Result) throws -> Result {
        let id = try committedID ?? create()
        committedID = id
        return try resolve(id)
    }
}
