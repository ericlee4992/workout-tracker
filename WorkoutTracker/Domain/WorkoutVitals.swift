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
