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
        #expect(catalog.exercises.count >= 76)
        // 1877 = ticket 20's 1887 minus the ten duplicate identities version 4
        // merged onto their older UUID. The catalog may only shrink through a
        // declared merge (RENAMED_MODELS in the generator).
        #expect(catalog.equipmentModels.count >= 1877)
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

    /// (id, manufacturer, the name shipped in version 1, the name today).
    ///
    /// The **id** is the invariant: every logged set, record and template
    /// reference resolves through it. The **name** is an allowlisted mutable
    /// field (D24) — version 4 merged ten rows that turned out to describe a
    /// machine the researched catalog also listed, keeping the older id and
    /// taking the researched name, and corrected three names the research could
    /// verify verbatim (codex-review-4). Both columns are kept so a future
    /// rename is a deliberate edit here, not a silent drift.
    private let version1ModelIDs: [(String, String, String, String)] = [
        ("5EED0002-0000-4000-8000-000000000001", "Life Fitness",
         "Insignia Series Chest Press", "Insignia Series Chest Press"),
        ("5EED0002-0000-4000-8000-000000000002", "Life Fitness",
         "Signature Series Shoulder Press", "Signature Series Shoulder Press"),
        ("5EED0002-0000-4000-8000-000000000003", "Life Fitness",
         "Signature Series Lat Pulldown", "Signature Series Pulldown"),
        ("5EED0002-0000-4000-8000-000000000004", "Life Fitness",
         "Signature Series Cable Motion Dual Adjustable Pulley",
         "Signature Series Dual Adjustable Pulley"),
        ("5EED0002-0000-4000-8000-000000000005", "Hammer Strength",
         "MTS Iso-Lateral Chest Press", "MTS Iso-Lateral Chest Press"),
        ("5EED0002-0000-4000-8000-000000000006", "Hammer Strength",
         "Plate-Loaded Seated Row", "Plate-Loaded Seated Row"),
        ("5EED0002-0000-4000-8000-000000000007", "Hammer Strength",
         "Select Leg Press", "Select Seated Leg Press"),
        ("5EED0002-0000-4000-8000-000000000008", "Technogym",
         "Selection 900 Lat Pulldown", "Selection 900 Lat Pulldown"),
        ("5EED0002-0000-4000-8000-000000000009", "Technogym",
         "Selection 900 Chest Press", "Selection 900 Chest Press"),
        ("5EED0002-0000-4000-8000-000000000010", "Technogym",
         "Cable Stations Dual Adjustable Pulley", "Cable Stations Dual Adjustable Pulley"),
        ("5EED0002-0000-4000-8000-000000000011", "Precor",
         "Vitality Series Seated Row", "Vitality Seated Row (VSL019BP)"),
        ("5EED0002-0000-4000-8000-000000000012", "Precor",
         "Resolute Series Leg Press", "Resolute Leg Press (RSL0602)"),
        ("5EED0002-0000-4000-8000-000000000013", "Precor",
         "Discovery Series Shoulder Press",
         "Discovery Plate Loaded Shoulder Press (DPL0550)"),
        ("5EED0002-0000-4000-8000-000000000014", "Cybex",
         "Eagle NX Leg Press", "Eagle NX Leg Press"),
        ("5EED0002-0000-4000-8000-000000000015", "Cybex",
         "Eagle NX Chest Press", "Eagle NX Chest Press"),
        ("5EED0002-0000-4000-8000-000000000016", "Cybex",
         "Bravo Functional Trainer", "Bravo Functional Trainer"),
        ("5EED0002-0000-4000-8000-000000000017", "Matrix",
         "Ultra Series Assisted Chin/Dip", "Ultra Series Assisted Chin/Dip"),
        ("5EED0002-0000-4000-8000-000000000018", "Matrix",
         "Versa Series Chest Press", "VS-S13 Converging Chest Press"),
        ("5EED0002-0000-4000-8000-000000000019", "Matrix",
         "Aura Series Seated Row", "G3-S31 Seated Row"),
        ("5EED0002-0000-4000-8000-000000000020", "Matrix",
         "Magnum Smith Machine", "MG-PL62 Smith Machine"),
        ("5EED0002-0000-4000-8000-000000000021", "Nautilus",
         "Impact Strength Shoulder Press", "Impact Shoulder Press"),
        ("5EED0002-0000-4000-8000-000000000022", "Nautilus",
         "Impact Strength Leg Press", "Impact Seated Leg Press"),
        ("5EED0002-0000-4000-8000-000000000023", "Hoist",
         "ROC-IT Lat Pulldown", "Lat Pulldown RS-2201"),
        ("5EED0002-0000-4000-8000-000000000024", "Hoist",
         "Mi7 Functional Trainer", "Mi7 Functional Training System Mi-7-MB"),
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
        for (rawID, manufacturer, version1Name, currentName) in version1ModelIDs {
            let id = try #require(UUID(uuidString: rawID))
            let model = try #require(modelsByID[id], "model id \(rawID) is gone")
            #expect(model.manufacturer == manufacturer)
            #expect(model.modelName == currentName,
                    "model id \(rawID) (v1: \(version1Name)) now names \(model.modelName)")
        }

        // A merged-away duplicate's id is retired, never reissued: the machine
        // it named is reachable only through the surviving version-1 id.
        let retired = [169, 225, 239, 255, 376, 389, 634, 651, 697, 1404].map {
            String(format: "5EED0002-0000-4000-8000-%012d", $0)
        }
        for rawID in retired {
            let id = try #require(UUID(uuidString: rawID))
            #expect(modelsByID[id] == nil, "retired model id \(rawID) is back")
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

    /// Ticket 21's `equipmentType` is an allowlisted seeded field: a store
    /// seeded before it existed picks it up on the version bump, and a
    /// user-created model is left with the type the *user* chose (D24).
    @Test func equipmentTypeArrivesWithTheVersionBump() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalogV1(), in: context)

        let beforeUpgrade = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.id == modelXID })).first)
        #expect(beforeUpgrade.equipmentType == nil)

        let userModel = EquipmentModel(
            manufacturer: "Acme", modelName: "Garage Press",
            exerciseIDs: [exerciseAID], equipmentType: .rackOrSmith, isSeeded: false)
        context.insert(userModel)
        try context.save()

        var typed = catalogV2()
        typed.equipmentModels = typed.equipmentModels.map { model in
            var copy = model
            copy.equipmentType = .selectorized
            return copy
        }
        try CatalogSeeder.reconcile(typed, in: context)

        let upgraded = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.id == modelXID })).first)
        #expect(upgraded.equipmentType == .selectorized)
        #expect(userModel.equipmentType == .rackOrSmith)
    }

    /// No two catalog rows may describe the same real machine. D23 keys
    /// history, records and the same-model-elsewhere layer on the model UUID,
    /// so a duplicated identity silently splits a user's own history the day
    /// they pick the other row. Byte-identical names are not the failure mode —
    /// the version-2 catalog shipped "Impact Strength Shoulder Press" *and*
    /// "Impact Shoulder Press", "Aura Series Seated Row" *and* "G3-S31 Seated
    /// Row" — so this compares identities with line words and model codes
    /// removed. `scripts/generate_seed_catalog.py` enforces a stricter version
    /// of the same rule at generation time (codex-review-4).
    @Test func bundledCatalogHasNoNearDuplicateIdentities() throws {
        let catalog = try SeedCatalog.bundled()
        var byManufacturer: [String: [(name: String, identity: ModelIdentity)]] = [:]
        for model in catalog.equipmentModels {
            byManufacturer[model.manufacturer, default: []]
                .append((model.modelName, ModelIdentity(model.manufacturer, model.modelName)))
        }

        for (manufacturer, rows) in byManufacturer {
            for outer in rows.indices {
                for inner in rows.indices where inner > outer {
                    let a = rows[outer], b = rows[inner]
                    // A manufacturer's own model code is an identity: rows
                    // carrying different codes are different products however
                    // alike they read. Only an under-specified row (no code)
                    // can be an alias of another row.
                    guard a.identity.codes.isEmpty || b.identity.codes.isEmpty else { continue }
                    #expect(a.identity.words != b.identity.words,
                            """
                            \(manufacturer): "\(a.name)" and "\(b.name)" are one \
                            identity. Merge them onto the older UUID in \
                            scripts/generate_seed_catalog.py (RENAMED_MODELS).
                            """)
                }
            }
        }
    }

    /// A model name split into its model codes and its identity words.
    /// Mirrors `identity_tokens` in scripts/generate_seed_catalog.py.
    private struct ModelIdentity {
        let codes: Set<String>
        let words: Set<String>

        /// Words that name a *line*, never a machine, and that sources write
        /// inconsistently ("Impact Strength Shoulder Press" / "Impact Shoulder
        /// Press").
        private static let noise: Set<String> = ["series", "line", "strength", "the"]
        /// Matrix writes its lines as a code prefix (research-confirmed).
        private static let matrixLines = [
            "g3": "aura", "g7": "ultra", "vs": "versa",
            "mg": "magnum", "go": "go", "vy": "varsity", "g1": "varsity",
        ]

        init(_ manufacturer: String, _ modelName: String) {
            var codes: Set<String> = [], words: Set<String> = []
            let separators = CharacterSet(charactersIn: " /(),|·")
            for raw in modelName.components(separatedBy: separators) {
                let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: "-–.:"))
                    .lowercased()
                guard !token.isEmpty else { continue }
                let head = token.components(separatedBy: "-")[0]
                if manufacturer == "Matrix", token.contains("-"),
                   let line = Self.matrixLines[head] {
                    words.insert(line)
                    codes.insert(token)
                } else if token.contains(where: \.isNumber) {
                    codes.insert(token)
                } else {
                    for word in token.components(separatedBy: "-")
                    where !word.isEmpty && !Self.noise.contains(word) {
                        words.insert(word)
                    }
                }
            }
            self.codes = codes
            self.words = words
        }
    }

    /// Load type is a property of the machine's mechanism, and records are
    /// computed from it (D20): a decline ab bench or a Roman chair logged under
    /// the *weighted* machine exercise gets weight×reps volume and a Brzycki
    /// e1RM for a movement carrying no external load. Version 4 split
    /// "Bench Crunch" and "Hyperextension" off for exactly this.
    @Test func bodyweightStationsLinkBodyweightExercises() throws {
        let catalog = try SeedCatalog.bundled()
        let byID = Dictionary(uniqueKeysWithValues: catalog.exercises.map { ($0.id, $0) })

        // The one row whose mechanism the research did not establish: Rogue's
        // Floor Glute sits in a bodyweight-typed section but is loaded.
        let unestablished: Set<String> = ["Floor Glute"]

        for model in catalog.equipmentModels
        where model.equipmentType == .bodyweight && !unestablished.contains(model.modelName) {
            for id in model.exerciseIDs {
                let exercise = try #require(byID[id])
                #expect(exercise.loadType != .weighted,
                        """
                        \(model.manufacturer) \(model.modelName) links weighted \
                        \(exercise.name) — a bodyweight station needs a \
                        bodyweight movement (D20)
                        """)
            }
        }

        // And the split actually shipped, on enough rows to matter.
        for name in ["Bench Crunch", "Hyperextension"] {
            let exercise = try #require(catalog.exercises.first { $0.name == name })
            #expect(exercise.loadType == .bodyweightPlus)
            let linked = catalog.equipmentModels.filter { $0.exerciseIDs.contains(exercise.id) }
            #expect(linked.count >= 8, "\(name) is linked by only \(linked.count) models")
        }
    }

    /// The shipped catalog classifies effectively every model, and never with
    /// a value the app cannot render.
    @Test func shippedModelsCarryAnEquipmentType() throws {
        let catalog = try SeedCatalog.bundled()
        let untyped = catalog.equipmentModels.filter { $0.equipmentType == nil }
        #expect(untyped.count < 20, "\(untyped.count) models have no equipment type")
        for type in EquipmentCategory.allCases {
            #expect(catalog.equipmentModels.contains { $0.equipmentType == type },
                    "no shipped model is \(type.label)")
        }
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
                .map { model in
                    SeedEquipmentModel(
                        id: model.id, manufacturer: model.manufacturer,
                        // The name as version 1 shipped it — this store is the
                        // phone's, seeded before the merges and renames.
                        modelName: version1ModelIDs
                            .first { UUID(uuidString: $0.0) == model.id }?.2
                            ?? model.modelName,
                        exerciseIDs: model.exerciseIDs.filter(legacyExerciseIDs.contains))
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
        for (rawID, manufacturer, _version1Name, currentName) in version1ModelIDs {
            let id = try #require(UUID(uuidString: rawID))
            let row = try #require(modelsByID[id])
            #expect(row.manufacturer == manufacturer)
            // Renamed in place where version 4 merged a duplicate onto this id:
            // the machine keeps the UUID its sets are keyed on (D23) and gains
            // the researched name (D24 allowlist).
            #expect(row.modelName == currentName)
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

    /// The fast path must not be foolable by a store whose *count* is right.
    /// Delete one seeded model and insert an unrelated `isSeeded` row: the old
    /// count check saw 1877 == 1877 and returned, leaving the deleted machine
    /// missing from the catalog forever (codex-review-4). Reconciliation is
    /// keyed on ids, so the check has to be too.
    @Test func countPreservingCorruptionStillHeals() throws {
        let catalog = try SeedCatalog.bundled()
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalog, in: context)

        let victim = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(
                predicate: #Predicate { $0.isSeeded })).first)
        let victimID = victim.id
        let victimName = victim.modelName
        context.delete(victim)
        // An impostor carrying the seeded flag but no catalog identity — what a
        // half-finished sync or a restored backup can leave behind.
        context.insert(EquipmentModel(
            id: UUID(), manufacturer: "Ghost", modelName: "Impostor",
            exerciseIDs: [catalog.exercises[0].id], isSeeded: true))
        try context.save()

        // The trap: counts match, so a count-based fast path sees nothing wrong.
        let seededCount = try context.fetchCount(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.isSeeded }))
        #expect(seededCount == catalog.equipmentModels.count)

        try CatalogSeeder.reconcile(catalog, in: context)

        let restored = try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.id == victimID }))
        #expect(restored.count == 1, "\(victimName) was not restored")
        #expect(restored.first?.modelName == victimName)
        // Rows the catalog no longer defines are never deleted (D24): a
        // historical reference must keep resolving.
        #expect(try context.fetchCount(FetchDescriptor<EquipmentModel>(
            predicate: #Predicate { $0.modelName == "Impostor" })) == 1)
    }

    /// Same version, different content — a catalog edited without a bump, or a
    /// rebuilt bundle. The version comparison alone called that a no-op and left
    /// the store on the old strings; the content fingerprint catches it.
    @Test func sameVersionContentChangeIsApplied() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalogV1(), in: context)

        var edited = catalogV1()          // same version number
        edited.exercises[0].name = "Chest Press (Converging)"
        edited.equipmentModels[0].modelName = "Insignia Series Chest Press"
        try CatalogSeeder.reconcile(edited, in: context)

        let exercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseAID })).first)
        #expect(exercise.name == "Chest Press (Converging)")
        let model = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.id == modelXID })).first)
        #expect(model.modelName == "Insignia Series Chest Press")
        #expect(try storedVersion(in: context) == 1)
    }

    /// The fingerprint has to cover everything reconciliation writes and be
    /// stable across processes (it is persisted between launches).
    @Test func fingerprintCoversEveryReconciledField() throws {
        let base = catalogV2()
        #expect(base.fingerprint == catalogV2().fingerprint)

        func mutated(_ change: (inout SeedCatalog) -> Void) -> String {
            var copy = catalogV2()
            change(&copy)
            return copy.fingerprint
        }
        #expect(mutated { $0.version += 1 } != base.fingerprint)
        #expect(mutated { $0.exercises[0].name += "!" } != base.fingerprint)
        #expect(mutated { $0.exercises[0].loadType = .assisted } != base.fingerprint)
        #expect(mutated { $0.exercises[0].muscleGroup = "Neck" } != base.fingerprint)
        #expect(mutated { $0.exercises[0].equipmentTypeTags = [.cable] } != base.fingerprint)
        #expect(mutated { $0.equipmentModels[0].manufacturer += "!" } != base.fingerprint)
        #expect(mutated { $0.equipmentModels[0].modelName += "!" } != base.fingerprint)
        #expect(mutated { $0.equipmentModels[0].equipmentType = .cable } != base.fingerprint)
        #expect(mutated { $0.equipmentModels[0].exerciseIDs.reverse() } != base.fingerprint)
        #expect(mutated { $0.equipmentModels.removeLast() } != base.fingerprint)

        // Field boundaries are hashed, so moving a character between adjacent
        // fields is not the same catalog.
        var shifted = catalogV2()
        shifted.equipmentModels[0].manufacturer = "Life Fitnes"
        shifted.equipmentModels[0].modelName = "sInsignia Chest Press"
        #expect(shifted.fingerprint != base.fingerprint)
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
        print("steady-state reconcile: \(String(format: "%.2f", perRun * 1000))ms per launch")

        // The fast path now proves the store still holds exactly the catalog's
        // seeded rows, and that the catalog content is the content last applied
        // (codex-review-4) — ~9 ms in a Debug simulator (catalog fingerprint
        // ~2.7 ms, four aggregate queries ~6 ms) against ~60–100 ms for the
        // per-field diff it replaces. The bound is loose enough not to be a
        // flaky timing test on a busy machine.
        #expect(perRun < 0.05, "steady-state reconcile took \(perRun)s per launch")
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
