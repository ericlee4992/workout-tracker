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
    /// The workout the running monitor belongs to, so a REPLACEMENT can bank
    /// its summary before the monitor is thrown away. Weak: the coordinator
    /// outlives workouts and must not keep a deleted one alive.
    private weak var currentWorkout: Workout?

    // The rest alarm lives HERE, not on the workout screen, for the same reason
    // the session does (codex-review-2 #2): C1's minimise dismisses that screen
    // while the workout keeps running. An alarm owned by the screen dies on
    // minimise — its `@State` goes with it — so the user who backgrounds the app
    // mid-rest, which is every user, gets silence.
    private let alarm: any RestAlarmSounding
    /// The rest end the phone is currently counting down to, mirrored here by
    /// `broadcastRest` — the screen already tells us on every change.
    private var restEndsAt: Date?
    /// The end already announced, so the alarm sounds once per rest rather than
    /// once per sample.
    private var lastSoundedRestEnd: Date?
    /// Forwarded to the screen when it is on screen. Nil after minimise, which
    /// is fine: the alarm above does not depend on it.
    var onSample: (() -> Void)?

    init(alarm: (any RestAlarmSounding)? = nil) {
        self.alarm = alarm ?? RestAlarms.make()
    }

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
        // A different workout: BANK the old one, then end its session. This
        // used to stop the old monitor and discard its samples, so "Finish it
        // and start new" — which auto-finishes the active workout in
        // WorkoutSession.startWorkout, out of this coordinator's sight — saved
        // that workout with no heart-rate summary at all (codex-review 05,
        // critical). Capturing here is the safety net; StartWorkoutView also
        // calls `end` explicitly before starting the replacement.
        if let previous = currentWorkout, previous.id == workoutID {
            end(previous)
        } else if let existing = monitor {
            existing.onSample = nil
            Task { await existing.stop() }
        }
        let fresh = HeartRateMonitor(
            provider: HeartRateProviders.make(workoutID: workout.id.uuidString))
        fresh.maxHeartRate = maxHeartRate
        // The sample tick is owned here and forwarded on, rather than being
        // handed to the screen: this is the only tick that survives both
        // minimise and the screen going off, so it is the only one the alarm
        // can hang from.
        fresh.onSample = { [weak self] in
            // The single most diagnostic line in the app: if these stop while
            // the phone is locked, the process is being suspended and NO
            // amount of audio work will make the alarm fire.
            restAlarmLog.debug("sample tick")
            self?.soundRestAlarmIfDue()
            self?.onSample?()
        }
        monitor = fresh
        workoutID = workout.id
        currentWorkout = workout
        // Hold the audio session open for the workout. Activating one from a
        // suspended background app is unreliable; activating it while the user
        // is still looking at the screen, and keeping it, is not.
        alarm.beginSession()
        Task { await fresh.start() }
        return fresh
    }

    /// Banks what the sensor saw onto the workout and ends the session.
    ///
    /// Called on every path that ends a workout — finish, templated finish,
    /// cancel, and the "finish it and start new" recovery in `StartWorkoutView`
    /// (explicitly there since codex-review 05, and as a net in `monitor(for:)`
    /// when a different workout arrives).
    func end(_ workout: Workout, capture: Bool = true) {
        guard workoutID == workout.id, let monitor else { return }
        if capture, !workout.isDeleted {
            // The finish boundary: take the provider's LATEST energy figures,
            // both halves together, rather than whatever the last sample tick
            // happened to copy (codex-review 05, high).
            monitor.refreshEnergy()
            // ONE bounded collection for aggregates AND series: the workout's
            // own span, ending at the recorded finish when there is one (a
            // replacement banked late) — so a reading that arrived after the
            // finish can change neither the chart nor the average under it
            // (codex-review 05c: the series was bounded, the vitals were not).
            let end = workout.finishedAt ?? Date()
            let bounded = monitor.summarySamples(from: workout.startedAt, to: end)
            WorkoutSummaryBuilder.capture(
                vitals: WorkoutVitalsMath.vitals(from: bounded, zoningAgainst: monitor.maxHeartRate),
                activeEnergyKilocalories: monitor.activeEnergyKilocalories,
                basalEnergyKilocalories: monitor.basalEnergyKilocalories,
                samples: bounded,
                zonesEstimated: monitor.maxHeartRate?.isEstimated ?? false,
                onto: workout,
                now: end)
        }
        monitor.onSample = nil
        let ending = monitor
        Task { await ending.stop() }
        self.monitor = nil
        self.workoutID = nil
        self.currentWorkout = nil
        releaseAlarm()
    }

    /// Test seam: arms a rest without a screen present.
    func armForTesting(restEndsAt: Date?) {
        broadcastRest(endsAt: restEndsAt)
    }

    /// Test seam: runs the alarm check at a chosen instant, as a sample would.
    func evaluateAlarmForTesting(now: Date) {
        soundRestAlarmIfDue(now: now)
    }

    /// Test seam: installs a monitor without opening a real session.
    func adoptForTesting(monitor: HeartRateMonitor, workoutID: UUID) {
        self.monitor = monitor
        self.workoutID = workoutID
    }

    /// Mirrors the phone's rest timer onto the watch, if one is listening, and
    /// arms the audible alarm for that rest.
    func broadcastRest(endsAt: Date?) {
        (monitor?.provider as? WatchRestBroadcasting)?.sendRest(endsAt: endsAt)
        restEndsAt = endsAt
        // A new rest re-arms. Without this the second rest of a workout would be
        // silent, the gate still holding the first one's end.
        if let endsAt, endsAt != lastSoundedRestEnd {
            lastSoundedRestEnd = nil
        }
        // QUEUE THE BEEP NOW, for the deadline we already know.
        //
        // This is the fix for three builds' worth of "it only beeps when the
        // app is on screen". The old design needed the app to be executing at
        // the instant the rest ended — iOS promises a backgrounded app no such
        // thing. Handing the audio pipeline a track that plays silence and then
        // beeps means the deadline needs no code at all.
        //
        // Called on every change to the deadline, so +15s re-queues and skip
        // cancels.
        if let endsAt {
            alarm.scheduleBeep(inSeconds: endsAt.timeIntervalSinceNow, pattern: .cap)
        } else {
            alarm.cancelScheduledBeep()
        }
    }

    /// The heart rate came down, so this rest ended early (D43). Sounds the
    /// "recovered" pattern and disarms, so the cap cannot also fire.
    func soundRecovered() {
        // The cap track is queued and would still beep later; this rest is over.
        alarm.cancelScheduledBeep()
        alarm.sound(.recovered)
        restEndsAt = nil
        lastSoundedRestEnd = nil
    }

    /// Sounds the cap pattern once, when a rest runs its full length.
    ///
    /// Evaluated on every sample — roughly once a second — so the gate is what
    /// keeps a face-down phone from beeping every second.
    private func soundRestAlarmIfDue(now: Date = .now) {
        guard RestAlarmDecision.shouldSound(
            restEndsAt: restEndsAt, lastSounded: lastSoundedRestEnd, now: now)
        else { return }
        lastSoundedRestEnd = restEndsAt
        // The queued track has already beeped by itself if the audio pipeline
        // survived. This is the belt-and-braces path for the case where it did
        // not — an interruption, a route change — and it is cheap: at worst the
        // user hears the same beep twice, which is better than not at all.
        restAlarmLog.notice("cap deadline reached while executing")
        guard !alarm.hasQueuedBeep else { return }
        alarm.sound(.cap)
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
        releaseAlarm()
    }

    /// Hands the audio session back when the workout ends. Holding it open for
    /// a workout nobody is doing is the audio equivalent of leaving the sensor
    /// powered.
    private func releaseAlarm() {
        restEndsAt = nil
        lastSoundedRestEnd = nil
        onSample = nil
        alarm.endSession()
    }
}
