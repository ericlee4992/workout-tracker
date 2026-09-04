import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Milestone 9, ticket 04 — dumbbell movements as exercises of their own, and
/// the one-time move of dumbbell-tagged history onto them.
struct DumbbellExercisesTests {

    @MainActor
    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private final class SilentNotifications: RestNotificationScheduling {
        func requestAuthorization() {}
        func schedule(at date: Date) {}
        func schedule(at date: Date, title: String, body: String) {}
        func cancel() {}
    }

    private func exercise(named name: String, in ctx: ModelContext) throws -> Exercise {
        try #require(try ctx.fetch(FetchDescriptor<Exercise>()).first { $0.name == name }, "catalog should hold \(name)")
    }

    /// A finished workout with one entry under `exercise`, tagged `tag`,
    /// snapshot frozen, `sets` completed working sets.
    @discardableResult
    private func logged(
        _ exercise: Exercise, tag: EquipmentTag?, machine: MachineInstance? = nil,
        sets: Int = 2, finished: Bool = true, daysAgo: Int = 3, in ctx: ModelContext
    ) -> ExerciseEntry {
        let start = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        let workout = Workout(startedAt: start, finishedAt: finished ? start.addingTimeInterval(3_600) : nil)
        ctx.insert(workout)
        let entry = ExerciseEntry(
            order: 0, freeWeightTag: machine == nil ? tag : nil, workout: workout, exercise: exercise,
            machine: machine, snapshotCapturedAt: start,
            snapshotExerciseID: exercise.id, snapshotMachineID: machine?.id,
            snapshotLoadType: exercise.loadType, snapshotFreeWeightTag: machine == nil ? tag : nil,
            snapshotExerciseName: exercise.name, snapshotMachineLabel: machine?.label)
        ctx.insert(entry)
        for i in 0..<sets {
            let set = SetRecord(order: i, type: .working, entry: entry)
            set.reps = 8; set.weightValue = 30; set.weightUnit = .kg; set.normalizedKg = 30
            set.completedAt = start.addingTimeInterval(Double(60 * (i + 1)))
            ctx.insert(set)
        }
        return entry
    }

    // MARK: The mapping is sound against the shipped catalog

    @Test func everyPairPointsAtRealCatalogRowsWithTheRightTags() throws {
        let catalog = try SeedCatalog.bundled()
        let byID = Dictionary(uniqueKeysWithValues: catalog.exercises.map { ($0.id, $0) })
        for pair in DumbbellCounterparts.pairs {
            let source = try #require(byID[pair.source], "source \(pair.source) must exist")
            let target = try #require(byID[pair.target], "target \(pair.target) must exist")
            #expect(target.equipmentTypeTags == [.dumbbell], "\(target.name) must be a dumbbell exercise")
            #expect(!source.equipmentTypeTags.contains(.dumbbell), "\(source.name) is the non-dumbbell row")
            #expect(target.loadType == source.loadType, "a move must not change how sets rank")
        }
    }

    @Test func noDuplicateTargetsOrSources() {
        let targets = DumbbellCounterparts.pairs.map(\.target)
        let sources = DumbbellCounterparts.pairs.map(\.source)
        #expect(Set(targets).count == targets.count)
        #expect(Set(sources).count == sources.count)
        #expect(Set(targets).isDisjoint(with: sources), "a target must never itself be a source, or the move could chain")
    }

    @Test func catalogIsVersionFiveWithTheFourteenDumbbellRows() throws {
        let catalog = try SeedCatalog.bundled()
        #expect(catalog.version == 5)
        let dumbbell = catalog.exercises.filter { $0.equipmentTypeTags == [.dumbbell] }
        #expect(dumbbell.count == 15, "Dumbbell Curl plus the fourteen new rows, got \(dumbbell.map(\.name))")
        #expect(catalog.exercises.contains { $0.name == "Dumbbell Bench Press" })
    }

    // MARK: The move

    @Test @MainActor func movesDumbbellTaggedHistoryAndOnlyThat() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let bench = try exercise(named: "Bench Press", in: ctx)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        let chestPress = try exercise(named: "Seated Chest Press", in: ctx)
        let deadlift = try exercise(named: "Deadlift", in: ctx)
        let machine = MachineInstance(label: "Chest Press #1")
        ctx.insert(machine)

        let moves = logged(bench, tag: .dumbbell, sets: 3, in: ctx)
        let barbell = logged(bench, tag: .barbell, in: ctx)
        let machined = logged(chestPress, tag: nil, machine: machine, in: ctx)
        let running = logged(bench, tag: .dumbbell, finished: false, in: ctx)
        let unmapped = logged(deadlift, tag: .dumbbell, in: ctx)
        try ctx.save()

        let outcome = try DumbbellHistoryMove.run(in: ctx)
        #expect(outcome == DumbbellHistoryMove.Outcome(entries: 1, sets: 3))

        // Relationship AND snapshot, because history reads the snapshot (D23).
        #expect(moves.exercise?.id == dbBench.id)
        #expect(moves.snapshotExerciseID == dbBench.id)
        #expect(moves.snapshotExerciseName == "Dumbbell Bench Press")
        #expect(moves.snapshotFreeWeightTag == .dumbbell, "the tag is the truth about the set and stays")
        #expect(moves.workout?.historyEditedAt == nil, "the user did not edit this")

        for untouched in [barbell, machined, running, unmapped] {
            #expect(untouched.snapshotExerciseID != dbBench.id)
        }
        #expect(barbell.snapshotExerciseID == bench.id)
        #expect(running.snapshotExerciseID == bench.id, "a running workout is not history yet")
        #expect(unmapped.snapshotExerciseID == deadlift.id, "no honest counterpart → left alone")
    }

    @Test @MainActor func aSecondRunMovesNothing() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let bench = try exercise(named: "Bench Press", in: ctx)
        logged(bench, tag: .dumbbell, in: ctx)
        try ctx.save()
        #expect(try DumbbellHistoryMove.run(in: ctx).entries == 1)
        #expect(try DumbbellHistoryMove.run(in: ctx) == DumbbellHistoryMove.Outcome(entries: 0, sets: 0))
    }

    /// The point of rewriting the snapshot: records and the chart key on it.
    @Test @MainActor func recordsAndChartFollowTheMovedEntry() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let bench = try exercise(named: "Bench Press", in: ctx)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        let entry = logged(bench, tag: .dumbbell, in: ctx)
        try ctx.save()
        try DumbbellHistoryMove.run(in: ctx)

        let inputs = (entry.sets ?? []).map { set in
            RecordSetInput(
                loadType: entry.snapshotLoadType, exerciseID: entry.snapshotExerciseID,
                freeWeightTag: entry.snapshotFreeWeightTag, presetID: entry.snapshotPresetID,
                setType: set.type, reps: set.reps, weightValue: set.weightValue,
                weightUnit: set.weightUnit, normalizedKg: set.normalizedKg, completedAt: set.completedAt)
        }
        let keys = Set(inputs.flatMap { RecordsMath.groupKeys(for: $0) })
        #expect(keys.contains(.exercise(dbBench.id, preset: nil)))
        #expect(!keys.contains(.exercise(bench.id, preset: nil)), "no record group may still file these under Bench Press")
        let variations = ProgressSeriesMath.variations(in: inputs)
        #expect(variations.keys.allSatisfy { $0.equipment == .freeWeight(.dumbbell) })
    }

    // MARK: The seeder runs it once, on the version-5 crossing

    @Test @MainActor func crossingIntoVersionFiveMovesOnceAndRecordsIt() throws {
        let ctx = try context()
        var v4 = try SeedCatalog.bundled()
        v4.version = 4
        v4.exercises.removeAll { $0.equipmentTypeTags == [.dumbbell] && $0.name != "Dumbbell Curl" }
        try CatalogSeeder.reconcile(v4, in: ctx)
        let prefs = try AppPreferences.canonical(in: ctx)
        #expect(prefs.seededCatalogVersion == 4)
        let bench = try exercise(named: "Bench Press", in: ctx)
        logged(bench, tag: .dumbbell, sets: 2, in: ctx)
        try ctx.save()

        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        #expect(prefs.seededCatalogVersion == 5)
        #expect(prefs.dumbbellHistoryMovedSets == 2)
        #expect(prefs.dumbbellHistoryMovedAt != nil)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<ExerciseEntry>()).first?.snapshotExerciseID == dbBench.id)

        // Already at 5: a re-run must not touch the record or re-move.
        let stamp = prefs.dumbbellHistoryMovedAt
        logged(bench, tag: .dumbbell, in: ctx)  // logged AFTER the move: stays, tagged
        try ctx.save()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        #expect(prefs.dumbbellHistoryMovedAt == stamp)
        #expect(prefs.dumbbellHistoryMovedSets == 2)
    }

    @Test @MainActor func aFreshStoreRecordsNothing() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let prefs = try AppPreferences.canonical(in: ctx)
        #expect(prefs.dumbbellHistoryMovedSets == nil)
        #expect(prefs.dumbbellHistoryMovedAt == nil)
    }

    // MARK: Switching mid-workout so the split cannot re-grow

    @Test @MainActor func aDraftEntrySwitchesInPlaceAndDropsThePreset() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let session = WorkoutSession(context: ctx, notifications: SilentNotifications())
        let bench = try exercise(named: "Bench Press", in: ctx)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        let workout = try session.startWorkout(at: nil)
        let entry = try session.addEntry(for: bench, to: workout, freeWeightTag: .barbell)
        let grip = ExercisePreset(name: "Wide grip", exercise: bench)
        ctx.insert(grip)
        entry.preset = grip

        let result = try session.switchExercise(of: entry, to: dbBench)
        #expect(result === entry, "a draft entry is edited in place")
        #expect(entry.exercise?.id == dbBench.id)
        #expect(entry.snapshotExerciseID == dbBench.id)
        #expect(entry.snapshotExerciseName == "Dumbbell Bench Press")
        #expect(entry.freeWeightTag == .dumbbell)
        #expect(entry.preset == nil, "a preset belongs to its exercise (D37)")
    }

    @Test @MainActor func aFrozenEntrySplitsIntoANewEntryForTheCounterpart() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let session = WorkoutSession(context: ctx, notifications: SilentNotifications())
        let bench = try exercise(named: "Bench Press", in: ctx)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        let workout = try session.startWorkout(at: nil)
        let entry = try session.addEntry(for: bench, to: workout, freeWeightTag: .barbell)
        let set = try #require(entry.sets?.first)
        try session.commitWeight("60", for: set)
        try session.commitReps("8", for: set)
        try session.toggleCompletion(of: set)  // freezes the snapshot (D19/D23)
        #expect(entry.snapshotCapturedAt != nil)

        let result = try session.switchExercise(of: entry, to: dbBench)
        #expect(result !== entry, "a frozen entry must not be rewritten")
        #expect(entry.snapshotExerciseID == bench.id, "the logged barbell set stays under Bench Press")
        #expect(result.exercise?.id == dbBench.id)
        #expect(result.freeWeightTag == .dumbbell)
        #expect(WorkoutSession.orderedEntries(of: workout).map(\.id) == [entry.id, result.id])
    }
}
