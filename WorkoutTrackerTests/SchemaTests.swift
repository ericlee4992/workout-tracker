import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 02 — SwiftData schema tests: round-trip persistence, archival
// semantics, and CloudKit schema rules.

struct SchemaTests {

    // MARK: Helpers

    /// A fresh on-disk store URL in the test sandbox's temp directory.
    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-test-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    private func fetchOne<T: PersistentModel>(
        _ type: T.Type, id: UUID, in context: ModelContext,
        matching predicate: Predicate<T>
    ) throws -> T {
        let results = try context.fetch(FetchDescriptor<T>(predicate: predicate))
        try #require(results.count == 1, "expected exactly one \(T.self) with id \(id)")
        return results[0]
    }

    // MARK: Round-trip

    /// Builds a full object graph, saves it to an on-disk store, releases the
    /// container, reopens the SAME store with a NEW container, refetches, and
    /// asserts field-by-field equality.
    @Test func roundTripThroughFreshContainer() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        // Fixed values so equality checks are exact.
        let exerciseID = UUID()
        let modelID = UUID()
        let gymID = UUID()
        let machineID = UUID()
        let templateID = UUID()
        let itemID = UUID()
        let workoutID = UUID()
        let entryID = UUID()
        let set1ID = UUID()
        let set2ID = UUID()
        let memoryID = UUID()
        let prefsID = UUID()
        let overrideID = UUID()
        let startedAt = Date(timeIntervalSinceReferenceDate: 760_000_000)
        let finishedAt = startedAt.addingTimeInterval(3_600)
        let restEndsAt = startedAt.addingTimeInterval(1_800)
        let completedAt = startedAt.addingTimeInterval(300)
        let updatedAt = Date(timeIntervalSinceReferenceDate: 760_100_000)

        // Seed in a scoped container that is fully released before reopening.
        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)

            let exercise = Exercise(
                id: exerciseID, name: "Seated Chest Press", loadType: .weighted,
                equipmentTypeTags: [.machine, .cable], muscleGroup: "Chest",
                isSeeded: true)
            let model = EquipmentModel(
                id: modelID, manufacturer: "Life Fitness",
                modelName: "Insignia Chest Press", exerciseIDs: [exerciseID],
                isSeeded: true)
            let gym = Gym(
                id: gymID, name: "Gold's Gym Gangnam", city: "Seoul",
                defaultUnit: .kg, notes: "3rd floor", archived: false)
            let machine = MachineInstance(
                id: machineID, label: "Chest Press #1", defaultUnit: .lb,
                archived: false, gym: gym, model: model)
            let template = WorkoutTemplate(id: templateID, name: "Push Day")
            let item = TemplateItem(
                id: itemID, order: 0, targetSets: 3, targetReps: 10,
                exercise: exercise)
            item.template = template

            let workout = Workout(
                id: workoutID, startedAt: startedAt, finishedAt: finishedAt,
                notes: "Felt strong", sourceTemplateID: templateID,
                restEndsAt: restEndsAt, gym: gym)
            let entry = ExerciseEntry(
                id: entryID, order: 0, freeWeightTag: nil, workout: workout,
                exercise: exercise, machine: machine,
                snapshotExerciseID: exerciseID, snapshotMachineID: machineID,
                snapshotModelID: modelID, snapshotGymID: gymID,
                snapshotLoadType: .weighted, snapshotFreeWeightTag: nil,
                snapshotExerciseName: "Seated Chest Press",
                snapshotMachineLabel: "Chest Press #1",
                snapshotModelName: "Life Fitness Insignia Chest Press",
                snapshotGymName: "Gold's Gym Gangnam")
            let completedSet = SetRecord(
                id: set1ID, order: 0, type: .warmup, reps: 12, weightValue: 40,
                weightUnit: .kg, normalizedKg: 40, completedAt: completedAt,
                entry: entry)
            let draftSet = SetRecord(
                id: set2ID, order: 1, type: .working, reps: nil,
                weightValue: nil, weightUnit: .kg, normalizedKg: nil,
                completedAt: nil, entry: entry)

            let memory = GymExerciseMemory(
                id: memoryID, gymID: gymID, exerciseID: exerciseID,
                machineID: machineID, updatedAt: updatedAt)
            let prefs = AppPreferences(
                id: prefsID, unitPreference: .kg, driftPromptSuppressed: true,
                globalWorkingRestSeconds: 150, globalWarmupRestSeconds: 90,
                seededCatalogVersion: 3, notificationPermissionRequested: true,
                updatedAt: updatedAt)
            let restOverride = ExerciseRestOverride(
                id: overrideID, exerciseID: exerciseID, workingRestSeconds: 180,
                warmupRestSeconds: nil, updatedAt: updatedAt)

            for object in [
                exercise, model, gym, machine, template, item, workout, entry,
                completedSet, draftSet, memory, prefs, restOverride,
            ] as [any PersistentModel] {
                context.insert(object)
            }
            try context.save()
        }()

        // Reopen the same file with a brand-new container and refetch.
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)

        let exercise = try fetchOne(
            Exercise.self, id: exerciseID, in: context,
            matching: #Predicate { $0.id == exerciseID })
        #expect(exercise.name == "Seated Chest Press")
        #expect(exercise.loadType == .weighted)
        #expect(exercise.equipmentTypeTags == [.machine, .cable])
        #expect(exercise.muscleGroup == "Chest")
        #expect(exercise.isSeeded == true)

        let model = try fetchOne(
            EquipmentModel.self, id: modelID, in: context,
            matching: #Predicate { $0.id == modelID })
        #expect(model.manufacturer == "Life Fitness")
        #expect(model.modelName == "Insignia Chest Press")
        #expect(model.exerciseIDs == [exerciseID])
        #expect(model.isSeeded == true)

        let gym = try fetchOne(
            Gym.self, id: gymID, in: context,
            matching: #Predicate { $0.id == gymID })
        #expect(gym.name == "Gold's Gym Gangnam")
        #expect(gym.city == "Seoul")
        #expect(gym.defaultUnit == .kg)
        #expect(gym.notes == "3rd floor")
        #expect(gym.archived == false)

        let machine = try fetchOne(
            MachineInstance.self, id: machineID, in: context,
            matching: #Predicate { $0.id == machineID })
        #expect(machine.label == "Chest Press #1")
        #expect(machine.defaultUnit == .lb)
        #expect(machine.archived == false)
        #expect(machine.gym?.id == gymID)
        #expect(machine.model?.id == modelID)

        let template = try fetchOne(
            WorkoutTemplate.self, id: templateID, in: context,
            matching: #Predicate { $0.id == templateID })
        #expect(template.name == "Push Day")
        let items = try #require(template.items)
        try #require(items.count == 1)
        #expect(items[0].id == itemID)
        #expect(items[0].order == 0)
        #expect(items[0].targetSets == 3)
        #expect(items[0].targetReps == 10)
        #expect(items[0].exercise?.id == exerciseID)

        let workout = try fetchOne(
            Workout.self, id: workoutID, in: context,
            matching: #Predicate { $0.id == workoutID })
        #expect(workout.startedAt == startedAt)
        #expect(workout.finishedAt == finishedAt)
        #expect(workout.notes == "Felt strong")
        #expect(workout.sourceTemplateID == templateID)
        #expect(workout.restEndsAt == restEndsAt)
        #expect(workout.gym?.id == gymID)

        let entries = try #require(workout.entries)
        try #require(entries.count == 1)
        let entry = entries[0]
        #expect(entry.id == entryID)
        #expect(entry.order == 0)
        #expect(entry.freeWeightTag == nil)
        #expect(entry.exercise?.id == exerciseID)
        #expect(entry.machine?.id == machineID)
        #expect(entry.snapshotExerciseID == exerciseID)
        #expect(entry.snapshotMachineID == machineID)
        #expect(entry.snapshotModelID == modelID)
        #expect(entry.snapshotGymID == gymID)
        #expect(entry.snapshotLoadType == .weighted)
        #expect(entry.snapshotFreeWeightTag == nil)
        #expect(entry.snapshotExerciseName == "Seated Chest Press")
        #expect(entry.snapshotMachineLabel == "Chest Press #1")
        #expect(entry.snapshotModelName == "Life Fitness Insignia Chest Press")
        #expect(entry.snapshotGymName == "Gold's Gym Gangnam")

        let sets = try #require(entry.sets).sorted { $0.order < $1.order }
        try #require(sets.count == 2)
        #expect(sets[0].id == set1ID)
        #expect(sets[0].order == 0)
        #expect(sets[0].type == .warmup)
        #expect(sets[0].reps == 12)
        #expect(sets[0].weightValue == 40)
        #expect(sets[0].weightUnit == .kg)
        #expect(sets[0].normalizedKg == 40)
        #expect(sets[0].completedAt == completedAt)
        // Draft set: value fields stay nil until completed.
        #expect(sets[1].id == set2ID)
        #expect(sets[1].order == 1)
        #expect(sets[1].type == .working)
        #expect(sets[1].reps == nil)
        #expect(sets[1].weightValue == nil)
        #expect(sets[1].weightUnit == .kg)
        #expect(sets[1].normalizedKg == nil)
        #expect(sets[1].completedAt == nil)

        let memory = try fetchOne(
            GymExerciseMemory.self, id: memoryID, in: context,
            matching: #Predicate { $0.id == memoryID })
        #expect(memory.gymID == gymID)
        #expect(memory.exerciseID == exerciseID)
        #expect(memory.machineID == machineID)
        #expect(memory.updatedAt == updatedAt)

        let prefs = try fetchOne(
            AppPreferences.self, id: prefsID, in: context,
            matching: #Predicate { $0.id == prefsID })
        #expect(prefs.unitPreference == .kg)
        #expect(prefs.driftPromptSuppressed == true)
        #expect(prefs.globalWorkingRestSeconds == 150)
        #expect(prefs.globalWarmupRestSeconds == 90)
        #expect(prefs.seededCatalogVersion == 3)
        #expect(prefs.notificationPermissionRequested == true)
        #expect(prefs.updatedAt == updatedAt)

        let restOverride = try fetchOne(
            ExerciseRestOverride.self, id: overrideID, in: context,
            matching: #Predicate { $0.id == overrideID })
        #expect(restOverride.exerciseID == exerciseID)
        #expect(restOverride.workingRestSeconds == 180)
        #expect(restOverride.warmupRestSeconds == nil)
        #expect(restOverride.updatedAt == updatedAt)
    }

    // MARK: Archival

    /// Gyms and machines are archived by flag, never deleted; archiving leaves
    /// workout history completely untouched. Even a hard delete (not used by
    /// the app for archival) must nullify, not cascade into history.
    @Test func archivalUsesFlagsAndNeverTouchesHistory() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        let gymID = UUID()
        let machineID = UUID()
        let workoutID = UUID()

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)

        let gym = Gym(id: gymID, name: "Old Gym", defaultUnit: .kg)
        let machine = MachineInstance(id: machineID, label: "Row #1", gym: gym)
        let workout = Workout(id: workoutID, startedAt: .now, finishedAt: .now, gym: gym)
        let entry = ExerciseEntry(
            id: UUID(), order: 0, workout: workout, machine: machine,
            snapshotExerciseID: UUID(), snapshotMachineID: machineID,
            snapshotGymID: gymID, snapshotLoadType: .weighted,
            snapshotExerciseName: "Seated Row",
            snapshotMachineLabel: "Row #1", snapshotGymName: "Old Gym")
        let set = SetRecord(
            id: UUID(), order: 0, type: .working, reps: 10, weightValue: 50,
            weightUnit: .kg, normalizedKg: 50, completedAt: .now, entry: entry)
        context.insert(gym)
        context.insert(machine)
        context.insert(workout)
        context.insert(entry)
        context.insert(set)
        try context.save()

        // Archive: set flags — no deletion involved.
        gym.archived = true
        machine.archived = true
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MachineInstance>()) == 1)
        let archivedGym = try fetchOne(
            Gym.self, id: gymID, in: context,
            matching: #Predicate { $0.id == gymID })
        #expect(archivedGym.archived == true)
        let archivedMachine = try fetchOne(
            MachineInstance.self, id: machineID, in: context,
            matching: #Predicate { $0.id == machineID })
        #expect(archivedMachine.archived == true)

        // History side is untouched: counts, live links, and snapshots intact.
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == 1)
        #expect(entry.machine?.id == machineID)
        #expect(workout.gym?.id == gymID)

        // Safety net: even hard-deleting gym + machine must not cascade into
        // history — relationships nullify and snapshots keep resolving.
        context.delete(machine)
        context.delete(gym)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == 1)
        let survivingWorkout = try fetchOne(
            Workout.self, id: workoutID, in: context,
            matching: #Predicate { $0.id == workoutID })
        #expect(survivingWorkout.gym == nil)
        let survivingEntry = try #require(survivingWorkout.entries?.first)
        #expect(survivingEntry.machine == nil)
        #expect(survivingEntry.snapshotMachineID == machineID)
        #expect(survivingEntry.snapshotGymID == gymID)
        #expect(survivingEntry.snapshotMachineLabel == "Row #1")
        #expect(survivingEntry.snapshotGymName == "Old Gym")
    }

    // MARK: Schema rules

    /// CloudKit rule: every relationship is optional. Assigning nil to each
    /// relationship property only compiles if the property is Optional, so
    /// this test is the compile-time proof; it also sanity-checks the schema
    /// builds and covers every model type.
    @Test func allRelationshipsAreOptional() throws {
        let exercise = Exercise(name: "X")
        exercise.entries = nil
        exercise.templateItems = nil

        let model = EquipmentModel(manufacturer: "M", modelName: "N")
        model.machines = nil

        let gym = Gym(name: "G")
        gym.machines = nil
        gym.workouts = nil

        let machine = MachineInstance(label: "L")
        machine.gym = nil
        machine.model = nil
        machine.entries = nil

        let template = WorkoutTemplate(name: "T")
        template.items = nil

        let item = TemplateItem(order: 0)
        item.template = nil
        item.exercise = nil

        let workout = Workout()
        workout.gym = nil
        workout.entries = nil

        let entry = ExerciseEntry(
            order: 0, snapshotExerciseID: UUID(), snapshotLoadType: .weighted,
            snapshotExerciseName: "X")
        entry.workout = nil
        entry.exercise = nil
        entry.machine = nil
        entry.sets = nil

        let set = SetRecord(order: 0)
        set.entry = nil

        // GymExerciseMemory, AppPreferences, and ExerciseRestOverride hold
        // scalar ids only — no relationships by design.

        // The full schema builds and includes every model.
        let schema = WorkoutTrackerStore.schema
        #expect(schema.entities.count == WorkoutTrackerStore.modelTypes.count)
    }
}
