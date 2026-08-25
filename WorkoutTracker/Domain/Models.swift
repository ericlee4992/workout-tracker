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
    /// The user corrected this exercise's load type by hand, so the catalog
    /// must stop overwriting it.
    ///
    /// What breaks without this: `CatalogSeeder.reconcileExercises` runs
    /// `setIfChanged(&row.loadType, seed.loadType)` on every seeded row at each
    /// catalog version bump. A user who fixes "Seated Dip" from weighted to
    /// assisted would see it work, then silently revert on the next bump — and
    /// their records for that movement would flip direction again with no
    /// error. Optional so stores written before this field migrate lightweightly.
    var loadTypeUserOverridden: Bool?

    @Relationship(deleteRule: .nullify, inverse: \ExerciseEntry.exercise)
    var entries: [ExerciseEntry]?
    @Relationship(deleteRule: .nullify, inverse: \TemplateItem.exercise)
    var templateItems: [TemplateItem]?
    /// Named variations of this movement — grips, stances, single/double
    /// (D37). Cascade: presets have no meaning without their exercise, and
    /// history keeps its own snapshot of the one it used (D36/D23).
    @Relationship(deleteRule: .cascade, inverse: \ExercisePreset.exercise)
    var presets: [ExercisePreset]?

    init(
        id: UUID = UUID(),
        name: String,
        loadType: LoadType = .weighted,
        equipmentTypeTags: [EquipmentTag] = [],
        muscleGroup: String? = nil,
        isSeeded: Bool = false,
        loadTypeUserOverridden: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.loadType = loadType
        self.equipmentTypeTags = equipmentTypeTags
        self.muscleGroup = muscleGroup
        self.isSeeded = isSeeded
        self.loadTypeUserOverridden = loadTypeUserOverridden
    }
}

/// A named variation of an exercise: `wide grip`, `single leg`, `high pulley`
/// (D36–D38, 2026-08-12).
///
/// User-created, never seeded — a worldwide list of every grip on every machine
/// is as unknowable as a worldwide list of gyms (D3's reasoning). Records key on
/// the preset alongside the equipment layers, so two variations of one movement
/// keep separate PRs.
@Model
final class ExercisePreset {
    var id: UUID = UUID()
    var name: String = ""
    /// Scalar ordering within the exercise — never implicit to-many order.
    var order: Int = 0

    var exercise: Exercise?
    @Relationship(deleteRule: .nullify, inverse: \ExerciseEntry.preset)
    var entries: [ExerciseEntry]?

    init(id: UUID = UUID(), name: String, order: Int = 0, exercise: Exercise? = nil) {
        self.id = id
        self.name = name
        self.order = order
        self.exercise = exercise
    }
}

@Model
final class EquipmentModel {
    var id: UUID = UUID()
    var manufacturer: String = ""
    var modelName: String = ""
    /// Linked exercise ids (scalar, per SPEC) — which exercises this model serves.
    var exerciseIDs: [UUID] = []
    /// How the model is loaded (selectorized / plate-loaded / cable / rack).
    /// Display-only browsing metadata (ticket 21, D23): nothing logged reads
    /// it. nil = uncategorized — a seeded row the research left undetermined,
    /// or a user-created model with no type chosen.
    var equipmentType: EquipmentCategory?
    /// Seeded rows are keyed by fixed catalog UUIDs (D24).
    var isSeeded: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \MachineInstance.model)
    var machines: [MachineInstance]?

    init(
        id: UUID = UUID(),
        manufacturer: String,
        modelName: String,
        exerciseIDs: [UUID] = [],
        equipmentType: EquipmentCategory? = nil,
        isSeeded: Bool = false
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.exerciseIDs = exerciseIDs
        self.equipmentType = equipmentType
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
    /// The preset this machine usually is (D38) — preselected when logging,
    /// never binding. A scalar id, not a relationship: a deleted preset must
    /// degrade to "none chosen", not resurrect (same rule as
    /// `AppPreferences.selectedGymID`).
    var defaultPresetID: UUID?
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
        defaultPresetID: UUID? = nil,
        archived: Bool = false,
        gym: Gym? = nil,
        model: EquipmentModel? = nil
    ) {
        self.id = id
        self.label = label
        self.defaultUnit = defaultUnit
        self.defaultPresetID = defaultPresetID
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
    /// When this workout was last edited after being logged (D47, milestone 8
    /// ticket 03). nil = never edited, which is every workout logged before
    /// history editing existed. Optional so those stores migrate lightweightly.
    ///
    /// Shown in the UI on purpose: a silently altered history claims a
    /// certainty it does not have, which is the one thing this app refuses.
    var historyEditedAt: Date?
    var sourceTemplateID: UUID?
    /// D23 history snapshots, captured when the workout starts. History reads
    /// these, never the live `WorkoutTemplate`/`Gym` rows: renaming or
    /// deleting a template must not retitle old workouts, and renaming a gym
    /// must not rewrite old subtitles. Added by ticket 17 (noted in ticket 02).
    var sourceTemplateName: String?
    var snapshotGymName: String?
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

    // MARK: Heart-rate summary (D44), captured at finish.
    //
    // Persisted rather than re-queried: History must render from the app's own
    // store, and asking HealthKit to redraw a six-month-old workout is both
    // slow and answerable differently later. Same reasoning as D23 — what
    // History shows must not change because a source changed its mind.
    //
    // ALL OPTIONAL, and nil means "no sensor ran", which is a different fact
    // from zero. A workout logged without heart rate shows no heart-rate rows
    // at all; `0 BPM` would be a false value rather than a missing one.
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var activeEnergyKilocalories: Double?
    /// Seconds per zone, indexed by `HeartRateZone.rawValue` (0…5). Empty when
    /// no maximum heart rate was resolvable, since without one there are no
    /// zones to attribute time to (D45). An array rather than a dictionary:
    /// CloudKit-compatible scalars only (T2).
    var zoneSeconds: [Int] = []
    /// D45: whether those zones came from an estimated maximum (220−age) rather
    /// than a measured one. nil = no zones recorded. Without it, a summary from
    /// a formula reads as measured fact (codex-review 1.1).
    var zonesFromEstimatedMax: Bool?

    var gym: Gym?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var entries: [ExerciseEntry]?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        notes: String = "",
        sourceTemplateID: UUID? = nil,
        sourceTemplateName: String? = nil,
        snapshotGymName: String? = nil,
        restEndsAt: Date? = nil,
        restStartedAt: Date? = nil,
        restStartedBySetID: UUID? = nil,
        averageHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        activeEnergyKilocalories: Double? = nil,
        zoneSeconds: [Int] = [],
        zonesFromEstimatedMax: Bool? = nil,
        gym: Gym? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.notes = notes
        self.sourceTemplateID = sourceTemplateID
        self.sourceTemplateName = sourceTemplateName
        self.snapshotGymName = snapshotGymName
        self.restEndsAt = restEndsAt
        self.restStartedAt = restStartedAt
        self.restStartedBySetID = restStartedBySetID
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.zoneSeconds = zoneSeconds
        self.zonesFromEstimatedMax = zonesFromEstimatedMax
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
    /// The variation performed (D36–D38). Freezes with the rest of the context
    /// snapshot; switching it on a frozen entry starts a new entry (D19).
    var preset: ExercisePreset?
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
    /// Optional so a store written before presets existed migrates
    /// lightweightly: nil means "nobody recorded which grip this was", which is
    /// the truth about every set logged before 2026-08-12.
    var snapshotPresetID: UUID?
    var snapshotPresetName: String?

    init(
        id: UUID = UUID(),
        order: Int,
        freeWeightTag: EquipmentTag? = nil,
        workout: Workout? = nil,
        exercise: Exercise? = nil,
        machine: MachineInstance? = nil,
        preset: ExercisePreset? = nil,
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
        snapshotGymName: String? = nil,
        snapshotPresetID: UUID? = nil,
        snapshotPresetName: String? = nil
    ) {
        self.id = id
        self.order = order
        self.freeWeightTag = freeWeightTag
        self.workout = workout
        self.exercise = exercise
        self.machine = machine
        self.preset = preset
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
        self.snapshotPresetID = snapshotPresetID
        self.snapshotPresetName = snapshotPresetName
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
    /// The bar this set was loaded on, in this row's `weightUnit` (D39–D40).
    /// nil = no bar: the weight was entered as a total, which is every set
    /// logged before 2026-08-22.
    ///
    /// **This is provenance, not a second source of truth.** `weightValue`
    /// stays the TOTAL lifted, bar included, in bar mode exactly as in total
    /// mode — records, volume, e1RM and the export's weight columns read it and
    /// know nothing about bars. Code that subtracts this field from
    /// `weightValue` to find "the real weight" has misunderstood it; the plates
    /// the user typed are *derived* for display (`BarbellMath.platesPerSide`).
    /// If a stored weight ever became plates-only, every barbell PR would drop
    /// by the weight of a bar and nothing would report an error.
    /// Optional, so stores written before it existed migrate lightweightly.
    var barWeightValue: Double?
    /// The same bar normalized to kilograms, persisted atomically with
    /// `barWeightValue` so stored weights keep the full D25 triple. Optional
    /// for lightweight migration; pre-review bar rows can derive it once from
    /// their value and the row's unit.
    var barNormalizedKg: Double?
    /// Set when these values were *inherited* rather than typed — from
    /// cross-workout prefill or within-session carry-forward — and cleared the
    /// moment the user edits the row.
    ///
    /// It exists so a context change can tell "last session's numbers, sitting
    /// here as a convenience" from "what the user just typed". When the
    /// variation or the equipment changes, the former is a false comparison and
    /// is cleared; the latter is the user's and is never touched (D36).
    /// Optional, so stores written before it existed migrate lightweightly.
    var prefilledAt: Date?

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
        barWeightValue: Double? = nil,
        barNormalizedKg: Double? = nil,
        prefilledAt: Date? = nil,
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
        self.barWeightValue = barWeightValue
        self.barNormalizedKg = barNormalizedKg
        self.prefilledAt = prefilledAt
        self.entry = entry
    }
}

extension SetRecord {
    /// Canonical bar value reconstructed from the as-entered value and the
    /// row's unit. This is also the compatibility path for the brief schema
    /// that persisted `barWeightValue` before `barNormalizedKg` existed.
    var resolvedBarWeight: BarWeight? {
        guard !isDeleted, let barWeightValue else { return nil }
        return BarWeight(value: barWeightValue, unit: weightUnit)
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
    /// Fingerprint of the catalog *content* last reconciled (D24): ids plus
    /// every allowlisted mutable field. The version alone cannot tell a
    /// same-version content change from a no-op, and a row count cannot tell a
    /// healthy store from one row deleted and another inserted. Optional so a
    /// store written before this field existed migrates lightweightly — nil
    /// simply means "unknown", which costs one full reconcile. Added by
    /// codex-review-4 (noted in ticket 02).
    var seededCatalogFingerprint: String?
    /// Whether notification permission has been requested (rest-timer alerts).
    var notificationPermissionRequested: Bool = false
    /// Measured maximum heart rate, if the user has one (D45). nil = fall back
    /// to 220−age, **marked as estimated** everywhere it reaches a screen.
    var measuredMaxHeartRate: Int?
    /// Used only to estimate a maximum heart rate when none is measured. nil
    /// means no zones are shown at all — inventing an age to invent a zone
    /// would be two guesses stacked on each other.
    var birthDate: Date?
    /// Gym the Start screen is set to, remembered across launches (D1,
    /// ticket 17). nil = "No gym", a real choice rather than a missing one.
    /// Scalar id, never a relationship: an archived or deleted gym must
    /// degrade to "No gym", not resurrect. Added by ticket 17 (noted in
    /// ticket 02).
    var selectedGymID: UUID?
    /// Catalog browsing state, remembered between visits (ticket 21). Purely
    /// how lists are *shown* — no logged entry, snapshot or record ever reads
    /// these (D23). Every field is optional: nil grouping = the screen's
    /// default, nil filter = "All". (Optional rather than defaulted, because a
    /// store written before these fields existed has no value to migrate and a
    /// non-optional enum column would fail to materialise.)
    var modelBrowseGrouping: CatalogGrouping?
    var modelBrowseMuscleGroup: String?
    var modelBrowseEquipmentType: EquipmentCategory?
    var machineBrowseGrouping: MachineGrouping?
    var exerciseBrowseMuscleGroup: String?
    var exerciseBrowseEquipmentTag: EquipmentTag?
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        unitPreference: WeightUnit? = nil,
        driftPromptSuppressed: Bool = false,
        globalWorkingRestSeconds: Int = 120,
        globalWarmupRestSeconds: Int = 60,
        seededCatalogVersion: Int = 0,
        seededCatalogFingerprint: String? = nil,
        notificationPermissionRequested: Bool = false,
        measuredMaxHeartRate: Int? = nil,
        birthDate: Date? = nil,
        selectedGymID: UUID? = nil,
        modelBrowseGrouping: CatalogGrouping? = nil,
        modelBrowseMuscleGroup: String? = nil,
        modelBrowseEquipmentType: EquipmentCategory? = nil,
        machineBrowseGrouping: MachineGrouping? = nil,
        exerciseBrowseMuscleGroup: String? = nil,
        exerciseBrowseEquipmentTag: EquipmentTag? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.unitPreference = unitPreference
        self.driftPromptSuppressed = driftPromptSuppressed
        self.globalWorkingRestSeconds = globalWorkingRestSeconds
        self.globalWarmupRestSeconds = globalWarmupRestSeconds
        self.seededCatalogVersion = seededCatalogVersion
        self.seededCatalogFingerprint = seededCatalogFingerprint
        self.notificationPermissionRequested = notificationPermissionRequested
        self.measuredMaxHeartRate = measuredMaxHeartRate
        self.birthDate = birthDate
        self.selectedGymID = selectedGymID
        self.modelBrowseGrouping = modelBrowseGrouping
        self.modelBrowseMuscleGroup = modelBrowseMuscleGroup
        self.modelBrowseEquipmentType = modelBrowseEquipmentType
        self.machineBrowseGrouping = machineBrowseGrouping
        self.exerciseBrowseMuscleGroup = exerciseBrowseMuscleGroup
        self.exerciseBrowseEquipmentTag = exerciseBrowseEquipmentTag
        self.updatedAt = updatedAt
    }
}

extension AppPreferences {
    /// Canonical row among duplicates: latest `updatedAt`, ties broken by
    /// `id` (app-side upsert — no unique constraints under CloudKit).
    static func canonical(of rows: [AppPreferences]) -> AppPreferences? {
        rows.canonical
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
    /// How this exercise rests (D43). nil = `.standard`, which is what every
    /// exercise logged before 2026-08-22 did. Optional so stores written before
    /// heart rate existed migrate lightweightly.
    var restMode: RestMode?
    /// Heart-rate mode only: rest ends when a reading is strictly below this.
    var heartRateThresholdBpm: Int?
    /// Heart-rate mode only: the longest the rest may run before the alarm
    /// fires anyway. Never nil in practice — the resolver substitutes the
    /// default — because a threshold with no cap can wait forever (D43).
    var heartRateCapSeconds: Int?
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        workingRestSeconds: Int? = nil,
        warmupRestSeconds: Int? = nil,
        restMode: RestMode? = nil,
        heartRateThresholdBpm: Int? = nil,
        heartRateCapSeconds: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.workingRestSeconds = workingRestSeconds
        self.warmupRestSeconds = warmupRestSeconds
        self.restMode = restMode
        self.heartRateThresholdBpm = heartRateThresholdBpm
        self.heartRateCapSeconds = heartRateCapSeconds
        self.updatedAt = updatedAt
    }
}

// MARK: - Store

enum WorkoutTrackerStore {
    /// Every model in the app schema — keep exhaustive.
    static let modelTypes: [any PersistentModel.Type] = [
        Exercise.self,
        ExercisePreset.self,
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
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try BarWeightStoreRepair.backfill(in: ModelContext(container))
        return container
    }

    /// Launch argument that makes the app start from an empty store, so
    /// XCUITest runs are deterministic (`WorkoutTrackerUITests`).
    static let uiTestResetArgument = "-uiTestReset"

    static var isUITestReset: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestResetArgument)
    }

    /// Throwaway UI-test store: a dedicated on-disk location wiped on every
    /// launch. On-disk (not in-memory) so the app exercises the real
    /// SwiftData persistence path the tests are meant to drive.
    static func makeUITestContainer() throws -> ModelContainer {
        let directory = URL.cachesDirectory.appending(
            path: "UITestStore", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        return try makeContainer(url: directory.appending(path: "UITestStore.store"))
    }
}
