import Foundation
import WatchConnectivity

// Milestone 7, ticket 04 — the phone's end of the watch link (D41).
//
// The Apple Watch is NOT a heart-rate GATT peripheral to the phone, so the
// phone's own workout session cannot read it (WWDC25 322 names wearable
// monitors and Powerbeats Pro 2, never the Watch). The only way to a live wrist
// reading is an app on the wrist running its own session and streaming here.
//
// This class receives. It never asks for anything: the watch decides when it has
// a reading, and a phone that demanded samples would just add a round trip to a
// link that is already lossy.

/// Something that can tell the watch about the phone's rest timer.
///
/// Deliberately separate from `HeartRateProviding`: a fixture, a preview and
/// the HealthKit provider have no watch to talk to, and widening the main
/// protocol would make three implementations carry a method that means nothing
/// to them.
@MainActor
protocol WatchRestBroadcasting: AnyObject {
    func sendRest(endsAt: Date?)
}

@MainActor
final class WatchHeartRateProvider: NSObject, HeartRateProviding, WatchRestBroadcasting {

    private var continuation: AsyncStream<HeartRateSample>.Continuation?
    let stream: AsyncStream<HeartRateSample>
    /// Always nil: active energy comes from the phone's own session, which is
    /// the one the system accumulates for. Two sources each reporting their own
    /// total would be two different numbers for one workout.
    let activeEnergyKilocalories: Double? = nil

    private var isActivated = false
    /// The workout this provider belongs to. Samples tagged with any other
    /// workout are dropped: `transferUserInfo` queues, so a reading from a
    /// previous session can be delivered mid-way through this one and would
    /// otherwise be folded into its average (codex-review 3.4).
    private let workoutID: String

    init(workoutID: String) {
        self.workoutID = workoutID
        var captured: AsyncStream<HeartRateSample>.Continuation!
        self.stream = AsyncStream { captured = $0 }
        self.continuation = captured
        super.init()
    }

    func start() async -> HeartRateFeedState {
        guard WCSession.isSupported() else { return .unavailable }
        let session = WCSession.default
        session.delegate = self
        if !isActivated {
            session.activate()
            isActivated = true
        }
        // Tell the watch a workout began, so it can start its own session. Best
        // effort: a watch that is asleep, out of range, or simply not wearing
        // the app installed will not answer, and the phone carries on with
        // whatever else is reporting.
        send(WatchLink.workoutStateMessage(
            isActive: true, restEndsAt: nil, workoutID: workoutID))
        // Never `.live` on start: nothing has arrived yet, and claiming a live
        // wrist before the first sample would freeze the UI on a promise.
        return .waitingForSensor
    }

    func stop() async {
        send(WatchLink.workoutStateMessage(
            isActive: false, restEndsAt: nil, workoutID: workoutID))
        continuation?.finish()
    }

    /// Mirrors the phone's rest timer onto the wrist.
    ///
    /// The watch screen was written to show this from the start, and for a day
    /// it showed nothing: `start`/`stop` were the only messages ever sent, and
    /// both passed `restEndsAt: nil`. The wire format supported it; nothing
    /// populated it.
    func sendRest(endsAt: Date?) {
        guard isActivated else { return }
        send(WatchLink.workoutStateMessage(
            isActive: true, restEndsAt: endsAt, workoutID: workoutID))
    }

    private func send(_ message: [String: Any]) {
        guard isActivated else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in }
        } else {
            // Queued rather than dropped: a wrist out of range should mean late
            // data, not lost data.
            session.transferUserInfo(message)
        }
    }
}

// MARK: - Receiving

extension WatchHeartRateProvider: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // iOS re-activates for the newly paired watch; without this the link
        // dies silently the first time the user switches watches.
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession, didReceiveMessage message: [String: Any]
    ) {
        ingest(message)
    }

    nonisolated func session(
        _ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        ingest(userInfo)
    }

    private nonisolated func ingest(_ message: [String: Any]) {
        guard let reading = WatchLink.heartRate(from: message) else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            // A sample with no workout id predates this fix, or came from a
            // watch build that does not send one; a sample from ANOTHER workout
            // is late queue traffic. Neither belongs in this workout's numbers.
            guard reading.workoutID == self.workoutID else { return }
            self.continuation?.yield(
                HeartRateSample(bpm: reading.bpm, date: reading.date, source: .watch))
        }
    }
}
