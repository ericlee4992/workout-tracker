import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Tester feedback 02 (D89), codex-review-02: New Gym's Add is one save — the gym and, from Train, the remembered
/// selection (D1) — and a failed save leaves nothing pending, keeps the stored pick and spares unrelated edits.
@MainActor
struct GymCreationTests {
    private struct SaveFailed: Error {}

    private func makeContainer() throws -> ModelContainer {
        let schema = WorkoutTrackerStore.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    /// A store with one gym, "Iron Temple", remembered as the selection; the screen's context.
    private func storeWithSelectedGym() throws -> (ModelContainer, ModelContext, Gym) {
        let container = try makeContainer()
        let screen = ModelContext(container)
        let iron = Gym(name: "Iron Temple")
        screen.insert(iron)
        try GymSelection.remember(iron, in: screen)
        return (container, screen, iron)
    }

    private func storedSelection(_ container: ModelContainer) throws -> UUID? {
        try AppPreferences.canonical(in: ModelContext(container)).selectedGymID
    }

    private func gymNames(_ container: ModelContainer) throws -> [String] {
        try ModelContext(container).fetch(FetchDescriptor<Gym>(sortBy: [SortDescriptor(\.name)])).map(\.name)
    }

    @Test func createsTheGymAndRemembersItInOneSave() throws {
        let (container, _, _) = try storeWithSelectedGym()
        var saves = 0
        let id = try GymCreation.create(name: "Harbor Gym", city: "Busan", defaultUnit: .kg, selecting: true,
                                        in: container, save: { saves += 1; try $0.save() })
        #expect(saves == 1, "the gym and the selection are one save")
        #expect(try storedSelection(container) == id)
        let gym = try #require(try ModelContext(container).fetch(FetchDescriptor<Gym>(predicate: #Predicate { $0.id == id })).first)
        #expect(gym.name == "Harbor Gym" && gym.city == "Busan" && gym.defaultUnit == .kg)
    }

    @Test func withoutSelectingTheStoredPickStays() throws {
        let (container, _, iron) = try storeWithSelectedGym()
        try GymCreation.create(name: "Harbor Gym", city: nil, defaultUnit: nil, selecting: false, in: container)
        #expect(try storedSelection(container) == iron.id)
        #expect(try gymNames(container) == ["Harbor Gym", "Iron Temple"])
    }

    /// The finding: a failed Add followed by Cancel (and the screen's next save) must leave no gym, and a retry must
    /// make exactly one.
    @Test func aFailedSaveLeavesNothingPendingAndARetryMakesOne() throws {
        let (container, screen, iron) = try storeWithSelectedGym()
        #expect(throws: SaveFailed.self) {
            try GymCreation.create(name: "Harbor Gym", city: nil, defaultUnit: nil, selecting: true,
                                   in: container, save: { _ in throw SaveFailed() })
        }
        #expect(!screen.hasChanges, "nothing was left pending in the screen's context")
        try screen.save()  // whatever the screen saves next
        #expect(try gymNames(container) == ["Iron Temple"], "Cancel after the failure created no gym")
        #expect(try storedSelection(container) == iron.id, "the stored pick is unchanged")

        let id = try GymCreation.create(name: "Harbor Gym", city: nil, defaultUnit: nil, selecting: true, in: container)
        #expect(try gymNames(container) == ["Harbor Gym", "Iron Temple"], "the retry made exactly one")
        #expect(try storedSelection(container) == id)
    }

    /// The rollback is the isolated context's own: an edit the screen has not saved yet survives a failed Add.
    @Test func aFailedSaveSparesTheScreensUnsavedEdits() throws {
        let (container, screen, iron) = try storeWithSelectedGym()
        iron.city = "Seoul"
        #expect(throws: SaveFailed.self) {
            try GymCreation.create(name: "Harbor Gym", city: nil, defaultUnit: nil, selecting: true,
                                   in: container, save: { _ in throw SaveFailed() })
        }
        #expect(screen.hasChanges && iron.city == "Seoul", "the unrelated edit is still pending")
    }

    /// R2-1: the save succeeds but the hand-back fails; Add again resolves the same gym — one gym, one remembered
    /// selection, and the screen ends up holding that gym.
    @Test func aFailedHandBackRetriesTheSameGym() throws {
        let (container, screen, _) = try storeWithSelectedGym()
        var attempt = GymAddAttempt()
        var creates = 0
        let create = {
            creates += 1
            return try GymCreation.create(name: "Harbor Gym", city: nil, defaultUnit: nil, selecting: true, in: container)
        }
        #expect(throws: GymCreation.Missing.self) {
            try attempt.run(create: create, resolve: { _ in throw GymCreation.Missing() })
        }
        let committed = try #require(attempt.committedID)
        let shown = try attempt.run(create: create, resolve: { try GymCreation.resolve($0, in: screen) })
        #expect(creates == 1, "the retry did not create again")
        #expect(shown.id == committed && shown.name == "Harbor Gym", "the screen holds the saved gym")
        #expect(try gymNames(container) == ["Harbor Gym", "Iron Temple"])
        #expect(try storedSelection(container) == committed, "one remembered selection, the shown one")
    }

    @Test func resolvingAGymThatIsNotThereThrows() throws {
        let (_, screen, _) = try storeWithSelectedGym()
        #expect(throws: GymCreation.Missing.self) { try GymCreation.resolve(UUID(), in: screen) }
    }
}
