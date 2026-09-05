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
// The data is tagged as fixture data by being seeded only under the argument
// AND `-uiTestReset` (see `isEnabled`): only the latter selects the throwaway
// UI-test container, so the pair is what keeps it out of a real store.

enum ChartFixture {

    static let launchArgument = "-uiTestChartHistory"

    static var isEnabled: Bool {
        isEnabled(arguments: ProcessInfo.processInfo.arguments)
    }

    /// `WorkoutTrackerStore.fixtureIsEnabled`: the argument alone never
    /// selected the throwaway store, so without `-uiTestReset` this would have
    /// seeded four weeks of fake history into a real one (codex-review 01 of
    /// the finish graph). Requires both.
    static func isEnabled(arguments: [String]) -> Bool {
        WorkoutTrackerStore.fixtureIsEnabled(launchArgument, in: arguments)
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
    ///
    /// The last two rows are DUMBBELL sessions with no preset (milestone 9,
    /// ticket 01): the free-weight tag is a variation axis of its own, and
    /// without a tagged row the picker could never show one.
    static let script: [(daysAgo: Int, weightLb: Double, reps: Int, preset: String?, tag: EquipmentTag?)] = [
        (28, 95, 8, nil, nil), (25, 100, 8, nil, nil), (21, 105, 8, nil, nil),
        (18, 105, 6, nil, nil), (14, 110, 8, nil, nil), (11, 110, 10, nil, nil),
        (7, 115, 8, nil, nil), (4, 112.5, 8, nil, nil), (1, 120, 8, nil, nil),
        (26, 85, 10, "Narrow grip", nil), (19, 90, 10, "Narrow grip", nil), (12, 95, 10, "Narrow grip", nil),
        (23, 75, 12, "Wide grip", nil), (16, 80, 12, "Wide grip", nil),
        (24, 40, 10, nil, .dumbbell), (10, 45, 10, nil, .dumbbell),
    ]

    /// One BARBELL session two days ago holding only a warmup. Records exclude
    /// warmups, so this variation has history in the list and nothing eligible
    /// to chart — the sparse case codex-review 01 found could strand the user
    /// in an empty state with no picker. From History it must open on Barbell,
    /// say so, and still offer the other variations.
    static let warmupOnlySession: (daysAgo: Int, weightLb: Double, reps: Int, tag: EquipmentTag) =
        (2, 45, 5, .barbell)

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

        let rows = script.map { ($0.daysAgo, $0.weightLb, $0.reps, $0.preset, $0.tag, SetType.working) }
            + [(warmupOnlySession.daysAgo, warmupOnlySession.weightLb, warmupOnlySession.reps,
                nil, warmupOnlySession.tag, SetType.warmup)]
        for (daysAgo, weightLb, reps, presetName, tag, setType) in rows {
            let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            let workout = Workout(startedAt: date)
            workout.finishedAt = date.addingTimeInterval(45 * 60)
            context.insert(workout)

            let preset = presetName.flatMap { presets[$0] }
            let entry = ExerciseEntry(
                order: 0,
                freeWeightTag: tag,
                workout: workout,
                exercise: exercise,
                preset: preset,
                snapshotCapturedAt: date,
                snapshotExerciseID: exercise.id,
                snapshotLoadType: exercise.loadType,
                snapshotFreeWeightTag: tag,
                snapshotExerciseName: exercise.name,
                // D23: the chart names a variation from the SNAPSHOT, so a
                // fixture that set only the relationship would leave the picker
                // rendering "Variation" for every row.
                snapshotPresetID: preset?.id,
                snapshotPresetName: preset?.name)
            context.insert(entry)

            let set = SetRecord(order: 0, type: setType, entry: entry)
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
