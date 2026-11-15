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

    /// An hour by default: a command only acts on a rest still running, and on GitHub's slower runner a test can wait
    /// minutes for the main actor (2026-11-14, run 43590959069: 338 s), so a 90-second rest ran out mid-test and
    /// "Skip" found nothing to skip.
    private func startRest(_ rig: Rig, after set: SetRecord, seconds: TimeInterval = 3600) throws {
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

    /// Records each queued beep as an absolute deadline: "in N seconds" is relative to the instant
    /// it is queued, which a slow `handle` would otherwise blur (codex-review-11c #3).
    final class DeadlineAlarm: RestAlarmSounding {
        var deadlines: [Date] = []
        var sessionOpens = 0
        var cancellations = 0
        func beginSession() { sessionOpens += 1 }
        func endSession() {}
        func scheduleBeep(inSeconds seconds: TimeInterval, pattern: RestAlarmPattern) {
            deadlines = [Date.now.addingTimeInterval(seconds)]
        }
        func cancelScheduledBeep() { cancellations += 1; deadlines.removeAll() }
        var hasQueuedBeep: Bool { !deadlines.isEmpty }
        func sound(_ pattern: RestAlarmPattern) {}
    }

    /// A command centre with a real coordinator (silent alarm), a silent card, and a recorded
    /// runtime attach — the cold-launch path cannot start HealthKit in a unit test.
    private struct Commands {
        let commands: WorkoutActivityCommands
        let notifications: FakeNotifications
        let alarm: DeadlineAlarm
        let presenter: SilentWorkoutActivityPresenter
        let attached: Box
    }
    final class Box { var workoutIDs: [UUID] = [] }

    private func commands(_ rig: Rig) -> Commands {
        let alarm = DeadlineAlarm()
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
        let deadline = try #require(c.alarm.deadlines.first, "the audible alarm is re-queued for the new end")
        #expect(abs(deadline.timeIntervalSince(end.addingTimeInterval(15))) < 0.5)
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
        #expect(c.alarm.cancellations == 1 && c.alarm.deadlines.isEmpty, "the audible alarm is cancelled")
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

    // MARK: Done on the card (live-workout 04)

    /// What the card showed: its current set, as the builder made it.
    private func shown(_ rig: Rig) throws -> WorkoutActivityShownSet {
        let next = try #require(WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil).next)
        return WorkoutActivityShownSet(workoutID: rig.workout.id, setID: try #require(next.setID),
                                       fingerprint: try #require(next.fingerprint))
    }

    @Test func theCardsCurrentSetCarriesItsIdAndIsLoggableOnlyWithAValue() throws {
        let rig = try rig()
        let next = try #require(WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil).next)
        #expect(next.setID == rig.pressSets[2].id && next.isLoggable)
        rig.pressSets[2].completedAt = .now
        try rig.context.save()
        let empty = try #require(WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil).next)
        #expect(empty.setID == nil && !empty.isLoggable, "no value, no Done")
        // A weight without reps is shown but cannot be logged (A1), so no Done either.
        rig.pressSets[3].weightValue = 55
        try rig.context.save()
        let weightOnly = try #require(WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil).next)
        #expect(weightOnly.weight == "55" && weightOnly.setID == nil && !weightOnly.isLoggable)
    }

    @Test func doneLogsTheShownSetAndStartsItsRestAlarmAndCard() throws {
        let rig = try rig()
        let c = commands(rig)
        var posted = false
        let observer = NotificationCenter.default.addObserver(forName: WorkoutActivityCommands.didApply, object: nil, queue: nil) { note in
            posted = (note.object as? UUID) == rig.workout.id
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        c.commands.coordinator.lastRestResult = .timer(seconds: 90)
        #expect(c.commands.performLogSet(try shown(rig)))
        let set = rig.pressSets[2]
        #expect(set.completedAt != nil && set.weightValue == 50 && set.reps == 8, "logged as shown")
        #expect(rig.press.snapshotCapturedAt != nil, "the set row's check: the snapshot is taken (D23)")
        #expect(rig.workout.restStartedBySetID == set.id && rig.workout.restEndsAt != nil, "its rest started")
        #expect(c.notifications.scheduled.count == 1, "the rest notification is scheduled")
        #expect(!c.alarm.deadlines.isEmpty, "the audible alarm is queued")
        #expect(c.commands.coordinator.lastRestResult == nil, "the last rest's result is gone")
        #expect(posted, "the live screen re-reads the workout")
        let state = try #require(c.presenter.lastState)
        #expect(state.completedSets == 3 && state.phase(at: .now, isStale: false) == .resting, "the card shows the rest")
    }

    /// The wrong record (AGENTS): a card that lags the workout logs nothing and is brought up to date.
    @Test func aStaleDoneLogsNothingAndRefreshesTheCard() throws {
        // The value was edited in the app after the card was drawn.
        do {
            let rig = try rig(); let c = commands(rig)
            let card = try shown(rig)
            rig.pressSets[2].reps = 10
            try rig.context.save()
            #expect(!c.commands.performLogSet(card))
            #expect(rig.pressSets[2].completedAt == nil && rig.workout.restEndsAt == nil)
            #expect(c.presenter.lastState?.next?.reps == 10, "the card catches up")
        }
        // The set was already checked in the app (the next set moved on).
        do {
            let rig = try rig(); let c = commands(rig)
            let card = try shown(rig)
            rig.pressSets[2].completedAt = .now.addingTimeInterval(-5)
            try rig.context.save()
            #expect(!c.commands.performLogSet(card))
            #expect(rig.pressSets[3].completedAt == nil, "no other set is logged in its place")
            #expect(c.presenter.lastState?.next?.exerciseName == "Chest Press" && c.presenter.lastState?.next?.isLoggable == false,
                    "the card catches up: set 3 has no value yet")
        }
        // The shown set is not the workout's next set.
        do {
            let rig = try rig(); let c = commands(rig)
            var card = try shown(rig)
            let rowSet = rig.row.sets!.first!
            card.setID = rowSet.id
            card.fingerprint = WorkoutActivityContent.logFingerprint(of: rowSet)
            #expect(!c.commands.performLogSet(card))
            #expect(rig.row.sets!.first!.completedAt == nil && rig.pressSets[2].completedAt == nil)
        }
        // The set was deleted.
        do {
            let rig = try rig(); let c = commands(rig)
            let card = try shown(rig)
            rig.context.delete(rig.pressSets[2])
            try rig.context.save()
            #expect(!c.commands.performLogSet(card))
            #expect(rig.pressSets[3].completedAt == nil)
        }
        // The workout finished (or is unknown): nothing logged, nothing pushed.
        do {
            let rig = try rig(); let c = commands(rig)
            let card = try shown(rig)
            rig.workout.finishedAt = .now
            try rig.context.save()
            #expect(!c.commands.performLogSet(card))
            var unknown = card; unknown.workoutID = UUID()
            #expect(!c.commands.performLogSet(unknown))
            #expect(rig.pressSets[2].completedAt == nil && c.presenter.starts == 0)
        }
    }

    /// codex-review-04 #3: the set's type and the exact stored weight are part of what was shown.
    @Test func aDoneAfterTheTypeOrAnUnseenDecimalChangedLogsNothing() throws {
        // Made a warmup in the app: same id, weight, unit and reps, a different set.
        do {
            let rig = try rig(); let c = commands(rig)
            let card = try shown(rig)
            rig.pressSets[2].type = .warmup
            try rig.context.save()
            #expect(!c.commands.performLogSet(card))
            #expect(rig.pressSets[2].completedAt == nil)
        }
        // 50.001 → 50.004 kg: both show "50".
        do {
            let rig = try rig(); let c = commands(rig)
            rig.pressSets[2].weightValue = 50.001
            try rig.context.save()
            let card = try shown(rig)
            rig.pressSets[2].weightValue = 50.004
            try rig.context.save()
            #expect(WorkoutActivityContent.make(for: rig.workout, in: rig.context, heart: nil).next?.weight == "50")
            #expect(!c.commands.performLogSet(card))
            #expect(rig.pressSets[2].completedAt == nil)
        }
    }

    /// codex-review-04 #1: a failed completion save leaves nothing behind — not in the context, not in the store — and
    /// the same set can then be logged.
    @Test func aFailedCompletionSaveIsRolledBackAndCanBeRetried() throws {
        struct SaveFailed: Error {}
        let rig = try rig()
        let gym = Gym(name: "Iron Temple")
        rig.context.insert(gym)
        rig.workout.gym = gym
        try rig.context.save()
        let c = commands(rig)
        let card = try shown(rig)
        c.commands.save = { _ in throw SaveFailed() }
        #expect(!c.commands.performLogSet(card))
        let set = rig.pressSets[2]
        #expect(set.completedAt == nil && rig.press.snapshotCapturedAt == nil, "the stamp and the snapshot are undone")
        #expect(try rig.context.fetchCount(FetchDescriptor<GymExerciseMemory>()) == 0, "and the gym memory")
        #expect(!rig.context.hasChanges)
        let setID = set.id
        let stored = try #require(try ModelContext(rig.container).fetch(FetchDescriptor<SetRecord>(predicate: #Predicate { $0.id == setID })).first)
        #expect(stored.completedAt == nil, "nothing reached the store")
        #expect(rig.workout.restEndsAt == nil && c.notifications.scheduled.isEmpty)
        #expect(c.presenter.lastState?.next?.setID == setID, "the card is refreshed, still on the set")
        c.commands.save = { try $0.save() }
        #expect(c.commands.performLogSet(card), "the same Done works once saving does")
        #expect(set.completedAt != nil)
    }

    /// codex-review-04 #2: a failed rest save keeps the logged set but publishes no rest that was never saved.
    @Test func aFailedRestSaveKeepsTheSetAndPublishesNoRest() throws {
        struct SaveFailed: Error {}
        let rig = try rig()
        let c = commands(rig)
        var saves = 0
        c.commands.save = { context in
            saves += 1
            if saves >= 2 { throw SaveFailed() }  // 1: the set's check; 2: its rest
            try context.save()
        }
        let card = try shown(rig)
        try rig.context.save()  // reading the card may create the preferences row; nothing else is pending
        #expect(c.commands.performLogSet(card), "the set itself was logged")
        let setID = rig.pressSets[2].id
        let stored = try #require(try ModelContext(rig.container).fetch(FetchDescriptor<SetRecord>(predicate: #Predicate { $0.id == setID })).first)
        #expect(stored.completedAt != nil)
        #expect(rig.workout.restEndsAt == nil && rig.workout.restStartedBySetID == nil, "the unsaved rest is rolled back")
        #expect(c.notifications.scheduled.isEmpty, "no notification for it")
        #expect(c.alarm.deadlines.isEmpty, "no alarm for it")
        #expect(c.presenter.lastState?.restEndsAt == nil, "the card shows no rest")
    }

    /// codex-review-04 #2, the superset branch: a failed skip leaves the running rest exactly as it was.
    @Test func aFailedSupersetSkipLeavesTheRunningRest() throws {
        struct SaveFailed: Error {}
        let rig = try rig()
        let group = UUID()
        rig.press.supersetGroupID = group
        rig.row.supersetGroupID = group
        let rowSet = try #require(rig.row.sets?.first)
        rowSet.completedAt = .now
        try rig.context.save()
        try startRest(rig, after: rowSet)
        let end = try #require(rig.workout.restEndsAt)
        let c = commands(rig)
        let card = try shown(rig)
        try rig.context.save()  // reading the card may create the preferences row; nothing else is pending
        var saves = 0
        c.commands.save = { context in
            saves += 1
            if saves >= 2 { throw SaveFailed() }  // 1: the set's check; 2: the skip
            try context.save()
        }
        #expect(c.commands.performLogSet(card))
        #expect(rig.pressSets[2].completedAt != nil)
        #expect(rig.workout.restEndsAt == end && rig.workout.restStartedBySetID == rowSet.id, "the rest still runs")
        #expect(c.notifications.cancellations == 0, "its notification stays armed")
        #expect(c.presenter.lastState?.restEndsAt == end)
    }

    /// codex-review-04 #4: a Done after a cold launch starts a heart-rate rest with no live screen; a recovering
    /// reading still ends it early (D43), and the card says so.
    @Test func aColdDoneHeartRateRestEndsEarlyWithoutTheScreen() async throws {
        let rig = try rig()
        try RestTimerService(context: rig.context).setOverride(
            for: try #require(rig.press.exercise), warmupSeconds: nil, workingSeconds: 3600,
            restMode: .heartRate, heartRateThresholdBpm: 110, heartRateCapSeconds: 7200)
        let provider = StubHeartRateProvider()
        let coordinator = WorkoutHeartRateCoordinator(alarm: DeadlineAlarm(), makeProvider: { _ in provider },
                                                      cardio: CardioRecorder(collectsDeviceSensors: false))
        let presenter = SilentWorkoutActivityPresenter()
        let commands = WorkoutActivityCommands(coordinator: coordinator, activity: WorkoutActivityController(presenter: presenter))
        commands.use(rig.container)
        commands.notifications = FakeNotifications()
        let clock = TestClock()
        coordinator.now = { clock.time }  // inside the no-reading grace: only the reading can end this rest
        #expect(coordinator.workoutID == nil, "cold: no runtime, no screen")
        await commands.logSet(try shown(rig))
        #expect(rig.pressSets[2].completedAt != nil)
        #expect(rig.workout.restEndsAt != nil && coordinator.onSample == nil)
        provider.emit(HeartRateSample(bpm: 104, date: .now, source: .fixture))
        try await waitUntil { rig.workout.restEndsAt == nil }
        #expect(rig.workout.restEndsAt == nil, "the reading under the target ended the rest")
        #expect(coordinator.lastRestResult == .recovered(bpm: 104, targetBpm: 110))
        #expect(presenter.lastState?.restEndsAt == nil, "the card was re-pushed")
        coordinator.end(rig.workout)
        await coordinator.settled()
    }

    /// codex-review-04 R2 #1: the load type the set would be logged under is part of what was shown — until the entry
    /// is frozen (D23), after which a catalog edit changes nothing about it.
    @Test func aDoneAfterTheLoadTypeChangedLogsNothingUntilTheEntryIsFrozen() throws {
        do {
            let rig = try rig(); let c = commands(rig)
            let card = try shown(rig)
            rig.press.exercise?.loadType = .bodyweight
            try rig.context.save()
            #expect(!c.commands.performLogSet(card), "shown as weighted, now bodyweight")
            #expect(rig.pressSets[2].completedAt == nil)
        }
        do {
            let rig = try rig(); let c = commands(rig)
            rig.press.snapshotCapturedAt = .now.addingTimeInterval(-60)
            rig.press.snapshotLoadType = .weighted
            try rig.context.save()
            let card = try shown(rig)
            rig.press.exercise?.loadType = .bodyweight
            try rig.context.save()
            #expect(c.commands.performLogSet(card), "a frozen entry keeps its load type, so the card still holds")
        }
    }

    /// A cold Done's heart-rate rest: a runtime with a scripted sensor and no screen.
    /// The coordinator's D43 clock, frozen and moved by the test (codex-review-04-ci #2): a delayed tick cannot pass the
    /// 20 s no-reading grace on its own while a recovery test waits for its sample.
    final class TestClock {
        var time: Date
        init(_ time: Date = .now) { self.time = time }
    }

    private struct ColdHeartRateRest {
        let clock: TestClock
        let rig: Rig
        let provider: StubHeartRateProvider
        let coordinator: WorkoutHeartRateCoordinator
        let commands: WorkoutActivityCommands
        let presenter: SilentWorkoutActivityPresenter
        let notifications: FakeNotifications
    }

    private func coldHeartRateRest() async throws -> ColdHeartRateRest {
        let rig = try rig()
        try RestTimerService(context: rig.context).setOverride(
            for: try #require(rig.press.exercise), warmupSeconds: nil, workingSeconds: 3600,
            restMode: .heartRate, heartRateThresholdBpm: 110, heartRateCapSeconds: 7200)
        let provider = StubHeartRateProvider()
        let coordinator = WorkoutHeartRateCoordinator(alarm: DeadlineAlarm(), makeProvider: { _ in provider },
                                                      cardio: CardioRecorder(collectsDeviceSensors: false))
        let presenter = SilentWorkoutActivityPresenter()
        let commands = WorkoutActivityCommands(coordinator: coordinator, activity: WorkoutActivityController(presenter: presenter))
        commands.use(rig.container)
        let notifications = FakeNotifications()
        commands.notifications = notifications
        let clock = TestClock()
        coordinator.now = { clock.time }  // frozen before the rest starts: inside the grace until a test moves it
        await commands.logSet(try shown(rig))
        try #require(rig.workout.restEndsAt != nil && coordinator.onSample == nil)
        return ColdHeartRateRest(clock: clock, rig: rig, provider: provider, coordinator: coordinator, commands: commands,
                                 presenter: presenter, notifications: notifications)
    }

    /// Polls until `condition` holds, up to five minutes — hang protection only; it returns as soon as the condition holds.
    /// On GitHub's runner these tests took 310 s (2026-11-15, run 43698481749), long enough for the real clock to pass the
    /// rests they assumed; the D43 clock is now the test's own (`TestClock`).
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date.now.addingTimeInterval(300)
        while !condition(), Date.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
    }

    /// codex-review-04 R2 #2: a failed save when the reading recovers leaves the rest as it was saved, and the next
    /// reading tries again.
    @Test func aFailedRecoverySaveKeepsTheRestAndTheNextReadingRetries() async throws {
        struct SaveFailed: Error {}
        let cold = try await coldHeartRateRest()
        let end = cold.rig.workout.restEndsAt
        var failedTransitions = 0
        cold.commands.save = { context in
            // Only the recovery's own save fails (the rest already cleared in memory); other pending edits save.
            if cold.rig.workout.restEndsAt == nil { failedTransitions += 1; throw SaveFailed() }
            try context.save()
        }
        cold.provider.emit(HeartRateSample(bpm: 104, date: .now, source: .fixture))
        try await waitUntil { failedTransitions >= 1 }
        #expect(failedTransitions >= 1, "the recovery's save was attempted and failed")
        #expect(cold.rig.workout.restEndsAt == end, "rolled back: the rest is as it was saved")
        #expect(cold.coordinator.lastRestResult == nil)
        cold.commands.save = { try $0.save() }
        cold.provider.emit(HeartRateSample(bpm: 103, date: .now, source: .fixture))
        try await waitUntil { cold.rig.workout.restEndsAt == nil }
        #expect(cold.rig.workout.restEndsAt == nil && cold.coordinator.lastRestResult != nil, "the next reading ended it")
        cold.coordinator.end(cold.rig.workout)
        await cold.coordinator.settled()
    }

    /// codex-review-04 R2 #3: with no reading at all, the screenless runtime's own tick drops the rest to the standard
    /// timer once the grace period passes (D43) — and a failed save there is retried on the next tick.
    @Test func noReadingFallsBackToTheTimerWithoutAScreenOrASample() async throws {
        struct SaveFailed: Error {}
        let cold = try await coldHeartRateRest()
        let set = cold.rig.pressSets[2]
        let start = try #require(cold.rig.workout.restStartedAt)
        let cap = try #require(cold.rig.workout.restEndsAt)
        let standard = try RestTimerService(context: cold.rig.context).durationSeconds(for: set)
        var failedTransitions = 0
        cold.commands.save = { context in
            // Only the fallback's own save fails (the end already moved in memory); other pending edits save.
            if cold.rig.workout.restEndsAt != cap { failedTransitions += 1; throw SaveFailed() }
            try context.save()
        }
        cold.coordinator.restEvaluatorInterval = .milliseconds(20)
        let evaluator = cold.coordinator.restEvaluator
        cold.coordinator.restEvaluator = evaluator  // restart the tick at the new period
        cold.clock.time = start.addingTimeInterval(30)  // past the 20 s grace, no sample ever
        try await waitUntil { failedTransitions >= 1 }
        #expect(failedTransitions >= 1, "the fallback's save was attempted and failed")
        #expect(cold.coordinator.degradedRestSetID == nil, "a failed fallback save marks nothing")
        #expect(cold.rig.workout.restEndsAt == cap, "rolled back: the cap as saved")
        cold.commands.save = { try $0.save() }
        try await waitUntil { cold.coordinator.degradedRestSetID != nil }
        #expect(cold.coordinator.degradedRestSetID == set.id, "the next tick retried")
        #expect(cold.rig.workout.restEndsAt == start.addingTimeInterval(TimeInterval(standard)), "the standard timer")
        #expect(cold.presenter.lastState?.rest == .fallback, "the card says it fell back")
        cold.coordinator.end(cold.rig.workout)
        await cold.coordinator.settled()
    }

    /// codex-review-04 R3: a workout opened on its screen and then minimised — the screen claimed the samples, then
    /// released them — still falls back with no reading after a Done, through the runtime.
    @Test func aMinimisedWorkoutStillFallsBackWithoutAReading() async throws {
        let rig = try rig()
        try RestTimerService(context: rig.context).setOverride(
            for: try #require(rig.press.exercise), warmupSeconds: nil, workingSeconds: 3600,
            restMode: .heartRate, heartRateThresholdBpm: 110, heartRateCapSeconds: 7200)
        let provider = StubHeartRateProvider()
        let coordinator = WorkoutHeartRateCoordinator(alarm: DeadlineAlarm(), makeProvider: { _ in provider },
                                                      cardio: CardioRecorder(collectsDeviceSensors: false))
        let presenter = SilentWorkoutActivityPresenter()
        let commands = WorkoutActivityCommands(coordinator: coordinator, activity: WorkoutActivityController(presenter: presenter))
        commands.use(rig.container)
        commands.notifications = FakeNotifications()
        commands.installRestEvaluator()
        let clock = TestClock()
        coordinator.now = { clock.time }
        // The live screen: attaches the runtime and claims the samples; then minimise.
        _ = coordinator.monitor(for: rig.workout, maxHeartRate: nil)
        var screenChecks = 0
        coordinator.claimSamples(for: rig.workout.id) { screenChecks += 1 }
        coordinator.releaseSamples(for: UUID())
        #expect(coordinator.onSample != nil, "another workout's screen cannot release this one's claim")
        coordinator.releaseSamples(for: rig.workout.id)
        #expect(coordinator.onSample == nil, "minimised: released")
        await commands.logSet(try shown(rig))
        let set = rig.pressSets[2]
        let start = try #require(rig.workout.restStartedAt)
        let standard = try RestTimerService(context: rig.context).durationSeconds(for: set)
        clock.time = start.addingTimeInterval(30)  // past the 20 s grace, no sample ever
        coordinator.restEvaluatorInterval = .milliseconds(20)
        let evaluator = coordinator.restEvaluator
        coordinator.restEvaluator = evaluator  // restart the tick at the new period
        try await waitUntil { coordinator.degradedRestSetID != nil }
        #expect(coordinator.degradedRestSetID == set.id)
        #expect(rig.workout.restEndsAt == start.addingTimeInterval(TimeInterval(standard)))
        #expect(presenter.lastState?.rest == .fallback)
        #expect(screenChecks == 0, "the released screen is not called")
        coordinator.end(rig.workout)
        await coordinator.settled()
    }

    /// With the screen up the runtime's tick runs the SCREEN's check (it redraws), not its own.
    @Test func theTickRunsTheScreensCheckWhileTheScreenOwnsTheWorkout() async throws {
        let rig = try rig()
        let coordinator = WorkoutHeartRateCoordinator(alarm: DeadlineAlarm(), makeProvider: { _ in StubHeartRateProvider() },
                                                      cardio: CardioRecorder(collectsDeviceSensors: false))
        _ = coordinator.monitor(for: rig.workout, maxHeartRate: nil)
        var screen = 0, runtime = 0
        coordinator.claimSamples(for: rig.workout.id) { screen += 1 }
        coordinator.restEvaluatorInterval = .milliseconds(20)
        coordinator.restEvaluator = { runtime += 1 }
        try await waitUntil { screen >= 2 }
        #expect(screen >= 2 && runtime == 0)
        coordinator.end(rig.workout)
        await coordinator.settled()
    }

    /// D48 through the shared rule: Done on a superset member that is not the last starts no rest and skips one running.
    @Test func doneInsideASupersetSkipsTheRestLikeTheCheck() throws {
        let rig = try rig()
        let group = UUID()
        rig.press.supersetGroupID = group
        rig.row.supersetGroupID = group
        let rowSet = try #require(rig.row.sets?.first)
        rowSet.completedAt = .now
        try rig.context.save()
        try startRest(rig, after: rowSet)
        let c = commands(rig)
        let card = try shown(rig)
        #expect(card.setID == rig.pressSets[2].id, "the press (A) is next")
        #expect(c.commands.performLogSet(card))
        #expect(rig.pressSets[2].completedAt != nil)
        #expect(rig.workout.restEndsAt == nil, "no rest between members; the running one is skipped")
        #expect(c.notifications.cancellations >= 1)
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
        let alarm = DeadlineAlarm()
        let coordinator = WorkoutHeartRateCoordinator(alarm: alarm, makeProvider: { _ in WorkoutActivityProvider { _ in feed } },
                                                      cardio: CardioRecorder(collectsDeviceSensors: false))
        let presenter = SilentWorkoutActivityPresenter()
        let commands = WorkoutActivityCommands(coordinator: coordinator, activity: WorkoutActivityController(presenter: presenter))
        commands.use(rig.container)
        commands.notifications = FakeNotifications()
        #expect(coordinator.workoutID == nil, "cold: no runtime yet")
        await commands.handle(.addFifteen, workoutID: rig.workout.id)
        #expect(coordinator.workoutID == rig.workout.id, "the command attached the workout's runtime")
        #expect(alarm.sessionOpens == 1)
        let deadline = try #require(alarm.deadlines.first, "the audible alarm is armed")
        #expect(abs(deadline.timeIntervalSince(end.addingTimeInterval(15))) < 0.5, "for the extended rest")
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
                                                      makeProvider: { _ in WorkoutActivityProvider { _ in WatchFeed() } },
                                                      cardio: CardioRecorder(collectsDeviceSensors: false))
        // A relaunch: the screen restores an expired rest's result before the runtime attaches.
        coordinator.noteRestFacts(for: rig.workout.id)
        coordinator.lastRestResult = .timer(seconds: 90)
        coordinator.monitor(for: rig.workout, maxHeartRate: nil)
        #expect(coordinator.lastRestResult == .timer(seconds: 90), "the first attachment keeps this workout's restored result")
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

        // Replacement with facts restored first (codex-review-11d #1): A is attached; B's screen
        // restores B's result, then B's runtime replaces A's. A's teardown must not take B's facts.
        let a = Workout(startedAt: .now.addingTimeInterval(-60))
        let b = Workout(startedAt: .now)
        rig.context.insert(a); rig.context.insert(b)
        coordinator.monitor(for: a, maxHeartRate: nil)
        coordinator.lastRestResult = .timer(seconds: 45)
        coordinator.noteRestFacts(for: b.id)
        #expect(coordinator.lastRestResult == nil, "B's screen does not inherit A's result")
        coordinator.lastRestResult = .noReading(seconds: 120)
        coordinator.monitor(for: b, maxHeartRate: nil)
        #expect(coordinator.lastRestResult == .noReading(seconds: 120), "A's teardown keeps B's restored result")
        let fallback = UUID()
        coordinator.degradedRestSetID = fallback
        coordinator.noteRestFacts(for: b.id)
        #expect(coordinator.degradedRestSetID == fallback, "B's own facts survive B's refresh after the replacement")
        coordinator.end(b)
        #expect(coordinator.lastRestResult == nil && coordinator.degradedRestSetID == nil)
        await coordinator.settled()
    }

    /// A feed whose start can be held, like a HealthKit session waiting on collection.
    private final class GatedFeed: HeartRateProviding {
        var activeEnergyKilocalories: Double?
        var basalEnergyKilocalories: Double?
        let stream = AsyncStream<HeartRateSample> { _ in }
        var started = false
        private var gate: CheckedContinuation<Void, Never>?
        private var open = false
        func start() async -> HeartRateFeedState {
            if !open { await withCheckedContinuation { gate = $0 } }
            started = true
            return .waitingForSensor
        }
        func release() { open = true; gate?.resume(); gate = nil }
        func setPaused(_ paused: Bool) async {}
        func stop() async {}
    }

    @Test func resumeOnTheCardWaitsForTheSensorsToStart() async throws {
        let rig = try rig()
        let segment = try CardioSession(context: rig.context).start(.indoorRun, in: rig.workout, at: .now.addingTimeInterval(-120))
        try CardioSession(context: rig.context).pause(segment)
        var cardioFeeds: [GatedFeed] = []
        let workout = rig.workout
        let coordinator = WorkoutHeartRateCoordinator(
            alarm: DeadlineAlarm(),
            makeProvider: { _ in
                WorkoutActivityProvider(configuration: workout.sensorConfiguration) { phase in
                    let feed = GatedFeed()
                    if phase.activity == nil { feed.release() } else { cardioFeeds.append(feed) }
                    return feed
                }
            },
            cardio: CardioRecorder(collectsDeviceSensors: false))
        let commands = WorkoutActivityCommands(coordinator: coordinator,
                                               activity: WorkoutActivityController(presenter: SilentWorkoutActivityPresenter()))
        commands.use(rig.container)
        commands.notifications = FakeNotifications()
        // The runtime is attached and settled with the segment paused: no cardio provider runs.
        coordinator.monitor(for: rig.workout, maxHeartRate: nil)
        await coordinator.ready()
        #expect(cardioFeeds.isEmpty)
        var finished = false
        let press = Task { await commands.handle(.resumeCardio, workoutID: workout.id); finished = true }
        for _ in 0..<50 where cardioFeeds.isEmpty { await Task.yield() }
        let feed = try #require(cardioFeeds.first, "Resume starts the cardio provider")
        for _ in 0..<20 { await Task.yield() }
        #expect(!finished, "the intent has not returned while the provider is still starting")
        #expect(segment.isRunning)
        feed.release()
        await press.value
        #expect(finished && feed.started)
        coordinator.end(rig.workout)
        await coordinator.settled()
    }
}
