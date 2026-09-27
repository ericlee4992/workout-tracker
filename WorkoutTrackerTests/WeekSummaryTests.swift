import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Floodlight redesign — the Workout tab's "This week" card and the template tiles' stats are
// derived from finished workouts. The rules: a running workout is not history; a workout
// belongs to the day it started; warmups never count; every load type counts toward its family;
// an exercise with no family counts toward none.

struct WeekSummaryTests {
    /// Monday-first Gregorian calendar in UTC, so the dates below are unambiguous.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 18, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func input(_ start: Date, minutes: Int = 60, lifting: Bool = true, cardio: Bool = false,
                       sets: [MuscleFamily: Int] = [:]) -> WeekSummaryInput {
        WeekSummaryInput(id: UUID(), title: "W", startedAt: start, durationSeconds: minutes * 60,
                         hasLifting: lifting, hasCardio: cardio, familySets: sets)
    }

    @Test func weekRunsFromTheCalendarsFirstWeekdayAndMarksToday() {
        // Thursday 24 September 2026.
        let summary = WeekSummaryMath.summary(of: [], now: date(24), calendar: calendar)
        #expect(summary.days.count == 7)
        #expect(summary.days.first?.date == calendar.startOfDay(for: date(21)))
        #expect(summary.days.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(summary.days.map(\.isToday) == [false, false, false, true, false, false, false])
        #expect(summary.days.map(\.isFuture) == [false, false, false, false, true, true, true])
        #expect(summary.workoutCount == 0 && summary.minutes == 0 && summary.lastWeekWorkoutCount == 0)
        #expect(summary.setsByFamily.map(\.family) == MuscleFamily.allCases)
        #expect(summary.setsByFamily.allSatisfy { $0.sets == 0 })
    }

    @Test func countsThisWeekOnlyAndLastWeekSeparately() {
        let workouts = [
            input(date(21), minutes: 77, sets: [.back: 10, .arms: 4]),
            input(date(23), minutes: 55, sets: [.legs: 13, .shoulders: 3]),
            input(date(23, 7), minutes: 20, lifting: false, cardio: true),
            input(date(16)), input(date(15)), input(date(14)), input(date(20, 23)),
            input(date(13)), // two weeks back: neither week
        ]
        let summary = WeekSummaryMath.summary(of: workouts, now: date(24), calendar: calendar)
        #expect(summary.workoutCount == 3)
        #expect(summary.trainingDayCount == 2)
        #expect(summary.minutes == 77 + 55 + 20)
        #expect(summary.lastWeekWorkoutCount == 4)
        #expect(summary.setsByFamily == [
            FamilyCount(family: .chest, sets: 0), FamilyCount(family: .back, sets: 10),
            FamilyCount(family: .shoulders, sets: 3), FamilyCount(family: .arms, sets: 4),
            FamilyCount(family: .legs, sets: 13)])
        // Same-day workouts in start order; the morning cardio first.
        let wednesday = summary.days[2].workouts
        #expect(wednesday.map(\.kind) == [.cardio, .lifting])
        #expect(wednesday.last?.families == [.shoulders, .legs])
    }

    @Test func mixedWorkoutIsMixedAndMinutesRoundDown() {
        let summary = WeekSummaryMath.summary(
            of: [input(date(22), minutes: 0, cardio: true)], now: date(24), calendar: calendar)
        #expect(summary.days[1].workouts.first?.kind == .mixed)
        let short = WeekSummaryInput(id: UUID(), title: "W", startedAt: date(22), durationSeconds: 119,
                                     hasLifting: true, hasCardio: false, familySets: [:])
        #expect(WeekSummaryMath.summary(of: [short], now: date(24), calendar: calendar).minutes == 1)
    }

    @Test @MainActor func inputSkipsRunningWorkoutsWarmupsAndFamilylessExercises() throws {
        let container = try ModelContainer(
            for: WorkoutTrackerStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let press = Exercise(name: "Chest Press", loadType: .weighted, muscleGroup: "Chest")
        let pullUp = Exercise(name: "Pull-Up", loadType: .bodyweight, muscleGroup: "Back")
        let plank = Exercise(name: "Plank", loadType: .bodyweight, muscleGroup: "Core")
        [press, pullUp, plank].forEach(context.insert)

        let workout = Workout(startedAt: date(22), finishedAt: date(22, 19))
        context.insert(workout)
        func entry(_ exercise: Exercise, _ types: [SetType], completed: Bool = true) {
            let entry = ExerciseEntry(order: 0, workout: workout, exercise: exercise,
                                      snapshotExerciseID: exercise.id, snapshotLoadType: exercise.loadType,
                                      snapshotExerciseName: exercise.name)
            context.insert(entry)
            for (index, type) in types.enumerated() {
                let set = SetRecord(order: index, type: type, reps: 8)
                set.completedAt = completed ? date(22, 18) : nil
                set.entry = entry
                context.insert(set)
            }
        }
        entry(press, [.warmup, .working, .working, .drop])
        entry(pullUp, [.working, .failure])
        entry(plank, [.working])
        entry(press, [.working], completed: false)

        let running = Workout(startedAt: date(23))
        context.insert(running)
        try context.save()

        #expect(WeekSummaryInput(workout: running) == nil)
        let input = try #require(WeekSummaryInput(workout: workout))
        #expect(input.familySets == [.chest: 3, .back: 2])
        #expect(input.hasLifting && !input.hasCardio)
        #expect(input.durationSeconds == 3600)
    }

    @Test func templateStatsCountFinishedRunsOnly() {
        #expect(TemplateStats.make(runs: []) == .none)
        let stats = TemplateStats.make(runs: [(date(10), 3000), (date(17), 3600), (date(3), 2400)])
        #expect(stats.timesRun == 3)
        #expect(stats.lastRun == date(17))
        #expect(stats.averageDurationSeconds == 3000)
    }

    @Test func aDaysMinutesRoundOnceAcrossItsWorkouts() {
        let a = WeekSummaryInput(id: UUID(), title: "A", startedAt: date(23, 7), durationSeconds: 30 * 60 + 59,
                                 hasLifting: true, hasCardio: false, familySets: [:])
        var b = a
        b.id = UUID()
        b.startedAt = date(23, 18)
        let summary = WeekSummaryMath.summary(of: [a, b], now: date(24), calendar: calendar)
        #expect(summary.days[2].minutes == 61)
        #expect(summary.minutes == 61)
    }
}
