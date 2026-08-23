import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Milestone 7, ticket 08 — one test per defect the Codex cross-review found
// (`.scratch/milestone-7-heart-rate/codex-review.md`).
//
// Kept as a named suite rather than scattered, because the review's own lesson
// from the scanner rounds is that the worst finding of round 2 is usually a
// defect introduced by round 1's fix. These are the tripwires for that.

@MainActor
private final class SpyScheduler: RestNotificationScheduling {
    struct Scheduled: Equatable { var date: Date; var title: String; var body: String }
    private(set) var scheduled: [Scheduled] = []
    private(set) var cancels = 0
    func requestAuthorization() {}
    func schedule(at date: Date) {
        scheduled.append(.init(date: date, title: "Rest complete", body: "Time for your next set."))
    }
    func schedule(at date: Date, title: String, body: String) {
        scheduled.append(.init(date: date, title: title, body: body))
    }
    func cancel() { cancels += 1 }
}

private struct FixedClock: RestClock { var now: Date }

@MainActor
struct CodexReviewRegressionTests {

    private let t0 = Date(timeIntervalSince1970: 6_000_000)

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        return ModelContext(try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }

    // MARK: 2.1 (critical) — degrading means the USER'S rest, not the cap

    @Test func aDeadSensorFallsBackToTheStandardDuration_notTheCap() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Press")
        let gym = Gym(name: "Gym")
        context.insert(exercise); context.insert(gym)
        try context.save()

        let scheduler = SpyScheduler()
        let clock = FixedClock(now: t0)
        let service = RestTimerService(context: context, clock: clock, notifications: scheduler)
        let session = WorkoutSession(context: context, notifications: scheduler)

        // A 90-second standard rest, and a heart-rate mode capped at 4 minutes.
        try service.setOverride(
            for: exercise, warmupSeconds: nil, workingSeconds: 90,
            restMode: .heartRate, heartRateThresholdBpm: 110, heartRateCapSeconds: 240)

        let workout = try session.startWorkout(at: gym, on: t0)
        let entry = try session.addEntry(for: exercise, to: workout)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.commitWeight("60", for: set)
        try session.commitReps("10", for: set)
        _ = try service.handleCompletionChange(of: set, isCompleted: true)
        #expect(workout.restEndsAt == t0.addingTimeInterval(240), "starts on the cap")

        // Nothing ever reports: the rule degrades, and the rest must become the
        // 90 seconds the user configured — not sit on the 4-minute cap.
        let state = try service.degradeToStandard(workout, set: set)

        #expect(workout.restEndsAt == t0.addingTimeInterval(90))
        #expect(state?.total == 90)
        let alarm = try #require(scheduler.scheduled.last)
        #expect(alarm.date == t0.addingTimeInterval(90))
        #expect(
            alarm.body.contains("No heart rate"),
            "the user must be told it degraded, got: \(alarm.body)")
    }

    @Test func degradingIsIdempotent_soATickingTimerDoesNotRescheduleForever() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Press")
        let gym = Gym(name: "Gym")
        context.insert(exercise); context.insert(gym)
        try context.save()
        let scheduler = SpyScheduler()
        let service = RestTimerService(
            context: context, clock: FixedClock(now: t0), notifications: scheduler)
        let session = WorkoutSession(context: context, notifications: scheduler)
        try service.setOverride(
            for: exercise, warmupSeconds: nil, workingSeconds: 90,
            restMode: .heartRate, heartRateThresholdBpm: 110, heartRateCapSeconds: 240)
        let workout = try session.startWorkout(at: gym, on: t0)
        let entry = try session.addEntry(for: exercise, to: workout)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.commitWeight("60", for: set)
        try session.commitReps("10", for: set)
        _ = try service.handleCompletionChange(of: set, isCompleted: true)

        _ = try service.degradeToStandard(workout, set: set)
        let afterFirst = scheduler.scheduled.count
        _ = try service.degradeToStandard(workout, set: set)
        _ = try service.degradeToStandard(workout, set: set)

        #expect(scheduler.scheduled.count == afterFirst, "already standard: nothing to reschedule")
    }

    // MARK: 2.3 (high) — never two contradictory alarms for one rest

    @Test func afterTheCapHasPassedARecoveryIsNotAlsoReported() {
        let rule = HeartRateRestRule(thresholdBpm: 110, cap: 240)
        // A qualifying reading exists inside the window, but it is only being
        // evaluated after the deadline — the cap alarm has already fired.
        let samples = [
            HeartRateSample(bpm: 150, date: t0.addingTimeInterval(30), source: .watch),
            HeartRateSample(bpm: 100, date: t0.addingTimeInterval(200), source: .watch),
        ]
        let atDeadline = rule.evaluate(
            samples: samples, start: t0, asOf: t0.addingTimeInterval(240))
        // codex-review-2 #1: this test used to bless `.recovered` here, which is
        // how the contradiction survived round 1. Past the deadline the cap
        // alarm has already gone out; reporting recovery now would deliver a
        // second, opposite alarm about the same rest. A recovery that was
        // *observed* in time ends the rest through the normal path instead.
        #expect(atDeadline == .finished(.cap(at: t0.addingTimeInterval(240))))

        // With no qualifying reading, past the deadline is a cap and stays one.
        let hard = [HeartRateSample(bpm: 150, date: t0.addingTimeInterval(30), source: .watch)]
        #expect(
            rule.evaluate(samples: hard, start: t0, asOf: t0.addingTimeInterval(600))
                == .finished(.cap(at: t0.addingTimeInterval(240))))
    }

    // MARK: codex-review-2 #6 — the summary must not depend on when it was asked

    @Test func oneLateSampleFromAnotherSensorDoesNotOwnTheWholeWorkout() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        let base = Date().addingTimeInterval(-600)
        // Ten minutes of AirPods…
        for index in 0..<40 {
            provider.emit(HeartRateSample(
                bpm: 120, date: base.addingTimeInterval(Double(index) * 10), source: .airPods))
        }
        // …then one fresh Watch reading, arriving just before Finish.
        provider.emit(HeartRateSample(bpm: 60, date: Date(), source: .watch))
        var lastCount = -1
        while monitor.samples.count != lastCount {
            lastCount = monitor.samples.count
            for _ in 0..<200 { await Task.yield() }
        }

        #expect(monitor.currentSource == .watch, "the live reading is the Watch's")
        #expect(monitor.dominantSource == .airPods, "but the workout was recorded on AirPods")
        #expect(
            monitor.vitals.averageBpm == 120,
            "a one-sample average of 60 would be the summary depending on the instant it was taken")
        #expect(monitor.vitals.sampleCount == 40)
    }

    // MARK: 3.2 (high) — one series means ONE sensor's series

    @Test func vitalsAndTheRestRuleUseOneSensor_notAnInterleavingOfTwo() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        let now = Date()
        // Both sensors reporting: the Watch wins precedence.
        provider.emit(HeartRateSample(bpm: 150, date: now, source: .watch))
        provider.emit(HeartRateSample(bpm: 100, date: now, source: .airPods))
        for _ in 0..<10 { await Task.yield() }

        #expect(monitor.currentSource == .watch)
        #expect(monitor.samples.count == 2, "both are kept…")
        #expect(monitor.samplesFromCurrentSource.count == 1, "…but only one feeds the rest rule")
        #expect(
            monitor.vitals.averageBpm == 150,
            "an average of 125 would be a blend of two devices")
    }

    // MARK: 3.3 (high) — the label names the sensor the number came from

    @Test func theFeedStateNamesTheSourceOfTheReadingShown() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        let now = Date()
        provider.emit(HeartRateSample(bpm: 150, date: now, source: .watch))
        // The ears report a moment later; the wrist still wins precedence, so
        // the state must not flip to AirPods just because it arrived last.
        provider.emit(HeartRateSample(bpm: 100, date: now, source: .airPods))
        for _ in 0..<10 { await Task.yield() }

        #expect(monitor.current?.source == .watch)
        #expect(monitor.state == .live(.watch), "the label followed the last arrival, not the reading")
    }

    // MARK: 3.4 (high) — a queued sample cannot contaminate another workout

    @Test func aSampleTaggedWithAnotherWorkoutIsDropped() {
        let mine = UUID().uuidString
        let theirs = UUID().uuidString
        let message = WatchLink.heartRateMessage(bpm: 140, at: t0, workoutID: theirs)
        let parsed = WatchLink.heartRate(from: message)
        #expect(parsed?.workoutID == theirs)
        #expect(parsed?.workoutID != mine, "the provider filters on exactly this")
    }

    @Test func aSampleWithNoWorkoutIDIsDropped_ratherThanAssumedToBeOurs() {
        let message = WatchLink.heartRateMessage(bpm: 140, at: t0)
        #expect(WatchLink.heartRate(from: message)?.workoutID == nil)
    }

    // MARK: 3.5 (medium) — with everything stale, recency beats precedence

    @Test func whenEverySourceIsStaleTheMostRecentReadingIsShown() {
        let staleWatch = HeartRateSample(bpm: 150, date: t0, source: .watch)
        let lessStaleEars = HeartRateSample(
            bpm: 120, date: t0.addingTimeInterval(240), source: .airPods)
        let chosen = [staleWatch, lessStaleEars].current(asOf: t0.addingTimeInterval(300))
        #expect(chosen?.source == .airPods, "a five-minute-old wrist value is not the better one")
        #expect(chosen?.bpm == 120)
    }

    // MARK: 1.1 (high) — an estimated zone stays marked on the permanent record

    @Test func zonesFromAnEstimatedMaximumAreRecordedAsEstimated() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: t0)
        context.insert(workout)
        let vitals = WorkoutVitalsMath.vitals(
            from: [
                HeartRateSample(bpm: 150, date: t0, source: .watch),
                HeartRateSample(bpm: 150, date: t0.addingTimeInterval(10), source: .watch),
            ],
            zoningAgainst: MaxHeartRate(bpm: 180, isEstimated: true))

        WorkoutSummaryBuilder.capture(
            vitals: vitals, activeEnergyKilocalories: 100,
            zonesEstimated: true, onto: workout)

        #expect(workout.zonesFromEstimatedMax == true)
        #expect(WorkoutSummaryBuilder.summary(for: workout).zonesFromEstimatedMax == true)
    }

    @Test func aWorkoutWithNoZonesRecordsNoEstimationClaimEither() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: t0)
        context.insert(workout)
        let vitals = WorkoutVitalsMath.vitals(
            from: [HeartRateSample(bpm: 150, date: t0, source: .watch)],
            zoningAgainst: nil)
        WorkoutSummaryBuilder.capture(
            vitals: vitals, activeEnergyKilocalories: nil, zonesEstimated: true, onto: workout)
        #expect(workout.zoneSeconds.isEmpty)
        #expect(workout.zonesFromEstimatedMax == nil, "no zones, nothing to qualify")
    }

    // MARK: 1.2 (medium) — calories survive a workout with no heart-rate samples

    @Test func systemCaloriesAreKeptEvenWhenNoHeartRateArrived() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: t0)
        context.insert(workout)

        WorkoutSummaryBuilder.capture(
            vitals: .empty, activeEnergyKilocalories: 282, onto: workout)

        #expect(workout.activeEnergyKilocalories == 282, "the session still burned them")
        #expect(workout.averageHeartRate == nil, "…and still measured no heart rate")
    }

    // MARK: 1.3 (medium) — long workouts are not silently truncated

    @Test func aLongSessionFoldsEverySampleIntoItsAverage() async {
        let provider = StubHeartRateProvider()
        let monitor = HeartRateMonitor(provider: provider)
        await monitor.start()
        let base = Date()
        // More than the old 5,000-sample cap, which used to drop the oldest and
        // then present the tail as a whole-workout average.
        for index in 0..<6_000 {
            provider.emit(HeartRateSample(
                bpm: 100, date: base.addingTimeInterval(Double(index)), source: .fixture))
        }
        // The pump processes roughly one sample per yield, so drain until it
        // settles rather than guessing an iteration count.
        var lastCount = -1
        while monitor.samples.count != lastCount {
            lastCount = monitor.samples.count
            for _ in 0..<2_000 { await Task.yield() }
        }

        #expect(monitor.samples.count == 6_000, "the old cap dropped the oldest 1,000")
        #expect(monitor.vitals.sampleCount == 6_000)
    }

    // MARK: 5.1 (critical) — the backup carries the user's heart-rate config

    @Test func theExportCarriesMaxHeartRateBirthDateAndRestMode() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Press")
        context.insert(exercise)
        let preferences = try AppPreferences.canonical(in: context)
        preferences.measuredMaxHeartRate = 191
        preferences.birthDate = t0
        try RestTimerService(context: context).setOverride(
            for: exercise, warmupSeconds: nil, workingSeconds: nil,
            restMode: .heartRate, heartRateThresholdBpm: 105, heartRateCapSeconds: 200)

        let snapshot = try ExportCollector(appVersion: "test").snapshot(from: context)

        let exported = try #require(snapshot.preferences)
        #expect(exported.measuredMaxHeartRate == 191)
        #expect(exported.birthDate != nil, "the estimation basis must survive a restore")
        let override = try #require(snapshot.exerciseRestOverrides.first)
        #expect(override.restMode == .heartRate)
        #expect(override.heartRateThresholdBpm == 105)
        #expect(override.heartRateCapSeconds == 200)
        // And it still round-trips, so a restore reads back what was written.
        #expect(try ExportJSON.decode(try ExportJSON.data(snapshot)) == snapshot)
    }
}

// MARK: - codex-review-2 #2: who owns the session

@MainActor
struct HeartRateOwnershipTests {

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        return ModelContext(try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }

    /// Minimise dismisses the workout SCREEN while the workout keeps running.
    /// Asking for the monitor again must return the same one, samples intact —
    /// otherwise a minimise/resume cycle silently starts a second session and
    /// the summary describes only the second half of the workout.
    @Test func askingTwiceForOneWorkoutReturnsTheSameSession() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: Date(timeIntervalSince1970: 7_000_000))
        context.insert(workout)
        let coordinator = WorkoutHeartRateCoordinator()

        let first = coordinator.monitor(for: workout, maxHeartRate: nil)
        let second = coordinator.monitor(for: workout, maxHeartRate: nil)

        #expect(first === second, "a minimise/resume cycle must not open a second session")
        #expect(coordinator.workoutID == workout.id)
    }

    /// A different workout means a different session — and the old one must be
    /// let go, not left powering a sensor for a workout nobody is doing.
    @Test func aDifferentWorkoutReplacesTheSession() throws {
        let context = try makeContext()
        let first = Workout(startedAt: Date(timeIntervalSince1970: 7_000_000))
        let second = Workout(startedAt: Date(timeIntervalSince1970: 7_001_000))
        context.insert(first); context.insert(second)
        let coordinator = WorkoutHeartRateCoordinator()

        let firstMonitor = coordinator.monitor(for: first, maxHeartRate: nil)
        let secondMonitor = coordinator.monitor(for: second, maxHeartRate: nil)

        #expect(firstMonitor !== secondMonitor)
        #expect(coordinator.workoutID == second.id)
    }

    /// Ending banks the vitals onto the workout — the step that used to live in
    /// the view and was therefore skipped by every path that did not go through
    /// its Finish button.
    @Test func endingBanksTheVitalsOntoTheWorkout() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: Date(timeIntervalSince1970: 7_000_000))
        context.insert(workout)
        let coordinator = WorkoutHeartRateCoordinator()
        let monitor = coordinator.monitor(for: workout, maxHeartRate: nil)
        // Stand in for what a session would have collected.
        monitor.ingestForTesting(
            HeartRateSample(bpm: 130, date: .now, source: .fixture))

        coordinator.end(workout)

        #expect(workout.averageHeartRate == 130)
        #expect(coordinator.monitor == nil, "the session must not outlive the workout")
        #expect(coordinator.workoutID == nil)
    }

    @Test func endingAWorkoutThatIsNotTheCurrentOneDoesNothing() throws {
        let context = try makeContext()
        let mine = Workout(startedAt: Date(timeIntervalSince1970: 7_000_000))
        let other = Workout(startedAt: Date(timeIntervalSince1970: 7_001_000))
        context.insert(mine); context.insert(other)
        let coordinator = WorkoutHeartRateCoordinator()
        _ = coordinator.monitor(for: mine, maxHeartRate: nil)

        coordinator.end(other)

        #expect(coordinator.workoutID == mine.id, "someone else's finish must not end my session")
    }
}
