import Foundation
import SwiftData

/// Every finished set logged against an exercise, in SNAPSHOT terms (D23), with its workout — the history the
/// progress charts draw. One reader for `ExerciseProgressView` and the Progress tab (ticket 16), so the two cannot
/// disagree about which sets count; scoping to a variation and eligibility stay with `ProgressSeriesMath`.
enum ExerciseHistory {
    typealias Item = (input: RecordSetInput, workout: Workout)

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
            normalizedKg: set.normalizedKg, completedAt: set.completedAt), workout))
    }
}
