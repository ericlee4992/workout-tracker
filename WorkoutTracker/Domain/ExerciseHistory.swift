import Foundation
import SwiftData

/// Every finished set logged against an exercise, in SNAPSHOT terms (D23), with its workout — the history the
/// progress charts draw. One reader for `ExerciseProgressView` and the Progress tab (ticket 16), so the two cannot
/// disagree about which sets count; scoping to a variation and eligibility stay with `ProgressSeriesMath`.
enum ExerciseHistory {
    /// A set as the charts read it, with its workout and the entry that logged it — the entry carries the snapshot
    /// names of that exact context (D23), e.g. a pooled session row's machine (live-workout 03).
    typealias Item = (input: RecordSetInput, workout: Workout, entry: ExerciseEntry)

    /// One exercise's history.
    static func items(for exerciseID: UUID, in context: ModelContext) -> [Item] {
        sets(in: context).compactMap { item(for: $0, only: exerciseID)?.item }
    }

    /// Every exercise's history in one fetch, keyed by the snapshot exercise id.
    static func all(in context: ModelContext) -> [UUID: [Item]] {
        var out: [UUID: [Item]] = [:]
        for set in sets(in: context) {
            guard let found = item(for: set, only: nil) else { continue }
            out[found.exerciseID, default: []].append(found.item)
        }
        return out
    }

    private static func sets(in context: ModelContext) -> [SetRecord] {
        (try? context.fetch(FetchDescriptor<SetRecord>())) ?? []
    }

    private static func item(for set: SetRecord, only exerciseID: UUID?) -> (exerciseID: UUID, item: Item)? {
        // Snapshot values only, and finished workouts only — an in-progress session is not history yet.
        guard !set.isDeleted, let entry = set.entry, !entry.isDeleted,
              exerciseID == nil || entry.snapshotExerciseID == exerciseID,
              let workout = entry.workout, !workout.isDeleted,
              workout.finishedAt != nil
        else { return nil }
        return (entry.snapshotExerciseID, (RecordSetInput(
            loadType: entry.snapshotLoadType,
            exerciseID: entry.snapshotExerciseID,
            gymID: entry.snapshotGymID,
            machineID: entry.snapshotMachineID,
            modelID: entry.snapshotModelID,
            freeWeightTag: entry.snapshotFreeWeightTag,
            presetID: entry.snapshotPresetID,
            setType: set.type, reps: set.reps,
            weightValue: set.weightValue, weightUnit: set.weightUnit,
            normalizedKg: set.normalizedKg, completedAt: set.completedAt), workout, entry))
    }

    /// Per calendar day, the item holding that day's best set in `variation` — the same pick as
    /// `ProgressSeriesMath.series` (eligible sets only; the records' rank, plain bodyweight by most reps; the first
    /// kept on a tie). A Sessions row opens that set's workout (Codex 05) and, under All machines, names that set's
    /// own entry's machine — not another entry of the same workout (live-workout 03, Codex review 03b).
    static func bestPerDay(
        _ items: [Item], variation: ProgressVariationKey, calendar: Calendar = .current
    ) -> [Date: Item] {
        var best: [Date: Item] = [:]
        for item in items where ProgressSeriesMath.scoped([item.input], to: variation).count == 1
            && RecordsMath.isEligible(item.input) {
            let day = calendar.startOfDay(for: item.input.completedAt ?? .distantPast)
            guard let incumbent = best[day] else { best[day] = item; continue }
            let better = variation.loadType == .bodyweight
                ? (item.input.reps ?? 0) > (incumbent.input.reps ?? 0)
                : RecordsMath.outranks(item.input, incumbent.input)
            if better { best[day] = item }
        }
        return best
    }
}

extension ProgressVariationKey {
    /// The variation an entry is performing — for a live entry, right now (live-workout 03, D87: the chart opened
    /// from a workout opens on the machine in use). A draft's equipment, preset and load type are still its live
    /// rows, editable until the first completed set freezes the snapshot (D19); after that the snapshot is the
    /// truth (D23), as `PerformanceHistory` reads it.
    static func current(for entry: ExerciseEntry) -> ProgressVariationKey {
        guard entry.snapshotCapturedAt == nil else {
            return ProgressVariationKey(
                loadType: entry.snapshotLoadType,
                equipment: ProgressEquipment(
                    machineID: entry.snapshotMachineID, freeWeightTag: entry.snapshotFreeWeightTag),
                presetID: entry.snapshotPresetID)
        }
        return ProgressVariationKey(
            loadType: entry.exercise?.loadType ?? entry.snapshotLoadType,
            equipment: ProgressEquipment(machineID: entry.machine?.id, freeWeightTag: entry.freeWeightTag),
            presetID: entry.preset?.id)
    }
}
