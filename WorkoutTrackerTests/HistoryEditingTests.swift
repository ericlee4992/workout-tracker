import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Milestone 8, ticket 03 — editing and deleting logged history (D47).
///
/// This is the highest-risk surface in the milestone: it mutates the user's
/// only copy of their training history. The tests that matter most are not the
/// ones proving an edit works — they are the ones proving an edit does NOT
/// reach further than it should.
@MainActor
struct HistoryEditingTests {

    private struct Rig {
        let context: ModelContext
        let workout: Workout
        let exercise: Exercise
        let entry: ExerciseEntry
        let set: SetRecord
    }

    private func makeRig(
        loadType: LoadType = .weighted,
        exerciseName: String = "Bench Press",
        machineLabel: String? = "Bench 1"
    ) throws -> Rig {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let exercise = Exercise(name: exerciseName, loadType: loadType)
        context.insert(exercise)
        let workout = Workout()
        workout.finishedAt = .now
        context.insert(workout)
        let entry = ExerciseEntry(
            order: 0, workout: workout, exercise: exercise,
            snapshotCapturedAt: .now,
            snapshotExerciseID: exercise.id, snapshotLoadType: loadType,
            snapshotExerciseName: exerciseName,
            snapshotMachineLabel: machineLabel)
        context.insert(entry)
        let set = SetRecord(order: 0, type: .working, entry: entry)
        set.reps = 8
        set.weightValue = 60
        set.weightUnit = .kg
        set.normalizedKg = 60
        set.completedAt = .now
        context.insert(set)
        try context.save()
        return Rig(
            context: context, workout: workout, exercise: exercise,
            entry: entry, set: set)
    }

    // MARK: - The edits themselves

    @Test func correctingAWeightUpdatesTheStoredValueAndItsNormalization() throws {
        let rig = try makeRig()
        let ok = HistoryEditing.apply(
            .init(reps: 8, weightValue: 65, weightUnit: .kg, setType: .working),
            to: rig.set)
        #expect(ok)
        #expect(rig.set.weightValue == 65)
        #expect(rig.set.normalizedKg == 65)
    }

    /// D25: value, unit and normalization move together, or the record maths
    /// silently disagrees with what the row displays.
    @Test func changingTheUnitRenormalizes() throws {
        let rig = try makeRig()
        HistoryEditing.apply(
            .init(reps: 8, weightValue: 135, weightUnit: .lb, setType: .working),
            to: rig.set)
        #expect(rig.set.weightUnit == .lb)
        let kg = try #require(rig.set.normalizedKg)
        #expect(abs(kg - 61.23) < 0.01, "135 lb should normalize to ~61.23 kg, got \(kg)")
    }

    /// A1: an edit must not be able to put a `— × reps` row into history.
    @Test func anEditThatWouldNotBeLoggableIsRefusedAndChangesNothing() throws {
        let rig = try makeRig()
        let ok = HistoryEditing.apply(
            .init(reps: 8, weightValue: nil, weightUnit: .kg, setType: .working),
            to: rig.set)
        #expect(!ok)
        #expect(rig.set.weightValue == 60, "a refused edit must not partially apply")
        #expect(rig.workout.historyEditedAt == nil, "a refused edit must not mark the workout")
    }

    @Test func aBodyweightSetCanBeCorrectedWithNoWeightAtAll() throws {
        let rig = try makeRig(loadType: .bodyweight, exerciseName: "Push-Up")
        let ok = HistoryEditing.apply(
            .init(reps: 20, weightValue: nil, weightUnit: .kg, setType: .working),
            to: rig.set)
        #expect(ok, "a bodyweight movement needs reps alone")
        #expect(rig.set.reps == 20)
    }

    // MARK: - The D23 boundary, which is the point of the whole ticket

    /// THE REGRESSION A PAST REVIEW ALREADY CAUGHT ONCE, in a different form.
    ///
    /// Editing a set must not re-resolve the entry's snapshot. If it did,
    /// correcting a weight typo on a March set would silently re-label that row
    /// with the machine's CURRENT name and the exercise's CURRENT load type —
    /// exactly the drift D23 exists to prevent, and invisible to the user.
    @Test func editingASetDoesNotRestateWhatEquipmentItWasLoggedOn() throws {
        let rig = try makeRig(exerciseName: "Chest Press", machineLabel: "Bench 1")

        // The world moves on: the exercise is renamed and re-typed.
        rig.exercise.name = "Incline Chest Press"
        rig.exercise.loadType = .assisted
        try rig.context.save()

        HistoryEditing.apply(
            .init(reps: 10, weightValue: 70, weightUnit: .kg, setType: .working),
            to: rig.set)

        #expect(
            rig.entry.snapshotExerciseName == "Chest Press",
            "the history row renamed itself to today's exercise name")
        #expect(
            rig.entry.snapshotLoadType == .weighted,
            "the history row re-typed itself — every past set just changed how it is ranked")
        #expect(rig.entry.snapshotMachineLabel == "Bench 1")
    }

    // MARK: - Marking

    @Test func anEditMarksTheWorkoutAsEdited() throws {
        let rig = try makeRig()
        #expect(rig.workout.historyEditedAt == nil, "unedited to begin with")
        HistoryEditing.apply(
            .init(reps: 9, weightValue: 60, weightUnit: .kg, setType: .working),
            to: rig.set)
        #expect(
            rig.workout.historyEditedAt != nil,
            "a silently altered history claims a certainty the app does not have")
    }

    @Test func deletingASetAlsoMarksTheWorkout() throws {
        let rig = try makeRig()
        HistoryEditing.deleteSet(rig.set, in: rig.context)
        #expect(rig.workout.historyEditedAt != nil)
    }

    // MARK: - Deletion

    @Test func deletingTheLastSetLeavesNoOrphanEntry() throws {
        let rig = try makeRig()
        let entry = try #require(HistoryEditing.deleteSet(rig.set, in: rig.context))
        #expect(HistoryEditing.isEmpty(entry), "the entry has nothing left in it")
        HistoryEditing.pruneIfEmpty(entry, in: rig.context)
        try rig.context.save()

        let entries = try rig.context.fetch(FetchDescriptor<ExerciseEntry>())
        #expect(entries.isEmpty, "an exercise with no sets under it reads as a bug in history")
    }

    /// The confirmation names what is lost, so it is not asking "are you sure?"
    /// about an unknown quantity. This phone holds the only copy.
    @Test func deletionImpactCountsWhatWillActuallyBeLost() throws {
        let rig = try makeRig()
        let warmup = SetRecord(order: 1, type: .warmup, entry: rig.entry)
        warmup.reps = 10
        warmup.weightValue = 20
        warmup.weightUnit = .kg
        warmup.normalizedKg = 20
        warmup.completedAt = .now
        rig.context.insert(warmup)
        try rig.context.save()

        let impact = HistoryEditing.impact(ofDeleting: rig.workout)
        #expect(impact.exercises == 1)
        #expect(impact.sets == 2, "both sets are lost, warmup included")
        // Volume excludes warmups, matching RecordsMath — quoting a different
        // number here would make the confirmation lie about what is lost.
        #expect(impact.volumeKg == 480, "8 × 60 kg working only, got \(impact.volumeKg)")
    }

    @Test func deletingAWorkoutRemovesItsSetsFromTheStore() throws {
        let rig = try makeRig()
        rig.context.delete(rig.workout)
        try rig.context.save()
        #expect(try rig.context.fetch(FetchDescriptor<SetRecord>()).isEmpty)
        #expect(try rig.context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
    }
}
