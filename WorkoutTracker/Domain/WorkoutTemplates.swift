import Foundation
import SwiftData

struct TemplateItemDraft {
    var exercise: Exercise
    var targetRepsBySet: [Int?]

    init(exercise: Exercise, targetRepsBySet: [Int?]) {
        self.exercise = exercise
        self.targetRepsBySet = targetRepsBySet
    }
}

enum WorkoutTemplateError: Error, Equatable {
    case emptyName
    case noExercises
}

/// Ticket 15's persisted template boundary: CRUD, gym-specific startup
/// resolution, provenance, and finished-workout capture. Templates never own
/// weights or rest durations (D6/D22).
struct WorkoutTemplateService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func create(name: String, items: [TemplateItemDraft]) throws -> WorkoutTemplate {
        let validName = try validatedName(name)
        guard !items.isEmpty else { throw WorkoutTemplateError.noExercises }
        let template = WorkoutTemplate(name: validName)
        context.insert(template)
        try replaceItems(of: template, with: items)
        try context.save()
        return template
    }

    func update(
        _ template: WorkoutTemplate,
        name: String,
        items: [TemplateItemDraft]
    ) throws {
        template.name = try validatedName(name)
        try replaceItems(of: template, with: items)
        try context.save()
    }

    func delete(_ template: WorkoutTemplate) throws {
        context.delete(template)
        try context.save()
    }

    /// Starts a template at `gym` (or no gym), resolving each exercise to the
    /// latest active remembered machine at that gym. Target set rows remain
    /// drafts; per-slot target reps are copied into their input values.
    @discardableResult
    func start(
        _ template: WorkoutTemplate,
        at gym: Gym?,
        on date: Date = .now
    ) throws -> Workout {
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: gym, on: date)
        workout.sourceTemplateID = template.id

        for item in Self.orderedItems(of: template) {
            guard let exercise = item.exercise else { continue }
            let machine: MachineInstance?
            if let gym {
                machine = try EquipmentLifecycle(context: context)
                    .rememberedMachine(for: exercise, at: gym)
            } else {
                machine = nil
            }
            let entry = try session.addEntry(
                for: exercise, to: workout, machine: machine)
            let count = max(1, item.targetSets ?? item.targetRepsBySet.count)
            while WorkoutSession.orderedSets(of: entry).count < count {
                try session.addSet(to: entry)
            }
            for (index, set) in WorkoutSession.orderedSets(of: entry).enumerated() {
                let perSlot = item.targetRepsBySet.indices.contains(index)
                    ? item.targetRepsBySet[index]
                    : nil
                set.reps = perSlot ?? item.targetReps
            }
        }
        try context.save()
        return workout
    }

    /// Captures completed entries/sets from a finished from-scratch workout.
    /// Entry order and completed-set order become authoritative template
    /// structure; target reps are retained independently per set slot.
    @discardableResult
    func saveAsTemplate(
        _ workout: Workout,
        name: String
    ) throws -> WorkoutTemplate {
        let drafts = WorkoutSession.orderedEntries(of: workout).compactMap { entry -> TemplateItemDraft? in
            guard let exercise = entry.exercise else { return nil }
            let completed = WorkoutSession.orderedSets(of: entry)
                .filter { $0.completedAt != nil }
            guard !completed.isEmpty else { return nil }
            return TemplateItemDraft(
                exercise: exercise,
                targetRepsBySet: completed.map(\.reps))
        }
        return try create(name: name, items: drafts)
    }

    static func orderedItems(of template: WorkoutTemplate) -> [TemplateItem] {
        (template.items ?? []).sorted { $0.order < $1.order }
    }

    private func replaceItems(
        of template: WorkoutTemplate,
        with drafts: [TemplateItemDraft]
    ) throws {
        guard !drafts.isEmpty else { throw WorkoutTemplateError.noExercises }
        for old in template.items ?? [] { context.delete(old) }
        for (order, draft) in drafts.enumerated() {
            let reps = draft.targetRepsBySet
            let item = TemplateItem(
                order: order,
                targetSets: reps.count,
                targetReps: reps.first.flatMap { $0 },
                targetRepsBySet: reps,
                exercise: draft.exercise)
            item.template = template
            context.insert(item)
        }
    }

    private func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WorkoutTemplateError.emptyName }
        return trimmed
    }
}
