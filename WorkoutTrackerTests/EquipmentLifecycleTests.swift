import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

struct EquipmentLifecycleTests {
    private struct Fixture {
        let context: ModelContext
        let lifecycle: EquipmentLifecycle
        let gym: Gym
        let exercise: Exercise
        let oldModel: EquipmentModel
        let newModel: EquipmentModel
        let machine: MachineInstance
        let otherMachine: MachineInstance
        let entry: ExerciseEntry
        let otherEntry: ExerciseEntry
    }

    private func makeFixture() throws -> Fixture {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let gym = Gym(name: "Original Gym")
        let exercise = Exercise(name: "Chest Press", isSeeded: false)
        let oldModel = EquipmentModel(
            manufacturer: "OldCo", modelName: "Press A",
            exerciseIDs: [exercise.id], isSeeded: false)
        let newModel = EquipmentModel(
            manufacturer: "NewCo", modelName: "Press B",
            exerciseIDs: [exercise.id], isSeeded: false)
        let machine = MachineInstance(label: "Machine One", gym: gym, model: oldModel)
        let otherMachine = MachineInstance(label: "Machine Two", gym: gym, model: oldModel)
        for object in [gym, exercise, oldModel, newModel, machine, otherMachine]
            as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()

        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: gym)
        let entry = try session.addEntry(for: exercise, to: workout, machine: machine)
        let otherEntry = try session.addEntry(for: exercise, to: workout, machine: otherMachine)
        for (index, loggedEntry) in [entry, otherEntry].enumerated() {
            let set = try #require(WorkoutSession.orderedSets(of: loggedEntry).first)
            try session.commitWeight("60", for: set)
            try session.commitReps("10", for: set)
            try session.toggleCompletion(
                of: set,
                at: Date(timeIntervalSince1970: TimeInterval(100 + index)))
        }
        try session.finish(workout)

        return Fixture(
            context: context, lifecycle: EquipmentLifecycle(context: context), gym: gym,
            exercise: exercise, oldModel: oldModel, newModel: newModel,
            machine: machine, otherMachine: otherMachine,
            entry: entry, otherEntry: otherEntry)
    }

    @Test func gymRenameChangesLiveRowButNotHistorySnapshot() throws {
        let f = try makeFixture()
        let snapshotID = f.entry.snapshotGymID
        let display = f.entry.snapshotGymName
        try f.lifecycle.rename(f.gym, to: "Renamed Gym")
        #expect(f.gym.name == "Renamed Gym")
        #expect(f.entry.snapshotGymID == snapshotID)
        #expect(f.entry.snapshotGymName == display)
    }

    @Test func machineRenameChangesLiveRowButNotHistorySnapshot() throws {
        let f = try makeFixture()
        let snapshotID = f.entry.snapshotMachineID
        let display = f.entry.snapshotEquipmentLabel
        try f.lifecycle.rename(f.machine, to: "Renamed Machine")
        #expect(f.machine.label == "Renamed Machine")
        #expect(f.entry.snapshotMachineID == snapshotID)
        #expect(f.entry.snapshotEquipmentLabel == display)
    }

    @Test func modelRenameChangesLiveRowButNotHistorySnapshot() throws {
        let f = try makeFixture()
        let snapshotID = f.entry.snapshotModelID
        let display = f.entry.snapshotEquipmentLabel
        try f.lifecycle.rename(f.oldModel, manufacturer: "RenamedCo", modelName: "Press X")
        #expect(f.oldModel.displayName == "RenamedCo Press X")
        #expect(f.entry.snapshotModelID == snapshotID)
        #expect(f.entry.snapshotEquipmentLabel == display)
    }

    /// D2 (ticket 17): a gym's unit and city are corrections, not one-shot
    /// choices — a wrong unit used to mean archive-and-recreate. History
    /// still reads its snapshot.
    @Test func gymUpdateEditsUnitAndCityWithoutTouchingHistory() throws {
        let f = try makeFixture()
        let snapshotName = f.entry.snapshotGymName
        try f.lifecycle.update(
            f.gym, name: "Corrected Gym", city: "Seoul", defaultUnit: .lb)
        #expect(f.gym.name == "Corrected Gym")
        #expect(f.gym.city == "Seoul")
        #expect(f.gym.defaultUnit == .lb)
        #expect(f.entry.snapshotGymName == snapshotName)

        // Blank city clears it; a blank name is still refused.
        try f.lifecycle.update(
            f.gym, name: "Corrected Gym", city: "  ", defaultUnit: nil)
        #expect(f.gym.city == nil)
        #expect(f.gym.defaultUnit == nil)
        #expect(throws: EquipmentLifecycleError.emptyName) {
            try f.lifecycle.update(f.gym, name: " ", city: nil, defaultUnit: .kg)
        }
    }

    /// D2: a machine's default unit is editable too, and editing it never
    /// touches the model (that correction has its own past-vs-future flow).
    @Test func machineUpdateEditsLabelAndUnitButNotModel() throws {
        let f = try makeFixture()
        try f.lifecycle.update(f.machine, label: "Corrected Machine", defaultUnit: .lb)
        #expect(f.machine.label == "Corrected Machine")
        #expect(f.machine.defaultUnit == .lb)
        #expect(f.machine.model?.id == f.oldModel.id)
        #expect(throws: EquipmentLifecycleError.emptyName) {
            try f.lifecycle.update(f.machine, label: "", defaultUnit: .kg)
        }
    }

    @Test func archivesHideRowsWithoutChangingHistory() throws {
        let f = try makeFixture()
        let machineSnapshotID = f.entry.snapshotMachineID
        let gymSnapshotID = f.entry.snapshotGymID
        let display = f.entry.snapshotEquipmentLabel
        try f.lifecycle.archive(f.machine)
        try f.lifecycle.archive(f.gym)
        #expect(f.machine.archived)
        #expect(f.gym.archived)
        #expect(f.entry.snapshotMachineID == machineSnapshotID)
        #expect(f.entry.snapshotGymID == gymSnapshotID)
        #expect(f.entry.snapshotEquipmentLabel == display)
    }

    /// Ticket 10: pickers offer active machines at an active gym only. Every
    /// machine list (equipment picker, add-by-machine, gym detail) reads this
    /// one property, so archiving is honoured identically in all of them.
    @Test func archivedGymOffersNoMachinesToPickers() throws {
        let f = try makeFixture()
        #expect(f.gym.activeMachines.map(\.label) == ["Machine One", "Machine Two"])

        try f.lifecycle.archive(f.machine)
        #expect(f.gym.activeMachines.map(\.label) == ["Machine Two"])

        try f.lifecycle.archive(f.gym)
        #expect(f.gym.activeMachines.isEmpty)
        // The machines themselves are untouched — only the gym was archived.
        #expect(f.otherMachine.archived == false)
    }

    /// Machine deletion (2026-09-10): "Delete" is archival (D10), and the
    /// gym's deleted list restores the SAME machine — id, model, label and the
    /// snapshots that reference it are all untouched either way.
    @Test func deletingIsArchivalAndRestoreBringsTheSameMachineBack() throws {
        let f = try makeFixture()
        let id = f.machine.id
        let presetID = UUID()
        f.machine.defaultUnit = .lb
        f.machine.defaultPresetID = presetID
        try f.context.save()
        let snapshotID = f.entry.snapshotMachineID
        let snapshotLabel = f.entry.snapshotEquipmentLabel
        let snapshotModelID = f.entry.snapshotModelID
        #expect(f.gym.archivedMachines.isEmpty)

        try f.lifecycle.archive(f.machine)
        #expect(f.gym.activeMachines.map(\.label) == ["Machine Two"])
        #expect(f.gym.archivedMachines.map(\.label) == ["Machine One"])
        #expect(f.entry.snapshotMachineID == snapshotID, "history keeps the deleted machine")

        try f.lifecycle.restore(f.machine)
        #expect(f.machine.archived == false)
        #expect(f.machine.id == id)
        #expect(f.machine.model === f.oldModel)
        #expect(f.machine.label == "Machine One")
        #expect(f.machine.defaultUnit == .lb, "the machine's own unit survives")
        #expect(f.machine.defaultPresetID == presetID, "and its usual preset (D38)")
        #expect(f.gym.activeMachines.map(\.label) == ["Machine One", "Machine Two"])
        #expect(f.gym.archivedMachines.isEmpty)
        #expect(f.entry.machine === f.machine, "the live relationship survived the round trip")
        #expect(f.entry.snapshotMachineID == snapshotID)
        #expect(f.entry.snapshotEquipmentLabel == snapshotLabel)
        #expect(f.entry.snapshotModelID == snapshotModelID, "no snapshot field moved either way (D23)")
    }

    @Test func futureOnlyCorrectionKeepsHistoricalModelLayer() throws {
        let f = try makeFixture()
        let oldID = f.oldModel.id
        let oldDisplay = f.entry.snapshotEquipmentLabel
        try f.lifecycle.correctModel(of: f.machine, to: f.newModel, scope: .futureOnly)
        #expect(f.machine.model?.id == f.newModel.id)
        #expect(f.entry.snapshotModelID == oldID)
        #expect(f.entry.snapshotEquipmentLabel == oldDisplay)
    }

    @Test func applyToPastCorrectionRewritesOnlyChosenMachinesSnapshots() throws {
        let f = try makeFixture()
        let oldID = f.oldModel.id
        try f.lifecycle.correctModel(of: f.machine, to: f.newModel, scope: .applyToPast)
        #expect(f.machine.model?.id == f.newModel.id)
        #expect(f.entry.snapshotMachineID == f.machine.id)
        #expect(f.entry.snapshotModelID == f.newModel.id)
        #expect(f.entry.snapshotModelName == f.newModel.displayName)
        #expect(f.otherEntry.snapshotMachineID == f.otherMachine.id)
        #expect(f.otherEntry.snapshotModelID == oldID)
        #expect(f.otherEntry.snapshotModelName == "OldCo Press A")
    }

    @Test func archivedEquipmentNeverResolvesFromMemory() throws {
        let f = try makeFixture()
        #expect(try f.lifecycle.rememberedMachine(for: f.exercise, at: f.gym)?.id == f.otherMachine.id)
        try f.lifecycle.archive(f.otherMachine)
        #expect(try f.lifecycle.rememberedMachine(for: f.exercise, at: f.gym) == nil)

        // A different active remembered machine is also ignored once its gym
        // is archived.
        let memory = try #require(try f.context.fetch(FetchDescriptor<GymExerciseMemory>()).first)
        memory.machineID = f.machine.id
        f.machine.archived = false
        try f.context.save()
        try f.lifecycle.archive(f.gym)
        #expect(try f.lifecycle.rememberedMachine(for: f.exercise, at: f.gym) == nil)
    }

    @Test func seededCatalogRowsRejectRename() throws {
        let f = try makeFixture()
        let seededModel = EquipmentModel(
            manufacturer: "SeedCo", modelName: "Locked", isSeeded: true)
        let seededExercise = Exercise(name: "Locked Exercise", isSeeded: true)
        f.context.insert(seededModel)
        f.context.insert(seededExercise)
        try f.context.save()

        #expect(throws: EquipmentLifecycleError.seededCatalogRowIsReadOnly) {
            try f.lifecycle.rename(seededModel, manufacturer: "Nope", modelName: "Nope")
        }
        #expect(throws: EquipmentLifecycleError.seededCatalogRowIsReadOnly) {
            try f.lifecycle.rename(seededExercise, to: "Nope")
        }
        #expect(seededModel.displayName == "SeedCo Locked")
        #expect(seededExercise.name == "Locked Exercise")
    }
}
