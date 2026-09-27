import Foundation
import SwiftData

// A lived-in store for the Floodlight redesign's captures: one gym, three templates, and two
// weeks of finished workouts relative to today, so "This week", the template tiles' last-run
// dates and History show real content in the simulator (which has no past). Requires
// `-uiTestReset` too (`WorkoutTrackerStore.fixtureIsEnabled`), so it can never seed a real store.

enum DesignSampleFixture {
    static let launchArgument = "-uiTestDesignSample"

    static var isEnabled: Bool {
        WorkoutTrackerStore.fixtureIsEnabled(launchArgument)
    }

    /// With `-uiTestDesignLive` too: Push Day is running at Iron Temple, 18 minutes in, with two
    /// sets logged on the chest press and a rest counting down (the live workout's captures).
    static let liveArgument = "-uiTestDesignLive"
    /// With `-uiTestDesignLiveEmpty` instead: an empty workout just started at Iron Temple.
    static let emptyLiveArgument = "-uiTestDesignLiveEmpty"
    /// With `-uiTestDesignLive` too: a barbell Bench Press on a 45 lb bar — 90 lb × 10 five days
    /// ago, and today a logged 102.5 lb × 10, a bar-mode new best (the receipt's bar annotation).
    static let barBestArgument = "-uiTestDesignBarBest"
    /// With `-uiTestDesignHistory` too (ticket 05, History's captures): weights climb session by
    /// session (new bests), the newest workout carries a heart-rate series with time in zones,
    /// Pull Day three days ago has a note, Leg Day nine days ago logs its calf raise in kg
    /// ("kg + lb"), and Pull Day eleven days ago is marked edited.
    static let historyArgument = "-uiTestDesignHistory"
    /// With `-uiTestDesignGyms` too (ticket 06, the Gyms captures): Iron Temple gets the machines
    /// the Pull and Leg Day templates use (so their history lands on them), a cable station, a
    /// machine with no model, a kg override and a deleted machine; Hotel Gym (New York) has one
    /// visit; Gangnam Fitness is deleted.
    static let gymsArgument = "-uiTestDesignGyms"
    static var gymsIsEnabled: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains(gymsArgument)
    }
    static var historyIsEnabled: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains(historyArgument)
    }
    static var liveIsEnabled: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains(liveArgument)
    }

    /// Machines at the gym: label, catalog model (manufacturer, model name), the exercise it serves.
    static let machines: [(label: String, manufacturer: String, model: String, exercise: String)] = [
        ("Chest Press 2", "Life Fitness", "Insignia Series Chest Press", "Seated Chest Press"),
        ("Incline Press", "Hammer Strength", "Iso-Lateral Incline Press", "Incline Chest Press"),
    ]

    static let gymName = "Iron Temple"

    /// The Gyms captures' extra machines at Iron Temple (`-uiTestDesignGyms`).
    static let gymMachines: [(label: String, manufacturer: String, model: String, exercise: String)] = [
        ("Lat Pulldown", "Life Fitness", "Insignia Series Pulldown", "Lat Pulldown"),
        ("Seated Row", "Life Fitness", "Insignia Series Row", "Seated Row"),
        ("Pec Deck", "Life Fitness", "Insignia Series Pectoral Fly/Rear Deltoid", "Rear Delt Fly"),
        ("Cable Station", "Life Fitness", "Dual Adjustable Pulley", "Triceps Pushdown"),
        ("Leg Press", "Life Fitness", "Plate Loaded Linear Leg Press", "Leg Press"),
        ("Leg Extension", "Life Fitness", "Insignia Series Leg Extension", "Leg Extension"),
        ("Seated Leg Curl", "Life Fitness", "Insignia Series Seated Leg Curl", "Seated Leg Curl"),
        ("Calf Raise", "Life Fitness", "Insignia Series Calf Extension", "Calf Raise"),
    ]

    /// Template name → seeded exercise names, in order.
    static let templates: [(name: String, exercises: [String])] = [
        ("Push Day", ["Seated Chest Press", "Incline Chest Press", "Machine Shoulder Press", "Lateral Raise", "Triceps Pushdown"]),
        ("Pull Day", ["Lat Pulldown", "Seated Row", "Rear Delt Fly", "Dumbbell Curl"]),
        ("Leg Day", ["Leg Press", "Leg Extension", "Seated Leg Curl", "Calf Raise"]),
    ]

    /// Finished workouts: days before today, template, minutes, (weight lb, reps) per working set.
    static let sessions: [(daysAgo: Int, template: String, minutes: Int)] = [
        (3, "Pull Day", 77), (1, "Leg Day", 55),
        (7, "Push Day", 62), (9, "Leg Day", 58), (11, "Pull Day", 70), (12, "Push Day", 49),
    ]

    /// Idempotent: a store that already holds a workout is left alone.
    static func seed(in context: ModelContext, now: Date = .now) throws {
        guard try context.fetch(FetchDescriptor<Workout>()).isEmpty else { return }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        func exercise(_ name: String) -> Exercise? { exercises.first { $0.name == name } }

        let gym = Gym(name: gymName, city: "Seoul", defaultUnit: .lb)
        context.insert(gym)

        let models = try context.fetch(FetchDescriptor<EquipmentModel>())
        var machineFor: [String: MachineInstance] = [:]
        for spec in machines + (gymsIsEnabled ? gymMachines : []) {
            let model = models.first { $0.manufacturer == spec.manufacturer && $0.modelName == spec.model }
            let machine = MachineInstance(label: spec.label, gym: gym, model: model)
            context.insert(machine)
            if let exercise = exercise(spec.exercise) {
                machineFor[spec.exercise] = machine
                // The gym remembers the machine, so a template start resolves to it (D1/D6).
                context.insert(GymExerciseMemory(gymID: gym.id, exerciseID: exercise.id, machineID: machine.id))
            }
        }

        var byName: [String: WorkoutTemplate] = [:]
        for (name, names) in templates {
            let template = WorkoutTemplate(name: name)
            context.insert(template)
            for (order, exerciseName) in names.enumerated() {
                guard let exercise = exercise(exerciseName) else { continue }
                let item = TemplateItem(order: order, targetRepsBySet: [10, 8, 8], exercise: exercise)
                item.template = template
                context.insert(item)
            }
            byName[name] = template
        }

        let calendar = Calendar.current
        for (daysAgo, templateName, minutes) in sessions {
            guard let template = byName[templateName],
                  let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            let start = calendar.date(bySettingHour: 18, minute: 10, second: 0, of: day) ?? day
            let workout = Workout(startedAt: start, sourceTemplateID: template.id,
                                  sourceTemplateName: template.name, snapshotGymName: gym.name, gym: gym)
            workout.finishedAt = start.addingTimeInterval(Double(minutes) * 60)
            context.insert(workout)
            if historyIsEnabled { decorate(workout, daysAgo: daysAgo, minutes: minutes) }
            let names = templates.first { $0.name == templateName }?.exercises ?? []
            for (order, name) in names.enumerated() {
                guard let exercise = exercise(name) else { continue }
                let machine = machineFor[name]
                let entry = ExerciseEntry(
                    order: order, workout: workout, exercise: exercise, machine: machine, snapshotCapturedAt: start,
                    snapshotExerciseID: exercise.id, snapshotMachineID: machine?.id, snapshotModelID: machine?.model?.id,
                    snapshotGymID: gym.id, snapshotLoadType: exercise.loadType,
                    snapshotExerciseName: exercise.name, snapshotMachineLabel: machine?.label,
                    snapshotModelName: machine?.model?.displayName, snapshotGymName: gym.name)
                context.insert(entry)
                // History captures: 5 lb more every few days, so newer sessions set new bests.
                let bump = historyIsEnabled ? Double((12 - daysAgo) / 3) * 5 : 0
                let base = 40.0 + Double(order * 15) + bump
                // One exercise logged in kg ("kg + lb" on its row).
                let inKg = historyIsEnabled && daysAgo == 9 && name == "Calf Raise"
                let rows: [(SetType, Double, Int)] = order == 0
                    ? [(.warmup, base * 0.5, 12), (.working, base, 10), (.working, base + 5, 8)]
                    : [(.working, base, 10), (.working, base, 8)]
                for (index, row) in rows.enumerated() {
                    let value = inKg ? (row.1 / 2.2).rounded() : row.1
                    let unit: WeightUnit = inKg ? .kg : .lb
                    let set = SetRecord(
                        order: index, type: row.0, reps: row.2, weightValue: value, weightUnit: unit,
                        normalizedKg: WeightMath.normalizedKg(value: value, unit: unit),
                        completedAt: start.addingTimeInterval(Double(order * 600 + index * 150)))
                    set.entry = entry
                    context.insert(set)
                }
            }
        }
        if gymsIsEnabled { try addGymsExtras(to: gym, machines: machineFor, models: models, now: now, in: context) }
        try context.save()
        try GymSelection.remember(gym, in: context)
        let barBest = ProcessInfo.processInfo.arguments.contains(barBestArgument)
            ? exercise("Bench Press") : nil
        if liveIsEnabled, let bench = barBest {
            try logBench(bench, perSide: "22.5", at: gym, on: now.addingTimeInterval(-5 * 86_400), in: context)
        }
        if liveIsEnabled, let push = byName["Push Day"] {
            try startLive(push, at: gym, now: now, in: context)
            if let bench = barBest, let live = try context.fetch(
                FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt == nil })).first {
                try logBench(bench, perSide: "28.75", into: live, at: gym, on: now.addingTimeInterval(-60), in: context)
            }
        } else if isEnabled && ProcessInfo.processInfo.arguments.contains(emptyLiveArgument) {
            // An empty workout just started at the gym (the "Recent at" state).
            _ = try WorkoutSession(context: context).startWorkout(at: gym, on: now.addingTimeInterval(-40))
            try context.save()
        }
    }

    /// The Gyms captures' extras: a kg override, a machine with no model, a deleted machine, a
    /// second gym with one finished visit, and a deleted gym.
    private static func addGymsExtras(to gym: Gym, machines: [String: MachineInstance], models: [EquipmentModel],
                                      now: Date, in context: ModelContext) throws {
        machines["Calf Raise"]?.defaultUnit = .kg
        context.insert(MachineInstance(label: "Biceps Curl", gym: gym))
        let oldRow = models.first { $0.manufacturer == "Life Fitness" && $0.modelName == "Plate Loaded Row" }
        context.insert(MachineInstance(label: "Old Row", archived: true, gym: gym, model: oldRow))
        let hotel = Gym(name: "Hotel Gym", city: "New York")
        context.insert(hotel)
        let calendar = Calendar.current
        if let day = calendar.date(byAdding: .day, value: -24, to: now) {
            let start = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: day) ?? day
            let visit = Workout(startedAt: start, snapshotGymName: hotel.name, gym: hotel)
            visit.finishedAt = start.addingTimeInterval(40 * 60)
            context.insert(visit)
        }
        context.insert(Gym(name: "Gangnam Fitness", city: "Seoul", defaultUnit: .kg, archived: true))
    }

    /// History captures: the newest workout's sensor data, a note, an edit mark.
    private static func decorate(_ workout: Workout, daysAgo: Int, minutes: Int) {
        switch daysAgo {
        case 1:
            let interval = HeartRateSeriesMath.defaultIntervalSeconds
            let full = HeartRateHistoryFixture.folded(intervalSeconds: interval)
            let count = min(full.mean.count, minutes * 60 / interval)
            let mean = Array(full.mean.prefix(count))
            let present = mean.filter { $0 > 0 }
            workout.heartRateSeries = mean
            workout.heartRateSeriesLow = Array(full.low.prefix(count))
            workout.heartRateSeriesHigh = Array(full.high.prefix(count))
            workout.heartRateSeriesIntervalSeconds = interval
            workout.averageHeartRate = present.isEmpty ? nil : present.reduce(0, +) / present.count
            workout.maxHeartRate = workout.heartRateSeriesHigh.max()
            workout.zoneSeconds = HeartRateHistoryFixture.zoneSeconds(of: mean, intervalSeconds: interval)
            workout.activeEnergyKilocalories = 318
            workout.basalEnergyKilocalories = 92
        case 3:
            workout.notes = "Rows felt strong. Last curl set was a grind."
        case 11:
            workout.historyEditedAt = workout.finishedAt?.addingTimeInterval(86_400)
        default:
            break
        }
    }

    /// One barbell Bench Press set of 10 on a 45 lb bar with `perSide` plates: a finished workout
    /// of its own on `date`, or appended to `workout` (completed at `date`).
    private static func logBench(_ bench: Exercise, perSide: String, into workout: Workout? = nil,
                                 at gym: Gym, on date: Date = .now, in context: ModelContext) throws {
        let session = WorkoutSession(context: context)
        let target = try workout ?? session.startWorkout(at: gym, on: date.addingTimeInterval(-600))
        let entry = try session.addEntry(for: bench, to: target, machine: nil, freeWeightTag: .barbell)
        try session.chooseBar(weight: 45, unit: .lb, for: entry)
        guard let set = WorkoutSession.orderedSets(of: entry).first(where: { $0.completedAt == nil }) else { return }
        set.weightUnit = .lb
        try session.commitPerSide(perSide, for: set)
        try session.commitReps("10", for: set)
        try session.toggleCompletion(of: set, at: date)
        if workout == nil { try session.finish(target, at: date.addingTimeInterval(300)) }
        try context.save()
    }

    /// Push Day, 18 minutes in: the chest press's first two sets logged (the second a new best),
    /// its third carried forward and untouched, and the rest after set 2 running.
    private static func startLive(_ template: WorkoutTemplate, at gym: Gym, now: Date, in context: ModelContext) throws {
        let workout = try WorkoutTemplateService(context: context)
            .start(template, at: gym, on: now.addingTimeInterval(-18 * 60 - 42))
        let session = WorkoutSession(context: context)
        guard let first = WorkoutSession.orderedEntries(of: workout).first else { return }
        let sets = WorkoutSession.orderedSets(of: first)
        let values: [(String, String)] = [("100", "10"), ("110", "8"), ("110", "8")]
        for (index, set) in sets.enumerated() where index < values.count {
            try session.commitPerSide(values[index].0, for: set)
            try session.commitReps(values[index].1, for: set)
            if index < 2 {
                try session.toggleCompletion(of: set)
                if index == 1 { _ = try RestTimerService(context: context).handleCompletionChange(of: set, isCompleted: true) }
            }
        }
        try context.save()
    }
}
