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

    /// The grips this fixture logs under, created as real `ExercisePreset`
    /// rows so the chart reaches them the way the user's own data would.
    static let presetNames = ["Narrow grip", "Wide grip"]

    /// A plausible progression: mostly up, with a down week, because a series
    /// that only rises would hide a chart that renders decline wrongly.
    /// Logged in LB so the display-unit conversion is exercised too.
    ///
    /// WHY THERE ARE THREE VARIATIONS HERE, and why the plain one must stay the
    /// longest: D36 forbids pooling variations into one line, and the variation
    /// PICKER is the only visible surface of that rule — with a single
    /// variation it does not render at all, so nothing could screenshot or test
    /// it. The nil rows below are deliberately the richest series, because
    /// `defaultVariation` opens the chart on whichever has the most days: that
    /// keeps the drawn series identical to what it was before the grips were
    /// added, which is what `ProgressChartTooltipUITests` drags across.
    ///
    /// A grip is lighter than the plain press on purpose. Pooled, the three
    /// series would look like violent week-to-week swings — which is precisely
    /// the false record D36 exists to prevent.
    static let script: [(daysAgo: Int, weightLb: Double, reps: Int, preset: String?)] = [
        (28, 95, 8, nil), (25, 100, 8, nil), (21, 105, 8, nil),
        (18, 105, 6, nil), (14, 110, 8, nil), (11, 110, 10, nil),
        (7, 115, 8, nil), (4, 112.5, 8, nil), (1, 120, 8, nil),
        (26, 85, 10, "Narrow grip"), (19, 90, 10, "Narrow grip"), (12, 95, 10, "Narrow grip"),
        (23, 75, 12, "Wide grip"), (16, 80, 12, "Wide grip"),
    ]

    /// Seeds the history. Idempotent by exercise: a second call does nothing,
    /// so a relaunch inside one test run cannot double the series.
    static func seed(in context: ModelContext, now: Date = .now) throws {
        let existing = try context.fetch(FetchDescriptor<Workout>())
        guard existing.isEmpty else { return }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        guard let exercise = exercises.first(where: { $0.name == exerciseName })
        else { return }

        // Real preset rows, so the exercise looks the same to every screen as
        // it would if the user had made them by hand.
        var presets: [String: ExercisePreset] = [:]
        for (index, name) in presetNames.enumerated() {
            let preset = ExercisePreset(name: name, order: index, exercise: exercise)
            context.insert(preset)
            presets[name] = preset
        }

        for (daysAgo, weightLb, reps, presetName) in script {
            let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            let workout = Workout(startedAt: date)
            workout.finishedAt = date.addingTimeInterval(45 * 60)
            context.insert(workout)

            let preset = presetName.flatMap { presets[$0] }
            let entry = ExerciseEntry(
                order: 0,
                workout: workout,
                exercise: exercise,
                preset: preset,
                snapshotCapturedAt: date,
                snapshotExerciseID: exercise.id,
                snapshotLoadType: exercise.loadType,
                snapshotExerciseName: exercise.name,
                // D23: the chart names a variation from the SNAPSHOT, so a
                // fixture that set only the relationship would leave the picker
                // rendering "Variation" for every row.
                snapshotPresetID: preset?.id,
                snapshotPresetName: preset?.name)
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
