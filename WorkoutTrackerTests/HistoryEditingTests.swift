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

/// Regressions for the Codex cross-review of milestone 8 tickets 02 and 03.
/// Every test here failed against the reviewed implementation.
@MainActor
struct HistoryEditingReviewRegressionTests {

    private func makeRig() throws -> (ModelContext, Workout, SetRecord) {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let exercise = Exercise(name: "Bench Press", loadType: .weighted)
        context.insert(exercise)
        let workout = Workout()
        workout.finishedAt = .now
        context.insert(workout)
        let entry = ExerciseEntry(
            order: 0, workout: workout, exercise: exercise, snapshotCapturedAt: .now,
            snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
            snapshotExerciseName: "Bench Press")
        context.insert(entry)
        let set = SetRecord(order: 0, type: .working, entry: entry)
        set.reps = 8
        set.weightValue = 60
        set.weightUnit = .kg
        set.normalizedKg = 60
        set.completedAt = .now
        context.insert(set)
        try context.save()
        return (context, workout, set)
    }

    /// codex-review Spec/critical: `apply` asked only whether the weight was
    /// non-nil, so a pasted negative, NaN or infinite load was accepted,
    /// normalized and written into finished history — poisoning records and
    /// potentially breaking JSON encoding of the only backup.
    @Test func invalidWeightsCannotBeWrittenIntoHistory() throws {
        let (_, workout, set) = try makeRig()
        for bad in [-50.0, Double.nan, Double.infinity, -0.001] {
            let ok = HistoryEditing.apply(
                .init(reps: 8, weightValue: bad, weightUnit: .kg, setType: .working),
                to: set)
            #expect(!ok, "\(bad) was accepted into history")
        }
        #expect(set.weightValue == 60, "a refused edit must not partially apply")
        #expect(workout.historyEditedAt == nil, "a refused edit must not mark the workout")
    }

    /// codex-review Standards/high: editing a bar-mode set's unit relabelled a
    /// 45 lb bar as 45 kg while keeping its old normalization, and a total
    /// could be edited below the bar it supposedly includes. D39's invariant is
    /// that `weightValue` is the TOTAL and `barWeightValue` is provenance.
    @Test func aUnitChangeDropsBarProvenanceRatherThanMislabellingIt() throws {
        let (_, _, set) = try makeRig()
        set.weightValue = 135
        set.weightUnit = .lb
        set.normalizedKg = 61.23
        set.barWeightValue = 45
        set.barNormalizedKg = 20.41

        HistoryEditing.apply(
            .init(reps: 5, weightValue: 61, weightUnit: .kg, setType: .working), to: set)

        #expect(
            set.barWeightValue == nil && set.barNormalizedKg == nil,
            "a 45 lb bar must not silently become a 45 kg bar")
    }

    @Test func aTotalBelowTheBarDropsProvenance() throws {
        let (_, _, set) = try makeRig()
        set.weightValue = 135
        set.weightUnit = .lb
        set.normalizedKg = 61.23
        set.barWeightValue = 45
        set.barNormalizedKg = 20.41

        HistoryEditing.apply(
            .init(reps: 5, weightValue: 30, weightUnit: .lb, setType: .working), to: set)

        #expect(
            set.barWeightValue == nil,
            "a 30 lb total cannot contain a 45 lb bar; keeping the provenance would be a lie")
    }

    @Test func aCoherentBarEditKeepsItsProvenance() throws {
        let (_, _, set) = try makeRig()
        set.weightValue = 135
        set.weightUnit = .lb
        set.normalizedKg = 61.23
        set.barWeightValue = 45
        set.barNormalizedKg = 20.41

        HistoryEditing.apply(
            .init(reps: 5, weightValue: 145, weightUnit: .lb, setType: .working), to: set)

        #expect(set.barWeightValue == 45, "same unit, total still above the bar — provenance stands")
    }

    /// codex-review Standards/high: the deletion impact summed EVERY load type,
    /// so an assisted set's assistance counted as volume — a number larger than
    /// what is actually lost, disagreeing with every other volume in the app.
    @Test func deletionVolumeUsesTheSharedRuleNotASecondImplementation() throws {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let exercise = Exercise(name: "Assisted Pull-Up", loadType: .assisted)
        context.insert(exercise)
        let workout = Workout()
        workout.finishedAt = .now
        context.insert(workout)
        let entry = ExerciseEntry(
            order: 0, workout: workout, exercise: exercise, snapshotCapturedAt: .now,
            snapshotExerciseID: exercise.id, snapshotLoadType: .assisted,
            snapshotExerciseName: "Assisted Pull-Up")
        context.insert(entry)
        let set = SetRecord(order: 0, type: .working, entry: entry)
        set.reps = 8
        set.weightValue = 30
        set.weightUnit = .kg
        set.normalizedKg = 30
        set.completedAt = .now
        context.insert(set)
        try context.save()

        let impact = HistoryEditing.impact(ofDeleting: workout)
        #expect(impact.sets == 1)
        #expect(
            impact.volumeKg == 0,
            "assistance is not volume lifted — got \(impact.volumeKg)")
    }
}

/// The critical Spec finding: neither ticket could repair a set already logged
/// under the wrong load type. `HistoryEditing.retype` closes it.
@MainActor
struct HistoricalRetypeTests {

    private func makeRig(loadType: LoadType) throws -> (ModelContext, Workout, ExerciseEntry) {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let exercise = Exercise(name: "Seated Dip", loadType: loadType)
        context.insert(exercise)
        let workout = Workout()
        workout.finishedAt = .now
        context.insert(workout)
        let entry = ExerciseEntry(
            order: 0, workout: workout, exercise: exercise, snapshotCapturedAt: .now,
            snapshotExerciseID: exercise.id, snapshotLoadType: loadType,
            snapshotExerciseName: "Seated Dip")
        context.insert(entry)
        let set = SetRecord(order: 0, type: .working, entry: entry)
        set.reps = 8
        set.weightValue = 30
        set.weightUnit = .kg
        set.normalizedKg = 30
        set.completedAt = .now
        context.insert(set)
        try context.save()
        return (context, workout, entry)
    }

    /// The user's actual complaint, on data already logged.
    @Test func aHistoricalEntryCanBeRetypedFromWeightedToAssisted() throws {
        let (_, workout, entry) = try makeRig(loadType: .weighted)
        #expect(HistoryEditing.retype(entry, to: .assisted))
        #expect(entry.snapshotLoadType == .assisted)
        #expect(workout.historyEditedAt != nil, "a re-type is an edit and must be marked")
    }

    /// The stored numbers are untouched — only their interpretation changes.
    @Test func retypingDoesNotTouchTheStoredNumbers() throws {
        let (_, _, entry) = try makeRig(loadType: .weighted)
        HistoryEditing.retype(entry, to: .assisted)
        let set = try #require((entry.sets ?? []).first)
        #expect(set.weightValue == 30)
        #expect(set.normalizedKg == 30)
        #expect(set.reps == 8)
    }

    /// Identity stays frozen. Re-pointing a row at a different exercise would
    /// split or merge records silently (D36) — the re-type is narrower than
    /// that on purpose.
    @Test func retypingDoesNotRepointTheEntryAtADifferentExercise() throws {
        let (_, _, entry) = try makeRig(loadType: .weighted)
        let originalID = entry.snapshotExerciseID
        let originalName = entry.snapshotExerciseName
        HistoryEditing.retype(entry, to: .bodyweight)
        #expect(entry.snapshotExerciseID == originalID)
        #expect(entry.snapshotExerciseName == originalName)
    }

    @Test func retypingToTheSameTypeIsANoOp() throws {
        let (_, workout, entry) = try makeRig(loadType: .assisted)
        #expect(!HistoryEditing.retype(entry, to: .assisted))
        #expect(workout.historyEditedAt == nil, "nothing changed, so nothing to mark")
    }

    /// A1: a re-type must not create a row the store would refuse.
    @Test func aRetypeThatWouldStrandASetIsRefused() throws {
        let (context, _, entry) = try makeRig(loadType: .bodyweight)
        // A bodyweight set logged with reps only cannot become `weighted`.
        let set = try #require((entry.sets ?? []).first)
        set.weightValue = nil
        set.normalizedKg = nil
        try context.save()
        #expect(
            !HistoryEditing.retype(entry, to: .weighted),
            "a weighted set with no weight is exactly the `— × reps` row A1 forbids")
        #expect(entry.snapshotLoadType == .bodyweight, "a refused re-type must not partially apply")
    }
}
