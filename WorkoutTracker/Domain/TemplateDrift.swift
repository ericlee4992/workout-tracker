import Foundation
import SwiftData

struct TemplateDriftItem: Equatable {
    var exerciseID: UUID
    var targetRepsBySet: [Int?]
}

enum TemplateDriftResolution: CaseIterable, Equatable, Sendable {
    case updateTemplate
    case updateValuesOnly
    case updateBoth
    case keepOriginal
}

/// Pure D18 comparison and transition rules. Exercise occurrences are
/// matched in order, so duplicate exercises remain deterministic.
enum TemplateDrift {
    static func hasDrift(
        template: [TemplateDriftItem],
        workout: [TemplateDriftItem]
    ) -> Bool {
        template != workout
    }

    static func resolving(
        _ resolution: TemplateDriftResolution,
        template: [TemplateDriftItem],
        workout: [TemplateDriftItem]
    ) -> [TemplateDriftItem] {
        switch resolution {
        case .keepOriginal:
            return template
        case .updateBoth:
            return workout
        case .updateTemplate:
            let matches = matchesFromWorkoutToTemplate(
                template: template, workout: workout)
            return workout.enumerated().map { index, item in
                let oldTargets = matches[index].map {
                    template[$0].targetRepsBySet
                } ?? []
                return TemplateDriftItem(
                    exerciseID: item.exerciseID,
                    targetRepsBySet: (0..<item.targetRepsBySet.count).map {
                        oldTargets.indices.contains($0) ? oldTargets[$0] : nil
                    })
            }
        case .updateValuesOnly:
            var result = template
            let matches = matchesFromWorkoutToTemplate(
                template: template, workout: workout)
            for (workoutIndex, templateIndex) in matches.enumerated() {
                guard let templateIndex else { continue }
                let completed = workout[workoutIndex].targetRepsBySet
                for slot in result[templateIndex].targetRepsBySet.indices
                    where completed.indices.contains(slot) {
                    result[templateIndex].targetRepsBySet[slot] = completed[slot]
                }
            }
            return result
        }
    }

    private static func matchesFromWorkoutToTemplate(
        template: [TemplateDriftItem],
        workout: [TemplateDriftItem]
    ) -> [Int?] {
        var available: [UUID: [Int]] = [:]
        for (index, item) in template.enumerated() {
            available[item.exerciseID, default: []].append(index)
        }
        var usedCount: [UUID: Int] = [:]
        var result: [Int?] = []
        for item in workout {
            let occurrence = usedCount[item.exerciseID, default: 0]
            let candidates = available[item.exerciseID] ?? []
            result.append(candidates.indices.contains(occurrence)
                ? candidates[occurrence]
                : nil)
            usedCount[item.exerciseID] = occurrence + 1
        }
        return result
    }
}

/// SwiftData boundary around the pure drift policy. Draft set rows and
/// entries with zero completed sets never enter the workout snapshot.
struct TemplateDriftService {
    let context: ModelContext

    func sourceTemplate(for workout: Workout) throws -> WorkoutTemplate? {
        guard let sourceID = workout.sourceTemplateID else { return nil }
        let id = sourceID
        return try context.fetch(FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.id == id })).first
    }

    func shouldPrompt(for workout: Workout, template: WorkoutTemplate) throws -> Bool {
        let preferences = try context.fetch(FetchDescriptor<AppPreferences>())
        guard AppPreferences.canonical(of: preferences)?.driftPromptSuppressed != true else {
            return false
        }
        return TemplateDrift.hasDrift(
            template: templateSnapshot(template),
            workout: workoutSnapshot(workout))
    }

    func apply(
        _ resolution: TemplateDriftResolution,
        workout: Workout,
        to template: WorkoutTemplate
    ) throws {
        guard resolution != .keepOriginal else { return }
        let original = templateSnapshot(template)
        let completed = workoutSnapshot(workout)
        let resolved = TemplateDrift.resolving(
            resolution, template: original, workout: completed)

        if resolution == .updateValuesOnly {
            // Pair rows with resolved values from ONE filtered source. A
            // positional zip over `orderedItems` would shift every target by
            // one for each item whose exercise was nullified by a delete,
            // writing one exercise's reps onto another.
            for (row, values) in zip(snapshotRows(template), resolved) {
                guard row.snapshot.exerciseID == values.exerciseID else { continue }
                row.item.targetSets = values.targetRepsBySet.count
                row.item.targetRepsBySet = values.targetRepsBySet
                row.item.targetReps = values.targetRepsBySet.first.flatMap { $0 }
            }
            try context.save()
            return
        }

        let exercises = exerciseLookup(template: template, workout: workout)
        for old in template.items ?? [] { context.delete(old) }
        for (order, value) in resolved.enumerated() {
            guard let exercise = exercises[value.exerciseID] else { continue }
            let item = TemplateItem(
                order: order,
                targetSets: value.targetRepsBySet.count,
                targetReps: value.targetRepsBySet.first.flatMap { $0 },
                targetRepsBySet: value.targetRepsBySet,
                exercise: exercise)
            item.template = template
            context.insert(item)
        }
        try context.save()
    }

    /// Close out a template-sourced workout: apply the chosen resolution, then
    /// finish the workout. The order matters — `apply` reads the workout's
    /// completed structure and `finish` prunes the workout — so both drift
    /// prompts (finishing, and replacing an active workout) share this one
    /// sequence rather than each spelling it out.
    func resolve(
        _ resolution: TemplateDriftResolution,
        workout: Workout,
        to template: WorkoutTemplate
    ) throws {
        try apply(resolution, workout: workout, to: template)
        try WorkoutSession(context: context).finish(workout)
    }

    func templateSnapshot(_ template: WorkoutTemplate) -> [TemplateDriftItem] {
        snapshotRows(template).map(\.snapshot)
    }

    /// The template's comparable rows, each still carrying the `TemplateItem`
    /// it came from. Items whose `exercise` was nullified by a delete have no
    /// identity to match on and are dropped here — the single place that
    /// filtering happens, so snapshots and write targets can never diverge.
    private func snapshotRows(
        _ template: WorkoutTemplate
    ) -> [(item: TemplateItem, snapshot: TemplateDriftItem)] {
        WorkoutTemplateService.orderedItems(of: template).compactMap { item in
            guard let exerciseID = item.exercise?.id else { return nil }
            return (item, TemplateDriftItem(
                exerciseID: exerciseID,
                targetRepsBySet: item.storedTargets.repsBySet))
        }
    }

    func workoutSnapshot(_ workout: Workout) -> [TemplateDriftItem] {
        WorkoutSession.orderedEntries(of: workout).compactMap { entry in
            guard let exerciseID = entry.exercise?.id else { return nil }
            let completed = WorkoutSession.orderedSets(of: entry)
                .filter { $0.completedAt != nil }
            guard !completed.isEmpty else { return nil }
            return TemplateDriftItem(
                exerciseID: exerciseID,
                targetRepsBySet: completed.map(\.reps))
        }
    }

    private func exerciseLookup(
        template: WorkoutTemplate,
        workout: Workout
    ) -> [UUID: Exercise] {
        let templateExercises = WorkoutTemplateService.orderedItems(of: template)
            .compactMap(\.exercise)
        let workoutExercises = WorkoutSession.orderedEntries(of: workout)
            .compactMap(\.exercise)
        return Dictionary(
            (templateExercises + workoutExercises).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
    }
}
