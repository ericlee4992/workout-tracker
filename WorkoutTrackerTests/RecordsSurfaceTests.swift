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
        // Layer 1 is tag-specific, so the dumbbell session never leaks in.
        #expect(try history.recordSummary(
            for: barbell, layer: .thisEquipment).repCountBests[5]?.weightValue == 100)
        // Layer 3 is exercise-wide (ticket 11), so it does include it.
        #expect(try history.recordSummary(
            for: barbell, layer: .anyEquipment).repCountBests[5]?.weightValue == 150)
    }

    // MARK: - Post-review regressions (records layer keys + D23 load type)

    /// D23: a catalog loadType edit must not reinterpret already-logged sets.
    /// Reading the live exercise made the summary's load type disagree with
    /// every input RecordsMath filters by snapshot load type, so all rep-count
    /// records vanished at every layer.
    @Test func weightedRecordsSurviveALiveLoadTypeEdit() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Bent Row", loadType: .weighted)
        context.insert(exercise)
        try context.save()
        try log(
            context: context, exercise: exercise, gym: nil, tag: .barbell,
            value: 100, reps: 5, date: Date(timeIntervalSince1970: 100))

        exercise.loadType = .assisted
        try context.save()

        let session = WorkoutSession(context: context)
        let current = try session.startWorkout(at: nil, on: Date(timeIntervalSince1970: 300))
        let entry = try session.addEntry(for: exercise, to: current, freeWeightTag: .barbell)
        let summary = try PerformanceHistory(context: context)
            .recordSummary(for: entry, layer: .thisEquipment)

        #expect(summary.loadType == .weighted)
        #expect(summary.repCountBests[5]?.weightValue == 100)
        #expect(summary.isEmpty == false)
    }

    /// The same D23 breach in the direction that blanks a layer outright:
    /// assisted history reclassified as weighted has no rep table and no
    /// e1RM, so the layer rendered its empty state.
    @Test func assistedRecordsSurviveALiveLoadTypeEdit() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Assisted Pull-up", loadType: .assisted)
        context.insert(exercise)
        try context.save()
        try log(
            context: context, exercise: exercise, gym: nil, tag: .bodyweight,
            value: 20, reps: 8, date: Date(timeIntervalSince1970: 100))

        exercise.loadType = .weighted
        try context.save()

        let session = WorkoutSession(context: context)
        let current = try session.startWorkout(at: nil, on: Date(timeIntervalSince1970: 300))
        let entry = try session.addEntry(for: exercise, to: current, freeWeightTag: .bodyweight)
        let summary = try PerformanceHistory(context: context)
            .recordSummary(for: entry, layer: .thisEquipment)

        #expect(summary.loadType == .assisted)
        #expect(summary.repCountBests[8]?.weightValue == 20)
        #expect(summary.estimatedOneRepMax == nil)
        #expect(summary.isEmpty == false)
    }

    /// Ticket 11 layer 3 = "exercise anywhere". Keying a machineless entry's
    /// any-equipment layer by (exercise, tag) made it identical to layer 1, so
    /// a barbell entry never saw its own machine history.
    @Test func anyEquipmentLayerIsExerciseWideForAFreeWeightEntry() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Chest Press", loadType: .weighted)
        let gym = Gym(name: "Gym")
        let model = EquipmentModel(
            manufacturer: "A", modelName: "Press", exerciseIDs: [exercise.id])
        let machine = MachineInstance(label: "Press 1", gym: gym, model: model)
        for object in [exercise, gym, model, machine] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()

        try log(
            context: context, exercise: exercise, gym: nil, tag: .barbell,
            value: 100, reps: 5, date: Date(timeIntervalSince1970: 100))
        try log(
            context: context, exercise: exercise, gym: gym, machine: machine,
            value: 150, reps: 5, date: Date(timeIntervalSince1970: 200))

        let session = WorkoutSession(context: context)
        let current = try session.startWorkout(at: nil, on: Date(timeIntervalSince1970: 300))
        let entry = try session.addEntry(
            for: exercise, to: current, freeWeightTag: .barbell)
        let history = PerformanceHistory(context: context)

        #expect(try history.recordSummary(
            for: entry, layer: .thisEquipment).repCountBests[5]?.weightValue == 100)
        #expect(try history.recordSummary(
            for: entry, layer: .anyEquipment).repCountBests[5]?.weightValue == 150)
    }

    /// Layer 2 is "same model *elsewhere*": keying it by model alone included
    /// the current gym's own sets, contradicting both its header and the
    /// snapshot list beside it, which filter on `snapshotGymID != gymID`.
    @Test func sameModelLayerExcludesTheCurrentGymsOwnSets() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Leg Press", loadType: .weighted)
        let model = EquipmentModel(
            manufacturer: "A", modelName: "Leg Press", exerciseIDs: [exercise.id])
        let gymA = Gym(name: "A")
        let gymB = Gym(name: "B")
        let machineA = MachineInstance(label: "A", gym: gymA, model: model)
        let machineB = MachineInstance(label: "B", gym: gymB, model: model)
        for object in [exercise, model, gymA, gymB, machineA, machineB]
            as [any PersistentModel] { context.insert(object) }
        try context.save()

        // The heaviest sets on this model are the ones logged at the *current*
        // gym, so they win the model group unless "elsewhere" is enforced.
        try log(
            context: context, exercise: exercise, gym: gymA, machine: machineA,
            value: 200, reps: 5, date: Date(timeIntervalSince1970: 100))
        try log(
            context: context, exercise: exercise, gym: gymB, machine: machineB,
            value: 50, reps: 5, date: Date(timeIntervalSince1970: 200))

        let session = WorkoutSession(context: context)
        let current = try session.startWorkout(at: gymA, on: Date(timeIntervalSince1970: 300))
        let entry = try session.addEntry(for: exercise, to: current, machine: machineA)
        let history = PerformanceHistory(context: context)

        #expect(try history.recordSummary(
            for: entry, layer: .sameModelElsewhere).repCountBests[5]?.weightValue == 50)
        #expect(try history.recordSummary(
            for: entry, layer: .thisEquipment).repCountBests[5]?.weightValue == 200)
    }

    /// Ticket 13: "Empty layers render their labeled empty states, not blank
    /// sections" — every applicable layer of a history-free entry offers a
    /// layer-specific history message plus the records placeholder.
    @Test func emptyLayersCarryLabeledEmptyStatesNotBlankSections() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Lat Pulldown", loadType: .weighted)
        let gym = Gym(name: "Gym")
        let model = EquipmentModel(
            manufacturer: "A", modelName: "Pulldown", exerciseIDs: [exercise.id])
        let machine = MachineInstance(label: "Pulldown 1", gym: gym, model: model)
        for object in [exercise, gym, model, machine] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()

        let session = WorkoutSession(context: context)
        let current = try session.startWorkout(at: gym, on: Date(timeIntervalSince1970: 100))
        let entry = try session.addEntry(for: exercise, to: current, machine: machine)
        let history = PerformanceHistory(context: context)
        let layers = try history.layers(for: entry)

        #expect(layers.map(\.kind) == [.thisEquipment, .sameModelElsewhere, .anyEquipment])
        var messages: Set<String> = []
        for layer in layers {
            #expect(layer.snapshot == nil)
            #expect(try history.recordSummary(for: entry, layer: layer.kind).isEmpty)
            let message = layer.kind.emptyHistoryMessage(hasMachine: true)
            #expect(!message.isEmpty)
            messages.insert(message)
        }
        // One distinct, layer-specific message each — never a blank section.
        #expect(messages.count == layers.count)
        #expect(!PerformanceLayerKind.emptyRecordsMessage.isEmpty)
        #expect(PerformanceLayerKind.thisEquipment.emptyHistoryMessage(hasMachine: false)
            != PerformanceLayerKind.thisEquipment.emptyHistoryMessage(hasMachine: true))
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
