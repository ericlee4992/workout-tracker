import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Gym feedback, 2026-08-29: reorder exercises during a workout, and add or
/// remove whole exercises when editing history.
@MainActor
struct ReorderAndHistoryStructureTests {

    private struct Rig {
        let context: ModelContext
        let workout: Workout
        let entries: [ExerciseEntry]
    }

    private func makeRig(count: Int, finished: Bool = false) throws -> Rig {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let workout = Workout()
        if finished { workout.finishedAt = .now }
        context.insert(workout)
        var entries: [ExerciseEntry] = []
        for index in 0..<count {
            let exercise = Exercise(name: "Exercise \(index)", loadType: .weighted)
            context.insert(exercise)
            let entry = ExerciseEntry(
                order: index, workout: workout, exercise: exercise,
                snapshotCapturedAt: finished ? .now : nil,
                snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
                snapshotExerciseName: exercise.name)
            context.insert(entry)
            let set = SetRecord(order: 0, type: .working, entry: entry)
            set.reps = 8
            set.weightValue = 60
            set.weightUnit = .kg
            set.normalizedKg = 60
            if finished { set.completedAt = .now }
            context.insert(set)
            entries.append(entry)
        }
        try context.save()
        return Rig(context: context, workout: workout, entries: entries)
    }

    private func names(_ workout: Workout) -> [String] {
        WorkoutSession.orderedEntries(of: workout)
            .filter { !$0.isDeleted }
            .map(\.snapshotExerciseName)
    }

    // MARK: - Reordering during a workout

    /// `WorkoutSession.moveEntry` existed with NO CALLER until now — the sixth
    /// time this repo has carried a function nothing invoked.
    @Test func anExerciseCanBeMovedUp() throws {
        let rig = try makeRig(count: 3)
        try WorkoutSession(context: rig.context).moveEntry(rig.entries[2], toIndex: 1)
        #expect(names(rig.workout) == ["Exercise 0", "Exercise 2", "Exercise 1"])
    }

    @Test func anExerciseCanBeMovedDown() throws {
        let rig = try makeRig(count: 3)
        try WorkoutSession(context: rig.context).moveEntry(rig.entries[0], toIndex: 1)
        #expect(names(rig.workout) == ["Exercise 1", "Exercise 0", "Exercise 2"])
    }

    @Test func orderIsContiguousAfterAMove() throws {
        let rig = try makeRig(count: 4)
        try WorkoutSession(context: rig.context).moveEntry(rig.entries[3], toIndex: 0)
        let orders = WorkoutSession.orderedEntries(of: rig.workout).map(\.order)
        #expect(orders == [0, 1, 2, 3], "gaps in order break later moves, got \(orders)")
    }

    /// D48 groups by ADJACENCY, so moving a third exercise between two members
    /// splits the superset. The group ids must not survive that, or a badge
    /// would sit on exercises that are no longer supersetted.
    @Test func movingAnExerciseBetweenSupersetMembersBreaksTheGroup() throws {
        let rig = try makeRig(count: 3)
        Supersets.group([rig.entries[0], rig.entries[1]])
        try rig.context.save()

        // C moves between A and B.
        try WorkoutSession(context: rig.context).moveEntry(rig.entries[2], toIndex: 1)
        Supersets.pruneOrphanGroups(in: rig.workout)
        try rig.context.save()

        #expect(Supersets.runs(of: rig.workout).allSatisfy { $0.count == 1 })
        for entry in rig.entries {
            #expect(
                entry.supersetGroupID == nil,
                "a split superset must not leave stale group ids behind")
        }
    }

    // MARK: - Adding an exercise to a past session

    @Test func anExerciseCanBeAddedToAFinishedWorkout() throws {
        let rig = try makeRig(count: 1, finished: true)
        let exercise = Exercise(name: "Forgotten Curl", loadType: .weighted)
        rig.context.insert(exercise)

        let pair = try #require(HistoryEditing.addEntry(
            for: exercise, to: rig.workout, in: rig.context))
        try rig.context.save()

        #expect(names(rig.workout).contains("Forgotten Curl"))
        #expect(pair.entry.snapshotCapturedAt != nil, "a history entry is frozen from the start")
        #expect(rig.workout.historyEditedAt != nil, "adding to history is an edit and must be marked")
    }

    /// The app does not know which machine was used weeks ago, and inventing
    /// one would be the fabricated context D23 exists to prevent.
    @Test func anAddedExerciseCarriesNoInventedEquipment() throws {
        let rig = try makeRig(count: 1, finished: true)
        let exercise = Exercise(name: "Forgotten Curl", loadType: .weighted)
        rig.context.insert(exercise)

        let pair = try #require(HistoryEditing.addEntry(
            for: exercise, to: rig.workout, in: rig.context))
        #expect(pair.entry.snapshotMachineID == nil)
        #expect(pair.entry.snapshotMachineLabel == nil)
        #expect(pair.entry.snapshotModelID == nil)
    }

    /// The added set starts with no values, so it must not be loggable until
    /// the user supplies them — otherwise an abandoned addition would sit in
    /// history as `— × —`.
    @Test func anAddedSetIsNotLoggableUntilItHasValues() throws {
        let rig = try makeRig(count: 1, finished: true)
        let exercise = Exercise(name: "Forgotten Curl", loadType: .weighted)
        rig.context.insert(exercise)

        let pair = try #require(HistoryEditing.addEntry(
            for: exercise, to: rig.workout, in: rig.context))
        #expect(
            !WorkoutSession.isLoggable(pair.set),
            "the view relies on this to discard an abandoned addition")

        // Filling it in makes it real.
        #expect(HistoryEditing.apply(
            .init(reps: 12, weightValue: 20, weightUnit: .kg, setType: .working),
            to: pair.set))
        #expect(WorkoutSession.isLoggable(pair.set))
    }

    // MARK: - Removing an exercise from a past session

    @Test func removingAnExerciseTakesItsSetsWithIt() throws {
        let rig = try makeRig(count: 2, finished: true)
        #expect(HistoryEditing.deleteEntry(rig.entries[0], in: rig.context))
        try rig.context.save()

        #expect(names(rig.workout) == ["Exercise 1"])
        let sets = try rig.context.fetch(FetchDescriptor<SetRecord>())
        #expect(sets.count == 1, "the removed exercise's sets must go with it")
        #expect(rig.workout.historyEditedAt != nil)
    }

    @Test func removingASupersetMemberRepairsTheGroup() throws {
        let rig = try makeRig(count: 2, finished: true)
        Supersets.group(rig.entries)
        try rig.context.save()

        HistoryEditing.deleteEntry(rig.entries[1], in: rig.context)
        try rig.context.save()

        #expect(
            rig.entries[0].supersetGroupID == nil,
            "a superset left with one member is not a superset")
    }
}
