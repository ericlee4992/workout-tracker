import Foundation
import HealthKit

// Milestone 7, ticket 03 — the one file in the app that talks to HealthKit
// (D41). Everything above it sees `HeartRateProviding` and knows nothing about
// workout sessions, which is what lets every rule in this milestone be tested
// on a Mac with no sensor.
//
// Requires iOS 26 (D42): `HKWorkoutSession(healthStore:configuration:)`,
// `HKLiveWorkoutBuilder` and `HKLiveWorkoutDataSource` are all
// API_AVAILABLE(ios(26.0)). The project's deployment target is 26.0, so there
// is nothing to gate.
//
// What starts the sensor is the SESSION, not the app: AirPods Pro 3 measure
// heart rate because a workout session asked them to. No session, no readings —
// which is why `start()` and `stop()` are tied to the app's own workout
// lifecycle and not to a screen appearing.

@MainActor
final class HealthKitHeartRateProvider: NSObject, HeartRateProviding, CardioMetricNotifying {

    private let store = HKHealthStore()
    private let activity: CardioActivity?
    private(set) var cardioReading: CardioSensorReading?
    var onCardioMetrics: (() -> Void)?
    private var session: HKWorkoutSession?
    private var shouldBePaused = false
    private var builder: HKLiveWorkoutBuilder?
    private var continuation: AsyncStream<HeartRateSample>.Continuation?

    private(set) var activeEnergyKilocalories: Double?
    private(set) var basalEnergyKilocalories: Double?

    let stream: AsyncStream<HeartRateSample>

    /// Which sensor the samples are coming from. HealthKit does not hand us a
    /// device model per sample in a form worth trusting, so this is the honest
    /// default for a phone-run session: something paired over the heart-rate
    /// GATT profile. The watch companion (ticket 04) reports `.watch` itself.
    private let assumedSource: HeartRateSource

    init(assumedSource: HeartRateSource = .airPods, activity: CardioActivity? = nil) {
        self.activity = activity
        self.assumedSource = assumedSource
        var captured: AsyncStream<HeartRateSample>.Continuation!
        self.stream = AsyncStream { captured = $0 }
        self.continuation = captured
        super.init()
    }

    private var heartRateType: HKQuantityType { .quantityType(forIdentifier: .heartRate)! }
    private var activeEnergyType: HKQuantityType {
        .quantityType(forIdentifier: .activeEnergyBurned)!
    }
    private var basalEnergyType: HKQuantityType {
        .quantityType(forIdentifier: .basalEnergyBurned)!
    }

    func start() async -> HeartRateFeedState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }

        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        var read: Set<HKObjectType> = [heartRateType, activeEnergyType, basalEnergyType]
        if let distanceType { read.insert(distanceType) }
        do {
            // Asked on first use of the feature, not at launch — the same rule
            // the rest-timer notification permission follows.
            try await store.requestAuthorization(toShare: share, read: read)
        } catch {
            return .denied
        }

        // Read permission is deliberately NOT probed with
        // `authorizationStatus(for:)`: HealthKit refuses to disclose read
        // denial, and treating "not determined" as denial would blank the UI
        // for a user who actually granted it. The honest signal that reads are
        // permitted is samples arriving — hence `.waitingForSensor` until one
        // does.
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity?.healthKitType ?? .traditionalStrengthTraining
        configuration.locationType = activity?.isOutdoor == true ? .outdoor : .indoor

        do {
            let session = try HKWorkoutSession(
                healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: store, workoutConfiguration: configuration)
            if let distanceType { builder.dataSource?.enableCollection(for: distanceType, predicate: nil) }
            builder.delegate = self
            session.delegate = self

            self.session = session
            self.builder = builder

            // `prepare()` before starting gives the sensor time to spin up —
            // Apple's own guidance, and the reason their UI shows a countdown.
            session.prepare()
            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            return .waitingForSensor
        } catch {
            self.session = nil
            self.builder = nil
            return .unavailable
        }
    }

    private var distanceType: HKQuantityType? {
        guard let activity else { return nil }
        if activity.isWalkingOrRunning { return HKQuantityType(.distanceWalkingRunning) }
        if activity.usesSpeed { return HKQuantityType(.distanceCycling) }
        if activity == .rowing { return HKQuantityType(.distanceRowing) }
        return nil
    }

    func setPaused(_ paused: Bool) async {
        shouldBePaused = paused
        reconcilePauseState()
    }

    private func reconcilePauseState() {
        guard let session else { return }
        if shouldBePaused, session.state == .running { session.pause() }
        else if !shouldBePaused, session.state == .paused { session.resume() }
    }

    func stop() async {
        guard let session, let builder else { return }
        let end = Date()
        session.stopActivity(with: end)
        session.end()
        // Ending collection and finishing are best-effort: the workout is the
        // user's record either way, and a failure here must not prevent the
        // session from being torn down — a live session left behind keeps the
        // sensor on.
        try? await builder.endCollection(at: end)
        for type in [activeEnergyType, basalEnergyType] {
            if let stats = builder.statistics(for: type) { apply(statistics: stats, identifier: type.identifier) }
        }
        _ = try? await builder.finishWorkout()
        self.session = nil
        self.builder = nil
        continuation?.finish()
    }
}

// MARK: - Live data

extension HealthKitHeartRateProvider: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType)
            else { continue }
            let identifier = quantityType.identifier
            Task { @MainActor [weak self] in
                guard let self, self.builder === workoutBuilder else { return }
                self.apply(statistics: statistics, identifier: identifier)
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    @MainActor
    private func apply(statistics: HKStatistics, identifier: String) {
        switch identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let unit = HKUnit.count().unitDivided(by: .minute())
            guard let quantity = statistics.mostRecentQuantity() else { return }
            let bpm = Int(quantity.doubleValue(for: unit).rounded())
            guard bpm > 0 else { return }
            // Date from the statistic itself, not `.now`: staleness is measured
            // against when the heart beat, not when we noticed.
            let date = statistics.mostRecentQuantityDateInterval()?.end ?? Date()
            continuation?.yield(
                HeartRateSample(bpm: bpm, date: date, source: assumedSource))
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            // The system's own accumulation. We never add these up ourselves.
            activeEnergyKilocalories = statistics
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            // Same rule: the system's figure, for TOTAL = active + basal
            // (milestone 9, ticket 05). Absent means total is not shown.
            basalEnergyKilocalories = statistics
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())
        default:
            if identifier == distanceType?.identifier,
               let meters = statistics.sumQuantity()?.doubleValue(for: .meter()),
               meters.isFinite, meters >= 0 {
                cardioReading = CardioSensorReading(distanceMeters: meters, date: statistics.endDate)
            }
        }
        onCardioMetrics?()
    }
}

// MARK: - Session lifecycle

extension HealthKitHeartRateProvider: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            self.reconcilePauseState()
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        // A failed session is a dead session: close the stream so the monitor
        // stops reporting live and the UI can say the sensor is gone, rather
        // than freezing on the last number forever.
        Task { @MainActor [weak self] in
            self?.continuation?.finish()
            self?.session = nil
            self?.builder = nil
        }
    }
}


extension CardioActivity {
    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .indoorWalk, .outdoorWalk: .walking
        case .indoorRun, .outdoorRun: .running
        case .indoorCycle, .outdoorCycle: .cycling
        case .elliptical: .elliptical
        case .rowing: .rowing
        case .stairStepper: .stairClimbing
        }
    }
}
