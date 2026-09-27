import Foundation
import SwiftData

// Floodlight redesign — what the finish receipt draws beyond `WorkoutSummary`: the families the
// ring is made of, the new bests with the best each one beat, one row per exercise with its
// best set and mark, and the comparison with the template's last run. Derived on read from the
// finished workout's snapshots (names, equipment: D23); family mapping reads the live
// `muscleGroup`, the documented exception (muscle groups are not snapshotted).

struct FinishReceipt: Equatable {
    struct Best: Equatable, Identifiable {
        var id: UUID
        var exerciseName: String
        /// "Chest Press 2", "Dumbbell · Narrow grip" — the snapshot equipment and preset.
        var equipment: String?
        var value: SetValue
        var previous: SetValue?
        var loadType: LoadType
    }

    struct ExerciseRow: Equatable, Identifiable {
        var id: UUID
        var name: String
        /// "Chest Press 2 · 5 sets".
        var detail: String
        var best: SetValue?
        var loadType: LoadType
        /// The entry holds a new best (or, the scope's very first sets, First time).
        var badge: SetBadge?
    }

    struct Comparison: Equatable {
        var templateName: String
        var lastDate: Date
        var lastVolumeKg: Double
        var volumeKg: Double
    }

    /// Completed sets per family in workout order (every set type: the ring has one segment per
    /// completed set, so it agrees with the set count).
    var familySets: [FamilyCount]
    var bests: [Best]
    var exercises: [ExerciseRow]
    var comparison: Comparison?
}

extension FinishReceipt {
    static func build(for workout: Workout, in context: ModelContext) throws -> FinishReceipt {
        let entries = WorkoutSession.orderedEntries(of: workout)
        var order: [MuscleFamily] = []
        var counts: [MuscleFamily: Int] = [:]
        var bests: [Best] = []
        var rows: [ExerciseRow] = []
        var seenScopes = Set<UUID>()

        for entry in entries {
            let completed = WorkoutSession.orderedSets(of: entry).filter { $0.completedAt != nil }
            guard !completed.isEmpty else { continue }
            if let family = MuscleFamily(muscleGroup: entry.exercise?.muscleGroup) {
                if counts[family] == nil { order.append(family) }
                counts[family, default: 0] += completed.count
            }
            let loadType = entry.snapshotLoadType
            let equipment = [entry.snapshotMachineLabel ?? entry.snapshotFreeWeightTag?.label, entry.snapshotPresetName]
                .compactMap { $0 }.joined(separator: " · ")
            // Outcomes are per scope; entries sharing one (a preset switched back and forth)
            // report the same map, so each set is read once.
            let outcomes = try SetBadgeMath.outcomes(for: entry, in: context)
            var entryBadge: SetBadge?
            for set in completed {
                guard let outcome = outcomes[set.id], seenScopes.insert(set.id).inserted else { continue }
                if outcome.badge == .newBest {
                    entryBadge = .newBest
                    bests.append(Best(
                        id: set.id, exerciseName: entry.snapshotExerciseName,
                        equipment: equipment.isEmpty ? nil : equipment,
                        value: SetValue(weight: set.weightValue, unit: set.weightUnit, reps: set.reps ?? 0,
                                        bar: set.barWeightValue),
                        previous: outcome.previous.flatMap(SetValue.init),
                        loadType: loadType))
                } else if entryBadge == nil {
                    entryBadge = .firstTime
                }
            }
            let best = bestSet(completed, loadType: loadType)
            rows.append(ExerciseRow(
                id: entry.id, name: entry.snapshotExerciseName,
                detail: ([equipment.isEmpty ? nil : equipment,
                          HistoryRendering.pluralized(completed.count, "set", "sets")] as [String?])
                    .compactMap { $0 }.joined(separator: " · "),
                best: best, loadType: loadType, badge: entryBadge))
        }

        return FinishReceipt(
            familySets: order.map { FamilyCount(family: $0, sets: counts[$0] ?? 0) },
            bests: bests, exercises: rows,
            comparison: try comparison(for: workout, in: context))
    }

    /// The best completed set by the records rank (warmups out unless nothing else was logged).
    private static func bestSet(_ sets: [SetRecord], loadType: LoadType) -> SetValue? {
        let inputs = sets.map { set in
            (set, RecordSetInput(loadType: loadType, exerciseID: UUID(), gymID: nil, machineID: nil, modelID: nil,
                                 freeWeightTag: nil, presetID: nil, setType: set.type, reps: set.reps,
                                 weightValue: set.weightValue, weightUnit: set.weightUnit,
                                 normalizedKg: set.normalizedKg, completedAt: set.completedAt))
        }
        let eligible = inputs.filter { RecordsMath.isEligible($0.1) }
        let pool = eligible.isEmpty ? inputs : eligible
        guard let best = pool.reduce(nil as (SetRecord, RecordSetInput)?, { incumbent, next in
            guard let incumbent else { return next }
            return RecordsMath.outranks(next.1, incumbent.1) ? next : incumbent
        }), let reps = best.0.reps else { return nil }
        return SetValue(weight: best.0.weightValue, unit: best.0.weightUnit, reps: reps, bar: best.0.barWeightValue)
    }

    /// The template's previous finished run, when both runs lifted something.
    private static func comparison(for workout: Workout, in context: ModelContext) throws -> Comparison? {
        guard let templateID = workout.sourceTemplateID else { return nil }
        let started = workout.startedAt
        let workoutID = workout.id
        let runs = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt != nil && $0.sourceTemplateID == templateID && $0.startedAt < started },
            sortBy: [SortDescriptor(\Workout.startedAt, order: .reverse)]))
        guard let last = runs.first(where: { $0.id != workoutID }) else { return nil }
        let now = WorkoutSummaryBuilder.summary(for: workout).totalVolumeKg
        let then = WorkoutSummaryBuilder.summary(for: last).totalVolumeKg
        guard now > 0, then > 0 else { return nil }
        return Comparison(templateName: workout.sourceTemplateName ?? last.sourceTemplateName ?? "Template",
                          lastDate: last.startedAt, lastVolumeKg: then, volumeKg: now)
    }
}
