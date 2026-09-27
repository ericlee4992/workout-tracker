import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Floodlight redesign ticket 04 — the Finish receipt's derived content: one new-best line per
// scope against the record from BEFORE the workout, the exercise rows' best set and mark
// (warmups out), ring families by completed set, and the template's last-run comparison.

struct FinishReceiptTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private struct Fixture {
        var context: ModelContext
        var exercise: Exercise
        var gym: Gym
        var machine: MachineInstance
    }

    private func fixture() throws -> Fixture {
        let context = try makeContext()
        let exercise = Exercise(name: "Chest Press", loadType: .weighted, muscleGroup: "Chest")
        let gym = Gym(name: "Iron Temple")
        let machine = MachineInstance(label: "Chest Press 2", gym: gym, model: nil)
        for object in [exercise, gym, machine] as [any PersistentModel] { context.insert(object) }
        try context.save()
        return Fixture(context: context, exercise: exercise, gym: gym, machine: machine)
    }

    /// Logs `sets` (kg, reps, warmup?) into one new entry; minutes are offsets from `start`.
    @discardableResult
    private func log(_ f: Fixture, in workout: Workout, _ sets: [(Double, Int, Bool)],
                     start: Date) throws -> ExerciseEntry {
        let session = WorkoutSession(context: f.context)
        let entry = try session.addEntry(for: f.exercise, to: workout, machine: f.machine)
        var rows = WorkoutSession.orderedSets(of: entry)
        while rows.count < sets.count { _ = try session.addSet(to: entry); rows = WorkoutSession.orderedSets(of: entry) }
        for (index, value) in sets.enumerated() {
            let row = rows[index]
            if value.2 { row.type = .warmup }
            row.weightUnit = .kg
            try session.commitWeight(String(value.0), for: row)
            try session.commitReps(String(value.1), for: row)
            try session.toggleCompletion(of: row, at: start.addingTimeInterval(Double(index + 1) * 60))
        }
        return entry
    }

    private func workout(_ f: Fixture, _ sets: [(Double, Int, Bool)], at start: Date,
                         template: UUID? = nil) throws -> Workout {
        let session = WorkoutSession(context: f.context)
        let workout = try session.startWorkout(at: f.gym, on: start)
        workout.sourceTemplateID = template
        workout.sourceTemplateName = template == nil ? nil : "Push Day"
        try log(f, in: workout, sets, start: start)
        try session.finish(workout, at: start.addingTimeInterval(3600))
        return workout
    }

    @Test func oneBestPerScopeAgainstThePreWorkoutRecord() throws {
        let f = try fixture()
        try workout(f, [(100, 5, false)], at: t0)
        let today = try workout(f, [(200, 5, true), (102, 5, false), (105, 5, false)], at: t0.addingTimeInterval(86_400))

        let receipt = try FinishReceipt.build(for: today, in: f.context)
        #expect(receipt.bests.count == 1)
        let best = try #require(receipt.bests.first)
        #expect(best.value.weight == 105 && best.value.reps == 5)
        #expect(best.previous?.weight == 100 && best.previous?.reps == 5)
        #expect(best.equipment == "Chest Press 2")

        let row = try #require(receipt.exercises.first)
        #expect(row.badge == .newBest)
        #expect(row.best?.weight == 105)   // the 200 kg warmup is not the best set
        #expect(row.detail == "Chest Press 2 · 3 sets")
        #expect(receipt.familySets == [FamilyCount(family: .chest, sets: 3)])
    }

    @Test func entriesSharingAScopeListTheirBestOnce() throws {
        let f = try fixture()
        try workout(f, [(100, 5, false)], at: t0)
        let start = t0.addingTimeInterval(86_400)
        let session = WorkoutSession(context: f.context)
        let today = try session.startWorkout(at: f.gym, on: start)
        try log(f, in: today, [(102, 5, false)], start: start)
        try log(f, in: today, [(105, 5, false)], start: start.addingTimeInterval(600))
        try session.finish(today, at: start.addingTimeInterval(3600))

        let receipt = try FinishReceipt.build(for: today, in: f.context)
        #expect(receipt.bests.map(\.value.weight) == [105])
        #expect(receipt.bests.first?.previous?.weight == 100)
        #expect(receipt.exercises.map(\.badge) == [.newBest, .newBest])
    }

    @Test func aLaterWorkoutDoesNotChangeAnEarlierReceipt() throws {
        let f = try fixture()
        try workout(f, [(100, 5, false)], at: t0)
        let earlier = try workout(f, [(105, 5, false)], at: t0.addingTimeInterval(86_400))
        try workout(f, [(120, 5, false)], at: t0.addingTimeInterval(2 * 86_400))

        let receipt = try FinishReceipt.build(for: earlier, in: f.context)
        #expect(receipt.bests.map(\.value.weight) == [105])
        #expect(receipt.bests.first?.previous?.weight == 100)
    }

    @Test func aFirstWorkoutInAScopeListsNoBestAndMarksFirstTime() throws {
        let f = try fixture()
        let first = try workout(f, [(60, 10, false), (70, 10, false)], at: t0)
        let receipt = try FinishReceipt.build(for: first, in: f.context)
        #expect(receipt.bests.isEmpty)
        #expect(receipt.exercises.first?.badge == .firstTime)
    }

    @Test func comparisonUsesTheTemplatesPreviousRun() throws {
        let f = try fixture()
        let template = UUID()
        try workout(f, [(100, 10, false)], at: t0, template: template)
        try workout(f, [(50, 10, false)], at: t0.addingTimeInterval(3600 * 5))   // no template
        let today = try workout(f, [(100, 5, false)], at: t0.addingTimeInterval(86_400), template: template)

        let comparison = try #require(FinishReceipt.build(for: today, in: f.context).comparison)
        #expect(comparison.templateName == "Push Day")
        #expect(comparison.lastDate == t0)
        #expect(abs(comparison.lastVolumeKg - 1000) < 0.001)
        #expect(abs(comparison.volumeKg - 500) < 0.001)
    }
}
