import Foundation
import SwiftData

// A few weeks of history for one exercise, seeded under a launch argument.
//
// WHY THIS EXISTS, in the same spirit as `-uiTestScanFixture` and
// `-uiTestHeartRate`: the simulator has no camera and no heartbeat, and it also
// has NO PAST. A progress chart needs sessions on different days, and a UI test
// can only ever log workouts today — which collapse into a single point, the
// one state that deliberately refuses to draw a line.
//
// So the chart with a real series could not be seen by any test, or screenshot
// for the user, without a way to manufacture a history. This is that.
//
// The data is tagged as fixture data by being seeded only under the argument;
// it can never reach a real store, because the argument also selects the
// throwaway UI-test container.

enum ChartFixture {

    static let launchArgument = "-uiTestChartHistory"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// The exercise the fixture logs against — a seeded catalog row, so the
    /// chart is reached the same way the user reaches it.
    static let exerciseName = "Seated Chest Press"

    /// A plausible progression: mostly up, with a down week, because a series
    /// that only rises would hide a chart that renders decline wrongly.
    /// Logged in LB so the display-unit conversion is exercised too.
    static let script: [(daysAgo: Int, weightLb: Double, reps: Int)] = [
        (28, 95, 8), (25, 100, 8), (21, 105, 8),
        (18, 105, 6), (14, 110, 8), (11, 110, 10),
        (7, 115, 8), (4, 112.5, 8), (1, 120, 8),
    ]

    /// Seeds the history. Idempotent by exercise: a second call does nothing,
    /// so a relaunch inside one test run cannot double the series.
    static func seed(in context: ModelContext, now: Date = .now) throws {
        let existing = try context.fetch(FetchDescriptor<Workout>())
        guard existing.isEmpty else { return }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        guard let exercise = exercises.first(where: { $0.name == exerciseName })
        else { return }

        for (daysAgo, weightLb, reps) in script {
            let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            let workout = Workout(startedAt: date)
            workout.finishedAt = date.addingTimeInterval(45 * 60)
            context.insert(workout)

            let entry = ExerciseEntry(
                order: 0,
                workout: workout,
                exercise: exercise,
                snapshotCapturedAt: date,
                snapshotExerciseID: exercise.id,
                snapshotLoadType: exercise.loadType,
                snapshotExerciseName: exercise.name)
            context.insert(entry)

            let set = SetRecord(order: 0, type: .working, entry: entry)
            set.reps = reps
            set.weightValue = weightLb
            set.weightUnit = .lb
            set.normalizedKg = WeightMath.normalizedKg(value: weightLb, unit: .lb)
            set.completedAt = date.addingTimeInterval(10 * 60)
            context.insert(set)
        }
        try context.save()
    }
}
