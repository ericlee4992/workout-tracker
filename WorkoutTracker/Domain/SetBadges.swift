import Foundation
import SwiftData

// Floodlight redesign — the live workout's "New best" / "First time" marks on completed sets.
// Pure core (`SetBadgeMath`) over `RecordsMath`, plus a SwiftData bridge for one entry.
//
// Rules (reference/brief/domain-data.md §3, the prototype's `Derived.liveOutcome`):
// - Scope: this equipment — the machine, or the exercise's free-weight tag — plus the preset
//   (D36), and the entry's load type. Records never merge across machines, tags or variations.
// - A set's value is its best-set rank: load first (assisted: LOWER is better), then reps
//   (`RecordsMath.outranks`). Warmups and incomplete sets never count (`RecordsMath.isEligible`).
// - "New best": beats every earlier eligible set in the scope — finished history AND this
//   workout's earlier sets. A tie is not a best (the earlier set keeps it).
// - "First time": the scope has no history; only its first eligible set carries the mark.
//   The first workout in a scope never shows "New best" (everything would be one).
// - Derived on read, never stored: a history edit (D47) must not leave a stale flag behind.

enum SetBadge: Hashable { case newBest, firstTime }

enum SetBadgeMath {
    /// Marks for `current` — this workout's sets in one scope, keyed by id — given the scope's
    /// finished history. Sets are judged in completion order.
    static func badges(current: [(id: UUID, set: RecordSetInput)], history: [RecordSetInput]) -> [UUID: SetBadge] {
        let pastEligible = history.filter(RecordsMath.isEligible)
        var best = pastEligible.reduce(nil as RecordSetInput?) { incumbent, set in
            guard let incumbent else { return set }
            return RecordsMath.outranks(set, incumbent) ? set : incumbent
        }
        let firstWorkout = pastEligible.isEmpty
        var result: [UUID: SetBadge] = [:]
        let ordered = current
            .filter { RecordsMath.isEligible($0.set) }
            .sorted { ($0.set.completedAt ?? .distantPast) < ($1.set.completedAt ?? .distantPast) }
        for (index, item) in ordered.enumerated() {
            guard let incumbent = best else {
                best = item.set
                if firstWorkout && index == 0 { result[item.id] = .firstTime }
                continue
            }
            if RecordsMath.outranks(item.set, incumbent) {
                best = item.set
                if !firstWorkout { result[item.id] = .newBest }
            }
        }
        return result
    }
}

// MARK: - SwiftData bridge

extension SetBadgeMath {
    /// Marks for one live entry's completed sets, against finished workouts in the same scope.
    static func badges(for entry: ExerciseEntry, in context: ModelContext) throws -> [UUID: SetBadge] {
        guard let workout = entry.workout else { return [:] }
        let scope = Scope(entry)
        let loadType = entry.effectiveLoadType
        let finished = try context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil }))
        let history = finished
            .filter { $0.id != workout.id }
            .flatMap { WorkoutSession.orderedEntries(of: $0) }
            .filter { Scope(snapshotOf: $0) == scope && $0.snapshotLoadType == loadType }
            .flatMap { entry in (entry.sets ?? []).map { input($0, entry: entry, loadType: loadType) } }
        // This workout's earlier entries in the same scope count too (a change of preset back and
        // forth splits one exercise into several entries).
        let current = WorkoutSession.orderedEntries(of: workout)
            .filter { Scope($0) == scope && $0.effectiveLoadType == loadType }
            .flatMap { entry in (entry.sets ?? []).map { (id: $0.id, set: input($0, entry: entry, loadType: loadType)) } }
        return badges(current: current, history: history)
    }

    private static func input(_ set: SetRecord, entry: ExerciseEntry, loadType: LoadType) -> RecordSetInput {
        RecordSetInput(
            loadType: loadType, exerciseID: entry.snapshotExerciseID, gymID: entry.snapshotGymID,
            machineID: entry.snapshotMachineID, modelID: entry.snapshotModelID,
            freeWeightTag: entry.snapshotFreeWeightTag, presetID: entry.snapshotPresetID,
            setType: set.type, reps: set.reps, weightValue: set.weightValue, weightUnit: set.weightUnit,
            normalizedKg: set.normalizedKg, completedAt: set.completedAt)
    }

    /// This equipment + variation. A live entry reads its current machine / tag / preset (it may
    /// not have frozen yet); history reads the snapshots (D23).
    private struct Scope: Equatable {
        var exerciseID: UUID
        var machineID: UUID?
        var freeWeightTag: EquipmentTag?
        var presetID: UUID?

        init(_ entry: ExerciseEntry) {
            exerciseID = entry.exercise?.id ?? entry.snapshotExerciseID
            machineID = entry.machine?.id ?? entry.snapshotMachineID
            freeWeightTag = machineID == nil ? (entry.freeWeightTag ?? entry.snapshotFreeWeightTag) : nil
            presetID = entry.snapshotCapturedAt == nil ? entry.preset?.id : entry.snapshotPresetID
        }

        init(snapshotOf entry: ExerciseEntry) {
            exerciseID = entry.snapshotExerciseID
            machineID = entry.snapshotMachineID
            freeWeightTag = machineID == nil ? entry.snapshotFreeWeightTag : nil
            presetID = entry.snapshotPresetID
        }
    }
}
