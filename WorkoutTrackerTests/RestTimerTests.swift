import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

struct RestTimerTests {
    private final class FakeClock: RestClock {
        var now: Date
        init(now: Date) { self.now = now }
    }

    private final class FakeNotifications: RestNotificationScheduling {
        var authorizationRequests = 0
        var scheduledDates: [Date] = []
        var cancellations = 0
        func requestAuthorization() { authorizationRequests += 1 }
        func schedule(at date: Date) { scheduledDates.append(date) }
        func cancel() { cancellations += 1 }
    }

    private struct Rig {
        let context: ModelContext
        let workout: Workout
        let exercise: Exercise
        let entry: ExerciseEntry
        let warmup: SetRecord
        let working: SetRecord
        let failure: SetRecord
    }

    private func makeRig(context: ModelContext) throws -> Rig {
        let exercise = Exercise(name: "Chest Press")
        let workout = Workout(startedAt: Date(timeIntervalSince1970: 1))
        context.insert(exercise)
        context.insert(workout)
        let entry = ExerciseEntry(
            order: 0, workout: workout, exercise: exercise,
            snapshotExerciseID: exercise.id,
            snapshotLoadType: .weighted,
            snapshotExerciseName: exercise.name)
        context.insert(entry)
        let warmup = SetRecord(order: 0, type: .warmup, entry: entry)
        let working = SetRecord(order: 1, type: .working, entry: entry)
        let failure = SetRecord(order: 2, type: .failure, entry: entry)
        context.insert(warmup)
        context.insert(working)
        context.insert(failure)
        try context.save()
        return Rig(
            context: context, workout: workout, exercise: exercise, entry: entry,
            warmup: warmup, working: working, failure: failure)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    @Test func durationPrecedenceAndFailureUsesWorking() throws {
        let rig = try makeRig(context: makeInMemoryContext())
        let clock = FakeClock(now: Date(timeIntervalSince1970: 100))
        let notifications = FakeNotifications()
        let timer = RestTimerService(
            context: rig.context, clock: clock, notifications: notifications)
        let preferences = try AppPreferences.canonical(in: rig.context)
        preferences.globalWarmupRestSeconds = 60
        preferences.globalWorkingRestSeconds = 120
        try rig.context.save()

        #expect(try timer.durationSeconds(for: rig.warmup) == 60)
        #expect(try timer.durationSeconds(for: rig.working) == 120)
        #expect(try timer.durationSeconds(for: rig.failure) == 120)

        try timer.setOverride(
            for: rig.exercise, warmupSeconds: 45, workingSeconds: 90)
        #expect(try timer.durationSeconds(for: rig.warmup) == 45)
        #expect(try timer.durationSeconds(for: rig.working) == 90)
        #expect(try timer.durationSeconds(for: rig.failure) == 90)
    }

    @Test func completionReplaceAddAndSkipRescheduleOneTimer() throws {
        let rig = try makeRig(context: makeInMemoryContext())
        let clock = FakeClock(now: Date(timeIntervalSince1970: 100))
        let notifications = FakeNotifications()
        let timer = RestTimerService(
            context: rig.context, clock: clock, notifications: notifications)

        rig.warmup.completedAt = clock.now
        let firstState = try timer.handleCompletionChange(
            of: rig.warmup, isCompleted: true)
        let first = try #require(firstState)
        #expect(first.end == Date(timeIntervalSince1970: 160))
        #expect(notifications.authorizationRequests == 1)
        #expect(notifications.scheduledDates == [first.end])

        clock.now = Date(timeIntervalSince1970: 110)
        rig.working.completedAt = clock.now
        let replacedState = try timer.handleCompletionChange(
            of: rig.working, isCompleted: true)
        let replaced = try #require(replacedState)
        #expect(replaced.end == Date(timeIntervalSince1970: 230))
        #expect(rig.workout.restStartedBySetID == rig.working.id)
        #expect(notifications.authorizationRequests == 1)

        let extendedState = try timer.add(seconds: 15, to: rig.workout)
        let extended = try #require(extendedState)
        #expect(extended.end == Date(timeIntervalSince1970: 245))
        #expect(notifications.scheduledDates.last == extended.end)

        try timer.skip(rig.workout)
        #expect(rig.workout.restEndsAt == nil)
        #expect(rig.workout.restStartedBySetID == nil)
        #expect(notifications.cancellations == 1)
    }

    @Test func uncompletionOnlyCancelsTimerStartedByThatSet() throws {
        let rig = try makeRig(context: makeInMemoryContext())
        let clock = FakeClock(now: Date(timeIntervalSince1970: 100))
        let notifications = FakeNotifications()
        let timer = RestTimerService(
            context: rig.context, clock: clock, notifications: notifications)
        rig.working.completedAt = clock.now
        try timer.handleCompletionChange(of: rig.working, isCompleted: true)

        // Un-completing a different set neither starts nor cancels.
        try timer.handleCompletionChange(of: rig.warmup, isCompleted: false)
        #expect(rig.workout.restEndsAt != nil)
        #expect(notifications.cancellations == 0)

        rig.working.completedAt = nil
        try timer.handleCompletionChange(of: rig.working, isCompleted: false)
        #expect(rig.workout.restEndsAt == nil)
        #expect(notifications.cancellations == 1)
        #expect(notifications.scheduledDates.count == 1)
    }

    @Test func relaunchMidRestReconstructsFromAbsoluteEnd() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rest-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")
        var workoutID = UUID()

        do {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let rig = try makeRig(context: context)
            workoutID = rig.workout.id
            let clock = FakeClock(now: Date(timeIntervalSince1970: 100))
            rig.working.completedAt = clock.now
            try RestTimerService(
                context: context, clock: clock, notifications: FakeNotifications())
                .handleCompletionChange(of: rig.working, isCompleted: true)
        }

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let id = workoutID
        let workouts = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.id == id }))
        let workout = try #require(workouts.first)
        let clock = FakeClock(now: Date(timeIntervalSince1970: 150))
        let restored = try RestTimerService(
            context: context, clock: clock, notifications: FakeNotifications())
            .currentState(for: workout)
        let state = try #require(restored)
        #expect(state.end == Date(timeIntervalSince1970: 220))
        #expect(state.remaining == 70)
    }

    @Test func returningAfterTimerEndClearsStalePersistenceAndNotification() throws {
        let rig = try makeRig(context: makeInMemoryContext())
        let clock = FakeClock(now: Date(timeIntervalSince1970: 100))
        let notifications = FakeNotifications()
        let timer = RestTimerService(
            context: rig.context, clock: clock, notifications: notifications)
        rig.working.completedAt = clock.now
        try timer.handleCompletionChange(of: rig.working, isCompleted: true)
        clock.now = Date(timeIntervalSince1970: 221)

        #expect(try timer.currentState(for: rig.workout) == nil)
        #expect(rig.workout.restEndsAt == nil)
        #expect(rig.workout.restStartedBySetID == nil)
        #expect(notifications.cancellations == 1)
    }
}
