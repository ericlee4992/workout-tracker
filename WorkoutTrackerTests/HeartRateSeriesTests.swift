import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Milestone 9, ticket 05 — the heart-rate series a workout keeps, and the
/// path that writes it. The most-shipped defect in this repo is a field
/// nothing sets, so the WRITE is tested end to end, not just the maths.
struct HeartRateSeriesTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func sample(_ bpm: Int, at seconds: TimeInterval, source: HeartRateSource = .fixture) -> HeartRateSample {
        HeartRateSample(bpm: bpm, date: start.addingTimeInterval(seconds), source: source)
    }

    @MainActor
    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    // MARK: Folding

    @Test func bucketsAreMeansAndEmptyBucketsAreZero() {
        let series = HeartRateSeriesMath.series(
            from: [sample(100, at: 1), sample(110, at: 5), sample(140, at: 31), sample(141, at: 44)],
            start: start, end: start.addingTimeInterval(60), intervalSeconds: 15)
        // 60 s / 15 s = 4 buckets: [0–15) holds 100 and 110 → 105; [15–30) is
        // empty → 0; [30–45) holds 140 and 141 → 140.5 rounds to 141; [45–60) is
        // empty → 0.
        #expect(series == [105, 0, 141, 0])
        #expect(series[1] == 0, "a gap is 0, and 0 is drawn as a gap")
    }

    @Test func lengthCoversTheWholeDurationRoundingUp() {
        let series = HeartRateSeriesMath.series(from: [], start: start, end: start.addingTimeInterval(61), intervalSeconds: 15)
        #expect(series.count == 5)
        #expect(series.allSatisfy { $0 == 0 })
        #expect(HeartRateSeriesMath.series(from: [], start: start, end: start).isEmpty, "no duration, no series")
    }

    @Test func samplesOutsideTheWorkoutAreIgnoredAndTheEndIsInclusive() {
        let series = HeartRateSeriesMath.series(
            from: [sample(90, at: -5), sample(150, at: 30), sample(99, at: 31), sample(120, at: 200)],
            start: start, end: start.addingTimeInterval(30), intervalSeconds: 15)
        #expect(series.count == 2)
        #expect(series == [0, 150], "the sample AT the end lands in the last bucket; before start and after end are not this workout")
    }

    @Test func pointsSkipGapsAndCarryElapsedSeconds() {
        let points = HeartRateSeriesMath.points(from: [0, 120, 0, 135], intervalSeconds: 15)
        #expect(points.map(\.bpm) == [120, 135])
        #expect(points.map(\.elapsedSeconds) == [15, 45])
    }

    /// codex-review 05: past the cap the series TRUNCATES — samples beyond the
    /// horizon are dropped, never folded into the last retained bucket.
    @Test func theBucketCountIsCappedAndTheTailIsDroppedNotFolded() {
        let horizon = TimeInterval(HeartRateSeriesMath.maxBuckets * 15)
        let series = HeartRateSeriesMath.series(
            from: [sample(120, at: horizon - 5), sample(200, at: horizon), sample(200, at: horizon + 100), sample(200, at: 9 * 86_400)],
            start: start, end: start.addingTimeInterval(10 * 86_400), intervalSeconds: 15)
        #expect(series.count == HeartRateSeriesMath.maxBuckets)
        #expect(series.last == 120, "the last retained bucket holds only what fell in it; a sample exactly ON the cap horizon belongs to the first omitted bucket")
    }

    // MARK: Low and high beside the mean (finish-graph ticket 01)

    @Test func theFoldKeepsEachBucketsLowAndHighAndGapsAreZeroInAllThree() {
        let folded = HeartRateSeriesMath.fold(
            from: [sample(100, at: 1), sample(110, at: 5), sample(140, at: 31), sample(141, at: 44)],
            start: start, end: start.addingTimeInterval(60), intervalSeconds: 15)
        #expect(folded.mean == [105, 0, 141, 0], "the mean is what `series` always returned")
        #expect(folded.low == [100, 0, 140, 0])
        #expect(folded.high == [110, 0, 141, 0])
        #expect(folded.hasSamples)
        for index in folded.mean.indices where folded.mean[index] > 0 {
            #expect(folded.low[index] <= folded.mean[index] && folded.mean[index] <= folded.high[index])
        }
        #expect(HeartRateSeriesMath.fold(from: [], start: start, end: start) == .empty)
        #expect(!HeartRateSeriesMath.fold(from: [], start: start, end: start.addingTimeInterval(30)).hasSamples)
    }

    @Test func displaySlotsMergeToTheCapKeepGapsAndUseTheRealRange() {
        // 8 buckets, cap 4 → 2 buckets per slot. Slot 1 (buckets 2–3) is all
        // gap and must not be drawn; slot 2 has one gap bucket that must not
        // drag its low to 0.
        let mean = [100, 110, 0, 0, 120, 0, 130, 140]
        let low = [95, 105, 0, 0, 118, 0, 125, 136]
        let high = [104, 116, 0, 0, 124, 0, 133, 145]
        let slots = HeartRateSeriesMath.displaySlots(
            mean: mean, low: low, high: high, intervalSeconds: 15, durationSeconds: 120, maxSlots: 4)
        #expect(slots.map(\.index) == [0, 2, 3], "the all-gap slot is a hole, not a bar")
        #expect(slots.map(\.low) == [95, 118, 125])
        #expect(slots.map(\.high) == [116, 124, 145])
        #expect(slots.map(\.startSeconds) == [0, 60, 90])
        #expect(slots.map(\.endSeconds) == [30, 90, 120])
        #expect(slots.count <= 4)
        #expect(HeartRateSeriesMath.range(of: slots) == 95...145)
        #expect(HeartRateSeriesMath.range(of: []) == nil)
    }

    @Test func aShortSeriesPassesThroughBucketForBucketAndEndsAtTheWorkoutsEnd() {
        let slots = HeartRateSeriesMath.displaySlots(
            mean: [120, 0, 135], low: [118, 0, 130], high: [125, 0, 138],
            intervalSeconds: 15, durationSeconds: 31)
        #expect(slots.map(\.index) == [0, 2])
        #expect(slots.map(\.startSeconds) == [0, 30])
        #expect(slots.map(\.endSeconds) == [15, 31], "the last bucket ends where the workout did, not at 45 s")
        #expect(slots.last?.low == 130 && slots.last?.high == 138)
    }

    /// A workout folded before low/high existed has only its means: a merged
    /// slot spans the range of the means inside it (real numbers, narrower
    /// than the samples), and an unmerged one is a flat tick at the mean.
    @Test func withoutARangeTheMeansStandInAndAMismatchedRangeIsIgnored() {
        let meansOnly = HeartRateSeriesMath.displaySlots(
            mean: [100, 110, 120, 130], low: [], high: [], intervalSeconds: 15, durationSeconds: 60, maxSlots: 2)
        #expect(meansOnly.map(\.low) == [100, 120])
        #expect(meansOnly.map(\.high) == [110, 130])
        let flat = HeartRateSeriesMath.displaySlots(
            mean: [100, 110], low: [], high: [], intervalSeconds: 15, durationSeconds: 30)
        #expect(flat.map { $0.low == $0.high } == [true, true], "unmerged and rangeless: a tick at the mean")
        // A range of the wrong length is not trusted: it is some other series.
        let mismatched = HeartRateSeriesMath.displaySlots(
            mean: [100, 110], low: [50], high: [200], intervalSeconds: 15, durationSeconds: 30)
        #expect(mismatched.map(\.low) == [100, 110] && mismatched.map(\.high) == [100, 110])
    }

    /// The screenshot fixture is data the user compares against Apple's own
    /// chart, so it has to obey the fold's invariants exactly.
    @Test @MainActor func theHourLongFixtureIsAWellFormedSeriesAndSeedsOnce() throws {
        let folded = HeartRateHistoryFixture.folded()
        #expect(folded.mean.count == 240, "60 min at 15 s")
        #expect(folded.low.count == 240 && folded.high.count == 240)
        #expect(folded.mean.contains(0), "it has a gap to draw")
        for index in folded.mean.indices {
            if folded.mean[index] == 0 {
                #expect(folded.low[index] == 0 && folded.high[index] == 0)
            } else {
                #expect(folded.low[index] <= folded.mean[index] && folded.mean[index] <= folded.high[index])
                #expect(folded.low[index] > 60 && folded.high[index] < 190, "a plausible strength session")
            }
        }
        #expect(HeartRateHistoryFixture.folded() == folded, "deterministic — the screenshot must not drift")

        let ctx = try context()
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: ctx)
        try HeartRateHistoryFixture.seed(in: ctx)
        try HeartRateHistoryFixture.seed(in: ctx)
        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1, "idempotent")
        let workout = try #require(workouts.first)
        let summary = WorkoutSummaryBuilder.summary(for: workout)
        #expect(summary.hasHeartRateSeries)
        #expect(summary.heartRateSeriesLow == folded.low)
        #expect(summary.averageHeartRate != nil && summary.maxHeartRate == folded.high.max())
        #expect(HeartRateSeriesMath.displaySlots(
            mean: folded.mean, low: folded.low, high: folded.high, intervalSeconds: 15, durationSeconds: 3_600
        ).count <= HeartRateSeriesMath.defaultMaxSlots)
    }

    // MARK: codex-review 01 of the finish graph

    /// The screenshot fixtures may only ever seed the wiped UI-test store.
    /// The flag alone never selected it (high): without `-uiTestReset` it
    /// would have written a fake workout into a real, empty history.
    @Test func aFixtureFlagWithoutTheResetFlagSeedsNothing() {
        #expect(!HeartRateHistoryFixture.isEnabled(arguments: [HeartRateHistoryFixture.launchArgument]))
        #expect(HeartRateHistoryFixture.isEnabled(arguments: ["-uiTestReset", HeartRateHistoryFixture.launchArgument]))
        #expect(!HeartRateHistoryFixture.isEnabled(arguments: ["-uiTestReset"]))
        // The older chart fixture had the identical hole.
        #expect(!ChartFixture.isEnabled(arguments: [ChartFixture.launchArgument]))
        #expect(ChartFixture.isEnabled(arguments: ["-uiTestReset", ChartFixture.launchArgument]))
        // One owner for the rule (codex-review 01b).
        #expect(!WorkoutTrackerStore.fixtureIsEnabled("-anyFixture", in: ["-anyFixture"]))
        #expect(WorkoutTrackerStore.fixtureIsEnabled("-anyFixture", in: ["-anyFixture", WorkoutTrackerStore.uiTestResetArgument]))
    }

    /// A slot that starts at or past a (corrupt) duration is dropped, and
    /// every kept slot ends within it — an invisible slot beyond the plot
    /// must not set the visible axis (medium).
    @Test func slotsBeyondTheWorkoutsDurationAreDroppedNotDrawnOffPlot() {
        let slots = HeartRateSeriesMath.displaySlots(
            mean: [120, 190], low: [118, 185], high: [125, 195], intervalSeconds: 15, durationSeconds: 10)
        #expect(slots.count == 1)
        #expect(slots.first?.endSeconds == 10)
        #expect(HeartRateSeriesMath.range(of: slots) == 118...125, "the 190 bucket past the end cannot reach the axis")
        // No horizon known: nothing is clipped.
        let unclipped = HeartRateSeriesMath.displaySlots(
            mean: [120, 190], low: [], high: [], intervalSeconds: 15, durationSeconds: 0)
        #expect(unclipped.map(\.endSeconds) == [15, 30])
    }

    /// codex-review 01b: the horizon must apply BEFORE merging. A corrupt
    /// 111-bucket series (perSlot 2 at the default cap) with a 10 s duration
    /// is ONE real bucket: it must come back alone, bucket-for-bucket, with
    /// the post-duration neighbour reaching neither its range nor the axis.
    @Test func postDurationBucketsNeitherMergeIntoNorRangeTheRealOnes() {
        var mean = [Int](repeating: 190, count: 111); mean[0] = 120
        var low = [Int](repeating: 185, count: 111); low[0] = 118
        var high = [Int](repeating: 195, count: 111); high[0] = 125
        let slots = HeartRateSeriesMath.displaySlots(
            mean: mean, low: low, high: high, intervalSeconds: 15, durationSeconds: 10)
        #expect(slots.count == 1)
        #expect(slots.first?.low == 118 && slots.first?.high == 125, "bucket 1 is past the end and cannot colour bucket 0's slot")
        #expect(slots.first?.endSeconds == 10)
        // And a real 31 s workout with a 111-bucket tail is three buckets, unmerged.
        let three = HeartRateSeriesMath.displaySlots(
            mean: mean, low: low, high: high, intervalSeconds: 15, durationSeconds: 31)
        #expect(three.map(\.startSeconds) == [0, 15, 30])
        #expect(three.last?.endSeconds == 31)
    }

    /// codex-review 01b: the view used to turn a non-positive duration into
    /// a one-second horizon. The extent it hands the slots and the x-scale
    /// is the series' own when the duration is unknown.
    @Test func thePlotExtentFallsBackToTheSeriesWhenTheDurationIsNotPositive() {
        #expect(HeartRateSeriesMath.plotExtentSeconds(durationSeconds: 0, bucketCount: 2, intervalSeconds: 15) == 30)
        #expect(HeartRateSeriesMath.plotExtentSeconds(durationSeconds: -5, bucketCount: 2, intervalSeconds: 15) == 30)
        #expect(HeartRateSeriesMath.plotExtentSeconds(durationSeconds: 31, bucketCount: 3, intervalSeconds: 15) == 31)
        #expect(HeartRateSeriesMath.plotExtentSeconds(durationSeconds: 3_600, bucketCount: 3, intervalSeconds: 15) == 45, "never past the series")
        #expect(HeartRateSeriesMath.plotExtentSeconds(durationSeconds: 0, bucketCount: 0, intervalSeconds: 15) == 1)
        // The extent then draws every slot of a duration-less series.
        let extent = HeartRateSeriesMath.plotExtentSeconds(durationSeconds: 0, bucketCount: 2, intervalSeconds: 15)
        #expect(HeartRateSeriesMath.displaySlots(mean: [120, 130], low: [], high: [], intervalSeconds: 15, durationSeconds: extent).count == 2)
    }

    /// The export carries the range pair only beside a mean of the same
    /// length — both arrays or neither (medium).
    @Test @MainActor func theExportOmitsALoneOrMismatchedRangeAsAPair() throws {
        #expect(HeartRateSeriesMath.exportableRange(mean: [1, 2], low: [1, 2], high: [1, 2]) != nil)
        #expect(HeartRateSeriesMath.exportableRange(mean: [1, 2], low: [1], high: [1, 2]) == nil)
        #expect(HeartRateSeriesMath.exportableRange(mean: [1, 2], low: [1, 2], high: []) == nil)
        #expect(HeartRateSeriesMath.exportableRange(mean: [], low: [1], high: [1]) == nil, "a range with no mean")

        let ctx = try context()
        let workout = Workout(startedAt: start, finishedAt: start.addingTimeInterval(60),
                              averageHeartRate: 130, heartRateSeries: [100, 140], heartRateSeriesIntervalSeconds: 15,
                              heartRateSeriesLow: [95], heartRateSeriesHigh: [104, 146])
        ctx.insert(workout)
        try ctx.save()
        let exported = try #require(try ExportCollector(appVersion: "test").snapshot(from: ctx).workouts.first)
        #expect(exported.heartRateSeries == [100, 140], "the mean still travels")
        #expect(exported.heartRateSeriesLow == nil && exported.heartRateSeriesHigh == nil, "a mismatched pair is dropped whole")
    }

    // MARK: Total energy

    @Test func totalCaloriesNeedsBothHalves() {
        #expect(WorkoutSummary.totalEnergyKilocalories(active: 300, basal: 80) == 380)
        #expect(WorkoutSummary.totalEnergyKilocalories(active: 300, basal: nil) == nil, "active alone is not total")
        #expect(WorkoutSummary.totalEnergyKilocalories(active: nil, basal: 80) == nil)
    }

    // MARK: The write

    @Test @MainActor func captureWritesTheSeriesAndBasalOntoTheWorkout() throws {
        let ctx = try context()
        let workout = Workout(startedAt: start)
        ctx.insert(workout)
        let samples = [sample(100, at: 2), sample(130, at: 20), sample(150, at: 40)]
        let vitals = WorkoutVitalsMath.vitals(from: samples, zoningAgainst: nil)
        WorkoutSummaryBuilder.capture(
            vitals: vitals, activeEnergyKilocalories: 120, basalEnergyKilocalories: 40,
            samples: samples, onto: workout, now: start.addingTimeInterval(50))
        #expect(workout.heartRateSeries == [100, 130, 150, 0])
        #expect(workout.heartRateSeriesLow == [100, 130, 150, 0], "one sample per bucket: low is the sample")
        #expect(workout.heartRateSeriesHigh == [100, 130, 150, 0])
        #expect(workout.heartRateSeriesIntervalSeconds == 15)
        #expect(workout.basalEnergyKilocalories == 40)
        let summary = WorkoutSummaryBuilder.summary(for: workout)
        #expect(summary.hasHeartRateSeries)
        #expect(summary.totalEnergyKilocalories == 160)
    }

    @Test @MainActor func noSamplesLeavesTheSeriesEmptyAndTotalHidden() throws {
        let ctx = try context()
        let workout = Workout(startedAt: start)
        ctx.insert(workout)
        WorkoutSummaryBuilder.capture(
            vitals: .empty, activeEnergyKilocalories: 90, basalEnergyKilocalories: nil,
            samples: [], onto: workout, now: start.addingTimeInterval(600))
        #expect(workout.heartRateSeries.isEmpty)
        #expect(workout.heartRateSeriesIntervalSeconds == nil)
        let summary = WorkoutSummaryBuilder.summary(for: workout)
        #expect(!summary.hasHeartRateSeries, "no chart for a workout without a series")
        #expect(summary.totalEnergyKilocalories == nil, "no basal → total row hidden, not 0")
        #expect(summary.activeEnergyKilocalories == 90)
    }

    /// End to end through the coordinator — the path every way out of a
    /// workout takes — so the series cannot be a field nothing sets.
    @Test @MainActor func endingTheSessionThroughTheCoordinatorWritesTheSeries() throws {
        let ctx = try context()
        let workout = Workout(startedAt: Date().addingTimeInterval(-90))
        ctx.insert(workout)
        let coordinator = WorkoutHeartRateCoordinator()
        let monitor = coordinator.monitor(for: workout, maxHeartRate: nil)
        for (i, bpm) in [110, 125, 140, 138, 120].enumerated() {
            monitor.ingestForTesting(HeartRateSample(bpm: bpm, date: workout.startedAt.addingTimeInterval(Double(i) * 15 + 2), source: .fixture))
        }
        coordinator.end(workout)
        #expect(!workout.heartRateSeries.isEmpty, "the coordinator must hand the samples to capture")
        #expect(workout.heartRateSeries.prefix(5) == [110, 125, 140, 138, 120])
        #expect(workout.heartRateSeriesIntervalSeconds == HeartRateSeriesMath.defaultIntervalSeconds)
        #expect(workout.averageHeartRate != nil)
    }

    // MARK: Export

    @Test @MainActor func theSeriesRoundTripsThroughJSONAndOlderFilesDecode() throws {
        let ctx = try context()
        let workout = Workout(startedAt: start, finishedAt: start.addingTimeInterval(60),
                              averageHeartRate: 130, maxHeartRate: 150, activeEnergyKilocalories: 100,
                              heartRateSeries: [100, 0, 140, 150], heartRateSeriesIntervalSeconds: 15,
                              heartRateSeriesLow: [95, 0, 135, 148], heartRateSeriesHigh: [104, 0, 146, 152],
                              basalEnergyKilocalories: 30)
        ctx.insert(workout)
        let entry = ExerciseEntry(order: 0, workout: workout, snapshotCapturedAt: start,
                                  snapshotExerciseID: UUID(), snapshotLoadType: .weighted, snapshotExerciseName: "Row")
        ctx.insert(entry)
        let set = SetRecord(order: 0, type: .working, entry: entry)
        set.reps = 5; set.weightValue = 50; set.weightUnit = .kg; set.normalizedKg = 50; set.completedAt = start.addingTimeInterval(30)
        ctx.insert(set)
        try ctx.save()

        var snapshot = try ExportCollector(appVersion: "test").snapshot(from: ctx)
        #expect(snapshot.schemaVersion == 10)
        let decoded = try ExportJSON.decode(try ExportJSON.data(snapshot))
        #expect(decoded.workouts.first?.heartRateSeries == [100, 0, 140, 150])
        #expect(decoded.workouts.first?.heartRateSeriesIntervalSeconds == 15)
        #expect(decoded.workouts.first?.heartRateSeriesLow == [95, 0, 135, 148])
        #expect(decoded.workouts.first?.heartRateSeriesHigh == [104, 0, 146, 152])
        #expect(decoded.workouts.first?.basalEnergyKilocalories == 30)
        #expect(decoded == snapshot)

        // A v8 file carries the mean and no range: it must decode with the
        // range absent, and a workout restored from it draws from its means.
        snapshot.schemaVersion = 8
        snapshot.workouts[0].heartRateSeriesLow = nil
        snapshot.workouts[0].heartRateSeriesHigh = nil
        let v8 = try ExportJSON.data(snapshot)
        #expect(!String(decoding: v8, as: UTF8.self).contains("heartRateSeriesLow"))
        let fromV8 = try ExportJSON.decode(v8)
        #expect(fromV8.workouts.first?.heartRateSeriesLow == nil)
        #expect(fromV8.workouts.first?.heartRateSeries == [100, 0, 140, 150])

        // A v7 file has none of these keys; encoding nil omits them, so this IS
        // that shape, and it must decode with the fields absent.
        snapshot.schemaVersion = 7
        snapshot.workouts[0].heartRateSeries = nil
        snapshot.workouts[0].heartRateSeriesIntervalSeconds = nil
        snapshot.workouts[0].basalEnergyKilocalories = nil
        let v7 = try ExportJSON.data(snapshot)
        #expect(!String(decoding: v7, as: UTF8.self).contains("heartRateSeries"))
        let old = try ExportJSON.decode(v7)
        #expect(old.workouts.first?.heartRateSeries == nil)
        #expect(old.workouts.first?.averageHeartRate == 130, "the aggregates a v7 file DOES carry still arrive")
    }

    // MARK: Which samples the summary is built from (codex-review 05)

    @Test func theOtherSensorFillsOnlyAGenuineDominantOutage() {
        // AirPods report for 0–60 s, go silent for 90 s, and report 150–210 s;
        // the Watch reports throughout, and once more after the AirPods' last
        // sample (the codex-review-2 #6 case: a late stray reading).
        var samples: [HeartRateSample] = []
        for t in stride(from: 0, through: 60, by: 10) { samples.append(sample(120, at: TimeInterval(t), source: .airPods)) }
        for t in stride(from: 150, through: 210, by: 10) { samples.append(sample(125, at: TimeInterval(t), source: .airPods)) }
        for t in stride(from: 0, through: 210, by: 10) { samples.append(sample(140, at: TimeInterval(t) + 1, source: .watch)) }
        samples.append(sample(60, at: 260, source: .watch))
        let merged = WorkoutVitalsMath.summarySamples(from: samples, dominant: .airPods)
        let watchKept = merged.filter { $0.source == .watch }
        #expect(!watchKept.isEmpty, "the Watch covered the AirPods' outage")
        #expect(watchKept.allSatisfy { $0.date.timeIntervalSince(start) > 60 && $0.date.timeIntervalSince(start) < 150 },
                "only readings strictly inside the 90 s outage; none from the overlap, none after the last AirPods sample")
        #expect(merged.filter { $0.source == .airPods }.count == 14, "every dominant sample is kept")
        #expect(!merged.contains { $0.bpm == 60 }, "the late stray reading stays out (codex-review-2 #6)")
        // And the series drawn from them has no false gap across the outage.
        let series = HeartRateSeriesMath.series(from: merged, start: start, end: start.addingTimeInterval(210))
        #expect(series.allSatisfy { $0 > 0 }, "a sensor handoff is data, not a gap: \(series)")
        // A gap of exactly the threshold is not an outage.
        let tight = [sample(120, at: 0, source: .airPods), sample(120, at: 60, source: .airPods), sample(140, at: 30, source: .watch)]
        #expect(WorkoutVitalsMath.summarySamples(from: tight, dominant: .airPods).count == 2)
    }

    @Test @MainActor func aReplacementWorkoutBanksThePreviousOnesSummary() throws {
        let ctx = try context()
        let first = Workout(startedAt: Date().addingTimeInterval(-120))
        let second = Workout(startedAt: .now)
        ctx.insert(first); ctx.insert(second)
        let coordinator = WorkoutHeartRateCoordinator()
        let monitor = coordinator.monitor(for: first, maxHeartRate: nil)
        for i in 0..<4 {
            monitor.ingestForTesting(HeartRateSample(bpm: 120 + i, date: first.startedAt.addingTimeInterval(Double(i) * 15 + 1), source: .fixture))
        }
        // "Finish it and start new": a different workout asks for a monitor.
        _ = coordinator.monitor(for: second, maxHeartRate: nil)
        #expect(first.averageHeartRate != nil, "the replaced workout keeps its aggregates")
        #expect(!first.heartRateSeries.isEmpty, "and its series")
        #expect(coordinator.workoutID == second.id)
    }

    @Test @MainActor func energyIsRefreshedAsAPairAtTheFinishBoundary() throws {
        let ctx = try context()
        let workout = Workout(startedAt: Date().addingTimeInterval(-60))
        ctx.insert(workout)
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        let coordinator = WorkoutHeartRateCoordinator()
        coordinator.adoptForTesting(monitor: monitor, workoutID: workout.id)
        // Energy arrives AFTER the last bpm — nothing ever ingests it.
        provider.activeEnergyKilocalories = 88
        provider.basalEnergyKilocalories = 30
        coordinator.end(workout)
        #expect(workout.activeEnergyKilocalories == 88)
        #expect(workout.basalEnergyKilocalories == 30, "basal must not be left stale when active is refreshed")
        #expect(WorkoutSummaryBuilder.summary(for: workout).totalEnergyKilocalories == 118)
    }

    /// codex-review 05b: a SUSTAINED terminal handoff counts — the Watch
    /// carrying the last minutes after the AirPods die, or the first minutes
    /// before they connect — while one stray reading still does not.
    @Test func sustainedTerminalHandoffsCountButAStrayDoesNot() {
        var samples: [HeartRateSample] = []
        for t in stride(from: 100, through: 400, by: 10) { samples.append(sample(120, at: TimeInterval(t), source: .airPods)) }
        // Leading: the Watch alone for 0–95 s (95 s span → sustained).
        for t in stride(from: 0, through: 95, by: 5) { samples.append(sample(135, at: TimeInterval(t), source: .watch)) }
        // Trailing: the Watch alone for 410–700 s (290 s span → sustained).
        for t in stride(from: 410, through: 700, by: 10) { samples.append(sample(128, at: TimeInterval(t), source: .watch)) }
        let merged = WorkoutVitalsMath.summarySamples(from: samples, dominant: .airPods)
        let watch = merged.filter { $0.source == .watch }
        #expect(watch.contains { $0.date.timeIntervalSince(start) == 0 }, "the leading run is kept")
        #expect(watch.contains { $0.date.timeIntervalSince(start) == 700 }, "the trailing run is kept")
        #expect(watch.count == 20 + 30)
        let series = HeartRateSeriesMath.series(from: merged, start: start, end: start.addingTimeInterval(700))
        #expect(series.allSatisfy { $0 > 0 }, "no false gap at either end: \(series)")

        // The stray: one Watch reading three minutes after the last AirPods
        // sample (codex-review-2 #6) — no span, not a run, stays out.
        let airPods = samples.filter { $0.source == .airPods }
        let stray = airPods + [sample(60, at: 580, source: .watch)]
        #expect(WorkoutVitalsMath.summarySamples(from: stray, dominant: .airPods).allSatisfy { $0.source == .airPods })
        // Two lone readings 61 s apart span the threshold but are not a sensor
        // REPORTING — their own gap exceeds it (codex-review 05c). Out.
        let twoLone = airPods + [sample(60, at: 500, source: .watch), sample(62, at: 561, source: .watch)]
        #expect(WorkoutVitalsMath.summarySamples(from: twoLone, dominant: .airPods).allSatisfy { $0.source == .airPods })
        // Whereas the same span with continuous reporting is a run.
        let continuous = airPods + stride(from: 410, through: 480, by: 10).map { sample(128, at: TimeInterval($0), source: .watch) }
        #expect(WorkoutVitalsMath.summarySamples(from: continuous, dominant: .airPods).contains { $0.source == .watch })
    }

    /// codex-review 05b: a replacement banked AFTER the workout was finished
    /// (the drift-resolution order) ends its series where the workout did,
    /// not at the wall clock.
    @Test @MainActor func aLateBankUsesTheRecordedFinishAsTheSeriesEnd() throws {
        let ctx = try context()
        let started = Date().addingTimeInterval(-3_600)
        let workout = Workout(startedAt: started, finishedAt: started.addingTimeInterval(120))
        ctx.insert(workout)
        let coordinator = WorkoutHeartRateCoordinator()
        let monitor = coordinator.monitor(for: workout, maxHeartRate: nil)
        for i in 0..<8 {
            monitor.ingestForTesting(HeartRateSample(bpm: 120, date: started.addingTimeInterval(Double(i) * 15 + 1), source: .fixture))
        }
        // Readings that arrived AFTER the recorded finish (codex-review 05c):
        // they must change neither the chart nor the aggregates under it.
        for i in 0..<20 {
            monitor.ingestForTesting(HeartRateSample(bpm: 190, date: started.addingTimeInterval(200 + Double(i) * 15), source: .fixture))
        }
        coordinator.end(workout)
        #expect(workout.heartRateSeries.count == 8, "120 s / 15 s, not an hour of buckets")
        #expect(workout.maxHeartRate == 120, "a post-finish 190 must not become the workout's maximum")
        #expect(workout.averageHeartRate == 120)
    }

    /// codex-review 05d: on a late bank, a flood of post-finish readings from
    /// the OTHER sensor must not make it dominant and throw the real in-workout
    /// data away. Bound first, then choose.
    @Test @MainActor func postFinishReadingsCannotChangeWhichSensorRecordedTheWorkout() throws {
        let ctx = try context()
        let started = Date().addingTimeInterval(-3_600)
        let workout = Workout(startedAt: started, finishedAt: started.addingTimeInterval(50))
        ctx.insert(workout)
        let coordinator = WorkoutHeartRateCoordinator()
        let monitor = coordinator.monitor(for: workout, maxHeartRate: nil)
        for i in 0..<6 {
            monitor.ingestForTesting(HeartRateSample(bpm: 130, date: started.addingTimeInterval(Double(i) * 8 + 1), source: .airPods))
        }
        for i in 0..<200 {
            monitor.ingestForTesting(HeartRateSample(bpm: 70, date: started.addingTimeInterval(60 + Double(i) * 5), source: .watch))
        }
        #expect(monitor.dominantSource == .watch, "over the whole history the Watch dominates — which is exactly the trap")
        coordinator.end(workout)
        #expect(workout.averageHeartRate == 130, "the workout was recorded on AirPods; the summary must say so")
        #expect(workout.maxHeartRate == 130)
        #expect(workout.heartRateSeries.count == 4)
        #expect(workout.heartRateSeries.allSatisfy { $0 == 0 || $0 == 130 })
    }
}
