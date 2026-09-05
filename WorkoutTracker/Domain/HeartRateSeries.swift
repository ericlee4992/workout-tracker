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

    /// The three folds a bucket keeps: the rounded mean, the lowest sample and
    /// the highest. A bucket with no sample is 0 in ALL THREE — a gap — so a
    /// consumer tests `mean > 0` once and never reads a low of 0 as 0 BPM.
    ///
    /// Low and high exist for the chart (finish-graph ticket 01): Apple's
    /// shape is a bar per interval spanning what the heart did INSIDE it, and
    /// a mean cannot draw a span. Workouts folded before this had only the
    /// mean; `displaySlots` says how those still draw.
    struct Folded: Equatable, Sendable {
        var mean: [Int]
        var low: [Int]
        var high: [Int]

        static let empty = Folded(mean: [], low: [], high: [])

        var hasSamples: Bool { mean.contains { $0 > 0 } }
    }

    /// Folds samples into buckets from `start` to `end`: the rounded mean bpm
    /// of the samples that fell in each, 0 where none did. Samples outside
    /// [start, end] are ignored — they are not this workout.
    static func series(
        from samples: [HeartRateSample],
        start: Date,
        end: Date,
        intervalSeconds: Int = defaultIntervalSeconds
    ) -> [Int] {
        fold(from: samples, start: start, end: end, intervalSeconds: intervalSeconds).mean
    }

    /// `series`, keeping each bucket's low and high beside its mean. Same
    /// bucketing, same boundaries, same cap — one fold, three readings.
    static func fold(
        from samples: [HeartRateSample],
        start: Date,
        end: Date,
        intervalSeconds: Int = defaultIntervalSeconds
    ) -> Folded {
        let interval = TimeInterval(max(1, intervalSeconds))
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return .empty }
        let count = min(maxBuckets, Int((span / interval).rounded(.up)))
        guard count > 0 else { return .empty }

        // When the cap bites, the series TRUNCATES at the horizon: samples past
        // it are dropped, not folded into the last bucket (codex-review 05 —
        // clamping the index averaged a whole tail into one 15 s mean). The
        // horizon is EXCLUSIVE when it is the artificial cap (a sample exactly
        // on it belongs to the first omitted bucket) and inclusive when it is
        // the workout's real end (codex-review 05b).
        let capped = Double(count) * interval < span
        let horizon = Double(count) * interval
        var sums = [Int](repeating: 0, count: count)
        var counts = [Int](repeating: 0, count: count)
        var lows = [Int](repeating: 0, count: count)
        var highs = [Int](repeating: 0, count: count)
        for sample in samples {
            let offset = sample.date.timeIntervalSince(start)
            guard offset >= 0, offset <= span, sample.bpm > 0 else { continue }
            if capped ? offset >= horizon : false { continue }
            let index = min(count - 1, Int(offset / interval))
            sums[index] += sample.bpm
            counts[index] += 1
            lows[index] = counts[index] == 1 ? sample.bpm : min(lows[index], sample.bpm)
            highs[index] = max(highs[index], sample.bpm)
        }
        let mean = (0..<count).map { counts[$0] == 0 ? 0 : Int((Double(sums[$0]) / Double(counts[$0])).rounded()) }
        return Folded(mean: mean, low: lows, high: highs)
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


    // MARK: Display slots (finish-graph ticket 01)

    /// One bar as the chart draws it: a span of elapsed seconds and the range
    /// of bpm the heart covered inside it.
    struct DisplaySlot: Equatable, Identifiable, Sendable {
        var id: Int { index }
        let index: Int
        let startSeconds: Int
        let endSeconds: Int
        let low: Int
        let high: Int
    }

    /// The most bars a chart draws. A 67-minute workout is 268 buckets across
    /// a ~330 pt plot — drawn one per bucket they fuse into a solid block,
    /// which is the "messy" the user reported. Apple's bars are ~2 pt with a
    /// gap; 110 slots keeps that on a phone width for anything up to ~3 h.
    static let defaultMaxSlots = 110

    /// Merges adjacent buckets so at most `maxSlots` bars are drawn. A slot's
    /// low is the lowest low among its non-gap buckets and its high the
    /// highest high; a slot holding only gaps is NOT returned, so a sensor
    /// outage stays a hole in the chart rather than a bar bridging it. A
    /// series of `maxSlots` buckets or fewer comes back bucket-for-bucket.
    ///
    /// `low`/`high` may be empty (a workout folded before they existed): the
    /// means then stand in for both, so a merged slot spans the range of the
    /// MEANS inside it — a narrower but real range, never an invented one —
    /// and an unmerged one is a flat tick at the mean. They are ignored, not
    /// trusted, when their length disagrees with `mean`.
    ///
    /// `durationSeconds` is the horizon when positive: a slot starting at or
    /// past it is not returned at all, and every returned slot ends no later
    /// than it, so a 31 s workout is not drawn as 45 s (codex-review 05) and
    /// a corrupt duration shorter than its own series cannot put an invisible
    /// slot beyond the plot that still sets the axis (codex-review 01). A
    /// non-positive duration means no horizon is known and nothing is clipped.
    static func displaySlots(
        mean: [Int], low: [Int], high: [Int],
        intervalSeconds: Int, durationSeconds: Int,
        maxSlots: Int = defaultMaxSlots
    ) -> [DisplaySlot] {
        let count = mean.count
        guard count > 0, maxSlots > 0 else { return [] }
        let interval = max(1, intervalSeconds)
        let hasRange = low.count == count && high.count == count
        let perSlot = Int((Double(count) / Double(maxSlots)).rounded(.up))
        let slotCount = Int((Double(count) / Double(perSlot)).rounded(.up))
        var slots: [DisplaySlot] = []
        slots.reserveCapacity(slotCount)
        for slot in 0..<slotCount {
            let first = slot * perSlot
            let last = min(count, first + perSlot)
            var lowest = Int.max
            var highest = Int.min
            for index in first..<last where mean[index] > 0 {
                let bucketLow = hasRange && low[index] > 0 ? low[index] : mean[index]
                let bucketHigh = hasRange && high[index] > 0 ? high[index] : mean[index]
                lowest = min(lowest, bucketLow)
                highest = max(highest, bucketHigh)
            }
            guard lowest != Int.max else { continue }
            let start = first * interval
            let end = last * interval
            if durationSeconds > 0, start >= durationSeconds { break }
            let clampedEnd = durationSeconds > 0 ? min(end, durationSeconds) : end
            slots.append(DisplaySlot(
                index: slot, startSeconds: start, endSeconds: clampedEnd,
                low: lowest, high: max(lowest, highest)))
        }
        return slots
    }

    /// The range pair as a backup may carry it: both arrays, each the mean's
    /// length, or neither. nil for a mean-only workout AND for any workout
    /// whose arrays disagree — a lone or mismatched range is not evidence of
    /// anything and must not be written as if it were (codex-review 01).
    static func exportableRange(mean: [Int], low: [Int], high: [Int]) -> (low: [Int], high: [Int])? {
        guard !mean.isEmpty, low.count == mean.count, high.count == mean.count else { return nil }
        return (low, high)
    }

    /// The bpm the drawn slots actually span — the chart's own axis, not
    /// 0…220 (the reference shows 75 at the bottom and 159 at the top and
    /// nothing else). nil when nothing is drawn.
    static func range(of slots: [DisplaySlot]) -> ClosedRange<Int>? {
        guard let lowest = slots.map(\.low).min(), let highest = slots.map(\.high).max() else { return nil }
        return lowest...highest
    }
}
