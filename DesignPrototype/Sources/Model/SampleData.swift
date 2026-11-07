import Foundation

// The shared sample scenario (redesign-brief.md), extended so every screen has
// real content. "Today" is Thursday 2026-09-24 18:30 local. The user logs in lb
// at Iron Temple (Seoul). History: 22 finished workouts, Aug 10 – Sep 23, on a
// Mon/Wed/Sat-ish rhythm, with a Seated Chest Press progression on Chest Press 2
// that makes today's 110 × 8 a new best (last time 105 × 8). Assisted Pull-Up
// (lower is better) and Dip (BW + added) have short histories; the Aug 31 hotel
// session carries the D51 dumbbell reclassification.

enum SampleData {

    // MARK: - Clock

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
        Calendar.app.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }
    /// Thursday, Sep 24 2026, 18:30 local.
    static let today = date(2026, 9, 24, 18, 30)
    /// When the one-time D51 dumbbell move ran.
    static let reclassifiedOn = date(2026, 9, 4, 9, 30)

    // MARK: - Stable ids

    static func exerciseID(_ name: String) -> UUID { .stable("exercise.\(name)") }
    static func presetID(_ exercise: String, _ preset: String) -> UUID { .stable("preset.\(exercise).\(preset)") }
    static func gymID(_ name: String) -> UUID { .stable("gym.\(name)") }
    static func machineID(_ gym: String, _ label: String) -> UUID { .stable("machine.\(gym).\(label)") }
    static func modelID(_ displayName: String) -> UUID { .stable("model.\(displayName)") }
    static func templateID(_ name: String) -> UUID { .stable("template.\(name)") }
    static func workoutID(_ key: String) -> UUID { .stable("workout.\(key)") }

    static let ironTemple = "Iron Temple"
    static let gangnam = "Gangnam Fitness"
    static let hotel = "Hotel Gym"
    static var ironTempleID: UUID { gymID(ironTemple) }

    /// Catalog size shown in the model picker (the real seed: v5).
    static let catalogModelCount = 1877
    static let catalogManufacturerCount = 23

    // MARK: - World

    struct World {
        var gyms: [Gym]
        var models: [EquipmentModel]
        var machines: [Machine]
        var exercises: [Exercise]
        var templates: [Template]
        var workouts: [Workout]
        var settings: AppSettings
        var restSettings: [UUID: RestSettings]
    }

    static func world() -> World {
        let exercises = makeExercises()
        let gyms = makeGyms()
        let models = makeModels()
        let machines = makeMachines()
        var settings = AppSettings()
        settings.birthDate = date(1994, 5, 12)
        settings.lastExportAt = date(2026, 9, 12, 20, 14)
        settings.lastExportFormat = .csv
        // D51: the one-time move re-filed the Aug 31 hotel session's 6 dumbbell sets.
        settings.historyUpdate = HistoryUpdateNote(setCount: 6, date: reclassifiedOn)
        let index = Index(exercises: exercises, gyms: gyms, machines: machines, models: models)
        return World(gyms: gyms, models: models, machines: machines, exercises: exercises,
                     templates: makeTemplates(), workouts: history.map { $0.build(index) },
                     settings: settings,
                     restSettings: [exerciseID("Leg Press"): RestSettings(workingSeconds: 180)])
    }

    // MARK: - Exercises (seeded names, tags and groups from the real catalog)

    private static let exerciseRows: [(String, LoadType, MuscleGroup?, [EquipmentTag], [String])] = [
        ("Seated Chest Press", .weighted, .chest, [.machine], ["Narrow grip", "Wide grip"]),
        ("Bench Press", .weighted, .chest, [.barbell], []),
        ("Incline Chest Press", .weighted, .chest, [.machine], []),
        ("Chest Fly (Pec Deck)", .weighted, .chest, [.machine], []),
        ("Cable Crossover", .weighted, .chest, [.cable], ["High pulley", "Low pulley"]),
        ("Dip", .bodyweightPlus, .chest, [.bodyweight], []),
        ("Assisted Dip", .assisted, .chest, [.machine], []),
        ("Dumbbell Bench Press", .weighted, .chest, [.dumbbell], []),
        ("Dumbbell Incline Press", .weighted, .chest, [.dumbbell], []),
        ("Dumbbell Fly", .weighted, .chest, [.dumbbell], []),
        ("Lat Pulldown", .weighted, .back, [.machine, .cable], ["Wide grip", "Neutral grip"]),
        ("Seated Row", .weighted, .back, [.machine, .cable], ["Narrow grip"]),
        ("Pull-Up", .bodyweightPlus, .back, [.bodyweight], []),
        ("Assisted Pull-Up", .assisted, .back, [.machine], []),
        ("T-Bar Row", .weighted, .back, [.machine], []),
        ("Chest-Supported Row", .weighted, .back, [.machine], []),
        ("Bent-Over Row", .weighted, .back, [.barbell], []),
        ("Deadlift", .weighted, .back, [.barbell, .machine], []),
        ("Dumbbell Row", .weighted, .back, [.dumbbell], []),
        ("Machine Shoulder Press", .weighted, .shoulders, [.machine], []),
        ("Lateral Raise", .weighted, .shoulders, [.machine], []),
        ("Rear Delt Fly", .weighted, .shoulders, [.machine], []),
        ("Overhead Press", .weighted, .shoulders, [.barbell], []),
        ("Dumbbell Shoulder Press", .weighted, .shoulders, [.dumbbell], []),
        ("Dumbbell Lateral Raise", .weighted, .shoulders, [.dumbbell], []),
        ("Dumbbell Curl", .weighted, .biceps, [.dumbbell], []),
        ("Machine Biceps Curl", .weighted, .biceps, [.machine, .cable], []),
        ("Preacher Curl", .weighted, .biceps, [.machine, .barbell], []),
        ("Triceps Pushdown", .weighted, .triceps, [.cable], []),
        ("Triceps Extension", .weighted, .triceps, [.machine], []),
        ("Overhead Triceps Extension", .weighted, .triceps, [.machine, .cable], []),
        ("Seated Dip", .weighted, .triceps, [.machine], []),
        ("Wrist Curl", .weighted, .forearms, [.machine], []),
        ("Grip Trainer", .weighted, .forearms, [.machine], []),
        ("Neck Machine", .weighted, .neck, [.machine], []),
        ("Leg Press", .weighted, .quads, [.machine], ["Feet high"]),
        ("Squat", .weighted, .quads, [.barbell], []),
        ("Leg Extension", .weighted, .quads, [.machine], []),
        ("Hack Squat", .weighted, .quads, [.machine], []),
        ("Smith Machine Squat", .weighted, .quads, [.smith], []),
        ("Bulgarian Split Squat", .weighted, .quads, [.dumbbell], []),
        ("Seated Leg Curl", .weighted, .hamstrings, [.machine], []),
        ("Lying Leg Curl", .weighted, .hamstrings, [.machine], []),
        ("Nordic Hamstring Curl", .bodyweightPlus, .hamstrings, [.bodyweight], []),
        ("Hip Thrust", .weighted, .glutes, [.machine], []),
        ("Glute Kickback", .weighted, .glutes, [.machine], []),
        ("Leg Abduction", .weighted, .hips, [.machine], []),
        ("Leg Adduction", .weighted, .hips, [.machine], []),
        ("Calf Raise", .weighted, .calves, [.machine], []),
        ("Seated Calf Raise", .weighted, .calves, [.machine], []),
        ("Abdominal Crunch", .weighted, .core, [.machine], []),
        ("Hanging Knee Raise", .bodyweightPlus, .core, [.bodyweight], []),
        ("Torso Rotation", .weighted, .core, [.machine], []),
        ("Jammer Press", .weighted, .fullBody, [.machine], []),
        ("Sled Push", .weighted, .fullBody, [.machine], []),
    ]

    static func makeExercises() -> [Exercise] {
        var list = exerciseRows.map { name, load, group, tags, presets in
            Exercise(id: exerciseID(name), name: name, loadType: load, muscleGroup: group, tags: tags,
                     presets: presets.map { ExercisePreset(id: presetID(name, $0), name: $0) })
        }
        // One user-created exercise with no body area (shows the "Uncategorized" path).
        list.append(Exercise(id: exerciseID("Landmine Press"), name: "Landmine Press", loadType: .weighted,
                             muscleGroup: nil, tags: [.barbell], isSeeded: false))
        return list
    }

    /// D51: "Log as Dumbbell Bench Press instead".
    static let dumbbellCounterparts: [String: String] = [
        "Bench Press": "Dumbbell Bench Press", "Chest Fly (Pec Deck)": "Dumbbell Fly",
        "Overhead Press": "Dumbbell Shoulder Press", "Lateral Raise": "Dumbbell Lateral Raise",
        "Bent-Over Row": "Dumbbell Row",
    ]

    /// Preset suggestions (ExercisePresets.suggestions).
    static let presetSuggestions = [
        "Wide grip", "Narrow grip", "Neutral grip", "Reverse grip", "Single arm", "Single leg",
        "Double leg", "High pulley", "Low pulley", "Feet high", "Feet low",
    ]

    /// Bar presets (BarbellMath).
    static let bars: [(title: String, weight: Double, unit: WeightUnit)] = [
        ("Olympic barbell", 20, .kg), ("Women's Olympic barbell", 15, .kg), ("Technique bar", 10, .kg),
        ("Olympic barbell", 45, .lb), ("Women's Olympic barbell", 35, .lb), ("Technique bar", 15, .lb),
    ]
    static func defaultBar(for unit: WeightUnit) -> Double { unit == .lb ? 45 : 20 }

    // MARK: - Gyms, models, machines

    static func makeGyms() -> [Gym] {
        [Gym(id: gymID(ironTemple), name: ironTemple, city: "Seoul", defaultUnit: .lb),
         Gym(id: gymID(gangnam), name: gangnam, city: "Seoul", defaultUnit: .kg),
         Gym(id: gymID(hotel), name: hotel, city: "New York", defaultUnit: nil)]
    }

    private static let modelRows: [(String, String, EquipmentCategory?, [String])] = [
        ("Life Fitness", "Insignia Series Chest Press", .selectorized, ["Seated Chest Press"]),
        ("Life Fitness", "Signature Series Chest Press", .selectorized, ["Seated Chest Press"]),
        ("Life Fitness", "Insignia Series Shoulder Press", .selectorized, ["Machine Shoulder Press"]),
        ("Life Fitness", "Insignia Series Lateral Raise", .selectorized, ["Lateral Raise"]),
        ("Life Fitness", "Insignia Series Pectoral Fly/Rear Deltoid", .selectorized, ["Chest Fly (Pec Deck)", "Rear Delt Fly"]),
        ("Life Fitness", "Insignia Series Pulldown", .selectorized, ["Lat Pulldown"]),
        ("Life Fitness", "Insignia Series Row", .selectorized, ["Seated Row"]),
        ("Life Fitness", "Insignia Series Leg Extension", .selectorized, ["Leg Extension"]),
        ("Life Fitness", "Insignia Series Seated Leg Curl", .selectorized, ["Seated Leg Curl"]),
        ("Life Fitness", "Insignia Series Abdominal", .selectorized, ["Abdominal Crunch"]),
        ("Life Fitness", "Insignia Series Assist Dip Chin", .selectorized, ["Assisted Pull-Up", "Assisted Dip"]),
        ("Life Fitness", "Insignia Series Hip Abduction / Adduction", .selectorized, ["Leg Abduction", "Leg Adduction"]),
        ("Life Fitness", "Insignia Series Biceps Curl", .selectorized, ["Machine Biceps Curl"]),
        ("Life Fitness", "Signature Series Dual Adjustable Pulley", .cable,
         ["Cable Crossover", "Lat Pulldown", "Triceps Pushdown", "Machine Biceps Curl"]),
        ("Life Fitness", "Axiom Series Multi-Press", .selectorized, ["Seated Chest Press", "Machine Shoulder Press"]),
        ("Life Fitness", "Plate Loaded Incline Press", .plateLoaded, ["Incline Chest Press"]),
        ("Hammer Strength", "Iso-Lateral Incline Press", .plateLoaded, ["Incline Chest Press"]),
        ("Hammer Strength", "Plate Loaded Linear Leg Press", .plateLoaded, ["Leg Press"]),
        ("Hammer Strength", "Smith Machine", .rackOrSmith, ["Smith Machine Squat"]),
        ("Hammer Strength", "Plate Loaded Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Hammer Strength", "Plate Loaded Glute Drive", .plateLoaded, ["Hip Thrust"]),
        ("Hammer Strength", "Select Chest Press", .selectorized, ["Seated Chest Press"]),
        ("Hammer Strength", "Select Lateral Raise", .selectorized, ["Lateral Raise"]),
        ("Hammer Strength", "Select Seated Leg Curl", .selectorized, ["Seated Leg Curl"]),
        ("Hammer Strength", "MTS Iso-Lateral Row", .selectorized, ["Seated Row"]),
        ("Technogym", "Selection 900 Lat Pulldown", .selectorized, ["Lat Pulldown"]),
        ("Technogym", "Selection 900 Shoulder Press", .selectorized, ["Machine Shoulder Press"]),
        ("Technogym", "Selection 900 Leg Press", .selectorized, ["Leg Press"]),
        ("Technogym", "Selection 900 Chest Press", .selectorized, ["Seated Chest Press"]),
        ("Technogym", "Selection 900 Leg Extension", .selectorized, ["Leg Extension"]),
        ("Technogym", "Pure Strength Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Matrix", "G7-S77 Calf Extension", .selectorized, ["Calf Raise"]),
        ("Matrix", "G7-S13 Converging Chest Press", .selectorized, ["Seated Chest Press"]),
        ("Matrix", "G7-S33 Diverging Lat Pulldown", .selectorized, ["Lat Pulldown"]),
        ("Matrix", "G7-S79 Hip Thrust", .selectorized, ["Hip Thrust"]),
        ("Matrix", "MG-PL71 Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Cybex", "Eagle NX Chest Press", .selectorized, ["Seated Chest Press"]),
        ("Cybex", "Eagle NX Leg Press", .selectorized, ["Leg Press"]),
        ("Watson", "PL Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Watson", "PL Linear Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Watson", "PL 30 Degree Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Gym80", "4159 Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Nautilus", "Hack Squat", .plateLoaded, ["Hack Squat"]),
        ("Precor", "Discovery Plate Loaded Hack Squat (DPL0603)", .plateLoaded, ["Hack Squat"]),
    ]

    static func makeModels() -> [EquipmentModel] {
        modelRows.map { maker, name, category, exercises in
            EquipmentModel(id: modelID("\(maker) \(name)"), manufacturer: maker, modelName: name,
                           category: category, exerciseIDs: exercises.map(exerciseID))
        }
    }

    // (gym, label, model display name, recognized exercises when no model, unit override, deleted on)
    private static let machineRows: [(String, String, String?, [String], WeightUnit?, Date?)] = [
        (ironTemple, "Chest Press 2", "Life Fitness Insignia Series Chest Press", [], nil, nil),
        (ironTemple, "Incline Press", "Hammer Strength Iso-Lateral Incline Press", [], nil, nil),
        (ironTemple, "Pec Deck", "Life Fitness Insignia Series Pectoral Fly/Rear Deltoid", [], nil, nil),
        (ironTemple, "Shoulder Press", "Life Fitness Insignia Series Shoulder Press", [], nil, nil),
        (ironTemple, "Lateral Raise", "Life Fitness Insignia Series Lateral Raise", [], nil, nil),
        (ironTemple, "Lat Pulldown", "Life Fitness Insignia Series Pulldown", [], nil, nil),
        (ironTemple, "Seated Row", "Life Fitness Insignia Series Row", [], nil, nil),
        (ironTemple, "Cable Station", "Life Fitness Signature Series Dual Adjustable Pulley", [], nil, nil),
        (ironTemple, "Leg Press", "Hammer Strength Plate Loaded Linear Leg Press", [], nil, nil),
        (ironTemple, "Leg Extension", "Life Fitness Insignia Series Leg Extension", [], nil, nil),
        (ironTemple, "Seated Leg Curl", "Life Fitness Insignia Series Seated Leg Curl", [], nil, nil),
        (ironTemple, "Calf Raise", "Matrix G7-S77 Calf Extension", [], .kg, nil),
        (ironTemple, "Ab Crunch", "Life Fitness Insignia Series Abdominal", [], nil, nil),
        (ironTemple, "Assist Dip/Chin", "Life Fitness Insignia Series Assist Dip Chin", [], nil, nil),
        (ironTemple, "Smith Machine", "Hammer Strength Smith Machine", [], nil, nil),
        (ironTemple, "Biceps Curl", nil, ["Machine Biceps Curl"], nil, nil),
        (ironTemple, "Chest Press 1", "Life Fitness Signature Series Chest Press", [], nil, date(2026, 9, 2, 19, 4)),
        (ironTemple, "Hip Abductor", "Life Fitness Insignia Series Hip Abduction / Adduction", [], nil, date(2026, 8, 30, 11, 20)),
        (gangnam, "Chest Press", "Life Fitness Insignia Series Chest Press", [], nil, nil),
        (gangnam, "Lat Pulldown", "Technogym Selection 900 Lat Pulldown", [], nil, nil),
        (gangnam, "Shoulder Press", "Technogym Selection 900 Shoulder Press", [], nil, nil),
        (gangnam, "Leg Press", "Technogym Selection 900 Leg Press", [], nil, nil),
    ]

    /// Usual presets (D38), preselected when the machine is chosen: (gym, label) → (exercise, preset).
    private static let usualPresets: [String: (String, String)] = [
        "\(ironTemple)|Seated Row": ("Seated Row", "Narrow grip"),
    ]

    static func makeMachines() -> [Machine] {
        machineRows.map { gym, label, model, recognized, unit, deletedAt in
            Machine(id: machineID(gym, label), gymID: gymID(gym), label: label, modelID: model.map(modelID),
                    recognizedExerciseIDs: recognized.map(exerciseID), defaultUnit: unit,
                    defaultPresetID: usualPresets["\(gym)|\(label)"].map { presetID($0.0, $0.1) },
                    isDeleted: deletedAt != nil, deletedAt: deletedAt)
        }
    }

    // MARK: - Templates

    private static func item(_ template: String, _ exercise: String, _ reps: [Int], rest: Int? = nil,
                             group: String? = nil, tag: EquipmentTag? = nil) -> TemplateItem {
        TemplateItem(id: .stable("item.\(template).\(exercise)"), exerciseID: exerciseID(exercise), targetReps: reps,
                     restSeconds: rest, supersetGroup: group.map { .stable("group.\(template).\($0)") }, equipmentTag: tag)
    }

    static func makeTemplates() -> [Template] {
        [
            Template(id: templateID("Whole Body"), name: "Whole Body", items: [
                item("Whole Body", "Bench Press", [10, 10, 10], group: "A", tag: .barbell),
                item("Whole Body", "Lat Pulldown", [10, 10, 10], group: "A"),
                item("Whole Body", "Machine Shoulder Press", [10, 10, 10]),
                item("Whole Body", "Dumbbell Curl", [10, 10, 10], tag: .dumbbell),
                item("Whole Body", "Leg Press", [12, 10, 8, 6]),
                item("Whole Body", "Abdominal Crunch", [10, 10, 10]),
            ]),
            Template(id: templateID("Push Day"), name: "Push Day", items: [
                item("Push Day", "Seated Chest Press", [12, 10, 8, 8], rest: 120),
                item("Push Day", "Incline Chest Press", [10, 10, 8, 8], rest: 120),
                item("Push Day", "Machine Shoulder Press", [12, 12, 10, 10], rest: 90),
                item("Push Day", "Lateral Raise", [12, 12, 12], rest: 60, group: "A"),
                item("Push Day", "Triceps Pushdown", [12, 12, 10], rest: 60, group: "A"),
            ], cardio: [PlannedCardio(id: .stable("plan.Push Day.run"), activity: .indoorRun, minutes: 20,
                                      distance: nil, unit: .mi)]),
            Template(id: templateID("Pull Day"), name: "Pull Day", items: [
                item("Pull Day", "Lat Pulldown", [12, 10, 10, 8], rest: 120),
                item("Pull Day", "Seated Row", [12, 10, 10], rest: 90),
                item("Pull Day", "Rear Delt Fly", [15, 12, 12], rest: 60),
                item("Pull Day", "Dumbbell Curl", [12, 10, 10], rest: 60, tag: .dumbbell),
            ]),
            Template(id: templateID("Leg Day"), name: "Leg Day", items: [
                item("Leg Day", "Leg Press", [12, 10, 10, 8], rest: 150),
                item("Leg Day", "Leg Extension", [12, 12, 10], rest: 90),
                item("Leg Day", "Seated Leg Curl", [12, 12, 10], rest: 90),
                item("Leg Day", "Calf Raise", [15, 15, 12], rest: 60),
            ]),
        ]
    }

    /// The Ask AI week (3 × "Day N — Fitness", 3 × 10 at 60 s, one 15-min cardio block
    /// per session — the real fixture). Saved, these become 3 AI templates for Iron Temple.
    static func aiWeek(days: Int = 3, available: Set<UUID>? = nil, cardio: Set<CardioActivity> = [.indoorRun, .indoorCycle],
                       unit: DistanceUnit = .mi) -> [AIRoutineDay] {
        let plans: [[String]] = [
            ["Seated Chest Press", "Lat Pulldown", "Machine Shoulder Press", "Triceps Pushdown"],
            ["Leg Press", "Leg Extension", "Seated Leg Curl", "Calf Raise", "Abdominal Crunch"],
            ["Seated Row", "Incline Chest Press", "Lateral Raise", "Rear Delt Fly", "Dumbbell Curl"],
            ["Hack Squat", "Hip Thrust", "Lying Leg Curl", "Seated Calf Raise"],
            ["Chest Fly (Pec Deck)", "Chest-Supported Row", "Dumbbell Shoulder Press", "Machine Biceps Curl"],
        ]
        let cardioOrder = CardioActivity.allCases.filter { cardio.contains($0) }
        return (0..<max(1, min(7, days))).map { day in
            let names = plans[day % plans.count].filter { available?.contains(exerciseID($0)) ?? true }
            let fallback = plans.flatMap { $0 }.filter { available?.contains(exerciseID($0)) ?? true }
            let chosen = names.count >= 3 ? names : Array(fallback.prefix(4))
            let items = chosen.map { name in
                AIRoutineItem(id: .stable("ai.\(day).\(name)"), exerciseID: exerciseID(name), sets: 3, reps: 10, restSeconds: 60)
            }
            let block = day % 2 == 0 && !cardioOrder.isEmpty
                ? [PlannedCardio(id: .stable("ai.\(day).cardio"), activity: cardioOrder[(day / 2) % cardioOrder.count],
                                 minutes: 15, distance: nil, unit: unit)] : []
            return AIRoutineDay(id: .stable("ai.day.\(day)"), name: "Day \(day + 1) — Fitness", items: items, cardio: block)
        }
    }

    // MARK: - History DSL

    struct Index {
        var exercises: [Exercise]
        var gyms: [Gym]
        var machines: [Machine]
        var models: [EquipmentModel]
        func exercise(_ name: String) -> Exercise { exercises.first { $0.name == name }! }
        func gym(_ name: String?) -> Gym? { name.flatMap { n in gyms.first { $0.name == n } } }
        func machine(_ gym: String?, _ label: String) -> Machine? {
            guard let gym else { return nil }
            return machines.first { $0.id == machineID(gym, label) }
        }
        func model(_ id: UUID?) -> EquipmentModel? { id.flatMap { id in models.first { $0.id == id } } }
    }

    struct CardioSpec {
        var activity: CardioActivity
        var seconds: Int
        var miles: Double?
        var avgHR: Int?
        var maxHR: Int?
        var calories: Int?
        var route: [RoutePoint] = []
    }

    struct HRSpec {
        var average: Int
        var maximum: Int
        var cardio = false
        var gap: ClosedRange<Int>?
        var zones: [Int]?
    }

    /// One stretch of a session's heart rate (lifting-shaped or steady cardio).
    struct HRPhase {
        var seconds: Int
        var spec: HRSpec
    }

    /// One history workout, written compactly. Entry lines:
    /// `"Name @Machine ~Preset | W45x12 100x10 F105x6 D90x12 B45:25x10 x12"`; a leading `&`
    /// joins the previous entry's superset; `#tag` for free weights; `B<bar>:<perSide>x<reps>` is bar mode;
    /// `x12` = no weight (bodyweight); BW + added and assisted log `0x12` for a plain set.
    struct Spec {
        var key: String
        var start: Date
        var minutes: Double
        var template: String?
        var name: String?
        var gym: String?
        var lines: [String] = []
        var cardio: [CardioSpec] = []
        var hr: HRSpec?
        var active: Int?
        var basal: Int?
        var edited: Date?
        var notes = ""
        /// D51: new exercise name → the name it was logged under (stamped `reclassifiedAt`).
        var reclassified: [String: String] = [:]
        var reclassifiedAt: Date?
        /// A multi-phase HR series (lifting then cardio); overrides `hr`.
        var hrPhases: [HRPhase]?

        func build(_ index: Index) -> Workout {
            let id = workoutID(key)
            let duration = Int(minutes * 60)
            let gymModel = index.gym(gym)
            let totalSets = lines.reduce(0) { $0 + ($1.split(separator: "|").last?.split(separator: " ").count ?? 0) }
            var setIndex = 0
            var entries: [WorkoutEntry] = []
            let liftingSeconds = Double(duration - cardio.reduce(0) { $0 + $1.seconds })
            for (n, raw) in lines.enumerated() {
                let parts = raw.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                var head = parts[0]
                let joins = head.hasPrefix("&")
                if joins { head = String(head.dropFirst()).trimmingCharacters(in: .whitespaces) }
                var presetName: String?, machineLabel: String?, tag: EquipmentTag?
                if let r = head.range(of: " ~") { presetName = String(head[r.upperBound...]); head = String(head[..<r.lowerBound]) }
                if let r = head.range(of: " @") { machineLabel = String(head[r.upperBound...]); head = String(head[..<r.lowerBound]) }
                if let r = head.range(of: " #") { tag = EquipmentTag(rawValue: String(head[r.upperBound...])); head = String(head[..<r.lowerBound]) }
                let exercise = index.exercise(head)
                let machine = machineLabel.flatMap { index.machine(gym, $0) }
                let unit = machine?.defaultUnit ?? gymModel?.defaultUnit ?? .lb
                var sets: [LoggedSet] = []
                for token in parts[1].split(separator: " ").map(String.init) {
                    setIndex += 1
                    var t = Substring(token)
                    var type = SetType.working
                    if let first = t.first, let kind = ["W": SetType.warmup, "F": .failure, "D": .drop][String(first)] {
                        type = kind; t = t.dropFirst()
                    }
                    var bar: Double?
                    if t.hasPrefix("B"), let colon = t.firstIndex(of: ":") {
                        bar = Double(t[t.index(after: t.startIndex)..<colon]); t = t[t.index(after: colon)...]
                    }
                    let pieces = t.split(separator: "x", omittingEmptySubsequences: false)
                    var weight = pieces[0].isEmpty ? nil : Double(pieces[0])
                    if let b = bar { weight = b + 2 * (weight ?? 0) }
                    let at = start.addingTimeInterval(liftingSeconds * Double(setIndex) / Double(totalSets + 1))
                    sets.append(LoggedSet(id: .stable("set.\(key).\(setIndex)"), type: type, weight: weight, unit: unit,
                                          reps: Int(pieces[1]), barWeight: bar, completedAt: at))
                }
                let group: UUID? = joins ? .stable("group.\(key).\(n - 1)") : nil
                if joins, !entries.isEmpty { entries[entries.count - 1].supersetGroup = group }
                entries.append(WorkoutEntry(
                    id: .stable("entry.\(key).\(n)"), exerciseID: exercise.id, exerciseName: exercise.name,
                    loadType: exercise.loadType, machineID: machine?.id, machineLabel: machine?.label,
                    modelName: index.model(machine?.modelID)?.displayName,
                    freeWeightTag: machine == nil ? (tag ?? exercise.tags.first { $0 != .machine }) : nil,
                    presetID: presetName.map { presetID(exercise.name, $0) }, presetName: presetName,
                    supersetGroup: group, sets: sets,
                    reclassifiedAt: reclassified[exercise.name] != nil ? reclassifiedAt : nil,
                    reclassifiedFromExerciseName: reclassified[exercise.name]))
            }
            var cardioStart = start.addingTimeInterval(liftingSeconds)
            let segments = cardio.enumerated().map { i, c -> CardioSegment in
                defer { cardioStart = cardioStart.addingTimeInterval(TimeInterval(c.seconds)) }
                let routeMeters = zip(c.route, c.route.dropFirst()).reduce(0) { $0 + Derived.meters($1.0, $1.1) }
                return CardioSegment(id: .stable("segment.\(key).\(i)"), activity: c.activity, startedAt: cardioStart,
                                     activeSeconds: c.seconds,
                                     measuredMeters: c.miles.map { $0 * DistanceUnit.mi.metersPerUnit } ?? (routeMeters > 0 ? routeMeters : nil),
                                     manualDistance: nil, unit: .mi, averageHeartRate: c.avgHR, maxHeartRate: c.maxHR,
                                     activeCalories: c.calories, route: c.route)
            }
            let summary = hrPhases.map { SampleData.heartRate(seed: key.hashValue64, phases: $0) }
                ?? hr.map { SampleData.heartRate(seed: key.hashValue64, duration: duration, spec: $0) }
            return Workout(id: id, name: name, templateID: template.map(templateID), templateName: template,
                           startedAt: start, durationSeconds: duration, gymID: gymModel?.id, gymName: gymModel?.name,
                           entries: entries, cardio: segments, heartRate: summary, activeCalories: active,
                           basalCalories: basal, editedAt: edited, notes: notes)
        }
    }

    // MARK: - History (22 workouts)

    static let history: [Spec] = [
        Spec(key: "2026-08-10", start: date(2026, 8, 10, 18, 40), minutes: 64, template: "Whole Body", gym: ironTemple, lines: [
            "Bench Press #barbell | B45:25x10 B45:35x10 B45:35x8",
            "& Lat Pulldown @Lat Pulldown | 90x10 100x10 100x10",
            "Machine Shoulder Press @Shoulder Press | 50x10 55x10 55x10",
            "Dumbbell Curl #dumbbell | 20x10 20x10 20x10",
            "Leg Press @Leg Press | 180x12 200x10 220x8 220x6",
            "Abdominal Crunch @Ab Crunch | 60x15 70x12 70x12",
            "Seated Chest Press @Chest Press 2 | 90x8 90x8 85x10",
        ]),
        Spec(key: "2026-08-12", start: date(2026, 8, 12, 19, 5), minutes: 52, template: "Push Day", gym: ironTemple, lines: [
            "Seated Chest Press @Chest Press 2 | W45x12 95x8 95x8 95x7",
            "Incline Chest Press @Incline Press | W70x10 110x10 120x10 120x8",
            "Machine Shoulder Press @Shoulder Press | W30x12 55x10 55x10 55x10",
            "Lateral Raise @Lateral Raise | 45x12 50x12 50x10",
            "Triceps Pushdown @Cable Station | 70x12 75x12 80x10",
        ], hr: HRSpec(average: 121, maximum: 152), active: 290, basal: 84),
        Spec(key: "2026-08-13", start: date(2026, 8, 13, 7, 10), minutes: 25.5, gym: ironTemple,
             cardio: [CardioSpec(activity: .indoorRun, seconds: 1500, miles: 2.5, avgHR: 146, maxHR: 166, calories: 262)],
             hr: HRSpec(average: 146, maximum: 166, cardio: true), active: 262, basal: 42),
        Spec(key: "2026-08-15", start: date(2026, 8, 15, 10, 20), minutes: 50, template: "Pull Day", gym: ironTemple, lines: [
            "Lat Pulldown @Lat Pulldown | W50x12 100x12 110x10 110x10 120x8",
            "Assisted Pull-Up @Assist Dip/Chin | 90x8 90x8 90x6",
            "Seated Row @Seated Row ~Narrow grip | 90x12 100x10 100x10",
            "Rear Delt Fly @Pec Deck | 40x15 45x12 45x12",
            "Dumbbell Curl #dumbbell | 20x10 20x10 20x10",
        ], hr: HRSpec(average: 118, maximum: 149), active: 251, basal: 80),
        Spec(key: "2026-08-17", start: date(2026, 8, 17, 18, 50), minutes: 56, template: "Leg Day", gym: ironTemple, lines: [
            "Leg Press @Leg Press | W90x15 200x12 230x10 250x10 270x8",
            "Leg Extension @Leg Extension | 70x12 80x12 80x10",
            "Seated Leg Curl @Seated Leg Curl | 60x12 70x12 70x10",
            "Calf Raise @Calf Raise | 40x15 50x15 50x12",
        ], hr: HRSpec(average: 124, maximum: 158), active: 318, basal: 90),
        Spec(key: "2026-08-19", start: date(2026, 8, 19, 19, 30), minutes: 49, template: "Push Day", gym: gangnam, lines: [
            "Seated Chest Press @Chest Press | W20x12 45x8 45x8 42.5x10",
            "Dumbbell Incline Press #dumbbell | 20x10 22.5x10 22.5x8",
            "Machine Shoulder Press @Shoulder Press | 25x10 27.5x10 27.5x8",
            "Dumbbell Lateral Raise #dumbbell | 8x12 8x12 8x10",
            "Triceps Pushdown #cable | 30x12 32.5x12 35x10",
        ], hr: HRSpec(average: 120, maximum: 150), active: 262, basal: 79),
        Spec(key: "2026-08-20", start: date(2026, 8, 20, 7, 0), minutes: 30.5, gym: ironTemple,
             cardio: [CardioSpec(activity: .indoorCycle, seconds: 1800, miles: 9.2, avgHR: 132, maxHR: 151, calories: 241)],
             hr: HRSpec(average: 132, maximum: 151, cardio: true), active: 241, basal: 49),
        Spec(key: "2026-08-22", start: date(2026, 8, 22, 10, 40), minutes: 51, template: "Pull Day", gym: ironTemple, lines: [
            "Lat Pulldown @Lat Pulldown | W50x12 110x12 115x10 115x10 120x8",
            "Assisted Pull-Up @Assist Dip/Chin | 90x8 90x8 90x7",
            "Seated Row @Seated Row ~Narrow grip | 100x12 105x10 110x10",
            "Rear Delt Fly @Pec Deck | 40x15 45x12 45x12",
            "Dumbbell Curl #dumbbell | 20x10 20x10 20x10",
        ], hr: HRSpec(average: 119, maximum: 150), active: 258, basal: 82),
        Spec(key: "2026-08-24", start: date(2026, 8, 24, 18, 45), minutes: 57, template: "Leg Day", gym: ironTemple, lines: [
            "Leg Press @Leg Press | W90x15 230x12 250x10 270x10 290x8",
            "Leg Extension @Leg Extension | 80x12 85x12 90x10",
            "Seated Leg Curl @Seated Leg Curl | 60x12 70x12 70x10",
            "Calf Raise @Calf Raise | 40x15 50x15 50x12",
        ], hr: HRSpec(average: 126, maximum: 161), active: 331, basal: 92),
        Spec(key: "2026-08-26", start: date(2026, 8, 26, 19, 10), minutes: 53, template: "Push Day", gym: ironTemple, lines: [
            "Seated Chest Press @Chest Press 2 | W45x12 100x8 100x8 95x10",
            "Incline Chest Press @Incline Press | W90x10 110x10 120x10 120x8 120x8",
            "Machine Shoulder Press @Shoulder Press | W40x12 65x10 70x8 70x8",
            "Lateral Raise @Lateral Raise | 45x12 50x12 50x10",
            "Triceps Pushdown @Cable Station | 70x12 75x12 80x10",
            "Dip #bodyweight | 0x10 10x8 10x8",
        ], hr: HRSpec(average: 122, maximum: 154), active: 297, basal: 86),
        Spec(key: "2026-08-27", start: date(2026, 8, 27, 18, 30), minutes: 61, template: "Whole Body", gym: ironTemple, lines: [
            "Bench Press #barbell | B45:35x10 B45:40x10 B45:40x8",
            "& Lat Pulldown @Lat Pulldown | 110x10 110x10 110x10",
            "Machine Shoulder Press @Shoulder Press | 60x10 60x10 60x10",
            "Dumbbell Curl #dumbbell | 25x10 25x10 25x10",
            "Leg Press @Leg Press | 230x12 250x10 270x8 270x6",
            "Abdominal Crunch @Ab Crunch | 70x15 80x12 80x12",
            "Seated Chest Press @Chest Press 2 ~Narrow grip | 85x10 85x10 80x12",
        ], hr: HRSpec(average: 117, maximum: 148), active: 322, basal: 99),
        Spec(key: "2026-08-29", start: date(2026, 8, 29, 8, 10), minutes: 37, cardio: [
            CardioSpec(activity: .outdoorRun, seconds: 2210, miles: 4.1, avgHR: 151, maxHR: 172, calories: 356,
                       route: route(centralPark, count: 30, duration: 2210)),
        ], hr: HRSpec(average: 151, maximum: 172, cardio: true), active: 356, basal: 59),
        // Logged as Bench Press / Bent-Over Row with the dumbbell tag; the D51 move re-filed them.
        Spec(key: "2026-08-31", start: date(2026, 8, 31, 7, 30), minutes: 46, template: "Whole Body", name: "Hotel Session",
             gym: hotel, lines: [
            "Dumbbell Bench Press #dumbbell | 40x10 45x10 45x8",
            "Dumbbell Row #dumbbell | 45x10 50x10 50x10",
            "Dumbbell Shoulder Press #dumbbell | 30x10 35x8 35x8",
            "Dumbbell Curl #dumbbell | 25x10 25x10 25x8",
            "Bulgarian Split Squat #dumbbell | 25x10 25x10 25x8",
            "Hanging Knee Raise #bodyweight | 0x12 0x12 0x10",
        ], reclassified: ["Dumbbell Bench Press": "Bench Press", "Dumbbell Row": "Bent-Over Row"],
             reclassifiedAt: reclassifiedOn),
        Spec(key: "2026-09-10", start: date(2026, 9, 10, 18, 35), minutes: 66, template: "Whole Body", gym: ironTemple, lines: [
            "Bench Press #barbell | WB45:0x10 B45:40x10 B45:40x8 B45:40x8",
            "& Lat Pulldown @Lat Pulldown | W50x12 110x10 115x10 115x10",
            "Machine Shoulder Press @Shoulder Press | 65x10 70x8 70x8",
            "Dumbbell Curl #dumbbell | 25x10 25x10 25x10",
            "Leg Press @Leg Press | 250x12 270x10 290x8 290x6",
            "Abdominal Crunch @Ab Crunch | 70x15 80x12 80x12",
            "Seated Chest Press @Chest Press 2 | 100x10 100x10 100x9",
        ], hr: HRSpec(average: 119, maximum: 151), active: 351, basal: 107),
        Spec(key: "2026-09-12", start: date(2026, 9, 12, 10, 15), minutes: 54, template: "Push Day", gym: ironTemple, lines: [
            "Seated Chest Press @Chest Press 2 | W45x12 100x8 100x8 100x8",
            "Incline Chest Press @Incline Press | W90x10 140x10 150x8 160x8 160x7",
            "Machine Shoulder Press @Shoulder Press | W40x12 65x10 70x8 70x8",
            "Lateral Raise @Lateral Raise | 62.5x12 65x12 65x10 65x10",
            "& Triceps Pushdown @Cable Station | 100x12 105x12 110x10 105x10",
            "Dip #bodyweight | 0x12 15x8 15x6",
        ], hr: HRSpec(average: 123, maximum: 155), active: 306, basal: 88),
        Spec(key: "2026-09-15", start: date(2026, 9, 15, 18, 40), minutes: 50, template: "Pull Day", gym: ironTemple, lines: [
            "Lat Pulldown @Lat Pulldown | W60x12 120x12 130x10 130x10 135x8",
            "Assisted Pull-Up @Assist Dip/Chin | 80x8 80x8 80x6",
            "Seated Row @Seated Row ~Narrow grip | 100x12 110x10 110x10",
            "Rear Delt Fly @Pec Deck | 40x15 45x12 45x12",
            "Dumbbell Curl #dumbbell | 25x10 25x10 25x8",
        ], hr: HRSpec(average: 120, maximum: 152), active: 262, basal: 81),
        Spec(key: "2026-09-16", start: date(2026, 9, 16, 18, 30), minutes: 54, template: "Leg Day", gym: ironTemple, lines: [
            "Leg Press @Leg Press | W90x15 270x12 290x10 310x10 330x8",
            "Leg Extension @Leg Extension | 85x12 90x10 90x10",
            "Seated Leg Curl @Seated Leg Curl | 80x12 85x12 90x10",
            "Calf Raise @Calf Raise | 50x15 50x15 50x12",
        ], hr: HRSpec(average: 125, maximum: 160, gap: 1920...1995), active: 324, basal: 88),
        Spec(key: "2026-09-17", start: date(2026, 9, 17, 18, 35), minutes: 50, template: "Push Day", gym: ironTemple, lines: [
            "Seated Chest Press @Chest Press 2 | W45x12 100x10 105x8 105x8",
            "Incline Chest Press @Incline Press | W90x10 140x10 150x8 160x8 160x8",
            "Machine Shoulder Press @Shoulder Press | W40x12 70x10 75x8 80x8",
            "Lateral Raise @Lateral Raise | 62.5x12 65x12 65x10 65x12",
            "& Triceps Pushdown @Cable Station | 100x12 105x12 110x10 110x10",
        ], hr: HRSpec(average: 121, maximum: 156), active: 296, basal: 82, edited: date(2026, 9, 18, 9, 12)),
        // H03 (Workout Detail): bar breakdowns with a warmup, superset A/B, a preset, free weights,
        // a cardio segment, two-phase HR and an Edited mark.
        Spec(key: "2026-09-19", start: date(2026, 9, 19, 10, 30), minutes: 67, template: "Whole Body", gym: ironTemple, lines: [
            "Bench Press #barbell | WB45:0x10 B45:45x10 B45:45x8 B45:50x6",
            "& Lat Pulldown @Lat Pulldown | 120x10 120x10 125x10",
            "Machine Shoulder Press @Shoulder Press | 70x10 70x10 70x10",
            "Dumbbell Curl #dumbbell | 25x10 25x10 25x8",
            "Leg Press @Leg Press | 270x12 290x10 310x8 310x6",
            "Abdominal Crunch @Ab Crunch | 70x15 80x12 80x12",
            "Seated Chest Press @Chest Press 2 ~Narrow grip | 90x10 90x10 90x9",
        ], cardio: [CardioSpec(activity: .indoorCycle, seconds: 900, miles: 4.6, avgHR: 128, maxHR: 141, calories: 118)],
             hr: HRSpec(average: 121, maximum: 153), active: 421, basal: 110, edited: date(2026, 9, 20, 8, 40),
             hrPhases: [HRPhase(seconds: 3120, spec: HRSpec(average: 119, maximum: 153)),
                        HRPhase(seconds: 900, spec: HRSpec(average: 128, maximum: 141, cardio: true))]),
        Spec(key: "2026-09-21", start: date(2026, 9, 21, 18, 20), minutes: 48, template: "Pull Day", gym: ironTemple, lines: [
            "Lat Pulldown @Lat Pulldown | W60x12 120x12 130x10 130x10 135x8",
            "Assisted Pull-Up @Assist Dip/Chin | 70x8 70x8 70x7",
            "Seated Row @Seated Row ~Narrow grip | 105x12 110x10 110x10",
            "Rear Delt Fly @Pec Deck | 40x15 45x12 45x12",
            "Dumbbell Curl #dumbbell | 30x10 30x10 30x10 F30x7",
        ], hr: HRSpec(average: 119, maximum: 151), active: 254, basal: 78),
        Spec(key: "2026-09-21-run", start: date(2026, 9, 21, 19, 15), minutes: 29, gym: ironTemple,
             cardio: [CardioSpec(activity: .indoorRun, seconds: 1720, miles: 3.1, avgHR: 149, maxHR: 171, calories: 318)],
             hr: HRSpec(average: 149, maximum: 171, cardio: true), active: 318, basal: 44),
        Spec(key: "2026-09-23", start: date(2026, 9, 23, 18, 40), minutes: 55, template: "Leg Day", gym: ironTemple, lines: [
            "Leg Press @Leg Press | W90x15 290x12 310x10 320x10 330x8",
            "Leg Extension @Leg Extension | 70x12 70x12 70x12",
            "Seated Leg Curl @Seated Leg Curl | 80x12 85x12 90x10",
            "Calf Raise @Calf Raise | 65x15 70x15 70x12",
        ], hr: HRSpec(average: 124, maximum: 158), active: 327, basal: 89,
             notes: "Left knee felt tight on leg extensions, kept them light."),
    ]

    // MARK: - Today's Push Day (the finish scenario)

    /// Push Day, finished today: 52:10, 18,450 lb, 22 sets, 5 exercises, 312 / 398 cal,
    /// 124 / 158 bpm, zones 6:40 · 14:20 · 18:05 · 9:30 · 3:35. New bests: Seated Chest
    /// Press 110 × 8 and Machine Shoulder Press 80 × 10. vs Sep 17: 17,400 lb (+6%).
    static let todayPushDayLines = [
        "Seated Chest Press @Chest Press 2 | W45x12 100x10 110x8 110x8 110x7",
        "Incline Chest Press @Incline Press | W90x10 140x10 160x8 160x8 160x8",
        "Machine Shoulder Press @Shoulder Press | W40x12 70x12 75x8 80x10",
        "Lateral Raise @Lateral Raise | 60x12 65x12 65x10 65x10",
        "& Triceps Pushdown @Cable Station | 100x12 105x12 110x10 D90x12",
    ]

    static func todayPushDay(withRun: Bool = false) -> Spec {
        let lifting = 3130.0
        var spec = Spec(key: withRun ? "2026-09-24-mixed" : "2026-09-24", start: today.addingTimeInterval(-lifting - (withRun ? 1260 : 0)),
                        minutes: (lifting + (withRun ? 1260 : 0)) / 60, template: "Push Day", gym: ironTemple,
                        lines: todayPushDayLines,
                        hr: HRSpec(average: 124, maximum: 158, zones: [400, 860, 1085, 570, 215, 0]),
                        active: 312, basal: 86)
        if withRun {
            spec.cardio = [CardioSpec(activity: .outdoorRun, seconds: 1170, miles: nil, avgHR: 152, maxHR: 168, calories: 221,
                                      route: loop(center: (37.5443, 127.0374), radii: (0.0045, 0.0065), count: 32, duration: 1170))]
            // Lifting (3,220 s incl. the walk out), then the run: the run shows in the graph.
            spec.hr = HRSpec(average: 131, maximum: 168)
            spec.hrPhases = [HRPhase(seconds: 3220, spec: HRSpec(average: 124, maximum: 158)),
                             HRPhase(seconds: 1170, spec: HRSpec(average: 152, maximum: 168, cardio: true))]
            spec.active = 533
            spec.basal = 112
        }
        return spec
    }

    static func index(_ world: World) -> Index {
        Index(exercises: world.exercises, gyms: world.gyms, machines: world.machines, models: world.models)
    }

    // MARK: - Routes

    /// Central Park loop from the real route fixture's start (40.7725, −73.9744): up the
    /// West Drive, across the 102nd St transverse, down the East Drive, back across 72nd.
    static let centralPark: [(Double, Double)] = [
        (40.7725, -73.9744), (40.7768, -73.9725), (40.7802, -73.9700), (40.7838, -73.9676),
        (40.7872, -73.9652), (40.7905, -73.9630), (40.7940, -73.9606), (40.7962, -73.9588),
        (40.7952, -73.9562), (40.7936, -73.9536), (40.7905, -73.9552), (40.7870, -73.9575),
        (40.7836, -73.9592), (40.7800, -73.9620), (40.7765, -73.9648), (40.7735, -73.9672),
        (40.7718, -73.9695), (40.7722, -73.9720), (40.7725, -73.9744),
    ]

    /// `count` points evenly spaced by distance along `waypoints`, timestamps spread over `duration`.
    static func route(_ waypoints: [(Double, Double)], count: Int, duration: Int) -> [RoutePoint] {
        let points = waypoints.map { RoutePoint(latitude: $0.0, longitude: $0.1, offset: 0) }
        var cumulative = [0.0]
        for i in 1..<points.count { cumulative.append(cumulative[i - 1] + Derived.meters(points[i - 1], points[i])) }
        let total = cumulative.last ?? 0
        return (0..<count).map { k in
            let target = total * Double(k) / Double(count - 1)
            let i = max(1, cumulative.firstIndex { $0 >= target } ?? points.count - 1)
            let span = cumulative[i] - cumulative[i - 1]
            let t = span > 0 ? (target - cumulative[i - 1]) / span : 0
            return RoutePoint(latitude: points[i - 1].latitude + t * (points[i].latitude - points[i - 1].latitude),
                              longitude: points[i - 1].longitude + t * (points[i].longitude - points[i - 1].longitude),
                              offset: Double(duration) * Double(k) / Double(count - 1))
        }
    }

    /// An elliptical loop (Seoul Forest for today's run).
    static func loop(center: (Double, Double), radii: (Double, Double), count: Int, duration: Int) -> [RoutePoint] {
        (0..<count).map { k in
            let a = 2 * Double.pi * Double(k) / Double(count - 1)
            return RoutePoint(latitude: center.0 + radii.0 * sin(a), longitude: center.1 + radii.1 * cos(a),
                              offset: Double(duration) * Double(k) / Double(count - 1))
        }
    }

    // MARK: - Heart-rate series

    /// A deterministic 15-second series shaped like a lifting session (efforts and
    /// rests) or a steady cardio session, scaled so its mean and peak match the spec.
    static func heartRate(seed: UInt64, duration: Int, spec: HRSpec, maxHR: Int = 185) -> HeartRateSummary {
        var rng = seed | 1
        func noise() -> Double {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Double((rng >> 33) % 1000) / 1000 - 0.5
        }
        let count = max(1, Int((Double(duration) / 15).rounded(.up)))
        var raw: [Double] = []
        for i in 0..<count {
            let t = Double(i * 15)
            let warm = min(1, t / 300)
            let shape: Double
            if spec.cardio {
                shape = 0.55 + 0.25 * sin(t / 420) + 0.1 * sin(t / 97)
            } else {
                let phase = t.truncatingRemainder(dividingBy: 165) / 165
                let s = phase < 0.3 ? sin(phase / 0.3 * .pi / 2) : max(0, 1 - (phase - 0.3) / 0.55)
                shape = s * s
            }
            raw.append(0.35 + warm * shape + noise() * 0.12)
        }
        let rawMean = raw.reduce(0, +) / Double(raw.count)
        let rawMax = raw.max() ?? 1
        let k = rawMax - rawMean > 0 ? Double(spec.maximum - spec.average) / (rawMax - rawMean) : 1
        var mean = raw.map { Int((Double(spec.average) + ($0 - rawMean) * k).rounded()) }
        var low = mean.map { $0 - 2 - Int(abs(noise()) * 8) }
        var high = zip(mean, raw).map { m, _ in min(spec.maximum, m + 2 + Int(abs(noise()) * 8)) }
        if let peak = mean.indices.max(by: { mean[$0] < mean[$1] }) { high[peak] = spec.maximum }
        if let gap = spec.gap {
            for i in mean.indices where gap.contains(i * 15) { mean[i] = 0; low[i] = 0; high[i] = 0 }
        }
        let series = HeartRateSeries(mean: mean, low: low, high: high)
        return HeartRateSummary(average: spec.average, maximum: spec.maximum,
                                zoneSeconds: spec.zones ?? Derived.zoneSeconds(series: series, max: maxHR),
                                series: series, source: .airPods)
    }

    /// Phases joined end to end (e.g. lifting, then a run), so each stretch keeps its own shape.
    /// Average = time-weighted phase averages; maximum = the highest phase maximum.
    static func heartRate(seed: UInt64, phases: [HRPhase], maxHR: Int = 185) -> HeartRateSummary {
        var mean: [Int] = [], low: [Int] = [], high: [Int] = []
        var weighted = 0.0, total = 0, peak = 0
        for (i, phase) in phases.enumerated() {
            let part = heartRate(seed: seed &+ UInt64(i) &* 0x9e37_79b9, duration: phase.seconds, spec: phase.spec, maxHR: maxHR)
            mean += part.series?.mean ?? []
            low += part.series?.low ?? []
            high += part.series?.high ?? []
            weighted += Double(phase.spec.average * phase.seconds)
            total += phase.seconds
            peak = max(peak, phase.spec.maximum)
        }
        let series = HeartRateSeries(mean: mean, low: low, high: high)
        return HeartRateSummary(average: Int((weighted / Double(max(1, total))).rounded()), maximum: peak,
                                zoneSeconds: Derived.zoneSeconds(series: series, max: maxHR),
                                series: series, source: .airPods)
    }
}

extension String {
    /// A process-stable 64-bit hash (Swift's `hashValue` is seeded per launch).
    var hashValue64: UInt64 {
        utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01b3 }
    }
}
