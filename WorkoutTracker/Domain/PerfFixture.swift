import Foundation
import SwiftData

// A heavy, lived-in store for measuring the live workout's responsiveness (performance ticket P1, "the whole app
// lags during a workout"). The design sample has six finished workouts and a two-exercise live one, which is far
// lighter than a store after months of logging, so a slowdown that grows with history or with the workout's length
// would not show there. Requires `-uiTestReset` too (`WorkoutTrackerStore.fixtureIsEnabled`), so it can never seed a
// real store.
//
// `-uiTestPerfStore`: `historyCount` finished workouts, one every other day, each with six exercises of four sets,
// and a live workout of eight exercises with four sets each (the first half logged, a rest counting down).

enum PerfFixture {
    static let launchArgument = "-uiTestPerfStore"

    static var isEnabled: Bool {
        WorkoutTrackerStore.fixtureIsEnabled(launchArgument)
    }

    /// With `-uiTestPerfNoHistory` too: the same live workout over an empty history (the control run).
    static let noHistoryArgument = "-uiTestPerfNoHistory"
    static var historyCount: Int {
        ProcessInfo.processInfo.arguments.contains(noHistoryArgument) ? 0 : 150
    }
    static let gymName = "Perf Gym"
    /// With `-uiTestPerfNewGym` too: the live workout runs at a second gym with no history, where Add Exercise's
    /// "Recent at" lookup finds nothing and walks the whole history (Codex review P1, the P3).
    static let newGymArgument = "-uiTestPerfNewGym"

    /// Catalog exercises the history rotates through; the live workout uses the first eight.
    static let exerciseNames = [
        "Seated Chest Press", "Incline Chest Press", "Machine Shoulder Press", "Lateral Raise", "Triceps Pushdown",
        "Lat Pulldown", "Seated Row", "Rear Delt Fly", "Dumbbell Curl", "Leg Press", "Leg Extension",
        "Seated Leg Curl", "Calf Raise", "Bench Press",
    ]

    /// Idempotent: a store that already holds a workout is left alone.
    static func seed(in context: ModelContext, now: Date = .now) throws {
        guard try context.fetch(FetchDescriptor<Workout>()).isEmpty else { return }
        let catalog = try context.fetch(FetchDescriptor<Exercise>())
        let exercises = exerciseNames.compactMap { name in catalog.first { $0.name == name } }
        guard exercises.count >= 8 else { return }

        let gym = Gym(name: gymName, city: "Seoul", defaultUnit: .lb)
        context.insert(gym)

        let calendar = Calendar.current
        for index in 0..<historyCount {
            let daysAgo = 1 + index * 2
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
            let workout = Workout(startedAt: start, snapshotGymName: gym.name, gym: gym)
            workout.finishedAt = start.addingTimeInterval(70 * 60)
            context.insert(workout)
            for order in 0..<6 {
                let exercise = exercises[(index * 3 + order) % exercises.count]
                let entry = ExerciseEntry(
                    order: order, workout: workout, exercise: exercise, machine: nil, snapshotCapturedAt: start,
                    snapshotExerciseID: exercise.id, snapshotMachineID: nil, snapshotModelID: nil,
                    snapshotGymID: gym.id, snapshotLoadType: exercise.loadType,
                    snapshotExerciseName: exercise.name, snapshotMachineLabel: nil,
                    snapshotModelName: nil, snapshotGymName: gym.name)
                context.insert(entry)
                // Older sessions lighter, so records are spread through the history.
                let base = 40.0 + Double(order * 10) + Double(historyCount - index) * 0.5
                for setIndex in 0..<4 {
                    let type: SetType = setIndex == 0 ? .warmup : .working
                    let value = setIndex == 0 ? (base * 0.5).rounded() : base + Double(setIndex) * 5
                    let set = SetRecord(
                        order: setIndex, type: type, reps: 12 - setIndex, weightValue: value, weightUnit: .lb,
                        normalizedKg: WeightMath.normalizedKg(value: value, unit: .lb),
                        completedAt: start.addingTimeInterval(Double(order * 600 + setIndex * 150)))
                    set.entry = entry
                    context.insert(set)
                }
            }
        }
        try context.save()
        try GymSelection.remember(gym, in: context)

        // The live workout: eight exercises, four sets each, the first four exercises logged.
        let template = WorkoutTemplate(name: "Perf Day")
        context.insert(template)
        for (order, exercise) in exercises.prefix(8).enumerated() {
            let item = TemplateItem(order: order, targetRepsBySet: [10, 10, 8, 8], exercise: exercise)
            item.template = template
            context.insert(item)
        }
        try context.save()
        var liveGym = gym
        if ProcessInfo.processInfo.arguments.contains(newGymArgument) {
            liveGym = Gym(name: "Perf Gym 2", city: "Busan", defaultUnit: .lb)
            context.insert(liveGym)
            try context.save()
            try GymSelection.remember(liveGym, in: context)
        }
        let workout = try WorkoutTemplateService(context: context)
            .start(template, at: liveGym, on: now.addingTimeInterval(-45 * 60))
        let session = WorkoutSession(context: context)
        var lastCompleted: SetRecord?
        for (entryIndex, entry) in WorkoutSession.orderedEntries(of: workout).enumerated() {
            for set in WorkoutSession.orderedSets(of: entry) {
                try session.commitPerSide("\(60 + entryIndex * 10)", for: set)
                try session.commitReps("10", for: set)
                if entryIndex < 4 {
                    try session.toggleCompletion(of: set)
                    lastCompleted = set
                }
            }
        }
        if let lastCompleted {
            _ = try RestTimerService(context: context).handleCompletionChange(of: lastCompleted, isCompleted: true)
        }
        try context.save()
    }
}
