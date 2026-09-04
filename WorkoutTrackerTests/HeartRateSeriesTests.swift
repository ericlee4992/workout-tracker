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
            from: [sample(120, at: horizon - 5), sample(200, at: horizon + 100), sample(200, at: 9 * 86_400)],
            start: start, end: start.addingTimeInterval(10 * 86_400), intervalSeconds: 15)
        #expect(series.count == HeartRateSeriesMath.maxBuckets)
        #expect(series.last == 120, "the last retained bucket holds only what fell in it")
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
        #expect(snapshot.schemaVersion == 8)
        let decoded = try ExportJSON.decode(try ExportJSON.data(snapshot))
        #expect(decoded.workouts.first?.heartRateSeries == [100, 0, 140, 150])
        #expect(decoded.workouts.first?.heartRateSeriesIntervalSeconds == 15)
        #expect(decoded.workouts.first?.basalEnergyKilocalories == 30)
        #expect(decoded == snapshot)

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
}
