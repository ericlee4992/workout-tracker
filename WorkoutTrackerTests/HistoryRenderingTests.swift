import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 09 — history rendering: unit-badge derivation from actual sets,
// snapshot-only equipment labels (D23) proven against live renames with the
// disk-backed reopen pattern, and convert-toggle formatting (D9/D25).

struct HistoryRenderingTests {

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    // MARK: Unit badge derivation

    @Test func allKgSetsDeriveKgBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: [.kg, .kg, .kg]) == .single(.kg))
        #expect(WorkoutUnitBadge.derive(fromUnits: [.kg])?.label == "kg")
    }

    @Test func allLbSetsDeriveLbBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: [.lb, .lb]) == .single(.lb))
        #expect(WorkoutUnitBadge.derive(fromUnits: [.lb])?.label == "lb")
    }

    @Test func mixedUnitsDeriveMixedBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: [.kg, .lb, .kg]) == .mixed)
        #expect(WorkoutUnitBadge.mixed.label == "Mixed")
    }

    @Test func noSetsDeriveNoBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: []) == nil)
        #expect(WorkoutUnitBadge.derive(fromCompleted: []) == nil)
    }

    /// Only completed sets feed the badge: a lingering lb draft must not turn
    /// an all-kg workout into Mixed.
    @Test func badgeIgnoresUncompletedDrafts() {
        let completed = SetRecord(
            order: 0, reps: 10, weightValue: 60, weightUnit: .kg,
            normalizedKg: 60, completedAt: .now)
        let draft = SetRecord(order: 1, weightUnit: .lb)
        #expect(WorkoutUnitBadge.derive(fromCompleted: [completed, draft]) == .single(.kg))
    }

    // MARK: Snapshot equipment labels

    @Test func machineEntryLabelIsMachineLabelDotModelDisplayName() {
        let entry = ExerciseEntry(
            order: 0,
            snapshotExerciseID: UUID(),
            snapshotLoadType: .weighted,
            snapshotExerciseName: "Seated Chest Press",
            snapshotMachineLabel: "Chest Press #1",
            snapshotModelName: "Life Fitness Insignia Chest Press")
        #expect(entry.snapshotEquipmentLabel == "Chest Press #1 · Life Fitness Insignia Chest Press")
    }

    @Test func freeWeightEntryLabelIsSnapshotTagLabel() {
        let entry = ExerciseEntry(
            order: 0,
            snapshotExerciseID: UUID(),
            snapshotLoadType: .weighted,
            snapshotFreeWeightTag: .barbell,
            snapshotExerciseName: "Bench Press")
        #expect(entry.snapshotEquipmentLabel == "Barbell")
    }

    /// Rendering source proof (D23): after logging, rename the live machine,
    /// model, and exercise — the labels history renders (snapshot display
    /// strings) survive a store reopen unchanged.
    @Test func historyLabelsSurviveLiveRenames() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-test-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: url.path + suffix))
            }
        }

        var workoutID = UUID()
        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let exercise = Exercise(name: "Seated Chest Press", loadType: .weighted)
            let model = EquipmentModel(
                manufacturer: "Life Fitness", modelName: "Insignia Chest Press",
                exerciseIDs: [exercise.id])
            let gym = Gym(name: "Gold's Gym Gangnam", defaultUnit: .kg)
            let machine = MachineInstance(label: "Chest Press #1", gym: gym, model: model)
            for object in [exercise, model, gym, machine] as [any PersistentModel] {
                context.insert(object)
            }
            try context.save()

            let session = WorkoutSession(context: context)
            let workout = try session.startWorkout(at: gym)
            workoutID = workout.id
            let entry = try session.addEntry(for: exercise, to: workout, machine: machine)
            let set = try #require(WorkoutSession.orderedSets(of: entry).first)
            try session.commitWeight("60", for: set)
            try session.commitReps("10", for: set)
            try session.toggleCompletion(of: set)
            try session.finish(workout)

            // Rename everything the entry points at through live relationships.
            machine.label = "Renamed Machine"
            model.manufacturer = "Rebranded"
            model.modelName = "Different Model"
            exercise.name = "Renamed Exercise"
            try context.save()
        }()

        // Reopen: history rendering reads snapshots, not the renamed rows.
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let workouts = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.id == workoutID }))
        let workout = try #require(workouts.first)
        let entry = try #require(WorkoutSession.orderedEntries(of: workout).first)

        // The live relationships did change...
        #expect(entry.machine?.label == "Renamed Machine")
        #expect(entry.exercise?.name == "Renamed Exercise")
        // ...but the snapshot strings history renders did not.
        #expect(entry.snapshotExerciseName == "Seated Chest Press")
        #expect(entry.snapshotEquipmentLabel == "Chest Press #1 · Life Fitness Insignia Chest Press")
        #expect(WorkoutUnitBadge.derive(fromCompleted: workout.completedSets) == .single(.kg))
    }

    // MARK: Row titles (E1, ticket 17)

    private func exercise(_ name: String, id: UUID = UUID()) -> HistoryExercise {
        HistoryExercise(id: id, name: name)
    }

    /// The template a workout started from names it, whatever was performed.
    @Test func templateNameWinsOverExercises() {
        #expect(HistoryRendering.title(
            templateName: "Push Day",
            exercises: [exercise("Chest Press"), exercise("Lateral Raise")]) == "Push Day")
        // Whitespace-only is not a name.
        #expect(HistoryRendering.title(
            templateName: "   ", exercises: [exercise("Chest Press")]) == "Chest Press")
    }

    /// Without a template the exercises performed name the workout — the
    /// first one, plus how many others.
    @Test func exercisesDeriveTheTitleWhenThereIsNoTemplate() {
        #expect(HistoryRendering.title(
            templateName: nil, exercises: [exercise("Chest Press")]) == "Chest Press")
        #expect(HistoryRendering.title(
            templateName: nil,
            exercises: [exercise("Chest Press"), exercise("Row"), exercise("Curl")])
            == "Chest Press +2")
        // Repeating an exercise (a split entry, D19) is one exercise.
        let press = UUID()
        #expect(HistoryRendering.title(
            templateName: nil,
            exercises: [exercise("Chest Press", id: press), exercise("Chest Press", id: press)])
            == "Chest Press")
    }

    /// Identity is the snapshot ID, not the display name: two distinct
    /// exercises that happen to share a name are two exercises, and collapsing
    /// them produced a title that could not tell the workouts apart.
    @Test func sameNamedDistinctExercisesAreNotCollapsed() {
        #expect(HistoryRendering.title(
            templateName: nil,
            exercises: [exercise("Row"), exercise("Row")]) == "Row +1")
    }

    /// Neither template nor exercises → a neutral label, never an empty row.
    @Test func titleFallsBackWhenNothingNamesTheWorkout() {
        #expect(HistoryRendering.title(templateName: nil, exercises: []) == "Workout")
        #expect(HistoryRendering.title(
            templateName: nil, exercises: [exercise(""), exercise("  ")]) == "Workout")
    }

    /// E1 against real persisted data: the title comes from SNAPSHOTS (D23),
    /// so renaming the live exercise afterwards never retitles history.
    @Test func workoutTitleReadsSnapshotsNotLiveExercises() throws {
        let context = try makeContext()
        let press = Exercise(name: "Chest Press")
        let row = Exercise(name: "Seated Row")
        let gym = Gym(name: "Gangnam Fitness", defaultUnit: .kg)
        for object in [press, row, gym] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()

        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: gym)
        for exercise in [press, row] {
            let entry = try session.addEntry(for: exercise, to: workout)
            let set = try #require(WorkoutSession.orderedSets(of: entry).first)
            try session.commitWeight("40", for: set)
            try session.commitReps("10", for: set)
            try session.toggleCompletion(of: set)
        }
        try session.finish(workout)

        #expect(workout.historyTitle == "Chest Press +1")

        press.name = "Renamed Press"
        try context.save()
        #expect(workout.historyTitle == "Chest Press +1")
    }

    /// D23 regression: a workout started from a template is titled by the
    /// template name captured AT START, and subtitled by the gym name captured
    /// at start/log time. Renaming (or deleting) either afterwards must leave
    /// the finished row exactly as it was — history is a record, not a live
    /// view of the library.
    @Test func renamingTheTemplateOrGymDoesNotRewriteFinishedWorkouts() throws {
        let context = try makeContext()
        let press = Exercise(name: "Chest Press")
        let gym = Gym(name: "Gangnam Fitness", defaultUnit: .kg)
        context.insert(press)
        context.insert(gym)
        try context.save()
        let template = try WorkoutTemplateService(context: context).create(
            name: "Push Day", items: [
                TemplateItemDraft(exercise: press, targetRepsBySet: [10]),
            ])

        let session = WorkoutSession(context: context)
        let workout = try WorkoutTemplateService(context: context)
            .start(template, at: gym)
        let entry = try #require(WorkoutSession.orderedEntries(of: workout).first)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.commitWeight("60", for: set)
        try session.commitReps("10", for: set)
        try session.toggleCompletion(of: set)
        try session.finish(workout)

        #expect(workout.historyTitle == "Push Day")
        #expect(workout.historyGymName == "Gangnam Fitness")

        // Rename both live rows...
        template.name = "Renamed Template"
        gym.name = "Renamed Gym"
        try context.save()
        #expect(workout.historyTitle == "Push Day")
        #expect(workout.historyGymName == "Gangnam Fitness")

        // ...and then delete the template outright.
        try WorkoutTemplateService(context: context).delete(template)
        #expect(workout.historyTitle == "Push Day")
        #expect(workout.historyGymName == "Gangnam Fitness")
    }

    // MARK: Stats line (E2, E3)

    /// E2: "1 exercises" was a hardcoded plural — for sets too.
    @Test func countsAgreeWithTheirNouns() {
        #expect(HistoryRendering.pluralized(1, "exercise", "exercises") == "1 exercise")
        #expect(HistoryRendering.pluralized(2, "exercise", "exercises") == "2 exercises")
        #expect(HistoryRendering.pluralized(0, "set", "sets") == "0 sets")
        #expect(HistoryRendering.statsLine(
            exerciseCount: 1, setCount: 1, duration: 3_600) == "1 exercise · 1 set · 60 min")
        #expect(HistoryRendering.statsLine(
            exerciseCount: 3, setCount: 12, duration: nil) == "3 exercises · 12 sets")
    }

    /// E3: a 14-second and a 45-second workout must not both read "0 min".
    @Test func subMinuteWorkoutsShowSeconds() {
        #expect(HistoryRendering.durationLabel(0) == "0s")
        #expect(HistoryRendering.durationLabel(14) == "14s")
        #expect(HistoryRendering.durationLabel(45) == "45s")
        #expect(HistoryRendering.durationLabel(59.9) == "59s")
        // A minute and above keeps minutes.
        #expect(HistoryRendering.durationLabel(60) == "1 min")
        #expect(HistoryRendering.durationLabel(2_700) == "45 min")
        // Never negative, whatever the clock did.
        #expect(HistoryRendering.durationLabel(-30) == "0s")
    }

    /// The same rule through the model: an active workout has no duration.
    @Test func workoutDurationLabelFollowsFinishedAt() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(Workout(startedAt: start).durationLabel == nil)
        #expect(Workout(
            startedAt: start,
            finishedAt: start.addingTimeInterval(45)).durationLabel == "45s")
        #expect(Workout(
            startedAt: start,
            finishedAt: start.addingTimeInterval(1_800)).durationLabel == "30 min")
    }

    // MARK: Convert-toggle formatting (D9/D25)

    private let enUS = Locale(identifier: "en_US")

    @Test func sameUnitRendersAsEnteredWithoutApproximation() throws {
        let kg = try #require(StoredWeight(value: 60, unit: .kg))
        let lb = try #require(StoredWeight(value: 135, unit: .lb))
        #expect(WeightMath.displayLabel(for: kg, in: .kg, locale: enUS) == "60 kg")
        #expect(WeightMath.displayLabel(for: lb, in: .lb, locale: enUS) == "135 lb")
    }

    @Test func convertedValuesArePlain() throws {
        let kg = try #require(StoredWeight(value: 60, unit: .kg))
        let lb = try #require(StoredWeight(value: 135, unit: .lb))
        // 60 / 0.45359237 = 132.277… → 132.28 lb (2 decimals, half-up), no ≈ (D52)
        #expect(WeightMath.displayLabel(for: kg, in: .lb, locale: enUS) == "132.28 lb")
        // 135 × 0.45359237 = 61.2349… → 61.23 kg
        #expect(WeightMath.displayLabel(for: lb, in: .kg, locale: enUS) == "61.23 kg")
    }
}
