import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Floodlight ticket 08 — the Exercises area's readouts, all derived from finished history.

@MainActor
struct ExerciseOverviewTests {
    private let exercise = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func logged(_ kg: Double?, _ reps: Int, day: Int, workout: UUID? = nil, type: SetType = .working,
                        load: LoadType = .weighted, preset: UUID? = nil, machine: UUID? = nil,
                        completed: Bool = true) -> ExerciseLoggedSet {
        let start = t0.addingTimeInterval(Double(day) * 86_400)
        return ExerciseLoggedSet(
            setID: UUID(), workoutID: workout ?? workoutID(day), workoutStartedAt: start,
            input: RecordSetInput(loadType: load, exerciseID: exercise, gymID: nil, machineID: machine, modelID: nil,
                                  freeWeightTag: nil, presetID: preset, setType: type, reps: reps,
                                  weightValue: kg, weightUnit: .kg, normalizedKg: kg,
                                  completedAt: completed ? start.addingTimeInterval(600) : nil))
    }

    /// One stable workout id per day, so sets of the same day share a workout.
    private func workoutID(_ day: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", day + 1000))!
    }

    // MARK: Stats

    @Test func statsCountWorkoutsAndWorkingSetsAndSkipWarmups() {
        let stat = ExerciseOverview.stat(of: [
            logged(40, 10, day: 0, type: .warmup), logged(100, 8, day: 0), logged(100, 8, day: 0),
            logged(105, 6, day: 3),
        ], currentLoadType: .weighted)
        #expect(stat.workouts == 2)
        #expect(stat.workingSets == 3)
        #expect(stat.lastTrained == t0.addingTimeInterval(3 * 86_400))
        #expect(stat.best?.weightValue == 105)
        #expect(stat.lastWasNewBest)
    }

    @Test func aTieAndAFirstTimeAreNeverANewBest() {
        let tie = ExerciseOverview.stat(of: [logged(100, 8, day: 0), logged(100, 8, day: 2)], currentLoadType: .weighted)
        #expect(tie.best?.completedAt == t0.addingTimeInterval(600))   // the earlier set keeps it
        #expect(!tie.lastWasNewBest)
        let first = ExerciseOverview.stat(of: [logged(100, 8, day: 0), logged(110, 8, day: 0)], currentLoadType: .weighted)
        #expect(first.best?.weightValue == 110)
        #expect(!first.lastWasNewBest)
    }

    @Test func assistedRanksLowerAndOtherLoadTypesNeverMixIn() {
        let stat = ExerciseOverview.stat(of: [
            logged(40, 8, day: 0, load: .assisted), logged(25, 8, day: 1, load: .assisted),
            logged(10, 8, day: 2, load: .weighted),   // logged before a re-type: ranks the other way
        ], currentLoadType: .assisted)
        #expect(stat.best?.weightValue == 25)
        #expect(stat.workouts == 3)
        // The latest workout (day 2) did not set the assisted best.
        #expect(!stat.lastWasNewBest)
    }

    @Test func incompleteSetsAreNotHistory() {
        let stat = ExerciseOverview.stat(of: [logged(100, 8, day: 0, completed: false)], currentLoadType: .weighted)
        #expect(stat == ExerciseStat())
    }

    // MARK: Presets

    @Test func presetUsageCountsWorkoutsAndBestsFollowTheLoadType() {
        let narrow = UUID(), wide = UUID()
        let sets = [
            logged(80, 10, day: 0, preset: narrow), logged(85, 8, day: 0, preset: narrow),
            logged(90, 8, day: 2, preset: narrow), logged(70, 8, day: 3, preset: wide),
            logged(200, 1, day: 4, load: .bodyweightPlus, preset: wide),
        ]
        #expect(ExerciseOverview.presetUsage(sets) == [narrow: 2, wide: 2])
        let bests = ExerciseOverview.presetBests(sets, currentLoadType: .weighted)
        #expect(bests[narrow]?.weightValue == 90)
        #expect(bests[wide]?.weightValue == 70)
    }

    // MARK: Catalog

    @Test func aStoredFamilyOrAnOldBodyAreaOpensOnItsFamily() {
        #expect(ExerciseCatalog.family(stored: "Arms") == .arms)
        #expect(ExerciseCatalog.family(stored: "Biceps") == .arms)
        #expect(ExerciseCatalog.family(stored: "Core") == nil)
        #expect(ExerciseCatalog.family(stored: nil) == nil)
    }

    @Test func theFamilyFilterNeverHidesAnUncategorizedRow() {
        #expect(ExerciseCatalog.matches(muscleGroup: "Triceps", family: .arms))
        #expect(!ExerciseCatalog.matches(muscleGroup: "Quads", family: .arms))
        #expect(!ExerciseCatalog.matches(muscleGroup: "Core", family: .arms))
        #expect(ExerciseCatalog.matches(muscleGroup: nil, family: .arms))
        #expect(ExerciseCatalog.matches(muscleGroup: "Core", family: nil))
    }

    @Test func bodyAreaSectionsRunHeadToToeThenUncategorized() {
        let items = [
            ExerciseCatalogItem(id: UUID(), name: "Leg Press", muscleGroup: "Quads"),
            ExerciseCatalogItem(id: UUID(), name: "Landmine Press", muscleGroup: nil),
            ExerciseCatalogItem(id: UUID(), name: "Dip", muscleGroup: "Chest"),
            ExerciseCatalogItem(id: UUID(), name: "Bench Press", muscleGroup: "Chest"),
        ]
        let sections = ExerciseCatalog.sections(items, by: .bodyArea, now: t0)
        #expect(sections.map(\.title) == ["Chest", "Quads", "Uncategorized"])
        #expect(sections[0].items.map(\.name) == ["Bench Press", "Dip"])
        #expect(sections[0].family == .chest)
        #expect(sections[2].family == nil)
    }

    @Test func lastTrainedBucketsByTheCalendarWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        // Thursday 2026-09-24 12:00 UTC.
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))!
        func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: d, hour: 9))! }
        let items = [
            ExerciseCatalogItem(id: UUID(), name: "Monday lift", lastTrained: day(21)),
            ExerciseCatalogItem(id: UUID(), name: "Wednesday lift", lastTrained: day(23)),
            ExerciseCatalogItem(id: UUID(), name: "Last Sunday", lastTrained: day(20)),
            ExerciseCatalogItem(id: UUID(), name: "Long ago", lastTrained: day(2)),
            ExerciseCatalogItem(id: UUID(), name: "Never", lastTrained: nil),
        ]
        let sections = ExerciseCatalog.sections(items, by: .lastTrained, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["This week", "Last week", "Earlier", "Not trained yet"])
        #expect(sections[0].items.map(\.name) == ["Wednesday lift", "Monday lift"])
        #expect(sections[1].items.map(\.name) == ["Last Sunday"])
        #expect(sections.allSatisfy { !$0.showsMark })
    }

    @Test func alphabeticalSectionsAreLetters() {
        let items = ["dip", "Deadlift", "Bench Press"].map { ExerciseCatalogItem(id: UUID(), name: $0) }
        let sections = ExerciseCatalog.sections(items, by: .alphabetical, now: t0)
        #expect(sections.map(\.title) == ["B", "D"])
        #expect(sections[1].items.map(\.name) == ["Deadlift", "dip"])
    }

    // MARK: Names, dates, values

    @Test func aTakenNameIgnoresCaseAndSpacing() {
        let names = ["Bench Press", "Dip"]
        #expect(ExerciseNames.isTaken("  bench   press ", among: names))
        #expect(ExerciseNames.isTaken("DIP", among: names))
        #expect(!ExerciseNames.isTaken("Bench Press 2", among: names))
        #expect(!ExerciseNames.isTaken("   ", among: names))
    }

    @Test func relativeDatesReadTodayYesterdayWeekdayThenDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let locale = Locale(identifier: "en_US")
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))!
        func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: d, hour: 7))! }
        #expect(ExerciseDates.relative(day(24), now: now, calendar: calendar, locale: locale) == "Today")
        #expect(ExerciseDates.relative(day(23), now: now, calendar: calendar, locale: locale) == "Yesterday")
        #expect(ExerciseDates.relative(day(21), now: now, calendar: calendar, locale: locale) == "Mon")
        #expect(ExerciseDates.relative(day(17), now: now, calendar: calendar, locale: locale) == "Sep 17")
    }

    @Test func valuesFollowTheLoadTypeAndShowAForeignUnitOnly() {
        let v = SetValue(weight: 70, unit: .lb, reps: 8)
        #expect(ExerciseValueText.label(v, loadType: .weighted, userUnit: .lb) == "70 × 8")
        #expect(ExerciseValueText.label(v, loadType: .weighted, userUnit: .kg) == "70 lb × 8")
        #expect(ExerciseValueText.label(v, loadType: .assisted, userUnit: .lb) == "−70 × 8")
        #expect(ExerciseValueText.label(v, loadType: .bodyweightPlus, userUnit: .lb) == "+70 × 8")
        #expect(ExerciseValueText.label(v, loadType: .bodyweight, userUnit: .lb) == "BW × 8")
        let plain = SetValue(weight: 0, unit: .lb, reps: 12)
        #expect(ExerciseValueText.label(plain, loadType: .assisted, userUnit: .lb) == "BW × 12")
        #expect(ExerciseValueText.figure(plain, loadType: .bodyweightPlus) == "BW")
        #expect(!ExerciseValueText.figureHasUnit(plain, loadType: .bodyweightPlus))
        #expect(ExerciseValueText.spoken(v, loadType: .assisted) == "70 pounds assistance, 8 reps")
    }

    // MARK: SwiftData bridge

    private func container() throws -> ModelContainer {
        let schema = WorkoutTrackerStore.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    @discardableResult
    private func workout(_ context: ModelContext, day: Int, finished: Bool = true, exercise: Exercise,
                         machine: MachineInstance? = nil, sets: [(Double, Int, SetType)]) -> Workout {
        let start = t0.addingTimeInterval(Double(day) * 86_400)
        let workout = Workout(startedAt: start, finishedAt: finished ? start.addingTimeInterval(3600) : nil)
        context.insert(workout)
        let entry = ExerciseEntry(
            order: 0, workout: workout, exercise: exercise, machine: machine, snapshotCapturedAt: start,
            snapshotExerciseID: exercise.id, snapshotMachineID: machine?.id, snapshotGymID: machine?.gym?.id,
            snapshotLoadType: exercise.loadType, snapshotExerciseName: exercise.name,
            snapshotMachineLabel: machine?.label, snapshotGymName: machine?.gym?.name)
        context.insert(entry)
        for (index, set) in sets.enumerated() {
            context.insert(SetRecord(order: index, type: set.2, reps: set.1, weightValue: set.0, weightUnit: .kg,
                                     normalizedKg: set.0, completedAt: start.addingTimeInterval(Double(index + 1) * 60),
                                     entry: entry))
        }
        return workout
    }

    @Test func theBridgeReadsFinishedWorkoutsOnlyAndSessionsMarkNewBests() throws {
        let store = try container()
        let context = store.mainContext
        let press = Exercise(name: "Seated Chest Press", loadType: .weighted)
        context.insert(press)
        workout(context, day: 0, exercise: press, sets: [(100, 8, .working)])
        workout(context, day: 1, exercise: press, sets: [(40, 10, .warmup), (105, 8, .working), (100, 8, .working)])
        workout(context, day: 2, finished: false, exercise: press, sets: [(200, 8, .working)])
        try context.save()

        let sets = try ExerciseOverview.loggedSets(in: context)[press.id] ?? []
        #expect(sets.count == 4)
        let stat = ExerciseOverview.stat(of: sets, currentLoadType: .weighted)
        #expect(stat.best?.weightValue == 105)
        #expect(stat.lastWasNewBest)

        let finished = try SetBadgeMath.finishedEntries(in: context)
        let sessions = ExerciseOverview.recentSessions(exerciseID: press.id, finishedEntries: finished)
        #expect(sessions.count == 2)
        #expect(sessions[0].groups.flatMap(\.sets).map(\.weightValue) == [40, 105, 100])
        let best = sessions[0].groups[0].sets[1]
        #expect(sessions[0].newBestSetIDs == [best.id])
        #expect(sessions[1].newBestSetIDs.isEmpty)   // the first time is not a best
    }

    @Test func machineUsesListServingAndLoggedLiveMachinesMostUsedFirst() throws {
        let store = try container()
        let context = store.mainContext
        let press = Exercise(name: "Seated Chest Press", loadType: .weighted)
        let model = EquipmentModel(manufacturer: "Life Fitness", modelName: "Insignia", exerciseIDs: [press.id])
        let gym = Gym(name: "Iron Temple")
        let serving = MachineInstance(label: "Chest Press 2", gym: gym, model: model)
        let logged = MachineInstance(label: "Chest Press", gym: gym)
        let archived = MachineInstance(label: "Old Press", archived: true, gym: gym, model: model)
        [press].forEach { context.insert($0) }
        context.insert(model); context.insert(gym)
        [serving, logged, archived].forEach { context.insert($0) }
        workout(context, day: 0, exercise: press, machine: logged, sets: [(45, 8, .working)])
        workout(context, day: 1, exercise: press, machine: archived, sets: [(50, 8, .working)])
        try context.save()

        let sets = try ExerciseOverview.loggedSets(in: context)[press.id] ?? []
        let uses = ExerciseOverview.machineUses(
            exerciseID: press.id, currentLoadType: .weighted, sets: sets,
            machines: try context.fetch(FetchDescriptor<MachineInstance>()))
        #expect(uses.map(\.label) == ["Chest Press", "Chest Press 2"])
        #expect(uses[0].workouts == 1)
        #expect(uses[0].best?.weightValue == 45)
        #expect(uses[1].workouts == 0)
        #expect(uses[1].best == nil)
    }

    // MARK: codex-review-08

    private func set(_ kg: Double, _ reps: Int, workout: UUID, started: Date, at completed: Date) -> ExerciseLoggedSet {
        ExerciseLoggedSet(setID: UUID(), workoutID: workout, workoutStartedAt: started,
                          input: RecordSetInput(loadType: .weighted, exerciseID: exercise, gymID: nil, machineID: nil,
                                                modelID: nil, freeWeightTag: .barbell, presetID: nil, setType: .working,
                                                reps: reps, weightValue: kg, weightUnit: .kg, normalizedKg: kg,
                                                completedAt: completed))
    }

    private var barbell: ProgressVariationKey {
        ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.barbell), presetID: nil)
    }

    /// Two workouts on one day: the evening's best is a new best, though the chart has one point.
    @Test func aVariationsNewBestIsJudgedByWorkoutNotByDay() {
        let morning = t0, evening = t0.addingTimeInterval(9 * 3600)
        let stat = ExerciseOverview.variationStat(of: [
            set(100, 8, workout: workoutID(1), started: morning, at: morning.addingTimeInterval(600)),
            set(110, 8, workout: workoutID(2), started: evening, at: evening.addingTimeInterval(600)),
        ], variation: barbell)
        #expect(stat.best?.weightValue == 110)
        #expect(stat.lastWasNewBest)
    }

    /// One first-ever workout across midnight: two chart days, but no earlier workout — no new best.
    @Test func aFirstWorkoutAcrossMidnightIsNotANewBest() {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let start = calendar.date(bySettingHour: 23, minute: 40, second: 0, of: t0)!
        let stat = ExerciseOverview.variationStat(of: [
            set(100, 8, workout: workoutID(1), started: start, at: start.addingTimeInterval(600)),
            set(110, 8, workout: workoutID(1), started: start, at: start.addingTimeInterval(1800)),
        ], variation: barbell)
        #expect(stat.best?.weightValue == 110)
        #expect(!stat.lastWasNewBest)
    }

    /// A later, lighter workout means the latest session did not set the best.
    @Test func aLaterLighterWorkoutClearsTheMark() {
        let stat = ExerciseOverview.variationStat(of: [
            set(100, 8, workout: workoutID(1), started: t0, at: t0.addingTimeInterval(600)),
            set(110, 8, workout: workoutID(2), started: t0.addingTimeInterval(3600), at: t0.addingTimeInterval(4200)),
            set(90, 8, workout: workoutID(3), started: t0.addingTimeInterval(7200), at: t0.addingTimeInterval(7800)),
        ], variation: barbell)
        #expect(!stat.lastWasNewBest)
    }

    @Test func sessionsKeepEachEntrysOwnContext() throws {
        let store = try container()
        let context = store.mainContext
        let pull = Exercise(name: "Assisted Pull-Up", loadType: .assisted)
        context.insert(pull)
        let start = t0
        let workout = Workout(startedAt: start, finishedAt: start.addingTimeInterval(3600))
        context.insert(workout)
        // Narrow grip, then wide grip; the wide entry was re-typed in History to Weighted.
        for (order, preset, load) in [(0, "Narrow grip", LoadType.assisted), (1, "Wide grip", LoadType.weighted)] {
            let entry = ExerciseEntry(order: order, workout: workout, exercise: pull, snapshotCapturedAt: start,
                                      snapshotExerciseID: pull.id, snapshotLoadType: load,
                                      snapshotExerciseName: pull.name, snapshotPresetID: UUID(), snapshotPresetName: preset)
            context.insert(entry)
            context.insert(SetRecord(order: 0, reps: 8, weightValue: 25, weightUnit: .kg, normalizedKg: 25,
                                     completedAt: start.addingTimeInterval(Double(order + 1) * 300), entry: entry))
        }
        try context.save()
        let sessions = ExerciseOverview.recentSessions(
            exerciseID: pull.id, finishedEntries: try SetBadgeMath.finishedEntries(in: context))
        #expect(sessions.count == 1)
        #expect(sessions[0].groups.map(\.equipment) == ["Narrow grip", "Wide grip"])
        #expect(sessions[0].groups.map(\.loadType) == [.assisted, .weighted])
        #expect(sessions[0].groups.map { $0.sets.count } == [1, 1])
    }

    @Test func theLedgerCountsSetsByTheTypeTheyWereLoggedUnder() throws {
        let store = try container()
        let context = store.mainContext
        let dip = Exercise(name: "Dip", loadType: .weighted)
        context.insert(dip)
        workout(context, day: 0, exercise: dip, sets: [(10, 8, .working), (10, 8, .working), (10, 8, .working)])
        try context.save()
        // Corrected to Assisted: the three sets stay Weighted.
        dip.loadType = .assisted
        workout(context, day: 1, exercise: dip, sets: [(20, 8, .working)])
        try context.save()
        let counts = ExerciseOverview.loggedSetCounts(of: dip)
        #expect(counts.map(\.loadType) == [.weighted, .assisted])
        #expect(counts.map(\.sets) == [3, 1])
    }
}
