import Foundation
import SwiftData

// Floodlight redesign ticket 07 — what a scan confirms and saves, and what a model correction
// reaches. Pure rules first (unit-tested with values), then the two SwiftData entry points the
// sheets and the machine form share, so a scanned machine is saved by ONE implementation
// whether the scan adds it directly (the gym page, routine setup) or fills the form.

enum ScanMachine {

    // MARK: The proposal the user confirmed

    /// The name the result prefills. A confirmed hand-typed name is the user's (D3); an unedited
    /// answer that matched a catalog model is named by its movement, as picking that model in
    /// the form names it (`MachineLabelDefaults`). Otherwise the AI's own short label.
    static func prefilledLabel(
        for proposal: EquipmentIdentification, catalogModelName: String?, modelExerciseNames: [String]
    ) -> String {
        guard !proposal.labelWasEdited, let catalogModelName else { return proposal.label }
        return MachineLabelDefaults.label(modelName: catalogModelName, exerciseNames: modelExerciseNames)
    }

    /// The proposal as Add (or the form) receives it. A catalog model supplies its own exercises
    /// (D24); choosing the generic identity, an ambiguous answer and a generic answer all save
    /// with no model claimed (D56), so the identity is cleared rather than left for a later
    /// resolution to re-claim. The AI's answer itself is kept by the caller until then, so
    /// "Use generic identity" stays reversible without a second identification.
    static func confirmed(
        _ proposal: EquipmentIdentification, resolution: EquipmentIdentityResolution,
        genericChosen: Bool
    ) -> EquipmentIdentification {
        var result = proposal
        result.label = proposal.label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (genericChosen, resolution) {
        case (false, .catalog(let model)):
            if !model.exerciseIDs.isEmpty { result.exerciseIDs = model.exerciseIDs }
        case (false, .newModel):
            break
        default:
            result.identity = "generic"
            result.manufacturer = ""
            result.modelName = ""
        }
        return result
    }

    /// Whether Add may run: a name and at least one exercise (the machine must serve something).
    static func canConfirm(label: String, exerciseIDs: [UUID]) -> Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exerciseIDs.isEmpty
    }

    // MARK: Suggested exercises (the Change exercises picker)

    struct ExerciseOption: Equatable {
        var id: UUID
        var name: String
        var muscleGroup: String?
        /// A machine or Smith exercise — what a scanned machine plausibly serves.
        var isMachine: Bool
    }

    /// The picker's "Suggested" group: what the AI proposed and what is already picked, then
    /// the machine exercises of the same muscle groups, A–Z. Each once.
    static func suggestedExercises(
        proposed: [UUID], selected: [UUID], among exercises: [ExerciseOption]
    ) -> [UUID] {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let seeds = (proposed + selected).compactMap { byID[$0] }
        let groups = Set(seeds.compactMap(\.muscleGroup))
        let related = exercises
            .filter { $0.isMachine && $0.muscleGroup.map(groups.contains) == true }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var seen = Set<UUID>()
        return (seeds + related).map(\.id).filter { seen.insert($0).inserted }
    }

    // MARK: SwiftData

    /// The model a confirmed proposal claims, created when it names a visible model the catalog
    /// lacks (D56: a user-space model with the confirmed exercises, never seeded).
    static func model(
        for proposal: EquipmentIdentification, exerciseIDs: [UUID], context: ModelContext
    ) throws -> EquipmentModel? {
        let models = try context.fetch(FetchDescriptor<EquipmentModel>())
        let seededNames = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isSeeded }))
            .map(\.name)
        switch EquipmentIdentityResolution.resolve(proposal, among: models, exerciseNames: seededNames) {
        case .catalog(let existing):
            return existing
        case .newModel(let manufacturer, let name):
            let custom = EquipmentModel(manufacturer: manufacturer, modelName: name,
                                        exerciseIDs: sortedIDs(exerciseIDs), isSeeded: false)
            context.insert(custom)
            return custom
        case .generic, .ambiguous:
            return nil
        }
    }

    /// Adds the confirmed machine to `gym` and saves. Its exercises are instance-local only when
    /// no model supplies them — a model's own list is the single source otherwise (D24).
    @discardableResult
    static func add(
        _ confirmed: EquipmentIdentification, to gym: Gym, context: ModelContext
    ) throws -> MachineInstance {
        let model = try model(for: confirmed, exerciseIDs: confirmed.exerciseIDs, context: context)
        let machine = MachineInstance(label: confirmed.label.trimmingCharacters(in: .whitespacesAndNewlines),
                                      gym: gym, model: model)
        machine.recognizedExerciseIDs = model?.exerciseIDs.isEmpty != false ? sortedIDs(confirmed.exerciseIDs) : []
        context.insert(machine)
        try context.save()
        return machine
    }

    /// A live machine at `gym` already on `modelID` — the result's duplicate warning. Deleted
    /// (archived) machines do not count; the first by label is named.
    static func existing(modelID: UUID, at gym: Gym) -> MachineInstance? {
        (gym.machines ?? [])
            .filter { !$0.archived && $0.model?.id == modelID }
            .min { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    static func sortedIDs(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }.sorted { $0.uuidString < $1.uuidString }
    }
}

// MARK: - Correct Model (D10)

enum ModelCorrection {
    /// What "Apply to Past Workouts Too" rewrites: every entry whose SNAPSHOT is this machine
    /// (`EquipmentLifecycle.correctModel`). Workouts are distinct; sets are completed ones.
    struct Impact: Equatable {
        var workouts: Int
        var sets: Int
    }

    struct EntryInput: Equatable {
        var workoutID: UUID?
        var completedSets: Int
    }

    static func impact(of entries: [EntryInput]) -> Impact {
        Impact(workouts: Set(entries.compactMap(\.workoutID)).count,
               sets: entries.reduce(0) { $0 + $1.completedSets })
    }

    static func impact(of machine: MachineInstance, context: ModelContext) throws -> Impact {
        let machineID = machine.id
        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate { $0.snapshotMachineID == machineID }))
        return impact(of: entries.map {
            EntryInput(workoutID: $0.workout?.id,
                       completedSets: ($0.sets ?? []).filter { $0.completedAt != nil }.count)
        })
    }

    struct ModelOption: Equatable {
        var id: UUID
        var modelName: String
        var displayName: String
        var exerciseIDs: [UUID]
    }

    /// The likely corrections: other models serving any of this machine's exercises — those
    /// named for the machine's label first ("Lat Pulldown"), then the most shared exercises,
    /// then A–Z by display name. At most `limit`.
    static func suggestions(
        machineLabel: String, exerciseIDs: [UUID], currentModelID: UUID?,
        among models: [ModelOption], limit: Int = 5
    ) -> [UUID] {
        let served = Set(exerciseIDs)
        guard !served.isEmpty else { return [] }
        let movement = machineLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func named(_ model: ModelOption) -> Bool {
            !movement.isEmpty && model.modelName.lowercased().contains(movement)
        }
        return models
            .filter { $0.id != currentModelID && !served.isDisjoint(with: $0.exerciseIDs) }
            .sorted { a, b in
                if named(a) != named(b) { return named(a) }
                let sa = served.intersection(a.exerciseIDs).count, sb = served.intersection(b.exerciseIDs).count
                if sa != sb { return sa > sb }
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            }
            .prefix(limit)
            .map(\.id)
    }
}
