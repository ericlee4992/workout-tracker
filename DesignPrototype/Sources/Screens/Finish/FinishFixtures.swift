import Foundation

// PROTOTYPE FIXTURES — sample data the Finish receipt needs that the shared fixture does not
// yet provide. Nothing here reshapes data at draw time: each function stands in for a stored
// value, and the receipt reads its output exactly as it would read `SampleData`.
//
// INTEGRATOR: promote both into Model/ and delete this file —
// 1. `FinishHeartRateFixture.build` → `SampleData.heartRate` (store its 5 s series on the
//    workout and derive zone seconds from it; `Derived.hrSlots` then groups it per minute). The current
//    `SampleData.heartRate` is a noisy sine at 15 s, so neighbouring minutes jump 40–60 bpm
//    and the graph reads as a barcode; its derived zones also run 5 s past the duration
//    (F02: 1:13:15 of zones for a 1:13:10 workout).
// 2. `FinishRouteFixture.seoulForest` → the F02 CardioSpec route (the stored loop is a
//    perfect ellipse across a motorway interchange and the river).

// MARK: - Heart rate

/// A physiological heart-rate trace for a finished workout, rebuilt from its own facts: each
/// set's completion time (a ≈40 s climb, then a fast-then-slow recovery that never fully
/// settles between sets), each cardio segment (a lagged ramp to a slowly drifting plateau,
/// then a decay back), and the stored gaps (no reading = no bar). One smooth rising map puts
/// it on the stored average and maximum, and Time in zones is counted off the same samples —
/// so the chart, the zone rows (which add up to the workout) and the Avg. / Max heart rate
/// tiles can never disagree.
enum FinishHeartRateFixture {
    struct Result {
        /// One range bar per minute (low…high over that minute's readings).
        var slots: [HRSlot]
        /// Seconds per zone (index 0 Warm-up … 5), summing to the time with readings.
        var zoneSeconds: [Int]
    }

    static let step = 5

    static func build(for workout: Workout, maxHeartRate: Int?) -> Result? {
        guard let summary = workout.heartRate, let series = summary.series, !series.mean.isEmpty else { return nil }
        let duration = max(60, workout.durationSeconds)
        let count = duration / step
        let interval = max(1, series.intervalSeconds)
        func hasReading(_ i: Int) -> Bool {
            let bucket = (i * step) / interval
            return bucket < series.mean.count && series.mean[bucket] > 0
        }
        let shape = trace(for: workout, count: count)
        let readings = (0..<count).filter(hasReading)
        guard !readings.isEmpty else { return nil }

        // Onto the stored average and maximum; the zone times are then counted off these same
        // samples, so the bars, the zone rows and the tiles always agree.
        let values = scale(readings, shape: shape, peak: Double(summary.maximum), average: Double(summary.average))
        var zoneSeconds: [Int] = []
        if let maxHR = maxHeartRate {
            zoneSeconds = [Int](repeating: 0, count: HeartRateZone.allCases.count)
            let bounds = HeartRateZone.allCases.map { Double(maxHR) * $0.lowerFraction }
            for value in values.values {
                let zone = bounds.lastIndex { value.rounded() >= $0.rounded() } ?? 0
                zoneSeconds[zone] += step
            }
        }

        // One bar per minute (a last part-minute under 30 s joins the minute before it, so
        // 52:10 draws 52 bars).
        var slots: [HRSlot] = []
        let perMinute = 60 / step
        let minutes = max(1, Int((Double(duration) / 60).rounded()))
        for minute in 0..<minutes {
            let end = minute == minutes - 1 ? count : min(count, (minute + 1) * perMinute)
            let samples = (minute * perMinute..<end).compactMap { values[$0] }
            guard let lo = samples.min(), let hi = samples.max() else { continue }
            slots.append(HRSlot(index: minute, startSeconds: minute * 60, endSeconds: minute == minutes - 1 ? duration : (minute + 1) * 60,
                                low: Int(lo.rounded()), high: min(summary.maximum, max(Int(lo.rounded()) + 1, Int(hi.rounded())))))
        }
        return Result(slots: slots, zoneSeconds: zoneSeconds)
    }

    // MARK: The shape (unitless; only its order and local motion survive the mapping)

    private static func trace(for workout: Workout, count: Int) -> [Double] {
        let windows: [ClosedRange<Double>] = workout.cardio.map { segment in
            let start = segment.startedAt.timeIntervalSince(workout.startedAt)
            return start...(start + Double(segment.activeSeconds))
        }
        // Lifting: each exercise holds its own working level (heavier work sits higher), the
        // body warms up over the first minutes, and each set adds a small climb and recovery.
        struct Block { var from: Double; var to: Double; var level: Double }
        struct Effort { var at: Double; var amplitude: Double }
        var blocks: [Block] = []
        var efforts: [Effort] = []
        let demands = workout.entries.map { entry in
            entry.countedSets.map { ($0.normalizedKg ?? 0) * Double($0.reps ?? 0) }.max() ?? 0
        }
        let top = max(1, demands.max() ?? 1)
        for (k, entry) in workout.entries.enumerated() {
            let times = entry.sets.map { $0.completedAt.timeIntervalSince(workout.startedAt) }
            guard let first = times.min(), let last = times.max() else { continue }
            blocks.append(Block(from: first - 60, to: last + 40,
                                level: 8 + 34 * pow(demands[k] / top, 2) + 2 * jitter(entry.id.uuidString.hashValue64)))
            for (n, set) in entry.sets.enumerated() {
                let amplitude: Double = switch set.type {
                case .warmup: 5
                case .working: 12
                case .failure: 14
                case .drop: 8
                }
                efforts.append(Effort(at: times[n], amplitude: amplitude))
            }
        }
        func blockLevel(_ t: Double) -> Double {
            // Between exercises the level eases from one block to the next.
            guard let next = blocks.firstIndex(where: { t < $0.to }) else { return blocks.last?.level ?? 12 }
            let block = blocks[next]
            if t >= block.from || next == 0 { return block.level }
            let previous = blocks[next - 1]
            let u = min(1, max(0, (t - previous.to) / max(1, block.from - previous.to)))
            return previous.level + (block.level - previous.level) * (0.5 - 0.5 * cos(u * .pi))
        }
        func level(_ t: Double) -> Double {
            92 + (1 - exp(-t / 300)) * blockLevel(t)
        }
        func effort(_ t: Double) -> Double {
            efforts.reduce(0) { sum, e in
                let d = t - e.at
                if d < -45 || d > 600 { return sum }
                if d < 0 { return sum + e.amplitude * (1 - exp(-(d + 45) / 16)) / (1 - exp(-45 / 16)) }
                return sum + e.amplitude * (0.6 * exp(-d / 50) + 0.4 * exp(-d / 180))
            }
        }
        var values = [Double](repeating: 0, count: count)
        var current = level(0)
        var carry = 0.0
        // Heart rate follows a change of exercise over about a minute, never in one step.
        var settled = level(0)
        for i in 0..<count {
            let t = Double(i * step)
            settled += (level(t) - settled) * (1 - exp(-Double(step) / 70))
            let lift = settled + effort(t)
            if let k = windows.firstIndex(where: { $0.contains(t) }) {
                let window = windows[k]
                let u = (t - window.lowerBound) / max(1, window.upperBound - window.lowerBound)
                // Hills and pace changes: a slow swell and a quicker ripple on the drift.
                let into = t - window.lowerBound
                let plateau = 150 + 16 * pow(u, 1.3) + 3 * sin(into / 150 * 2 * .pi) + 2.2 * sin(into / 41 * 2 * .pi)
                current += (plateau - current) * (1 - exp(-Double(step) / 70))
                carry = current - lift
            } else {
                carry *= exp(-Double(step) / 60)
                current = lift + carry
            }
            values[i] = current + 0.6 * sin(Double(i) * 2.39996) * jitter(UInt64(i))
        }
        // A watch reports a smoothed rate: average over ±10 s, so neighbouring minutes stay
        // close and the per-minute bars read as one calm band, not a barcode.
        let r = 2
        return values.indices.map { i in
            let lo = max(0, i - r), hi = min(values.count - 1, i + r)
            return values[lo...hi].reduce(0, +) / Double(hi - lo + 1)
        }
    }

    // MARK: Mapping onto the stored facts

    /// Onto the stored figures with one smooth, rising map in two straight pieces: the lowest
    /// sample lands on `floor` (a resting-to-warm start), the highest on the stored maximum,
    /// and the joint (at the trace's median) is placed so the mean is the stored average.
    private static func scale(_ readings: [Int], shape: [Double], peak: Double, average: Double) -> [Int: Double] {
        let raw = readings.map { shape[$0] }
        let sorted = raw.sorted()
        guard let low = sorted.first, let high = sorted.last, high > low else {
            return Dictionary(uniqueKeysWithValues: readings.map { ($0, average) })
        }
        let joint = sorted[sorted.count / 2]
        let floor = min(average - 10, 88)
        func map(_ v: Double, _ at: Double) -> Double {
            v <= joint ? floor + (v - low) / max(0.001, joint - low) * (at - floor)
                       : at + (v - joint) / max(0.001, high - joint) * (peak - at)
        }
        // Bisect the joint's value for the stored average (the map rises with it).
        var a = floor, b = peak
        for _ in 0..<40 {
            let mid = (a + b) / 2
            let mean = raw.reduce(0) { $0 + map($1, mid) } / Double(raw.count)
            if mean < average { a = mid } else { b = mid }
        }
        let at = (a + b) / 2
        var values: [Int: Double] = [:]
        for index in readings { values[index] = map(shape[index], at) }
        return values
    }

    private static func jitter(_ seed: UInt64) -> Double {
        var x = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x632B_E59B_D9B4_E019
        x ^= x >> 29
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 32
        return Double(x % 10_000) / 10_000
    }
}

// MARK: - Today's run

/// Today's Seoul Forest run on real paths: from the park's east gate, north around the lawns,
/// west round the lake, under Ttukseom-ro into the riverside section, and back up
/// Wangsimni-ro (OpenStreetMap foot routing, simplified to 2.5 m; 3.28 km of path, while the
/// stored 2.09 mi stays the figure shown). Timestamps follow a real pace profile — a steady
/// first mile, a quicker second, then the last stretch walked in easy — so the splits differ.
enum FinishRouteFixture {
    /// (latitude, longitude)
    static let seoulForest: [(Double, Double)] = [
        (37.544108, 127.042372), (37.544229, 127.042006), (37.544301, 127.042037), (37.544470, 127.041500),
        (37.544967, 127.041609), (37.545136, 127.041534), (37.545375, 127.041350), (37.545424, 127.041201),
        (37.545613, 127.041247), (37.545652, 127.041102), (37.546849, 127.041626), (37.547126, 127.040633),
        (37.546864, 127.040498), (37.547126, 127.040633), (37.547417, 127.039590), (37.547162, 127.039452),
        (37.547160, 127.039412), (37.546704, 127.039207), (37.546683, 127.039292), (37.546450, 127.039201),
        (37.546380, 127.039485), (37.546111, 127.039387), (37.546181, 127.038978), (37.546156, 127.038519),
        (37.546027, 127.038146), (37.545747, 127.037715), (37.545445, 127.037456), (37.545130, 127.037344),
        (37.544679, 127.037361), (37.544431, 127.037473), (37.544013, 127.036407), (37.543808, 127.036362),
        (37.543774, 127.036320), (37.543823, 127.036016), (37.543876, 127.035938), (37.543765, 127.035700),
        (37.543612, 127.035585), (37.543410, 127.035567), (37.542846, 127.035273), (37.542586, 127.035210),
        (37.542241, 127.035631), (37.541586, 127.036731), (37.541339, 127.037045), (37.541120, 127.037447),
        (37.540950, 127.037634), (37.540817, 127.037858), (37.540761, 127.038073), (37.540713, 127.038661),
        (37.540578, 127.039195), (37.540135, 127.040128), (37.539941, 127.040165), (37.539839, 127.040235),
        (37.539391, 127.040641), (37.539328, 127.040781), (37.539291, 127.041160), (37.538861, 127.042313),
        (37.539827, 127.042860), (37.539638, 127.043455), (37.539965, 127.043619), (37.539959, 127.043723),
        (37.540322, 127.043772), (37.540498, 127.043740), (37.540709, 127.043104), (37.540800, 127.043015),
        (37.540890, 127.042992), (37.541131, 127.043073), (37.541083, 127.043281), (37.541204, 127.043320),
        (37.541148, 127.043621), (37.541272, 127.043669), (37.541300, 127.043530), (37.541401, 127.043492),
        (37.541451, 127.043400), (37.541564, 127.043433), (37.541455, 127.043968), (37.541586, 127.044005),
        (37.541701, 127.043949), (37.541789, 127.044039), (37.541971, 127.044124), (37.542045, 127.044079),
        (37.542464, 127.044256), (37.543434, 127.044517), (37.543934, 127.042827), (37.544068, 127.042887),
        (37.544199, 127.042411), (37.544108, 127.042372),
    ]

    /// The fixture's Seoul Forest loop is centred here.
    private static let seoulForestCentre = (37.5443, 127.0374)

    /// Pace of the first and second whole unit relative to the average; the rest of the run
    /// takes the remaining time.
    private static let paceProfile: [Double] = [1.018, 0.975]

    /// The segment as the receipt draws it: today's run on its real paths.
    static func displaySegment(_ segment: CardioSegment) -> CardioSegment {
        guard segment.route.count > 1, let meters = segment.distanceMeters, meters > 0 else { return segment }
        let lat = segment.route.map(\.latitude).reduce(0, +) / Double(segment.route.count)
        let lon = segment.route.map(\.longitude).reduce(0, +) / Double(segment.route.count)
        guard abs(lat - seoulForestCentre.0) < 0.003, abs(lon - seoulForestCentre.1) < 0.004 else { return segment }

        let points = seoulForest.map { RoutePoint(latitude: $0.0, longitude: $0.1, offset: 0) }
        var along = [0.0]
        for i in 1..<points.count { along.append(along[i - 1] + Derived.meters(points[i - 1], points[i])) }
        let pathLength = max(1, along.last ?? 1)
        let units = meters / segment.unit.metersPerUnit
        let total = Double(segment.activeSeconds)
        let averagePace = total / units
        // Seconds at each whole unit, then the rest evenly.
        var marks: [Double] = [0]
        for (k, share) in paceProfile.enumerated() where Double(k + 1) <= units {
            marks.append(marks[k] + averagePace * share)
        }
        let whole = Double(marks.count - 1)
        let restPace = units > whole ? (total - marks[marks.count - 1]) / (units - whole) : averagePace
        func time(atUnits d: Double) -> Double {
            let k = Int(d)
            if k < marks.count - 1 { return marks[k] + (d - Double(k)) * (marks[k + 1] - marks[k]) }
            return marks[marks.count - 1] + (d - whole) * restPace
        }
        var result = segment
        result.route = points.indices.map { i in
            RoutePoint(latitude: points[i].latitude, longitude: points[i].longitude,
                       offset: min(total, time(atUnits: along[i] / pathLength * units)), portion: 0)
        }
        return result
    }
}
