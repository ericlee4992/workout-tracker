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
                     start: Date, exercise: Exercise? = nil) throws -> ExerciseEntry {
        let session = WorkoutSession(context: f.context)
        let entry = try exercise.map { try session.addEntry(for: $0, to: workout, machine: nil) }
            ?? session.addEntry(for: f.exercise, to: workout, machine: f.machine)
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

    // MARK: Codex review 04

    private func exercise(_ f: Fixture, _ name: String, group: String?) throws -> Exercise {
        let exercise = Exercise(name: name, loadType: .weighted, muscleGroup: group)
        f.context.insert(exercise)
        try f.context.save()
        return exercise
    }

    /// Finding 1: every completed set is in the ring — unmapped groups neutral, in workout order.
    @Test func theRingHasEveryCompletedSetInWorkoutOrder() throws {
        let f = try fixture()
        let crunch = try exercise(f, "Crunch", group: "Core")
        let row = try exercise(f, "Row", group: "Back")
        let session = WorkoutSession(context: f.context)
        let workout = try session.startWorkout(at: f.gym, on: t0)
        try log(f, in: workout, [(50, 10, false), (55, 8, false), (55, 8, false)], start: t0)
        try log(f, in: workout, [(40, 10, false)], start: t0.addingTimeInterval(600), exercise: row)
        try log(f, in: workout, [(60, 6, false), (60, 6, false)], start: t0.addingTimeInterval(1200))
        try log(f, in: workout, [(10, 15, false), (10, 15, false)], start: t0.addingTimeInterval(1800), exercise: crunch)
        try session.finish(workout, at: t0.addingTimeInterval(3600))

        let receipt = try FinishReceipt.build(for: workout, in: f.context)
        #expect(receipt.ringRuns == [RingRun(family: .chest, sets: 3), RingRun(family: .back, sets: 1),
                                     RingRun(family: .chest, sets: 2), RingRun(family: nil, sets: 2)])
        #expect(receipt.ringRuns.reduce(0) { $0 + $1.sets } == workout.completedSets.count)
        #expect(receipt.familySets == [FamilyCount(family: .chest, sets: 5), FamilyCount(family: .back, sets: 1)])
    }

    @Test func aCoreOnlyWorkoutStillHasARing() throws {
        let f = try fixture()
        let crunch = try exercise(f, "Crunch", group: "Core")
        let session = WorkoutSession(context: f.context)
        let workout = try session.startWorkout(at: f.gym, on: t0)
        try log(f, in: workout, [(10, 15, false), (10, 15, false)], start: t0, exercise: crunch)
        try session.finish(workout, at: t0.addingTimeInterval(3600))

        let receipt = try FinishReceipt.build(for: workout, in: f.context)
        #expect(receipt.ringRuns == [RingRun(family: nil, sets: 2)])
        #expect(receipt.familySets.isEmpty)
    }

    /// Finding 5: a bar-mode best and the bar-mode record it beat both keep their bar.
    @Test func barModeBestsKeepTheirBar() throws {
        let f = try fixture()
        let past = try workout(f, [(100, 5, false)], at: t0)
        for set in past.completedSets { set.barWeightValue = 20 }
        try f.context.save()
        let start = t0.addingTimeInterval(86_400)
        let session = WorkoutSession(context: f.context)
        let today = try session.startWorkout(at: f.gym, on: start)
        let entry = try log(f, in: today, [(110, 5, false)], start: start)
        for set in entry.sets ?? [] { set.barWeightValue = 20 }
        try session.finish(today, at: start.addingTimeInterval(3600))

        let receipt = try FinishReceipt.build(for: today, in: f.context)
        let best = try #require(receipt.bests.first)
        #expect(best.value.bar == 20)
        #expect(best.previous?.bar == 20)
        #expect(receipt.exercises.first?.best?.bar == 20)
        #expect(LookFormat.set(best.value) == "\(LookFormat.weight(110, .kg)) × 5 (\(LookFormat.weight(20, .kg)) bar)")
    }

    /// Findings 2 and 3: the count-up reads the locale's own grouping, and keeps decimals.
    @Test func countUpParsesInTheFormattingLocale() throws {
        let german = try #require(CountUpFormat.parse("1.880", locale: Locale(identifier: "de_DE")))
        #expect(german.value == 1880)
        let english = try #require(CountUpFormat.parse("1,880", locale: Locale(identifier: "en_US")))
        #expect(english.value == 1880)
        let fraction = try #require(CountUpFormat.parse("7.5", locale: Locale(identifier: "en_US")))
        #expect(fraction.value == 7.5)
        let germanFraction = try #require(CountUpFormat.parse("1.234,25", locale: Locale(identifier: "de_DE")))
        #expect(germanFraction.value == 1234.25)
        #expect(CountUpFormat.parse("52:10")?.value == 3130)
    }

    @Test func volumeKeepsItsDecimals() {
        #expect(LookFormat.groupedDecimal(7.5) == LookFormat.number(7.5))
        #expect(LookFormat.groupedDecimal(0.25) == LookFormat.number(0.25))
        #expect(LookFormat.groupedDecimal(18_450) == LookFormat.grouped(18_450))
    }
}
