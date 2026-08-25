import Foundation
import SwiftData

// Milestone 8, ticket 03 — editing and deleting logged history.
//
// THE DECISION THIS FILE IMPLEMENTS (D47). D23 froze history so the past could
// not be *silently* rewritten: renaming a machine today must not restate what
// you did in March. Editing history deliberately is a different act, and the
// difference has to be written down or D23 quietly dies:
//
//   1. CORRECTING what you actually did — a typo'd weight, a missed rep — is
//      legitimate. The log should describe reality.
//   2. SNAPSHOTS STAY FROZEN. An edit touches the numbers on a set. It must
//      never re-resolve the entry's exercise/machine/gym snapshot to today's
//      values, because that is the drift D23 exists to prevent.
//   3. EDITS ARE MARKED. A silently altered history claims a certainty it does
//      not have, which is the one thing this app refuses to do.
//
// What breaks if 2 is dropped: correct a weight typo on a March set, and the
// row silently re-labels itself with the machine's *current* name and the
// exercise's *current* load type — so a supported dip corrected today would
// restate every March set as assisted. The user would have no way to see it
// happened.

enum HistoryEditing {

    /// A single set's editable numbers. Deliberately NOT the snapshot fields:
    /// there is no path here that can re-point a row at today's catalog.
    struct SetEdit: Equatable {
        var reps: Int?
        var weightValue: Double?
        var weightUnit: WeightUnit
        var setType: SetType
    }

    /// Applies an edit to one logged set, re-deriving `normalizedKg` from the
    /// pair it belongs to (D25: value and unit and normalization move together
    /// or the record maths silently disagrees with the display).
    ///
    /// Returns false and changes nothing when the result would not be loggable
    /// — an edit must not be able to put a `— × reps` row into history, which
    /// is what A1 exists to prevent.
    @discardableResult
    static func apply(
        _ edit: SetEdit, to set: SetRecord, at date: Date = .now
    ) -> Bool {
        guard !set.isDeleted else { return false }
        let loadType = WorkoutSession.loadType(of: set)
        guard WorkoutSession.isLoggable(
            reps: edit.reps, weightValue: edit.weightValue, loadType: loadType)
        else { return false }

        // VALIDATE through `StoredWeight`, not by trusting a parsed Double.
        //
        // codex-review (critical): the first version asked only whether the
        // value was non-nil, so a pasted negative, NaN or infinite load was
        // accepted, normalized and written into finished history — poisoning
        // records and potentially breaking JSON encoding of the backup.
        // `StoredWeight` is the type that owns "a weight is valid and its
        // normalization is derived atomically" (D25); going around it was the
        // whole bug.
        var stored: StoredWeight?
        if let value = edit.weightValue {
            guard let valid = StoredWeight(value: value, unit: edit.weightUnit) else {
                return false
            }
            stored = valid
        }

        // BAR PROVENANCE (D39): `weightValue` is the TOTAL and `barWeightValue`
        // is what the bar contributed. codex-review (high): editing the total
        // or the unit while leaving the bar fields alone relabels a 45 lb bar
        // as 45 kg and exports its stale normalization, and can leave a total
        // below the bar it supposedly includes. An edit that cannot keep the
        // pair coherent drops the provenance rather than lying about it.
        if let bar = set.barWeightValue {
            let unitChanged = edit.weightUnit != set.weightUnit
            let totalBelowBar = (edit.weightValue ?? 0) < bar
            if unitChanged || totalBelowBar {
                set.barWeightValue = nil
                set.barNormalizedKg = nil
            }
        }

        set.reps = edit.reps
        set.weightValue = stored?.value
        set.weightUnit = edit.weightUnit
        // Value, unit and normalization move together or the record maths
        // silently disagrees with what the row displays (D25).
        set.normalizedKg = stored?.normalizedKg
        set.type = edit.setType
        markEdited(set.entry?.workout, at: date)
        return true
    }

    /// Deletes one logged set. Returns the entry it belonged to, so a caller
    /// can clean up an entry left with nothing in it.
    @discardableResult
    static func deleteSet(
        _ set: SetRecord, in context: ModelContext, at date: Date = .now
    ) -> ExerciseEntry? {
        guard !set.isDeleted else { return nil }
        let entry = set.entry
        let workout = entry?.workout
        context.delete(set)
        markEdited(workout, at: date)
        return entry
    }

    /// True when this entry has no sets left worth keeping.
    ///
    /// Deleting the last set of an exercise must not leave an entry behind:
    /// history would show the exercise with nothing under it, which reads as a
    /// bug and exports as an empty group.
    static func isEmpty(_ entry: ExerciseEntry) -> Bool {
        guard !entry.isDeleted else { return false }
        return (entry.sets ?? []).filter { !$0.isDeleted }.isEmpty
    }

    /// Re-types ONE historical entry, for the case ticket 02 could not reach.
    ///
    /// codex-review (critical): correcting an exercise's load type fixes only
    /// future sets, because frozen entries keep `snapshotLoadType` (D23/D47).
    /// That left sets already logged under a wrong type permanently ranked in
    /// the wrong direction — a supported dip logged as `weighted` stayed
    /// heaviest-wins forever — which was the user's original complaint.
    ///
    /// This is deliberately NARROW, and the narrowness is the decision:
    ///
    /// - It changes ONE entry, chosen by the user on that workout's screen. It
    ///   is not a bulk re-type of every past entry, because a bulk operation
    ///   over history is the thing D23 exists to prevent.
    /// - It changes ONLY the load type. Exercise identity, machine, gym and
    ///   name stay frozen: re-pointing a row at a different exercise would
    ///   split or merge records silently (D36).
    /// - It marks the workout as edited, like every other correction.
    ///
    /// The set's stored numbers are untouched — what changes is how they are
    /// RANKED. An assisted 30 kg was always 30 kg of assistance; it was only
    /// ever the interpretation that was wrong.
    @discardableResult
    static func retype(
        _ entry: ExerciseEntry, to loadType: LoadType, at date: Date = .now
    ) -> Bool {
        guard !entry.isDeleted, entry.snapshotLoadType != loadType else { return false }
        // Refuse a re-type that would strand sets the new type cannot express:
        // a weighted set with no weight cannot become... it can, but a set with
        // no reps is not loggable under any type, and re-typing must not create
        // a row the store would refuse (A1).
        let sets = (entry.sets ?? []).filter { !$0.isDeleted && $0.completedAt != nil }
        for set in sets {
            guard WorkoutSession.isLoggable(
                reps: set.reps, weightValue: set.weightValue, loadType: loadType)
            else { return false }
        }
        entry.snapshotLoadType = loadType
        markEdited(entry.workout, at: date)
        return true
    }

    /// Removes an entry that has been emptied by deletions.
    static func pruneIfEmpty(_ entry: ExerciseEntry, in context: ModelContext) {
        guard isEmpty(entry) else { return }
        context.delete(entry)
    }

    /// What a whole-workout deletion destroys, so the confirmation can name it
    /// rather than asking "are you sure?" about an unknown quantity. This is
    /// the user's only copy of their training history.
    struct DeletionImpact: Equatable {
        var exercises: Int
        var sets: Int
        var volumeKg: Double
    }

    static func impact(ofDeleting workout: Workout) -> DeletionImpact {
        guard !workout.isDeleted else { return DeletionImpact(exercises: 0, sets: 0, volumeKg: 0) }
        let entries = (workout.entries ?? []).filter { !$0.isDeleted }
        var sets = 0
        var inputs: [RecordSetInput] = []
        for entry in entries {
            for set in (entry.sets ?? []) where !set.isDeleted && set.completedAt != nil {
                sets += 1
                inputs.append(RecordSetInput(
                    loadType: entry.snapshotLoadType,
                    exerciseID: entry.snapshotExerciseID,
                    gymID: entry.snapshotGymID,
                    machineID: entry.snapshotMachineID,
                    modelID: entry.snapshotModelID,
                    freeWeightTag: entry.snapshotFreeWeightTag,
                    presetID: entry.snapshotPresetID,
                    setType: set.type, reps: set.reps,
                    weightValue: set.weightValue, weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg, completedAt: set.completedAt))
            }
        }
        // `RecordsMath.totalVolumeKg`, NOT a second implementation.
        // codex-review (high): the first version summed every load type, so an
        // assisted set's ASSISTANCE counted as volume — the number quoted to
        // the user would have been larger than the volume they actually lose,
        // and would disagree with every other volume figure in the app.
        return DeletionImpact(
            exercises: entries.count, sets: sets,
            volumeKg: RecordsMath.totalVolumeKg(among: inputs))
    }

    /// Stamps the workout as edited. Every mutating path above routes through
    /// this — an unmarked edit is the dishonest case.
    private static func markEdited(_ workout: Workout?, at date: Date) {
        guard let workout, !workout.isDeleted else { return }
        workout.historyEditedAt = date
    }
}
