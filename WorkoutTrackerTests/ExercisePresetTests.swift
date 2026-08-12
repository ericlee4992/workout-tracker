import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

// Exercise presets (D36–D38) — the rules that decide which sets are comparable
// to which. A preset that splits records is only as good as its boundaries: get
// them wrong and a wide-grip PR quietly becomes a narrow-grip PR, which is the
// same class of damage as attaching a set to the wrong machine (D23).

struct ExercisePresetTests {

    // MARK: - Naming rules (pure)

    @Test func namesAreTrimmedAndDuplicatesRejectedCaseInsensitively() {
        #expect(ExercisePresets.cleanedName("  Wide grip \n") == "Wide grip")
        let existing = ["Wide grip", "Narrow grip"]
        #expect(ExercisePresets.isDuplicate("wide grip", among: existing))
        #expect(ExercisePresets.isDuplicate("  WIDE   GRIP  ", among: existing))
        #expect(!ExercisePresets.isDuplicate("Neutral grip", among: existing))
        // Two presets that read identically would split a rep-count table
        // across rows the user cannot tell apart.
        #expect(!ExercisePresets.isValid("wide grip", existing: existing))
        #expect(!ExercisePresets.isValid("   ", existing: existing))
        #expect(ExercisePresets.isValid("Single leg", existing: existing))
    }

    @Test func orderingAppendsAndRenumbers() {
        #expect(ExercisePresets.nextOrder(after: []) == 0)
        #expect(ExercisePresets.nextOrder(after: [0, 1, 2]) == 3)
        // Gaps do not confuse it — a delete leaves them behind.
        #expect(ExercisePresets.nextOrder(after: [0, 5]) == 6)
        #expect(ExercisePresets.renumbered(3) == [0, 1, 2])
    }

    @Test func suggestionsAreOfferedButNeverSeeded() {
        #expect(ExercisePresets.suggestions.contains("Wide grip"))
        #expect(ExercisePresets.suggestions.contains("Single leg"))
        // They are strings in the app, not catalog rows: nothing here has an id.
        #expect(ExercisePresets.suggestions.allSatisfy { !$0.isEmpty })
    }

    // MARK: - Rig

    private struct Rig {
        var context: ModelContext
        var session: WorkoutSession
        var gym: Gym
        var machine: MachineInstance
        var exercise: Exercise
        var wide: ExercisePreset
        var narrow: ExercisePreset
    }

    private func makeRig() throws -> Rig {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let exercise = Exercise(name: "Seated Cable Row", loadType: .weighted)
        let wide = ExercisePreset(name: "Wide grip", order: 0, exercise: exercise)
        let narrow = ExercisePreset(name: "Narrow grip", order: 1, exercise: exercise)
        let model = EquipmentModel(
            manufacturer: "Life Fitness", modelName: "Insignia Row",
            exerciseIDs: [exercise.id])
        let gym = Gym(name: "Gold's", defaultUnit: .kg)
        let machine = MachineInstance(label: "Cable Row #2", gym: gym, model: model)
        for object in [exercise, wide, narrow, model, gym, machine] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()
        return Rig(
            context: context, session: WorkoutSession(context: context),
            gym: gym, machine: machine, exercise: exercise, wide: wide, narrow: narrow)
    }

    @discardableResult
    private func logSet(
        _ rig: Rig, on entry: ExerciseEntry, weight: Double, reps: Int, at date: Date
    ) throws -> SetRecord {
        let set = try #require(WorkoutSession.orderedSets(of: entry).last { $0.completedAt == nil })
        try rig.session.commitWeight(String(weight), for: set)
        try rig.session.commitReps(String(reps), for: set)
        try rig.session.toggleCompletion(of: set, at: date)
        return set
    }

    // MARK: - The machine's usual preset (D38)

    @Test func aNewEntryArrivesOnTheMachinesUsualPreset() throws {
        let rig = try makeRig()
        rig.machine.defaultPresetID = rig.narrow.id
        try rig.context.save()

        let workout = try rig.session.startWorkout(at: rig.gym, on: .now)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        #expect(entry.preset?.id == rig.narrow.id)
    }

    /// A stale default — the preset was deleted, or belongs to another exercise
    /// — must degrade to "none chosen", never attach someone else's variation.
    @Test func aStaleUsualPresetDegradesToNone() throws {
        let rig = try makeRig()
        let other = Exercise(name: "Leg Press", loadType: .weighted)
        let foreign = ExercisePreset(name: "Single leg", order: 0, exercise: other)
        rig.context.insert(other)
        rig.context.insert(foreign)
        rig.machine.defaultPresetID = foreign.id
        try rig.context.save()

        let workout = try rig.session.startWorkout(at: rig.gym, on: .now)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        #expect(entry.preset == nil, "another exercise's preset must not attach")
    }

    // MARK: - Freezing and splitting (D19 + D36)

    @Test func switchingPresetBeforeAnySetJustSwitches() throws {
        let rig = try makeRig()
        let workout = try rig.session.startWorkout(at: rig.gym, on: .now)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)

        let same = try rig.session.choosePreset(rig.wide, for: entry)
        #expect(same === entry, "a draft entry changes in place")
        #expect(entry.preset?.id == rig.wide.id)
        #expect(WorkoutSession.orderedEntries(of: workout).count == 1)
    }

    /// The rule that protects history: once a set is logged, its snapshot says
    /// which variation it was. Changing handles afterwards is a new entry.
    @Test func switchingPresetAfterASetStartsANewEntry() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: entry)
        try logSet(rig, on: entry, weight: 70, reps: 8, at: start.addingTimeInterval(60))

        let switched = try rig.session.choosePreset(rig.narrow, for: entry)
        #expect(switched !== entry, "a frozen entry splits rather than relabelling")
        #expect(switched.preset?.id == rig.narrow.id)
        #expect(entry.snapshotPresetID == rig.wide.id, "the logged set keeps its variation")
        #expect(entry.snapshotPresetName == "Wide grip")

        let entries = WorkoutSession.orderedEntries(of: workout)
        #expect(entries.count == 2)
        #expect(entries.map(\.order) == [0, 1])
        // Completed work stays behind; the fresh entry starts empty.
        #expect(WorkoutSession.orderedSets(of: entry).count == 1)
        #expect(WorkoutSession.orderedSets(of: switched).allSatisfy { $0.completedAt == nil })
    }

    @Test func theSnapshotRecordsThePresetAtFirstCompletion() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 2_000_000)
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: entry)
        #expect(entry.snapshotPresetID == nil, "nothing is frozen until a set completes")

        try logSet(rig, on: entry, weight: 70, reps: 8, at: start.addingTimeInterval(60))
        #expect(entry.snapshotPresetID == rig.wide.id)

        // Renaming afterwards must not rewrite what history says (D23).
        rig.wide.name = "Wide (V-bar)"
        try rig.context.save()
        #expect(entry.snapshotPresetName == "Wide grip")
        #expect(entry.snapshotEquipmentLabel.contains("Wide grip"))
    }

    // MARK: - Records and prefill (D36)

    /// The point of the whole feature: two variations of one movement on one
    /// machine keep separate bests.
    @Test func recordsDoNotCrossPresets() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 3_000_000)
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)

        let wideEntry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: wideEntry)
        try logSet(rig, on: wideEntry, weight: 70, reps: 8, at: start.addingTimeInterval(60))

        let narrowEntry = try rig.session.choosePreset(rig.narrow, for: wideEntry)
        try logSet(rig, on: narrowEntry, weight: 90, reps: 8, at: start.addingTimeInterval(300))

        let inputs = try rig.context.fetch(FetchDescriptor<SetRecord>())
            .filter { $0.completedAt != nil }
            .map { set in
                RecordSetInput(
                    loadType: .weighted,
                    exerciseID: set.entry?.snapshotExerciseID ?? UUID(),
                    machineID: set.entry?.snapshotMachineID,
                    modelID: set.entry?.snapshotModelID,
                    presetID: set.entry?.snapshotPresetID,
                    setType: set.type, reps: set.reps,
                    weightValue: set.weightValue, weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg, completedAt: set.completedAt)
            }
        let grouped = RecordsMath.grouped(inputs)

        let wideKey = RecordGroupKey.machine(rig.machine.id, preset: rig.wide.id)
        let narrowKey = RecordGroupKey.machine(rig.machine.id, preset: rig.narrow.id)
        #expect(grouped[wideKey]?.count == 1)
        #expect(grouped[narrowKey]?.count == 1)
        #expect(
            RecordsMath.repCountBests(among: grouped[wideKey] ?? [], loadType: .weighted)[8]?
                .normalizedKg == 70,
            "the wide-grip table must not inherit the narrow-grip 90")
        #expect(
            RecordsMath.repCountBests(among: grouped[narrowKey] ?? [], loadType: .weighted)[8]?
                .normalizedKg == 90)
        // Volume is a whole-workout number and still counts everything.
        #expect(abs(RecordsMath.totalVolumeKg(among: inputs) - (70 * 8 + 90 * 8)) < 1e-9)
    }

    /// The service is the owner of D37, not whichever view calls it: a preset
    /// from another exercise must never attach, or it would be snapshotted and
    /// grouped as if it belonged (codex-review, finding 4).
    @Test func aPresetFromAnotherExerciseIsRefused() throws {
        let rig = try makeRig()
        let other = Exercise(name: "Leg Press", loadType: .weighted)
        let foreign = ExercisePreset(name: "Single leg", order: 0, exercise: other)
        rig.context.insert(other)
        rig.context.insert(foreign)
        try rig.context.save()

        let workout = try rig.session.startWorkout(at: rig.gym, on: .now)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try rig.session.choosePreset(foreign, for: entry)
        #expect(entry.preset == nil, "a Leg Press variation cannot be attached to a Row")

        // And it cannot ride across an equipment change either.
        try rig.session.choosePreset(rig.wide, for: entry)
        let moved = try rig.session.chooseEquipment(
            for: entry, machine: nil, freeWeightTag: .cable)
        #expect(moved.preset?.id == rig.wide.id, "a valid preset does follow the user")
    }

    /// Prefill writes into the draft row, so a variation change leaves last
    /// session's numbers sitting in the inputs one tap from being logged as
    /// this variation (codex-review, finding 3).
    @Test func switchingPresetDropsValuesInheritedFromTheOtherOne() throws {
        let rig = try makeRig()
        let firstStart = Date(timeIntervalSince1970: 5_000_000)
        let first = try rig.session.startWorkout(at: rig.gym, on: firstStart)
        let wideEntry = try rig.session.addEntry(
            for: rig.exercise, to: first, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: wideEntry)
        try logSet(rig, on: wideEntry, weight: 70, reps: 8, at: firstStart.addingTimeInterval(60))
        _ = try rig.session.finish(first, at: firstStart.addingTimeInterval(600))

        // Next session: the wide-grip row prefills, then the user switches grip
        // before logging anything.
        let second = try rig.session.startWorkout(
            at: rig.gym, on: firstStart.addingTimeInterval(86_400))
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: second, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: entry)
        let row = try #require(WorkoutSession.orderedSets(of: entry).first)
        let history = PerformanceHistory(context: rig.context)
        let candidate = try #require(try history.prefill(for: row))
        try history.applyPrefill(candidate, to: row, isDirty: false)
        #expect(row.weightValue == 70)

        try rig.session.choosePreset(rig.narrow, for: entry)
        #expect(row.weightValue == nil, "wide-grip numbers must not stand in a narrow-grip row")
        #expect(row.reps == nil)
        #expect(row.prefilledAt == nil)
    }

    /// …but what the user typed is theirs, and a context change must not eat it.
    @Test func switchingPresetKeepsWhatTheUserTyped() throws {
        let rig = try makeRig()
        let workout = try rig.session.startWorkout(at: rig.gym, on: .now)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: entry)
        let row = try #require(WorkoutSession.orderedSets(of: entry).first)
        try rig.session.commitWeight("62.5", for: row)
        try rig.session.commitReps("6", for: row)

        try rig.session.choosePreset(rig.narrow, for: entry)
        #expect(row.weightValue == 62.5, "the user's own numbers survive the switch")
        #expect(row.reps == 6)
    }

    /// The split moves drafts — and the values they inherited from the old
    /// variation stay behind with it.
    @Test func aSplitMovesDraftRowsWithoutTheirInheritedValues() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 6_000_000)
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: entry)
        try logSet(rig, on: entry, weight: 70, reps: 8, at: start.addingTimeInterval(60))
        // Carry-forward seeds the next row with the wide-grip numbers.
        let carried = try rig.session.addSet(to: entry)
        #expect(carried.weightValue == 70)
        #expect(carried.prefilledAt != nil)

        let switched = try rig.session.choosePreset(rig.narrow, for: entry)
        let moved = WorkoutSession.orderedSets(of: switched)
        #expect(moved.count == 1, "the draft row moves across")
        #expect(moved.first?.id == carried.id)
        #expect(moved.first?.weightValue == nil, "but not the wide-grip weight it inherited")
        #expect(WorkoutSession.orderedSets(of: entry).count == 1, "the logged set stays put")
    }

    /// A preset hangs off a *seeded* exercise, and the catalog reconciler
    /// rewrites seeded rows on every version bump (D24). The user's presets are
    /// user data on a catalog row — the same shape D27 protects for
    /// user-created exercises linked to seeded models — so they must survive.
    @Test func presetsOnASeededExerciseSurviveACatalogBump() throws {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let catalog = try SeedCatalog.bundled()
        try CatalogSeeder.reconcile(catalog, in: context)

        let seeded = try #require(
            try context.fetch(FetchDescriptor<Exercise>()).first { $0.isSeeded })
        let preset = ExercisePreset(name: "Wide grip", order: 0, exercise: seeded)
        context.insert(preset)
        try context.save()

        // Same content, a later version — the path that rewrites allowlisted
        // fields on every seeded row.
        var bumped = catalog
        bumped.version = catalog.version + 1
        try CatalogSeeder.reconcile(bumped, in: context)

        let after = try #require(
            try context.fetch(FetchDescriptor<Exercise>()).first { $0.id == seeded.id })
        #expect(
            (after.presets ?? []).map(\.name) == ["Wide grip"],
            "the user's preset must not be swept away by a catalog update")
    }

    /// Finding 7: the record test only checked the machine key with named
    /// presets. Every layer's key, and the `nil` group, matter just as much.
    @Test func everyGroupKeyCarriesThePresetIncludingNone() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 7_000_000)
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)

        let none = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try logSet(rig, on: none, weight: 50, reps: 10, at: start.addingTimeInterval(60))
        let wide = try rig.session.choosePreset(rig.wide, for: none)
        try logSet(rig, on: wide, weight: 70, reps: 10, at: start.addingTimeInterval(300))

        let inputs = try rig.context.fetch(FetchDescriptor<SetRecord>())
            .filter { $0.completedAt != nil }
            .map { set in
                RecordSetInput(
                    loadType: .weighted,
                    exerciseID: set.entry?.snapshotExerciseID ?? UUID(),
                    machineID: set.entry?.snapshotMachineID,
                    modelID: set.entry?.snapshotModelID,
                    presetID: set.entry?.snapshotPresetID,
                    setType: set.type, reps: set.reps,
                    weightValue: set.weightValue, weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg, completedAt: set.completedAt)
            }
        let grouped = RecordsMath.grouped(inputs)
        let modelID = try #require(rig.machine.model?.id)

        // Machine, model and exercise keys all separate the two, and "no
        // preset" is its own group rather than a catch-all.
        #expect(grouped[.machine(rig.machine.id, preset: nil)]?.count == 1)
        #expect(grouped[.machine(rig.machine.id, preset: rig.wide.id)]?.count == 1)
        #expect(grouped[.model(modelID, preset: nil)]?.count == 1)
        #expect(grouped[.model(modelID, preset: rig.wide.id)]?.count == 1)
        #expect(grouped[.exercise(rig.exercise.id, preset: nil)]?.count == 1)
        #expect(grouped[.exercise(rig.exercise.id, preset: rig.wide.id)]?.count == 1)
        // Free-weight keys carry it too, on a machineless entry.
        let free = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .dumbbell)
        try rig.session.choosePreset(rig.narrow, for: free)
        try logSet(rig, on: free, weight: 30, reps: 12, at: start.addingTimeInterval(600))
        let freeInput = try #require(
            try rig.context.fetch(FetchDescriptor<SetRecord>())
                .first { $0.entry?.snapshotFreeWeightTag == .dumbbell })
        let keys = RecordsMath.groupKeys(for: RecordSetInput(
            loadType: .weighted,
            exerciseID: rig.exercise.id,
            freeWeightTag: .dumbbell,
            presetID: freeInput.entry?.snapshotPresetID,
            setType: .working, reps: 12, weightValue: 30, weightUnit: .kg,
            normalizedKg: 30, completedAt: freeInput.completedAt))
        #expect(keys.contains(
            .freeWeight(exerciseID: rig.exercise.id, tag: .dumbbell, preset: rig.narrow.id)))
        #expect(!keys.contains(
            .freeWeight(exerciseID: rig.exercise.id, tag: .dumbbell, preset: nil)))
    }

    /// All three previous-performance layers are scoped to the variation, not
    /// just layer one (codex-review, finding 2).
    @Test func everyPerformanceLayerIsScopedToTheVariation() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 8_000_000)

        // A wide-grip session at *another* gym on the same model, plus a
        // pre-preset session here — neither should surface for narrow grip.
        let elsewhere = Gym(name: "Other Gym", defaultUnit: .kg)
        let elsewhereMachine = MachineInstance(
            label: "Row", gym: elsewhere, model: rig.machine.model)
        rig.context.insert(elsewhere)
        rig.context.insert(elsewhereMachine)
        try rig.context.save()

        let away = try rig.session.startWorkout(at: elsewhere, on: start)
        let awayEntry = try rig.session.addEntry(
            for: rig.exercise, to: away, machine: elsewhereMachine)
        try rig.session.choosePreset(rig.wide, for: awayEntry)
        try logSet(rig, on: awayEntry, weight: 65, reps: 8, at: start.addingTimeInterval(60))
        _ = try rig.session.finish(away, at: start.addingTimeInterval(600))

        let home = try rig.session.startWorkout(
            at: rig.gym, on: start.addingTimeInterval(86_400))
        let narrowEntry = try rig.session.addEntry(
            for: rig.exercise, to: home, machine: rig.machine)
        try rig.session.choosePreset(rig.narrow, for: narrowEntry)

        let history = PerformanceHistory(context: rig.context)
        let summary = try history.summary(for: narrowEntry)
        for layer in summary.layers {
            #expect(
                layer.snapshot == nil,
                "\(layer.kind) surfaced a wide-grip session for a narrow-grip entry")
        }
    }

    /// Prefill is the sharp end of D36: seeding a narrow-grip row with
    /// wide-grip numbers asserts a comparability the app exists to deny.
    @Test func prefillDoesNotCrossPresets() throws {
        let rig = try makeRig()
        let firstStart = Date(timeIntervalSince1970: 4_000_000)
        let first = try rig.session.startWorkout(at: rig.gym, on: firstStart)
        let wideEntry = try rig.session.addEntry(
            for: rig.exercise, to: first, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: wideEntry)
        try logSet(rig, on: wideEntry, weight: 70, reps: 8, at: firstStart.addingTimeInterval(60))
        _ = try rig.session.finish(first, at: firstStart.addingTimeInterval(600))

        let second = try rig.session.startWorkout(
            at: rig.gym, on: firstStart.addingTimeInterval(86_400))
        let narrowEntry = try rig.session.addEntry(
            for: rig.exercise, to: second, machine: rig.machine)
        try rig.session.choosePreset(rig.narrow, for: narrowEntry)

        let previous = PerformanceHistory(context: rig.context)
        let narrowRow = try #require(WorkoutSession.orderedSets(of: narrowEntry).first)
        #expect(
            try previous.prefill(for: narrowRow) == nil,
            "narrow grip has no history to prefill from")

        let wideAgain = try rig.session.addEntry(
            for: rig.exercise, to: second, machine: rig.machine)
        try rig.session.choosePreset(rig.wide, for: wideAgain)
        let wideRow = try #require(WorkoutSession.orderedSets(of: wideAgain).first)
        let widePrefill = try previous.prefill(for: wideRow)
        #expect(widePrefill?.weightValue == 70, "wide grip prefills from wide grip")
    }
}
