import Foundation
import SwiftData

// Milestone 9, ticket 04 — the reclassification of dumbbell-tagged history
// onto the dumbbell exercises catalog version 5 introduced. D51 is the
// decision; read it before touching this.
//
// This rewrites frozen snapshots, which D19/D23/D47 otherwise forbid. D51
// permits exactly this, on these terms, all of which are enforced here:
//
// 1. CATALOG-DRIVEN, NOT A USER EDIT. The identity was never wrong in the
//    user's terms — they did a dumbbell bench and said so with the tag; the
//    catalog had no row for it. So `historyEditedAt` is NOT set. The row
//    carries its own provenance instead: `reclassifiedAt` and
//    `reclassifiedFromExerciseName`, both exported, both shown in History.
// 2. NARROW. Only finished workouts, only frozen snapshots whose tag says
//    Dumbbell, only movements in `DumbbellCounterparts`. Numbers, tag,
//    machine/gym snapshots, superset membership, `historyEditedAt`: untouched.
// 3. THE VARIATION MOVES WITH THE MOVEMENT. A preset belongs to its exercise
//    (D37) and its UUID is part of record/chart identity (D36). Leaving a
//    Bench Press preset on a Dumbbell Bench Press entry would strand that
//    history on an island no future set could join (codex-review 04,
//    critical). So the entry's preset is re-homed: a same-named preset on the
//    target is found or created, and BOTH the relationship and
//    `snapshotPresetID` point at it. `snapshotPresetName` is unchanged.
// 4. RUNS ON EVERY LAUNCH, CHEAPLY, NOT ONCE. A one-shot version gate missed
//    history that arrives after the crossing — a CloudKit merge, a restored
//    backup (codex-review 04, critical). The pre-check is a single COUNT
//    query over entries whose snapshot still names a SOURCE exercise; moved
//    entries name a target, and no target is a source, so it is idempotent
//    by construction and the common case costs one count.

enum DumbbellHistoryMove {

    struct Outcome: Equatable {
        var entries: Int
        var sets: Int
        static let nothing = Outcome(entries: 0, sets: 0)
    }

    /// Moves every qualifying entry. Returns how many entries and completed
    /// sets moved; `.nothing` when there was nothing to do.
    @discardableResult
    static func run(in context: ModelContext, now: Date = .now) throws -> Outcome {
        let sourceIDs = DumbbellCounterparts.sourceIDs
        // The cheap gate: any entry still filed under a source exercise?
        let candidates = try context.fetchCount(FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate { sourceIDs.contains($0.snapshotExerciseID) }))
        guard candidates > 0 else { return .nothing }

        let targetIDs = Set(DumbbellCounterparts.pairs.map(\.target))
        let targets = try context.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { targetIDs.contains($0.id) }))
        let targetByID = Dictionary(uniqueKeysWithValues: targets.map { ($0.id, $0) })

        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate { sourceIDs.contains($0.snapshotExerciseID) }))
        var outcome = Outcome.nothing
        for entry in entries {
            guard !entry.isDeleted,
                  let workout = entry.workout, !workout.isDeleted, workout.finishedAt != nil,
                  entry.snapshotCapturedAt != nil,
                  entry.snapshotFreeWeightTag == .dumbbell,
                  let targetID = DumbbellCounterparts.counterpart(of: entry.snapshotExerciseID),
                  let target = targetByID[targetID]
            else { continue }

            let previousName = entry.snapshotExerciseName
            entry.exercise = target
            entry.snapshotExerciseID = target.id
            entry.snapshotExerciseName = target.name
            entry.reclassifiedAt = now
            entry.reclassifiedFromExerciseName = previousName

            // 3. The variation travels: re-home the preset onto the target.
            if let name = entry.preset?.name ?? entry.snapshotPresetName {
                let homed = try preset(named: name, on: target, in: context)
                entry.preset = homed
                entry.snapshotPresetID = homed.id
            }

            outcome.entries += 1
            outcome.sets += (entry.sets ?? []).filter { !$0.isDeleted && $0.completedAt != nil }.count
        }
        return outcome
    }

    /// The target's preset with this name, created if it does not exist yet.
    /// Two moved entries with the same grip share one preset, and a grip the
    /// user later adds under the same name is this very row.
    private static func preset(
        named name: String, on exercise: Exercise, in context: ModelContext
    ) throws -> ExercisePreset {
        let existing = (exercise.presets ?? []).filter { !$0.isDeleted }
        if let match = existing.first(where: {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return match
        }
        let created = ExercisePreset(
            name: name,
            order: ExercisePresets.nextOrder(after: existing.map(\.order)),
            exercise: exercise)
        context.insert(created)
        return created
    }
}
