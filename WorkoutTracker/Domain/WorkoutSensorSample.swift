import Foundation
import SwiftData

/// An in-flight heartbeat checkpoint. Append rows rather than rewriting a growing
/// blob at every tick. The rows are removed once the workout's summary is frozen.
@Model
final class WorkoutSensorSample {
    var id: UUID = UUID()
    var bpm: Int = 0
    var date: Date = Date()
    var sourceRawValue: String = HeartRateSource.otherMonitor.rawValue
    var workout: Workout?

    init(sample: HeartRateSample, workout: Workout) {
        id = sample.id; bpm = sample.bpm; date = sample.date
        sourceRawValue = sample.source.rawValue
        self.workout = workout
    }
    var sample: HeartRateSample {
        HeartRateSample(id: id, bpm: bpm, date: date,
                        source: HeartRateSource(rawValue: sourceRawValue) ?? .otherMonitor)
    }
}

extension Workout {
    var checkpointSamples: [HeartRateSample] {
        (sensorSampleRows ?? []).filter { !$0.isDeleted }.map(\.sample)
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
    }
    func clearSensorCheckpoint(in context: ModelContext) {
        for row in sensorSampleRows ?? [] where !row.isDeleted { context.delete(row) }
        sensorActiveEnergyCheckpoint = nil
        sensorBasalEnergyCheckpoint = nil
        sensorMaxHeartRateBpm = nil
        sensorMaxHeartRateEstimated = nil
    }
    /// This path also runs for strays after relaunch, when no live coordinator
    /// exists. Otherwise their saved samples would never reach History's summary.
    func captureSensorCheckpoint(at end: Date, in context: ModelContext) {
        let raw = checkpointSamples.filter { $0.date >= startedAt && $0.date <= end }
        if !raw.isEmpty || sensorActiveEnergyCheckpoint != nil || sensorBasalEnergyCheckpoint != nil {
            let dominant = WorkoutVitalsMath.dominantSource(among: raw)
            let selected = dominant.map { WorkoutVitalsMath.summarySamples(from: raw, dominant: $0) } ?? []
            let maximum = sensorMaxHeartRateBpm.map { MaxHeartRate(bpm: $0, isEstimated: sensorMaxHeartRateEstimated ?? false) }
            WorkoutSummaryBuilder.capture(
                vitals: WorkoutVitalsMath.vitals(from: selected, zoningAgainst: maximum),
                activeEnergyKilocalories: sensorActiveEnergyCheckpoint ?? activeEnergyKilocalories,
                basalEnergyKilocalories: sensorBasalEnergyCheckpoint ?? basalEnergyKilocalories,
                samples: selected, zonesEstimated: maximum?.isEstimated ?? false, onto: self, now: end)
        }
        clearSensorCheckpoint(in: context)
    }
}
