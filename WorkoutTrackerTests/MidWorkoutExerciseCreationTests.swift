import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 19 — creating an exercise mid-workout. The pickers own the taps; the
// contract they lean on lives in `EquipmentLifecycle.createExercise` and is
// what these tests pin down: the row lands in D24's user ID space, linking it
// to a station's model makes that station offer it, and neither survives a
// catalog reconciliation by accident.

struct MidWorkoutExerciseCreationTests {

    // MARK: Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = WorkoutTrackerStore.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private let seededExerciseID = UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000019")!
    private let seededModelID = UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000019")!

    private func catalog(version: Int, exerciseName: String) -> SeedCatalog {
        SeedCatalog(
            version: version,
            exercises: [
                SeedExercise(
                    id: seededExerciseID, name: exerciseName, loadType: .weighted,
                    equipmentTypeTags: [.machine], muscleGroup: "Chest"),
            ],
            equipmentModels: [
                SeedEquipmentModel(
                    id: seededModelID, manufacturer: "Life Fitness",
                    modelName: "Insignia Chest Press", exerciseIDs: [seededExerciseID]),
            ])
    }

    private func seededContext() throws -> ModelContext {
        let context = ModelContext(try makeInMemoryContainer())
        try CatalogSeeder.reconcile(catalog(version: 1, exerciseName: "Chest Press"), in: context)
        return context
    }

    private func seededModel(in context: ModelContext) throws -> EquipmentModel {
        let id = seededModelID
        return try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.id == id })).first)
    }

    // MARK: Creation lands in the user ID space

    /// The movement invented mid-workout is user-owned (`isSeeded == false`),
    /// shows up in the same catalog query the Exercises tab and every later
    /// picker use, and can be logged against immediately.
    @Test func midWorkoutCreationProducesAUserExerciseThatIsImmediatelyLoggable() throws {
        let context = try seededContext()
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: nil)

        let created = try EquipmentLifecycle(context: context).createExercise(
            name: "  Landmine Press  ",
            loadType: .weighted,
            equipmentTypeTags: [.barbell])

        #expect(created.isSeeded == false)
        #expect(created.name == "Landmine Press", "The name is trimmed, not stored raw")
        #expect(created.equipmentTypeTags == [.barbell])

        // The catalog every picker queries now contains it, next to the seeded row.
        let catalogRows = try context.fetch(FetchDescriptor<Exercise>())
        #expect(catalogRows.count == 2)
        #expect(catalogRows.contains { $0.id == created.id && !$0.isSeeded })

        // …and the entry being added selects it without a further step.
        let entry = try session.addEntry(for: created, to: workout)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        set.reps = 8
        set.weightValue = 40
        try session.toggleCompletion(of: set)
        #expect(entry.snapshotExerciseName == "Landmine Press")
        #expect(entry.exercise?.isSeeded == false)
    }

    /// A blank name is not an exercise — the form disables Add, and the
    /// service refuses rather than storing an unnamed row.
    @Test func blankNamesAreRefused() throws {
        let context = try seededContext()
        #expect(throws: EquipmentLifecycleError.emptyName) {
            try EquipmentLifecycle(context: context).createExercise(name: "   ")
        }
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }

    // MARK: Linking to the station's model

    /// Created from a machine's chooser, the exercise is appended to that
    /// machine's model — so the station offers it the next time it is picked
    /// (D7), instead of the movement being unlisted forever.
    @Test func linkingToAModelUpdatesItsExerciseIDsAndTheStationOffersIt() throws {
        let context = try seededContext()
        let model = try seededModel(in: context)
        let gym = Gym(name: "Gangnam Fitness")
        let machine = MachineInstance(label: "Chest press #1", gym: gym, model: model)
        context.insert(gym)
        context.insert(machine)
        try context.save()

        let created = try EquipmentLifecycle(context: context).createExercise(
            name: "Single-Arm Chest Press",
            equipmentTypeTags: [.machine],
            linkedTo: model)

        #expect(model.exerciseIDs == [seededExerciseID, created.id])

        let offered = try WorkoutSession(context: context).exercisesFor(machine: machine)
        #expect(offered.map(\.id) == [seededExerciseID, created.id])

        // Creating it a second time against the same model does not duplicate
        // the link for the row already there.
        try EquipmentLifecycle(context: context).createExercise(
            name: "Another Movement", linkedTo: model)
        #expect(model.exerciseIDs.count == 3)
        #expect(Set(model.exerciseIDs).count == 3)
    }

    /// A model-less machine has nothing to link to — creation still works and
    /// touches no model.
    @Test func creationWithoutAModelTouchesNoModel() throws {
        let context = try seededContext()
        let model = try seededModel(in: context)

        let created = try EquipmentLifecycle(context: context).createExercise(
            name: "Sled Push", linkedTo: nil)

        #expect(created.isSeeded == false)
        #expect(model.exerciseIDs == [seededExerciseID])
    }

    // MARK: Reconciliation (ticket 04) leaves it alone

    /// A catalog version bump rewrites the allowlisted seeded fields — and
    /// must leave the mid-workout creation entirely alone: the exercise keeps
    /// every field, and the link the user added to a *seeded* model survives
    /// alongside the catalog's own links rather than being overwritten.
    @Test func catalogReconciliationLeavesTheCreatedExerciseAndItsLinkAlone() throws {
        let context = try seededContext()
        let model = try seededModel(in: context)
        let created = try EquipmentLifecycle(context: context).createExercise(
            name: "Single-Arm Chest Press",
            loadType: .assisted,
            equipmentTypeTags: [.machine, .cable],
            linkedTo: model)

        // Same-version rerun, then an upgrade that rewrites the seeded rows.
        try CatalogSeeder.reconcile(catalog(version: 1, exerciseName: "Chest Press"), in: context)
        try CatalogSeeder.reconcile(
            catalog(version: 2, exerciseName: "Seated Chest Press"), in: context)

        // The upgrade did land on the seeded row…
        let seededID = seededExerciseID
        let seeded = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == seededID })).first)
        #expect(seeded.name == "Seated Chest Press")

        // …while the user's exercise kept every field and its identity.
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 2)
        let createdID = created.id
        let survivor = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == createdID })).first)
        #expect(survivor.isSeeded == false)
        #expect(survivor.name == "Single-Arm Chest Press")
        #expect(survivor.loadType == .assisted)
        #expect(survivor.equipmentTypeTags == [.machine, .cable])

        // …and the link the user added to the seeded model survived the
        // rewrite of that model's catalog links.
        #expect(model.exerciseIDs == [seededExerciseID, created.id])
    }

    /// The merge preserves *user* links only: a stale id the catalog dropped
    /// (a seeded exercise no longer served by this model) is still removed.
    @Test func reconciliationStillDropsSeededLinksTheCatalogRemoved() throws {
        let context = try seededContext()
        let model = try seededModel(in: context)
        let ghostSeededID = UUID()
        context.insert(Exercise(id: ghostSeededID, name: "Old Link", isSeeded: true))
        model.exerciseIDs.append(ghostSeededID)
        let created = try EquipmentLifecycle(context: context).createExercise(
            name: "Single-Arm Chest Press", linkedTo: model)
        try context.save()

        try CatalogSeeder.reconcile(
            catalog(version: 2, exerciseName: "Seated Chest Press"), in: context)

        #expect(model.exerciseIDs == [seededExerciseID, created.id])
    }
}
