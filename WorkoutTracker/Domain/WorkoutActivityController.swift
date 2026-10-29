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
    /// Ends every workout card the app has posted, tracked or not (ticket 21): one adopted from an
    /// earlier launch, or one whose end never reached the system.
    func endAll()
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
    /// Workouts whose card was ended (ticket 21). A push that lands after its workout ended — the
    /// screen's 2-second tick or a rest change while the cancelled workout's screen is still being
    /// dismissed — must not post the card again: SwiftData reports a deleted workout as not deleted
    /// once the deletion is saved, so the screen's own guard cannot tell. An ended workout never
    /// runs again (finish and cancel are final) unless that finish or cancel failed, which
    /// `reopen(workoutID:)` undoes; the set grows by one per workout.
    private var ended: Set<UUID> = []

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
        guard !ended.contains(workoutID) else { return }
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
        ended.insert(workoutID)
        // Nothing tracked (a card from an earlier launch not adopted yet): sweep. A different
        // workout's card is left alone — a stale id must not end the current one.
        guard self.workoutID == workoutID || self.workoutID == nil else { return }
        endAny()
    }

    /// At launch (ticket 21): with no live workout, a card left over — one whose end never reached the system, the
    /// app quit right after a cancel — goes. `nil`: the store could not say, so any card stays rather than end a
    /// live workout's (codex-review-21 #2).
    func reconcileAtLaunch(hasLiveWorkout: Bool?) {
        if hasLiveWorkout == false { endAny() }
    }

    /// Lets an ended workout's card be shown again (codex-review-21 #1): its finish or cancel failed after the card
    /// was ended, so the workout is still live.
    func reopen(workoutID: UUID) {
        ended.remove(workoutID)
    }

    /// Ends whatever is showing, whichever workout it belongs to, and any stray card with it.
    func endAny() {
        if let workoutID { ended.insert(workoutID) }
        presenter.endAll()
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
    private(set) var sweeps = 0
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

    func endAll() {
        sweeps += 1
        if isActive { ends += 1 }
    }
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

    func endAll() {
        let tracked = activity
        activity = nil
        let posted = Activity<WorkoutActivityAttributes>.activities
        Task {
            for card in posted { await card.end(nil, dismissalPolicy: .immediate) }
            // Requested this run but not yet listed by the system.
            if let tracked, !posted.contains(where: { $0.id == tracked.id }) {
                await tracked.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
