import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@MainActor
struct SensorCheckpointTests {
    private final class Feed: HeartRateProviding {
        let stream = AsyncStream<HeartRateSample> { _ in }
        var activeEnergyKilocalories: Double? = 20
        var basalEnergyKilocalories: Double? = 5
        var collectionStartedAt: Date?
        func start() async -> HeartRateFeedState { .waitingForSensor }
        func stop() async { activeEnergyKilocalories = 25 }
    }
    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
    @Test func resumedSessionAddsNewEnergyAndKeepsEarlierHeartbeats() async throws {
        let context = try context()
        let now = Date()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: now.addingTimeInterval(-100))
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: workout.startedAt)
        segment.pause(at: now.addingTimeInterval(-10))
        segment.heartRateCount = 1; segment.heartRateTotal = 140
        segment.averageHeartRate = 140; segment.maxHeartRate = 140
        segment.activeEnergyKilocalories = 250
        segment.basalEnergyKilocalories = 30
        workout.sensorActiveEnergyCheckpoint = 300
        workout.sensorBasalEnergyCheckpoint = 40
        let earlier = HeartRateSample(bpm: 140, date: now.addingTimeInterval(-50), source: .airPods)
        context.insert(WorkoutSensorSample(sample: earlier, workout: workout))
        try context.save()
        let feed = Feed(); feed.collectionStartedAt = now
        let provider = WorkoutActivityProvider(configuration: .init(segmentID: segment.id, activity: .indoorRun, paused: true),
                                               initialActiveEnergy: workout.sensorActiveEnergyCheckpoint,
                                               initialBasalEnergy: workout.sensorBasalEnergyCheckpoint) { _ in feed }
        let monitor = HeartRateMonitor(provider: provider, initialSamples: workout.checkpointSamples)
        await monitor.start()
        let recorder = CardioRecorder(collectsDeviceSensors: false)
        recorder.attach(to: workout, monitor: monitor)
        recorder.resume()
        await provider.configure(workout.sensorConfiguration)
        let recent = HeartRateSample(bpm: 160, date: .now, source: .airPods)
        monitor.ingestForTesting(recent)
        recorder.refresh()
        #expect(segment.averageHeartRate == 150)
        #expect(segment.activeEnergyKilocalories == 270)
        #expect(provider.activeEnergyKilocalories == 320)
        #expect(workout.sensorActiveEnergyCheckpoint == 320)
        #expect(workout.checkpointSamples.map(\.id) == [earlier.id, recent.id])
        recorder.stop(); await monitor.stop()
        #expect(segment.activeEnergyKilocalories == 275)
        #expect(provider.activeEnergyKilocalories == 325)
    }
    @Test func strayFinishFoldsSavedSamplesAndClearsCheckpointRows() throws {
        let context = try context()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: nil, on: start)
        _ = try CardioSession(context: context).start(.indoorRun, in: workout, at: start)
        context.insert(WorkoutSensorSample(sample: .init(bpm: 120, date: start.addingTimeInterval(10), source: .airPods), workout: workout))
        context.insert(WorkoutSensorSample(sample: .init(bpm: 140, date: start.addingTimeInterval(20), source: .airPods), workout: workout))
        workout.sensorActiveEnergyCheckpoint = 50
        workout.sensorBasalEnergyCheckpoint = 10
        workout.sensorMaxHeartRateBpm = 180
        workout.sensorMaxHeartRateEstimated = true
        try context.save()
        // No coordinator is present: replacement/recovery still freezes the facts.
        _ = try session.startWorkout(at: nil, on: start.addingTimeInterval(60))
        #expect(workout.averageHeartRate == 130)
        #expect(workout.maxHeartRate == 140)
        #expect(workout.activeEnergyKilocalories == 50)
        #expect(workout.basalEnergyKilocalories == 10)
        #expect(workout.heartRateSeries.contains { $0 > 0 })
        #expect(workout.zonesFromEstimatedMax == true)
        #expect(workout.sensorActiveEnergyCheckpoint == nil)
        #expect(try context.fetch(FetchDescriptor<WorkoutSensorSample>()).isEmpty)
    }

    @Test func energyOnlyCheckpointsAndActiveCardioTimeAreExported() throws {
        let context = try context()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let segment = try CardioSession(context: context).start(.indoorCycle, in: workout, at: start)
        workout.sensorActiveEnergyCheckpoint = 50
        workout.sensorBasalEnergyCheckpoint = 10
        let collector = ExportCollector()
        var snapshot = try collector.snapshot(from: context, now: start.addingTimeInterval(60))
        #expect(snapshot.workouts.first?.sensorCheckpoint?.activeEnergyKilocalories == 50)
        var rows = TestCSV.rows(ExportCSV.render(snapshot))
        let column = try #require(rows[0].firstIndex(of: "cardioActiveSeconds"))
        #expect(Double(rows[1][column]) == 60)
        try CardioSession(context: context).pause(segment, at: start.addingTimeInterval(60))
        snapshot = try collector.snapshot(from: context, now: start.addingTimeInterval(500))
        rows = TestCSV.rows(ExportCSV.render(snapshot))
        #expect(Double(rows[1][column]) == 60)
    }
}
