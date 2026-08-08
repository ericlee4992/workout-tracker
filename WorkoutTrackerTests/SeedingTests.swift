import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 04 — versioned idempotent catalog seeding (D24).

struct SeedingTests {

    // MARK: Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = WorkoutTrackerStore.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func counts(in context: ModelContext) throws -> (exercises: Int, models: Int) {
        (
            try context.fetchCount(FetchDescriptor<Exercise>()),
            try context.fetchCount(FetchDescriptor<EquipmentModel>())
        )
    }

    private func storedVersion(in context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<AppPreferences>())
        try #require(all.count == 1, "expected exactly one AppPreferences row")
        return all[0].seededCatalogVersion
    }

    // Small programmatic catalogs for version-transition tests.

    private let exerciseAID = UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000001")!
    private let exerciseBID = UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000002")!
    private let exerciseCID = UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000003")!
    private let modelXID = UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000001")!
    private let modelYID = UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000002")!

    private func catalogV1() -> SeedCatalog {
        SeedCatalog(
            version: 1,
            exercises: [
                SeedExercise(
                    id: exerciseAID, name: "Chest Press", loadType: .weighted,
                    equipmentTypeTags: [.machine], muscleGroup: "Chest"),
                SeedExercise(
                    id: exerciseBID, name: "Assisted Pull-Up", loadType: .assisted,
                    equipmentTypeTags: [.machine], muscleGroup: "Back"),
            ],
            equipmentModels: [
                SeedEquipmentModel(
                    id: modelXID, manufacturer: "Life Fitness",
                    modelName: "Insignia Chest Press", exerciseIDs: [exerciseAID]),
            ])
    }

    private func catalogV2() -> SeedCatalog {
        SeedCatalog(
            version: 2,
            exercises: [
                // Renamed + retagged (allowlisted metadata update).
                SeedExercise(
                    id: exerciseAID, name: "Seated Chest Press", loadType: .weighted,
                    equipmentTypeTags: [.machine, .cable], muscleGroup: "Chest"),
                SeedExercise(
                    id: exerciseBID, name: "Assisted Pull-Up", loadType: .assisted,
                    equipmentTypeTags: [.machine], muscleGroup: "Back"),
                // New in v2.
                SeedExercise(
                    id: exerciseCID, name: "Dip", loadType: .bodyweightPlus,
                    equipmentTypeTags: [.bodyweight], muscleGroup: "Chest"),
            ],
            equipmentModels: [
                // Link list grows (allowlisted links update).
                SeedEquipmentModel(
                    id: modelXID, manufacturer: "Life Fitness",
                    modelName: "Insignia Chest Press",
                    exerciseIDs: [exerciseAID, exerciseCID]),
                // New in v2.
                SeedEquipmentModel(
                    id: modelYID, manufacturer: "Matrix",
                    modelName: "Ultra Assisted Chin/Dip",
                    exerciseIDs: [exerciseBID, exerciseCID]),
            ])
    }

    // MARK: Bundled fixture

    /// The shipped fixture meets the ticket's content bar and only references
    /// exercises it also defines.
    @Test func bundledFixtureMeetsContentBar() throws {
        let catalog = try SeedCatalog.bundled()

        #expect(catalog.version >= 1)
        #expect(catalog.exercises.count == 12)
        #expect(catalog.equipmentModels.count >= 20)
        #expect(Set(catalog.equipmentModels.map(\.manufacturer)).count >= 6)

        // Fixed catalog UUIDs are unique per entity kind.
        let exerciseIDs = Set(catalog.exercises.map(\.id))
        #expect(exerciseIDs.count == catalog.exercises.count)
        #expect(Set(catalog.equipmentModels.map(\.id)).count == catalog.equipmentModels.count)

        // Every model links to ≥1 defined exercise; ≥1 multi-exercise station.
        for model in catalog.equipmentModels {
            #expect(!model.exerciseIDs.isEmpty, "\(model.modelName) links no exercise")
            #expect(Set(model.exerciseIDs).isSubset(of: exerciseIDs),
                    "\(model.modelName) links an undefined exercise")
        }
        #expect(catalog.equipmentModels.contains { Set($0.exerciseIDs).count >= 2 })

        // Load types match the prototype taxonomy.
        func loadType(_ name: String) -> LoadType? {
            catalog.exercises.first { $0.name == name }?.loadType
        }
        #expect(loadType("Pull-Up") == .bodyweightPlus)
        #expect(loadType("Dip") == .bodyweightPlus)
        #expect(loadType("Assisted Pull-Up") == .assisted)
        #expect(loadType("Seated Chest Press") == .weighted)
    }

    // MARK: Reconciliation

    /// An empty store seeds fully: every catalog row lands, marked seeded,
    /// keyed by its fixed catalog UUID, and the version is recorded.
    @Test func emptyStoreSeedsFully() throws {
        let catalog = try SeedCatalog.bundled()
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try CatalogSeeder.reconcile(catalog, in: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let models = try context.fetch(FetchDescriptor<EquipmentModel>())
        #expect(exercises.count == catalog.exercises.count)
        #expect(models.count == catalog.equipmentModels.count)
        let allExercisesSeeded = exercises.allSatisfy(\.isSeeded)
        let allModelsSeeded = models.allSatisfy(\.isSeeded)
        #expect(allExercisesSeeded)
        #expect(allModelsSeeded)
        #expect(Set(exercises.map(\.id)) == Set(catalog.exercises.map(\.id)))
        #expect(Set(models.map(\.id)) == Set(catalog.equipmentModels.map(\.id)))
        let version = try storedVersion(in: context)
        #expect(version == catalog.version)

        // Spot-check one row's fields carried over.
        let pullUp = try #require(exercises.first { $0.name == "Pull-Up" })
        #expect(pullUp.loadType == .bodyweightPlus)
        #expect(pullUp.equipmentTypeTags == [.bodyweight])
    }

    /// Rerunning the identical catalog is a no-op: row counts stable, no
    /// duplicates, version unchanged.
    @Test func identicalRerunChangesNothing() throws {
        let catalog = try SeedCatalog.bundled()
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try CatalogSeeder.reconcile(catalog, in: context)
        let before = try counts(in: context)

        try CatalogSeeder.reconcile(catalog, in: context)
        try CatalogSeeder.reconcile(catalog, in: context)

        let after = try counts(in: context)
        #expect(after.exercises == before.exercises)
        #expect(after.models == before.models)
        let version = try storedVersion(in: context)
        #expect(version == catalog.version)
    }

    /// A partial store (some seeded rows deleted) heals on the next run at the
    /// same version — missing rows are reinserted, survivors not duplicated.
    @Test func partialStoreHeals() throws {
        let catalog = try SeedCatalog.bundled()
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalog, in: context)

        // Blow away a few seeded rows to simulate a damaged/partial store.
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let models = try context.fetch(FetchDescriptor<EquipmentModel>())
        for exercise in exercises.prefix(3) { context.delete(exercise) }
        for model in models.prefix(5) { context.delete(model) }
        try context.save()
        let damaged = try counts(in: context)
        #expect(damaged.exercises == catalog.exercises.count - 3)
        #expect(damaged.models == catalog.equipmentModels.count - 5)

        try CatalogSeeder.reconcile(catalog, in: context)

        let healed = try counts(in: context)
        #expect(healed.exercises == catalog.exercises.count)
        #expect(healed.models == catalog.equipmentModels.count)
        let healedIDs = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.id))
        #expect(healedIDs == Set(catalog.exercises.map(\.id)))
    }

    /// A newer catalog version adds new rows and updates allowlisted fields
    /// (name, links, metadata) of existing rows in place — same catalog UUIDs,
    /// no duplicates. Local edits to seeded rows are overwritten (seeded rows
    /// are not user-editable, D24).
    @Test func versionUpgradeUpdatesWithoutDuplicating() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalogV1(), in: context)
        let v1Counts = try counts(in: context)
        let v1Version = try storedVersion(in: context)
        #expect(v1Counts == (2, 1))
        #expect(v1Version == 1)

        // Simulate an out-of-band edit of a seeded row; v2 must restore it.
        let tampered = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseAID })).first)
        tampered.name = "My Renamed Press"
        try context.save()

        try CatalogSeeder.reconcile(catalogV2(), in: context)

        let v2Counts = try counts(in: context)
        let v2Version = try storedVersion(in: context)
        #expect(v2Counts == (3, 2))
        #expect(v2Version == 2)

        let updated = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseAID })).first)
        #expect(updated.name == "Seated Chest Press")
        #expect(updated.equipmentTypeTags == [.machine, .cable])

        let updatedModel = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.id == modelXID })).first)
        #expect(updatedModel.exerciseIDs == [exerciseAID, exerciseCID])

        // Rerunning v2 is again a no-op; an older catalog never downgrades.
        try CatalogSeeder.reconcile(catalogV2(), in: context)
        try CatalogSeeder.reconcile(catalogV1(), in: context)
        let staleCounts = try counts(in: context)
        let staleVersion = try storedVersion(in: context)
        #expect(staleCounts == (3, 2))
        #expect(staleVersion == 2)
        let afterStale = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseAID })).first)
        #expect(afterStale.name == "Seated Chest Press")
    }

    /// User-created rows (isSeeded == false) are invisible to reconciliation:
    /// reruns and version upgrades leave them byte-for-byte alone.
    @Test func userCreatedRowsUntouched() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalogV1(), in: context)

        // User rows — one deliberately shadowing a seeded exercise's name.
        let userExerciseID = UUID()
        let userModelID = UUID()
        context.insert(Exercise(
            id: userExerciseID, name: "Chest Press", loadType: .weighted,
            equipmentTypeTags: [.dumbbell], muscleGroup: "Custom",
            isSeeded: false))
        context.insert(EquipmentModel(
            id: userModelID, manufacturer: "Homemade", modelName: "Garage Rack",
            exerciseIDs: [userExerciseID], isSeeded: false))
        try context.save()

        try CatalogSeeder.reconcile(catalogV1(), in: context)
        try CatalogSeeder.reconcile(catalogV2(), in: context)

        let finalCounts = try counts(in: context)
        #expect(finalCounts == (3 + 1, 2 + 1))

        let userExercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == userExerciseID })).first)
        #expect(userExercise.name == "Chest Press")
        #expect(userExercise.equipmentTypeTags == [.dumbbell])
        #expect(userExercise.muscleGroup == "Custom")
        #expect(userExercise.isSeeded == false)

        let userModel = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.id == userModelID })).first)
        #expect(userModel.manufacturer == "Homemade")
        #expect(userModel.modelName == "Garage Rack")
        #expect(userModel.exerciseIDs == [userExerciseID])
        #expect(userModel.isSeeded == false)
    }
}
