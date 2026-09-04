import Foundation
import Testing
@testable import WorkoutTracker

// Milestone 7, ticket 03 — the feed, driven by a stub provider. No HealthKit,
// no sensor, no sleeping: every test here answers "what should the screen say
// right now", including the cases where the honest answer is "nothing".

@MainActor
/// Test-only: the whole-history fold, for tests written against the monitor's
/// old unbounded `vitals`. Production has no such accessor on purpose
/// (codex-review 05e) — the persisted summary is bounded to the workout first.
extension HeartRateMonitor {
    var liveVitals: WorkoutVitals {
        guard let source = dominantSource else { return .empty }
        return WorkoutVitalsMath.vitals(
            from: WorkoutVitalsMath.summarySamples(from: samples, dominant: source),
            zoningAgainst: maxHeartRate)
    }
}

final class StubHeartRateProvider: HeartRateProviding {
    private var continuation: AsyncStream<HeartRateSample>.Continuation?
    let stream: AsyncStream<HeartRateSample>
    var activeEnergyKilocalories: Double?
    var basalEnergyKilocalories: Double?
    var startResult: HeartRateFeedState = .live(.fixture)
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() {
        var captured: AsyncStream<HeartRateSample>.Continuation!
        stream = AsyncStream { captured = $0 }
        continuation = captured
    }

    func start() async -> HeartRateFeedState {
        startCount += 1
        return startResult
    }

    func stop() async {
        stopCount += 1
        continuation?.finish()
    }

    func emit(_ sample: HeartRateSample) {
        continuation?.yield(sample)
    }
}

@MainActor
struct HeartRateMonitorTests {

    private let t0 = Date(timeIntervalSince1970: 2_000_000)

    private func sample(
        _ bpm: Int, at date: Date, from source: HeartRateSource = .fixture
    ) -> HeartRateSample {
        HeartRateSample(bpm: bpm, date: date, source: source)
    }

    /// Lets the monitor's stream task pick up whatever the stub emitted.
    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }

    // MARK: Lifecycle

    @Test func startingTwiceStartsTheProviderOnce() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        await monitor.start()
        #expect(provider.startCount == 1, "a second start would open a second session")
    }

    /// A session that outlives its workout keeps the sensor powered and drains
    /// the battery for a workout nobody is doing.
    @Test func stoppingEndsTheProviderAndLeavesTheFeedIdle() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        await monitor.stop()
        #expect(provider.stopCount == 1)
        #expect(monitor.state == .idle)
    }

    @Test func aDeniedProviderNeverStartsPumping() async {
        let provider = StubHeartRateProvider()
        provider.startResult = .denied
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        #expect(monitor.state == .denied)
        #expect(!monitor.state.isRunning)
        provider.emit(sample(140, at: .now))
        await settle()
        #expect(monitor.samples.isEmpty, "nothing may arrive from a denied feed")
    }

    // MARK: Samples

    @Test func samplesArriveAndBecomeTheCurrentReading() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()

        provider.emit(sample(120, at: .now))
        await settle()

        #expect(monitor.samples.count == 1)
        #expect(monitor.current?.bpm == 120)
        #expect(monitor.state == .live(.fixture))
        #expect(!monitor.isStale)
    }

    @Test func activeEnergyIsWhateverTheProviderSays_neverComputedHere() async {
        let provider = StubHeartRateProvider()
        provider.activeEnergyKilocalories = 282
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        provider.emit(sample(120, at: .now))
        await settle()
        #expect(monitor.activeEnergyKilocalories == 282)
    }

    // MARK: Staleness and liveness

    /// A number that stopped updating is not a heart rate. Without this the
    /// state would say `.live` forever off one sample from ten minutes ago.
    @Test func aQuietSensorStopsBeingReportedAsLive() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        let old = Date().addingTimeInterval(-60)
        provider.emit(sample(150, at: old))
        await settle()
        // codex-review 3.3: `ingest` used to set `.live(sample.source)` off
        // whatever arrived last — so a sample that was ALREADY a minute old
        // reported as live until the next timer tick. State now follows the
        // reading actually being shown.
        #expect(monitor.state == .waitingForSensor)

        monitor.refreshLiveness()

        #expect(monitor.state == .waitingForSensor)
        #expect(monitor.isStale, "the reading is still shown — marked, not hidden")
        #expect(monitor.current?.bpm == 150)
    }

    @Test func refreshingLivenessOnAnIdleFeedChangesNothing() {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        monitor.refreshLiveness()
        #expect(monitor.state == .idle)
    }

    // MARK: Zones (D45)

    @Test func noMaximumMeansNoZone_ratherThanAGuess() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        provider.emit(sample(150, at: .now))
        await settle()
        #expect(monitor.maxHeartRate == nil)
        #expect(monitor.currentZone == nil)
    }

    @Test func zonesFollowTheResolvedMaximum() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        monitor.maxHeartRate = MaxHeartRate(bpm: 180, isEstimated: true)
        await monitor.start()
        provider.emit(sample(150, at: .now))
        await settle()
        #expect(monitor.currentZone == .three, "150/180 = 83%, and D45's revised zone 4 starts at 85%")
        #expect(monitor.maxHeartRate?.isEstimated == true, "the UI must be able to mark it")
    }

    // MARK: Vitals

    @Test func vitalsFoldEverySampleSeen() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        monitor.maxHeartRate = MaxHeartRate(bpm: 180, isEstimated: false)
        await monitor.start()
        let base = Date()
        for (index, bpm) in [100, 120, 140].enumerated() {
            provider.emit(sample(bpm, at: base.addingTimeInterval(Double(index) * 10)))
        }
        await settle()
        #expect(monitor.liveVitals.averageBpm == 120)
        #expect(monitor.liveVitals.maxBpm == 140)
        #expect(monitor.liveVitals.sampleCount == 3)
    }

    @Test func anEmptyFeedYieldsEmptyVitals_notZeroes() {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        #expect(monitor.liveVitals.isEmpty)
        #expect(monitor.liveVitals.averageBpm == nil)
    }

    // MARK: The fixture provider

    /// The fixture must be tagged as fixture data, so a test reading can never
    /// be mistaken for a measurement.
    @Test func theFixtureProviderIdentifiesItselfAsFixtureData() async {
        let provider = FixtureHeartRateProvider(script: [111], interval: 0.01)
        let state = await provider.start()
        #expect(state == .live(.fixture))
        await provider.stop()
    }

    @Test func theFixtureScriptIsNotAFlatLine() {
        // A flat line would let a broken UI look correct.
        let script = FixtureHeartRateProvider.defaultScript
        #expect(Set(script).count > 5)
        #expect(script.max()! - script.min()! > 30, "it must climb and fall like real work")
    }
}
