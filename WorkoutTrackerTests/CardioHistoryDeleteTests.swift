import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Ticket 20 (the user, 2026-10-18): one recorded cardio activity can be deleted from a past
/// workout; the rest of the workout stays. The workout's only content is not deleted this way —
/// that is Delete Workout, whose confirmation names what goes.
@MainActor
struct CardioHistoryDeleteTests {
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

    private func addCompletedSet(to workout: Workout, in context: ModelContext) {
        let exercise = Exercise(name: "Bench Press", loadType: .weighted)
        context.insert(exercise)
        let entry = ExerciseEntry(order: 0, workout: workout, exercise: exercise, snapshotCapturedAt: at(10),
                                  snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
                                  snapshotExerciseName: exercise.name)
        context.insert(entry)
        let set = SetRecord(order: 0, type: .working, entry: entry)
        set.reps = 8; set.weightValue = 60; set.weightUnit = .kg; set.normalizedKg = 60
        set.completedAt = at(20)
        context.insert(set)
    }

    @Test func deletingTheCardioOfAMixedWorkoutKeepsTheLifting() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        addCompletedSet(to: workout, in: store.context)
        let run = try cardio.start(.indoorRun, in: workout, at: at(60))
        try cardio.end(run, at: at(660))
        #expect(try session.finish(workout, at: at(700)) == .saved)
        #expect(workout.recordedCardio.count == 1)

        #expect(!HistoryEditing.isOnlyContent(run))
        #expect(HistoryEditing.deleteCardio(run, in: store.context, at: at(900)))
        try store.context.save()

        #expect(workout.recordedCardio.isEmpty)
        #expect(workout.completedSets.count == 1)
        #expect(try store.context.fetch(FetchDescriptor<CardioSegment>()).isEmpty, "the segment itself is gone")
        #expect(workout.historyEditedAt == at(900), "an edit to history is marked (D50)")
    }

    @Test func deletingOneOfTwoCardioActivitiesLeavesTheOtherAndItsTime() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        let walk = try cardio.start(.indoorWalk, in: workout, at: start)
        let run = try cardio.start(.indoorRun, in: workout, at: at(300))
        try cardio.end(run, at: at(500))
        #expect(try session.finish(workout, at: at(600)) == .saved)
        #expect(workout.duration == 500, "cardio-only: the active time of both (D64)")

        #expect(HistoryEditing.deleteCardio(walk, in: store.context))
        try store.context.save()

        #expect(workout.recordedCardio.map(\.activity) == [.indoorRun])
        #expect(workout.isCardioOnly)
        #expect(workout.duration == 200, "the workout's time follows what is left")
    }

    @Test func theOnlyContentIsNotDeletedAsCardio() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        let run = try cardio.start(.outdoorRun, in: workout, at: start)
        try cardio.end(run, at: at(600))
        #expect(try session.finish(workout, at: at(600)) == .saved)

        #expect(HistoryEditing.isOnlyContent(run))
        #expect(!HistoryEditing.deleteCardio(run, in: store.context))
        #expect(workout.recordedCardio.count == 1)
        #expect(workout.historyEditedAt == nil)
    }

    @Test func aRunningWorkoutsCardioIsNotHistory() throws {
        let store = try Store()
        let session = WorkoutSession(context: store.context)
        let cardio = CardioSession(context: store.context)
        let workout = try session.startWorkout(at: nil, on: start)
        addCompletedSet(to: workout, in: store.context)
        let run = try cardio.start(.indoorRun, in: workout, at: at(60))
        try cardio.end(run, at: at(300))

        #expect(!HistoryEditing.deleteCardio(run, in: store.context))
        #expect(workout.orderedCardio.count == 1)
    }
}
