import Foundation
import SwiftData

enum PerformanceLayerKind: String, Sendable, Hashable {
    case thisEquipment
    case sameModelElsewhere
    case anyEquipment
}

extension PerformanceLayerKind {
    /// Ticket 13: a layer with no history still renders a labeled explanation
    /// naming *this* layer — never a blank section. Kept beside the layer kind
    /// (Foundation-only, unit-tested) so the empty states cannot silently
    /// vanish from the sheet.
    func emptyHistoryMessage(hasMachine: Bool) -> String {
        switch self {
        case .thisEquipment:
            hasMachine
                ? "No completed sets on this machine yet."
                : "No completed sets with this equipment yet."
        case .sameModelElsewhere:
            "No other gyms with this model logged yet."
        case .anyEquipment:
            "No history for this exercise yet."
        }
    }

    /// Shown in place of a layer's records block when it has no eligible sets.
    static let emptyRecordsMessage = "No eligible records at this layer yet."
}

struct PreviousSetValue: Sendable, Equatable, Identifiable {
    var id: UUID
    var order: Int
    var type: SetType
    var reps: Int
    var weightValue: Double?
    var weightUnit: WeightUnit
    var normalizedKg: Double?
    var completedAt: Date

    var displayLabel: String {
        let repsLabel = "\(reps)"
        guard let weightValue else { return "\(repsLabel) reps" }
        return "\(Format.weight(weightValue)) \(weightUnit.rawValue) × \(repsLabel)"
    }
}

struct PreviousPerformanceSnapshot: Sendable, Equatable {
    var layer: PerformanceLayerKind
    var workoutID: UUID
    var workoutDate: Date
    var gymName: String?
    var equipmentLabel: String
    var sets: [PreviousSetValue]
}

struct PerformanceLayerResult: Sendable, Equatable, Identifiable {
    var kind: PerformanceLayerKind
    var snapshot: PreviousPerformanceSnapshot?
    var id: PerformanceLayerKind { kind }
}

struct RecordLayerSummary: Sendable, Equatable {
    var loadType: LoadType
    var repCountBests: [Int: RecordAchievement]
    var bodyweightBest: RecordAchievement?
    var estimatedOneRepMax: E1RMRecord?

    var isEmpty: Bool {
        repCountBests.isEmpty && bodyweightBest == nil && estimatedOneRepMax == nil
    }
}

/// Ticket 11 history selection. Every grouping decision uses entry snapshots
/// (D23), and every source is a finished workout with completed sets only.
/// Live catalog relationships are used solely to identify the draft entry's
/// current context before its own snapshot is captured.
struct PerformanceHistory {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Prefill source for one draft row, matched by exact set type and its
    /// zero-based ordinal among rows of that type. The source entry is from
    /// the most recent finished matching workout; if that workout contains
    /// duplicates, the last entry by scalar order wins.
    func prefill(for target: SetRecord) throws -> PreviousSetValue? {
        guard target.completedAt == nil, let entry = target.entry else { return nil }
        let peers = WorkoutSession.orderedSets(of: entry)
            .filter { $0.type == target.type }
        guard let ordinal = peers.firstIndex(where: { $0.id == target.id }),
              let source = try latestEntry(matching: layerOneMatch(for: entry)) else {
            return nil
        }
        let matchingSets = completedSets(of: source).filter { $0.type == target.type }
        guard matchingSets.indices.contains(ordinal) else { return nil }
        return value(from: matchingSets[ordinal])
    }

    /// Applies a previously selected candidate without completing the row.
    /// Callers pass their dirty state at the last possible moment; a dirty
    /// row is never overwritten by a delayed result.
    @discardableResult
    func applyPrefill(
        _ value: PreviousSetValue,
        to target: SetRecord,
        isDirty: Bool
    ) throws -> Bool {
        guard !isDirty, target.completedAt == nil else { return false }
        target.reps = value.reps
        target.weightValue = value.weightValue
        target.weightUnit = value.weightUnit
        target.normalizedKg = value.normalizedKg
        try context.save()
        return true
    }

    /// Latest reference snapshot for each applicable fallback layer. A
    /// machine entry has three layers. A machineless entry has a tag-specific
    /// first layer and an exercise-wide reference layer.
    func layers(for entry: ExerciseEntry) throws -> [PerformanceLayerResult] {
        let all = try historicalEntries()
        var results: [PerformanceLayerResult] = []

        results.append(PerformanceLayerResult(
            kind: .thisEquipment,
            snapshot: snapshot(
                layer: .thisEquipment,
                entry: latestEntry(in: all, matching: layerOneMatch(for: entry)))))

        if let modelID = entry.machine?.model?.id,
           let gymID = entry.workout?.gym?.id {
            results.append(PerformanceLayerResult(
                kind: .sameModelElsewhere,
                snapshot: snapshot(
                    layer: .sameModelElsewhere,
                    entry: latestEntry(in: all) { candidate in
                        candidate.snapshotExerciseID == currentExerciseID(for: entry)
                            && candidate.snapshotModelID == modelID
                            && candidate.snapshotGymID != gymID
                    })))
        }

        results.append(PerformanceLayerResult(
            kind: .anyEquipment,
            snapshot: snapshot(
                layer: .anyEquipment,
                entry: latestEntry(in: all) { candidate in
                    candidate.snapshotExerciseID == currentExerciseID(for: entry)
                })))
        return results
    }

    /// All completed values in a layer, used by ticket 13's record surface.
    func completedValues(
        for entry: ExerciseEntry,
        layer: PerformanceLayerKind
    ) throws -> [(entry: ExerciseEntry, set: PreviousSetValue)] {
        let all = try historicalEntries()
        let exerciseID = currentExerciseID(for: entry)
        let matches: (ExerciseEntry) -> Bool
        switch layer {
        case .thisEquipment:
            matches = layerOneMatch(for: entry)
        case .sameModelElsewhere:
            guard let modelID = entry.machine?.model?.id,
                  let gymID = entry.workout?.gym?.id else { return [] }
            matches = {
                $0.snapshotExerciseID == exerciseID
                    && $0.snapshotModelID == modelID
                    && $0.snapshotGymID != gymID
            }
        case .anyEquipment:
            matches = { $0.snapshotExerciseID == exerciseID }
        }
        return all.filter(matches).flatMap { historicalEntry in
            completedSets(of: historicalEntry).map {
                (entry: historicalEntry, set: value(from: $0))
            }
        }
    }

    /// Ticket 13 bridge from SwiftData snapshots into ticket 12's pure
    /// records core. Group selection follows `RecordGroupKey`: machine,
    /// model, exercise, or tag-specific free weight. Thus barbell and
    /// dumbbell records never merge even though both share an exercise UUID.
    ///
    /// The summary's load type classifies *history*, so it is derived from
    /// the layer's own inputs' snapshot load types (D23), never from the live
    /// exercise: RecordsMath filters each input by its snapshot load type, so
    /// a catalog loadType edit would otherwise leave the summary's load type
    /// disagreeing with every one of its inputs and blank every past record
    /// at every layer. Live catalog reads survive only where they answer
    /// "which exercise/equipment is the user on right now" for the draft
    /// entry (`currentExerciseID`, `layerOneMatch`, `layers`); nothing that
    /// classifies or filters history reads a live relationship.
    func recordSummary(
        for entry: ExerciseEntry,
        layer: PerformanceLayerKind
    ) throws -> RecordLayerSummary {
        let allInputs = try historicalEntries().flatMap(recordInputs(from:))
        let grouped = RecordsMath.grouped(allInputs)
        let exerciseID = currentExerciseID(for: entry)
        let key: RecordGroupKey?
        // Set when the layer is scoped to gyms other than the current one.
        var elsewhereThanGymID: UUID?
        switch layer {
        case .thisEquipment:
            if let machineID = entry.machine?.id {
                key = .machine(machineID)
            } else {
                key = .freeWeight(exerciseID: exerciseID, tag: entry.freeWeightTag)
            }
        case .sameModelElsewhere:
            // "Elsewhere" is part of the layer, not just its header: the model
            // group spans gyms, so the current gym's own sets are dropped —
            // the same rule `layers`/`completedValues` apply to snapshots.
            if let modelID = entry.machine?.model?.id,
               let gymID = entry.workout?.gym?.id {
                key = .model(modelID)
                elsewhereThanGymID = gymID
            } else {
                key = nil
            }
        case .anyEquipment:
            // Layer 3 is "exercise anywhere" (ticket 11) — always the
            // exercise-wide key. Keying machineless entries by free-weight tag
            // made it byte-identical to layer 1, hiding all other equipment.
            key = .exercise(exerciseID)
        }
        var inputs = key.flatMap { grouped[$0] } ?? []
        if let elsewhereThanGymID {
            inputs = inputs.filter { $0.gymID != elsewhereThanGymID }
        }
        let loadType = historicalLoadType(among: inputs) ?? entry.snapshotLoadType
        return RecordLayerSummary(
            loadType: loadType,
            repCountBests: RecordsMath.repCountBests(among: inputs, loadType: loadType),
            bodyweightBest: RecordsMath.mostRepsRecord(among: inputs),
            estimatedOneRepMax: RecordsMath.bestE1RM(among: inputs))
    }

    /// The load type a layer's history is recorded under: the dominant
    /// snapshot load type among its inputs, ties resolving to the most
    /// recently completed set's. nil when the layer has no history, leaving
    /// the caller to fall back to the entry's own snapshot load type.
    private func historicalLoadType(among inputs: [RecordSetInput]) -> LoadType? {
        var counts: [LoadType: Int] = [:]
        for input in inputs { counts[input.loadType, default: 0] += 1 }
        guard let topCount = counts.values.max() else { return nil }
        let leaders = Set(counts.filter { $0.value == topCount }.keys)
        if leaders.count == 1 { return leaders.first }
        return inputs
            .filter { leaders.contains($0.loadType) }
            .max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }?
            .loadType
    }

    // MARK: Selection

    private func historicalEntries() throws -> [ExerciseEntry] {
        try context.fetch(FetchDescriptor<ExerciseEntry>()).filter {
            $0.snapshotCapturedAt != nil
                && $0.workout?.finishedAt != nil
                && !$0.isDeleted
                && !completedSets(of: $0).isEmpty
        }
    }

    private func latestEntry(
        matching predicate: (ExerciseEntry) -> Bool
    ) throws -> ExerciseEntry? {
        latestEntry(in: try historicalEntries(), matching: predicate)
    }

    private func latestEntry(
        in entries: [ExerciseEntry],
        matching predicate: (ExerciseEntry) -> Bool
    ) -> ExerciseEntry? {
        // Max over (finishedAt, startedAt, workout id, entry order). Including
        // entry order last makes duplicate matches in one source workout
        // deterministically choose the final entry.
        entries.filter(predicate).max { lhs, rhs in
            entrySortKey(lhs) < entrySortKey(rhs)
        }
    }

    private func entrySortKey(_ entry: ExerciseEntry) -> (Date, Date, String, Int, String) {
        (
            entry.workout?.finishedAt ?? .distantPast,
            entry.workout?.startedAt ?? .distantPast,
            entry.workout?.id.uuidString ?? "",
            entry.order,
            entry.id.uuidString
        )
    }

    private func currentExerciseID(for entry: ExerciseEntry) -> UUID {
        entry.exercise?.id ?? entry.snapshotExerciseID
    }

    private func layerOneMatch(for entry: ExerciseEntry) -> (ExerciseEntry) -> Bool {
        let exerciseID = currentExerciseID(for: entry)
        if let machineID = entry.machine?.id {
            return {
                $0.snapshotExerciseID == exerciseID
                    && $0.snapshotMachineID == machineID
            }
        }
        let tag = entry.freeWeightTag
        return {
            $0.snapshotExerciseID == exerciseID
                && $0.snapshotMachineID == nil
                && $0.snapshotFreeWeightTag == tag
        }
    }

    private func completedSets(of entry: ExerciseEntry) -> [SetRecord] {
        WorkoutSession.orderedSets(of: entry).filter { $0.completedAt != nil }
    }

    private func value(from set: SetRecord) -> PreviousSetValue {
        PreviousSetValue(
            id: set.id,
            order: set.order,
            type: set.type,
            reps: set.reps ?? 0,
            weightValue: set.weightValue,
            weightUnit: set.weightUnit,
            normalizedKg: set.normalizedKg,
            completedAt: set.completedAt ?? .distantPast)
    }

    private func recordInputs(from entry: ExerciseEntry) -> [RecordSetInput] {
        completedSets(of: entry).map { set in
            RecordSetInput(
                loadType: entry.snapshotLoadType,
                exerciseID: entry.snapshotExerciseID,
                gymID: entry.snapshotGymID,
                machineID: entry.snapshotMachineID,
                modelID: entry.snapshotModelID,
                freeWeightTag: entry.snapshotFreeWeightTag,
                setType: set.type,
                reps: set.reps,
                weightValue: set.weightValue,
                weightUnit: set.weightUnit,
                normalizedKg: set.normalizedKg,
                completedAt: set.completedAt)
        }
    }

    private func snapshot(
        layer: PerformanceLayerKind,
        entry: ExerciseEntry?
    ) -> PreviousPerformanceSnapshot? {
        guard let entry, let workout = entry.workout else { return nil }
        return PreviousPerformanceSnapshot(
            layer: layer,
            workoutID: workout.id,
            workoutDate: workout.finishedAt ?? workout.startedAt,
            gymName: entry.snapshotGymName,
            equipmentLabel: entry.snapshotEquipmentLabel,
            sets: completedSets(of: entry).map(value(from:)))
    }
}
