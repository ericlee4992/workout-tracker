import Foundation
import Observation

// Milestone 7, ticket 03 — the live heart-rate feed, as the rest of the app
// sees it. The provider protocol and the fixture live here; the HealthKit
// implementation is in `HealthKitHeartRateProvider.swift`, following the shape
// `RestTimer.swift` already set for UserNotifications: a system framework
// behind a protocol, injectable, so every rule above it is testable on a
// machine with no sensor attached.
//
// The monitor owns one honest job: turn a stream of samples into "what should
// the screen say right now", including the cases where the answer is "nothing".

/// What the feed is currently doing. Every case is something the UI must be
/// able to render — a state that renders as blank space is a state the user
/// reads as a bug.
enum HeartRateFeedState: Equatable, Sendable {
    /// No workout running, or heart rate not started.
    case idle
    /// Authorization has never been asked for.
    case needsAuthorization
    /// The user said no. Nothing will ever arrive; say so and offer Settings.
    case denied
    /// Running, but nothing has reported yet — or the sensor has gone quiet.
    case waitingForSensor
    /// Live, from this source.
    case live(HeartRateSource)
    /// HealthKit is not available on this device at all.
    case unavailable

    var isRunning: Bool {
        switch self {
        case .waitingForSensor, .live: true
        case .idle, .needsAuthorization, .denied, .unavailable: false
        }
    }
}

/// Produces heart-rate samples and active energy for one workout.
///
/// `AnyObject` so implementations can hold HealthKit's mutable session state;
/// `@MainActor` because everything downstream of it is UI, and hopping actors
/// per sample would buy nothing but races.
@MainActor
protocol HeartRateProviding: AnyObject {
    /// Called once when a workout starts. Implementations request
    /// authorization here — on first use of the feature, not at launch, the
    /// same rule the rest-timer notifications follow.
    func start() async -> HeartRateFeedState
    /// Ends the session. **Must** be called when the workout ends: a session
    /// that outlives its workout keeps the sensor powered and drains the
    /// battery for a workout nobody is doing.
    func stop() async
    /// Samples as they arrive.
    var stream: AsyncStream<HeartRateSample> { get }
    /// Active energy accumulated by the *system* during the session (a
    /// "generated type", WWDC25 322). Never computed by this app: a calorie
    /// figure we invented would be exactly the false precision the app exists
    /// to refuse.
    var activeEnergyKilocalories: Double? { get }
    /// Resting energy over the session, likewise the system's own figure.
    /// Defaulted to nil: most providers (a watch link, a test double) have no
    /// energy at all, and total calories is simply not shown without it.
    var basalEnergyKilocalories: Double? { get }
}

extension HeartRateProviding {
    var basalEnergyKilocalories: Double? { nil }
}

/// The app-facing feed. Views observe this; nothing above it knows whether the
/// samples came from HealthKit, a fixture, or a preview.
@MainActor
@Observable
final class HeartRateMonitor {

    private(set) var state: HeartRateFeedState = .idle
    /// Every sample this workout has seen, oldest first. Bounded — see
    /// `sampleLimit`.
    private(set) var samples: [HeartRateSample] = []
    private(set) var activeEnergyKilocalories: Double?
    private(set) var basalEnergyKilocalories: Double?
    /// The ceiling zones are computed against (D45). nil = show no zones.
    var maxHeartRate: MaxHeartRate?

    /// Readable so the coordinator can forward watch-specific messages (the
    /// rest mirror) without the monitor knowing what a watch is.
    let provider: any HeartRateProviding
    private var pump: Task<Void, Never>?

    // There is deliberately NO sample cap.
    //
    // There used to be one (5,000, oldest dropped) with a comment claiming the
    // aggregate was kept separately. It was not: `vitals` folds this array, so a
    // long or high-frequency session would have reported an average, maximum and
    // zone time describing only the tail of the workout — while the summary
    // presented them as whole-workout totals (codex-review 1.3).
    //
    // The cost of not capping is small and knowable: a three-hour session at one
    // sample per second is ~11,000 samples of a small struct. The cost of
    // capping was a summary that quietly lied about long workouts, which is
    // exactly the kind of claim this app exists not to make.

    init(provider: any HeartRateProviding) {
        self.provider = provider
    }

    /// The reading to display, or nil when nothing has ever arrived.
    var current: HeartRateSample? {
        samples.current(asOf: .now)
    }

    /// True when the reading shown is too old to call current. The UI must
    /// mark this rather than showing the number plainly — a frozen 138 while
    /// the user's heart is at 90 is worse than showing nothing at all.
    var isStale: Bool {
        guard let current else { return false }
        return current.isStale(asOf: .now)
    }

    var currentZone: HeartRateZone? {
        guard let bpm = current?.bpm, let max = maxHeartRate else { return nil }
        return HeartRateZones.zone(for: bpm, max: max.bpm)
    }

    /// The source the feed is currently believing — the highest-precedence one
    /// that is actually reporting.
    var currentSource: HeartRateSource? {
        current?.source
    }

    /// Samples from the sensor the feed is believing RIGHT NOW. Used for the
    /// rest rule, which is a question about this moment.
    ///
    /// codex-review 3.2 (high): handing the rest rule an interleaving of two
    /// sensors lets a lower-precedence AirPods reading end a rest while the
    /// Watch still says the user is above threshold.
    var samplesFromCurrentSource: [HeartRateSample] {
        guard let source = currentSource else { return [] }
        return samples.filter { $0.source == source }
    }

    /// The sensor that actually recorded this workout: the one that produced
    /// the most samples, ties going to the higher-precedence device.
    ///
    /// codex-review-2 #6: using `currentSource` for the SUMMARY meant whichever
    /// sensor happened to be live when Finish was tapped owned the whole
    /// workout — one fresh Watch reading after two hours of AirPods produced a
    /// one-sample average, and sixteen seconds later it flipped back. A
    /// workout's summary must not depend on the instant it was asked for.
    var dominantSource: HeartRateSource? {
        WorkoutVitalsMath.dominantSource(among: samples)
    }

    // There is deliberately NO unbounded "vitals so far" accessor here. The
    // persisted summary goes through `summarySamples(from:to:)`, which bounds
    // the raw samples to the workout BEFORE choosing a source (codex-review
    // 05d); an unbounded twin beside it is how that defect comes back
    // (codex-review 05e). Tests that want the whole-history fold compose the
    // pure math themselves.

    /// The samples the persisted summary is built from — aggregates AND series,
    /// so they describe the same evidence. Bounded to the workout FIRST, then
    /// the dominant sensor is chosen among what remains, then the other
    /// sensor's readings fill its silences (`WorkoutVitalsMath.summarySamples`).
    /// Order matters: choosing the source from the unbounded history let a
    /// flood of post-finish readings from the other sensor make it dominant on
    /// a late bank and discard the real in-workout data (codex-review 05d).
    func summarySamples(from start: Date, to end: Date) -> [HeartRateSample] {
        let bounded = samples.filter { $0.date >= start && $0.date <= end }
        guard let source = WorkoutVitalsMath.dominantSource(among: bounded) else { return [] }
        return WorkoutVitalsMath.summarySamples(from: bounded, dominant: source)
    }

    /// Copies the provider's current energy figures — both halves, together.
    /// Called at the finish boundary so a late update, or a session that
    /// burned energy without ever reporting a bpm, is not lost
    /// (codex-review 05, high).
    func refreshEnergy() {
        activeEnergyKilocalories = provider.activeEnergyKilocalories
        basalEnergyKilocalories = provider.basalEnergyKilocalories
    }

    func start() async {
        guard !state.isRunning else { return }
        state = await provider.start()
        guard state.isRunning else { return }
        pump?.cancel()
        pump = Task { [weak self] in
            guard let stream = self?.provider.stream else { return }
            for await sample in stream {
                guard let self else { return }
                self.ingest(sample)
            }
        }
    }

    func stop() async {
        pump?.cancel()
        pump = nil
        await provider.stop()
        state = .idle
    }

    private func ingest(_ sample: HeartRateSample) {
        samples.append(sample)
        activeEnergyKilocalories = provider.activeEnergyKilocalories
        basalEnergyKilocalories = provider.basalEnergyKilocalories
        // codex-review 3.3 (high): this used to be `.live(sample.source)` —
        // whichever sensor happened to report LAST — while the number on screen
        // came from `current`, chosen by precedence. A Watch reading could
        // therefore be labelled "AirPods". The label and the number must come
        // from the same sample.
        refreshLiveness()
        onSample?()
    }

    /// Called after every ingested sample. The rest rule (D43) hangs off this
    /// rather than off a UI timer: an active workout session keeps the app
    /// running in the background, so samples keep arriving with the screen off —
    /// but a SwiftUI `Timer` does not keep firing (codex-review 2.2, high).
    var onSample: (() -> Void)?

    /// Test seam: feeds a sample as though it had arrived from the provider, so
    /// ownership and summary behaviour can be exercised without a live stream.
    func ingestForTesting(_ sample: HeartRateSample) {
        ingest(sample)
    }

    /// Called on a timer by the UI so a sensor that goes quiet stops being
    /// reported as live. Without this the state would say `.live` forever off
    /// the strength of one sample from ten minutes ago.
    func refreshLiveness(asOf now: Date = .now) {
        guard state.isRunning else { return }
        // codex-review-2 #7: energy used to be copied only while ingesting a
        // heart-rate sample, so a session that burned calories without ever
        // reporting a bpm persisted none of them — and one that kept burning
        // after the last bpm persisted a stale total. Both halves (codex-review
        // 05: basal was left out and went stale).
        refreshEnergy()
        if let current, !current.isStale(asOf: now) {
            state = .live(current.source)
        } else {
            state = .waitingForSensor
        }
    }
}

// MARK: - Choosing a provider

enum HeartRateProviders {
    /// Launch argument that swaps HealthKit for the scripted series, so the
    /// simulator — which has no heartbeat, no AirPods and no Watch — can drive
    /// the whole feature. Same shape as `-uiTestScanFixture`, for the same
    /// reason: a camera and a heart are both unavailable to a test runner.
    static let uiTestArgument = "-uiTestHeartRate"

    static var isUITestFixture: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestArgument)
    }

    /// Both real sources at once (D41): AirPods through the phone's own
    /// workout session, the Watch through `WCSession`. Which one the screen
    /// believes at any moment is ticket 01's precedence rule, applied to the
    /// merged stream — not a choice made here.
    @MainActor
    static func make(workoutID: String) -> any HeartRateProviding {
        if isUITestFixture { return FixtureHeartRateProvider() }
        // A UI-test run that is NOT exercising heart rate must not summon the
        // HealthKit permission sheet: it is a system alert that covers the
        // screen, and every existing XCUITest that starts a workout went from
        // passing to "button not hittable" the moment this milestone landed.
        // Silent rather than fixture-driven, so those tests see the app they
        // were written against.
        if WorkoutTrackerStore.isUITestReset { return DisabledHeartRateProvider() }
        return CompositeHeartRateProvider(providers: [
            HealthKitHeartRateProvider(assumedSource: .airPods),
            WatchHeartRateProvider(workoutID: workoutID),
        ])
    }
}

/// Reports nothing and asks for nothing. Used by UI-test runs that are not
/// about heart rate.
@MainActor
final class DisabledHeartRateProvider: HeartRateProviding {
    let stream: AsyncStream<HeartRateSample> = AsyncStream { $0.finish() }
    let activeEnergyKilocalories: Double? = nil
    func start() async -> HeartRateFeedState { .unavailable }
    func stop() async {}
}

// MARK: - Fixture

/// Replays a scripted series. Drives the simulator (which has no heartbeat, no
/// AirPods and no Watch), XCUITests, and previews.
///
/// Its samples are tagged `.fixture` rather than impersonating a real sensor,
/// so a test reading can never be mistaken for a measurement.
@MainActor
final class FixtureHeartRateProvider: HeartRateProviding {

    private let script: [Int]
    private let interval: TimeInterval
    private var continuation: AsyncStream<HeartRateSample>.Continuation?
    private var task: Task<Void, Never>?
    private(set) var activeEnergyKilocalories: Double?
    private(set) var basalEnergyKilocalories: Double?
    private(set) var isRunning = false

    let stream: AsyncStream<HeartRateSample>

    /// A plausible strength-training shape: climbs under load, falls during
    /// rest, never a flat line — a flat line would let a broken UI look correct.
    static let defaultScript = [
        92, 104, 118, 131, 142, 148, 151, 146, 138, 129, 121, 114, 108, 103,
        99, 112, 127, 139, 147, 153, 149, 141, 132, 123, 115, 109, 104, 100,
    ]

    init(script: [Int] = FixtureHeartRateProvider.defaultScript, interval: TimeInterval = 1) {
        self.script = script.isEmpty ? [100] : script
        self.interval = interval
        var captured: AsyncStream<HeartRateSample>.Continuation!
        self.stream = AsyncStream { captured = $0 }
        self.continuation = captured
    }

    func start() async -> HeartRateFeedState {
        isRunning = true
        activeEnergyKilocalories = 0
        basalEnergyKilocalories = 0
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            var index = 0
            while !Task.isCancelled {
                let bpm = self.script[index % self.script.count]
                self.continuation?.yield(
                    HeartRateSample(bpm: bpm, date: .now, source: .fixture))
                // Roughly a kcal every few seconds under load — enough for the
                // number on screen to move, and labelled fixture data.
                self.activeEnergyKilocalories = (self.activeEnergyKilocalories ?? 0) + 0.35
                // Resting burn runs regardless of effort. Deliberately higher
                // than a real ~1.2 kcal/min so a short test workout shows a
                // TOTAL that visibly differs from ACTIVE; it is labelled fixture
                // data and never reaches a real store.
                self.basalEnergyKilocalories = (self.basalEnergyKilocalories ?? 0) + 0.1
                index += 1
                try? await Task.sleep(for: .seconds(self.interval))
            }
        }
        return .live(.fixture)
    }

    func stop() async {
        task?.cancel()
        task = nil
        isRunning = false
        continuation?.finish()
    }
}
