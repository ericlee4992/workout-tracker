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
