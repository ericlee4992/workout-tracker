import Foundation
import SwiftData

/// Scope selected when correcting the catalog model attached to a machine.
enum ModelCorrectionScope: Sendable, Equatable {
    /// Change the live machine only. Existing snapshots keep their original
    /// model id/name and therefore remain in the original history layer.
    case futureOnly
    /// Change the live machine and rewrite snapshots belonging to this exact
    /// machine. Other machines using the old model are intentionally ignored.
    case applyToPast
}

enum EquipmentLifecycleError: Error, Equatable {
    case seededCatalogRowIsReadOnly
    case emptyName
}

extension Gym {
    /// The machines a picker may offer at this gym, label-sorted (ticket 10).
    /// An archived gym offers none — archiving a gym archives its pickable
    /// inventory with it, the same way an archived machine disappears. Every
    /// machine list goes through here so that rule cannot be forgotten at one
    /// call site; history stays visible because it reads snapshots, not this.
    var activeMachines: [MachineInstance] {
        guard !archived else { return [] }
        return (machines ?? [])
            .filter { !$0.archived }
            .sorted { $0.label < $1.label }
    }
}

/// Ticket 10's persistence boundary for rename, archive, and model-correction
/// operations. History display remains snapshot-driven; the sole operation
/// allowed to rewrite historical equipment context is an explicit
/// `.applyToPast` model correction (D10).
struct EquipmentLifecycle {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func rename(_ gym: Gym, to name: String) throws {
        gym.name = try validated(name)
        try context.save()
    }

    func rename(_ machine: MachineInstance, to label: String) throws {
        machine.label = try validated(label)
        try context.save()
    }

    func rename(_ model: EquipmentModel, manufacturer: String, modelName: String) throws {
        guard !model.isSeeded else {
            throw EquipmentLifecycleError.seededCatalogRowIsReadOnly
        }
        model.manufacturer = try validated(manufacturer)
        model.modelName = try validated(modelName)
        try context.save()
    }

    func rename(_ exercise: Exercise, to name: String) throws {
        guard !exercise.isSeeded else {
            throw EquipmentLifecycleError.seededCatalogRowIsReadOnly
        }
        exercise.name = try validated(name)
        try context.save()
    }

    /// Creates a user-owned exercise (`isSeeded == false`, D24's user ID
    /// space) and optionally links it to `model` by appending its id to the
    /// model's `exerciseIDs` — which is what makes an unlisted movement on a
    /// known station selectable there next time (D7, ticket 19).
    ///
    /// Linking to a *seeded* model is deliberately allowed: the station the
    /// user is standing at is usually a catalog one. `exerciseIDs` is an
    /// allowlisted seeded field (D24), so `CatalogSeeder` re-merges these
    /// user-added links on a catalog version bump rather than dropping them.
    @discardableResult
    func createExercise(
        name: String,
        loadType: LoadType = .weighted,
        equipmentTypeTags: [EquipmentTag] = [],
        muscleGroup: String? = nil,
        linkedTo model: EquipmentModel? = nil
    ) throws -> Exercise {
        let exercise = Exercise(
            name: try validated(name),
            loadType: loadType,
            equipmentTypeTags: equipmentTypeTags,
            muscleGroup: normalized(muscleGroup),
            isSeeded: false)
        context.insert(exercise)
        if let model, !model.exerciseIDs.contains(exercise.id) {
            model.exerciseIDs.append(exercise.id)
        }
        try context.save()
        return exercise
    }

    /// D2 (ticket 17): a gym's whole identity is editable — name, city, and
    /// default unit. A wrong unit used to mean archive-and-recreate, which
    /// stranded the gym's machines and memory. Gyms are user-owned, so D24's
    /// seeded-catalog read-only rule does not apply here (it still guards
    /// models and exercises).
    func update(
        _ gym: Gym,
        name: String,
        city: String?,
        defaultUnit: WeightUnit?
    ) throws {
        gym.name = try validated(name)
        gym.city = normalized(city)
        gym.defaultUnit = defaultUnit
        try context.save()
    }

    /// D2: a machine's label and default unit are editable. Its *model* is
    /// not changed here — that is a correction with past-vs-future
    /// consequences (D10), owned by `correctModel(of:to:scope:)`.
    func update(
        _ machine: MachineInstance,
        label: String,
        defaultUnit: WeightUnit?
    ) throws {
        machine.label = try validated(label)
        machine.defaultUnit = defaultUnit
        try context.save()
    }

    func archive(_ machine: MachineInstance) throws {
        machine.archived = true
        try context.save()
    }

    func archive(_ gym: Gym) throws {
        gym.archived = true
        try context.save()
    }

    /// Corrects a machine's model. Applying to past workouts rewrites both
    /// the grouping UUID and display string on snapshots for this machine;
    /// all other snapshot fields remain frozen.
    func correctModel(
        of machine: MachineInstance,
        to newModel: EquipmentModel?,
        scope: ModelCorrectionScope
    ) throws {
        if scope == .applyToPast {
            let machineID = machine.id
            let entries = try context.fetch(FetchDescriptor<ExerciseEntry>(
                predicate: #Predicate { $0.snapshotMachineID == machineID }
            ))
            for entry in entries {
                entry.snapshotModelID = newModel?.id
                entry.snapshotModelName = newModel?.displayName
            }
        }
        machine.model = newModel
        try context.save()
    }

    /// Resolves remembered equipment only when the gym and machine are both
    /// still active and the machine still belongs to that gym. Stale memory
    /// rows remain harmless scalar history rather than being destructively
    /// deleted during archival.
    func rememberedMachine(for exercise: Exercise, at gym: Gym) throws -> MachineInstance? {
        guard !gym.archived else { return nil }
        let gymID = gym.id
        let exerciseID = exercise.id
        let rows = try context.fetch(FetchDescriptor<GymExerciseMemory>(
            predicate: #Predicate { $0.gymID == gymID && $0.exerciseID == exerciseID }
        ))
        guard let memory = rows.canonical,
              let machineID = memory.machineID else { return nil }

        let machines = try context.fetch(FetchDescriptor<MachineInstance>(
            predicate: #Predicate { $0.id == machineID && !$0.archived }
        ))
        return machines.first { $0.gym?.id == gymID && $0.gym?.archived == false }
    }

    /// Optional free text: blank and whitespace both mean "not set".
    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    private func validated(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EquipmentLifecycleError.emptyName }
        return trimmed
    }
}
