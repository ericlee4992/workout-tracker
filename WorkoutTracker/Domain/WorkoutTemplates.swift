import Foundation
import SwiftData

struct TemplateItemDraft {
    var exercise: Exercise
    var targetRepsBySet: [Int?]
    /// Superset membership (D48), carried so a template does not silently lose
    /// its grouping between save and start.
    var supersetGroupID: UUID?

    init(exercise: Exercise, targetRepsBySet: [Int?], supersetGroupID: UUID? = nil) {
        self.exercise = exercise
        self.targetRepsBySet = targetRepsBySet
        self.supersetGroupID = supersetGroupID
    }
}

enum WorkoutTemplateError: Error, Equatable {
    case emptyName
    case noExercises
}

/// The per-slot rep targets a `TemplateItem` describes. `targetSets`,
/// `targetReps`, and `targetRepsBySet` always travel together and are
/// derivable from one another, so the derivation lives here once instead of
/// being re-spelled — with drifting floors — by every reader.
struct TemplateTargets: Equatable {
    /// One entry per set slot; nil = that slot carries no rep target.
    var repsBySet: [Int?]

    /// How many set rows the item describes.
    var count: Int { repsBySet.count }

    /// `targetSets` decides the slot count (falling back to the stored
    /// per-slot list); slots beyond the per-slot list inherit the item's
    /// single `targetReps`. `minimumSets` is the caller's floor — see
    /// `TemplateItem.storedTargets` / `.editableTargets`.
    fileprivate init(of item: TemplateItem, minimumSets: Int) {
        let count = max(minimumSets, item.targetSets ?? item.targetRepsBySet.count)
        repsBySet = (0..<count).map { slot in
            item.targetRepsBySet.indices.contains(slot)
                ? item.targetRepsBySet[slot]
                : item.targetReps
        }
    }

    init(repsBySet: [Int?]) {
        self.repsBySet = repsBySet
    }
}

extension TemplateItem {
    /// The item exactly as stored, floored at zero: an item describing no sets
    /// describes no slots. Used where the targets are *reported* — a drift
    /// snapshot of an empty item must be able to come back empty rather than
    /// inventing a phantom row that would read as drift.
    var storedTargets: TemplateTargets { TemplateTargets(of: self, minimumSets: 0) }

    /// The same derivation floored at one row. Used where the targets are
    /// *materialized* — starting a template must produce at least one set row
    /// to log into, and the editor must show at least one slot to edit.
    var editableTargets: TemplateTargets { TemplateTargets(of: self, minimumSets: 1) }
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
    /// latest active remembered machine at that gym. Target set counts
    /// materialize as genuinely empty, uncompleted draft rows: a *planned*
    /// rep count is not a *performed* one, so it is never written into a
    /// SetRecord. Ticket 11's same-machine prefill fills rows from real
    /// history, and it can only do so while the row is untouched.
    @discardableResult
    func start(
        _ template: WorkoutTemplate,
        at gym: Gym?,
        on date: Date = .now
    ) throws -> Workout {
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: gym, on: date)
        workout.sourceTemplateID = template.id
        // D23: history titles read this snapshot, so renaming or deleting the
        // template later cannot retitle the workouts it produced.
        workout.sourceTemplateName = template.name

        var restoredGroups: [UUID: UUID] = [:]
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
            // Restore the superset (D48). Ids are remapped per start rather
            // than reused: two workouts from one template must not share a
            // group id, or a later query keyed on it would conflate them.
            if let templateGroup = item.supersetGroupID {
                let restored = restoredGroups[templateGroup] ?? UUID()
                restoredGroups[templateGroup] = restored
                entry.supersetGroupID = restored
            }
            let count = item.editableTargets.count
            while WorkoutSession.orderedSets(of: entry).count < count {
                try session.addSet(to: entry)
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
        try create(name: name, items: Self.capturableItems(of: workout))
    }

    /// Whether `saveAsTemplate` can succeed for this workout. The UI must
    /// gate the option on this instead of finishing first and discovering
    /// `noExercises` afterwards.
    static func canSaveAsTemplate(_ workout: Workout) -> Bool {
        guard !workout.isDeleted else { return false }
        return !capturableItems(of: workout).isEmpty
    }

    /// The completed structure a template would be built from: entries with a
    /// live exercise and at least one completed set, in scalar order.
    private static func capturableItems(of workout: Workout) -> [TemplateItemDraft] {
        WorkoutSession.orderedEntries(of: workout).compactMap { entry -> TemplateItemDraft? in
            guard let exercise = entry.exercise else { return nil }
            let completed = WorkoutSession.orderedSets(of: entry)
                .filter { $0.completedAt != nil }
            guard !completed.isEmpty else { return nil }
            return TemplateItemDraft(
                exercise: exercise,
                targetRepsBySet: completed.map(\.reps),
                supersetGroupID: entry.supersetGroupID)
        }
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
                supersetGroupID: draft.supersetGroupID,
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
