import Foundation

// Public beta ticket 16 (D63): the numbers behind a cardio activity's progress — the Progress tab's cardio panels and
// the cardio progress screen. Pure over finished workouts, so the series can be proven without rendering.
//
// A SESSION is one finished workout's recorded segments of one activity, combined: "run, lift, run" is one run that
// day, not two. Distances are stored in metres and shown in the app's distance unit (D52: a plain conversion). Pace is
// per km or mile, except rowing, which is per 500 m whatever the unit (the rowing convention); cycling shows speed.

struct CardioProgressSession: Equatable, Identifiable, Sendable {
    var id: UUID { workoutID }
    let workoutID: UUID
    /// When the first of the workout's segments of this activity started.
    let date: Date
    /// Summed over the segments that have one; nil when none does (no source and nothing entered).
    let meters: Double?
    /// Active seconds (pauses excluded), summed.
    let seconds: Double
    /// Average over every heart-rate sample of these segments; nil without any.
    let heartRate: Int?
}

struct CardioProgressPoint: Equatable, Identifiable, Sendable {
    var id: UUID { workoutID }
    let workoutID: UUID
    let date: Date
    let value: Double
    /// Better than every earlier session (the first is not a best, a tie is not one) — the lifting chart's rule.
    let isBest: Bool
}

enum CardioProgressChange: Equatable, Sendable {
    /// Since the first session, oriented so positive is better (distance, time, speed).
    case fraction(Double)
    /// Pace, seconds per pace unit: positive = faster.
    case paceSeconds(Double)
}

enum CardioProgressMath {

    /// Every finished workout's recorded segments of `activity`, one session per workout, oldest first.
    static func sessions(in workouts: [Workout], activity: CardioActivity) -> [CardioProgressSession] {
        workouts.compactMap { workout -> CardioProgressSession? in
            // History only: an in-progress workout is not a session yet (as the lifting chart).
            guard !workout.isDeleted, workout.finishedAt != nil else { return nil }
            let segments = workout.recordedCardio.filter { $0.activity == activity }
            guard let first = segments.min(by: { $0.startedAt < $1.startedAt }) else { return nil }
            let distances = segments.compactMap(\.distanceMeters)
            let samples = segments.reduce(0) { $0 + $1.heartRateCount }
            let total = segments.reduce(0) { $0 + $1.heartRateTotal }
            return CardioProgressSession(
                workoutID: workout.id,
                date: first.startedAt,
                meters: distances.isEmpty ? nil : distances.reduce(0, +),
                seconds: segments.reduce(0) { $0 + $1.activeDuration(at: $1.endedAt ?? $1.lastCheckpointAt) },
                heartRate: samples > 0 ? Int((Double(total) / Double(samples)).rounded()) : nil)
        }
        .sorted { ($0.date, $0.workoutID.uuidString) < ($1.date, $1.workoutID.uuidString) }
    }

    /// Activities with at least one finished session, most sessions first (ties by name) — the Add Chart list.
    static func activities(in workouts: [Workout]) -> [(activity: CardioActivity, sessions: Int)] {
        var counts: [CardioActivity: Int] = [:]
        for workout in workouts where !workout.isDeleted && workout.finishedAt != nil {
            for activity in Set(workout.recordedCardio.map(\.activity)) { counts[activity, default: 0] += 1 }
        }
        return counts.map { (activity: $0.key, sessions: $0.value) }
            .sorted { ($1.sessions, $0.activity.name) < ($0.sessions, $1.activity.name) }
    }

    /// Metres in one pace unit: 500 for rowing, otherwise one km or mile.
    static func paceMeters(_ activity: CardioActivity, unit: CardioDistanceUnit) -> Double {
        activity == .rowing ? 500 : unit.metersPerUnit
    }

    /// The pace unit's label: "/500 m", "/km", "/mi".
    static func paceLabel(_ activity: CardioActivity, unit: CardioDistanceUnit) -> String {
        activity == .rowing ? "/500 m" : "/\(unit.rawValue)"
    }

    /// True where a smaller number is the improvement: pace (not speed).
    static func lowerIsBetter(_ metric: ProgressPinMetric, activity: CardioActivity) -> Bool {
        metric == .pace && !activity.usesSpeed
    }

    /// One session's value: distance in the unit, pace in seconds per pace unit, speed in unit per hour, time in
    /// minutes. nil when the session cannot say (no distance for distance/pace/speed; under a second of activity).
    static func value(_ session: CardioProgressSession, metric: ProgressPinMetric, activity: CardioActivity,
                      unit: CardioDistanceUnit) -> Double? {
        let meters = session.meters.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
        let seconds = session.seconds.isFinite && session.seconds >= 1 ? session.seconds : nil
        switch metric {
        case .distance:
            return meters.map { $0 / unit.metersPerUnit }
        case .pace:
            guard let meters, let seconds else { return nil }
            return activity.usesSpeed
                ? (meters / unit.metersPerUnit) / (seconds / 3600)
                : seconds / meters * paceMeters(activity, unit: unit)
        case .time:
            return seconds.map { $0 / 60 }
        case .bestSet, .volume, .e1rm:
            return nil
        }
    }

    /// The charted series: sessions with a value, oldest first, each marked when it beat every earlier one.
    static func points(_ sessions: [CardioProgressSession], metric: ProgressPinMetric, activity: CardioActivity,
                       unit: CardioDistanceUnit) -> [CardioProgressPoint] {
        let lower = lowerIsBetter(metric, activity: activity)
        var best: Double?
        return sessions.compactMap { session in
            guard let value = value(session, metric: metric, activity: activity, unit: unit) else { return nil }
            let beats = best.map { lower ? value < $0 : value > $0 } ?? false
            if best == nil || beats { best = value }
            return CardioProgressPoint(workoutID: session.workoutID, date: session.date, value: value, isBest: beats)
        }
    }

    /// From the first to the last point; nil for fewer than two points or a zero baseline.
    static func change(_ points: [CardioProgressPoint], metric: ProgressPinMetric,
                       activity: CardioActivity) -> CardioProgressChange? {
        guard points.count >= 2, let first = points.first?.value, let last = points.last?.value else { return nil }
        if lowerIsBetter(metric, activity: activity) { return .paceSeconds(first - last) }
        guard first != 0 else { return nil }
        return .fraction((last - first) / abs(first))
    }

    /// True when the latest point is the best of all (ties count) and there is something to compare it with — the
    /// panel's "Longest" / "Fastest" caption.
    static func latestIsBest(_ points: [CardioProgressPoint], metric: ProgressPinMetric, activity: CardioActivity) -> Bool {
        guard points.count >= 2, let last = points.last?.value else { return false }
        let values = points.map(\.value)
        return lowerIsBetter(metric, activity: activity) ? last <= (values.min() ?? last) : last >= (values.max() ?? last)
    }

    /// The bests list: the longest distance, the fastest pace or speed, the longest session. Each is the earliest
    /// session that set it, so a later tie does not take the date.
    static func bests(_ sessions: [CardioProgressSession], activity: CardioActivity,
                      unit: CardioDistanceUnit) -> (longest: CardioProgressPoint?, fastest: CardioProgressPoint?,
                                                    longestTime: CardioProgressPoint?) {
        func top(_ metric: ProgressPinMetric) -> CardioProgressPoint? {
            let all = points(sessions, metric: metric, activity: activity, unit: unit)
            let lower = lowerIsBetter(metric, activity: activity)
            return all.reduce(nil) { incumbent, point in
                guard let incumbent else { return point }
                return (lower ? point.value < incumbent.value : point.value > incumbent.value) ? point : incumbent
            }
        }
        return (top(.distance), top(.pace), top(.time))
    }
}
