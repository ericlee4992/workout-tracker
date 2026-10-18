import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Ticket 17 (D64): a cardio-only workout's time is its cardio's active time — pausing the cardio
/// pauses the workout. A workout with lifting keeps the whole session (a cardio pause is rest).
@MainActor
struct CardioOnlyTimeTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// One container for the whole test (a SwiftData object must not outlive its container).
    private final class Store {
        let container: ModelContainer
        let context: ModelContext
        init() throws {
            let schema = WorkoutTrackerStore.schema
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            context = ModelContext(container)
        }
    }

    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    @Test func cardioOnlyTimeStopsWhileTheCardioIsPaused() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        // Before any cardio: an empty workout, the whole session.
        #expect(!workout.isCardioOnly)
        #expect(workout.trainingSeconds(at: at(20)) == 20)

        let segment = try cardio.start(.indoorRun, in: workout, at: at(30))
        #expect(workout.isCardioOnly)
        #expect(workout.trainingSeconds(at: at(90)) == 60)
        try cardio.pause(segment, at: at(120))
        #expect(workout.trainingSeconds(at: at(400)) == 90)
        try cardio.resume(segment, at: at(400))
        #expect(workout.trainingSeconds(at: at(430)) == 120)

        #expect(try session.finish(workout, at: at(500)) == .saved)
        #expect(workout.isCardioOnly)
        #expect(workout.duration == 190)
        #expect(workout.durationLabel == "3 min")
        #expect(HistoryWorkoutFacts(workout: workout)?.durationSeconds == 190)
        // The tile shows the active time; the heart-rate axis keeps the wall time.
        let summary = WorkoutSummaryBuilder.summary(for: workout)
        #expect(summary.workoutTime == 190)
        #expect(summary.duration == 500)
    }

    @Test func everySegmentCountsAndTimeWithNoCardioRecordingDoesNot() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        _ = try cardio.start(.indoorWalk, in: workout, at: start)
        let run = try cardio.start(.indoorRun, in: workout, at: at(300))
        try cardio.end(run, at: at(500))
        // 300 s walking, 200 s running; the next 100 s nothing records.
        #expect(workout.trainingSeconds(at: at(600)) == 500)
        #expect(try session.finish(workout, at: at(600)) == .saved)
        #expect(workout.duration == 500)
    }

    @Test func addingAnExerciseBringsBackTheWholeSession() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        let segment = try cardio.start(.indoorRun, in: workout, at: start)
        try cardio.pause(segment, at: at(60))
        #expect(workout.trainingSeconds(at: at(300)) == 60)

        let exercise = Exercise(name: "Chest Press")
        store.context.insert(exercise)
        let entry = try session.addEntry(for: exercise, to: workout)
        // No set done yet: the clock is already the whole session.
        #expect(!workout.isCardioOnly)
        #expect(workout.trainingSeconds(at: at(300)) == 300)

        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.commitWeight("40", for: set)
        try session.commitReps("10", for: set)
        try session.toggleCompletion(of: set, at: at(320))
        #expect(try session.finish(workout, at: at(400)) == .saved)
        #expect(!workout.isCardioOnly)
        #expect(workout.duration == 400)
        #expect(WorkoutSummaryBuilder.summary(for: workout).workoutTime == 400)
    }

    @Test func anExerciseWithNoSetDoneFinishesAsCardioOnly() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        let segment = try cardio.start(.indoorRun, in: workout, at: start)
        try cardio.pause(segment, at: at(100))
        let exercise = Exercise(name: "Chest Press")
        store.context.insert(exercise)
        _ = try session.addEntry(for: exercise, to: workout)
        // Finish deletes the set-less entry, so History records the cardio's time.
        #expect(try session.finish(workout, at: at(400)) == .saved)
        #expect(workout.isCardioOnly)
        #expect(workout.duration == 100)
    }

    @Test func liveActivityClockFollowsTheCardioOnlyRule() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        #expect(WorkoutActivityContent.workoutClock(workout, now: at(10)) == nil)

        // One open segment: the cardio clock on the card is the same time.
        let walk = try cardio.start(.indoorWalk, in: workout, at: at(10))
        #expect(WorkoutActivityContent.workoutClock(workout, now: at(40)) == .hidden)
        try cardio.end(walk, at: at(70))
        #expect(WorkoutActivityContent.workoutClock(workout, now: at(100)) == .stopped(seconds: 60))

        // A second segment: the workout's clock runs from a fixed instant (60 s banked).
        let run = try cardio.start(.indoorRun, in: workout, at: at(100))
        let running = WorkoutActivityContent.workoutClock(workout, now: at(130))
        #expect(running == .running(since: at(40)))
        #expect(WorkoutActivityContent.workoutClock(workout, now: at(132)) == running)
        try cardio.pause(run, at: at(160))
        #expect(WorkoutActivityContent.workoutClock(workout, now: at(500)) == .stopped(seconds: 120))
    }
}
