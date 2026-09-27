import Foundation

// The Workout tab's "This week" card (Floodlight redesign): what was trained this week, derived
// from finished workouts. Pure values; the builder lives beside them.

/// Completed working sets in one muscle family.
struct FamilyCount: Identifiable, Hashable {
    var id: MuscleFamily { family }
    var family: MuscleFamily
    var sets: Int
}

enum DayWorkoutKind: Hashable {
    case lifting
    case cardio
    case mixed
}

/// One finished workout on a day of the week strip.
struct DayWorkout: Identifiable, Hashable {
    var id: UUID { workoutID }
    var workoutID: UUID
    var title: String
    var kind: DayWorkoutKind
    var families: [MuscleFamily]
    var minutes: Int
    var sets: Int
}

struct WeekDaySummary: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    /// "M", "T", …
    var letter: String
    var isToday: Bool
    var isFuture: Bool
    var workouts: [DayWorkout]
}

struct WeekSummary: Hashable {
    /// The week's days in calendar order.
    var days: [WeekDaySummary]
    var workoutCount: Int
    /// Days with at least one workout.
    var trainingDayCount: Int
    /// Completed non-warmup sets per family, head to toe; zero families included.
    var setsByFamily: [FamilyCount]
    var minutes: Int
    var lastWeekWorkoutCount: Int
}

// MARK: - Building the week

/// One finished workout as the week card reads it. Built from a `Workout` by
/// `init?(workout:)`; plain values so the week math is testable without a store.
struct WeekSummaryInput: Hashable {
    var id: UUID
    var title: String
    var startedAt: Date
    var durationSeconds: Int
    var hasLifting: Bool
    var hasCardio: Bool
    /// Completed non-warmup sets per family.
    var familySets: [MuscleFamily: Int]
}

extension WeekSummaryInput {
    /// nil for a workout still running: it is not history yet.
    ///
    /// Family counts read the LIVE `exercise.muscleGroup` — muscle group is not snapshotted
    /// (D23 covers names, not muscles), so an exercise without a group counts toward no family.
    /// Every load type counts (a pull-up is a back set); warmups never do (D12/D26).
    init?(workout: Workout) {
        guard workout.finishedAt != nil else { return nil }
        var counts: [MuscleFamily: Int] = [:]
        var liftingSets = 0
        for entry in WorkoutSession.orderedEntries(of: workout) {
            let sets = (entry.sets ?? []).filter { $0.completedAt != nil && $0.type.countsTowardRecords }
            liftingSets += (entry.sets ?? []).filter { $0.completedAt != nil }.count
            guard !sets.isEmpty, let family = MuscleFamily(muscleGroup: entry.exercise?.muscleGroup) else { continue }
            counts[family, default: 0] += sets.count
        }
        self.init(
            id: workout.id,
            title: workout.historyTitle,
            startedAt: workout.startedAt,
            durationSeconds: Int(workout.duration ?? 0),
            hasLifting: liftingSets > 0,
            hasCardio: !workout.recordedCardio.isEmpty,
            familySets: counts)
    }
}

enum WeekSummaryMath {
    /// The week containing `now` in `calendar` (its locale's first weekday — the same weeks
    /// History's calendar draws). Workouts belong to the day they STARTED on, as everywhere in
    /// History (`WorkoutCalendar`). `lastWeekWorkoutCount` is the previous calendar week.
    static func summary(of workouts: [WeekSummaryInput], now: Date, calendar: Calendar = .current) -> WeekSummary {
        let today = calendar.startOfDay(for: now)
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let letters = calendar.veryShortWeekdaySymbols
        var days: [WeekDaySummary] = []
        var counts: [MuscleFamily: Int] = [:]
        var seconds = 0
        var total = 0
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let items = workouts
                .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                .sorted { $0.startedAt < $1.startedAt }
            for workout in items {
                seconds += workout.durationSeconds
                for (family, sets) in workout.familySets { counts[family, default: 0] += sets }
            }
            total += items.count
            days.append(WeekDaySummary(
                date: day,
                letter: letters[calendar.component(.weekday, from: day) - 1],
                isToday: day == today,
                isFuture: day > today,
                workouts: items.map(dayWorkout)))
        }
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start
        let lastWeek = workouts.filter { $0.startedAt >= lastWeekStart && $0.startedAt < start }.count
        return WeekSummary(
            days: days,
            workoutCount: total,
            trainingDayCount: days.filter { !$0.workouts.isEmpty }.count,
            setsByFamily: MuscleFamily.allCases.map { FamilyCount(family: $0, sets: counts[$0] ?? 0) },
            minutes: seconds / 60,
            lastWeekWorkoutCount: lastWeek)
    }

    private static func dayWorkout(_ input: WeekSummaryInput) -> DayWorkout {
        let kind: DayWorkoutKind = input.hasLifting && input.hasCardio ? .mixed
            : (input.hasCardio ? .cardio : .lifting)
        return DayWorkout(
            workoutID: input.id, title: input.title, kind: kind,
            families: MuscleFamily.allCases.filter { (input.familySets[$0] ?? 0) > 0 },
            minutes: input.durationSeconds / 60,
            sets: input.familySets.values.reduce(0, +))
    }
}
