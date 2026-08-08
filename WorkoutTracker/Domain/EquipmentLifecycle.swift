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
        guard let memory = rows.max(by: {
            ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString)
        }), let machineID = memory.machineID else { return nil }

        let machines = try context.fetch(FetchDescriptor<MachineInstance>(
            predicate: #Predicate { $0.id == machineID && !$0.archived }
        ))
        return machines.first { $0.gym?.id == gymID && $0.gym?.archived == false }
    }

    private func validated(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EquipmentLifecycleError.emptyName }
        return trimmed
    }
}
