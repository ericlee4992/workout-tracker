import Foundation
import HealthKit
import Observation
import WatchConnectivity

// Milestone 7, ticket 04 — the watch's whole job: run a workout session on the
// wrist and stream what the sensor says to the phone.
//
// It deliberately owns no logging, no exercises and no history. The phone is
// where a workout is recorded; duplicating any of that here would mean two
// stores to reconcile and a second place for the user's training to disagree
// with itself.

@MainActor
@Observable
final class WatchWorkoutModel: NSObject {

    enum State: Equatable {
        case idle
        case starting
        case running
        case denied
        case unavailable
    }

    private(set) var state: State = .idle
    private(set) var latestBpm: Int?
    private(set) var latestAt: Date?
    /// Mirrored from the phone so the wrist can show the rest countdown without
    /// knowing anything about how rest is decided (D43 lives on the phone).
    private(set) var restEndsAt: Date?
    /// Echoed back on every sample so the phone can drop queued readings from a
    /// workout that has already ended (codex-review 3.4).
    private(set) var workoutID: String?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// True when the reading is recent enough to show as current. Same rule and
    /// same tolerance as the phone (`HeartRateSample.stalenessTolerance`),
    /// restated here because the watch target does not compile the phone's
    /// domain — if one changes, change both.
    var isStale: Bool {
        guard let latestAt else { return true }
        return Date().timeIntervalSince(latestAt) > 15
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: Session

    func start() async {
        guard state == .idle else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .unavailable
            return
        }
        state = .starting

        let heartRate = HKQuantityType(.heartRate)
        let activeEnergy = HKQuantityType(.activeEnergyBurned)
        do {
            try await store.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: [heartRate, activeEnergy])
        } catch {
            state = .denied
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(
                healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: store, workoutConfiguration: configuration)
            builder.delegate = self
            session.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            state = .running
        } catch {
            state = .unavailable
        }
    }

    func stop() async {
        guard let session, let builder else {
            state = .idle
            return
        }
        let end = Date()
        session.stopActivity(with: end)
        session.end()
        try? await builder.endCollection(at: end)
        _ = try? await builder.finishWorkout()
        self.session = nil
        self.builder = nil
        latestBpm = nil
        latestAt = nil
        restEndsAt = nil
        workoutID = nil
        state = .idle
    }

    // MARK: Sending

    private func send(bpm: Int, at date: Date) {
        guard WCSession.isSupported() else { return }
        let message = WatchLink.heartRateMessage(
            bpm: bpm, at: date, workoutID: workoutID)
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in }
        } else {
            // Out of range is a delay, not a loss: the phone's summary still
            // wants these samples even if the live number missed its moment.
            session.transferUserInfo(message)
        }
    }
}

// MARK: - Live data

extension WatchWorkoutModel: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)),
              let statistics = workoutBuilder.statistics(for: HKQuantityType(.heartRate)),
              let quantity = statistics.mostRecentQuantity()
        else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = Int(quantity.doubleValue(for: unit).rounded())
        // The date the heart beat, not the moment we noticed — the phone judges
        // staleness against it.
        let date = statistics.mostRecentQuantityDateInterval()?.end ?? Date()
        guard bpm > 0 else { return }
        Task { @MainActor [weak self] in
            self?.latestBpm = bpm
            self?.latestAt = date
            self?.send(bpm: bpm, at: date)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension WatchWorkoutModel: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.state = .unavailable
            self?.session = nil
            self?.builder = nil
        }
    }
}

// MARK: - Phone link

extension WatchWorkoutModel: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(
        _ session: WCSession, didReceiveMessage message: [String: Any]
    ) {
        apply(message)
    }

    nonisolated func session(
        _ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        apply(userInfo)
    }

    private nonisolated func apply(_ message: [String: Any]) {
        guard let state = WatchLink.workoutState(from: message) else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.restEndsAt = state.restEndsAt
            self.workoutID = state.isActive ? state.workoutID : nil
            // The phone owns the workout's lifecycle; the wrist follows it, so
            // the user never has to start the same workout twice.
            if state.isActive {
                await self.start()
            } else {
                await self.stop()
            }
        }
    }
}
