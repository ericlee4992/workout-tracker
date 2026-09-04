import Foundation
import SwiftData

// Milestone 9, ticket 04 — the one-time move of dumbbell-tagged history onto
// the dumbbell exercises catalog version 5 introduced.
//
// This is a MIGRATION, not an edit, and it says so plainly: D23 forbids
// reinterpreting a snapshot silently, so the move is (1) keyed on the catalog
// version bump and run once, (2) idempotent by construction — a moved entry
// points at an exercise that has no counterpart, so a second pass finds
// nothing — (3) narrow: only FINISHED workouts, only entries whose frozen
// snapshot says Dumbbell, only movements in `DumbbellCounterparts`, and
// (4) recorded on `AppPreferences` and shown in Settings, so it is visible.
//
// What it rewrites: the `exercise` relationship AND the snapshot identity
// (`snapshotExerciseID`, `snapshotExerciseName`), because history reads the
// snapshot (D23) — rewriting only the relationship would leave records, the
// chart and prefill still filing these sets under "Bench Press". What it
// leaves alone: every number, the tag, the preset and its snapshot (D37 —
// a grip travels with the movement), machine/gym/model snapshots (nil for a
// free-weight set anyway), and `historyEditedAt` — the user did not edit this.

enum DumbbellHistoryMove {

    struct Outcome: Equatable {
        var entries: Int
        var sets: Int
    }

    /// Moves every qualifying entry. Returns how many entries and completed
    /// sets moved; zero when there was nothing to do.
    @discardableResult
    static func run(in context: ModelContext) throws -> Outcome {
        let targetIDs = Set(DumbbellCounterparts.pairs.map(\.target))
        let exercises = try context.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { targetIDs.contains($0.id) }))
        let targetByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        // Small table on this app's scale; the enum-typed tag is not a
        // predicate-friendly field, so filter in Swift.
        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>())
        var outcome = Outcome(entries: 0, sets: 0)
        for entry in entries {
            guard !entry.isDeleted,
                  let workout = entry.workout, !workout.isDeleted, workout.finishedAt != nil,
                  entry.snapshotCapturedAt != nil,
                  entry.snapshotFreeWeightTag == .dumbbell,
                  let targetID = DumbbellCounterparts.counterpart(of: entry.snapshotExerciseID),
                  let target = targetByID[targetID]
            else { continue }
            entry.exercise = target
            entry.snapshotExerciseID = target.id
            entry.snapshotExerciseName = target.name
            outcome.entries += 1
            outcome.sets += (entry.sets ?? []).filter { !$0.isDeleted && $0.completedAt != nil }.count
        }
        return outcome
    }
}
