import Foundation
import Observation
import SwiftData

// codex-review-2 #2 (critical) — who owns the heart-rate session.
//
// It used to be the workout SCREEN. That screen is dismissed by C1's minimise
// while the workout keeps running, so minimising either orphaned a live session
// (sensor powered, nobody watching) or — after the first patch — quietly ended
// heart-rate tracking half way through a workout and replaced the banked
// summary on resume.
//
// The session belongs to the WORKOUT, so it is owned at the same level the
// workout is: `RootView`, which survives minimise. The screen borrows it.
//
// The invariant: at most one monitor exists, and it belongs to exactly one
// workout id. Starting a session for a different workout ends the previous one
// first — an orphaned session is a sensor running for a workout nobody is doing.

@MainActor
@Observable
final class WorkoutHeartRateCoordinator {

    private(set) var workoutID: UUID?
    private(set) var monitor: HeartRateMonitor?

    /// The monitor for this workout, started if it is not already running.
    ///
    /// Idempotent: calling it again for the same workout returns the same
    /// monitor with its samples intact, which is what makes minimise and resume
    /// continue one session rather than start a second.
    @discardableResult
    func monitor(for workout: Workout, maxHeartRate: MaxHeartRate?) -> HeartRateMonitor {
        if let monitor, workoutID == workout.id {
            monitor.maxHeartRate = maxHeartRate
            return monitor
        }
        // A different workout: end the old session before opening a new one.
        if let existing = monitor {
            let previous = existing
            previous.onSample = nil
            Task { await previous.stop() }
        }
        let fresh = HeartRateMonitor(
            provider: HeartRateProviders.make(workoutID: workout.id.uuidString))
        fresh.maxHeartRate = maxHeartRate
        monitor = fresh
        workoutID = workout.id
        Task { await fresh.start() }
        return fresh
    }

    /// Banks what the sensor saw onto the workout and ends the session.
    ///
    /// Called on every path that ends a workout — finish, templated finish,
    /// cancel, and the "finish it and start new" recovery in `StartWorkoutView`,
    /// which previously had no access to the monitor at all and so could neither
    /// save the vitals nor stop the sensor.
    func end(_ workout: Workout, capture: Bool = true) {
        guard workoutID == workout.id, let monitor else { return }
        if capture, !workout.isDeleted {
            WorkoutSummaryBuilder.capture(
                vitals: monitor.vitals,
                activeEnergyKilocalories: monitor.activeEnergyKilocalories,
                zonesEstimated: monitor.maxHeartRate?.isEstimated ?? false,
                onto: workout)
        }
        monitor.onSample = nil
        let ending = monitor
        Task { await ending.stop() }
        self.monitor = nil
        self.workoutID = nil
    }

    /// Test seam: installs a monitor without opening a real session.
    func adoptForTesting(monitor: HeartRateMonitor, workoutID: UUID) {
        self.monitor = monitor
        self.workoutID = workoutID
    }

    /// Mirrors the phone's rest timer onto the watch, if one is listening.
    func broadcastRest(endsAt: Date?) {
        (monitor?.provider as? WatchRestBroadcasting)?.sendRest(endsAt: endsAt)
    }

    /// Ends whatever is running, whichever workout it belongs to. Used when the
    /// app cannot name the workout being replaced.
    func endAny() {
        guard let monitor else { return }
        monitor.onSample = nil
        let ending = monitor
        Task { await ending.stop() }
        self.monitor = nil
        self.workoutID = nil
    }
}
