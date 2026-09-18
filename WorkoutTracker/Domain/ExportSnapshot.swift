import Foundation

// Milestone 3, ticket 01 — the export's value-type layer. Pure: no UI, no
// SwiftData. `ExportCollector` builds one of these from a `ModelContext`;
// `ExportJSON` and `ExportCSV` render it.
//
// Everything the user created is in here (D30) — including draft sets and an
// unfinished workout. What is *not* in here: the shipped seeded catalog beyond
// the rows the user's data actually references (D28), and anything derived
// (PRs, e1RM, volume — SPEC: derived, never source-of-truth).
//
// Timestamps are already-formatted ISO 8601 strings with a UTC offset (D31),
// not `Date`s. Formatting once, at collection time, is what makes the two
// renderers agree to the character and makes a JSON round-trip exact — an
// ISO 8601 `Date` round-trip silently truncates sub-second precision.

struct ExportSnapshot: Codable, Equatable {
    /// Bumped on any breaking shape change. A consumer that does not
    /// recognise the version should refuse the file rather than guess.
    /// 2 — presets (D36) added `presetID`/`presetName` to every entry, and two
    /// columns to the CSV. Readers of version 1 are not wrong about anything
    /// they already understood, but the shape did change, so the number moves.
    /// 3 — bar weight (D39) added `barWeight`/`barWeightKg` to every set, and
    /// two columns to the CSV. Same story: `weight` still means the total
    /// lifted, so a version-2 reader misunderstands nothing it already read.
    /// 4 — heart rate (D44) added a per-workout summary: average and maximum
    /// bpm, active energy, and seconds per zone. Absent, not zero, when no
    /// sensor ran — a reader must treat missing as "not measured".
    /// 5 — milestone 8. Supersets (D48) add `entries[].supersetGroupID`; ticket
    /// 02 adds `exercises[].loadTypeUserOverridden`, without which a restore
    /// silently reverts a corrected load type at the next catalog version; and
    /// D47 adds `workouts[].historyEditedAt`, without which a restored history
    /// claims never to have been edited. All three are optional, so a v1–v4
    /// file still decodes.
    /// 6 — milestone 9, ticket 02 (D50). `workouts[].name`, the title the user
    /// typed, beside `sourceTemplateName` — intent and provenance are different
    /// facts. The CSV APPENDS `workoutTypedName` (column 36); column 4
    /// `workoutName` keeps meaning the template, so a v1–v5 consumer reading
    /// provenance there is not lied to.
    /// 7 — milestone 9, ticket 04 (D51). `entries[].reclassifiedAt` and
    /// `reclassifiedFromExerciseName`: the provenance of the dumbbell
    /// reclassification, on the row it rewrote; and the preferences record of
    /// the run (`dumbbellHistoryMovedSets/At`, `dumbbellHistoryCheckedAt`). A
    /// backup that carried the rewritten identity without the fact of the
    /// rewrite would be a history claiming to be untouched (codex-review 04).
    /// CSV appends column 37 `reclassifiedFrom`.
    /// 8 — milestone 9, ticket 05. `workouts[].heartRateSeries` (+ its bucket
    /// width) and `basalEnergyKilocalories`. JSON only: an array has no honest
    /// place in a flat ledger of sets, exactly as `zoneSeconds` (v4). Absent
    /// when no sensor ran — missing is not zero.
    /// 9 — finish-graph ticket 01. `workouts[].heartRateSeriesLow` / `High`,
    /// the per-bucket range beside the mean, so a restore draws the chart the
    /// phone drew. Omitted when empty — a v8 workout restored has means only
    /// and draws from them. JSON only, like the mean; CSV unchanged.
    /// 10 — cardio segments, measured/entered distance, active intervals and routes.
    static let currentSchemaVersion = 10

    var schemaVersion: Int = ExportSnapshot.currentSchemaVersion
    var exportedAt: String
    /// Marketing version + build, e.g. `1.0 (3)`. Empty when unavailable.
    var appVersion: String
    /// D28: which catalog the omitted seeded rows can be reproduced from.
    var seededCatalogVersion: Int
    var counts: Counts
    var preferences: Preferences?
    var gyms: [Gym] = []
    /// Every preset the user has defined (D36–D38) — including ones never
    /// logged against. They are user data, and the JSON is the complete backup
    /// (D30): "only the presets you happened to use" would restore a
    /// half-erased list (codex-review, finding 1).
    var presets: [Preset] = []
    var machines: [Machine] = []
    var exercises: [Exercise] = []
    var equipmentModels: [EquipmentModel] = []
    var templates: [Template] = []
    var workouts: [Workout] = []
    var gymExerciseMemory: [GymMemory] = []
    var exerciseRestOverrides: [RestOverride] = []
}

// MARK: - Counts

extension ExportSnapshot {
    /// Header numbers, so a consumer (and the export screen) can see at a
    /// glance whether the file holds what it should.
    struct Counts: Codable, Equatable {
        var workouts: Int = 0
        var entries: Int = 0
        var sets: Int = 0
        /// Sets with a `completedAt` — the ones records and volume count.
        var completedSets: Int = 0
        var gyms: Int = 0
        var machines: Int = 0
        var exercises: Int = 0
        var equipmentModels: Int = 0
        var templates: Int = 0
        var presets: Int = 0
        var cardioSegments: Int? = nil
    }
}

// MARK: - Preferences

extension ExportSnapshot {
    /// The canonical `AppPreferences` row. Catalog browsing state is
    /// deliberately absent: it is display-only (D23), meaningless outside the
    /// screen that wrote it, and restoring it would restore nothing the user
    /// would miss. `seededCatalogFingerprint` is likewise omitted — it is
    /// derived from the bundled catalog, not user data.
    struct Preferences: Codable, Equatable {
        var unitPreference: WeightUnit?
        var driftPromptSuppressed: Bool
        var globalWorkingRestSeconds: Int
        var globalWarmupRestSeconds: Int
        var seededCatalogVersion: Int
        var notificationPermissionRequested: Bool
        var selectedGymID: UUID?
        /// D45. The user typed these; restoring a backup without them erases
        /// their measured maximum and the basis for every zone
        /// (codex-review 5.1, critical).
        var measuredMaxHeartRate: Int?
        var birthDate: String?
        var updatedAt: String
        /// v7 (D51): the reclassification's record — cumulative sets moved,
        /// when it last moved any, and when it first ran at all.
        var dumbbellHistoryMovedSets: Int? = nil
        var dumbbellHistoryMovedAt: String? = nil
        var dumbbellHistoryCheckedAt: String? = nil
    }
}

// MARK: - Catalog & places

extension ExportSnapshot {
    struct Gym: Codable, Equatable {
        var id: UUID
        var name: String
        var city: String?
        var defaultUnit: WeightUnit?
        var notes: String
        /// Archived gyms export too: history still resolves through them.
        var archived: Bool
    }

    struct Machine: Codable, Equatable {
        var id: UUID
        var label: String
        var gymID: UUID?
        var modelID: UUID?
        var defaultUnit: WeightUnit?
        /// The preset this machine usually is (D38).
        var defaultPresetID: UUID?
        var archived: Bool
    }

    /// A named variation of an exercise (D36–D38).
    struct Preset: Codable, Equatable {
        var id: UUID
        var name: String
        var order: Int
        var exerciseID: UUID?
    }

    struct Exercise: Codable, Equatable {
        var id: UUID
        var name: String
        var loadType: LoadType
        var equipmentTypeTags: [EquipmentTag]
        var muscleGroup: String?
        /// True for a seeded row the user's data referenced (D28).
        var isSeeded: Bool
        /// The user corrected this seeded row's load type by hand (milestone 8
        /// ticket 02). codex-review (critical): without this in the backup, a
        /// restore followed by catalog reconciliation silently reverts the
        /// correction and flips the direction of every future record for that
        /// movement. Optional so v1 files still decode.
        var loadTypeUserOverridden: Bool?
    }

    struct EquipmentModel: Codable, Equatable {
        var id: UUID
        var manufacturer: String
        var modelName: String
        var exerciseIDs: [UUID]
        var equipmentType: EquipmentCategory?
        var isSeeded: Bool
    }
}

// MARK: - Templates

extension ExportSnapshot {
    struct Template: Codable, Equatable {
        var id: UUID
        var name: String
        var items: [TemplateItem]
    }

    struct TemplateItem: Codable, Equatable {
        var id: UUID
        var order: Int
        var exerciseID: UUID?
        /// Resolved at export time for readability; `exerciseID` is the key.
        var exerciseName: String?
        var targetSets: Int?
        var targetReps: Int?
        var targetRepsBySet: [Int?]
        /// Superset membership (D48). Omitted at first, so a restored template
        /// came back silently ungrouped (codex-review 2, critical).
        var supersetGroupID: UUID?
    }
}

// MARK: - History

extension ExportSnapshot {
    struct Workout: Codable, Equatable {
        var id: UUID
        var startedAt: String
        /// Absent while the workout is still running (D30).
        var finishedAt: String?
        var notes: String
        /// When this workout was edited after being logged (D47). The mark is
        /// the honesty half of that decision — a backup that drops it restores
        /// a history claiming to be untouched. Optional so v1 files decode.
        var historyEditedAt: String?
        var sourceTemplateID: UUID?
        var sourceTemplateName: String?
        /// v6: the user's own title for the workout; absent when none was
        /// typed and the title is derived. Kept beside `sourceTemplateName`
        /// rather than replacing it — one is intent, the other provenance.
        var name: String? = nil
        var gymID: UUID?
        var gymName: String?
        var entries: [Entry]
        /// D44, schemaVersion 4. All absent when no sensor ran: a consumer must
        /// read missing as "not measured", never as zero.
        var averageHeartRate: Int?
        var maxHeartRate: Int?
        var activeEnergyKilocalories: Double?
        /// Seconds per zone, indexed by zone 0…5. Omitted when empty.
        var zoneSeconds: [Int]?
        /// D45: whether those zones came from an estimated maximum. Without it
        /// a restore turns historically estimated zones into unqualified fact
        /// (codex-review-2 #3) — the export must carry the qualifier along with
        /// the number it qualifies.
        var zonesFromEstimatedMax: Bool?
        /// v8: bpm per bucket from `startedAt`, 0 = gap; omitted when empty.
        var heartRateSeries: [Int]? = nil
        var heartRateSeriesIntervalSeconds: Int? = nil
        /// v9: the lowest/highest sample per bucket; omitted when the
        /// workout predates them. Same length as `heartRateSeries` when present.
        var heartRateSeriesLow: [Int]? = nil
        var heartRateSeriesHigh: [Int]? = nil
        /// v8: the system's resting-energy figure; absent when not provided.
        var basalEnergyKilocalories: Double? = nil
        var cardioSegments: [Cardio]? = nil
        var sensorCheckpoint: SensorCheckpoint? = nil
    }

    /// One exercise within a workout.
    ///
    /// Context for a **frozen** entry (first set completed) is the entry's D23
    /// snapshot, never a live lookup — renaming a gym must not rewrite an old
    /// export row. Context for a **draft** entry (`snapshotCapturedAt == nil`)
    /// is the live relationships, because no snapshot has been captured yet and
    /// the equipment the user just picked is the only truth there is
    /// (codex-review, finding 1).
    ///
    /// `modelManufacturer` is the one value neither path stores; it is resolved
    /// from the catalog at export time and absent when the model is gone.
    struct Entry: Codable, Equatable {
        var id: UUID
        var order: Int
        /// When equipment froze (first set completion). Absent = still a draft,
        /// and every context field below is live rather than snapshotted.
        var snapshotCapturedAt: String?
        var exerciseID: UUID
        var exerciseName: String
        var loadType: LoadType
        var freeWeightTag: EquipmentTag?
        /// Superset membership (D48). Entries sharing an id were performed
        /// alternately. Optional so v1 files still decode.
        var supersetGroupID: UUID?
        var machineID: UUID?
        var machineLabel: String?
        var modelID: UUID?
        /// Manufacturer *and* model, as the snapshot stores it
        /// (`EquipmentModel.displayName`) — hence not `modelName`, which would
        /// promise a raw name the store never captured (codex-review, finding 5).
        var modelDisplayName: String?
        var modelManufacturer: String?
        var gymID: UUID?
        var gymName: String?
        /// The variation performed (D36). Absent = none recorded, which is the
        /// truth about every set logged before presets existed.
        var presetID: UUID?
        var presetName: String?
        /// v7 (D51): set when this entry's identity was rewritten by the
        /// dumbbell reclassification; `reclassifiedFromExerciseName` is what
        /// the snapshot said before. Absent for every other entry.
        var reclassifiedAt: String? = nil
        var reclassifiedFromExerciseName: String? = nil
        var sets: [SetRow]
    }

    /// One logged set. `weight`/`unit` are exactly as entered and `weightKg`
    /// is the stored normalization (D29) — never a converted display value,
    /// and never rounded.
    struct SetRow: Codable, Equatable {
        var id: UUID
        var order: Int
        var type: SetType
        var reps: Int?
        /// The TOTAL lifted, in `unit` — bar included on a bar-mode set (D39).
        var weight: Double?
        var unit: WeightUnit
        var weightKg: Double?
        /// The bar the set was loaded on, as entered (in `unit`) and normalized
        /// — D29's rule applies to it for the same reason it applies to the
        /// weight: a consumer must never have to guess a column's unit. Absent
        /// when the weight was entered as a total, which is every set logged
        /// before 2026-08-22. Not a component to add to `weight`; `weight`
        /// already includes it.
        var barWeight: Double?
        var barWeightKg: Double?
        /// Absent = not completed. Present in the export regardless (D30).
        var completedAt: String?
    }
}

// MARK: - Memory & overrides

extension ExportSnapshot {
    struct GymMemory: Codable, Equatable {
        var id: UUID
        var gymID: UUID
        var exerciseID: UUID
        var machineID: UUID?
        var updatedAt: String
    }

    struct RestOverride: Codable, Equatable {
        var id: UUID
        /// D43. Without these a restore turns every heart-rate rest back into a
        /// plain timer, silently (codex-review 5.1, critical).
        var restMode: RestMode?
        var heartRateThresholdBpm: Int?
        var heartRateCapSeconds: Int?
        var exerciseID: UUID
        var workingRestSeconds: Int?
        var warmupRestSeconds: Int?
        var updatedAt: String
    }
}

// MARK: - Timestamps (D31)

/// ISO 8601 with the exporting device's UTC offset — `2026-08-11T18:30:00+09:00`.
///
/// Not bare UTC: a workout log is a record of local time-of-day, and a 6 a.m.
/// session in Seoul must not read as the previous evening. The offset keeps
/// both the instant and the wall clock.
struct ExportDateFormat {
    private let formatter: ISO8601DateFormatter

    init(timeZone: TimeZone = .current) {
        let formatter = ISO8601DateFormatter()
        // Fractional seconds are not decoration: `CanonicalRow` breaks ties
        // between duplicate preference/memory/override rows by `updatedAt`
        // before falling back to the id, so two updates inside the same second
        // must not collapse into one value (codex-review, finding 4).
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = timeZone
        self.formatter = formatter
    }

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    /// Optional passthrough — nil stays nil (an absent timestamp is a fact:
    /// an unfinished workout, an uncompleted set).
    func optionalString(from date: Date?) -> String? {
        guard let date else { return nil }
        return formatter.string(from: date)
    }

    /// Filename stamp: `2026-08-11-1830`, local time, sorts chronologically.
    func fileStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = self.formatter.timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}


extension ExportSnapshot {
    struct Cardio: Codable, Equatable {
        var id: UUID
        var order: Int
        var activity: String
        var startedAt: String
        var endedAt: String?
        var activeStartedAt: String?
        var accumulatedActiveSeconds: Double
        var lastCheckpointAt: String
        var displayUnit: String
        var automaticDistanceMeters: Double?
        var distanceSource: String?
        var manualDistanceValue: Double?
        var manualDistanceUnit: String?
        var averageHeartRate: Int?
        var maxHeartRate: Int?
        var heartRateTotal: Int
        var heartRateCount: Int
        var lastHeartRateSampleID: UUID?
        var activeEnergyKilocalories: Double?
        var basalEnergyKilocalories: Double?
        var intervals: [CardioActiveInterval]
        var distanceSpans: [CardioDistanceInterval]
        var route: [CardioRoute]
    }
    struct CardioActiveInterval: Codable, Equatable { var start: String; var end: String }
    struct CardioDistanceInterval: Codable, Equatable {
        var start: String
        var readings: [String: Double]
        var updatedAt: [String: String]
        var selectedSource: String?
    }
    struct CardioRoute: Codable, Equatable {
        var id: UUID
        var latitude: Double
        var longitude: Double
        var date: String
        var accuracy: Double
        var portion: UUID
    }
}


extension ExportSnapshot {
    struct SensorCheckpoint: Codable, Equatable {
        var samples: [SensorSample]
        var maximumHeartRateBpm: Int?
        var maximumHeartRateEstimated: Bool?
        var activeEnergyKilocalories: Double?
        var basalEnergyKilocalories: Double?
    }
    struct SensorSample: Codable, Equatable {
        var id: UUID
        var bpm: Int
        var date: String
        var source: HeartRateSource
    }
}
