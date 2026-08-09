import Foundation
import SwiftData

// Milestone-2 SwiftData schema — the complete data-model sketch from
// docs/SPEC.md as revised 2026-08-08 (D19–D25, T1/T2).
//
// CloudKit-compatibility rules (T2), enforced throughout:
// - identity via plain `UUID` attributes with defaults — never `@Attribute(.unique)`
// - ALL relationships optional, each pair with an explicit inverse declared once
//   (on the to-many side)
// - delete rules are deliberate `.cascade`/`.nullify` — never `.deny`
// - ordering via scalar `order` fields, never implicit to-many order
// - every non-optional scalar has an inline default value
//
// Later tickets may add fields only with an explicit note in ticket 02.

// MARK: - Catalog

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var loadType: LoadType = LoadType.weighted
    var equipmentTypeTags: [EquipmentTag] = []
    /// Light muscle grouping, e.g. "Chest"; nil when uncategorized.
    var muscleGroup: String?
    /// Seeded catalog rows are reconciled by version (D24) and not user-editable.
    var isSeeded: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \ExerciseEntry.exercise)
    var entries: [ExerciseEntry]?
    @Relationship(deleteRule: .nullify, inverse: \TemplateItem.exercise)
    var templateItems: [TemplateItem]?

    init(
        id: UUID = UUID(),
        name: String,
        loadType: LoadType = .weighted,
        equipmentTypeTags: [EquipmentTag] = [],
        muscleGroup: String? = nil,
        isSeeded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.loadType = loadType
        self.equipmentTypeTags = equipmentTypeTags
        self.muscleGroup = muscleGroup
        self.isSeeded = isSeeded
    }
}

@Model
final class EquipmentModel {
    var id: UUID = UUID()
    var manufacturer: String = ""
    var modelName: String = ""
    /// Linked exercise ids (scalar, per SPEC) — which exercises this model serves.
    var exerciseIDs: [UUID] = []
    /// Seeded rows are keyed by fixed catalog UUIDs (D24).
    var isSeeded: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \MachineInstance.model)
    var machines: [MachineInstance]?

    init(
        id: UUID = UUID(),
        manufacturer: String,
        modelName: String,
        exerciseIDs: [UUID] = [],
        isSeeded: Bool = false
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.exerciseIDs = exerciseIDs
        self.isSeeded = isSeeded
    }

    var displayName: String { "\(manufacturer) \(modelName)" }
}

// MARK: - Gyms & machines

@Model
final class Gym {
    var id: UUID = UUID()
    var name: String = ""
    var city: String?
    var defaultUnit: WeightUnit?
    var notes: String = ""
    /// Archival replaces deletion so workout history keeps resolving (never delete for archival).
    var archived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \MachineInstance.gym)
    var machines: [MachineInstance]?
    @Relationship(deleteRule: .nullify, inverse: \Workout.gym)
    var workouts: [Workout]?

    init(
        id: UUID = UUID(),
        name: String,
        city: String? = nil,
        defaultUnit: WeightUnit? = nil,
        notes: String = "",
        archived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.defaultUnit = defaultUnit
        self.notes = notes
        self.archived = archived
    }
}

@Model
final class MachineInstance {
    var id: UUID = UUID()
    var label: String = ""
    var defaultUnit: WeightUnit?
    /// Archival replaces deletion so workout history keeps resolving (never delete for archival).
    var archived: Bool = false

    var gym: Gym?
    var model: EquipmentModel?
    @Relationship(deleteRule: .nullify, inverse: \ExerciseEntry.machine)
    var entries: [ExerciseEntry]?

    init(
        id: UUID = UUID(),
        label: String,
        defaultUnit: WeightUnit? = nil,
        archived: Bool = false,
        gym: Gym? = nil,
        model: EquipmentModel? = nil
    ) {
        self.id = id
        self.label = label
        self.defaultUnit = defaultUnit
        self.archived = archived
        self.gym = gym
        self.model = model
    }
}

// MARK: - Templates

@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TemplateItem.template)
    var items: [TemplateItem]?

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

@Model
final class TemplateItem {
    var id: UUID = UUID()
    /// Scalar ordering within the template — never implicit to-many order.
    var order: Int = 0
    var targetSets: Int?
    var targetReps: Int?
    /// Per-set-slot target reps in scalar set order. Added by ticket 15 so
    /// templates can retain differing rep targets across their set rows.
    var targetRepsBySet: [Int?] = []
    // No rest durations in v1 (D22).

    var template: WorkoutTemplate?
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        order: Int,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetRepsBySet: [Int?] = [],
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRepsBySet = targetRepsBySet
        self.exercise = exercise
    }
}

// MARK: - Workout history

@Model
final class Workout {
    var id: UUID = UUID()
    /// Lifecycle: nil `finishedAt` = active; cancel deletes; Finish deletes
    /// uncompleted draft rows and zero-completed-set entries. At most one
    /// active workout — the newest keeps running, older strays auto-finish.
    var startedAt: Date = Date()
    var finishedAt: Date?
    var notes: String = ""
    /// Scalar reference to the template this workout was started from, if any.
    var sourceTemplateID: UUID?
    /// Persisted rest-timer end so the timer survives relaunch.
    var restEndsAt: Date?
    /// When the current rest timer started. Persisted alongside `restEndsAt`
    /// so the *total* duration (end − start, including any +15s) survives
    /// relaunch — the progress bar's denominator must not be the remaining
    /// time, or a restored timer renders as full.
    var restStartedAt: Date?
    /// Set whose completion started/replaced the current rest timer. Needed
    /// so un-completing that exact set cancels the timer, including after a
    /// relaunch. Added by ticket 14 (noted in ticket 02).
    var restStartedBySetID: UUID?

    var gym: Gym?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var entries: [ExerciseEntry]?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        notes: String = "",
        sourceTemplateID: UUID? = nil,
        restEndsAt: Date? = nil,
        restStartedAt: Date? = nil,
        restStartedBySetID: UUID? = nil,
        gym: Gym? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.notes = notes
        self.sourceTemplateID = sourceTemplateID
        self.restEndsAt = restEndsAt
        self.restStartedAt = restStartedAt
        self.restStartedBySetID = restStartedBySetID
        self.gym = gym
    }
}

@Model
final class ExerciseEntry {
    var id: UUID = UUID()
    /// Scalar ordering within the workout — never implicit to-many order.
    var order: Int = 0
    /// Free-weight equipment choice when no machine is involved (D19).
    var freeWeightTag: EquipmentTag?

    var workout: Workout?
    var exercise: Exercise?
    var machine: MachineInstance?
    @Relationship(deleteRule: .cascade, inverse: \SetRecord.entry)
    var sets: [SetRecord]?

    // Context snapshot (D23): stable UUIDs + loadType + freeWeightTag +
    // display strings, frozen once the entry's first set completes (D19).
    // Historical queries group by these values, never live relationships.
    /// When the snapshot was captured (first set completion). nil = draft
    /// entry, equipment still editable. Non-nil = equipment frozen (D19) —
    /// permanently, even if the completion is later undone, so this field is
    /// never reset. Added by ticket 07 (noted in ticket 02).
    var snapshotCapturedAt: Date?
    var snapshotExerciseID: UUID = UUID()
    var snapshotMachineID: UUID?
    var snapshotModelID: UUID?
    var snapshotGymID: UUID?
    var snapshotLoadType: LoadType = LoadType.weighted
    var snapshotFreeWeightTag: EquipmentTag?
    var snapshotExerciseName: String = ""
    var snapshotMachineLabel: String?
    var snapshotModelName: String?
    var snapshotGymName: String?

    init(
        id: UUID = UUID(),
        order: Int,
        freeWeightTag: EquipmentTag? = nil,
        workout: Workout? = nil,
        exercise: Exercise? = nil,
        machine: MachineInstance? = nil,
        snapshotCapturedAt: Date? = nil,
        snapshotExerciseID: UUID,
        snapshotMachineID: UUID? = nil,
        snapshotModelID: UUID? = nil,
        snapshotGymID: UUID? = nil,
        snapshotLoadType: LoadType,
        snapshotFreeWeightTag: EquipmentTag? = nil,
        snapshotExerciseName: String,
        snapshotMachineLabel: String? = nil,
        snapshotModelName: String? = nil,
        snapshotGymName: String? = nil
    ) {
        self.id = id
        self.order = order
        self.freeWeightTag = freeWeightTag
        self.workout = workout
        self.exercise = exercise
        self.machine = machine
        self.snapshotCapturedAt = snapshotCapturedAt
        self.snapshotExerciseID = snapshotExerciseID
        self.snapshotMachineID = snapshotMachineID
        self.snapshotModelID = snapshotModelID
        self.snapshotGymID = snapshotGymID
        self.snapshotLoadType = snapshotLoadType
        self.snapshotFreeWeightTag = snapshotFreeWeightTag
        self.snapshotExerciseName = snapshotExerciseName
        self.snapshotMachineLabel = snapshotMachineLabel
        self.snapshotModelName = snapshotModelName
        self.snapshotGymName = snapshotGymName
    }
}

@Model
final class SetRecord {
    var id: UUID = UUID()
    /// Scalar ordering within the entry — never implicit to-many order.
    var order: Int = 0
    var type: SetType = SetType.working
    /// Draft optionality: reps/weightValue/normalizedKg stay nil until completed.
    var reps: Int?
    var weightValue: Double?
    var weightUnit: WeightUnit = WeightUnit.kg
    /// Recomputed atomically from (weightValue, weightUnit) on any edit (D25).
    var normalizedKg: Double?
    /// nil = not completed; only completed sets feed records/volume/prefill.
    var completedAt: Date?

    var entry: ExerciseEntry?

    init(
        id: UUID = UUID(),
        order: Int,
        type: SetType = .working,
        reps: Int? = nil,
        weightValue: Double? = nil,
        weightUnit: WeightUnit = .kg,
        normalizedKg: Double? = nil,
        completedAt: Date? = nil,
        entry: ExerciseEntry? = nil
    ) {
        self.id = id
        self.order = order
        self.type = type
        self.reps = reps
        self.weightValue = weightValue
        self.weightUnit = weightUnit
        self.normalizedKg = normalizedKg
        self.completedAt = completedAt
        self.entry = entry
    }
}

// MARK: - Memory & preferences

/// "Last machine used for this exercise at this gym". Scalar ids only —
/// app-level upsert; duplicates resolved by latest `updatedAt` then `id`
/// (no unique constraints allowed under CloudKit).
@Model
final class GymExerciseMemory {
    var id: UUID = UUID()
    var gymID: UUID = UUID()
    var exerciseID: UUID = UUID()
    /// nil when the exercise was last done without a machine (free weight).
    var machineID: UUID?
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        gymID: UUID,
        exerciseID: UUID,
        machineID: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.gymID = gymID
        self.exerciseID = exerciseID
        self.machineID = machineID
        self.updatedAt = updatedAt
    }
}

/// App-level preferences, stored as a single row upserted app-side
/// (duplicates resolved by latest `updatedAt` then `id` — no unique constraints).
@Model
final class AppPreferences {
    var id: UUID = UUID()
    /// nil until first launch resolves the default from the locale's measurement system.
    var unitPreference: WeightUnit?
    /// Suppresses the machine/gym drift prompt.
    var driftPromptSuppressed: Bool = false
    /// Global rest defaults (D22): 2:00 working (failure uses working), 1:00 warmup.
    var globalWorkingRestSeconds: Int = 120
    var globalWarmupRestSeconds: Int = 60
    /// Version of the seeded catalog last reconciled (D24).
    var seededCatalogVersion: Int = 0
    /// Whether notification permission has been requested (rest-timer alerts).
    var notificationPermissionRequested: Bool = false
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        unitPreference: WeightUnit? = nil,
        driftPromptSuppressed: Bool = false,
        globalWorkingRestSeconds: Int = 120,
        globalWarmupRestSeconds: Int = 60,
        seededCatalogVersion: Int = 0,
        notificationPermissionRequested: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.unitPreference = unitPreference
        self.driftPromptSuppressed = driftPromptSuppressed
        self.globalWorkingRestSeconds = globalWorkingRestSeconds
        self.globalWarmupRestSeconds = globalWarmupRestSeconds
        self.seededCatalogVersion = seededCatalogVersion
        self.notificationPermissionRequested = notificationPermissionRequested
        self.updatedAt = updatedAt
    }
}

extension AppPreferences {
    /// Canonical row among duplicates: latest `updatedAt`, ties broken by
    /// `id` (app-side upsert — no unique constraints under CloudKit).
    static func canonical(of rows: [AppPreferences]) -> AppPreferences? {
        rows.max {
            ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString)
        }
    }

    /// Canonical AppPreferences row for `context`, inserting a fresh row when
    /// none exists yet (first launch).
    static func canonical(in context: ModelContext) throws -> AppPreferences {
        if let canonical = canonical(of: try context.fetch(FetchDescriptor<AppPreferences>())) {
            return canonical
        }
        let fresh = AppPreferences()
        context.insert(fresh)
        return fresh
    }

    /// First-launch unit-preference resolution: when unset, derive the default
    /// from the locale measurement system (US → lb, else kg) and persist it.
    /// Idempotent — an already-set preference is never overwritten.
    @discardableResult
    static func ensureUnitPreference(
        in context: ModelContext,
        measurementSystem: Locale.MeasurementSystem = Locale.current.measurementSystem
    ) throws -> AppPreferences {
        let preferences = try canonical(in: context)
        if preferences.unitPreference == nil {
            preferences.unitPreference = UnitPrecedence.firstLaunchDefault(for: measurementSystem)
            preferences.updatedAt = .now
        }
        if context.hasChanges {
            try context.save()
        }
        return preferences
    }
}

/// Per-exercise rest override (D22 precedence: override → global default).
/// Scalar exercise id; app-level upsert like GymExerciseMemory.
@Model
final class ExerciseRestOverride {
    var id: UUID = UUID()
    var exerciseID: UUID = UUID()
    /// nil = fall through to the global default for that set type.
    var workingRestSeconds: Int?
    var warmupRestSeconds: Int?
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        workingRestSeconds: Int? = nil,
        warmupRestSeconds: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.workingRestSeconds = workingRestSeconds
        self.warmupRestSeconds = warmupRestSeconds
        self.updatedAt = updatedAt
    }
}

// MARK: - Store

enum WorkoutTrackerStore {
    /// Every model in the app schema — keep exhaustive.
    static let modelTypes: [any PersistentModel.Type] = [
        Exercise.self,
        EquipmentModel.self,
        Gym.self,
        MachineInstance.self,
        WorkoutTemplate.self,
        TemplateItem.self,
        Workout.self,
        ExerciseEntry.self,
        SetRecord.self,
        GymExerciseMemory.self,
        AppPreferences.self,
        ExerciseRestOverride.self,
    ]

    static var schema: Schema { Schema(modelTypes) }

    /// On-disk container. `url` overrides the store location (tests);
    /// nil uses the default application-support location.
    static func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let schema = Self.schema
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
