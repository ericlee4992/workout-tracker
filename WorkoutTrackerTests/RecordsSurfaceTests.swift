import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

struct RecordsSurfaceTests {
    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    @discardableResult
    private func log(
        context: ModelContext,
        exercise: Exercise,
        gym: Gym?,
        machine: MachineInstance? = nil,
        tag: EquipmentTag? = nil,
        value: Double? = nil,
        unit: WeightUnit = .kg,
        reps: Int,
        date: Date
    ) throws -> ExerciseEntry {
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: gym, on: date)
        let entry = try session.addEntry(
            for: exercise, to: workout, machine: machine, freeWeightTag: tag)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        set.weightUnit = unit
        if let value { try session.commitWeight(String(value), for: set) }
        try session.commitReps(String(reps), for: set)
        try session.toggleCompletion(of: set, at: date.addingTimeInterval(1))
        try session.finish(workout, at: date.addingTimeInterval(10))
        return entry
    }

    @Test func weightedRecordsBridgeMachineModelExerciseLayersAndPreserveUnits() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Chest Press", loadType: .weighted)
        let model = EquipmentModel(manufacturer: "A", modelName: "Press", exerciseIDs: [exercise.id])
        let otherModel = EquipmentModel(manufacturer: "B", modelName: "Press", exerciseIDs: [exercise.id])
        let gymA = Gym(name: "A")
        let gymB = Gym(name: "B")
        let machineA = MachineInstance(label: "A", gym: gymA, model: model)
        let machineB = MachineInstance(label: "B", gym: gymB, model: model)
        let machineC = MachineInstance(label: "C", gym: gymB, model: otherModel)
        for object in [exercise, model, otherModel, gymA, gymB, machineA, machineB, machineC]
            as [any PersistentModel] { context.insert(object) }
        try context.save()

        try log(
            context: context, exercise: exercise, gym: gymA, machine: machineA,
            value: 100, unit: .lb, reps: 5, date: Date(timeIntervalSince1970: 100))
        try log(
            context: context, exercise: exercise, gym: gymB, machine: machineB,
            value: 50, unit: .kg, reps: 5, date: Date(timeIntervalSince1970: 200))
        try log(
            context: context, exercise: exercise, gym: gymB, machine: machineC,
            value: 60, unit: .kg, reps: 5, date: Date(timeIntervalSince1970: 300))

        let session = WorkoutSession(context: context)
        let current = try session.startWorkout(at: gymA, on: Date(timeIntervalSince1970: 500))
        let entry = try session.addEntry(for: exercise, to: current, machine: machineA)
        let history = PerformanceHistory(context: context)

        let exact = try history.recordSummary(for: entry, layer: .thisEquipment)
        #expect(exact.repCountBests[5]?.weightValue == 100)
        #expect(exact.repCountBests[5]?.weightUnit == .lb)
        #expect(exact.estimatedOneRepMax != nil)

        let modelLayer = try history.recordSummary(for: entry, layer: .sameModelElsewhere)
        #expect(modelLayer.repCountBests[5]?.weightValue == 50)
        #expect(modelLayer.repCountBests[5]?.weightUnit == .kg)

        let exerciseLayer = try history.recordSummary(for: entry, layer: .anyEquipment)
        #expect(exerciseLayer.repCountBests[5]?.weightValue == 60)
        #expect(exerciseLayer.repCountBests[5]?.weightUnit == .kg)
    }

    @Test func freeWeightRecordLayersNeverMergeBarbellAndDumbbell() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Bench Press", loadType: .weighted)
        context.insert(exercise)
        try context.save()
        try log(
            context: context, exercise: exercise, gym: nil, tag: .barbell,
            value: 100, reps: 5, date: Date(timeIntervalSince1970: 100))
        try log(
            context: context, exercise: exercise, gym: nil, tag: .dumbbell,
            value: 150, reps: 5, date: Date(timeIntervalSince1970: 200))

        let session = WorkoutSession(context: context)
        let current = try session.startWorkout(at: nil, on: Date(timeIntervalSince1970: 300))
        let barbell = try session.addEntry(
            for: exercise, to: current, freeWeightTag: .barbell)
        let history = PerformanceHistory(context: context)
        #expect(try history.recordSummary(
            for: barbell, layer: .thisEquipment).repCountBests[5]?.weightValue == 100)
        #expect(try history.recordSummary(
            for: barbell, layer: .anyEquipment).repCountBests[5]?.weightValue == 100)
    }

    @Test func loadTypeSpecificSummariesExposeOnlyApplicableRecords() throws {
        let context = try makeContext()
        let session = WorkoutSession(context: context)
        let cases: [(LoadType, Double?, Int)] = [
            (.assisted, 20, 8),
            (.bodyweightPlus, 25, 6),
            (.bodyweight, nil, 30),
        ]

        for (offset, item) in cases.enumerated() {
            let exercise = Exercise(name: "Type \(offset)", loadType: item.0)
            context.insert(exercise)
            try context.save()
            try log(
                context: context, exercise: exercise, gym: nil, tag: .bodyweight,
                value: item.1, reps: item.2,
                date: Date(timeIntervalSince1970: TimeInterval(100 + offset * 100)))
            let current = try session.startWorkout(
                at: nil, on: Date(timeIntervalSince1970: TimeInterval(150 + offset * 100)))
            let entry = try session.addEntry(
                for: exercise, to: current, freeWeightTag: .bodyweight)
            let summary = try PerformanceHistory(context: context)
                .recordSummary(for: entry, layer: .thisEquipment)

            #expect(summary.loadType == item.0)
            #expect(summary.estimatedOneRepMax == nil)
            if item.0 == .bodyweight {
                #expect(summary.repCountBests.isEmpty)
                #expect(summary.bodyweightBest?.reps == 30)
            } else {
                #expect(summary.repCountBests[item.2]?.weightValue == item.1)
                #expect(summary.bodyweightBest == nil)
            }

            // Leave no active workout before the next case.
            try session.cancel(current)
        }
    }
}
