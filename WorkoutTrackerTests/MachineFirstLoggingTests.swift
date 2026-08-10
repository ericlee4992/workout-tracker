import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 08 — machine-first logging (D7) at the service boundary:
// exercise resolution from the machine's model (single → auto-fill,
// several → restricted chooser, model-less → empty ⇒ full picker),
// persistence of the machine-first entry, and the unchanged exercise-first
// free-weight path including snapshot tag capture (D23).

struct MachineFirstLoggingTests {

    // MARK: Helpers

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("machine-first-test-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// A gym with three machines: a single-exercise model, a multi-exercise
    /// station (two of the three exercises, plus one dangling link), and a
    /// model-less machine.
    private struct Fixture {
        let gym: Gym
        let chestPress: Exercise
        let latPulldown: Exercise
        let seatedRow: Exercise
        let singleMachine: MachineInstance
        let stationMachine: MachineInstance
        let modelLessMachine: MachineInstance
    }

    private func seedFixture(in context: ModelContext) throws -> Fixture {
        let chestPress = Exercise(name: "Seated Chest Press")
        let latPulldown = Exercise(name: "Lat Pulldown")
        let seatedRow = Exercise(name: "Seated Row")
        let singleModel = EquipmentModel(
            manufacturer: "Life Fitness", modelName: "Insignia Chest Press",
            exerciseIDs: [chestPress.id])
        let stationModel = EquipmentModel(
            manufacturer: "Technogym", modelName: "Dual Pulley Station",
            exerciseIDs: [latPulldown.id, seatedRow.id, UUID()]) // last id dangles
        let gym = Gym(name: "Gold's Gym Gangnam", defaultUnit: .kg)
        let singleMachine = MachineInstance(
            label: "Chest Press #1", gym: gym, model: singleModel)
        let stationMachine = MachineInstance(
            label: "Pulley Station", gym: gym, model: stationModel)
        let modelLessMachine = MachineInstance(label: "Mystery Rig", gym: gym)
        for object in [chestPress, latPulldown, seatedRow, singleModel,
                       stationModel, gym, singleMachine, stationMachine,
                       modelLessMachine] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()
        return Fixture(
            gym: gym, chestPress: chestPress, latPulldown: latPulldown,
            seatedRow: seatedRow, singleMachine: singleMachine,
            stationMachine: stationMachine, modelLessMachine: modelLessMachine)
    }

    // MARK: Exercise resolution (D7 branch point)

    /// A single-exercise model resolves to exactly its one exercise — the
    /// auto-fill case, zero extra prompts.
    @Test func singleExerciseMachineResolvesToItsOneExercise() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)

        let linked = try session.exercisesFor(machine: fixture.singleMachine)
        #expect(linked.map(\.id) == [fixture.chestPress.id])
    }

    /// A multi-exercise station lists exactly the model's linked exercises,
    /// in link order — dangling ids drop out, unlinked exercises never appear.
    @Test func multiExerciseStationListsExactlyLinkedExercises() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)

        let linked = try session.exercisesFor(machine: fixture.stationMachine)
        #expect(linked.map(\.id) == [fixture.latPulldown.id, fixture.seatedRow.id])
        #expect(!linked.contains { $0.id == fixture.chestPress.id })
    }

    /// A model-less machine resolves to no exercises — the caller falls back
    /// to the full exercise picker (per ticket 06).
    @Test func modelLessMachineResolvesToEmpty() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)

        #expect(try session.exercisesFor(machine: fixture.modelLessMachine).isEmpty)
    }

    // MARK: Machine-first entry creation

    /// The machine-first add creates an entry carrying both machine and
    /// exercise (plus one draft set on the precedence-chain unit), and it all
    /// survives a store reopen.
    @Test func machineFirstEntryPersistsMachineAndExercise() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        var workoutID = UUID()
        var machineID = UUID()
        var exerciseID = UUID()

        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let fixture = try seedFixture(in: context)
            let session = WorkoutSession(context: context)
            machineID = fixture.singleMachine.id
            exerciseID = fixture.chestPress.id

            let workout = try session.startWorkout(at: fixture.gym)
            workoutID = workout.id
            let exercise = try #require(
                try session.exercisesFor(machine: fixture.singleMachine).first)
            let entry = try session.addEntry(
                machine: fixture.singleMachine, exercise: exercise, to: workout)
            #expect(entry.machine?.id == machineID)
            #expect(entry.exercise?.id == exerciseID)
            #expect(entry.freeWeightTag == nil)
        }()

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let workouts = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt == nil }))
        let workout = try #require(workouts.first { $0.id == workoutID })
        let entry = try #require(WorkoutSession.orderedEntries(of: workout).first)
        #expect(entry.machine?.id == machineID)
        #expect(entry.exercise?.id == exerciseID)
        #expect(entry.freeWeightTag == nil)
        let sets = WorkoutSession.orderedSets(of: entry)
        try #require(sets.count == 1)
        #expect(sets[0].weightUnit == .kg) // gym default via precedence chain
    }

    // MARK: Exercise-first path unaffected

    /// The exercise-first free-weight path still works: entry with a tag and
    /// no machine, tag captured into the snapshot at first completion (D23),
    /// and a later machine pick on a draft entry clears the tag.
    @Test func exerciseFirstFreeWeightPathUnaffected() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)

        let workout = try session.startWorkout(at: fixture.gym)
        let entry = try session.addEntry(
            for: fixture.chestPress, to: workout, freeWeightTag: .dumbbell)
        #expect(entry.machine == nil)
        #expect(entry.freeWeightTag == .dumbbell)

        // Free-weight tag reaches the snapshot at first completion.
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        // A1: a row only completes once it carries weight and reps.
        try session.commitWeight("30", for: set)
        try session.commitReps("10", for: set)
        try session.toggleCompletion(of: set)
        #expect(entry.snapshotFreeWeightTag == .dumbbell)
        #expect(entry.snapshotMachineID == nil)

        // Optional machine pick on a fresh draft entry still edits in place.
        let draft = try session.addEntry(
            for: fixture.chestPress, to: workout, freeWeightTag: .barbell)
        let chosen = try session.chooseEquipment(
            for: draft, machine: fixture.singleMachine, freeWeightTag: nil)
        #expect(chosen.id == draft.id)
        #expect(draft.machine?.id == fixture.singleMachine.id)
        #expect(draft.freeWeightTag == nil)
    }
}
