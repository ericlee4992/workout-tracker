import Foundation

// Milestone 7, ticket 01 — what a workout's heart rate adds up to (D44).
// Pure: a fold over samples, no clock, no storage.
//
// The rule worth stating: time in a zone is measured BETWEEN samples, and a gap
// longer than `maxAttributedGap` is not attributed to any zone. A sensor that
// disconnects for five minutes must not donate five minutes to whatever zone it
// happened to be in when it died — the user would read that as five minutes of
// training they never did, in a summary whose whole claim is that it reports
// what happened.

struct WorkoutVitals: Equatable, Sendable {
    /// nil when no samples were collected — the summary omits heart-rate rows
    /// entirely rather than rendering zeros (D44). `0 BPM` is not a missing
    /// value, it is a false one.
    var averageBpm: Int?
    var maxBpm: Int?
    /// Seconds spent in each zone, keyed by `HeartRateZone.rawValue`. Empty
    /// when no maximum heart rate was resolvable (D45: no basis, no zones).
    var secondsInZone: [Int: Int]
    var sampleCount: Int

    static let empty = WorkoutVitals(
        averageBpm: nil, maxBpm: nil, secondsInZone: [:], sampleCount: 0)

    var isEmpty: Bool { sampleCount == 0 }

    var totalZonedSeconds: Int {
        secondsInZone.values.reduce(0, +)
    }
}

enum WorkoutVitalsMath {

    /// Gaps longer than this are treated as "the sensor was not reporting" and
    /// are attributed to no zone at all. Four times the staleness tolerance:
    /// long enough that ordinary jitter never trips it, short enough that a
    /// genuine dropout is never counted as training.
    static let maxAttributedGap: TimeInterval = 60

    /// The readings a summary should be built from when more than one sensor
    /// reported: every sample from `dominant`, plus the other sensor's samples
    /// that fall STRICTLY INSIDE a dominant outage — a gap between two
    /// consecutive dominant samples longer than `maxAttributedGap`, the same
    /// threshold below which the zone fold already treats a gap as "still
    /// reporting". So the dominant sensor owns every moment it covered, the
    /// other fills only genuine silences, and a lone reading before the first
    /// or after the last dominant sample is not an outage and stays out —
    /// which is codex-review-2 #6 (one late Watch reading must not own the
    /// summary), kept intact while codex-review 05's handoff case is honoured.
    static func summarySamples(
        from samples: [HeartRateSample],
        dominant: HeartRateSource,
        minimumGap: TimeInterval = maxAttributedGap
    ) -> [HeartRateSample] {
        let primary = samples.filter { $0.source == dominant }.sorted { $0.date < $1.date }
        guard !primary.isEmpty else { return samples.sorted { $0.date < $1.date } }
        let others = samples.filter { $0.source != dominant }
        guard !others.isEmpty else { return primary }
        // Interior outages: (start, end) of every dominant gap longer than the
        // threshold; the other sensor fills strictly inside them.
        var outages: [(Date, Date)] = []
        for (a, b) in zip(primary, primary.dropFirst()) where b.date.timeIntervalSince(a.date) > minimumGap {
            outages.append((a.date, b.date))
        }
        var fillers = others.filter { other in
            outages.contains { other.date > $0.0 && other.date < $0.1 }
        }
        // Terminal handoffs (codex-review 05b): the dominant sensor stopping
        // for good, or starting late, while the other KEPT REPORTING. A run
        // OUTSIDE the dominant span counts only if it is sustained AND
        // continuous — first-to-last span longer than the threshold, and no
        // internal gap longer than it (codex-review 05c: two lone readings 61 s
        // apart are not a sensor reporting, by this module's own definition
        // of a gap). That admits a Watch that carried the last five minutes
        // and still rejects a single stray reading after Finish (codex-review-2
        // #6: one reading has no span).
        let first = primary.first!.date, last = primary.last!.date
        for run in [others.filter { $0.date < first }, others.filter { $0.date > last }] {
            let sorted = run.sorted { $0.date < $1.date }
            guard let a = sorted.first, let b = sorted.last,
                  b.date.timeIntervalSince(a.date) > minimumGap,
                  zip(sorted, sorted.dropFirst()).allSatisfy({ $1.date.timeIntervalSince($0.date) <= minimumGap })
            else { continue }
            fillers += sorted
        }
        guard !fillers.isEmpty else { return primary }
        return (primary + fillers).sorted { $0.date < $1.date }
    }

    /// Folds a sample stream into the numbers the summary shows.
    ///
    /// `maxBpm` is the maximum *heart rate ceiling* used for zoning (D45), not
    /// the maximum observed — those are different numbers and conflating them
    /// would put every set in zone 5.
    static func vitals(
        from samples: [HeartRateSample],
        zoningAgainst ceiling: MaxHeartRate?
    ) -> WorkoutVitals {
        guard !samples.isEmpty else { return .empty }
        let ordered = samples.sorted { $0.date < $1.date }

        let total = ordered.reduce(0) { $0 + $1.bpm }
        let average = Int((Double(total) / Double(ordered.count)).rounded())
        let observedMax = ordered.map(\.bpm).max()

        var secondsInZone: [Int: Int] = [:]
        if let ceiling {
            for (index, sample) in ordered.enumerated() where index + 1 < ordered.count {
                let gap = ordered[index + 1].date.timeIntervalSince(sample.date)
                // A gap that is negative (duplicate timestamps) or longer than
                // the cutoff contributes nothing.
                guard gap > 0, gap <= maxAttributedGap else { continue }
                guard let zone = HeartRateZones.zone(for: sample.bpm, max: ceiling.bpm)
                else { continue }
                secondsInZone[zone.rawValue, default: 0] += Int(gap.rounded())
            }
        }

        return WorkoutVitals(
            averageBpm: average,
            maxBpm: observedMax,
            secondsInZone: secondsInZone,
            sampleCount: ordered.count)
    }
}
