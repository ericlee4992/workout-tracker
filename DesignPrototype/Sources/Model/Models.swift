import Foundation

// Plain value types for the redesign prototype. They mirror the real app's
// SwiftData models (WorkoutTracker/Domain/Models.swift) closely enough that the
// screens show real content, but they are in-memory structs: no persistence,
// no CloudKit rules. Display strings for enums are the real app's strings.

// MARK: - Stable ids and the app calendar

extension UUID {
    /// Deterministic UUID for a key, so sample data keeps the same ids across
    /// `Store.reset(to:)` and a navigation path never dangles.
    static func stable(_ key: String) -> UUID {
        var a: UInt64 = 0xcbf2_9ce4_8422_2325
        var b: UInt64 = 0x8422_2325_cbf2_9ce4
        for byte in key.utf8 {
            a = (a ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
            b = (b ^ UInt64(byte) ^ 0x5a) &* 0x0000_0100_0000_01b3 &+ 0x9e37_79b9
        }
        func byte(_ v: UInt64, _ i: Int) -> UInt8 { UInt8(truncatingIfNeeded: v >> UInt64(i * 8)) }
        return UUID(uuid: (
            byte(a, 0), byte(a, 1), byte(a, 2), byte(a, 3), byte(a, 4), byte(a, 5),
            (byte(a, 6) & 0x0F) | 0x40, byte(a, 7),
            (byte(b, 0) & 0x3F) | 0x80, byte(b, 1), byte(b, 2), byte(b, 3),
            byte(b, 4), byte(b, 5), byte(b, 6), byte(b, 7)))
    }
}

extension Calendar {
    /// Gregorian, device time zone, weeks start on Monday (the week widget is Mon–Sun).
    static let app: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()
}

// MARK: - Units

enum WeightUnit: String, CaseIterable, Identifiable, Hashable {
    case kg, lb

    var id: String { rawValue }
    var label: String { rawValue }
    var toggled: WeightUnit { self == .kg ? .lb : .kg }

    /// Exact by definition (D25).
    static let kilogramsPerPound = 0.45359237

    func toKg(_ value: Double) -> Double { self == .kg ? value : value * Self.kilogramsPerPound }
    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg / Self.kilogramsPerPound }
}

enum DistanceUnit: String, CaseIterable, Identifiable, Hashable {
    case km, mi

    var id: String { rawValue }
    var label: String { rawValue }
    var metersPerUnit: Double { self == .km ? 1000 : 1609.344 }
}

/// Settings › units. Metric = kg + km, U.S. customary = lb + mi.
enum UnitSystem: String, CaseIterable, Identifiable, Hashable {
    case metric, usCustomary

    var id: String { rawValue }
    var label: String { self == .metric ? "Metric" : "U.S. customary" }
    var weight: WeightUnit { self == .metric ? .kg : .lb }
    var distance: DistanceUnit { self == .metric ? .km : .mi }
}

// MARK: - Catalog enums (real app strings)

enum SetType: String, CaseIterable, Identifiable, Hashable {
    case warmup, working, failure, drop

    var id: String { rawValue }
    /// Row marker; working sets show their working index instead.
    var marker: String? {
        switch self {
        case .warmup: "W"
        case .working: nil
        case .failure: "F"
        case .drop: "D"
        }
    }
    var displayName: String {
        switch self {
        case .warmup: "Warmup"
        case .working: "Working"
        case .failure: "Failure"
        case .drop: "Drop"
        }
    }
    /// D26: a drop set is performed without resting.
    var startsRestTimer: Bool { self != .drop }
    /// D12: only warmups are excluded from records and volume.
    var countsTowardRecords: Bool { self != .warmup }
}

enum LoadType: String, CaseIterable, Identifiable, Hashable {
    case weighted, bodyweight, bodyweightPlus, assisted

    var id: String { rawValue }
    var badge: String {
        switch self {
        case .weighted: "Weighted"
        case .bodyweight: "Bodyweight"
        case .bodyweightPlus: "BW + added"
        case .assisted: "Assisted"
        }
    }
    /// Assisted: less assistance is better (records, charts, change %).
    var higherIsBetter: Bool { self != .assisted }
    /// Bodyweight logs reps only.
    var takesWeight: Bool { self != .bodyweight }
    /// Column header over the weight field (bar mode shows "PER SIDE").
    var weightColumn: String { self == .assisted ? "ASSIST" : "WEIGHT" }
    /// Progress chart y-axis label (real copy; append " (lb)" / " (kg)" where the unit applies).
    var axisLabel: String {
        switch self {
        case .weighted: "Weight"
        case .bodyweight: "Reps"
        case .bodyweightPlus: "Added weight"
        case .assisted: "Assistance (less is better)"
        }
    }
}

enum EquipmentTag: String, CaseIterable, Identifiable, Hashable {
    case machine, barbell, dumbbell, cable, smith, bodyweight

    var id: String { rawValue }
    var label: String {
        switch self {
        case .machine: "Machine"
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .cable: "Cable"
        case .smith: "Smith machine"
        case .bodyweight: "Bodyweight"
        }
    }
    var symbol: String {
        switch self {
        case .machine: "gearshape.2"
        case .barbell: "figure.strengthtraining.traditional"
        case .dumbbell: "dumbbell"
        case .cable: "cable.connector"
        case .smith: "square.split.1x2"
        case .bodyweight: "figure.core.training"
        }
    }
    /// Bar mode (bar + per side = total) applies to barbell and Smith.
    var offersBar: Bool { self == .barbell || self == .smith }
}

enum EquipmentCategory: String, CaseIterable, Identifiable, Hashable {
    case selectorized, plateLoaded, cable, rackOrSmith, bodyweight

    var id: String { rawValue }
    var label: String {
        switch self {
        case .selectorized: "Selectorized"
        case .plateLoaded: "Plate-loaded"
        case .cable: "Cable & functional"
        case .rackOrSmith: "Rack, Smith & bench"
        case .bodyweight: "Bodyweight station"
        }
    }
}

/// The seeded 14-value `muscleGroup` vocabulary, head to toe.
enum MuscleGroup: String, CaseIterable, Identifiable, Hashable {
    case chest = "Chest", back = "Back", shoulders = "Shoulders", biceps = "Biceps"
    case triceps = "Triceps", forearms = "Forearms", neck = "Neck", quads = "Quads"
    case hamstrings = "Hamstrings", glutes = "Glutes", hips = "Hips", calves = "Calves"
    case core = "Core", fullBody = "Full Body"

    var id: String { rawValue }
    var label: String { rawValue }
    /// Core, Neck and Full Body map to no family.
    var family: MuscleFamily? {
        switch self {
        case .chest: .chest
        case .back: .back
        case .shoulders: .shoulders
        case .biceps, .triceps, .forearms: .arms
        case .quads, .hamstrings, .glutes, .hips, .calves: .legs
        case .neck, .core, .fullBody: nil
        }
    }
}

/// The five families a muscle map exists for, head to toe (the order summaries use).
enum MuscleFamily: String, CaseIterable, Identifiable, Hashable {
    case chest, back, shoulders, arms, legs

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    /// Asset names in Assets.xcassets/MuscleMaps (namespaced folder).
    var bodyAsset: String { "MuscleMaps/\(rawValue)-body" }
    var muscleAsset: String { "MuscleMaps/\(rawValue)-muscle" }

    /// Families present, each once, in head-to-toe order.
    static func ordered(_ families: some Sequence<MuscleFamily>) -> [MuscleFamily] {
        let present = Set(families)
        return allCases.filter { present.contains($0) }
    }
}

enum CardioActivity: String, CaseIterable, Identifiable, Hashable {
    case indoorWalk, indoorRun, indoorCycle, elliptical, rowing, stairStepper
    case outdoorWalk, outdoorRun, outdoorCycle

    var id: String { rawValue }
    var name: String {
        switch self {
        case .indoorWalk: "Indoor Walk"
        case .indoorRun: "Indoor Run"
        case .indoorCycle: "Indoor Cycle"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .stairStepper: "Stair Stepper"
        case .outdoorWalk: "Outdoor Walk"
        case .outdoorRun: "Outdoor Run"
        case .outdoorCycle: "Outdoor Cycle"
        }
    }
    var symbol: String {
        switch self {
        case .indoorWalk, .outdoorWalk: "figure.walk"
        case .indoorRun, .outdoorRun: "figure.run"
        case .indoorCycle: "figure.indoor.cycle"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .stairStepper: "figure.stair.stepper"
        case .outdoorCycle: "figure.outdoor.cycle"
        }
    }
    var isOutdoor: Bool { [.outdoorWalk, .outdoorRun, .outdoorCycle].contains(self) }
    /// Cycling shows speed instead of pace.
    var usesSpeed: Bool { self == .indoorCycle || self == .outdoorCycle }
    /// Picker section: "Gym" or "Outdoors".
    var section: String { isOutdoor ? "Outdoors" : "Gym" }
}

enum HeartRateSource: String, CaseIterable, Hashable {
    case airPods = "AirPods"
    case appleWatch = "Apple Watch"
    case monitor = "Heart rate monitor"
}

/// Zones at 55/65/75/85/95 % of max — 5 points above textbook (D45).
enum HeartRateZone: Int, CaseIterable, Identifiable, Hashable {
    case warm = 0, one, two, three, four, five

    var id: Int { rawValue }
    var lowerFraction: Double { [0, 0.55, 0.65, 0.75, 0.85, 0.95][rawValue] }
    var label: String { self == .warm ? "Warm-up" : "Zone \(rawValue)" }
    var descriptionText: String {
        switch self {
        case .warm: "Below training intensity"
        case .one: "Very light"
        case .two: "Light — endurance"
        case .three: "Moderate — aerobic"
        case .four: "Hard — threshold"
        case .five: "Maximum"
        }
    }
}

// MARK: - Gyms, machines, catalog

struct Gym: Identifiable, Hashable {
    let id: UUID
    var name: String
    var city: String?
    /// nil = falls through to the app unit.
    var defaultUnit: WeightUnit?
    /// "Delete" in the UI; the real app archives (history keeps the snapshot name).
    var isDeleted = false
}

/// A catalog (or user-made) machine model, e.g. "Life Fitness Insignia Series Chest Press".
struct EquipmentModel: Identifiable, Hashable {
    let id: UUID
    var manufacturer: String
    var modelName: String
    var category: EquipmentCategory?
    var exerciseIDs: [UUID]
    var isSeeded = true

    var displayName: String { "\(manufacturer) \(modelName)" }
}

/// One machine at one gym. Label is the movement ("Chest Press 2"), not the hardware (D3).
struct Machine: Identifiable, Hashable {
    let id: UUID
    var gymID: UUID
    var label: String
    var modelID: UUID?
    /// Exercises recognised for a machine whose model has none (or no model).
    /// The effective list is `Store.exerciseIDs(of:)`.
    var recognizedExerciseIDs: [UUID] = []
    var defaultUnit: WeightUnit?
    var defaultPresetID: UUID?
    var isDeleted = false
    var deletedAt: Date?
}

struct ExercisePreset: Identifiable, Hashable {
    let id: UUID
    var name: String
}

struct Exercise: Identifiable, Hashable {
    let id: UUID
    var name: String
    var loadType: LoadType
    var muscleGroup: MuscleGroup?
    var tags: [EquipmentTag]
    var presets: [ExercisePreset] = []
    var isSeeded = true

    var family: MuscleFamily? { muscleGroup?.family }
    var isMachineExercise: Bool { tags.contains(.machine) }
}

// MARK: - Templates

struct TemplateItem: Identifiable, Hashable {
    let id: UUID
    var exerciseID: UUID
    /// One target per set; the count is the set count ("3 sets · 10, 10, 8 reps").
    var targetReps: [Int]
    var restSeconds: Int?
    /// Consecutive items sharing a group form a superset (A/B/C).
    var supersetGroup: UUID?
    var equipmentTag: EquipmentTag?

    var setCount: Int { targetReps.count }
}

/// A planned cardio target. Targets are prescriptions, never measurements (D57).
struct PlannedCardio: Identifiable, Hashable {
    let id: UUID
    var activity: CardioActivity
    var minutes: Int
    var distance: Double?
    var unit: DistanceUnit
}

struct Template: Identifiable, Hashable {
    let id: UUID
    var name: String
    var items: [TemplateItem]
    var cardio: [PlannedCardio] = []
    /// Set on templates saved from Ask AI.
    var generatedForGymID: UUID?

    var isAI: Bool { generatedForGymID != nil }
    var setCount: Int { items.reduce(0) { $0 + $1.setCount } }
}

// MARK: - A set's value (history, previous, records)

/// A performed set's value as entered. `weight` is the TOTAL (bar included).
struct SetValue: Hashable {
    var weight: Double?
    var unit: WeightUnit
    var reps: Int
    /// Bar weight when logged in bar mode (same unit); breakdown = bar + 2 × per side.
    var bar: Double? = nil

    var kg: Double? { weight.map { unit.toKg($0) } }
    var perSide: Double? {
        guard let bar, let weight else { return nil }
        return (weight - bar) / 2
    }
}

// MARK: - History

struct LoggedSet: Identifiable, Hashable {
    let id: UUID
    var type: SetType
    /// TOTAL weight as entered (bar included). nil for bodyweight.
    var weight: Double?
    var unit: WeightUnit
    var reps: Int?
    var barWeight: Double?
    var completedAt: Date

    var normalizedKg: Double? { weight.map { unit.toKg($0) } }
    var value: SetValue? { reps.map { SetValue(weight: weight, unit: unit, reps: $0, bar: barWeight) } }
}

/// One exercise in a finished workout, with its frozen snapshot (D23): history
/// always shows these names, never live ones.
struct WorkoutEntry: Identifiable, Hashable {
    let id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var loadType: LoadType
    var machineID: UUID?
    var machineLabel: String?
    var modelName: String?
    var freeWeightTag: EquipmentTag?
    var presetID: UUID?
    var presetName: String?
    var supersetGroup: UUID?
    var sets: [LoggedSet]
    /// D51 provenance: the one-time dumbbell move re-filed this entry under a dumbbell
    /// exercise. Not an edit (no "Edited" mark); History shows `reclassifiedLine`.
    var reclassifiedAt: Date? = nil
    var reclassifiedFromExerciseName: String? = nil

    var isReclassified: Bool { reclassifiedFromExerciseName != nil }
    /// "Reclassified from Bench Press · Sep 4, 2026" (real copy), or nil.
    var reclassifiedLine: String? {
        guard let old = reclassifiedFromExerciseName else { return nil }
        return reclassifiedAt.map { "Reclassified from \(old) · \(Format.mediumDate($0))" } ?? "Reclassified from \(old)"
    }

    /// "Chest Press 2 · Life Fitness Insignia Series Chest Press · Narrow grip", tag label, or "No equipment".
    var equipmentLabel: String {
        var parts: [String] = []
        if let machineLabel {
            parts.append(machineLabel)
            if let modelName { parts.append(modelName) }
        } else if let freeWeightTag {
            parts.append(freeWeightTag.label)
        }
        if parts.isEmpty { parts.append("No equipment") }
        if let presetName { parts.append(presetName) }
        return parts.joined(separator: " · ")
    }
    var countedSets: [LoggedSet] { sets.filter { $0.type.countsTowardRecords } }
}

struct RoutePoint: Hashable {
    var latitude: Double
    var longitude: Double
    /// Seconds since the segment started.
    var offset: TimeInterval
    /// GPS portion; never join a line across portions (pauses, outages).
    var portion: Int = 0
}

struct CardioSegment: Identifiable, Hashable {
    let id: UUID
    var activity: CardioActivity
    var startedAt: Date
    /// Active time, pauses excluded.
    var activeSeconds: Int
    var measuredMeters: Double?
    /// A manual distance overrides the measured one.
    var manualDistance: Double?
    var unit: DistanceUnit
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var activeCalories: Int?
    var route: [RoutePoint] = []
    var plannedID: UUID?

    var distanceMeters: Double? {
        if let manualDistance { return manualDistance * unit.metersPerUnit }
        return measuredMeters
    }
    /// Seconds per `unit`; nil without distance.
    var paceSecondsPerUnit: Double? {
        guard let meters = distanceMeters, meters > 0, activeSeconds > 0 else { return nil }
        return Double(activeSeconds) / (meters / unit.metersPerUnit)
    }
    /// Units per hour (cycling).
    var speedPerHour: Double? {
        guard let meters = distanceMeters, activeSeconds > 0 else { return nil }
        return (meters / unit.metersPerUnit) / (Double(activeSeconds) / 3600)
    }
    var hasRoute: Bool { route.count > 1 }
}

/// 15-second buckets (mean, low, high); 0 = gap (a hole, never joined).
struct HeartRateSeries: Hashable {
    var mean: [Int]
    var low: [Int]
    var high: [Int]
    var intervalSeconds = 15
}

struct HeartRateSummary: Hashable {
    var average: Int
    var maximum: Int
    /// Seconds per zone, index 0 (Warm-up) … 5. Empty when no max HR resolved.
    var zoneSeconds: [Int]
    var series: HeartRateSeries?
    var source: HeartRateSource = .airPods

    /// Zones that have time, in order (zero rows omitted).
    var zoneTimes: [ZoneTime] { Derived.zoneTimes(zoneSeconds) }
}

/// One zone's time for a zone-bar legend (only zones with time are listed).
struct ZoneTime: Identifiable, Hashable {
    var id: HeartRateZone { zone }
    var zone: HeartRateZone
    var seconds: Int
}

struct Workout: Identifiable, Hashable {
    let id: UUID
    /// Typed title; nil falls back to the template snapshot name.
    var name: String?
    var templateID: UUID?
    var templateName: String?
    var startedAt: Date
    var durationSeconds: Int
    var gymID: UUID?
    /// Snapshot of the gym name at the time.
    var gymName: String?
    var entries: [WorkoutEntry]
    var cardio: [CardioSegment] = []
    var heartRate: HeartRateSummary?
    var activeCalories: Int?
    var basalCalories: Int?
    /// D47: an edited workout shows an "Edited" mark.
    var editedAt: Date?
    var notes: String = ""

    var finishedAt: Date { startedAt.addingTimeInterval(TimeInterval(durationSeconds)) }
    var isEdited: Bool { editedAt != nil }
    /// Only when both parts exist (missing is not zero, D44).
    var totalCalories: Int? {
        guard let activeCalories, let basalCalories else { return nil }
        return activeCalories + basalCalories
    }
    /// Typed name, else template snapshot, else "First Exercise +N", else "Workout".
    var title: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let templateName { return templateName }
        let names = entries.map(\.exerciseName) + cardio.map(\.activity.name)
        guard let first = names.first else { return "Workout" }
        return names.count > 1 ? "\(first) +\(names.count - 1)" : first
    }
    var allSets: [LoggedSet] { entries.flatMap(\.sets) }
    /// Completed sets, warmups included (the history "N sets" count).
    var setCount: Int { allSets.count }
    var hasLifting: Bool { !entries.isEmpty }
    var hasCardio: Bool { !cardio.isEmpty }
    /// kg / lb / Mixed badge from the units actually entered.
    var unitBadge: String? {
        let units = Set(allSets.map(\.unit))
        if units.count > 1 { return "Mixed" }
        return units.first?.label
    }
}

// MARK: - Live session

enum LiveSetState: Hashable {
    case empty, prefilled, typed, completed
}

struct LiveSet: Identifiable, Hashable {
    let id: UUID
    var type: SetType = .working
    /// The weight FIELD: the total, or the plates PER SIDE when the entry is in bar mode.
    var weight: Double?
    var unit: WeightUnit
    var reps: Int?
    var completedAt: Date?
    /// Values were inherited (last workout or carried forward) and not typed over.
    var isPrefilled = false

    var isCompleted: Bool { completedAt != nil }
    var state: LiveSetState {
        if isCompleted { return .completed }
        if weight == nil && reps == nil { return .empty }
        return isPrefilled ? .prefilled : .typed
    }
}

struct LiveEntry: Identifiable, Hashable {
    let id: UUID
    var exerciseID: UUID
    var machineID: UUID?
    var freeWeightTag: EquipmentTag?
    var presetID: UUID?
    var supersetGroup: UUID?
    /// Non-nil = bar mode: each set's `weight` is per side; total = bar + 2 × per side.
    var barWeight: Double?
    var sets: [LiveSet]
    /// Template prescription ("Target: 4 sets · 12, 10, 8, 8 reps"). Never written as performed.
    var targetReps: [Int] = []
    var plannedRestSeconds: Int?
    /// D23: the exercise's load type captured at the entry's first completed set. Later
    /// "Change load type" edits apply to new entries; this one keeps ranking (and is
    /// saved) under the snapshot, or its completed sets would be re-ranked.
    var snapshotLoadType: LoadType? = nil

    var isBarMode: Bool { barWeight != nil }
    /// After a completed set, changing equipment or preset splits the entry (frozen).
    var isFrozen: Bool { sets.contains(where: \.isCompleted) }
    var completedCount: Int { sets.filter(\.isCompleted).count }

    /// Total weight a set represents (bar + 2 × per side in bar mode).
    func total(of set: LiveSet) -> Double? {
        guard let weight = set.weight else { return barWeight }
        guard let barWeight else { return weight }
        return barWeight + 2 * weight
    }
}

enum SessionFocus: String, Hashable { case lifting, cardio }

enum GPSState: Hashable {
    case notNeeded, waiting, live
    /// GPS lost (prototype toggle `Store.setGPSUnavailable`): time keeps recording,
    /// distance and route stop until it comes back.
    case unavailable

    /// The live location line (real copy), or nil when there is nothing to say.
    var message: String? {
        switch self {
        case .notNeeded, .live: nil
        case .waiting: "Waiting for GPS…"
        case .unavailable: "Location unavailable."
        }
    }
    /// Distance accrues (indoor, or outdoor with a fix).
    var recordsDistance: Bool { self == .notNeeded || self == .live }
}

struct LiveCardio: Identifiable, Hashable {
    let id: UUID
    var activity: CardioActivity
    var startedAt: Date
    /// Active seconds banked before the current running stretch.
    var accumulatedSeconds: Double = 0
    /// Start of the current running stretch; nil while paused or ended.
    var runningSince: Date?
    var endedAt: Date?
    var measuredMeters: Double = 0
    var manualDistance: Double?
    var unit: DistanceUnit
    /// Latest simulated speed (m/s) for "Current pace".
    var currentSpeed: Double?
    var heartRateSum = 0
    var heartRateCount = 0
    var maxHeartRate: Int?
    var activeCalories: Double = 0
    var route: [RoutePoint] = []
    var plannedID: UUID?
    var gps: GPSState = .notNeeded
    /// GPS portion new route points join; bumped on resume / GPS regained (never join across).
    var routePortion = 0
    /// Active seconds when the current GPS wait began.
    var gpsWaitFrom: Double = 0

    var isEnded: Bool { endedAt != nil }
    var isPaused: Bool { endedAt == nil && runningSince == nil }
    var isRunning: Bool { runningSince != nil }

    func activeSeconds(at now: Date) -> Int {
        let running = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return Int(accumulatedSeconds + running)
    }
    var distanceMeters: Double? {
        if let manualDistance { return manualDistance * unit.metersPerUnit }
        return measuredMeters > 0 ? measuredMeters : nil
    }
    var averageHeartRate: Int? { heartRateCount > 0 ? heartRateSum / heartRateCount : nil }
    /// "Average pace": seconds per `unit` over active time; nil without distance.
    func paceSecondsPerUnit(at now: Date) -> Double? {
        let seconds = activeSeconds(at: now)
        guard let meters = distanceMeters, meters > 0, seconds > 0 else { return nil }
        return Double(seconds) / (meters / unit.metersPerUnit)
    }
    /// "Average speed" (cycling): `unit`s per hour; nil without distance.
    func speedPerHour(at now: Date) -> Double? {
        let seconds = activeSeconds(at: now)
        guard let meters = distanceMeters, seconds > 0 else { return nil }
        return (meters / unit.metersPerUnit) / (Double(seconds) / 3600)
    }
    /// "Current pace" from the latest speed (hidden with a manual distance, like the real app).
    var currentPaceSecondsPerUnit: Double? {
        guard manualDistance == nil, let v = currentSpeed, v > 0 else { return nil }
        return unit.metersPerUnit / v
    }
    /// "Current speed" in `unit`s per hour (cycling).
    var currentSpeedPerHour: Double? {
        guard manualDistance == nil, let v = currentSpeed, v > 0 else { return nil }
        return v * 3600 / unit.metersPerUnit
    }
}

/// Heart rate banked during a live session (becomes the HeartRateSummary at finish).
struct HeartRateLog: Hashable {
    var mean: [Int] = []
    var low: [Int] = []
    var high: [Int] = []
    var zoneSeconds = [Int](repeating: 0, count: 6)
    var sum = 0
    var count = 0
    var maximum = 0
    // Current 15-second bucket.
    var bucketElapsed: Double = 0
    var bucketSum = 0
    var bucketCount = 0
    var bucketLow = Int.max
    var bucketHigh = 0

    var average: Int? { count > 0 ? sum / count : nil }

    mutating func add(_ bpm: Int, seconds: Double, zone: HeartRateZone?) {
        sum += bpm; count += 1; maximum = max(maximum, bpm)
        if let zone { zoneSeconds[zone.rawValue] += Int(seconds.rounded()) }
        bucketSum += bpm; bucketCount += 1
        bucketLow = min(bucketLow, bpm); bucketHigh = max(bucketHigh, bpm)
        bucketElapsed += seconds
        if bucketElapsed >= 15 { closeBucket() }
    }

    mutating func addGap(seconds: Double) {
        bucketElapsed += seconds
        if bucketElapsed >= 15 { closeBucket() }
    }

    mutating func closeBucket() {
        if bucketCount > 0 {
            mean.append(bucketSum / bucketCount); low.append(bucketLow); high.append(bucketHigh)
        } else {
            mean.append(0); low.append(0); high.append(0)
        }
        bucketElapsed = 0; bucketSum = 0; bucketCount = 0; bucketLow = .max; bucketHigh = 0
    }
}

extension HeartRateLog {
    /// A log that already holds `seconds` of readings (sample sessions that start mid-way),
    /// so finishing them yields an HR graph, zones and avg / max tiles.
    init(seeded summary: HeartRateSummary, seconds: Int) {
        self.init(mean: summary.series?.mean ?? [], low: summary.series?.low ?? [], high: summary.series?.high ?? [],
                  zoneSeconds: summary.zoneSeconds.count == 6 ? summary.zoneSeconds : [Int](repeating: 0, count: 6),
                  sum: summary.average * max(1, seconds), count: max(1, seconds), maximum: summary.maximum)
    }
}

struct LiveSession: Identifiable, Hashable {
    let id: UUID
    /// Typed name (rename); nil shows the derived title.
    var name: String?
    var templateID: UUID?
    var templateName: String?
    var gymID: UUID?
    var startedAt: Date
    var entries: [LiveEntry] = []
    var cardio: [LiveCardio] = []
    var plannedCardio: [PlannedCardio] = []
    var focus: SessionFocus = .lifting
    var activeCalories: Double = 0
    var heartRate = HeartRateLog()

    var unfinishedCardio: LiveCardio? { cardio.first { !$0.isEnded } }
    var hasCardio: Bool { !cardio.isEmpty }
    var completedSetCount: Int { entries.reduce(0) { $0 + $1.completedCount } }
    var totalSetCount: Int { entries.reduce(0) { $0 + $1.sets.count } }
}

// MARK: - Rest

enum RestMode: String, CaseIterable, Identifiable, Hashable {
    case timer, heartRate

    var id: String { rawValue }
    var label: String { self == .timer ? "Timer" : "Heart rate" }
}

/// Per-exercise rest override (Rest settings sheet). nil durations fall through
/// to the template's planned rest, then the global defaults.
struct RestSettings: Hashable {
    var mode: RestMode = .timer
    var workingSeconds: Int?
    var warmupSeconds: Int?
    /// Heart-rate rest ends at a reading strictly below this.
    var thresholdBpm = 110
    /// Heart-rate rest never runs longer than this.
    var capSeconds = 240
}

struct RestState: Hashable {
    var entryID: UUID
    var setID: UUID
    var startedAt: Date
    /// Timer: start + duration. Heart rate: start + cap.
    var endsAt: Date
    var totalSeconds: Int
    var mode: RestMode
    /// Heart-rate mode target (ends below it).
    var thresholdBpm: Int?
    /// Heart-rate rest fell back to the timer: "No heart rate reading — resting by the timer instead."
    var isDegraded = false

    func remaining(at now: Date) -> Int { max(0, Int(endsAt.timeIntervalSince(now).rounded(.up))) }
    func elapsed(at now: Date) -> Int { max(0, Int(now.timeIntervalSince(startedAt))) }
    /// Draining ring: remaining ÷ total.
    func progress(at now: Date) -> Double {
        totalSeconds > 0 ? Double(remaining(at: now)) / Double(totalSeconds) : 0
    }
}

/// How the last rest ended (drives the rest-complete notification copy).
enum RestOutcome: Hashable {
    case timerDone
    case recovered(bpm: Int)
    case cap
    case skipped

    /// Notification title (real app copy); nil for a skip (no notification).
    var notificationTitle: String? { self == .skipped ? nil : "Rest complete" }
    /// Notification body (real app copy); nil for a skip.
    var notificationBody: String? {
        switch self {
        case .timerDone: "Time for your next set."
        case .recovered(let bpm): "Heart rate down to \(bpm) bpm — ready for your next set."
        case .cap: "Time is up — your heart rate didn't reach the target."
        case .skipped: nil
        }
    }
}

// MARK: - Heart-rate feed (simulated sensor)

/// The prototype's sensor toggle: live readings, a stale feed, or no sensor.
enum SensorMode: String, CaseIterable, Identifiable, Hashable {
    case live, stale, none

    var id: String { rawValue }
}

enum HeartRateFeed: Hashable {
    case live(HeartRateSource)
    /// Last reading is older than 15 s.
    case stale(lastBpm: Int, secondsAgo: Int)
    /// "Looking for a sensor…"
    case waiting
}

struct HeartRateState: Hashable {
    var bpm: Int?
    var lastSampleAt: Date?
    var source: HeartRateSource = .airPods
    var mode: SensorMode = .live
    /// Index into the script (one step every `HRScript.secondsPerStep`).
    var scriptStep = 0
    /// While resting, the reading decays from `recoveryFrom` (starting at `recoveryStart`)
    /// instead of following the script.
    var recoveryFrom: Int?
    var recoveryStart: Date?
    /// Seconds since the script last stepped.
    var scriptElapsed: Double = 0
    /// Smoothed level the reading eases along (nil = start from `bpm`), so the zone never flickers.
    var level: Double? = nil

    static let staleAfter: TimeInterval = 15

    func feed(at now: Date) -> HeartRateFeed {
        guard let bpm, let lastSampleAt else { return .waiting }
        let age = now.timeIntervalSince(lastSampleAt)
        if age > Self.staleAfter { return .stale(lastBpm: bpm, secondsAgo: Int(age)) }
        return .live(source)
    }
    /// A fresh reading, or nil.
    func current(at now: Date) -> Int? {
        if case .live = feed(at: now) { return bpm }
        return nil
    }
}

// MARK: - Set completion and records

enum BestOutcome: Hashable {
    case none
    /// The first eligible set ever in this scope — "First time", never a PR.
    case firstTime
    /// Beats every earlier eligible set in the scope (ties are not PRs).
    case newBest(previous: SetValue?)

    var isNewBest: Bool { if case .newBest = self { return true } else { return false } }
}

/// What `Store.completeSet` returns (and publishes as `lastCompletion`) for the celebration.
struct SetCompletion: Identifiable, Hashable {
    let id: UUID
    var entryID: UUID
    var setID: UUID
    var exerciseName: String
    var value: SetValue
    var outcome: BestOutcome
    var restStarted: Bool
    var at: Date
}

/// Records are kept per scope: the machine OR the free-weight tag, plus the preset.
struct RecordScope: Hashable {
    var exerciseID: UUID
    var machineID: UUID?
    var freeWeightTag: EquipmentTag?
    var presetID: UUID?
}

// MARK: - Previous performance (three layers, D1)

enum PerformanceLayerKind: String, CaseIterable, Identifiable, Hashable {
    case thisEquipment, sameModelElsewhere, anyEquipment

    var id: String { rawValue }
}

struct PerformanceSession: Identifiable, Hashable {
    var id: UUID { workoutID }
    var workoutID: UUID
    var date: Date
    var gymName: String?
    var equipmentLabel: String
    var sets: [SetValue]
    var types: [SetType]
}

struct RepBest: Identifiable, Hashable {
    var id: Int { reps }
    var reps: Int
    var value: SetValue
    var date: Date
}

struct PerformanceLayer: Identifiable, Hashable {
    var id: PerformanceLayerKind { kind }
    var kind: PerformanceLayerKind
    /// "This machine" / "This equipment" / "Same model elsewhere" / "Any equipment".
    var title: String
    /// Most recent first, at most 5.
    var sessions: [PerformanceSession]
    var best: SetValue?
    var repBests: [RepBest]
    /// Weighted only (D20).
    var oneRepMaxKg: Double?
    /// Bodyweight: most reps.
    var mostReps: Int?
    /// Real-app empty copy when `sessions` is empty.
    var emptyMessage: String?
}

struct PreviousPerformance: Hashable {
    var exerciseName: String
    var loadType: LoadType
    var presetName: String?
    var layers: [PerformanceLayer]
}

// MARK: - Progress

enum ProgressMetric: String, CaseIterable, Identifiable, Hashable {
    case bestSet, volume, oneRepMax

    var id: String { rawValue }
    var label: String {
        switch self {
        case .bestSet: "Best set"
        case .volume: "Volume"
        case .oneRepMax: "1RM"
        }
    }
}

struct ProgressVariation: Identifiable, Hashable {
    /// Stable key: load type × equipment × preset.
    var id: String
    var label: String
    var machineID: UUID?
    var freeWeightTag: EquipmentTag?
    var presetID: UUID?
    var loadType: LoadType
    var trainingDays: Int
}

struct ProgressPoint: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var workoutID: UUID
    var best: SetValue
    var bestKg: Double?
    var volumeKg: Double
    var oneRepMaxKg: Double?
    /// The day's best beat every earlier day (PR marker).
    var isRecord: Bool
}

enum ProgressConfidence: Hashable {
    case empty
    /// One day: draw a point, never a line.
    case single
    case series(days: Int)
}

struct ProgressSeries: Hashable {
    var exerciseID: UUID
    var variation: ProgressVariation
    var points: [ProgressPoint]

    var confidence: ProgressConfidence {
        switch points.count {
        case 0: .empty
        case 1: .single
        default: .series(days: points.count)
        }
    }
}

// MARK: - Summaries

enum DayWorkoutKind: Hashable {
    case lifting
    case cardio(CardioActivity)
    case mixed
}

struct DayWorkout: Identifiable, Hashable {
    var id: UUID { workoutID }
    var workoutID: UUID
    var title: String
    var kind: DayWorkoutKind
    var families: [MuscleFamily]
    var minutes: Int
    var sets: Int
}

struct WeekDaySummary: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    /// "M", "T", …
    var letter: String
    var isToday: Bool
    var isFuture: Bool
    var workouts: [DayWorkout]
}

struct FamilyCount: Identifiable, Hashable {
    var id: MuscleFamily { family }
    var family: MuscleFamily
    var sets: Int
}

struct WeekSummary: Hashable {
    /// Monday … Sunday.
    var days: [WeekDaySummary]
    var workoutCount: Int
    /// Days with at least one workout (Mon's Pull Day + Indoor Run count as one day).
    var trainingDayCount: Int
    /// Completed non-warmup sets per family (every load type), head to toe; zero families included.
    var setsByFamily: [FamilyCount]
    var minutes: Int
    var lastWeekWorkoutCount: Int
}

struct MonthSummary: Hashable {
    var month: Date
    var workouts: Int
    var sets: Int
    var hours: Double
}

/// PROPOSED (not in SPEC/DECISIONS): consecutive weeks with ≥ 1 workout.
struct WeekStreak: Hashable {
    /// Completed weeks in a row before this one.
    var completedWeeks: Int
    /// This week already has a workout.
    var thisWeekActive: Bool
}

struct TemplateStats: Hashable {
    var timesRun: Int
    var lastRun: Date?
    var averageDurationSeconds: Int?
}

struct GymStats: Hashable {
    var visits: Int
    var lastVisit: Date?
    var machineCount: Int
    var deletedMachineCount: Int
}

/// The best set on a machine for one record scope: exercise + preset (records are machine + preset).
struct MachineBest: Identifiable, Hashable {
    var id: String { "\(exerciseID.uuidString)|\(presetID?.uuidString ?? "")" }
    var exerciseID: UUID
    var exerciseName: String
    var presetID: UUID?
    var presetName: String?
    var loadType: LoadType
    var value: SetValue
    /// Workouts that used this exercise + preset on the machine.
    var timesUsed: Int

    /// "Seated Chest Press" or "Seated Chest Press · Narrow grip".
    var label: String { presetName.map { "\(exerciseName) · \($0)" } ?? exerciseName }
}

struct MachineStats: Hashable {
    var timesUsed: Int
    var lastUsed: Date?
    /// Most used scope first.
    var bests: [MachineBest]
    var setCount: Int

    var best: MachineBest? { bests.first }
}

struct CalendarDay: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var dayNumber: Int
    var isToday: Bool
    var isFuture: Bool
    /// Completed non-warmup sets that day.
    var sets: Int
    /// 0 = no workout, 1…4 by sets (a cardio-only day is 1).
    var intensity: Int
    var workoutIDs: [UUID]
    var isSelected: Bool
}

struct CalendarMonth: Hashable {
    var month: Date
    /// "Sep 2026"
    var title: String
    /// Monday-first single letters.
    var weekdaySymbols: [String]
    /// Rows of 7; nil = padding outside the month.
    var weeks: [[CalendarDay?]]
    var selectedDate: Date?
    var selectedWorkouts: [DayWorkout]
    var hasPrevious: Bool
    var hasNext: Bool
}

struct HRSlot: Identifiable, Hashable {
    var id: Int { index }
    var index: Int
    var startSeconds: Int
    var endSeconds: Int
    var low: Int
    var high: Int
}

struct ZoneRow: Identifiable, Hashable {
    var id: HeartRateZone { zone }
    var zone: HeartRateZone
    /// Inclusive lower bound in bpm (0 for Warm-up).
    var lowerBound: Int
    /// Exclusive upper bound; nil for Zone 5.
    var upperBound: Int?
}

struct CardioSplit: Identifiable, Hashable {
    var id: Int { index }
    var index: Int
    /// Distance covered in this split, in the segment's unit (1.0 except the last).
    var distance: Double
    var seconds: Int
}

// MARK: - Finish

enum FinishTileKind: String, CaseIterable, Identifiable, Hashable {
    case workoutTime, totalVolume, activeCalories, totalCalories, averageHeartRate, maxHeartRate

    var id: String { rawValue }
    var label: String {
        switch self {
        case .workoutTime: "Workout time"
        case .totalVolume: "Total volume"
        case .activeCalories: "Active calories"
        case .totalCalories: "Total calories"
        case .averageHeartRate: "Avg. heart rate"
        case .maxHeartRate: "Max heart rate"
        }
    }
    var symbol: String {
        switch self {
        case .workoutTime: "timer"
        case .totalVolume: "scalemass.fill"
        case .activeCalories: "flame.fill"
        case .totalCalories: "flame"
        case .averageHeartRate: "heart.fill"
        case .maxHeartRate: "arrow.up.heart.fill"
        }
    }
}

struct FinishTile: Identifiable, Hashable {
    var id: FinishTileKind { kind }
    var kind: FinishTileKind
    var value: String
    var unit: String
    var label: String { kind.label }
}

struct NewBestLine: Identifiable, Hashable {
    var id: UUID { setID }
    var setID: UUID
    var exerciseID: UUID
    var exerciseName: String
    var value: SetValue
    var previous: SetValue?
}

struct FinishExerciseLine: Identifiable, Hashable {
    var id: UUID { entryID }
    var entryID: UUID
    var exerciseID: UUID
    var name: String
    var equipmentLabel: String
    var family: MuscleFamily?
    var setCount: Int
    /// Best counted set (warmups excluded).
    var best: SetValue?
    var loadType: LoadType
    var hasNewBest: Bool
}

struct TemplateComparison: Hashable {
    var templateName: String
    var lastDate: Date
    var lastVolumeKg: Double
    var volumeKg: Double
    var lastDurationSeconds: Int
    var durationSeconds: Int
    /// nil when the last volume was zero.
    var volumeChangePercent: Double?
}

struct FinishSummary: Identifiable, Hashable {
    let id: UUID
    /// false = nothing was logged, so the workout wasn't saved.
    var saved: Bool
    var workoutID: UUID?
    var title: String
    var date: Date
    var gymName: String?
    var durationSeconds: Int
    var volumeKg: Double
    var setCount: Int
    var exerciseCount: Int
    /// In the user's order: time | volume, active | total cal, avg | max HR. Missing facts are omitted, never zeroed.
    var tiles: [FinishTile]
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    /// Empty when no max HR / no HR.
    var zoneSeconds: [Int]
    var hrSlots: [HRSlot]
    var newBests: [NewBestLine]
    var comparison: TemplateComparison?
    var families: [MuscleFamily]
    var exercises: [FinishExerciseLine]
    var cardio: [CardioSegment]
    /// "5 exercises · 22 sets · Iron Temple"
    var summaryLine: String

    /// Zones that have time, in order (zero rows omitted; empty without HR / max HR).
    var zoneTimes: [ZoneTime] { Derived.zoneTimes(zoneSeconds) }
}

// MARK: - Template drift

enum DriftChangeKind: Hashable {
    case added(sets: Int)
    case removed
    case setCount(from: Int, to: Int)
    case reps(from: [Int], to: [Int])
}

struct DriftChange: Identifiable, Hashable {
    let id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var kind: DriftChangeKind
    /// Completed values this workout, e.g. "110 lb × 8" (the heaviest counted set).
    var bestValue: SetValue?

    /// Compact diff badge: "+1 set", "−1 set", "New", "Removed", "12, 10, 8 → 12, 10, 8, 7".
    var badge: String {
        switch kind {
        case .added: "New"
        case .removed: "Removed"
        case .setCount(let from, let to):
            to > from ? "+\(to - from) set\(to - from == 1 ? "" : "s")" : "−\(from - to) set\(from - to == 1 ? "" : "s")"
        case .reps(let from, let to):
            "\(from.map(String.init).joined(separator: ", ")) → \(to.map(String.init).joined(separator: ", "))"
        }
    }
}

struct TemplateDrift: Hashable {
    var templateID: UUID
    var templateName: String
    var workoutID: UUID
    var changes: [DriftChange]
}

enum DriftResolution: String, CaseIterable, Identifiable, Hashable {
    case updateTemplate, updateValuesOnly, updateBoth, keepOriginal

    var id: String { rawValue }
    var title: String {
        switch self {
        case .updateTemplate: "Update Template"
        case .updateValuesOnly: "Update Values Only"
        case .updateBoth: "Update Both"
        case .keepOriginal: "Keep Original"
        }
    }
    /// PROPOSED one-line consequences (new strings for the user to approve).
    var consequence: String {
        switch self {
        case .updateTemplate: "Exercises and set counts follow this workout; rep targets stay."
        case .updateValuesOnly: "Only rep targets change; exercises and sets stay."
        case .updateBoth: "The template becomes exactly this workout."
        case .keepOriginal: "The template stays as it is."
        }
    }
}

// MARK: - Ask AI for Templates

enum AIExperience: String, CaseIterable, Identifiable, Hashable {
    case beginner, intermediate, experienced

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum RoutineEquipment: String, CaseIterable, Identifiable, Hashable {
    case dumbbells, bench, adjustableBench, barbellRack, cable, smith, pullupBar, dipStation

    var id: String { rawValue }
    var label: String {
        switch self {
        case .dumbbells: "Dumbbells"
        case .bench: "Flat bench"
        case .adjustableBench: "Adjustable bench"
        case .barbellRack: "Barbell, plates and rack"
        case .cable: "Cable station and attachments"
        case .smith: "Smith machine"
        case .pullupBar: "Pull-up bar"
        case .dipStation: "Dip station"
        }
    }
    /// Free-weight tags this equipment makes available.
    var tags: [EquipmentTag] {
        switch self {
        case .dumbbells, .bench, .adjustableBench: [.dumbbell]
        case .barbellRack: [.barbell]
        case .cable: [.cable]
        case .smith: [.smith]
        case .pullupBar, .dipStation: [.bodyweight]
        }
    }
}

struct AIRoutineRequest: Hashable {
    var goals = ""
    var experience: AIExperience = .beginner
    /// 1…7
    var daysPerWeek = 3
    /// 15…120, step 5
    var minutesPerSession = 45
    var heightCm: Double?
    var weightKg: Double?
    var gymID: UUID?
    var equipment: Set<RoutineEquipment> = []
    var cardio: Set<CardioActivity> = []
    /// "Allow sending routine details to OpenAI" (mirrors Settings' routine consent).
    var consent = false

    var hasGoals: Bool { !goals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct AIRoutineItem: Identifiable, Hashable {
    let id: UUID
    var exerciseID: UUID
    /// 1…10
    var sets: Int
    /// 1…50
    var reps: Int
    /// 0…600, step 15
    var restSeconds: Int
}

struct AIRoutineDay: Identifiable, Hashable {
    let id: UUID
    var name: String
    var items: [AIRoutineItem]
    var cardio: [PlannedCardio]

    /// The app's own estimate: 45 s per set + rest + 60 s per exercise, plus cardio minutes.
    var estimatedMinutes: Int {
        let strength = items.reduce(0) { $0 + $1.sets * (45 + $1.restSeconds) + 60 }
        return Int((Double(strength) / 60).rounded()) + cardio.reduce(0) { $0 + $1.minutes }
    }
    var setCount: Int { items.reduce(0) { $0 + $1.sets } }
}

enum AIStep: String, Hashable {
    case goals, equipment, generating, preview, saved, error
}

struct AIRoutineFlow: Hashable {
    var step: AIStep = .goals
    var request = AIRoutineRequest()
    var days: [AIRoutineDay] = []
    /// 0…1 while generating.
    var progress: Double = 0
    var progressText = ""
    /// Real-app error copy (shown on the equipment step or the error step).
    var error: String?
    var savedTemplateIDs: [UUID] = []
    /// Prototype switch: make the next generation fail.
    var simulateFailure = false
}

// MARK: - Scan

enum ScanStep: String, Hashable {
    case camera, consent, identifying, result, confirmed
    /// Identification failed (`ScanFlow.error` holds the real copy); "Take another photo" → `scanRetake()`.
    case error
}

enum ScanKind: String, CaseIterable, Identifiable, Hashable {
    case specific, ambiguous, newModel, generic

    var id: String { rawValue }
    var label: String {
        switch self {
        case .specific: "Specific"
        case .ambiguous: "Ambiguous"
        case .newModel: "New model"
        case .generic: "Generic"
        }
    }
}

struct ScanCandidate: Identifiable, Hashable {
    let id: UUID
    var manufacturer: String
    var modelName: String
    var category: EquipmentCategory?
    var exerciseIDs: [UUID]
    /// 0…1, shown as a visual state (never prose).
    var confidence: Double
    /// nil = not in the catalog (would add a new model).
    var catalogModelID: UUID?

    var displayName: String { "\(manufacturer) \(modelName)" }
}

struct ScanResult: Hashable {
    var kind: ScanKind
    /// Editable machine name (the movement).
    var label: String
    var candidates: [ScanCandidate]
    var selectedCandidateID: UUID?
    /// Effective exercises (≤ 6).
    var exerciseIDs: [UUID]
    /// Text the AI read off the plate (specific only).
    var visibleText: String?

    var selectedCandidate: ScanCandidate? { candidates.first { $0.id == selectedCandidateID } }
}

struct ScanFlow: Hashable {
    var step: ScanStep = .camera
    var gymID: UUID?
    /// Which kind of result the simulated AI returns next.
    var demoKind: ScanKind = .specific
    var progress: Double = 0
    var result: ScanResult?
    var confirmedMachineID: UUID?
    var torchOn = false
    /// A photo was taken (identifying / result / error show its thumbnail). No image asset
    /// ships: draw the placeholder described by `ScanSimulator.photoSymbol` / `photoCaption`.
    var hasPhoto = false
    /// Real error copy on `.error`.
    var error: String?
    /// Prototype switch: make the next identification fail.
    var simulateFailure = false
}

/// Correct Model sheet: apply to future workouts only, or rewrite past snapshots too.
enum CorrectionScope: String, CaseIterable, Identifiable, Hashable {
    case futureOnly, applyToPast

    var id: String { rawValue }
    var title: String { self == .futureOnly ? "Future Workouts Only" : "Apply to Past Workouts Too" }
}

// MARK: - Settings and export

enum ExportFormat: String, CaseIterable, Identifiable, Hashable {
    case csv, json

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

enum ExportState: Hashable {
    case idle
    case exporting(ExportFormat)
    case done(fileName: String)
    /// The export threw; `error` is the system's description.
    case failed(error: String)

    /// The red failure row: "Export failed: <error>" (real copy), or nil.
    var failureLine: String? {
        if case .failed(let error) = self { return "Export failed: \(error)" }
        return nil
    }
}

/// Settings' "History update" row (D51): the one-time dumbbell history move.
struct HistoryUpdateNote: Hashable {
    var setCount: Int
    var date: Date

    /// "6 sets moved to dumbbell exercises · Sep 4, 2026" (real copy).
    var text: String {
        "\(setCount) set\(setCount == 1 ? "" : "s") moved to dumbbell exercises · \(Format.mediumDate(date))"
    }
}

enum AIConsent: String, CaseIterable, Identifiable, Hashable {
    case photos, routine, modelDetails

    var id: String { rawValue }
    var label: String {
        switch self {
        case .photos: "Send equipment photos to OpenAI"
        case .routine: "Send routine details to OpenAI"
        case .modelDetails: "Send model details to OpenAI"
        }
    }
}

struct AppSettings: Hashable {
    var unitSystem: UnitSystem = .usCustomary
    /// Global rest defaults, 0…600 s step 15.
    var workingRestSeconds = 120
    var warmupRestSeconds = 60
    /// "Suppress template update prompts" (drift prompt off).
    var suppressTemplatePrompts = false
    /// A measured max always wins over 220 − age.
    var measuredMaxHeartRate: Int? = 185
    var birthDate: Date?
    var aiKeySaved = true
    /// Masked hint of the saved key (PROPOSED display).
    var aiKeyHint = "sk-…a1b2"
    var photoConsent = true
    var routineConsent = true
    var modelDetailsConsent = false
    var lastExportAt: Date?
    var lastExportFormat: ExportFormat?
    /// D51 "History update" row; nil hides it.
    var historyUpdate: HistoryUpdateNote?

    var weightUnit: WeightUnit { unitSystem.weight }
    var distanceUnit: DistanceUnit { unitSystem.distance }

    func consent(_ kind: AIConsent) -> Bool {
        switch kind {
        case .photos: photoConsent
        case .routine: routineConsent
        case .modelDetails: modelDetailsConsent
        }
    }
    mutating func setConsent(_ kind: AIConsent, _ value: Bool) {
        switch kind {
        case .photos: photoConsent = value
        case .routine: routineConsent = value
        case .modelDetails: modelDetailsConsent = value
        }
    }
}

// MARK: - Live helpers

/// "Next · Set 3 · 110 × 8" under the rest timer.
struct NextSetPreview: Hashable {
    var entryID: UUID
    var setID: UUID
    var exerciseName: String
    /// "Set 3", "Warmup", "Drop"…
    var setLabel: String
    /// Prefilled / typed values (total weight), nil when the row is empty.
    var value: SetValue?
    var loadType: LoadType
    /// The next set belongs to a different exercise than the one just done.
    var isNewExercise: Bool
}

enum PlannedCardioStatus: Hashable {
    case notStarted
    case recording
    case paused
    case done
}

// MARK: - Starting while a workout runs

/// A start the user asked for while a workout was live (W05 confirmation).
struct PendingStart: Hashable {
    var templateID: UUID?
    /// Always nil in this prototype, as in the real app: Home hides Start while a workout
    /// is live, and cardio starts inside the running workout add a segment instead.
    var activity: CardioActivity?
}

enum StartResult: Hashable {
    case started
    /// A workout is already running: show "Resume Workout / Finish It & Start New / Cancel".
    case needsConfirmation
}

// MARK: - Live Activity (lock screen / Dynamic Island mock)

/// What the Live Activity shows. Build from `Store.liveActivity`, or for another state
/// (e.g. the cardio variant) `Store.liveActivitySample(.c02)`.
struct LiveActivitySnapshot: Hashable {
    var title: String
    var gymName: String?
    /// Elapsed timer = now − startedAt.
    var startedAt: Date
    var elapsedSeconds: Int
    var isCardio: Bool
    /// Lifting: the current exercise ("Seated Chest Press").
    var exerciseName: String?
    var completedSets: Int
    var totalSets: Int
    var bpm: Int?
    var zone: HeartRateZone?
    /// Running rest: countdown to `rest.endsAt` (remaining / total for the ring).
    var restEndsAt: Date?
    var restRemaining: Int?
    var restTotal: Int?
    /// Cardio (focus on a running or paused segment).
    var activity: CardioActivity?
    var cardioSeconds: Int?
    var distanceMeters: Double?
    var distanceUnit: DistanceUnit
    var paceSecondsPerUnit: Double?
    var isCardioPaused: Bool
}

// MARK: - New Model: "Suggest exercises with AI" (simulated)

struct ModelExerciseSuggestion: Identifiable, Hashable {
    var id: UUID { exerciseID }
    var exerciseID: UUID
    /// PROPOSED reason line under a ticked row (the real reasons come from the AI).
    var reason: String
}

enum ModelSuggestState: Hashable {
    case idle
    /// Model-details consent is off: show "Send model details to OpenAI?" first.
    case needsConsent
    /// "Asking AI…"
    case asking
    case suggested([ModelExerciseSuggestion])
    /// "AI could not tell which exercises this machine serves."
    case empty
    /// Real error copy.
    case failed(String)
}

// MARK: - Screen targets (what reset(to:) points the UI at)

/// Ids a screen reset points at, so ScreenIndex / -screen can navigate there.
struct ScreenTarget: Hashable {
    var templateID: UUID?
    var workoutID: UUID?
    var gymID: UUID?
    var machineID: UUID?
    /// A second machine for a variant (G04: Seated Row, which has a usual preset).
    var secondaryMachineID: UUID?
    var exerciseID: UUID?
    var entryID: UUID?
    /// A second entry for a variant (L08: Lateral Raise, which offers the dumbbell counterpart).
    var secondaryEntryID: UUID?
    /// Primary set (e.g. the row with swipe-to-delete revealed, the set being edited).
    var setID: UUID?
    /// Secondary set (e.g. the row whose set-type menu is open).
    var secondarySetID: UUID?
    var aiDayID: UUID?
    var segmentID: UUID?
    var date: Date?
}
