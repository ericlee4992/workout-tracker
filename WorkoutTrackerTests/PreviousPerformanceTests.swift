import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

struct PreviousPerformanceTests {
    private struct Rig {
        let context: ModelContext
        let session: WorkoutSession
        let history: PerformanceHistory
        let exercise: Exercise
        let model: EquipmentModel
        let gymA: Gym
        let gymB: Gym
        let machineA: MachineInstance
        let machineB: MachineInstance
        let machineNoHistory: MachineInstance
    }

    private func makeRig() throws -> Rig {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let exercise = Exercise(name: "Chest Press", loadType: .weighted)
        let model = EquipmentModel(
            manufacturer: "Life Fitness", modelName: "Insignia",
            exerciseIDs: [exercise.id])
        let gymA = Gym(name: "Gym A", defaultUnit: .kg)
        let gymB = Gym(name: "Gym B", defaultUnit: .lb)
        let machineA = MachineInstance(label: "Press A", gym: gymA, model: model)
        let machineB = MachineInstance(label: "Press B", gym: gymB, model: model)
        let machineNoHistory = MachineInstance(label: "New Press", gym: gymA, model: model)
        for object in [exercise, model, gymA, gymB, machineA, machineB, machineNoHistory]
            as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()
        return Rig(
            context: context,
            session: WorkoutSession(context: context),
            history: PerformanceHistory(context: context),
            exercise: exercise, model: model, gymA: gymA, gymB: gymB,
            machineA: machineA, machineB: machineB,
            machineNoHistory: machineNoHistory)
    }

    @discardableResult
    private func log(
        rig: Rig,
        gym: Gym?,
        machine: MachineInstance? = nil,
        tag: EquipmentTag? = nil,
        values: [(SetType, Double, WeightUnit, Int)],
        start: Date
    ) throws -> ExerciseEntry {
        let workout = try rig.session.startWorkout(at: gym, on: start)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: machine, freeWeightTag: tag)
        for (index, item) in values.enumerated() {
            let set = index == 0
                ? try #require(WorkoutSession.orderedSets(of: entry).first)
                : try rig.session.addSet(to: entry)
            set.type = item.0
            set.weightUnit = item.2
            try rig.session.commitWeight(String(item.1), for: set)
            try rig.session.commitReps(String(item.3), for: set)
            try rig.session.toggleCompletion(
                of: set, at: start.addingTimeInterval(TimeInterval(index + 1)))
        }
        try rig.session.finish(workout, at: start.addingTimeInterval(100))
        return entry
    }

    @Test func sameMachinePrefillStaysIncompleteAndCompletesInOneTap() throws {
        let rig = try makeRig()
        try log(
            rig: rig, gym: rig.gymA, machine: rig.machineA,
            values: [(.working, 60, .kg, 10)], start: Date(timeIntervalSince1970: 100))

        let workout = try rig.session.startWorkout(at: rig.gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try rig.session.addEntry(for: rig.exercise, to: workout, machine: rig.machineA)
        let row = try #require(WorkoutSession.orderedSets(of: entry).first)
        let selected = try rig.history.prefill(for: row)
        let candidate = try #require(selected)
        #expect(candidate.displayLabel == "60 kg × 10")
        #expect(try rig.history.applyPrefill(candidate, to: row, isDirty: false))
        #expect(row.weightValue == 60)
        #expect(row.weightUnit == .kg)
        #expect(row.reps == 10)
        #expect(row.completedAt == nil)

        try rig.session.toggleCompletion(of: row, at: Date(timeIntervalSince1970: 301))
        #expect(row.completedAt == Date(timeIntervalSince1970: 301))
    }

    @Test func typeAwareOrdinalMatchingSkipsWarmups() throws {
        let rig = try makeRig()
        try log(
            rig: rig, gym: rig.gymA, machine: rig.machineA,
            values: [
                (.warmup, 20, .kg, 12),
                (.working, 50, .kg, 10),
                (.working, 55, .kg, 8),
                (.working, 60, .kg, 6),
            ],
            start: Date(timeIntervalSince1970: 100))

        let workout = try rig.session.startWorkout(at: rig.gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try rig.session.addEntry(for: rig.exercise, to: workout, machine: rig.machineA)
        let first = try #require(WorkoutSession.orderedSets(of: entry).first)
        let second = try rig.session.addSet(to: entry)
        #expect(try rig.history.prefill(for: first)?.weightValue == 50)
        #expect(try rig.history.prefill(for: second)?.weightValue == 55)
    }

    /// D26: `drop` is its own sequence, exactly as warmup and working already
    /// are — the nth drop set matches the previous session's nth drop set,
    /// not its nth working set.
    @Test func typeAwareOrdinalMatchingTreatsDropSetsAsTheirOwnSequence() throws {
        let rig = try makeRig()
        try log(
            rig: rig, gym: rig.gymA, machine: rig.machineA,
            values: [
                (.warmup, 20, .kg, 12),
                (.working, 100, .kg, 8),
                (.working, 100, .kg, 6),
                (.drop, 70, .kg, 8),
                (.drop, 50, .kg, 10),
            ],
            start: Date(timeIntervalSince1970: 100))

        let workout = try rig.session.startWorkout(
            at: rig.gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machineA)
        let firstWorking = try #require(WorkoutSession.orderedSets(of: entry).first)
        let firstDrop = try rig.session.addSet(to: entry)
        try rig.session.setType(.drop, of: firstDrop)
        let secondDrop = try rig.session.addSet(to: entry)
        try rig.session.setType(.drop, of: secondDrop)

        #expect(try rig.history.prefill(for: firstWorking)?.weightValue == 100)
        #expect(try rig.history.prefill(for: firstDrop)?.weightValue == 70)
        #expect(try rig.history.prefill(for: secondDrop)?.weightValue == 50)

        // A third drop row has no counterpart last time — no invented match.
        let thirdDrop = try rig.session.addSet(to: entry)
        try rig.session.setType(.drop, of: thirdDrop)
        #expect(try rig.history.prefill(for: thirdDrop) == nil)
    }

    @Test func dirtyRowRejectsDelayedPrefill() throws {
        let rig = try makeRig()
        try log(
            rig: rig, gym: rig.gymA, machine: rig.machineA,
            values: [(.working, 60, .kg, 10)], start: Date(timeIntervalSince1970: 100))
        let workout = try rig.session.startWorkout(at: rig.gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try rig.session.addEntry(for: rig.exercise, to: workout, machine: rig.machineA)
        let row = try #require(WorkoutSession.orderedSets(of: entry).first)
        let selected = try rig.history.prefill(for: row)
        let delayed = try #require(selected)

        try rig.session.commitWeight("72.5", for: row)
        #expect(try !rig.history.applyPrefill(delayed, to: row, isDirty: true))
        #expect(row.weightValue == 72.5)
        #expect(row.reps == nil)
    }

    @Test func noHistoryMachineHasNoPrefillButFallbackLayersDisplay() throws {
        let rig = try makeRig()
        try log(
            rig: rig, gym: rig.gymB, machine: rig.machineB,
            values: [(.working, 135, .lb, 8)], start: Date(timeIntervalSince1970: 100))
        let workout = try rig.session.startWorkout(at: rig.gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machineNoHistory)
        let row = try #require(WorkoutSession.orderedSets(of: entry).first)
        #expect(try rig.history.prefill(for: row) == nil)

        let layers = try rig.history.layers(for: entry)
        #expect(layers.map(\.kind) == [.thisEquipment, .sameModelElsewhere, .anyEquipment])
        #expect(layers[0].snapshot == nil)
        #expect(layers[1].snapshot?.gymName == "Gym B")
        #expect(layers[1].snapshot?.sets.first?.displayLabel == "135 lb × 8")
        #expect(layers[2].snapshot?.sets.first?.weightUnit == .lb)
    }

    @Test func travelCaseUsesSnapshotModelAtOtherGymWithAsEnteredUnits() throws {
        let rig = try makeRig()
        try log(
            rig: rig, gym: rig.gymB, machine: rig.machineB,
            values: [(.working, 140, .lb, 6)], start: Date(timeIntervalSince1970: 100))
        let workout = try rig.session.startWorkout(at: rig.gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try rig.session.addEntry(for: rig.exercise, to: workout, machine: rig.machineA)
        let layers = try rig.history.layers(for: entry)
        let sameModel = try #require(
            layers.first { $0.kind == .sameModelElsewhere }?.snapshot)
        #expect(sameModel.gymName == "Gym B")
        #expect(sameModel.equipmentLabel == "Press B · Life Fitness Insignia")
        #expect(sameModel.sets.first?.weightUnit == .lb)
        #expect(sameModel.sets.first?.weightValue == 140)
    }

    @Test func machinelessPrefillSeparatesBarbellFromDumbbell() throws {
        let rig = try makeRig()
        try log(
            rig: rig, gym: nil, tag: .barbell,
            values: [(.working, 100, .kg, 5)], start: Date(timeIntervalSince1970: 100))
        try log(
            rig: rig, gym: nil, tag: .dumbbell,
            values: [(.working, 30, .kg, 10)], start: Date(timeIntervalSince1970: 300))

        let workout = try rig.session.startWorkout(at: nil, on: Date(timeIntervalSince1970: 500))
        let barbell = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .barbell)
        let row = try #require(WorkoutSession.orderedSets(of: barbell).first)
        #expect(try rig.history.prefill(for: row)?.weightValue == 100)

        let layers = try rig.history.layers(for: barbell)
        #expect(layers.map(\.kind) == [.thisEquipment, .anyEquipment])
        #expect(layers[0].snapshot?.equipmentLabel == "Barbell")
        #expect(layers[1].snapshot?.equipmentLabel == "Dumbbell")
    }

    @Test func duplicateEntriesInSourceWorkoutUseLastEntryOrder() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 100)
        let workout = try rig.session.startWorkout(at: rig.gymA, on: start)
        for weight in [50.0, 70.0] {
            let entry = try rig.session.addEntry(
                for: rig.exercise, to: workout, machine: rig.machineA)
            let set = try #require(WorkoutSession.orderedSets(of: entry).first)
            try rig.session.commitWeight(String(weight), for: set)
            try rig.session.commitReps("8", for: set)
            try rig.session.toggleCompletion(of: set, at: start.addingTimeInterval(weight))
        }
        try rig.session.finish(workout, at: start.addingTimeInterval(100))

        let current = try rig.session.startWorkout(at: rig.gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try rig.session.addEntry(for: rig.exercise, to: current, machine: rig.machineA)
        let row = try #require(WorkoutSession.orderedSets(of: entry).first)
        #expect(try rig.history.prefill(for: row)?.weightValue == 70)
    }
}
