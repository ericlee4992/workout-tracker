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
//
// Floodlight redesign ticket 11: the state grew to carry the prototype's three states
// (resting / ready / cardio) and how the last rest ended. Every field added then is optional,
// so a payload from an older build still decodes (synthesised `Decodable` reads optionals with
// `decodeIfPresent`).

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

        /// The zone's level 1…5 for the meter (0 = warm-up), with `zoneLabel`'s D45 rule.
        var zoneLevel: Int?
        /// Every set in the workout, done or not ("7/18").
        var totalSets: Int?
        /// When the current rest started: with `restEndsAt`, the ring's span.
        var restStartedAt: Date?
        /// How the current rest runs (timer, heart-rate target, or the timer a heart-rate rest
        /// fell back to). Lets the card say how a rest ended when it ends unobserved.
        var rest: RestKind?
        /// The set that started this rest was a new best (`SetBadgeMath`).
        var restFollowsNewBest: Bool?
        /// How the last rest ended, when the app saw it end (recovered, or after expiry).
        var restResult: RestResult?
        /// The next set to do, when there is one.
        var next: NextSet?
        /// The running cardio segment, when there is one.
        var cardio: Cardio?
        /// The workout's name (the cardio card's header).
        var workoutTitle: String?

        init(heartRateBpm: Int? = nil, zoneLabel: String? = nil, restEndsAt: Date? = nil,
             completedSets: Int, currentExercise: String? = nil, zoneLevel: Int? = nil,
             totalSets: Int? = nil, restStartedAt: Date? = nil, rest: RestKind? = nil,
             restFollowsNewBest: Bool? = nil, restResult: RestResult? = nil, next: NextSet? = nil,
             cardio: Cardio? = nil, workoutTitle: String? = nil) {
            self.heartRateBpm = heartRateBpm
            self.zoneLabel = zoneLabel
            self.restEndsAt = restEndsAt
            self.completedSets = completedSets
            self.currentExercise = currentExercise
            self.zoneLevel = zoneLevel
            self.totalSets = totalSets
            self.restStartedAt = restStartedAt
            self.rest = rest
            self.restFollowsNewBest = restFollowsNewBest
            self.restResult = restResult
            self.next = next
            self.cardio = cardio
            self.workoutTitle = workoutTitle
        }
    }

    enum RestKind: Codable, Hashable {
        /// The standard timer (D22).
        case timer
        /// A heart-rate rest (D43): ends early under the target, else at its cap.
        case heartRate(targetBpm: Int)
        /// A heart-rate rest that fell back to the timer: no reading arrived (D43).
        case fallback
    }

    /// How a rest ended (Z03), drawn in the card beside the system's notification.
    enum RestResult: Codable, Hashable {
        case timer(seconds: Int)
        case recovered(bpm: Int, targetBpm: Int)
        case cap(bpm: Int?, targetBpm: Int, capSeconds: Int)
        case noReading(seconds: Int)
    }

    struct NextSet: Codable, Hashable {
        /// The set's marker: its working number ("3") or its type ("W", "D", "F").
        var marker: String
        /// "A" / "B" when the next set is in a superset.
        var supersetLetter: String?
        /// The exercise the next set belongs to (the header once rest is over).
        var exerciseName: String
        /// The live rest bar's own line: "Next · Set 3 · 110 lb × 8" / "Next · <exercise>".
        var line: String
        /// The drafted value, split for big numbers and small units; nil when not drafted.
        var weight: String?
        var unit: String?
        var reps: Int?
        /// Last time's value for this set ("105 lb × 8").
        var previous: String?
    }

    struct Cardio: Codable, Hashable {
        var activity: String
        var symbol: String
        var isPaused: Bool
        /// Running: the instant the segment's active clock read zero (now − active time), so
        /// the system can tick it. nil while paused.
        var clockStart: Date?
        /// Paused: the frozen clock. Running: the time banked before the current stretch (the
        /// live figure is `now − clockStart`; see `activeSeconds(at:)`).
        var elapsedSeconds: Int
        var distance: String?
        var distanceUnit: String?
        /// Pace ("8:43", "/mi") or speed ("12.4", "mi/h"), per the activity (D52 plain numbers).
        var rate: String?
        var rateUnit: String?
        /// The planned target the segment was started from (D57), in minutes.
        var targetMinutes: Int?

        func activeSeconds(at now: Date) -> Int {
            guard let clockStart, !isPaused else { return elapsedSeconds }
            return max(0, Int(now.timeIntervalSince(clockStart)))
        }
    }

    /// Fixed for the life of the activity.
    var workoutID: UUID
    var startedAt: Date
    var gymName: String?
}

// MARK: - What the card shows (pure; unit-tested in the app target)

extension WorkoutActivityAttributes.ContentState {
    enum Phase: Hashable { case resting, ready, cardio }

    /// Resting while a rest runs; ready once it has ended — at `now`, or when the system marks
    /// the content stale (the app sets the stale date to the rest's end, so an app that is not
    /// running at that instant still gets its card redrawn in the ready state).
    func phase(at now: Date, isStale: Bool) -> Phase {
        if cardio != nil { return .cardio }
        if let end = restEndsAt, end > now, !isStale { return .resting }
        return .ready
    }

    /// The rest ring's fraction left at `now` (1 → 0).
    func restFractionLeft(at now: Date) -> Double {
        guard let end = restEndsAt, let start = restStartedAt, end > start else { return 0 }
        return max(0, min(1, end.timeIntervalSince(now) / end.timeIntervalSince(start)))
    }

    /// How the last rest ended, once it has: what the app saw, else what the plan implies for a
    /// rest that ran out unobserved (a timer ran its length; a heart-rate rest reached its cap
    /// with the last reading; a fallback ran the timer).
    func shownResult(at now: Date, isStale: Bool) -> WorkoutActivityAttributes.RestResult? {
        guard phase(at: now, isStale: isStale) == .ready else { return nil }
        if let restResult { return restResult }
        guard let end = restEndsAt, let start = restStartedAt, let rest else { return nil }
        let seconds = Int(end.timeIntervalSince(start).rounded())
        switch rest {
        case .timer: return .timer(seconds: seconds)
        case .heartRate(let target): return .cap(bpm: heartRateBpm, targetBpm: target, capSeconds: seconds)
        case .fallback: return .noReading(seconds: seconds)
        }
    }

    /// The header's name: the exercise you are on; once rest is over, the one you move to;
    /// in cardio, the workout (its clock sits beside it).
    func headerTitle(at now: Date, isStale: Bool) -> String {
        switch phase(at: now, isStale: isStale) {
        case .cardio: return workoutTitle ?? cardio?.activity ?? "Workout"
        case .resting: return currentExercise ?? next?.exerciseName ?? workoutTitle ?? "Workout"
        case .ready: return next?.exerciseName ?? currentExercise ?? workoutTitle ?? "Workout"
        }
    }
}
