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

    // MARK: Bundled catalog

    /// The shipped catalog meets the ticket's content bar and only references
    /// exercises it also defines. Counts are lower bounds: ticket 20 grew the
    /// catalog to 74 exercises / 1887 models across 23 manufacturers, and a
    /// later expansion may only add.
    @Test func bundledFixtureMeetsContentBar() throws {
        let catalog = try SeedCatalog.bundled()

        #expect(catalog.version >= 2)
        #expect(catalog.exercises.count >= 74)
        #expect(catalog.equipmentModels.count >= 1887)
        #expect(Set(catalog.equipmentModels.map(\.manufacturer)).count >= 23)

        // A model name is the identity history and records are keyed on (D23),
        // so no manufacturer may list the same model twice.
        let identities = catalog.equipmentModels.map { "\($0.manufacturer)|\($0.modelName)" }
        #expect(Set(identities).count == identities.count)

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
        #expect(loadType("Assisted Dip") == .assisted)
        #expect(loadType("Hip Thrust") == .weighted)
    }

    /// Every seeded exercise carries a muscle group from one shared vocabulary —
    /// ticket 21 groups the exercise picker by it, and one machine's "Legs"
    /// against another's "Quads" would split that grouping.
    @Test func everySeededExerciseHasAKnownMuscleGroup() throws {
        let catalog = try SeedCatalog.bundled()
        let vocabulary: Set<String> = [
            "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Neck",
            "Quads", "Hamstrings", "Glutes", "Hips", "Calves", "Core", "Full Body",
        ]
        for exercise in catalog.exercises {
            let group = exercise.muscleGroup ?? ""
            #expect(vocabulary.contains(group),
                    "\(exercise.name) has muscle group \"\(group)\"")
        }
    }

    // MARK: Catalog UUID stability (D24)

    /// The rows shipped in catalog version 1, pinned by id. Every logged set,
    /// record and template reference resolves through these UUIDs: if one moves
    /// or is reused for a different row, that history is orphaned or, worse,
    /// silently reattributed to another machine.
    private let version1ExerciseIDs: [(String, String)] = [
        ("5EED0001-0000-4000-8000-000000000001", "Seated Chest Press"),
        ("5EED0001-0000-4000-8000-000000000002", "Lat Pulldown"),
        ("5EED0001-0000-4000-8000-000000000003", "Seated Row"),
        ("5EED0001-0000-4000-8000-000000000004", "Leg Press"),
        ("5EED0001-0000-4000-8000-000000000005", "Machine Shoulder Press"),
        ("5EED0001-0000-4000-8000-000000000006", "Bench Press"),
        ("5EED0001-0000-4000-8000-000000000007", "Squat"),
        ("5EED0001-0000-4000-8000-000000000008", "Pull-Up"),
        ("5EED0001-0000-4000-8000-000000000009", "Assisted Pull-Up"),
        ("5EED0001-0000-4000-8000-000000000010", "Dumbbell Curl"),
        ("5EED0001-0000-4000-8000-000000000011", "Triceps Pushdown"),
        ("5EED0001-0000-4000-8000-000000000012", "Dip"),
    ]

    private let version1ModelIDs: [(String, String, String)] = [
        ("5EED0002-0000-4000-8000-000000000001", "Life Fitness", "Insignia Series Chest Press"),
        ("5EED0002-0000-4000-8000-000000000002", "Life Fitness", "Signature Series Shoulder Press"),
        ("5EED0002-0000-4000-8000-000000000003", "Life Fitness", "Signature Series Lat Pulldown"),
        ("5EED0002-0000-4000-8000-000000000004", "Life Fitness",
         "Signature Series Cable Motion Dual Adjustable Pulley"),
        ("5EED0002-0000-4000-8000-000000000005", "Hammer Strength", "MTS Iso-Lateral Chest Press"),
        ("5EED0002-0000-4000-8000-000000000006", "Hammer Strength", "Plate-Loaded Seated Row"),
        ("5EED0002-0000-4000-8000-000000000007", "Hammer Strength", "Select Leg Press"),
        ("5EED0002-0000-4000-8000-000000000008", "Technogym", "Selection 900 Lat Pulldown"),
        ("5EED0002-0000-4000-8000-000000000009", "Technogym", "Selection 900 Chest Press"),
        ("5EED0002-0000-4000-8000-000000000010", "Technogym", "Cable Stations Dual Adjustable Pulley"),
        ("5EED0002-0000-4000-8000-000000000011", "Precor", "Vitality Series Seated Row"),
        ("5EED0002-0000-4000-8000-000000000012", "Precor", "Resolute Series Leg Press"),
        ("5EED0002-0000-4000-8000-000000000013", "Precor", "Discovery Series Shoulder Press"),
        ("5EED0002-0000-4000-8000-000000000014", "Cybex", "Eagle NX Leg Press"),
        ("5EED0002-0000-4000-8000-000000000015", "Cybex", "Eagle NX Chest Press"),
        ("5EED0002-0000-4000-8000-000000000016", "Cybex", "Bravo Functional Trainer"),
        ("5EED0002-0000-4000-8000-000000000017", "Matrix", "Ultra Series Assisted Chin/Dip"),
        ("5EED0002-0000-4000-8000-000000000018", "Matrix", "Versa Series Chest Press"),
        ("5EED0002-0000-4000-8000-000000000019", "Matrix", "Aura Series Seated Row"),
        ("5EED0002-0000-4000-8000-000000000020", "Matrix", "Magnum Smith Machine"),
        ("5EED0002-0000-4000-8000-000000000021", "Nautilus", "Impact Strength Shoulder Press"),
        ("5EED0002-0000-4000-8000-000000000022", "Nautilus", "Impact Strength Leg Press"),
        ("5EED0002-0000-4000-8000-000000000023", "Hoist", "ROC-IT Lat Pulldown"),
        ("5EED0002-0000-4000-8000-000000000024", "Hoist", "Mi7 Functional Trainer"),
    ]

    /// Every id shipped in catalog version 1 is still in the bundled catalog,
    /// on the same row, and no later row has been given one of them.
    @Test func version1CatalogIDsAreUnchanged() throws {
        let catalog = try SeedCatalog.bundled()
        let exercisesByID = Dictionary(uniqueKeysWithValues: catalog.exercises.map { ($0.id, $0) })
        let modelsByID = Dictionary(
            uniqueKeysWithValues: catalog.equipmentModels.map { ($0.id, $0) })

        for (rawID, name) in version1ExerciseIDs {
            let id = try #require(UUID(uuidString: rawID))
            let exercise = try #require(exercisesByID[id], "exercise id \(rawID) is gone")
            #expect(exercise.name == name, "exercise id \(rawID) now names \(exercise.name)")
        }
        for (rawID, manufacturer, modelName) in version1ModelIDs {
            let id = try #require(UUID(uuidString: rawID))
            let model = try #require(modelsByID[id], "model id \(rawID) is gone")
            #expect(model.manufacturer == manufacturer)
            #expect(model.modelName == modelName, "model id \(rawID) now names \(model.modelName)")
        }

        // Ids come from two dense sequences, so the version-1 range is fully
        // spoken for: every id in it is used, exactly once, by the row above.
        // (Row *order* in the file is free — models are grouped by manufacturer,
        // so the version-1 models are scattered through the list.)
        #expect(Set(catalog.exercises.map(\.id)).intersection(
            version1ExerciseIDs.compactMap { UUID(uuidString: $0.0) }).count == 12)
        #expect(Set(catalog.equipmentModels.map(\.id)).intersection(
            version1ModelIDs.compactMap { UUID(uuidString: $0.0) }).count == 24)
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

    /// The real ticket-20 upgrade: a store seeded from the version-1 catalog is
    /// reconciled against the shipped one. New models appear, the version-1 ids
    /// keep their identity, and the user's own rows — including an exercise the
    /// user linked to a seeded model (D27) — survive untouched.
    @Test func upgradeFromVersion1CatalogAddsModelsAndKeepsUserData() throws {
        let shipped = try SeedCatalog.bundled()
        let legacyExerciseIDs = Set(version1ExerciseIDs.compactMap { UUID(uuidString: $0.0) })
        let legacyModelIDs = Set(version1ModelIDs.compactMap { UUID(uuidString: $0.0) })
        let version1 = SeedCatalog(
            version: 1,
            exercises: shipped.exercises.filter { legacyExerciseIDs.contains($0.id) },
            equipmentModels: shipped.equipmentModels
                .filter { legacyModelIDs.contains($0.id) }
                .map {
                    SeedEquipmentModel(
                        id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName,
                        exerciseIDs: $0.exerciseIDs.filter(legacyExerciseIDs.contains))
                })
        #expect(version1.exercises.count == 12)
        #expect(version1.equipmentModels.count == 24)

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(version1, in: context)
        #expect(try counts(in: context) == (12, 24))
        #expect(try storedVersion(in: context) == 1)

        // A user-created exercise, a user-created model, and the ticket-19 case:
        // that exercise linked to a *seeded* model.
        let userExerciseID = UUID()
        let userModelID = UUID()
        let seededModelID = try #require(UUID(uuidString: version1ModelIDs[0].0))
        context.insert(Exercise(
            id: userExerciseID, name: "Landmine Press", loadType: .weighted,
            equipmentTypeTags: [.barbell], muscleGroup: "Shoulders", isSeeded: false))
        context.insert(EquipmentModel(
            id: userModelID, manufacturer: "Homemade", modelName: "Garage Rack",
            exerciseIDs: [userExerciseID], isSeeded: false))
        let seededModel = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(
                predicate: #Predicate { $0.id == seededModelID })).first)
        seededModel.exerciseIDs.append(userExerciseID)
        try context.save()

        try CatalogSeeder.reconcile(shipped, in: context)

        // Everything in the shipped catalog is present, plus the two user rows.
        let after = try counts(in: context)
        #expect(after.exercises == shipped.exercises.count + 1)
        #expect(after.models == shipped.equipmentModels.count + 1)
        #expect(try storedVersion(in: context) == shipped.version)

        // Version-1 ids still resolve to the same machines.
        let models = try context.fetch(FetchDescriptor<EquipmentModel>())
        let modelsByID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        for (rawID, manufacturer, modelName) in version1ModelIDs {
            let id = try #require(UUID(uuidString: rawID))
            let row = try #require(modelsByID[id])
            #expect(row.manufacturer == manufacturer)
            #expect(row.modelName == modelName)
            #expect(row.isSeeded)
        }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        for (rawID, name) in version1ExerciseIDs {
            let id = try #require(UUID(uuidString: rawID))
            let row = try #require(exercisesByID[id])
            #expect(row.name == name)
        }

        // New models landed, exactly once each.
        #expect(Set(models.filter(\.isSeeded).map(\.id))
                == Set(shipped.equipmentModels.map(\.id)))
        #expect(models.filter { $0.manufacturer == "Gym80" }.count > 100)

        // User rows untouched, and the user's link to a seeded model survives
        // the seeded-field rewrite (D27).
        let userExercise = try #require(exercisesByID[userExerciseID])
        #expect(userExercise.name == "Landmine Press")
        #expect(userExercise.isSeeded == false)
        let userModel = try #require(modelsByID[userModelID])
        #expect(userModel.modelName == "Garage Rack")
        #expect(userModel.exerciseIDs == [userExerciseID])
        #expect(userModel.isSeeded == false)
        let rewritten = try #require(modelsByID[seededModelID])
        #expect(rewritten.exerciseIDs.contains(userExerciseID))
        #expect(rewritten.exerciseIDs.last == userExerciseID)
    }

    /// The reconciler runs on every launch against ~1900 rows. Once the store is
    /// seeded at the current version there is nothing to do, and the fast path
    /// must make that nothing cheap rather than diffing every row.
    @Test func reconcileIsCheapOnceSeeded() throws {
        let catalog = try SeedCatalog.bundled()
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalog, in: context)

        let start = Date()
        for _ in 0..<10 { try CatalogSeeder.reconcile(catalog, in: context) }
        let perRun = Date().timeIntervalSince(start) / 10

        #expect(perRun < 0.25, "steady-state reconcile took \(perRun)s per launch")
        #expect(try counts(in: context)
                == (catalog.exercises.count, catalog.equipmentModels.count))
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
