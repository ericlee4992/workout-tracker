import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Floodlight redesign ticket 05 — History's derived overview: month figures, the day strip's
// intensity, week grouping and titles, each row's facts (new-best count judged against the
// past only, volume without warmups, unit badge), and the History edits the detail adds
// (Add Set, notes).

struct HistoryOverviewTests {
    /// A fixed Gregorian calendar (US: Sunday first) so weeks and titles are deterministic.
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

    private func facts(_ start: Date, sets: Int, minutes: Int = 60, cardio: Bool = false) -> HistoryWorkoutFacts {
        HistoryWorkoutFacts(id: UUID(), startedAt: start, durationSeconds: minutes * 60, sets: sets,
                            hasLifting: sets > 0, hasCardio: cardio)
    }

    // MARK: Month, days, weeks

    @Test func monthSummaryAddsTheMonthsRowsOnly() {
        let items = [facts(date(2026, 9, 2), sets: 14, minutes: 55),
                     facts(date(2026, 9, 23), sets: 18, minutes: 48),
                     facts(date(2026, 8, 30), sets: 20)]
        let summary = HistoryOverviewMath.monthSummary(items, month: date(2026, 9, 15), calendar: calendar)
        #expect(summary.workouts == 2)
        #expect(summary.sets == 32)
        #expect(summary.seconds == (55 + 48) * 60)
        #expect(abs(summary.hours - 103.0 / 60) < 0.0001)
    }

    @Test func intensityStepsBySetsAndATrainedDayIsNeverDark() {
        #expect(HistoryOverviewMath.intensity(sets: 0, trained: false) == 0)
        #expect(HistoryOverviewMath.intensity(sets: 0, trained: true) == 1, "a cardio-only day still lights")
        #expect(HistoryOverviewMath.intensity(sets: 11, trained: true) == 1)
        #expect(HistoryOverviewMath.intensity(sets: 12, trained: true) == 2)
        #expect(HistoryOverviewMath.intensity(sets: 20, trained: true) == 3)
        #expect(HistoryOverviewMath.intensity(sets: 28, trained: true) == 4)
    }

    @Test func daysCoverTheMonthAndSumEachDaysWorkouts() {
        let morning = facts(date(2026, 9, 21, 7), sets: 0, cardio: true)
        let evening = facts(date(2026, 9, 21, 18), sets: 18)
        let days = HistoryOverviewMath.days(inMonthOf: date(2026, 9, 1), facts: [evening, morning],
                                            now: date(2026, 9, 24, 12), calendar: calendar)
        #expect(days.count == 30)
        let day = days[20]
        #expect(day.dayNumber == 21)
        #expect(day.sets == 18 && day.intensity == 2)
        #expect(day.workoutIDs == [morning.id, evening.id], "oldest first")
        #expect(day.hasCardio && day.hasLifting)
        #expect(days[23].isToday && !days[23].isFuture)
        #expect(days[24].isFuture)
        #expect(days[5].isWeekStart, "Sep 6, 2026 is a Sunday — the US first weekday")
    }

    @Test func weeksGroupNewestFirstAndAWeekAcrossAMonthEndStaysWhole() {
        let now = date(2026, 9, 24, 12)          // Thursday
        let thisWeek = facts(date(2026, 9, 23), sets: 14)
        let lastWeek = facts(date(2026, 9, 19), sets: 20)
        let aug31 = facts(date(2026, 8, 31), sets: 10)   // Mon of the week Aug 30 – Sep 5
        let sep2 = facts(date(2026, 9, 2), sets: 12)
        let aug20 = facts(date(2026, 8, 20), sets: 16)
        let months = HistoryOverviewMath.sections([aug31, thisWeek, aug20, sep2, lastWeek], now: now, calendar: calendar)

        #expect(months.count == 2)
        #expect(months[0].weeks.map(\.title) == ["This week", "Last week", "Aug 30 – Sep 5"])
        #expect(months[0].weeks[2].workoutIDs == [sep2.id, aug31.id], "newest first; filed under its newest workout's month")
        #expect(months[1].weeks.map(\.title) == ["Aug 16 – 22"])
    }

    @Test func unitBadgeOnlyWhenItSaysSomething() {
        var item = facts(date(2026, 9, 2), sets: 3)
        item.units = [.lb]
        #expect(item.unitBadge(appUnit: .lb) == nil)
        #expect(item.unitBadge(appUnit: .kg) == "lb")
        item.units = [.kg, .lb]
        #expect(item.unitBadge(appUnit: .lb) == "kg + lb")
        item.units = []
        #expect(item.unitBadge(appUnit: .kg) == nil)
    }

    // MARK: Row facts from the store

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Fixture {
        var context: ModelContext
        var press: Exercise
        var pulldown: Exercise
        var gym: Gym
        var machine: MachineInstance
    }

    private func fixture() throws -> Fixture {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let press = Exercise(name: "Chest Press", loadType: .weighted, muscleGroup: "Chest")
        let pulldown = Exercise(name: "Assisted Pull-up", loadType: .assisted, muscleGroup: "Back")
        let gym = Gym(name: "Iron Temple")
        let machine = MachineInstance(label: "Chest Press 2", gym: gym, model: nil)
        for object in [press, pulldown, gym, machine] as [any PersistentModel] { context.insert(object) }
        try context.save()
        return Fixture(context: context, press: press, pulldown: pulldown, gym: gym, machine: machine)
    }

    /// One finished workout: per exercise, sets of (weight, reps, warmup?, unit).
    @discardableResult
    private func workout(_ f: Fixture, at start: Date,
                         _ blocks: [(Exercise, [(Double, Int, Bool, WeightUnit)])]) throws -> Workout {
        let session = WorkoutSession(context: f.context)
        let workout = try session.startWorkout(at: f.gym, on: start)
        var minute = 1.0
        for (exercise, sets) in blocks {
            let entry = try session.addEntry(for: exercise, to: workout,
                                             machine: exercise === f.press ? f.machine : nil)
            var rows = WorkoutSession.orderedSets(of: entry)
            while rows.count < sets.count { _ = try session.addSet(to: entry); rows = WorkoutSession.orderedSets(of: entry) }
            for (index, value) in sets.enumerated() {
                let row = rows[index]
                if value.2 { row.type = .warmup }
                row.weightUnit = value.3
                try session.commitWeight(String(value.0), for: row)
                try session.commitReps(String(value.1), for: row)
                try session.toggleCompletion(of: row, at: start.addingTimeInterval(minute * 60))
                minute += 1
            }
        }
        try session.finish(workout, at: start.addingTimeInterval(3600))
        return workout
    }

    private func allFacts(_ f: Fixture) throws -> [UUID: HistoryWorkoutFacts] {
        let workouts = try f.context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil }))
        return HistoryOverviewMath.facts(for: workouts, finishedEntries: try SetBadgeMath.finishedEntries(in: f.context))
    }

    @Test func newBestsCountScopesJudgedAgainstThePastOnly() throws {
        let f = try fixture()
        let day = 86_400.0
        let first = try workout(f, at: t0, [(f.press, [(100, 5, false, .kg)]), (f.pulldown, [(40, 8, false, .kg)])])
        // Heavier press (a best), and less assistance (assisted: lower is better — a best too).
        let second = try workout(f, at: t0 + day, [(f.press, [(105, 5, false, .kg)]), (f.pulldown, [(30, 8, false, .kg)])])
        // A tie on the press and more assistance: no bests. A heavy WARMUP never counts.
        let third = try workout(f, at: t0 + 2 * day, [(f.press, [(200, 5, true, .kg), (105, 5, false, .kg)]),
                                                      (f.pulldown, [(35, 8, false, .kg)])])
        let facts = try allFacts(f)
        #expect(facts[first.id]?.newBests == 0, "a first time is not a best")
        #expect(facts[second.id]?.newBests == 2)
        #expect(facts[third.id]?.newBests == 0)

        // A later, heavier press does not change what an earlier workout set.
        try workout(f, at: t0 + 3 * day, [(f.press, [(120, 5, false, .kg)])])
        #expect(try allFacts(f)[second.id]?.newBests == 2)
    }

    @Test func rowFactsCountCompletedSetsAndWeightedVolumeWithoutWarmups() throws {
        let f = try fixture()
        let w = try workout(f, at: t0, [(f.press, [(20, 10, true, .kg), (100, 5, false, .kg)]),
                                        (f.pulldown, [(40, 8, false, .lb)])])
        let item = try #require(try allFacts(f)[w.id])
        #expect(item.sets == 3, "warmups count toward the row's sets, as on the receipt")
        #expect(abs(item.volumeKg - 500) < 0.001, "warmups and assisted loads are not volume")
        #expect(item.families == [.chest, .back])
        #expect(item.units == [.kg, .lb])
        #expect(item.unitBadge(appUnit: .kg) == "kg + lb")
        #expect(item.hasLifting && !item.hasCardio && !item.isEdited)
    }

    // MARK: History edits

    @Test func addSetIsMarkedAndAnAbandonedSetLeavesNothing() throws {
        let f = try fixture()
        let w = try workout(f, at: t0, [(f.press, [(100, 5, false, .lb)])])
        let entry = try #require(WorkoutSession.orderedEntries(of: w).first)
        let added = try #require(HistoryEditing.addSet(to: entry, in: f.context, at: t0 + 7200))
        #expect(WorkoutSession.orderedSets(of: entry).count == 2)
        #expect(added.weightUnit == .lb, "the exercise's last unit")
        #expect(added.completedAt != nil && added.type == .working)
        #expect(w.historyEditedAt == t0 + 7200)

        #expect(HistoryEditing.pruneAbandonedSet(added, in: f.context))
        try f.context.save()
        #expect(WorkoutSession.orderedSets(of: entry).count == 1, "the logged set stays")

        let running = try WorkoutSession(context: f.context).startWorkout(at: f.gym, on: t0 + 10_000)
        let live = try WorkoutSession(context: f.context).addEntry(for: f.press, to: running, machine: nil)
        #expect(HistoryEditing.addSet(to: live, in: f.context) == nil, "a running workout is not history")
    }

    @Test func notesAreTrimmedMarkedAndRefusedOnARunningWorkout() throws {
        let f = try fixture()
        let w = try workout(f, at: t0, [(f.press, [(100, 5, false, .kg)])])
        #expect(HistoryEditing.setNotes(w, to: "  Bench moved fast.\n", at: t0 + 100))
        #expect(w.notes == "Bench moved fast.")
        #expect(w.historyEditedAt == t0 + 100)
        #expect(!HistoryEditing.setNotes(w, to: "Bench moved fast.", at: t0 + 200), "unchanged")
        #expect(w.historyEditedAt == t0 + 100)

        let running = try WorkoutSession(context: f.context).startWorkout(at: f.gym, on: t0 + 10_000)
        #expect(!HistoryEditing.setNotes(running, to: "hi"))
        #expect(running.historyEditedAt == nil)
    }
}
