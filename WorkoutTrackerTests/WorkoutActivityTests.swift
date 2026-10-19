import Foundation
import Testing

@testable import WorkoutTracker

/// Milestone 8, ticket 05 — the workout on the lock screen.
///
/// The ticket demands these assert the activity is STARTED and UPDATED, not
/// merely that the view compiles. That is deliberate: this repo has now shipped
/// the absence-of-a-caller bug four times — a field carried, a view rendering
/// it, and nothing ever setting it. The watch rest countdown was exactly this
/// shape, and no test asserted a message was ever sent.
@MainActor
struct WorkoutActivityTests {

    private func rig() -> (WorkoutActivityController, SilentWorkoutActivityPresenter) {
        let presenter = SilentWorkoutActivityPresenter()
        return (WorkoutActivityController(presenter: presenter), presenter)
    }

    private func state(bpm: Int? = 120, sets: Int = 3) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            heartRateBpm: bpm, zoneLabel: "Zone 3", restEndsAt: nil,
            completedSets: sets, currentExercise: "Bench Press")
    }

    @Test func showingAWorkoutStartsAnActivity() {
        let (controller, presenter) = rig()
        controller.show(
            workoutID: UUID(), startedAt: .now, gymName: "Home", state: state())
        #expect(presenter.starts == 1, "the activity must actually be requested")
        #expect(presenter.isActive)
    }

    @Test func changedStatePushesAnUpdateRatherThanASecondActivity() {
        let (controller, presenter) = rig()
        let id = UUID()
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state(bpm: 120))
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state(bpm: 135))
        #expect(presenter.starts == 1, "one workout, one activity")
        #expect(presenter.updates == 1, "the new heart rate must reach the lock screen")
        #expect(presenter.lastState?.heartRateBpm == 135)
    }

    /// The push happens on a 2-second tick. Waking the system to re-render an
    /// identical card is work nobody asked for.
    @Test func unchangedStateDoesNotPushAnUpdate() {
        let (controller, presenter) = rig()
        let id = UUID()
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        #expect(presenter.updates == 0)
    }

    // MARK: - Lifecycle, which is the actual risk

    @Test func endingTheWorkoutEndsTheActivity() {
        let (controller, presenter) = rig()
        let id = UUID()
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        controller.end(workoutID: id)
        #expect(presenter.ends == 1)
        #expect(!presenter.isActive, "a card outliving its workout shows a session nobody is doing")
    }

    /// A stale id must not be able to end the CURRENT workout's card.
    @Test func endingADifferentWorkoutLeavesThisOneAlone() {
        let (controller, presenter) = rig()
        controller.show(workoutID: UUID(), startedAt: .now, gymName: nil, state: state())
        controller.end(workoutID: UUID())
        #expect(presenter.ends == 0)
        #expect(presenter.isActive)
    }

    /// Starting a different workout must not stack a second card.
    @Test func startingADifferentWorkoutReplacesTheActivity() {
        let (controller, presenter) = rig()
        controller.show(workoutID: UUID(), startedAt: .now, gymName: nil, state: state())
        controller.show(workoutID: UUID(), startedAt: .now, gymName: nil, state: state())
        #expect(presenter.ends == 1, "the previous workout's card must be ended first")
        #expect(presenter.starts == 2)
    }

    @Test func endAnyClearsWhateverIsShowing() {
        let (controller, presenter) = rig()
        controller.show(workoutID: UUID(), startedAt: .now, gymName: nil, state: state())
        controller.endAny()
        #expect(presenter.ends == 1)
        #expect(controller.workoutID == nil)
    }

    @Test func endingWhenNothingIsShowingIsHarmless() {
        let (controller, presenter) = rig()
        controller.endAny()
        controller.end(workoutID: UUID())
        #expect(presenter.ends == 0)
    }

    // MARK: - Ticket 21: the card stays gone after a cancel

    /// The cancelled workout's screen is still up while it is dismissed, and its 2-second tick (or
    /// the rest the cancel cleared) pushes again; SwiftData then reports the deleted workout as not
    /// deleted. That late push used to post a NEW card for a workout that no longer exists.
    @Test func aLatePushAfterTheEndDoesNotBringTheCardBack() {
        let (controller, presenter) = rig()
        let id = UUID()
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        controller.end(workoutID: id)
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state(sets: 4))
        #expect(presenter.starts == 1, "an ended workout's card is never requested again")
        #expect(!presenter.isActive)
        #expect(controller.workoutID == nil)
    }

    @Test func endAnyAlsoRefusesTheEndedWorkoutsCard() {
        let (controller, presenter) = rig()
        let id = UUID()
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        controller.endAny()
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        #expect(presenter.starts == 1)
    }

    /// The next workout still gets its card.
    @Test func aNewWorkoutAfterACancelShowsItsCard() {
        let (controller, presenter) = rig()
        let cancelled = UUID()
        controller.show(workoutID: cancelled, startedAt: .now, gymName: nil, state: state())
        controller.end(workoutID: cancelled)
        controller.show(workoutID: UUID(), startedAt: .now, gymName: nil, state: state())
        #expect(presenter.starts == 2)
        #expect(presenter.isActive)
    }

    /// codex-review-21 #1: a finish or cancel that failed after ending the card leaves the workout live; reopening
    /// lets its card come back when the workout is shown again.
    @Test func aReopenedWorkoutShowsItsCardAgain() {
        let (controller, presenter) = rig()
        let id = UUID()
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        controller.end(workoutID: id)
        controller.reopen(workoutID: id)
        controller.show(workoutID: id, startedAt: .now, gymName: nil, state: state())
        #expect(presenter.starts == 2)
        #expect(presenter.isActive)
    }

    /// codex-review-21 #2: the launch sweep runs only when the store says no workout is live — never when it could
    /// not be read, and never with a live one.
    @Test func theLaunchSweepNeedsAKnownAbsence() {
        let (controller, presenter) = rig()
        controller.reconcileAtLaunch(hasLiveWorkout: nil)
        controller.reconcileAtLaunch(hasLiveWorkout: true)
        #expect(presenter.sweeps == 0)
        controller.reconcileAtLaunch(hasLiveWorkout: false)
        #expect(presenter.sweeps == 1)
    }

    /// Ending with nothing tracked (a card left by an earlier launch, not yet adopted) sweeps every
    /// posted card rather than doing nothing.
    @Test func endingWithNothingTrackedSweepsStrayCards() {
        let (controller, presenter) = rig()
        controller.end(workoutID: UUID())
        #expect(presenter.sweeps == 1)
    }

    // MARK: - Honesty of the content

    /// D44's rule, carried onto the lock screen: absent means "not measured",
    /// never zero. A card showing 0 bpm would be a reading the app does not
    /// have.
    @Test func noSensorRendersAsAbsentRatherThanZero() {
        let (controller, presenter) = rig()
        controller.show(
            workoutID: UUID(), startedAt: .now, gymName: nil,
            state: state(bpm: nil))
        #expect(presenter.lastState?.heartRateBpm == nil)
    }
}
