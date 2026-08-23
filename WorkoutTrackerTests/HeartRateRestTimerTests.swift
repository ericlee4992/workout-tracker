import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Milestone 7, ticket 06 — the heart-rate rest, wired to the machinery that
// already existed (D13/D22/D26 + D43).
//
// The rule itself is proven in `HeartRateTests`; what these prove is the
// wiring: which mode a set rests under, what the countdown is, and — the part
// that would be easiest to get quietly wrong — WHICH alarm fires and what it
// says.

@MainActor
private final class SpyScheduler: RestNotificationScheduling {
    struct Scheduled: Equatable {
        var date: Date
        var title: String
        var body: String
    }
    private(set) var scheduled: [Scheduled] = []
    private(set) var cancels = 0
    var authorizationRequests = 0

    func requestAuthorization() { authorizationRequests += 1 }

    func schedule(at date: Date) {
        scheduled.append(
            Scheduled(date: date, title: "Rest complete", body: "Time for your next set."))
    }

    func schedule(at date: Date, title: String, body: String) {
        scheduled.append(Scheduled(date: date, title: title, body: body))
    }

    func cancel() { cancels += 1 }
}

private struct FixedClock: RestClock {
    var now: Date
}

@MainActor
struct HeartRateRestTimerTests {

    private let t0 = Date(timeIntervalSince1970: 3_000_000)

    private struct Rig {
        var context: ModelContext
        var service: RestTimerService
        var session: WorkoutSession
        var scheduler: SpyScheduler
        var exercise: Exercise
        var gym: Gym
    }

    private func makeRig() throws -> Rig {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let exercise = Exercise(name: "Bench Press")
        let gym = Gym(name: "Gym", defaultUnit: .kg)
        context.insert(exercise)
        context.insert(gym)
        try context.save()
        let scheduler = SpyScheduler()
        return Rig(
            context: context,
            service: RestTimerService(
                context: context, clock: FixedClock(now: t0), notifications: scheduler),
            session: WorkoutSession(context: context, notifications: scheduler),
            scheduler: scheduler,
            exercise: exercise,
            gym: gym)
    }

    private func loggedSet(_ rig: Rig) throws -> (Workout, SetRecord) {
        let workout = try rig.session.startWorkout(at: rig.gym, on: t0)
        let entry = try rig.session.addEntry(for: rig.exercise, to: workout)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try rig.session.commitWeight("60", for: set)
        try rig.session.commitReps("10", for: set)
        return (workout, set)
    }

    private func enableHeartRateRest(
        _ rig: Rig, threshold: Int = 110, cap: Int = 240
    ) throws {
        try rig.service.setOverride(
            for: rig.exercise, warmupSeconds: nil, workingSeconds: nil,
            restMode: .heartRate, heartRateThresholdBpm: threshold,
            heartRateCapSeconds: cap)
    }

    // MARK: Mode resolution

    @Test func anExerciseWithNoOverrideRestsByTheClock() throws {
        let rig = try makeRig()
        let (_, set) = try loggedSet(rig)
        let plan = try rig.service.restPlan(for: set)
        #expect(plan.mode == .standard)
        #expect(plan.rule == nil)
        #expect(plan.seconds == 120, "the global working default (D22)")
    }

    @Test func heartRateModeUsesItsThresholdAndCap() throws {
        let rig = try makeRig()
        let (_, set) = try loggedSet(rig)
        try enableHeartRateRest(rig, threshold: 105, cap: 180)
        let plan = try rig.service.restPlan(for: set)
        #expect(plan.mode == .heartRate)
        #expect(plan.rule?.thresholdBpm == 105)
        #expect(plan.seconds == 180, "the countdown is the cap")
    }

    /// A user who asked for a heart-rate rest and supplied no numbers gets the
    /// defaults — never a silently standard timer, which would be the app
    /// quietly doing something other than what was asked.
    @Test func heartRateModeWithoutNumbersFallsBackToDefaults() throws {
        let rig = try makeRig()
        let (_, set) = try loggedSet(rig)
        try rig.service.setOverride(
            for: rig.exercise, warmupSeconds: nil, workingSeconds: nil, restMode: .heartRate)
        let plan = try rig.service.restPlan(for: set)
        #expect(plan.mode == .heartRate)
        #expect(plan.rule?.thresholdBpm == HeartRateRestRule.defaultThresholdBpm)
        #expect(plan.seconds == Int(HeartRateRestRule.defaultCap))
    }

    @Test func capAndThresholdAreClampedRatherThanTrusted() throws {
        let rig = try makeRig()
        let (_, set) = try loggedSet(rig)
        try enableHeartRateRest(rig, threshold: 5, cap: 0)
        let plan = try rig.service.restPlan(for: set)
        // A zero cap would expire the rest the instant it started.
        #expect(plan.seconds >= 15)
        #expect((plan.rule?.thresholdBpm ?? 0) >= 30)
    }

    // MARK: What the alarm says (D43)

    @Test func startingAHeartRateRestSchedulesTheCapAlarm_sayingTimeRanOut() throws {
        let rig = try makeRig()
        let (_, set) = try loggedSet(rig)
        try enableHeartRateRest(rig, cap: 180)

        let state = try rig.service.handleCompletionChange(of: set, isCompleted: true)

        #expect(state?.total == 180)
        let scheduled = try #require(rig.scheduler.scheduled.last)
        #expect(scheduled.date == t0.addingTimeInterval(180))
        #expect(
            scheduled.body.contains("Time is up"),
            "the cap alarm must not claim a recovery it never saw, got: \(scheduled.body)")
    }

    @Test func recoveringEndsTheRestEarlyAndSaysSo() throws {
        let rig = try makeRig()
        let (workout, set) = try loggedSet(rig)
        try enableHeartRateRest(rig)
        _ = try rig.service.handleCompletionChange(of: set, isCompleted: true)
        #expect(workout.restEndsAt != nil)

        try rig.service.finishRecovered(workout, bpm: 104)

        // The persisted rest is cleared, so a relaunch does not resurrect it.
        #expect(workout.restEndsAt == nil)
        #expect(workout.restStartedBySetID == nil)
        let scheduled = try #require(rig.scheduler.scheduled.last)
        #expect(scheduled.body.contains("104"), "the alarm names the reading that ended it")
        #expect(!scheduled.body.contains("Time is up"))
    }

    @Test func recoveringOnAWorkoutWithNoRestDoesNothing() throws {
        let rig = try makeRig()
        let (workout, _) = try loggedSet(rig)
        let before = rig.scheduler.scheduled.count
        try rig.service.finishRecovered(workout, bpm: 100)
        #expect(rig.scheduler.scheduled.count == before, "no rest, no alarm")
    }

    // MARK: The rules that must not regress

    /// D26: a drop set is performed without resting, in either mode.
    @Test func aDropSetStartsNoRestInHeartRateModeEither() throws {
        let rig = try makeRig()
        let (workout, set) = try loggedSet(rig)
        try enableHeartRateRest(rig)
        try rig.session.setType(.drop, of: set)

        _ = try rig.service.handleCompletionChange(of: set, isCompleted: true)

        #expect(workout.restEndsAt == nil)
        #expect(rig.scheduler.scheduled.isEmpty)
    }

    /// The existing un-complete behaviour must survive: un-completing the set
    /// that started the rest cancels it.
    @Test func unCompletingTheStartingSetCancelsAHeartRateRest() throws {
        let rig = try makeRig()
        let (workout, set) = try loggedSet(rig)
        try enableHeartRateRest(rig)
        _ = try rig.service.handleCompletionChange(of: set, isCompleted: true)
        #expect(workout.restEndsAt != nil)

        _ = try rig.service.handleCompletionChange(of: set, isCompleted: false)

        #expect(workout.restEndsAt == nil)
        #expect(rig.scheduler.cancels >= 1)
    }

    /// Switching an exercise back to the clock mid-workout must not strand a
    /// running heart-rate rest: the cap is the persisted end either way, so the
    /// rest still finishes on its own.
    @Test func switchingModeMidRestLeavesTheRunningRestIntact() throws {
        let rig = try makeRig()
        let (workout, set) = try loggedSet(rig)
        try enableHeartRateRest(rig, cap: 200)
        _ = try rig.service.handleCompletionChange(of: set, isCompleted: true)
        let end = try #require(workout.restEndsAt)

        try rig.service.setOverride(
            for: rig.exercise, warmupSeconds: nil, workingSeconds: nil, restMode: .standard)

        #expect(workout.restEndsAt == end, "the running rest keeps its own deadline")
        #expect(try rig.service.restPlan(for: set).mode == .standard, "the NEXT rest is standard")
    }
}
