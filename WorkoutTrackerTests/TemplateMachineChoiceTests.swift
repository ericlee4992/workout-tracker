import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Ticket 23 (the user, 2026-10-23; D66): a machine picked for an exercise while building a template becomes the
/// user's machine for that exercise at that gym, so the template starts on it there. Templates stay generic (D6):
/// another gym is untouched, and the template stores no machine.
@MainActor
struct TemplateMachineChoiceTests {

    private final class Store {
        let container: ModelContainer
        let context: ModelContext
        init() throws {
            let schema = WorkoutTrackerStore.schema
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            context = ModelContext(container)
        }
    }

    @Test func aPickedMachineIsWhereTheTemplateStartsAtThatGym() throws {
        let store = try Store()
        let context = store.context
        let iron = Gym(name: "Iron Temple")
        let other = Gym(name: "Other Gym")
        let press = Exercise(name: "Chest Press", isSeeded: false)
        let model = EquipmentModel(manufacturer: "Co", modelName: "Press", exerciseIDs: [press.id], isSeeded: false)
        let first = MachineInstance(label: "Chest Press 1", gym: iron, model: model)
        let second = MachineInstance(label: "Chest Press 2", gym: iron, model: model)
        let elsewhere = MachineInstance(label: "Press", gym: other, model: model)
        for object in [iron, other, press, model, first, second, elsewhere] as [any PersistentModel] { context.insert(object) }
        try context.save()

        let service = WorkoutTemplateService(context: context)
        let template = try service.create(name: "Push", items: [TemplateItemDraft(exercise: press, targetRepsBySet: [10])])
        // Two compatible machines and no memory: nothing to resolve to.
        #expect(try service.resolvedMachine(for: press, in: template, at: iron) == nil)

        WorkoutSession(context: context).rememberMachine(second, for: press)
        try context.save()

        #expect(try service.resolvedMachine(for: press, in: template, at: iron)?.id == second.id)
        #expect(try service.resolvedMachine(for: press, in: template, at: other) == nil, "another gym is untouched")
        let workout = try service.start(template, at: iron)
        #expect(workout.entries?.first?.machine?.id == second.id, "the template starts on the picked machine")
    }

    @Test func aLaterPickReplacesTheEarlierOneAndAnArchivedMachineIsIgnored() throws {
        let store = try Store()
        let context = store.context
        let gym = Gym(name: "Iron Temple")
        let press = Exercise(name: "Chest Press", isSeeded: false)
        let a = MachineInstance(label: "A", gym: gym)
        let b = MachineInstance(label: "B", gym: gym)
        for object in [gym, press, a, b] as [any PersistentModel] { context.insert(object) }
        try context.save()
        let session = WorkoutSession(context: context)
        let lifecycle = EquipmentLifecycle(context: context)

        session.rememberMachine(a, for: press, at: Date(timeIntervalSince1970: 1_800_000_000))
        session.rememberMachine(b, for: press, at: Date(timeIntervalSince1970: 1_800_000_100))
        try context.save()
        #expect(try lifecycle.rememberedMachine(for: press, at: gym)?.id == b.id)
        #expect(try context.fetch(FetchDescriptor<GymExerciseMemory>()).count == 1, "one memory row per gym and exercise")

        b.archived = true
        session.rememberMachine(b, for: press)
        try context.save()
        #expect(try lifecycle.rememberedMachine(for: press, at: gym) == nil, "an archived machine is never remembered")
    }

    /// codex-review-23 #3: a template save that fails puts every touched memory row back — an existing row's values
    /// and a newly inserted row alike — so a discarded template changes no gym's machine.
    @Test func undoingStagedPicksRestoresTheGymsMemory() throws {
        let store = try Store()
        let context = store.context
        let gym = Gym(name: "Iron Temple")
        let press = Exercise(name: "Chest Press", isSeeded: false)
        let row = Exercise(name: "Seated Row", isSeeded: false)
        let a = MachineInstance(label: "A", gym: gym)
        let b = MachineInstance(label: "B", gym: gym)
        for object in [gym, press, row, a, b] as [any PersistentModel] { context.insert(object) }
        let earlier = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(GymExerciseMemory(gymID: gym.id, exerciseID: press.id, machineID: a.id, updatedAt: earlier))
        try context.save()
        let lifecycle = EquipmentLifecycle(context: context)

        let undo = WorkoutSession(context: context).stageMachineMemory([(b, press), (a, row)])
        #expect(try lifecycle.rememberedMachine(for: press, at: gym)?.id == b.id, "staged: the pick is in effect")
        #expect(try lifecycle.rememberedMachine(for: row, at: gym)?.id == a.id)
        undo()
        try context.save()

        #expect(try lifecycle.rememberedMachine(for: press, at: gym)?.id == a.id, "the existing row's machine is back")
        #expect(try context.fetch(FetchDescriptor<GymExerciseMemory>()).first { $0.exerciseID == press.id }?.updatedAt == earlier)
        #expect(try lifecycle.rememberedMachine(for: row, at: gym) == nil, "the inserted row is gone")
        #expect(try context.fetch(FetchDescriptor<GymExerciseMemory>()).count == 1)
    }

    /// codex-review-23 #2: a newer pick for the same exercise at the same gym is every such row's choice, so dragging
    /// rows cannot change which machine the template starts on; another gym's choice and another exercise are kept.
    @Test func aNewerPickIsTheChoiceForEveryRowOfThatExerciseAtThatGym() {
        let exercise = UUID(), other = UUID(), iron = UUID(), elsewhere = UUID()
        let a = TemplateEditorSheet.MachineChoice(machineID: UUID(), gymID: iron, caption: "A · Iron")
        let b = TemplateEditorSheet.MachineChoice(machineID: UUID(), gymID: iron, caption: "B · Iron")
        let far = TemplateEditorSheet.MachineChoice(machineID: UUID(), gymID: elsewhere, caption: "C · Elsewhere")
        let items = [
            TemplateEditorSheet.EditorItem(exerciseID: exercise, repsBySet: [10], machine: a),
            TemplateEditorSheet.EditorItem(exerciseID: exercise, repsBySet: [10], machine: far),
            TemplateEditorSheet.EditorItem(exerciseID: other, repsBySet: [10], machine: a),
            TemplateEditorSheet.EditorItem(exerciseID: exercise, repsBySet: [10]),
        ]
        let chosen = TemplateEditorSheet.choosing(b, for: exercise, in: items)
        #expect(chosen.map(\.machine) == [b, far, a, nil])
    }
}
