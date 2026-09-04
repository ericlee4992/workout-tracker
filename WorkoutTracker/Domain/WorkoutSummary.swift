import Foundation
import SwiftData

// Milestone 7, ticket 07 — what the finish screen shows (D44).
//
// Apple's summary cannot say what you lifted; this app's could not say what
// your heart did. The user asked for both on one screen, so this assembles
// them: HealthKit's numbers beside the app's own.
//
// Two rules the type enforces rather than hopes for:
//
// 1. Heart-rate values are OPTIONAL and omitted when absent. A workout logged
//    without a sensor renders no heart-rate rows at all. `0 BPM` is not a
//    missing value, it is a false one — the same distinction D30 draws for
//    draft sets.
// 2. Volume comes from `RecordsMath`, never recomputed here. Two numbers for
//    one fact is how they drift, and the one on this screen would be the one
//    the user believes.

struct WorkoutSummary: Equatable, Sendable {
    var date: Date
    var gymName: String?
    var duration: TimeInterval
    var totalVolumeKg: Double
    var completedSets: Int
    var exercises: [ExerciseLine]

    // nil throughout = no session ran.
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var activeEnergyKilocalories: Double?
    var zoneSeconds: [Int]
    /// D45: whether `zoneSeconds` was computed against an estimated maximum.
    /// nil when there are no zones at all.
    var zonesFromEstimatedMax: Bool?
    /// Milestone 9, ticket 05. nil basal = total not shown; empty series = no chart.
    var basalEnergyKilocalories: Double? = nil
    var heartRateSeries: [Int] = []
    var heartRateSeriesIntervalSeconds: Int? = nil

    var hasHeartRate: Bool {
        averageHeartRate != nil || maxHeartRate != nil || activeEnergyKilocalories != nil
    }

    /// Active + basal, only when both exist (D9/D25: no invented halves).
    var totalEnergyKilocalories: Double? {
        HeartRateSeriesMath.totalEnergyKilocalories(active: activeEnergyKilocalories, basal: basalEnergyKilocalories)
    }

    var hasHeartRateSeries: Bool {
        heartRateSeriesIntervalSeconds != nil && heartRateSeries.contains { $0 > 0 }
    }

    /// One exercise as the summary lists it: what it was, on what, how much.
    struct ExerciseLine: Equatable, Sendable, Identifiable {
        var id: UUID
        var name: String
        /// Equipment as the D23 snapshot recorded it — the machine label, the
        /// free-weight tag, or nothing.
        var equipment: String?
        /// The variation performed (D36), when one was.
        var preset: String?
        var setCount: Int
        /// The heaviest completed set, rendered as entered (D25). nil for a
        /// bodyweight exercise, where "best" means reps and is carried in
        /// `bestReps` instead.
        var bestSet: String?
    }
}

enum WorkoutSummaryBuilder {

    /// Builds the summary for a finished workout, reading the persisted
    /// heart-rate fields rather than any live source.
    static func summary(for workout: Workout, locale: Locale = .current) -> WorkoutSummary {
        let entries = WorkoutSession.orderedEntries(of: workout)
        let end = workout.finishedAt ?? .now

        var lines: [WorkoutSummary.ExerciseLine] = []
        var inputs: [RecordSetInput] = []
        var completedSets = 0

        for entry in entries {
            let completed = WorkoutSession.orderedSets(of: entry)
                .filter { $0.completedAt != nil }
            guard !completed.isEmpty else { continue }
            completedSets += completed.count

            for set in completed {
                inputs.append(RecordSetInput(
                    loadType: entry.snapshotLoadType,
                    exerciseID: entry.snapshotExerciseID,
                    gymID: entry.snapshotGymID,
                    machineID: entry.snapshotMachineID,
                    modelID: entry.snapshotModelID,
                    freeWeightTag: entry.snapshotFreeWeightTag,
                    presetID: entry.snapshotPresetID,
                    setType: set.type,
                    reps: set.reps,
                    weightValue: set.weightValue,
                    weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg,
                    completedAt: set.completedAt))
            }

            lines.append(WorkoutSummary.ExerciseLine(
                id: entry.id,
                name: entry.snapshotExerciseName,
                equipment: entry.snapshotMachineLabel
                    ?? entry.snapshotFreeWeightTag?.label,
                preset: entry.snapshotPresetName,
                setCount: completed.count,
                bestSet: bestSetLabel(among: completed, locale: locale)))
        }

        return WorkoutSummary(
            date: workout.startedAt,
            gymName: workout.snapshotGymName ?? workout.gym?.name,
            duration: end.timeIntervalSince(workout.startedAt),
            totalVolumeKg: RecordsMath.totalVolumeKg(among: inputs),
            completedSets: completedSets,
            exercises: lines,
            averageHeartRate: workout.averageHeartRate,
            maxHeartRate: workout.maxHeartRate,
            activeEnergyKilocalories: workout.activeEnergyKilocalories,
            zoneSeconds: workout.zoneSeconds,
            zonesFromEstimatedMax: workout.zonesFromEstimatedMax,
            basalEnergyKilocalories: workout.basalEnergyKilocalories,
            heartRateSeries: workout.heartRateSeries,
            heartRateSeriesIntervalSeconds: workout.heartRateSeriesIntervalSeconds)
    }

    /// The heaviest completed set, as entered. Warmups are excluded exactly as
    /// they are from records (D12/D26) — a summary whose "best" was a warmup
    /// would disagree with every PR table in the app.
    private static func bestSetLabel(
        among sets: [SetRecord], locale: Locale
    ) -> String? {
        let eligible = sets.filter { $0.type.countsTowardRecords }
        let pool = eligible.isEmpty ? sets : eligible
        guard let best = pool.max(by: {
            ($0.normalizedKg ?? -1, $0.reps ?? 0) < ($1.normalizedKg ?? -1, $1.reps ?? 0)
        }) else { return nil }
        let reps = best.reps.map(String.init) ?? "—"
        guard let weight = best.weightValue else { return "\(reps) reps" }
        let number = WeightMath.displayNumber(weight, locale: locale)
        let bar = best.barWeightValue.map { barWeight in
            // D39: a bar-mode set says which bar, because the total alone does
            // not tell you what you actually loaded.
            " (\(WeightMath.displayNumber(barWeight, locale: locale)) \(best.weightUnit.rawValue) bar)"
        } ?? ""
        return "\(number) \(best.weightUnit.rawValue) × \(reps)\(bar)"
    }

    /// Captures the heart-rate summary onto the workout at finish. Called once,
    /// with whatever the monitor collected; nothing is written when no samples
    /// arrived, so "no sensor" stays distinguishable from "zero".
    static func capture(
        vitals: WorkoutVitals,
        activeEnergyKilocalories: Double?,
        basalEnergyKilocalories: Double? = nil,
        samples: [HeartRateSample] = [],
        zonesEstimated: Bool = false,
        onto workout: Workout,
        now: Date = .now
    ) {
        // Calories are a separate fact from heart rate: the system accumulates
        // active energy whether or not a single bpm arrived, and dropping it
        // because no sample came showed calories all workout then omitted them
        // from the summary (codex-review 1.2).
        workout.activeEnergyKilocalories = activeEnergyKilocalories
        workout.basalEnergyKilocalories = basalEnergyKilocalories
        // Milestone 9, ticket 05: the series, folded here — the one moment the
        // samples exist. `finishedAt` is not set yet on this path, so the end
        // is `now`. Empty samples leave the series empty and the interval nil.
        let series = HeartRateSeriesMath.series(from: samples, start: workout.startedAt, end: now)
        if series.contains(where: { $0 > 0 }) {
            workout.heartRateSeries = series
            workout.heartRateSeriesIntervalSeconds = HeartRateSeriesMath.defaultIntervalSeconds
        }
        guard !vitals.isEmpty else { return }
        workout.averageHeartRate = vitals.averageBpm
        workout.maxHeartRate = vitals.maxBpm
        let zones = HeartRateZone.allCases.map { vitals.secondsInZone[$0.rawValue] ?? 0 }
        workout.zoneSeconds = zones.contains(where: { $0 > 0 }) ? zones : []
        // D45: zones computed from 220−age are an estimate, and the summary has
        // to say so — otherwise a workout zoned from a formula is
        // indistinguishable from one zoned against a measured maximum
        // (codex-review 1.1, high).
        workout.zonesFromEstimatedMax = workout.zoneSeconds.isEmpty ? nil : zonesEstimated
    }
}
