import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@MainActor
struct CardioRecorderTests {
    private final class Clock { var date = Date(timeIntervalSince1970: 1_800_000_000) }
    private final class Feed: HeartRateProviding {
        var cardioReading: CardioSensorReading?
        var collectionStartedAt: Date?
        var activeEnergyKilocalories: Double? = 10
        var finalEnergy: Double = 15
        var paused = false
        let stream = AsyncStream<HeartRateSample> { _ in }
        func start() async -> HeartRateFeedState { .waitingForSensor }
        func setPaused(_ value: Bool) async { paused = value }
        func stop() async { activeEnergyKilocalories = finalEnergy }
    }
    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
    private func fix(_ lat: Double, _ lon: Double, _ date: Date, accuracy: Double = 5) -> CLLocation {
        CLLocation(coordinate: .init(latitude: lat, longitude: lon), altitude: 0,
                   horizontalAccuracy: accuracy, verticalAccuracy: 5, timestamp: date)
    }

    @Test func lateHealthKitTotalAfterPauseReplacesTheSameEpochsPhoneDistance() async throws {
        let context = try context(); let clock = Clock()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: clock.date)
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: clock.date)
        let initialStart = clock.date
        let feed = Feed()
        let provider = WorkoutActivityProvider(configuration: .init(segmentID: segment.id, activity: .indoorRun)) { _ in feed }
        let monitor = HeartRateMonitor(provider: provider); await monitor.start()
        let recorder = CardioRecorder(collectsDeviceSensors: false, clock: { clock.date })
        recorder.attach(to: workout, monitor: monitor)
        clock.date.addTimeInterval(100)
        recorder.acceptPhoneDistance(500, at: clock.date, since: initialStart, segmentID: segment.id)
        #expect(segment.distanceMeters == 500)
        recorder.pause()
        clock.date.addTimeInterval(60); recorder.resume()
        for _ in 0..<30 { await Task.yield() }
        #expect(feed.paused == false, "a queued pause cannot override a later resume")
        let resumed = clock.date
        clock.date.addTimeInterval(30)
        recorder.acceptPhoneDistance(300, at: clock.date, since: resumed, segmentID: segment.id)
        #expect(segment.distanceMeters == 800)
        feed.cardioReading = .init(distanceMeters: 780, date: clock.date)
        recorder.refresh()
        #expect(segment.distanceMeters == 780, "cumulative alternatives replace; 500 + 780 would duplicate the first span")
        #expect(segment.distanceSpans.count == 1)
        #expect(segment.source == .healthKit)
        recorder.stop(); await monitor.stop()
    }

    @Test func delayedTotalsAreRetainedButStalePaceIsNotShown() async throws {
        let context = try context(); let clock = Clock()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: clock.date)
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: clock.date)
        let feed = Feed()
        let provider = WorkoutActivityProvider(configuration: .init(segmentID: segment.id, activity: .indoorRun)) { _ in feed }
        let monitor = HeartRateMonitor(provider: provider); await monitor.start()
        let recorder = CardioRecorder(collectsDeviceSensors: false, clock: { clock.date })
        recorder.attach(to: workout, monitor: monitor)
        clock.date.addTimeInterval(60)
        feed.cardioReading = .init(distanceMeters: 200, date: clock.date.addingTimeInterval(-30))
        recorder.refresh()
        #expect(segment.distanceMeters == 200)
        #expect(recorder.freshSpeed == nil)
        recorder.stop(); await monitor.stop()
    }

    @Test func deviceSilenceCanFallBackToPhoneMotionWithoutAddingBothTotals() async throws {
        let context = try context(); let clock = Clock()
        let start = clock.date
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: start)
        let feed = Feed()
        let provider = WorkoutActivityProvider(configuration: .init(segmentID: segment.id, activity: .indoorRun)) { _ in feed }
        let monitor = HeartRateMonitor(provider: provider); await monitor.start()
        let recorder = CardioRecorder(collectsDeviceSensors: false, clock: { clock.date })
        recorder.attach(to: workout, monitor: monitor)
        clock.date.addTimeInterval(10)
        feed.cardioReading = .init(distanceMeters: 100, date: clock.date); recorder.refresh()
        clock.date.addTimeInterval(20)
        recorder.acceptPhoneDistance(150, at: clock.date, since: start, segmentID: segment.id)
        #expect(segment.distanceMeters == 150)
        #expect(segment.source == .phoneMotion)
        feed.cardioReading = .init(distanceMeters: 145, date: clock.date); recorder.refresh()
        #expect(segment.distanceMeters == 145)
        #expect(segment.source == .healthKit)
        recorder.stop(); await monitor.stop()
    }

    @Test func gpsKeepsGrowingAcrossReattachAndDoesNotJoinPauseOrOutageGaps() throws {
        let context = try context(); let clock = Clock()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: clock.date)
        let segment = try CardioSession(context: context).start(.outdoorRun, in: workout, at: clock.date)
        let monitor = HeartRateMonitor(provider: DisabledHeartRateProvider())
        let recorder = CardioRecorder(collectsDeviceSensors: false, clock: { clock.date })
        recorder.attach(to: workout, monitor: monitor)
        recorder.accept([fix(40, -73, clock.date)])
        clock.date.addTimeInterval(2); recorder.accept([fix(40.0001, -73, clock.date)])
        let before = try #require(segment.distanceMeters)
        // The screen can go away and reattach while the recorder owns the session.
        recorder.attach(to: workout, monitor: monitor)
        clock.date.addTimeInterval(2); recorder.accept([fix(40.0002, -73, clock.date)])
        #expect(try #require(segment.distanceMeters) > before)
        recorder.pause(); let pausedMeters = segment.distanceMeters
        clock.date.addTimeInterval(30)
        recorder.accept([fix(40.001, -73, clock.date)])
        #expect(segment.distanceMeters == pausedMeters)
        recorder.resume(); recorder.accept([fix(40.001, -73, clock.date)])
        #expect(segment.distanceMeters == pausedMeters, "no straight-line distance across a pause")
        clock.date.addTimeInterval(2); recorder.accept([fix(40.0011, -73, clock.date)])
        #expect(try #require(segment.distanceMeters) > (pausedMeters ?? 0))
        #expect(Set(segment.route.map(\.portion)).count == 2)
        let beforeOutage = segment.distanceMeters
        clock.date.addTimeInterval(30); recorder.accept([fix(40.002, -73, clock.date)])
        #expect(segment.distanceMeters == beforeOutage)
        #expect(Set(segment.route.map(\.portion)).count == 3)
        recorder.stop()
    }

    @Test func indoorCountersStartTogetherAfterSensorSetup() async throws {
        let context = try context(); let clock = Clock()
        let initial = clock.date
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: initial)
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: initial)
        clock.date.addTimeInterval(30)
        let collectionStart = clock.date
        let feed = Feed(); feed.collectionStartedAt = collectionStart
        let provider = WorkoutActivityProvider(configuration: .init(segmentID: segment.id, activity: .indoorRun)) { _ in feed }
        let monitor = HeartRateMonitor(provider: provider); await monitor.start()
        let recorder = CardioRecorder(collectsDeviceSensors: false, clock: { clock.date })
        recorder.attach(to: workout, monitor: monitor)
        clock.date.addTimeInterval(30)
        recorder.acceptPhoneDistance(100, at: clock.date, since: collectionStart, segmentID: segment.id)
        feed.cardioReading = .init(distanceMeters: 90, date: clock.date); recorder.refresh()
        #expect(segment.distanceSpans.first?.start == collectionStart)
        #expect(segment.distanceMeters == 90)
        recorder.stop(); await monitor.stop()
    }

    @Test func cardioHeartRateDoesNotSelectAWatchReadingFromThePreviousActivity() throws {
        let context = try context(); let clock = Clock()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: clock.date.addingTimeInterval(-30))
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: clock.date)
        let monitor = HeartRateMonitor(provider: DisabledHeartRateProvider())
        monitor.ingestForTesting(.init(bpm: 180, date: clock.date.addingTimeInterval(-2), source: .watch))
        monitor.ingestForTesting(.init(bpm: 120, date: clock.date, source: .airPods))
        let recorder = CardioRecorder(collectsDeviceSensors: false, clock: { clock.date })
        recorder.attach(to: workout, monitor: monitor)
        #expect(recorder.currentHeartRate?.bpm == 120)
        #expect(segment.averageHeartRate == 120)
        clock.date.addTimeInterval(16); recorder.refresh()
        #expect(recorder.currentHeartRate == nil)
        recorder.stop()
    }

    @Test func endingPhaseBanksFinalSegmentEnergy() async throws {
        let context = try context(); let clock = Clock()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: clock.date)
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: clock.date)
        let feed = Feed()
        let provider = WorkoutActivityProvider(configuration: .init(segmentID: segment.id, activity: .indoorRun)) { _ in feed }
        let monitor = HeartRateMonitor(provider: provider); await monitor.start()
        let recorder = CardioRecorder(collectsDeviceSensors: false, clock: { clock.date })
        recorder.attach(to: workout, monitor: monitor)
        recorder.refresh(); #expect(segment.activeEnergyKilocalories == 10)
        recorder.stop(); await monitor.stop()
        #expect(segment.activeEnergyKilocalories == 15)
    }
}
