import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Floodlight redesign ticket 11 — what the Lock Screen card is told, how it reads it, and the
/// commands pressed on it (+15s, Skip, Pause, Resume).
@MainActor
struct WorkoutActivityContentTests {
    typealias State = WorkoutActivityAttributes.ContentState

    private final class FakeNotifications: RestNotificationScheduling {
        var scheduled: [Date] = []
        var cancellations = 0
        func requestAuthorization() {}
        func schedule(at date: Date) { scheduled.append(date) }
        func cancel() { cancellations += 1 }
    }

    /// The container stays alive for the whole test (a context outliving it crashes).
    private struct Rig {
        let container: ModelContainer
        @MainActor var context: ModelContext { container.mainContext }
        let workout: Workout
        let press: ExerciseEntry
        let row: ExerciseEntry
        let pressSets: [SetRecord]
    }

    /// Chest Press: warm-up and set 1 done, set 2 drafted 50 kg × 8, set 3 empty; Row: one set.
    private func rig() throws -> Rig {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let workout = Workout(startedAt: .now.addingTimeInterval(-600))
        context.insert(workout)
        func entry(_ name: String, order: Int) -> ExerciseEntry {
            let exercise = Exercise(name: name)
            context.insert(exercise)
            let entry = ExerciseEntry(order: order, workout: workout, exercise: exercise, snapshotExerciseID: exercise.id,
                                      snapshotLoadType: .weighted, snapshotExerciseName: name)
            context.insert(entry)
            return entry
        }
        let press = entry("Chest Press", order: 0)
        let row = entry("Seated Row", order: 1)
        let sets = [
            SetRecord(order: 0, type: .warmup, reps: 12, weightValue: 20, completedAt: .now.addingTimeInterval(-300), entry: press),
            SetRecord(order: 1, reps: 8, weightValue: 45, completedAt: .now.addingTimeInterval(-60), entry: press),
            SetRecord(order: 2, reps: 8, weightValue: 50, entry: press),
            SetRecord(order: 3, entry: press),
        ]
        sets.forEach(context.insert)
        context.insert(SetRecord(order: 0, reps: 10, weightValue: 40, entry: row))
        try context.save()
        return Rig(container: container, workout: workout, press: press, row: row, pressSets: sets)
    }

    private func startRest(_ rig: Rig, after set: SetRecord, seconds: TimeInterval = 90) throws {
        rig.workout.restStartedAt = .now.addingTimeInterval(-10)
        rig.workout.restEndsAt = .now.addingTimeInterval(seconds - 10)
        rig.workout.restStartedBySetID = set.id
        try rig.context.save()
    }

    // MARK: Phases and results (the widget's reading)

    @Test func phaseFollowsTheRestAndTheStaleDate() {
        let now = Date.now
        var state = State(restEndsAt: now.addingTimeInterval(30), completedSets: 1, restStartedAt: now.addingTimeInterval(-60), rest: .timer)
        #expect(state.phase(at: now, isStale: false) == .resting)
        #expect(state.phase(at: now.addingTimeInterval(31), isStale: false) == .ready, "the countdown ran out")
        #expect(state.phase(at: now, isStale: true) == .ready, "the system marked it stale at the rest's end")
        state.cardio = .init(activity: "Indoor Run", symbol: "figure.run", isPaused: false, clockStart: now, elapsedSeconds: 0)
        #expect(state.phase(at: now, isStale: false) == .cardio)
    }

    @Test func aRestThatRanOutUnobservedSaysHowItEnded() {
        let now = Date.now
        let start = now.addingTimeInterval(-122), end = now.addingTimeInterval(-2)
        var state = State(heartRateBpm: 128, restEndsAt: end, completedSets: 2, restStartedAt: start, rest: .timer)
        #expect(state.shownResult(at: now, isStale: true) == .timer(seconds: 120))
        state.rest = .heartRate(targetBpm: 110)
        #expect(state.shownResult(at: now, isStale: true) == .cap(bpm: 128, targetBpm: 110, capSeconds: 120))
        state.rest = .fallback
        #expect(state.shownResult(at: now, isStale: true) == .noReading(seconds: 120))
        state.restResult = .recovered(bpm: 105, targetBpm: 110)
        #expect(state.shownResult(at: now, isStale: true) == .recovered(bpm: 105, targetBpm: 110), "what the app saw wins")
        state.restEndsAt = now.addingTimeInterval(60)
        #expect(state.shownResult(at: now, isStale: false) == nil, "no result while resting")
    }

    @Test func aStateFromAnOlderBuildStillDecodes() throws {
        let old = #"{"completedSets":3,"heartRateBpm":120,"currentExercise":"Bench Press"}"#
        let state = try JSONDecoder().decode(State.self, from: Data(old.utf8))
        #expect(state.completedSets == 3 && state.totalSets == nil && state.next == nil)
    }

    // MARK: The builder

    @Test func restingStateCarriesTheNextSetItsLineAndTheCounts() throws {
        let rig = try rig()
        try startRest(rig, after: rig.pressSets[1])
        let state = WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: .init(bpm: 128, zone: .two))
        #expect(state.completedSets == 2 && state.totalSets == 5)
        #expect(state.rest == .timer)
        #expect(state.restStartedAt == rig.workout.restStartedAt)
        #expect(state.heartRateBpm == 128 && state.zoneLevel == 2 && state.zoneLabel == HeartRateZone.two.label)
        #expect(state.currentExercise == "Chest Press")
        let next = try #require(state.next)
        #expect(next.marker == "2" && next.exerciseName == "Chest Press")
        #expect(next.weight == "50" && next.unit == "kg" && next.reps == 8)
        #expect(next.line == "Next · Set 2 · 50 kg × 8")
        #expect(state.phase(at: .now, isStale: false) == .resting)
    }

    @Test func theNextLineNamesTheExerciseWhenRestLeadsToAnother() throws {
        let rig = try rig()
        for set in rig.pressSets { set.completedAt = set.completedAt ?? .now; set.reps = set.reps ?? 8 }
        try startRest(rig, after: rig.pressSets[3])
        let state = WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil)
        #expect(state.next?.line == "Next · Seated Row")
        #expect(state.next?.exerciseName == "Seated Row")
        #expect(state.heartRateBpm == nil && state.zoneLevel == nil, "no reading is absent, never zero (D44)")
    }

    @Test func aHeartRateRestIsNamedAndItsFallbackToo() throws {
        let rig = try rig()
        try RestTimerService(context: rig.context).setOverride(
            for: try #require(rig.press.exercise), warmupSeconds: nil, workingSeconds: nil,
            restMode: .heartRate, heartRateThresholdBpm: 110, heartRateCapSeconds: 240)
        try startRest(rig, after: rig.pressSets[1])
        #expect(WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil).rest == .heartRate(targetBpm: 110))
        let degraded = WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil,
                                                   degradedRestSetID: rig.pressSets[1].id)
        #expect(degraded.rest == .fallback)
    }

    @Test func cardioStateTicksFromItsActiveStartAndKnowsItsTarget() throws {
        let rig = try rig()
        let segment = try CardioSession(context: rig.context).start(.indoorRun, in: rig.workout, at: .now.addingTimeInterval(-300))
        var plan = rig.workout.plannedCardio
        plan.append(PlannedCardio(activity: .indoorRun, minutes: 20, segmentID: segment.id))
        rig.workout.plannedCardio = plan
        try rig.context.save()
        let now = Date.now
        let state = WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil, now: now)
        let cardio = try #require(state.cardio)
        #expect(!cardio.isPaused && cardio.targetMinutes == 20 && cardio.activity == CardioActivity.indoorRun.name)
        let start = try #require(cardio.clockStart)
        #expect(abs(now.timeIntervalSince(start) - 300) < 2, "the system ticks the clock from the active start")
        #expect(state.phase(at: now, isStale: false) == .cardio)
        #expect(state.restEndsAt == nil, "starting cardio ends the rest")
    }

    // MARK: The builder, superset grouping (D48)

    @Test func groupingIntoASupersetMovesTheNextSetToThePartner() throws {
        let rig = try rig()
        try startRest(rig, after: rig.pressSets[1])
        #expect(WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil).next?.exerciseName == "Chest Press")
        let group = UUID()
        rig.press.supersetGroupID = group
        rig.row.supersetGroupID = group
        try rig.context.save()
        let grouped = WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil)
        #expect(grouped.next?.exerciseName == "Seated Row", "the partner comes next in a superset")
        #expect(grouped.next?.supersetLetter == "B")
    }

    // MARK: Commands pressed on the card

    /// A command centre with a real coordinator (silent alarm), a silent card, and a recorded
    /// runtime attach — the cold-launch path cannot start HealthKit in a unit test.
    private struct Commands {
        let commands: WorkoutActivityCommands
        let notifications: FakeNotifications
        let alarm: SilentRestAlarm
        let presenter: SilentWorkoutActivityPresenter
        let attached: Box
    }
    final class Box { var workoutIDs: [UUID] = [] }

    private func commands(_ rig: Rig) -> Commands {
        let alarm = SilentRestAlarm()
        let presenter = SilentWorkoutActivityPresenter()
        let attached = Box()
        let commands = WorkoutActivityCommands(
            coordinator: WorkoutHeartRateCoordinator(alarm: alarm),
            activity: WorkoutActivityController(presenter: presenter),
            attachRuntime: { workout, _ in attached.workoutIDs.append(workout.id) })
        commands.use(rig.container)
        let notifications = FakeNotifications()
        commands.notifications = notifications
        return Commands(commands: commands, notifications: notifications, alarm: alarm, presenter: presenter, attached: attached)
    }

    @Test func plusFifteenOnTheCardMovesTheRestItsAlarmAndTheCard() throws {
        let rig = try rig()
        try startRest(rig, after: rig.pressSets[1])
        let end = try #require(rig.workout.restEndsAt)
        let c = commands(rig)
        var posted = false
        let observer = NotificationCenter.default.addObserver(forName: WorkoutActivityCommands.didApply, object: nil, queue: nil) { note in
            posted = (note.object as? UUID) == rig.workout.id
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        #expect(c.commands.perform(.addFifteen, workoutID: rig.workout.id))
        #expect(c.attached.workoutIDs == [rig.workout.id], "the workout's runtime is attached first (cold launch)")
        #expect(rig.workout.restEndsAt == end.addingTimeInterval(15))
        #expect(c.notifications.scheduled.last == end.addingTimeInterval(15), "the rest notification moves with it")
        let queued = try #require(c.alarm.queued.first, "the audible alarm is re-queued for the new end")
        #expect(abs(queued.seconds - end.addingTimeInterval(15).timeIntervalSinceNow) < 2)
        #expect(posted, "the live screen re-reads its rest")
        #expect(c.presenter.starts == 1)
        #expect(c.presenter.lastState?.restEndsAt == end.addingTimeInterval(15), "the card is re-pushed")
    }

    @Test func skipOnTheCardEndsTheRestItsAlarmAndItsResult() throws {
        let rig = try rig()
        try startRest(rig, after: rig.pressSets[1])
        let c = commands(rig)
        c.commands.coordinator.lastRestResult = .timer(seconds: 90)
        #expect(c.commands.perform(.skipRest, workoutID: rig.workout.id))
        #expect(rig.workout.restEndsAt == nil && rig.workout.restStartedBySetID == nil)
        #expect(c.notifications.cancellations == 1)
        #expect(c.alarm.cancellations == 1 && c.alarm.queued.isEmpty, "the audible alarm is cancelled")
        #expect(c.commands.coordinator.lastRestResult == nil, "a skipped rest has no result")
        #expect(c.presenter.starts == 1, "the card was pushed")
        let state = try #require(c.presenter.lastState)
        #expect(state.restEndsAt == nil && state.shownResult(at: .now, isStale: false) == nil)
    }

    @Test func aCommandKeepsAHeartRateRestThatFellBackAFallback() throws {
        let rig = try rig()
        try RestTimerService(context: rig.context).setOverride(
            for: try #require(rig.press.exercise), warmupSeconds: nil, workingSeconds: nil,
            restMode: .heartRate, heartRateThresholdBpm: 110, heartRateCapSeconds: 240)
        try startRest(rig, after: rig.pressSets[1])
        let c = commands(rig)
        c.commands.coordinator.degradedRestSetID = rig.pressSets[1].id
        #expect(c.commands.perform(.addFifteen, workoutID: rig.workout.id))
        #expect(c.presenter.lastState?.rest == .fallback)
    }

    @Test func aCommandOnARestThatRanOutKeepsHowItEnded() throws {
        let rig = try rig()
        rig.workout.restStartedAt = .now.addingTimeInterval(-122)
        rig.workout.restEndsAt = .now.addingTimeInterval(-2)
        rig.workout.restStartedBySetID = rig.pressSets[1].id
        try rig.context.save()
        let c = commands(rig)
        #expect(!c.commands.perform(.skipRest, workoutID: rig.workout.id), "nothing left to skip")
        #expect(c.commands.coordinator.lastRestResult == .timer(seconds: 120))
        #expect(!c.commands.perform(.addFifteen, workoutID: rig.workout.id), "no adding to a finished rest")
        #expect(c.commands.coordinator.lastRestResult == .timer(seconds: 120), "the result survives the clearing")
    }

    @Test func aStaleCardCannotEditAWorkoutThatIsNotLive() throws {
        let rig = try rig()
        let c = commands(rig)
        #expect(!c.commands.perform(.addFifteen, workoutID: rig.workout.id), "no rest running")
        #expect(!c.commands.perform(.skipRest, workoutID: rig.workout.id), "no rest running")
        #expect(!c.commands.perform(.pauseCardio, workoutID: rig.workout.id), "no cardio running")
        #expect(!c.commands.perform(.skipRest, workoutID: UUID()), "unknown workout")
        try startRest(rig, after: rig.pressSets[1])
        rig.workout.finishedAt = .now
        try rig.context.save()
        #expect(!c.commands.perform(.skipRest, workoutID: rig.workout.id), "finished workout")
        #expect(rig.workout.restEndsAt != nil)
        #expect(c.presenter.starts == 0, "nothing pushed for a refused command")
    }

    @Test func pauseAndResumeOnTheCardDriveTheCardioSegment() throws {
        let rig = try rig()
        let segment = try CardioSession(context: rig.context).start(.indoorRun, in: rig.workout, at: .now.addingTimeInterval(-120))
        let c = commands(rig)
        #expect(!c.commands.perform(.resumeCardio, workoutID: rig.workout.id), "already running")
        #expect(c.commands.perform(.pauseCardio, workoutID: rig.workout.id))
        #expect(!segment.isRunning)
        #expect(c.presenter.lastState?.cardio?.isPaused == true)
        #expect(c.commands.perform(.resumeCardio, workoutID: rig.workout.id))
        #expect(segment.isRunning)
        let cardio = try #require(c.presenter.lastState?.cardio)
        #expect(!cardio.isPaused && abs(cardio.activeSeconds(at: .now) - 120) <= 2, "the clock resumes where it stopped")
    }

    // MARK: Cold launch and workout boundaries (codex-review-11b)

    private final class WatchFeed: HeartRateProviding, WatchRestBroadcasting {
        var sent: [Date?] = []
        var started = false
        var activeEnergyKilocalories: Double?
        var basalEnergyKilocalories: Double?
        let stream = AsyncStream<HeartRateSample> { _ in }
        func start() async -> HeartRateFeedState { started = true; sent.append(nil); return .waitingForSensor }
        func setPaused(_ paused: Bool) async {}
        func stop() async {}
        func sendRest(endsAt: Date?) { sent.append(endsAt) }
    }

    @Test func aColdPlusFifteenAttachesTheRuntimeAndReachesTheWatch() async throws {
        let rig = try rig()
        try startRest(rig, after: rig.pressSets[1])
        let end = try #require(rig.workout.restEndsAt)
        let feed = WatchFeed()
        let alarm = SilentRestAlarm()
        let coordinator = WorkoutHeartRateCoordinator(alarm: alarm, makeProvider: { _ in WorkoutActivityProvider { _ in feed } })
        let presenter = SilentWorkoutActivityPresenter()
        let commands = WorkoutActivityCommands(coordinator: coordinator, activity: WorkoutActivityController(presenter: presenter))
        commands.use(rig.container)
        commands.notifications = FakeNotifications()
        #expect(coordinator.workoutID == nil, "cold: no runtime yet")
        await commands.handle(.addFifteen, workoutID: rig.workout.id)
        #expect(coordinator.workoutID == rig.workout.id, "the command attached the workout's runtime")
        #expect(alarm.sessionOpens == 1 && abs((alarm.queued.first?.seconds ?? 0) - end.addingTimeInterval(15).timeIntervalSinceNow) < 2,
                "the audible alarm is armed for the extended rest")
        #expect(feed.started)
        #expect(feed.sent.last == end.addingTimeInterval(15), "the Watch hears the extended rest after its start message")
        #expect(presenter.lastState?.restEndsAt == end.addingTimeInterval(15))
        // A second command reuses the runtime rather than starting another.
        await commands.handle(.skipRest, workoutID: rig.workout.id)
        #expect(alarm.sessionOpens == 1)
        #expect(feed.sent.last == .some(nil), "Skip reaches the Watch")
        coordinator.end(rig.workout)
        await coordinator.settled()
    }

    @Test func restFactsDoNotCarryIntoTheNextWorkout() async throws {
        let rig = try rig()
        let coordinator = WorkoutHeartRateCoordinator(alarm: SilentRestAlarm(),
                                                      makeProvider: { _ in WorkoutActivityProvider { _ in WatchFeed() } })
        coordinator.monitor(for: rig.workout, maxHeartRate: nil)
        coordinator.lastRestResult = .timer(seconds: 90)
        coordinator.degradedRestSetID = rig.pressSets[1].id
        coordinator.monitor(for: rig.workout, maxHeartRate: nil)
        #expect(coordinator.lastRestResult == .timer(seconds: 90), "minimise and resume keep them")
        let next = Workout(startedAt: .now)
        rig.context.insert(next)
        coordinator.monitor(for: next, maxHeartRate: nil)
        #expect(coordinator.lastRestResult == nil && coordinator.degradedRestSetID == nil, "a new workout starts clean")
        coordinator.lastRestResult = .timer(seconds: 60)
        coordinator.end(next)
        #expect(coordinator.lastRestResult == nil, "ending the workout ends its rest facts")
        await coordinator.settled()
    }
}
