import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

struct WorkoutTemplateTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    @Test func crudOrderingAndPerSlotTargetsSurviveRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("template-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")
        var templateID = UUID()

        do {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let bench = Exercise(name: "Bench")
            let press = Exercise(name: "Press")
            context.insert(bench)
            context.insert(press)
            try context.save()
            let service = WorkoutTemplateService(context: context)
            let template = try service.create(name: "Push", items: [
                TemplateItemDraft(exercise: bench, targetRepsBySet: [10, 8, 6]),
                TemplateItemDraft(exercise: press, targetRepsBySet: [12, 12]),
            ])
            templateID = template.id
            try service.update(template, name: "Push A", items: [
                TemplateItemDraft(exercise: press, targetRepsBySet: [15]),
                TemplateItemDraft(exercise: bench, targetRepsBySet: [5, 5]),
            ])
        }

        do {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let id = templateID
            let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate { $0.id == id }))
            let template = try #require(templates.first)
            #expect(template.name == "Push A")
            let items = WorkoutTemplateService.orderedItems(of: template)
            #expect(items.map { $0.exercise?.name } == ["Press", "Bench"])
            #expect(items[0].targetSets == 1)
            #expect(items[0].targetRepsBySet == [15])
            #expect(items[1].targetSets == 2)
            #expect(items[1].targetRepsBySet == [5, 5])
            try WorkoutTemplateService(context: context).delete(template)
        }

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        #expect(try context.fetchCount(
            FetchDescriptor<WorkoutTemplate>()) == 0)
    }

    @Test func templateResolvesRememberedMachinesPerGymAndUnknownStartsMachineless() throws {
        let context = try makeInMemoryContext()
        let bench = Exercise(name: "Bench")
        let row = Exercise(name: "Row")
        let model = EquipmentModel(
            manufacturer: "A", modelName: "Combo",
            exerciseIDs: [bench.id, row.id])
        let gymA = Gym(name: "Gym A")
        let gymB = Gym(name: "Gym B")
        let benchA = MachineInstance(label: "Bench A", gym: gymA, model: model)
        let benchB = MachineInstance(label: "Bench B", gym: gymB, model: model)
        let rowA = MachineInstance(label: "Row A", gym: gymA, model: model)
        for object in [bench, row, model, gymA, gymB, benchA, benchB, rowA]
            as [any PersistentModel] { context.insert(object) }
        context.insert(GymExerciseMemory(
            gymID: gymA.id, exerciseID: bench.id, machineID: benchA.id,
            updatedAt: Date(timeIntervalSince1970: 10)))
        context.insert(GymExerciseMemory(
            gymID: gymA.id, exerciseID: row.id, machineID: rowA.id,
            updatedAt: Date(timeIntervalSince1970: 10)))
        context.insert(GymExerciseMemory(
            gymID: gymB.id, exerciseID: bench.id, machineID: benchB.id,
            updatedAt: Date(timeIntervalSince1970: 10)))
        try context.save()
        let service = WorkoutTemplateService(context: context)
        let template = try service.create(name: "Upper", items: [
            TemplateItemDraft(exercise: bench, targetRepsBySet: [10, 8]),
            TemplateItemDraft(exercise: row, targetRepsBySet: [12]),
        ])

        let atA = try service.start(
            template, at: gymA, on: Date(timeIntervalSince1970: 100))
        #expect(atA.sourceTemplateID == template.id)
        let entriesA = WorkoutSession.orderedEntries(of: atA)
        #expect(entriesA.map { $0.machine?.id } == [benchA.id, rowA.id])
        #expect(WorkoutSession.orderedSets(of: entriesA[0]).map(\.reps) == [10, 8])
        try WorkoutSession(context: context).cancel(atA)

        let atB = try service.start(
            template, at: gymB, on: Date(timeIntervalSince1970: 200))
        let entriesB = WorkoutSession.orderedEntries(of: atB)
        #expect(entriesB.map { $0.machine?.id } == [benchB.id, nil])
        #expect(entriesB[1].freeWeightTag == nil)
    }

    @Test func noGymTemplateStartMakesEveryEntryMachineless() throws {
        let context = try makeInMemoryContext()
        let a = Exercise(name: "A")
        let b = Exercise(name: "B")
        context.insert(a)
        context.insert(b)
        try context.save()
        let service = WorkoutTemplateService(context: context)
        let template = try service.create(name: "Home", items: [
            TemplateItemDraft(exercise: a, targetRepsBySet: [10]),
            TemplateItemDraft(exercise: b, targetRepsBySet: [8, 8]),
        ])
        let workout = try service.start(template, at: nil)
        #expect(workout.gym == nil)
        #expect(WorkoutSession.orderedEntries(of: workout).allSatisfy { $0.machine == nil })
    }

    @Test func saveAsTemplateCapturesCompletedStructureAndSlotRepsOnly() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSession(context: context)
        let bench = Exercise(name: "Bench")
        let row = Exercise(name: "Row")
        let empty = Exercise(name: "Empty")
        context.insert(bench)
        context.insert(row)
        context.insert(empty)
        try context.save()
        let workout = try session.startWorkout(at: nil)

        for (exercise, reps) in [(bench, [10, 8, 6]), (row, [12, 12])] {
            let entry = try session.addEntry(for: exercise, to: workout)
            while WorkoutSession.orderedSets(of: entry).count < reps.count {
                try session.addSet(to: entry)
            }
            for (index, set) in WorkoutSession.orderedSets(of: entry).enumerated() {
                try session.commitWeight("50", for: set)
                try session.commitReps(String(reps[index]), for: set)
                try session.toggleCompletion(of: set)
            }
        }
        _ = try session.addEntry(for: empty, to: workout)
        try session.finish(workout)

        let template = try WorkoutTemplateService(context: context)
            .saveAsTemplate(workout, name: "Captured")
        let items = WorkoutTemplateService.orderedItems(of: template)
        #expect(items.map { $0.exercise?.name } == ["Bench", "Row"])
        #expect(items.map(\.targetSets) == [3, 2])
        #expect(items[0].targetRepsBySet == [10, 8, 6])
        #expect(items[1].targetRepsBySet == [12, 12])
        #expect(workout.sourceTemplateID == nil)
    }
}
