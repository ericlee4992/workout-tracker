import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Floodlight redesign ticket 06 — the Gyms tab's derived facts: visits as distinct days and the
// eight-week rhythm, the tab's order, each machine's use and bests (warmups out, assisted lower is
// better, ties to the earliest, snapshot scope), the relative day words, the New Model prefill
// and restoring a deleted gym.

struct GymOverviewTests {
    /// A fixed Gregorian calendar (US: Sunday first) so weeks and words are deterministic.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US")
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 1
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: Visits and order

    @Test func visitsCountDistinctDaysAndTheRhythmEndsThisWeek() {
        let iron = UUID(), hotel = UUID()
        // Thursday Sep 24 2026 is "now"; that week is Sep 20 – 26.
        let now = date(2026, 9, 24, 12)
        let workouts = [
            GymVisitInput(gymID: iron, startedAt: date(2026, 9, 21, 7)),   // a run…
            GymVisitInput(gymID: iron, startedAt: date(2026, 9, 21, 18)),  // …and a lift: one visit
            GymVisitInput(gymID: iron, startedAt: date(2026, 9, 15)),
            GymVisitInput(gymID: iron, startedAt: date(2026, 9, 17)),
            GymVisitInput(gymID: iron, startedAt: date(2026, 7, 1)),       // older than 8 weeks
            GymVisitInput(gymID: hotel, startedAt: date(2026, 9, 22)),
            GymVisitInput(gymID: nil, startedAt: date(2026, 9, 23)),
        ]
        let visits = GymOverviewMath.visits(of: iron, in: workouts, now: now, calendar: calendar)
        #expect(visits.visits == 4)
        #expect(visits.lastVisit == date(2026, 9, 21, 18))
        #expect(visits.weekly == [0, 0, 0, 0, 0, 0, 2, 1], "oldest first; this week last")
        let none = GymOverviewMath.visits(of: UUID(), in: workouts, now: now, calendar: calendar)
        #expect(none.visits == 0 && none.lastVisit == nil && none.weekly == Array(repeating: 0, count: 8))
    }

    @Test func orderPutsTheCurrentGymFirstThenRecentThenName() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        let gyms = [(id: a, name: "Zeta Gym"), (id: b, name: "Alpha Gym"), (id: c, name: "Beta Gym"), (id: d, name: "Hotel")]
        let last = [b: date(2026, 9, 1), c: date(2026, 9, 20)]
        #expect(GymOverviewMath.order(gyms, current: d, lastVisit: last) == [d, c, b, a],
                "current first even unvisited; then most recent; never-visited by name")
        #expect(GymOverviewMath.order(gyms, current: nil, lastVisit: [:]) == [b, c, d, a])
    }

    // MARK: Machine use

    private func set(_ machine: UUID?, _ exercise: UUID, _ kg: Double, _ reps: Int, at time: Date,
                     type: SetType = .working, loadType: LoadType = .weighted, preset: UUID? = nil,
                     unit: WeightUnit = .kg, completed: Bool = true) -> RecordSetInput {
        RecordSetInput(loadType: loadType, exerciseID: exercise, gymID: nil, machineID: machine, modelID: nil,
                       freeWeightTag: nil, presetID: preset, setType: type, reps: reps,
                       weightValue: unit == .kg ? kg : kg / 0.45359237, weightUnit: unit,
                       normalizedKg: kg, completedAt: completed ? time : nil)
    }

    @Test func machineUseCountsWorkoutsSetsAndOneBestPerScope() {
        let machine = UUID(), press = UUID(), narrow = UUID()
        let w1 = UUID(), w2 = UUID(), w3 = UUID()
        let d1 = date(2026, 9, 1), d2 = date(2026, 9, 8), d3 = date(2026, 9, 15)
        let inputs: [MachineSetInput] = [
            // Workout 1: a heavy WARMUP never counts as a best; the working set does.
            .init(workoutID: w1, workoutStartedAt: d1, set: set(machine, press, 200, 5, at: d1, type: .warmup)),
            .init(workoutID: w1, workoutStartedAt: d1, set: set(machine, press, 100, 5, at: d1)),
            // Workout 2: same load, more reps — the better set; an uncompleted draft is ignored.
            .init(workoutID: w2, workoutStartedAt: d2, set: set(machine, press, 100, 8, at: d2)),
            .init(workoutID: w2, workoutStartedAt: d2, set: set(machine, press, 500, 8, at: d2, completed: false)),
            // Workout 3: the narrow-grip preset is its own scope (D36), used once.
            .init(workoutID: w3, workoutStartedAt: d3, set: set(machine, press, 90, 10, at: d3, preset: narrow)),
            // Another machine's set never lands here.
            .init(workoutID: w3, workoutStartedAt: d3, set: set(UUID(), press, 300, 1, at: d3)),
        ]
        let use = try! #require(GymOverviewMath.machineUse(inputs)[machine])
        #expect(use.workouts == 3)
        #expect(use.sets == 4, "every completed set on the machine, warmups included")
        #expect(use.lastUsed == d3)
        #expect(use.bests.count == 2)
        #expect(use.bests[0].presetID == nil && use.bests[0].workouts == 2, "the most-used scope first")
        #expect(use.bests[0].best.normalizedKg == 100 && use.bests[0].best.reps == 8)
        #expect(use.bests[1].presetID == narrow && use.bests[1].best.reps == 10)
        #expect(use.best()?.id == use.bests[0].id)
        #expect(use.lastUsed(for: press) == d3)
        #expect(use.best(for: UUID()) == nil && use.lastUsed(for: UUID()) == nil, "missing is not zero")
    }

    @Test func aGroupsRowShowsItsOwnExercisesBest() {
        // A cable station used mostly for pushdowns, once for a chest fly: under Chest its row
        // shows the fly, never the pushdown; outside a group, the most-used scope.
        let station = UUID(), pushdown = UUID(), fly = UUID()
        let d1 = date(2026, 9, 1), d2 = date(2026, 9, 8), d3 = date(2026, 9, 15)
        let inputs: [MachineSetInput] = [
            .init(workoutID: UUID(), workoutStartedAt: d1, set: set(station, pushdown, 40, 10, at: d1)),
            .init(workoutID: UUID(), workoutStartedAt: d2, set: set(station, pushdown, 45, 10, at: d2)),
            .init(workoutID: UUID(), workoutStartedAt: d3, set: set(station, fly, 20, 12, at: d3)),
        ]
        let use = try! #require(GymOverviewMath.machineUse(inputs)[station])
        #expect(use.best()?.exerciseID == pushdown)
        #expect(use.best(among: [fly])?.exerciseID == fly)
        #expect(use.lastUsed(among: [pushdown]) == d2)
        #expect(use.lastUsed(among: [fly, pushdown]) == d3)
        #expect(use.best(among: [UUID()]) == nil && use.lastUsed(among: [UUID()]) == nil)
    }

    @Test func warmupOnlyWorkoutsCountAsUseButNeverAsABest() {
        // Scope A: one working workout and two warmup-only ones — used three times. Scope B: two
        // working workouts. A leads (usage); its best is the working set (Codex review 06).
        let machine = UUID(), a = UUID(), b = UUID()
        let d = (1...5).map { date(2026, 9, $0) }
        let inputs: [MachineSetInput] = [
            .init(workoutID: UUID(), workoutStartedAt: d[0], set: set(machine, a, 60, 8, at: d[0])),
            .init(workoutID: UUID(), workoutStartedAt: d[1], set: set(machine, a, 30, 12, at: d[1], type: .warmup)),
            .init(workoutID: UUID(), workoutStartedAt: d[4], set: set(machine, a, 30, 12, at: d[4], type: .warmup)),
            .init(workoutID: UUID(), workoutStartedAt: d[2], set: set(machine, b, 50, 8, at: d[2])),
            .init(workoutID: UUID(), workoutStartedAt: d[3], set: set(machine, b, 55, 8, at: d[3])),
        ]
        let use = try! #require(GymOverviewMath.machineUse(inputs)[machine])
        #expect(use.bests.map(\.exerciseID) == [a, b])
        #expect(use.bests[0].workouts == 3 && use.bests[0].lastUsed == d[4])
        #expect(use.bests[0].best.normalizedKg == 60, "the warmups never become the best")
        // A scope with nothing but warmups has usage but no best row.
        let onlyWarmups = [MachineSetInput(workoutID: UUID(), workoutStartedAt: d[0],
                                           set: set(machine, a, 30, 12, at: d[0], type: .warmup))]
        let warm = try! #require(GymOverviewMath.machineUse(onlyWarmups)[machine])
        #expect(warm.workouts == 1 && warm.sets == 1 && warm.bests.isEmpty)
    }

    @Test func aBestsChartOnAStationChartsOnlyItsExercise() {
        // Pushdowns at 40 kg three times, then one fly at 70 kg — same station, no preset, both
        // weighted. The pushdown's chart must not carry the fly's 70 kg (Codex review 06).
        let station = UUID(), pushdown = UUID(), fly = UUID()
        let d = (1...4).map { date(2026, 9, $0 * 2) }
        var inputs = (0..<3).map { i in
            MachineSetInput(workoutID: UUID(), workoutStartedAt: d[i], set: set(station, pushdown, 40, 10, at: d[i]))
        }
        inputs.append(.init(workoutID: UUID(), workoutStartedAt: d[3], set: set(station, fly, 70, 10, at: d[3])))
        let use = try! #require(GymOverviewMath.machineUse(inputs)[station])
        let best = try! #require(use.best())
        #expect(best.exerciseID == pushdown)
        let series = GymOverviewMath.series(of: best, on: station, in: inputs.map(\.set), calendar: calendar)
        #expect(series.points.count == 3)
        #expect(series.points.allSatisfy { $0.bestKg == 40 }, "only the pushdown's days")
    }

    @Test func aBestKeepsTheNamesItWasLoggedUnder() {
        let machine = UUID(), row = UUID(), narrow = UUID(), wide = UUID()
        let d1 = date(2026, 9, 1), d2 = date(2026, 9, 8)
        let inputs: [MachineSetInput] = [
            .init(workoutID: UUID(), workoutStartedAt: d1, set: set(machine, row, 60, 8, at: d1, preset: narrow),
                  exerciseName: "Seated Row", presetName: "Narrow grip"),
            .init(workoutID: UUID(), workoutStartedAt: d2, set: set(machine, row, 50, 8, at: d2, preset: wide),
                  exerciseName: "Seated Row", presetName: "Wide grip"),
        ]
        let titles = Set(try! #require(GymOverviewMath.machineUse(inputs)[machine]).bests.map(\.title))
        #expect(titles == ["Seated Row · Narrow grip", "Seated Row · Wide grip"],
                "two scopes whose live presets may be gone still read apart")
    }

    @Test func assistedBestIsTheLeastAssistanceAndATieKeepsTheEarliest() {
        let machine = UUID(), dip = UUID()
        let d1 = date(2026, 9, 1), d2 = date(2026, 9, 8), d3 = date(2026, 9, 15)
        let inputs: [MachineSetInput] = [
            .init(workoutID: UUID(), workoutStartedAt: d1, set: set(machine, dip, 40, 8, at: d1, loadType: .assisted)),
            .init(workoutID: UUID(), workoutStartedAt: d2, set: set(machine, dip, 30, 8, at: d2, loadType: .assisted)),
            .init(workoutID: UUID(), workoutStartedAt: d3, set: set(machine, dip, 30, 8, at: d3, loadType: .assisted)),
        ]
        let best = try! #require(GymOverviewMath.machineUse(inputs)[machine]?.best())
        #expect(best.loadType == .assisted)
        #expect(best.best.normalizedKg == 30, "less assistance is better")
        #expect(best.best.completedAt == d2, "a tie is not a new best: the earlier set holds it")
    }

    @Test func machineFactsFollowTheSnapshotThroughARenameAndARemodel() throws {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let press = Exercise(name: "Chest Press", loadType: .weighted, muscleGroup: "Chest")
        let gym = Gym(name: "Iron Temple")
        let oldModel = EquipmentModel(manufacturer: "OldCo", modelName: "Press A", exerciseIDs: [press.id], isSeeded: false)
        let newModel = EquipmentModel(manufacturer: "NewCo", modelName: "Press B", exerciseIDs: [press.id], isSeeded: false)
        let machine = MachineInstance(label: "Chest Press 2", gym: gym, model: oldModel)
        for object in [press, gym, oldModel, newModel, machine] as [any PersistentModel] { context.insert(object) }
        try context.save()

        let session = WorkoutSession(context: context)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = try session.startWorkout(at: gym, on: start)
        let entry = try session.addEntry(for: press, to: workout, machine: machine)
        let row = try #require(WorkoutSession.orderedSets(of: entry).first)
        row.weightUnit = .lb
        try session.commitWeight("150", for: row)
        try session.commitReps("8", for: row)
        try session.toggleCompletion(of: row, at: start.addingTimeInterval(60))
        try session.finish(workout, at: start.addingTimeInterval(3600))
        // A workout still running is not history.
        let live = try session.startWorkout(at: gym, on: start.addingTimeInterval(7200))
        let liveEntry = try session.addEntry(for: press, to: live, machine: machine)
        let liveRow = try #require(WorkoutSession.orderedSets(of: liveEntry).first)
        try session.commitWeight("500", for: liveRow)
        try session.commitReps("1", for: liveRow)
        try session.toggleCompletion(of: liveRow, at: start.addingTimeInterval(7260))

        let lifecycle = EquipmentLifecycle(context: context)
        try lifecycle.rename(machine, to: "Old Press")
        try lifecycle.correctModel(of: machine, to: newModel, scope: .futureOnly)
        try lifecycle.rename(press, to: "Machine Press")

        let entries = try SetBadgeMath.finishedEntries(in: context)
        let use = try #require(GymOverviewMath.machineUse(GymOverviewMath.machineSetInputs(finishedEntries: entries))[machine.id])
        #expect(use.workouts == 1 && use.sets == 1)
        let best = try #require(use.best())
        #expect(best.best.weightValue == 150 && best.best.weightUnit == .lb, "as entered (D52)")
        #expect(best.exerciseName == "Chest Press", "the snapshot name, not a later rename")
        #expect(best.variation(on: machine.id) == ProgressVariationKey(loadType: .weighted, equipment: .machine(machine.id), presetID: nil))

        let visits = GymOverviewMath.visits(of: gym.id, in: GymOverviewMath.visitInputs(
            try context.fetch(FetchDescriptor<Workout>())), now: start.addingTimeInterval(86_400))
        #expect(visits.visits == 1, "the running workout is not a visit")
    }

    // MARK: Words and prefill

    @Test func relativeDayWords() {
        let now = date(2026, 9, 24, 12) // Thursday
        #expect(GymOverviewMath.relativeDay(date(2026, 9, 24, 7), now: now, calendar: calendar) == "Today")
        #expect(GymOverviewMath.relativeDay(date(2026, 9, 23, 22), now: now, calendar: calendar) == "Yesterday")
        #expect(GymOverviewMath.relativeDay(date(2026, 9, 21), now: now, calendar: calendar) == "Mon")
        #expect(GymOverviewMath.relativeDay(date(2026, 9, 19), now: now, calendar: calendar) == "Sep 19",
                "last Saturday is another week")
    }

    @Test func newModelPrefillSplitsOffAKnownManufacturer() {
        let makers = ["Life Fitness", "Life", "Hammer Strength", "Cybex"]
        #expect(GymOverviewMath.newModelPrefill(query: "life fitness leg press", manufacturers: makers)
                == ("Life Fitness", "Leg Press"))
        #expect(GymOverviewMath.newModelPrefill(query: "  belt squat ", manufacturers: makers) == ("", "Belt Squat"))
        #expect(GymOverviewMath.newModelPrefill(query: "Cybex VR1 Row", manufacturers: makers) == ("Cybex", "VR1 Row"),
                "typed capitals are kept")
        #expect(GymOverviewMath.newModelPrefill(query: "cybex", manufacturers: makers) == ("", "Cybex"),
                "the maker alone is taken as the model: no empty model name")
        #expect(GymOverviewMath.newModelPrefill(query: "   ", manufacturers: makers) == ("", ""))
    }

    // MARK: Restore

    @Test func restoringADeletedGymBringsItBackWithItsMachines() throws {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let gym = Gym(name: "Hotel Gym")
        let machine = MachineInstance(label: "Leg Press", gym: gym)
        let gone = MachineInstance(label: "Old Row", archived: true, gym: gym)
        for object in [gym, machine, gone] as [any PersistentModel] { context.insert(object) }
        try context.save()
        let lifecycle = EquipmentLifecycle(context: context)
        try lifecycle.archive(gym)
        #expect(gym.activeMachines.isEmpty, "an archived gym offers no machines")
        try lifecycle.restore(gym)
        #expect(!gym.archived)
        #expect(gym.activeMachines.map(\.label) == ["Leg Press"])
        #expect(gym.archivedMachines.map(\.label) == ["Old Row"], "a machine deleted before stays deleted")
    }
}
