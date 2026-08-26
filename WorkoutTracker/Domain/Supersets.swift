import Foundation
import SwiftData

// Milestone 8, ticket 04 — supersets (D48).
//
// THE TWO DECISIONS, made deliberately (user's call, 2026-08-25):
//
// 1. A superset is a GROUP OF ENTRIES, not a tag on sets. That matches how
//    people actually train — A1/B1, A2/B2, alternating between exercises —
//    where a set-level tag would record that sets were "in a superset" without
//    modelling the alternation that makes it one.
// 2. REST COMES AFTER THE LAST MEMBER of the group, not between members. Moving
//    straight from A to B with no rest is the entire point of the technique; a
//    timer that fired between them would be telling the user to do the opposite
//    of what they chose.
//
// WHAT MUST NOT CHANGE: a set in a superset is still a set. Records, PRs and
// volume must be identical to the same sets logged ungrouped. If grouping ever
// alters them, it has stopped being presentation and become a new kind of load
// — and every PR the user has would depend on how they happened to arrange
// their workout that day.

enum Supersets {

    /// Entries of one workout, in order, grouped into supersets.
    ///
    /// Returns runs: a standalone entry is a run of one. Order is preserved, so
    /// the screen renders in the same sequence the user built.
    ///
    /// Members are identified by `supersetGroupID` but grouped by ADJACENCY: a
    /// group interrupted by an unrelated exercise is rendered as two runs
    /// rather than pretending the interruption did not happen. Ordering is the
    /// thing the user can see, so it wins over the id.
    static func runs(of workout: Workout) -> [[ExerciseEntry]] {
        let entries = WorkoutSession.orderedEntries(of: workout).filter { !$0.isDeleted }
        var runs: [[ExerciseEntry]] = []
        for entry in entries {
            if let groupID = entry.supersetGroupID,
               let last = runs.last, last.first?.supersetGroupID == groupID {
                runs[runs.count - 1].append(entry)
            } else {
                runs.append([entry])
            }
        }
        return runs
    }

    /// True when this entry is part of a group of two or more.
    ///
    /// A "superset" of one is not a superset. A group can be left holding a
    /// single member by deleting the other, and rendering that as a superset
    /// would show a badge the user cannot act on.
    static func isGrouped(_ entry: ExerciseEntry, in workout: Workout) -> Bool {
        guard entry.supersetGroupID != nil else { return false }
        return run(containing: entry, in: workout).count > 1
    }

    /// The run this entry belongs to, or just itself.
    static func run(containing entry: ExerciseEntry, in workout: Workout) -> [ExerciseEntry] {
        runs(of: workout).first { $0.contains(where: { $0.id == entry.id }) } ?? [entry]
    }

    /// Position within a superset, for the A1/B1 label. nil when standalone.
    static func memberLabel(for entry: ExerciseEntry, in workout: Workout) -> String? {
        let run = run(containing: entry, in: workout)
        guard run.count > 1,
              let index = run.firstIndex(where: { $0.id == entry.id })
        else { return nil }
        // A, B, C… beyond Z falls back to a number rather than wrapping to a
        // second alphabet, which would repeat labels within one workout.
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return index < letters.count ? String(letters[index]) : "\(index + 1)"
    }

    /// THE REST RULE. Whether completing a set in this entry should start a
    /// rest at all.
    ///
    /// Inside a superset the answer is no until the last member — that is what
    /// makes it a superset. The check is on the ENTRY's position in the run,
    /// not on how many sets are done, because the user alternates: A set 1,
    /// B set 1, rest; A set 2, B set 2, rest.
    static func shouldRest(afterCompletingSetIn entry: ExerciseEntry, in workout: Workout) -> Bool {
        let run = run(containing: entry, in: workout)
        guard run.count > 1 else { return true }
        return run.last?.id == entry.id
    }

    /// The entry the user should move to next after completing a set — the next
    /// member of the superset, wrapping back to the first.
    static func nextMember(after entry: ExerciseEntry, in workout: Workout) -> ExerciseEntry? {
        let run = run(containing: entry, in: workout)
        guard run.count > 1,
              let index = run.firstIndex(where: { $0.id == entry.id })
        else { return nil }
        return index + 1 < run.count ? run[index + 1] : run.first
    }

    // MARK: - Mutation

    /// Groups entries into one superset, in the order given.
    ///
    /// Refuses a group of fewer than two: a superset of one is not a superset,
    /// and allowing it would put an unactionable badge on an ordinary exercise.
    @discardableResult
    static func group(_ entries: [ExerciseEntry]) -> Bool {
        let live = entries.filter { !$0.isDeleted }
        guard live.count > 1 else { return false }
        let groupID = UUID()
        for entry in live { entry.supersetGroupID = groupID }
        return true
    }

    /// Removes grouping from every member of this entry's run.
    ///
    /// Ungrouping the whole run rather than one member: leaving one entry
    /// holding a group id is the "superset of one" case again, reached from the
    /// other direction.
    static func ungroup(_ entry: ExerciseEntry, in workout: Workout) {
        for member in run(containing: entry, in: workout) {
            member.supersetGroupID = nil
        }
    }

    /// Repairs groups left with a single member — after a delete, say — so a
    /// stale badge cannot survive on an entry that is no longer supersetted.
    static func pruneOrphanGroups(in workout: Workout) {
        for run in runs(of: workout) where run.count == 1 {
            run[0].supersetGroupID = nil
        }
    }
}
