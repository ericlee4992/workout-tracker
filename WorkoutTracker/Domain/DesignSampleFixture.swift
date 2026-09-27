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
    static var liveIsEnabled: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains(liveArgument)
    }

    /// Machines at the gym: label, catalog model (manufacturer, model name), the exercise it serves.
    static let machines: [(label: String, manufacturer: String, model: String, exercise: String)] = [
        ("Chest Press 2", "Life Fitness", "Insignia Series Chest Press", "Seated Chest Press"),
        ("Incline Press", "Hammer Strength", "Iso-Lateral Incline Press", "Incline Chest Press"),
    ]

    static let gymName = "Iron Temple"

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
        for spec in machines {
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
                let base = 40.0 + Double(order * 15)
                let rows: [(SetType, Double, Int)] = order == 0
                    ? [(.warmup, base * 0.5, 12), (.working, base, 10), (.working, base + 5, 8)]
                    : [(.working, base, 10), (.working, base, 8)]
                for (index, row) in rows.enumerated() {
                    let set = SetRecord(
                        order: index, type: row.0, reps: row.2, weightValue: row.1, weightUnit: .lb,
                        normalizedKg: WeightMath.normalizedKg(value: row.1, unit: .lb),
                        completedAt: start.addingTimeInterval(Double(order * 600 + index * 150)))
                    set.entry = entry
                    context.insert(set)
                }
            }
        }
        try context.save()
        try GymSelection.remember(gym, in: context)
        if liveIsEnabled, let push = byName["Push Day"] {
            try startLive(push, at: gym, now: now, in: context)
        }
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
