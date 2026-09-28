import ActivityKit
import Foundation
import Observation

// Milestone 8, ticket 05 — starting, updating and ENDING the Live Activity.
//
// The lifecycle is the whole risk here. An activity that outlives its workout
// sits on the lock screen showing a heart rate for a session nobody is doing —
// the same class of defect as the orphaned heart-rate session that
// codex-review-2 #2 caught in milestone 7, and it is caught the same way: one
// owner, and every workout-ending path routes through it.
//
// D46 governs the content: the app pushes state and the system renders it. The
// rest countdown is a `timerInterval` the system ticks, so a suspended app
// shows a correct countdown rather than a frozen one.

/// System framework behind a protocol, injectable — the same shape
/// `RestTimer`, `HeartRateMonitor` and `RestAlarmSound` already use, so the
/// rules above it stay testable on a machine with no Live Activity support.
@MainActor
protocol WorkoutActivityPresenting: AnyObject {
    var isActive: Bool { get }
    func start(_ attributes: WorkoutActivityAttributes, state: WorkoutActivityAttributes.ContentState)
    func update(_ state: WorkoutActivityAttributes.ContentState)
    func end()
    /// Waits for the last update to reach the system (a lock-screen command's intent must not
    /// return, and let the app be suspended, before the card it changed is redrawn).
    func settle() async
}

extension WorkoutActivityPresenting {
    func settle() async {}
}

@MainActor
@Observable
final class WorkoutActivityController {

    private let presenter: any WorkoutActivityPresenting
    private(set) var workoutID: UUID?
    /// The last state pushed, so an update that changes nothing does not wake
    /// the system for no reason.
    private var lastState: WorkoutActivityAttributes.ContentState?

    init(presenter: (any WorkoutActivityPresenting)? = nil) {
        self.presenter = presenter ?? WorkoutActivities.make()
    }

    /// Starts the activity for this workout, or updates it if already running.
    ///
    /// Idempotent for the same workout, like `WorkoutHeartRateCoordinator`: the
    /// screen calls this whenever state changes, and it must not stack
    /// activities.
    func show(
        workoutID: UUID,
        startedAt: Date,
        gymName: String?,
        state: WorkoutActivityAttributes.ContentState
    ) {
        if self.workoutID == workoutID, presenter.isActive {
            guard state != lastState else { return }
            lastState = state
            presenter.update(state)
            return
        }
        // A different workout: end the old activity before starting a new one.
        if presenter.isActive { presenter.end() }
        self.workoutID = workoutID
        lastState = state
        presenter.start(
            WorkoutActivityAttributes(
                workoutID: workoutID, startedAt: startedAt, gymName: gymName),
            state: state)
    }

    /// Waits for the last push to reach the system.
    func settle() async { await presenter.settle() }

    /// Ends the activity for this workout.
    ///
    /// Called from EVERY path that ends a workout — finish, templated finish,
    /// cancel, discard, and the "finish it and start new" recovery. A path that
    /// forgets leaves a workout on the lock screen that no longer exists.
    func end(workoutID: UUID) {
        guard self.workoutID == workoutID else { return }
        endAny()
    }

    /// Ends whatever is showing, whichever workout it belongs to.
    func endAny() {
        guard presenter.isActive else {
            workoutID = nil
            lastState = nil
            return
        }
        presenter.end()
        workoutID = nil
        lastState = nil
    }
}

// MARK: - Choosing a presenter

enum WorkoutActivities {
    @MainActor
    static func make() -> any WorkoutActivityPresenting {
        // A UI-test run must not post real Live Activities: they survive the
        // app, so a test run would litter the device's lock screen with
        // workouts that never happened.
        // `-uiTestRealLiveActivity` (ticket 11): the one UI test that checks the real card on
        // the Simulator's Lock Screen and presses its buttons; it ends the activity itself.
        WorkoutTrackerStore.isUITestReset && !ProcessInfo.processInfo.arguments.contains("-uiTestRealLiveActivity")
            ? SilentWorkoutActivityPresenter()
            : SystemWorkoutActivityPresenter()
    }
}

/// Posts nothing. Used by tests and UI-test runs.
@MainActor
final class SilentWorkoutActivityPresenter: WorkoutActivityPresenting {
    private(set) var starts = 0
    private(set) var updates = 0
    private(set) var ends = 0
    private(set) var lastState: WorkoutActivityAttributes.ContentState?
    var isActive: Bool { starts > ends }

    func start(
        _ attributes: WorkoutActivityAttributes,
        state: WorkoutActivityAttributes.ContentState
    ) {
        starts += 1
        lastState = state
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        updates += 1
        lastState = state
    }

    func end() { ends += 1 }
}

/// The real thing.
@MainActor
final class SystemWorkoutActivityPresenter: WorkoutActivityPresenting {

    private var activity: Activity<WorkoutActivityAttributes>?
    private var lastUpdate: Task<Void, Never>?

    var isActive: Bool { activity != nil }

    func settle() async { await lastUpdate?.value }

    func start(
        _ attributes: WorkoutActivityAttributes,
        state: WorkoutActivityAttributes.ContentState
    ) {
        // The user can switch Live Activities off for the app. That is a
        // preference, not an error — the workout runs exactly the same, it just
        // does not appear on the lock screen.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Floodlight ticket 11: a relaunched app (or a lock-screen command that launched it in
        // the background) adopts the card it already posted for this workout instead of
        // stacking a second one, and ends any card left by a workout that is no longer live.
        for existing in Activity<WorkoutActivityAttributes>.activities {
            if existing.attributes.workoutID == attributes.workoutID, activity == nil {
                activity = existing
                update(state)
            } else if existing.id != activity?.id {
                Task { await existing.end(nil, dismissalPolicy: .immediate) }
            }
        }
        guard activity == nil else { return }
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: Self.content(state))
        } catch {
            // Never fatal, and never `assertionFailure`: this app installs as
            // Debug, so trapping here would turn a missing lock-screen card
            // into a crashed workout — the mistake the rest alarm already made.
            print("[LiveActivity] could not start: \(error)")
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        let previous = lastUpdate
        lastUpdate = Task {
            await previous?.value
            await activity.update(Self.content(state))
        }
    }

    /// The content goes stale when the rest ends: the system then redraws the card (with
    /// `isStale`) in its ready state even if the app is not running at that instant.
    static func content(_ state: WorkoutActivityAttributes.ContentState) -> ActivityContent<WorkoutActivityAttributes.ContentState> {
        let staleDate = state.restEndsAt.flatMap { $0 > .now ? $0 : nil }
        return ActivityContent(state: state, staleDate: staleDate)
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        // `.immediate`, not the default: a dismissal policy that leaves the
        // card on the lock screen after the workout ended is the orphan this
        // controller exists to prevent, one layer down.
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
