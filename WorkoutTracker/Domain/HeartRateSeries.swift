import Foundation

// Milestone 9, ticket 05 — the heart-rate series a workout keeps.
//
// The app used to persist only aggregates (average, maximum, calories, seconds
// per zone), so the "how did my heart rate move through the session" graph
// could not exist for any workout, finished or historical. This is the fix:
// samples are folded into fixed-width buckets at finish and stored as a
// CloudKit-safe `[Int]` beside `zoneSeconds` (T2). Pure, so the fold can be
// proven without a sensor.
//
// A bucket with no sample stores 0 and is DRAWN AS A GAP, never as 0 BPM —
// the same rule D44 applies to the aggregates: missing is not zero.

enum HeartRateSeriesMath {

    /// Bucket width. Fifteen seconds is fine enough to show a set and its rest
    /// and coarse enough that a two-hour session is ~480 ints.
    static let defaultIntervalSeconds = 15

    /// Hard ceiling on buckets (24 h at the default width), so a corrupt end
    /// date cannot produce a multi-megabyte row.
    static let maxBuckets = 5_760

    /// Folds samples into buckets from `start` to `end`. Each bucket is the
    /// rounded mean bpm of the samples that fell in it; 0 where none did.
    /// Samples outside [start, end] are ignored — they are not this workout.
    static func series(
        from samples: [HeartRateSample],
        start: Date,
        end: Date,
        intervalSeconds: Int = defaultIntervalSeconds
    ) -> [Int] {
        let interval = TimeInterval(max(1, intervalSeconds))
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return [] }
        let count = min(maxBuckets, Int((span / interval).rounded(.up)))
        guard count > 0 else { return [] }

        // When the cap bites, the series TRUNCATES at the horizon: samples past
        // it are dropped, not folded into the last bucket (codex-review 05 —
        // clamping the index averaged a whole tail into one 15 s mean).
        let horizon = Double(count) * interval
        var sums = [Int](repeating: 0, count: count)
        var counts = [Int](repeating: 0, count: count)
        for sample in samples {
            let offset = sample.date.timeIntervalSince(start)
            guard offset >= 0, offset <= span, offset <= horizon, sample.bpm > 0 else { continue }
            let index = min(count - 1, Int(offset / interval))
            sums[index] += sample.bpm
            counts[index] += 1
        }
        return (0..<count).map { counts[$0] == 0 ? 0 : Int((Double(sums[$0]) / Double(counts[$0])).rounded()) }
    }

    /// One drawable point per non-empty bucket: elapsed seconds at the bucket's
    /// START, and its bpm. Zeros are gaps and are not returned.
    struct Point: Equatable, Identifiable {
        var id: Int { index }
        let index: Int
        let elapsedSeconds: Int
        let bpm: Int
    }

    static func points(from series: [Int], intervalSeconds: Int) -> [Point] {
        series.enumerated().compactMap { index, bpm in
            bpm > 0 ? Point(index: index, elapsedSeconds: index * intervalSeconds, bpm: bpm) : nil
        }
    }

}
