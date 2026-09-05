import Foundation
import SwiftData

// ONE finished hour-long workout with a heart-rate series, seeded under a
// launch argument — finish-graph ticket 01.
//
// WHY THIS EXISTS, in the same spirit as `ChartFixture`: the scripted sensor
// (`-uiTestHeartRate`) yields two 15 s buckets in a 20 s test, and the graph's
// whole problem was DENSITY — 268 buckets of a real 67-minute session drawn
// one per bucket fused into a block. No UI test can wait an hour, so the only
// way to see the chart at the density the user sees it is to manufacture the
// series. This is that, and it is what the History screenshot compares
// against the Apple Fitness reference.
//
// Fixture data must never reach a real store. The argument does NOT itself
// select the throwaway container — only `-uiTestReset` does — so enablement
// requires BOTH (codex-review 01, high: the flag alone would have seeded a
// fake workout into the user's own history on a phone with none).

enum HeartRateHistoryFixture {

    static let launchArgument = "-uiTestHeartRateHistory"

    static var isEnabled: Bool {
        isEnabled(arguments: ProcessInfo.processInfo.arguments)
    }

    /// True only when the fixture is asked for AND the store is the wiped
    /// UI-test one (`WorkoutTrackerStore.fixtureIsEnabled`). Pure, so the
    /// guard is testable without relaunching.
    static func isEnabled(arguments: [String]) -> Bool {
        WorkoutTrackerStore.fixtureIsEnabled(launchArgument, in: arguments)
    }

    static let durationMinutes = 60
    static let exerciseName = "Seated Chest Press"

    /// A plausible strength session at the default 15 s bucket: ~45 s of
    /// effort climbing to the high 140s, ~90 s of rest falling to the low
    /// 110s, a few longer rests, and one 75 s sensor outage (the earbuds
    /// case) drawn as a gap. Deterministic — the screenshot must not change
    /// between runs — hence the hand-rolled generator rather than `random`.
    static func folded(intervalSeconds: Int = HeartRateSeriesMath.defaultIntervalSeconds) -> HeartRateSeriesMath.Folded {
        let count = durationMinutes * 60 / intervalSeconds
        var mean: [Int] = [], low: [Int] = [], high: [Int] = []
        var seed: UInt32 = 0x9E37_79B9
        func next() -> Int {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Int(seed >> 24)  // 0…255
        }
        var bpm = 96.0
        var phaseLeft = 3  // buckets left in the current phase
        var effort = false
        for index in 0..<count {
            if phaseLeft == 0 {
                effort.toggle()
                phaseLeft = effort ? 3 + next() % 2 : 5 + next() % 4
            }
            phaseLeft -= 1
            let target = effort ? 138.0 + Double(next() % 14) : 106.0 + Double(next() % 10)
            bpm += (target - bpm) * 0.55
            // The outage: buckets 128–132 (32:00–33:15) carry nothing.
            if (128...132).contains(index) {
                mean.append(0); low.append(0); high.append(0)
                continue
            }
            let spread = 2 + next() % 6
            let rounded = Int(bpm.rounded())
            mean.append(rounded)
            low.append(rounded - spread / 2)
            high.append(rounded + (spread - spread / 2))
        }
        return HeartRateSeriesMath.Folded(mean: mean, low: low, high: high)
    }

    /// Seeds the workout two days ago. Idempotent: a store that already has a
    /// workout is left alone, so a relaunch cannot double it.
    static func seed(in context: ModelContext, now: Date = .now) throws {
        guard try context.fetch(FetchDescriptor<Workout>()).isEmpty else { return }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        guard let exercise = exercises.first(where: { $0.name == exerciseName }) else { return }

        let series = folded()
        let present = series.mean.filter { $0 > 0 }
        let started = Calendar.current.date(bySettingHour: 18, minute: 29, second: 0,
                                            of: now.addingTimeInterval(-2 * 86_400)) ?? now
        let workout = Workout(
            startedAt: started,
            finishedAt: started.addingTimeInterval(Double(durationMinutes * 60)),
            averageHeartRate: present.isEmpty ? nil : present.reduce(0, +) / present.count,
            maxHeartRate: series.high.max(),
            activeEnergyKilocalories: 282,
            zoneSeconds: [],
            heartRateSeries: series.mean,
            heartRateSeriesIntervalSeconds: HeartRateSeriesMath.defaultIntervalSeconds,
            heartRateSeriesLow: series.low,
            heartRateSeriesHigh: series.high,
            basalEnergyKilocalories: 85)
        context.insert(workout)

        let entry = ExerciseEntry(
            order: 0, workout: workout, exercise: exercise,
            snapshotCapturedAt: started, snapshotExerciseID: exercise.id,
            snapshotLoadType: exercise.loadType, snapshotExerciseName: exercise.name)
        context.insert(entry)
        for (index, reps) in [10, 8, 8].enumerated() {
            let set = SetRecord(order: index, type: .working, entry: entry)
            set.reps = reps
            set.weightValue = 60
            set.weightUnit = .kg
            set.normalizedKg = 60
            set.completedAt = started.addingTimeInterval(Double(5 * 60 + index * 150))
            context.insert(set)
        }
        try context.save()
    }
}
