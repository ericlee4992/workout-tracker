import Foundation

/// What the cardio screens derive from a segment (Floodlight ticket 12). Pure: nothing here stores
/// anything, so the recorded data (D15/D57, the September 19 cardio rules) stays the only truth.

/// What the live ring counts, and what its centre says. One rule for the ring and its caption,
/// so the centre is always what the ring measures (the user's decision 3, 2026-09-28):
/// a planned target's time; else, once there is a distance, the way to the next mile / km;
/// else a 60-second sweep around the clock.
struct CardioRingModel: Equatable {
    enum Centre: Equatable {
        /// The active time ("12:40").
        case time(Int)
        /// The distance in the segment's unit ("1.47").
        case distance(Double)
    }
    /// 0…1 of the ring lit (a met target is 1).
    var progress: Double
    /// Segments drawn around the ring.
    var ticks: Int
    var centre: Centre
    /// The target the ring counts to: the target seconds, or the next whole unit. nil = the sweep.
    var targetSeconds: Int?
    var nextUnit: Int?
    var targetDone: Bool
    /// Whole units covered — changes once per split (a light haptic).
    var splitIndex: Int

    var countsDistance: Bool { if case .distance = centre { true } else { false } }

    static func make(activeSeconds: Int, targetMinutes: Int?, distanceMeters: Double?,
                     unit: CardioDistanceUnit) -> CardioRingModel {
        let active = max(0, activeSeconds)
        if let minutes = targetMinutes, minutes > 0 {
            let target = max(60, minutes * 60)
            return CardioRingModel(
                progress: min(1, Double(active) / Double(target)),
                ticks: minutes < 5 ? 12 : min(60, minutes),
                centre: .time(active), targetSeconds: target, nextUnit: nil,
                targetDone: active >= target, splitIndex: 0)
        }
        // A distance ring needs a whole-unit count an Int can hold; an absurd stored value (the
        // domain accepts any finite entry) falls back to the sweep rather than trapping.
        if let meters = distanceMeters, meters.isFinite, meters > 0,
           meters / unit.metersPerUnit < CardioReadout.maxSplits * 1_000 {
            let units = meters / unit.metersPerUnit
            let whole = units.rounded(.down)
            return CardioRingModel(
                progress: units - whole, ticks: 10, centre: .distance(units),
                targetSeconds: nil, nextUnit: Int(whole) + 1, targetDone: false, splitIndex: Int(whole))
        }
        return CardioRingModel(progress: Double(active % 60) / 60, ticks: 12, centre: .time(active),
                               targetSeconds: nil, nextUnit: nil, targetDone: false, splitIndex: 0)
    }
}

/// One per-unit split of a recorded route: `distance` in the segment's unit (1 except a part-unit
/// tail), `seconds` of ACTIVE time (pauses excluded).
struct CardioSplit: Equatable, Identifiable {
    var index: Int
    var distance: Double
    var seconds: Int
    var id: Int { index }
    /// Seconds per unit (a pace), or nil for an empty split.
    var secondsPerUnit: Double? { distance > 0 && seconds > 0 ? Double(seconds) / distance : nil }
    var isPartial: Bool { distance < 0.995 }
}

enum CardioReadout {
    /// The most splits a view derives. A typed distance is the user's (kept as entered, D52/D15),
    /// but a mistyped 999999 km must not expand into a million rows and markers on the main thread.
    static let maxSplits: Double = 200

    /// Seconds since the running segment was paused (nil while it records or once it ended).
    /// A pause ends a segment's active interval at `lastCheckpointAt`; a relaunch that could not
    /// observe the gap pauses at the last checkpoint too (`CardioSession.recover`), so this counts
    /// from the last moment the app knows the segment was recording.
    static func pausedSeconds(_ segment: CardioSegment, at now: Date) -> Int? {
        guard segment.endedAt == nil, segment.activeStartedAt == nil else { return nil }
        let since = segment.intervals.last?.end ?? segment.lastCheckpointAt
        return max(0, Int(now.timeIntervalSince(since)))
    }

    /// Active seconds at a wall-clock date: the recorded intervals up to it, plus the current one.
    static func activeSeconds(_ segment: CardioSegment, at date: Date) -> Double {
        var total = 0.0
        for interval in segment.intervals where interval.start < date {
            total += min(date, interval.end).timeIntervalSince(interval.start)
        }
        if let start = segment.activeStartedAt, date > start { total += date.timeIntervalSince(start) }
        return max(0, total)
    }

    /// Per-unit splits of a route (GPS), in active time. The route's own length is scaled to the
    /// segment's distance, so a typed distance keeps the splits consistent with the figure shown.
    /// Portions are never joined (a pause or an outage adds no distance). Fewer than two route
    /// points, or no distance: none.
    static func splits(_ segment: CardioSegment, end: Date? = nil) -> [CardioSplit] {
        let route = segment.route.sorted { $0.date < $1.date }
        guard route.count > 1, let total = segment.distanceMeters, total.isFinite, total > 0,
              total / segment.unit.metersPerUnit <= maxSplits else { return [] }
        var cumulative: [(meters: Double, offset: Double)] = [(0, activeSeconds(segment, at: route[0].date))]
        for i in 1..<route.count {
            let step = route[i].portion == route[i - 1].portion ? CardioMath.meters(between: route[i - 1], and: route[i]) : 0
            cumulative.append((cumulative[i - 1].meters + step, activeSeconds(segment, at: route[i].date)))
        }
        guard let routeMeters = cumulative.last?.meters, routeMeters > 0 else { return [] }
        let scale = total / routeMeters
        let unitMeters = segment.unit.metersPerUnit
        let endOffset = segment.activeDuration(at: end ?? segment.endedAt ?? segment.lastCheckpointAt)
        func offset(atMeters m: Double) -> Double {
            for i in 1..<cumulative.count where cumulative[i].meters * scale >= m {
                let a = cumulative[i - 1], b = cumulative[i]
                let span = (b.meters - a.meters) * scale
                let t = span > 0 ? (m - a.meters * scale) / span : 0
                return a.offset + t * (b.offset - a.offset)
            }
            return endOffset
        }
        var result: [CardioSplit] = []
        var start = 0.0, covered = 0.0, index = 0, lastStart = 0.0
        // A tail under a metre is rounding, not a split.
        while covered < total - 1 {
            let next = min(total, covered + unitMeters)
            let finish = next >= total ? endOffset : offset(atMeters: next)
            result.append(CardioSplit(index: index, distance: (next - covered) / unitMeters,
                                      seconds: max(0, Int((finish - start).rounded()))))
            lastStart = start
            start = finish; covered = next; index += 1
        }
        // …but its time is real: the last split runs to the segment's end.
        if covered < total, !result.isEmpty {
            result[result.count - 1].seconds = max(0, Int((endOffset - lastStart).rounded()))
        }
        return result
    }

    /// The most recent segment of each activity among finished workouts (the picker's "last done").
    static func lastDone(in segments: [CardioSegment]) -> [CardioActivity: CardioSegment] {
        var result: [CardioActivity: CardioSegment] = [:]
        for segment in segments where segment.endedAt != nil && segment.hasRecordedActivity {
            guard let workout = segment.workout, !workout.isDeleted, workout.finishedAt != nil else { continue }
            if let known = result[segment.activity], known.startedAt >= segment.startedAt { continue }
            result[segment.activity] = segment
        }
        return result
    }
}

/// One 15-second bucket of heart rate for the live trace (index 0 … `limit - 1`, newest last).
struct CardioHeartPoint: Equatable {
    var index: Int
    var bpm: Double
}

enum CardioHeartTrace {
    /// The last `limit` 15-second buckets up to `now`, of samples since `since` (the segment's
    /// active start): each bucket's mean. Empty buckets are left out, so a gap stays a gap.
    static func points(_ samples: [HeartRateSample], since: Date?, now: Date, limit: Int = 24) -> [CardioHeartPoint] {
        let window = Double(limit) * 15
        let start = max(since ?? .distantPast, now.addingTimeInterval(-window))
        var sums = [Double](repeating: 0, count: limit), counts = [Int](repeating: 0, count: limit)
        for sample in samples where sample.bpm > 0 && sample.date >= start && sample.date <= now {
            let back = Int(now.timeIntervalSince(sample.date) / 15)
            let index = limit - 1 - min(limit - 1, back)
            sums[index] += Double(sample.bpm); counts[index] += 1
        }
        return (0..<limit).compactMap { counts[$0] > 0 ? CardioHeartPoint(index: $0, bpm: sums[$0] / Double(counts[$0])) : nil }
    }
}

/// The outdoor segment's location status, from the recorder's message (decision 2, 2026-09-28:
/// shown only when something is wrong — nothing while fixes arrive).
enum CardioLocationStatus: Equatable {
    /// Fixes are arriving (or the segment is paused / indoor): nothing to show.
    case fine
    /// Waiting for a fix, or recording with a caveat: the bars and the message.
    case waiting(String)
    /// No location: the plate. Time keeps recording; distance stops.
    case lost

    static let unavailable = "Location unavailable."
    static let gpsFailed = "GPS unavailable. Recording time continues."

    static func of(message: String?, outdoor: Bool, running: Bool) -> CardioLocationStatus {
        guard outdoor, running, let message else { return .fine }
        if message == unavailable || message == gpsFailed { return .lost }
        return .waiting(message)
    }
}
