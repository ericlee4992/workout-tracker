import ActivityKit
import Foundation

// Milestone 8, ticket 05 — the workout on the lock screen (D46 applied).
//
// This file compiles into BOTH the app and the widget extension, so the two can
// never drift about the shape of what they are exchanging — the same
// arrangement `WatchLink.swift` uses for the watch.
//
// WHY THIS IS A GOOD FIT FOR D46: the app pushes state, and the SYSTEM renders
// and counts down. Nothing has to execute at a deadline. That is the trap that
// cost four attempts on the rest alarm — the rest countdown here is a
// `timerInterval`, ticked by the system, not by us.

struct WorkoutActivityAttributes: ActivityAttributes {

    /// What changes during the workout. Everything the lock screen shows lives
    /// here; `ContentState` is the only thing an update can move.
    struct ContentState: Codable, Hashable {
        /// Live heart rate, or nil when no sensor is reporting. Absent means
        /// "not measured" and must render as such — never as zero, which would
        /// be a reading the app does not have (D44's rule, same as export).
        var heartRateBpm: Int?
        /// Zone label ("Zone 3"), only when a maximum exists to compute it
        /// against (D45). nil = show no zone rather than inventing a basis.
        var zoneLabel: String?
        /// When the current rest ends. The system ticks this down itself.
        var restEndsAt: Date?
        /// Total completed sets so far, for a glanceable sense of progress.
        var completedSets: Int
        /// The exercise being worked, from the frozen snapshot where there is
        /// one (D23).
        var currentExercise: String?
    }

    /// Fixed for the life of the activity.
    var workoutID: UUID
    var startedAt: Date
    var gymName: String?
}
