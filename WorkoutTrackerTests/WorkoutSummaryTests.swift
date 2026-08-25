import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Milestone 7, ticket 07 — the finish summary (D44).
//
// The claim this screen makes is "here is what happened". The tests that matter
// are therefore the ones about what it must NOT say: no heart-rate rows when no
// sensor ran, no warmup masquerading as a best set, and a volume that agrees
// with the app's own record maths to the last decimal.

struct WorkoutSummaryTests {

    private let t0 = Date(timeIntervalSince1970: 4_000_000)

    private struct Rig {
        var context: ModelContext
        var session: WorkoutSession
        var exercise: Exercise
        var gym: Gym
        var machine: MachineInstance
    }

    private func makeRig() throws -> Rig {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let exercise = Exercise(name: "Bench Press")
        let model = EquipmentModel(
            manufacturer: "Rogue", modelName: "Rack", exerciseIDs: [exercise.id])
        let gym = Gym(name: "Gold's", defaultUnit: .kg)
        let machine = MachineInstance(label: "Rack 1", gym: gym, model: model)
        for object in [exercise, model, gym, machine] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()
        return Rig(
            context: context, session: WorkoutSession(context: context),
            exercise: exercise, gym: gym, machine: machine)
    }

    @discardableResult
    private func logWorkout(
        _ rig: Rig, sets: [(weight: String, reps: String, type: SetType)]
    ) throws -> Workout {
        let workout = try rig.session.startWorkout(at: rig.gym, on: t0)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        for (index, plan) in sets.enumerated() {
            let set = index == 0
                ? try #require(WorkoutSession.orderedSets(of: entry).first)
                : try rig.session.addSet(to: entry)
            try rig.session.setType(plan.type, of: set)
            try rig.session.commitWeight(plan.weight, for: set)
            try rig.session.commitReps(plan.reps, for: set)
            try rig.session.toggleCompletion(
                of: set, at: t0.addingTimeInterval(Double(index + 1) * 60))
        }
        return workout
    }

    // MARK: What only this app knows

    @Test func theSummaryListsEveryExercisePerformed() throws {
        let rig = try makeRig()
        let workout = try logWorkout(rig, sets: [
            ("60", "10", .working), ("70", "8", .working),
        ])
        try rig.session.finish(workout, at: t0.addingTimeInterval(600))

        let summary = WorkoutSummaryBuilder.summary(for: workout)
        #expect(summary.exercises.count == 1)
        let line = try #require(summary.exercises.first)
        #expect(line.name == "Bench Press")
        #expect(line.equipment == "Rack 1")
        #expect(line.setCount == 2)
        #expect(line.bestSet == "70 kg × 8")
        #expect(summary.completedSets == 2)
        #expect(summary.duration == 600)
        #expect(summary.gymName == "Gold's")
    }

    /// Two numbers for one fact is how they drift, and this is the one the user
    /// would believe.
    @Test func volumeAgreesWithRecordsMath() throws {
        let rig = try makeRig()
        let workout = try logWorkout(rig, sets: [
            ("60", "10", .working), ("70", "8", .working), ("20", "12", .warmup),
        ])
        try rig.session.finish(workout, at: t0.addingTimeInterval(600))

        let summary = WorkoutSummaryBuilder.summary(for: workout)
        // 60×10 + 70×8 = 1160; the warmup is excluded (D21).
        #expect(abs(summary.totalVolumeKg - 1160) < 1e-9)
    }

    /// A "best set" that was a warmup would disagree with every PR table in the
    /// app (D12/D26).
    @Test func theBestSetIgnoresWarmups() throws {
        let rig = try makeRig()
        let workout = try logWorkout(rig, sets: [
            ("100", "3", .warmup), ("60", "10", .working),
        ])
        try rig.session.finish(workout, at: t0.addingTimeInterval(300))

        let line = try #require(WorkoutSummaryBuilder.summary(for: workout).exercises.first)
        #expect(line.bestSet == "60 kg × 10", "the 100 kg warmup is not a best set")
    }

    /// D39: a bar-mode set says which bar, because the total alone does not
    /// tell you what you loaded.
    @Test func aBarModeBestSetNamesItsBar() throws {
        let rig = try makeRig()
        let workout = try rig.session.startWorkout(at: rig.gym, on: t0)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .barbell)
        try rig.session.chooseBar(
            BarPreset(id: "olympic-45lb", name: "Olympic barbell", value: 45, unit: .lb),
            for: entry)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try rig.session.commitPerSide("45", for: set)
        try rig.session.commitReps("5", for: set)
        try rig.session.toggleCompletion(of: set, at: t0.addingTimeInterval(60))
        try rig.session.finish(workout, at: t0.addingTimeInterval(300))

        let line = try #require(WorkoutSummaryBuilder.summary(for: workout).exercises.first)
        #expect(line.bestSet == "135 lb × 5 (45 lb bar)")
        #expect(line.equipment == "Barbell")
    }

    // MARK: What it must not say (D44)

    @Test func aWorkoutWithNoSensorHasNoHeartRateRows() throws {
        let rig = try makeRig()
        let workout = try logWorkout(rig, sets: [("60", "10", .working)])
        try rig.session.finish(workout, at: t0.addingTimeInterval(300))

        let summary = WorkoutSummaryBuilder.summary(for: workout)
        #expect(!summary.hasHeartRate)
        #expect(summary.averageHeartRate == nil, "0 BPM would be a false value")
        #expect(summary.maxHeartRate == nil)
        #expect(summary.activeEnergyKilocalories == nil)
        #expect(summary.zoneSeconds.isEmpty)
    }

    @Test func capturingEmptyVitalsWritesNothing() throws {
        let rig = try makeRig()
        let workout = try logWorkout(rig, sets: [("60", "10", .working)])
        WorkoutSummaryBuilder.capture(
            vitals: .empty, activeEnergyKilocalories: nil, onto: workout)
        #expect(workout.averageHeartRate == nil)
        #expect(workout.zoneSeconds.isEmpty)
    }

    @Test func capturedVitalsSurviveOntoTheSummary() throws {
        let rig = try makeRig()
        let workout = try logWorkout(rig, sets: [("60", "10", .working)])
        let ceiling = MaxHeartRate(bpm: 180, isEstimated: false)
        let samples = [
            HeartRateSample(bpm: 150, date: t0, source: .watch),
            HeartRateSample(bpm: 130, date: t0.addingTimeInterval(10), source: .watch),
            HeartRateSample(bpm: 110, date: t0.addingTimeInterval(20), source: .watch),
        ]
        let vitals = WorkoutVitalsMath.vitals(from: samples, zoningAgainst: ceiling)

        WorkoutSummaryBuilder.capture(
            vitals: vitals, activeEnergyKilocalories: 282, onto: workout)
        try rig.session.finish(workout, at: t0.addingTimeInterval(300))

        let summary = WorkoutSummaryBuilder.summary(for: workout)
        #expect(summary.hasHeartRate)
        #expect(summary.averageHeartRate == 130)
        #expect(summary.maxHeartRate == 150)
        #expect(summary.activeEnergyKilocalories == 282)
        // Against a 180 max under D45's revised boundaries: 150 is 83% (zone 3)
        // and 130 is 72% (zone 2), 10 seconds each.
        #expect(summary.zoneSeconds[HeartRateZone.three.rawValue] == 10)
        #expect(summary.zoneSeconds[HeartRateZone.two.rawValue] == 10)
    }

    /// The summary is read from the workout's own fields, so History and the
    /// finish screen can never disagree — and neither re-queries HealthKit.
    @Test func theSummaryReadsPersistedFieldsNotALiveSource() throws {
        let rig = try makeRig()
        let workout = try logWorkout(rig, sets: [("60", "10", .working)])
        workout.averageHeartRate = 112
        workout.maxHeartRate = 159
        try rig.context.save()
        try rig.session.finish(workout, at: t0.addingTimeInterval(300))

        #expect(WorkoutSummaryBuilder.summary(for: workout).averageHeartRate == 112)
        #expect(WorkoutSummaryBuilder.summary(for: workout).maxHeartRate == 159)
    }
}
