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
        #expect(moves.workout?.historyEditedAt == nil, "the user did not edit this (D51)")
        // D51: provenance on the row, so the rewrite is never silent.
        #expect(moves.reclassifiedAt != nil)
        #expect(moves.reclassifiedFromExerciseName == "Bench Press")
        #expect(barbell.reclassifiedAt == nil)

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

        // Already at 5: a plain re-run leaves the record alone...
        let stamp = prefs.dumbbellHistoryMovedAt
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        #expect(prefs.dumbbellHistoryMovedAt == stamp)
        #expect(prefs.dumbbellHistoryMovedSets == 2)

        // ...but history that ARRIVES after the crossing (a merge, a restore)
        // is still moved, and the record accumulates (codex-review 04: a
        // one-shot gate missed this forever).
        logged(bench, tag: .dumbbell, sets: 3, in: ctx)
        try ctx.save()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        #expect(prefs.dumbbellHistoryMovedSets == 5)
        #expect(prefs.dumbbellHistoryMovedAt != stamp)
        #expect(try ctx.fetch(FetchDescriptor<ExerciseEntry>()).allSatisfy { $0.snapshotExerciseID == dbBench.id })
    }

    /// The seeder's FAST PATH (store already matches the catalog) must still
    /// run the cheap check — that is the launch every user has after the
    /// crossing, and the one a late-arriving row would meet.
    @Test @MainActor func theFastPathStillReclassifiesLateHistory() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)  // now on the fast path
        let bench = try exercise(named: "Bench Press", in: ctx)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        let late = logged(bench, tag: .dumbbell, in: ctx)
        try ctx.save()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        #expect(late.snapshotExerciseID == dbBench.id)
        #expect(try AppPreferences.canonical(in: ctx).dumbbellHistoryMovedSets == 2)
    }

    /// A fresh store: it RAN (checkedAt set) and moved nothing (sets nil), and
    /// those are two different facts (codex-review 04).
    @Test @MainActor func aFreshStoreRecordsThatItRanAndMovedNothing() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let prefs = try AppPreferences.canonical(in: ctx)
        #expect(prefs.dumbbellHistoryCheckedAt != nil)
        #expect(prefs.dumbbellHistoryMovedSets == nil)
        #expect(prefs.dumbbellHistoryMovedAt == nil)
    }

    // MARK: The variation moves with the movement (D51 §3)

    @Test @MainActor func aPresetIsReHomedOntoTheCounterpartAndShared() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let bench = try exercise(named: "Bench Press", in: ctx)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        let wide = ExercisePreset(name: "Wide grip", order: 0, exercise: bench)
        ctx.insert(wide)
        let first = logged(bench, tag: .dumbbell, in: ctx)
        let second = logged(bench, tag: .dumbbell, daysAgo: 10, in: ctx)
        for e in [first, second] { e.preset = wide; e.snapshotPresetID = wide.id; e.snapshotPresetName = "Wide grip" }
        // A third whose preset was since DELETED: only the snapshot name remains,
        // and spelled the way the app's own duplicate rule considers equal —
        // case, diacritics AND spacing (codex-review 04b).
        let orphan = logged(bench, tag: .dumbbell, daysAgo: 20, in: ctx)
        orphan.snapshotPresetID = UUID(); orphan.snapshotPresetName = "  WIDE   GRIP "
        try ctx.save()

        try DumbbellHistoryMove.run(in: ctx)

        let homed = try #require(first.preset)
        #expect(homed.exercise?.id == dbBench.id, "the preset now belongs to the counterpart (D37)")
        #expect(homed.id != wide.id)
        #expect(first.snapshotPresetID == homed.id, "records and chart key on the snapshot id (D36)")
        #expect(second.preset?.id == homed.id && second.snapshotPresetID == homed.id, "one shared preset, not one per entry")
        #expect(orphan.snapshotPresetID == homed.id, "matched by the app's own name rule: case, diacritics, spacing")
        #expect(homed.name == "Wide grip", "created with the cleaned name of the first arrival")
        #expect(first.snapshotPresetName == "Wide grip", "the name as logged is unchanged")
        #expect((dbBench.presets ?? []).count == 1)
        #expect((bench.presets ?? []).contains { $0.id == wide.id }, "the source keeps its own preset for its own history")
    }

    @Test @MainActor func uncapturedDeletedAndRelationshipLessRowsAreHandled() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let bench = try exercise(named: "Bench Press", in: ctx)
        let dbBench = try exercise(named: "Dumbbell Bench Press", in: ctx)
        let uncaptured = logged(bench, tag: .dumbbell, in: ctx)
        uncaptured.snapshotCapturedAt = nil
        let relationshipless = logged(bench, tag: .dumbbell, daysAgo: 5, in: ctx)
        relationshipless.exercise = nil  // the live row is gone; the snapshot still says Bench Press
        let doomed = logged(bench, tag: .dumbbell, daysAgo: 6, in: ctx)
        try ctx.save()
        ctx.delete(doomed)

        try DumbbellHistoryMove.run(in: ctx)
        #expect(uncaptured.snapshotExerciseID == bench.id, "no frozen snapshot → not history → untouched")
        #expect(relationshipless.snapshotExerciseID == dbBench.id, "D23: the snapshot is the identity, and it qualifies")
        #expect(relationshipless.exercise?.id == dbBench.id)
    }

    @Test @MainActor func theExportCarriesTheProvenance() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let bench = try exercise(named: "Bench Press", in: ctx)
        logged(bench, tag: .dumbbell, in: ctx)
        try ctx.save()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let snapshot = try ExportCollector(appVersion: "test").snapshot(from: ctx)
        let entry = try #require(snapshot.workouts.first?.entries.first)
        #expect(entry.exerciseName == "Dumbbell Bench Press")
        #expect(entry.reclassifiedFromExerciseName == "Bench Press")
        #expect(entry.reclassifiedAt != nil)
        #expect(snapshot.preferences?.dumbbellHistoryMovedSets == 2)
        #expect(snapshot.preferences?.dumbbellHistoryCheckedAt != nil)
        let csv = ExportCSV.render(snapshot)
        let column = try #require(ExportCSV.header.firstIndex(of: "reclassifiedFrom"))
        let rows = csv.split(separator: "\r\n").dropFirst().map { $0.split(separator: ",", omittingEmptySubsequences: false) }
        #expect(rows.allSatisfy { String($0[column]) == "Bench Press" })
        #expect(try ExportJSON.decode(try ExportJSON.data(snapshot)) == snapshot)
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

        let result = try #require(try session.switchToDumbbellCounterpart(of: entry))
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

        let result = try #require(try session.switchToDumbbellCounterpart(of: entry))
        #expect(result !== entry, "a frozen entry must not be rewritten")
        #expect(entry.snapshotExerciseID == bench.id, "the logged barbell set stays under Bench Press")
        #expect(result.exercise?.id == dbBench.id)
        #expect(result.freeWeightTag == .dumbbell)
        #expect(WorkoutSession.orderedEntries(of: workout).map(\.id) == [entry.id, result.id])
    }

    /// codex-review 04 (high): a frozen switch inside a superset used to
    /// insert an ungrouped entry between members and sever the adjacency run
    /// (D48). The new entry carries the group id.
    @Test @MainActor func aFrozenSwitchInsideASupersetKeepsTheGroupContiguous() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let session = WorkoutSession(context: ctx, notifications: SilentNotifications())
        let bench = try exercise(named: "Bench Press", in: ctx)
        let row = try exercise(named: "Seated Row", in: ctx)
        let workout = try session.startWorkout(at: nil)
        let a = try session.addEntry(for: bench, to: workout, freeWeightTag: .barbell)
        let b = try session.addEntry(for: row, to: workout)
        let group = UUID()
        a.supersetGroupID = group; b.supersetGroupID = group
        let set = try #require(a.sets?.first)
        try session.commitWeight("60", for: set); try session.commitReps("8", for: set)
        try session.toggleCompletion(of: set)

        let new = try #require(try session.switchToDumbbellCounterpart(of: a))
        let order = WorkoutSession.orderedEntries(of: workout)
        #expect(order.map(\.id) == [a.id, new.id, b.id])
        #expect(order.allSatisfy { $0.supersetGroupID == group }, "the run a → new → b must stay one group")
    }

    @Test @MainActor func theSwitchRefusesAMovementWithNoCounterpart() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let session = WorkoutSession(context: ctx, notifications: SilentNotifications())
        let deadlift = try exercise(named: "Deadlift", in: ctx)
        let workout = try session.startWorkout(at: nil)
        let entry = try session.addEntry(for: deadlift, to: workout, freeWeightTag: .barbell)
        #expect(try session.switchToDumbbellCounterpart(of: entry) == nil)
        #expect(entry.exercise?.id == deadlift.id)
    }

    /// codex-review 04b: a store whose only source-exercise rows are ineligible
    /// — barbell history, a running workout, an uncaptured draft — moves
    /// nothing and stamps nothing. (The persisted gate excludes the running and
    /// uncaptured rows outright; the finished barbell rows pass it and are
    /// rejected on the tag in Swift, because SwiftData cannot compare an enum
    /// in a predicate.)
    @Test @MainActor func ineligibleSourceHistoryMovesNothing() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let bench = try exercise(named: "Bench Press", in: ctx)
        for day in 1...30 { logged(bench, tag: .barbell, daysAgo: day, in: ctx) }
        logged(bench, tag: .dumbbell, finished: false, in: ctx)
        let draft = logged(bench, tag: .dumbbell, daysAgo: 40, in: ctx)
        draft.snapshotCapturedAt = nil
        try ctx.save()
        #expect(try DumbbellHistoryMove.run(in: ctx) == .nothing)
        #expect(try ctx.fetch(FetchDescriptor<ExerciseEntry>()).allSatisfy { $0.reclassifiedAt == nil })
    }

    /// codex-review 04b: a source entry holding a STALE one-member group id
    /// must not pass it to the continuation — that would fabricate a
    /// two-entry superset out of a standalone exercise (D48).
    @Test @MainActor func aStaleSingletonGroupIsNotCarriedThroughASplit() throws {
        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        let session = WorkoutSession(context: ctx, notifications: SilentNotifications())
        let bench = try exercise(named: "Bench Press", in: ctx)
        let workout = try session.startWorkout(at: nil)
        let a = try session.addEntry(for: bench, to: workout, freeWeightTag: .barbell)
        a.supersetGroupID = UUID()  // orphaned: no adjacent member
        let set = try #require(a.sets?.first)
        try session.commitWeight("60", for: set); try session.commitReps("8", for: set)
        try session.toggleCompletion(of: set)

        let new = try #require(try session.switchToDumbbellCounterpart(of: a))
        #expect(new.supersetGroupID == nil)
        #expect(a.supersetGroupID == nil, "and the stale id is pruned off the source")
    }
}
