import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 07 — core logging loop: durability of every mutation across a store
// reopen (ticket 02 pattern), the exactly-one-active-workout invariant,
// finish cleanup, cancel cascade, equipment freeze / draft-row moves (D19),
// snapshot capture (D23), memory upsert dedupe, and unit-default precedence.

struct WorkoutSessionTests {

    // MARK: Helpers

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("session-test-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// Standard fixture: a gym (kg default) with two machines on distinct
    /// models, and a weighted exercise.
    private struct Fixture {
        let gymID: UUID
        let machine1ID: UUID
        let machine2ID: UUID
        let model1ID: UUID
        let model2ID: UUID
        let exerciseID: UUID
    }

    private func seedFixture(in context: ModelContext) throws -> Fixture {
        let exercise = Exercise(name: "Seated Chest Press", loadType: .weighted)
        let model1 = EquipmentModel(
            manufacturer: "Life Fitness", modelName: "Insignia Chest Press",
            exerciseIDs: [exercise.id])
        let model2 = EquipmentModel(
            manufacturer: "Hammer Strength", modelName: "MTS Chest Press",
            exerciseIDs: [exercise.id])
        let gym = Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg)
        let machine1 = MachineInstance(
            label: "Chest Press #1", gym: gym, model: model1)
        let machine2 = MachineInstance(
            label: "Chest Press #2", gym: gym, model: model2)
        for object in [exercise, model1, model2, gym, machine1, machine2]
            as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()
        return Fixture(
            gymID: gym.id, machine1ID: machine1.id, machine2ID: machine2.id,
            model1ID: model1.id, model2ID: model2.id, exerciseID: exercise.id)
    }

    private func fetchWorkout(_ id: UUID, in context: ModelContext) throws -> Workout {
        let results = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.id == id }))
        try #require(results.count == 1)
        return results[0]
    }

    // MARK: Recovery of every mutation

    /// Add/delete/reorder entry and add/delete set all survive a container
    /// teardown and reopen — each boundary saved by the service.
    @Test func recoveryCoversEntryAndSetStructureMutations() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        var workoutID = UUID()
        var keptEntryID = UUID()
        var movedEntryID = UUID()
        var extraSetID = UUID()

        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let fixture = try seedFixture(in: context)
            let session = WorkoutSession(context: context)
            let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
            let exercise = try #require(try context.fetch(
                FetchDescriptor<Exercise>(
                    predicate: #Predicate { $0.isSeeded == false })).first)
            _ = fixture

            let workout = try session.startWorkout(at: gym)
            workoutID = workout.id

            // add entry ×3
            let first = try session.addEntry(for: exercise, to: workout)
            let second = try session.addEntry(for: exercise, to: workout)
            let third = try session.addEntry(for: exercise, to: workout)
            keptEntryID = first.id
            movedEntryID = third.id

            // add set, delete set
            let extraSet = try session.addSet(to: first)
            extraSetID = extraSet.id
            let doomedSet = try session.addSet(to: first)
            try session.deleteSet(doomedSet)

            // delete entry
            try session.deleteEntry(second)

            // reorder: third moves to the front
            try session.moveEntry(third, toIndex: 0)
        }()

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let workout = try fetchWorkout(workoutID, in: context)
        let entries = WorkoutSession.orderedEntries(of: workout)
        try #require(entries.count == 2)
        #expect(entries[0].id == movedEntryID)
        #expect(entries[1].id == keptEntryID)
        #expect(entries.map(\.order) == [0, 1])

        let sets = WorkoutSession.orderedSets(of: entries[1])
        try #require(sets.count == 2)
        #expect(sets[1].id == extraSetID)
        #expect(sets.map(\.order) == [0, 1])
    }

    /// Weight/reps commit, unit toggle, set-type cycle, completion, equipment
    /// choice, and notes all survive a reopen.
    @Test func recoveryCoversFieldCommitsCompletionEquipmentAndNotes() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        var workoutID = UUID()
        var fixture: Fixture!
        let completedAt = Date(timeIntervalSinceReferenceDate: 761_000_000)

        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            fixture = try seedFixture(in: context)
            let session = WorkoutSession(context: context)
            let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
            let exercise = try #require(try context.fetch(
                FetchDescriptor<Exercise>(
                    predicate: #Predicate { $0.isSeeded == false })).first)

            let workout = try session.startWorkout(at: gym)
            workoutID = workout.id
            let entry = try session.addEntry(for: exercise, to: workout)

            // equipment choice (draft entry → edited in place)
            let machineID = fixture.machine1ID
            let machine = try #require(try context.fetch(
                FetchDescriptor<MachineInstance>(
                    predicate: #Predicate { $0.id == machineID })).first)
            try session.chooseEquipment(for: entry, machine: machine, freeWeightTag: nil)

            let set = try #require(WorkoutSession.orderedSets(of: entry).first)
            try session.commitWeight("60", for: set)
            try session.commitReps("10", for: set)
            try session.toggleUnit(of: set) // kg → lb, value stays 60 as entered
            try session.cycleSetType(set)   // working → warmup
            try session.toggleCompletion(of: set, at: completedAt)
            try session.commitNotes("Felt strong", for: workout)
        }()

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let workout = try fetchWorkout(workoutID, in: context)
        #expect(workout.notes == "Felt strong")
        let entry = try #require(WorkoutSession.orderedEntries(of: workout).first)
        #expect(entry.machine?.id == fixture.machine1ID)
        #expect(entry.freeWeightTag == nil)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        #expect(set.weightValue == 60)
        #expect(set.weightUnit == .lb)
        #expect(set.normalizedKg == 60 * WeightMath.kilogramsPerPound)
        #expect(set.reps == 10)
        #expect(set.type == .warmup)
        #expect(set.completedAt == completedAt)
        // Snapshot captured on the first completion (D23).
        #expect(entry.snapshotCapturedAt == completedAt)
        #expect(entry.snapshotExerciseID == fixture.exerciseID)
        #expect(entry.snapshotMachineID == fixture.machine1ID)
        #expect(entry.snapshotModelID == fixture.model1ID)
        #expect(entry.snapshotGymID == fixture.gymID)
        #expect(entry.snapshotLoadType == .weighted)
        #expect(entry.snapshotFreeWeightTag == nil)
        #expect(entry.snapshotExerciseName == "Seated Chest Press")
        #expect(entry.snapshotMachineLabel == "Chest Press #1")
        #expect(entry.snapshotModelName == "Life Fitness Insignia Chest Press")
        #expect(entry.snapshotGymName == "Gold's Gym Gangnam")
    }

    // MARK: Exactly-one-active invariant

    /// Relaunch resumes the newest active workout; older strays are
    /// auto-finished with `finishedAt` stamped and finish cleanup applied.
    @Test func recoveryResumesNewestActiveAndAutoFinishesStrays() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        let base = Date(timeIntervalSinceReferenceDate: 761_000_000)
        var newestID = UUID()
        var strayID = UUID()
        var finishedID = UUID()

        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let exercise = Exercise(name: "Squat")
            context.insert(exercise)

            let stray = Workout(startedAt: base)
            let newest = Workout(startedAt: base.addingTimeInterval(3_600))
            let finished = Workout(
                startedAt: base.addingTimeInterval(-7_200),
                finishedAt: base.addingTimeInterval(-3_600))
            strayID = stray.id
            newestID = newest.id
            finishedID = finished.id
            // The stray carries one completed set and one draft — cleanup
            // must keep only the completed one.
            let entry = ExerciseEntry(
                order: 0, workout: stray, exercise: exercise,
                snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
                snapshotExerciseName: exercise.name)
            let done = SetRecord(
                order: 0, reps: 5, weightValue: 100, weightUnit: .kg,
                normalizedKg: 100, completedAt: base, entry: entry)
            let draft = SetRecord(order: 1, entry: entry)
            for object in [stray, newest, finished, entry, done, draft]
                as [any PersistentModel] {
                context.insert(object)
            }
            try context.save()
        }()

        // "Relaunch": reopen the store and recover.
        let recoveredAt = base.addingTimeInterval(10_000)
        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let session = WorkoutSession(context: context)
            let resumed = try #require(try session.resumableWorkout(at: recoveredAt))
            #expect(resumed.id == newestID)
        }()

        // Reopen once more: the auto-finish itself must have persisted.
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let newest = try fetchWorkout(newestID, in: context)
        #expect(newest.finishedAt == nil)
        let stray = try fetchWorkout(strayID, in: context)
        #expect(stray.finishedAt == recoveredAt)
        let strayEntry = try #require(stray.entries?.first)
        let straySets = try #require(strayEntry.sets)
        try #require(straySets.count == 1)
        #expect(straySets[0].completedAt != nil)
        let finished = try fetchWorkout(finishedID, in: context)
        #expect(finished.finishedAt == base.addingTimeInterval(-3_600))
        // Exactly one active workout remains.
        let active = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt == nil }))
        #expect(active.map(\.id) == [newestID])
    }

    /// Starting a new workout while one is active (the UI's
    /// finish-and-start-new path) finishes the old one first — the invariant
    /// holds at the service boundary.
    @Test func startWorkoutFinishesLingeringActives() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let session = WorkoutSession(context: context)

        let old = try session.startWorkout(at: nil)
        let new = try session.startWorkout(
            at: nil, on: old.startedAt.addingTimeInterval(60))
        #expect(old.finishedAt != nil)
        #expect(new.finishedAt == nil)
        let active = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt == nil }))
        #expect(active.map(\.id) == [new.id])
    }

    // MARK: Equipment freeze (D19)

    /// After one completed set the equipment is frozen: switching machines
    /// creates a NEW entry ordered right after; uncompleted draft rows move
    /// over (values intact), completed sets and the old snapshot stay.
    @Test func switchAfterCompletionSplitsEntryAndMovesDrafts() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        var workoutID = UUID()
        var oldEntryID = UUID()
        var newEntryID = UUID()
        var fixture: Fixture!

        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            fixture = try seedFixture(in: context)
            let session = WorkoutSession(context: context)
            let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
            let exercise = try #require(try context.fetch(
                FetchDescriptor<Exercise>(
                    predicate: #Predicate { $0.isSeeded == false })).first)
            let machine1ID = fixture.machine1ID
            let machine2ID = fixture.machine2ID
            let machine1 = try #require(try context.fetch(
                FetchDescriptor<MachineInstance>(
                    predicate: #Predicate { $0.id == machine1ID })).first)
            let machine2 = try #require(try context.fetch(
                FetchDescriptor<MachineInstance>(
                    predicate: #Predicate { $0.id == machine2ID })).first)

            let workout = try session.startWorkout(at: gym)
            workoutID = workout.id
            let entry = try session.addEntry(
                for: exercise, to: workout, machine: machine1)
            oldEntryID = entry.id

            let set1 = try #require(WorkoutSession.orderedSets(of: entry).first)
            try session.commitWeight("60", for: set1)
            try session.commitReps("10", for: set1)
            try session.toggleCompletion(of: set1)

            // Two draft rows with in-progress values.
            let set2 = try session.addSet(to: entry)
            try session.commitWeight("62.5", for: set2)
            let set3 = try session.addSet(to: entry)
            try session.commitReps("8", for: set3)

            let result = try session.chooseEquipment(
                for: entry, machine: machine2, freeWeightTag: nil)
            newEntryID = result.id
            #expect(result.id != entry.id)
        }()

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let workout = try fetchWorkout(workoutID, in: context)
        let entries = WorkoutSession.orderedEntries(of: workout)
        try #require(entries.count == 2)
        let old = entries[0]
        let new = entries[1]
        #expect(old.id == oldEntryID)
        #expect(new.id == newEntryID)

        // Old entry: untouched — machine 1, snapshot intact, completed set stays.
        #expect(old.machine?.id == fixture.machine1ID)
        #expect(old.snapshotMachineID == fixture.machine1ID)
        #expect(old.snapshotModelID == fixture.model1ID)
        #expect(old.snapshotMachineLabel == "Chest Press #1")
        #expect(old.snapshotCapturedAt != nil)
        let oldSets = WorkoutSession.orderedSets(of: old)
        try #require(oldSets.count == 1)
        #expect(oldSets[0].completedAt != nil)
        #expect(oldSets[0].weightValue == 60)

        // New entry: machine 2, unfrozen, draft rows moved with values intact.
        #expect(new.machine?.id == fixture.machine2ID)
        #expect(new.snapshotCapturedAt == nil)
        let newSets = WorkoutSession.orderedSets(of: new)
        try #require(newSets.count == 2)
        #expect(newSets.allSatisfy { $0.completedAt == nil })
        #expect(newSets[0].weightValue == 62.5)
        #expect(newSets[1].reps == 8)
        #expect(newSets.map(\.order) == [0, 1])
    }

    /// The freeze is permanent (D19): un-completing the only completed set
    /// does not unfreeze — a later switch still creates a new entry.
    @Test func freezeSurvivesUncompletingFirstSet() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)
        let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
        let exercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.isSeeded == false })).first)
        let machine1ID = fixture.machine1ID
        let machine2ID = fixture.machine2ID
        let machine1 = try #require(try context.fetch(
            FetchDescriptor<MachineInstance>(
                predicate: #Predicate { $0.id == machine1ID })).first)
        let machine2 = try #require(try context.fetch(
            FetchDescriptor<MachineInstance>(
                predicate: #Predicate { $0.id == machine2ID })).first)

        let workout = try session.startWorkout(at: gym)
        let entry = try session.addEntry(for: exercise, to: workout, machine: machine1)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.toggleCompletion(of: set)
        try session.toggleCompletion(of: set) // undo
        #expect(set.completedAt == nil)
        #expect(entry.snapshotCapturedAt != nil) // freeze survives

        let result = try session.chooseEquipment(
            for: entry, machine: machine2, freeWeightTag: nil)
        #expect(result.id != entry.id)
        #expect(entry.machine?.id == fixture.machine1ID)
        #expect(result.machine?.id == fixture.machine2ID)
        // The (now uncompleted) draft row moved to the new entry.
        #expect((entry.sets ?? []).isEmpty)
        #expect(WorkoutSession.orderedSets(of: result).count == 1)
    }

    /// Before any completion the entry is a draft: equipment choice edits it
    /// in place, no new entry.
    @Test func equipmentChoiceOnDraftEntryEditsInPlace() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)
        let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
        let exercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.isSeeded == false })).first)
        let machine2ID = fixture.machine2ID
        let machine2 = try #require(try context.fetch(
            FetchDescriptor<MachineInstance>(
                predicate: #Predicate { $0.id == machine2ID })).first)

        let workout = try session.startWorkout(at: gym)
        let entry = try session.addEntry(
            for: exercise, to: workout, freeWeightTag: .dumbbell)
        #expect(entry.freeWeightTag == .dumbbell)

        let result = try session.chooseEquipment(
            for: entry, machine: machine2, freeWeightTag: nil)
        #expect(result.id == entry.id)
        #expect(entry.machine?.id == fixture.machine2ID)
        #expect(entry.freeWeightTag == nil)
        #expect(WorkoutSession.orderedEntries(of: workout).count == 1)
    }

    // MARK: Memory upsert

    /// Duplicate (gym, exercise) rows in the store: the latest `updatedAt`
    /// wins and is updated in place; no new duplicate is created.
    @Test func memoryUpsertDedupesByLatestUpdatedAt() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)
        let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
        let exercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.isSeeded == false })).first)
        let machine1ID = fixture.machine1ID
        let machine1 = try #require(try context.fetch(
            FetchDescriptor<MachineInstance>(
                predicate: #Predicate { $0.id == machine1ID })).first)

        let older = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let newer = older.addingTimeInterval(1_000)
        let staleRow = GymExerciseMemory(
            gymID: fixture.gymID, exerciseID: fixture.exerciseID,
            machineID: nil, updatedAt: older)
        let latestRow = GymExerciseMemory(
            gymID: fixture.gymID, exerciseID: fixture.exerciseID,
            machineID: nil, updatedAt: newer)
        context.insert(staleRow)
        context.insert(latestRow)
        try context.save()

        let workout = try session.startWorkout(at: gym)
        let entry = try session.addEntry(for: exercise, to: workout, machine: machine1)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        let completedAt = newer.addingTimeInterval(5_000)
        try session.toggleCompletion(of: set, at: completedAt)

        var rows = try context.fetch(FetchDescriptor<GymExerciseMemory>())
        #expect(rows.count == 2) // no new duplicate
        #expect(rows.first { $0.id == latestRow.id }?.machineID == fixture.machine1ID)
        #expect(rows.first { $0.id == latestRow.id }?.updatedAt == completedAt)
        #expect(rows.first { $0.id == staleRow.id }?.machineID == nil)
        #expect(rows.first { $0.id == staleRow.id }?.updatedAt == older)

        // Completing another set still creates no duplicates.
        let set2 = try session.addSet(to: entry)
        try session.toggleCompletion(of: set2, at: completedAt.addingTimeInterval(60))
        rows = try context.fetch(FetchDescriptor<GymExerciseMemory>())
        #expect(rows.count == 2)
    }

    /// First completion for a (gym, exercise) pair inserts the row; no-gym
    /// workouts record no memory.
    @Test func memoryUpsertInsertsWhenMissingAndSkipsNoGym() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let fixture = try seedFixture(in: context)
        let session = WorkoutSession(context: context)
        let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
        let exercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.isSeeded == false })).first)

        // No-gym workout → no memory row.
        let homeWorkout = try session.startWorkout(at: nil)
        let homeEntry = try session.addEntry(
            for: exercise, to: homeWorkout, freeWeightTag: .dumbbell)
        let homeSet = try #require(WorkoutSession.orderedSets(of: homeEntry).first)
        try session.toggleCompletion(of: homeSet)
        #expect(try context.fetch(FetchDescriptor<GymExerciseMemory>()).isEmpty)
        try session.finish(homeWorkout)

        // Gym workout, free weight → row with nil machineID.
        let workout = try session.startWorkout(at: gym)
        let entry = try session.addEntry(
            for: exercise, to: workout, freeWeightTag: .barbell)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.toggleCompletion(of: set)
        let rows = try context.fetch(FetchDescriptor<GymExerciseMemory>())
        try #require(rows.count == 1)
        #expect(rows[0].gymID == fixture.gymID)
        #expect(rows[0].exerciseID == fixture.exerciseID)
        #expect(rows[0].machineID == nil)
    }

    // MARK: Unit defaults

    /// New-set units follow the precedence chain (machine → gym → app
    /// preference) and persist per set as entered.
    @Test func setUnitsDefaultPerPrecedenceChain() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let session = WorkoutSession(context: context)

        let prefs = AppPreferences(unitPreference: .kg)
        let exercise = Exercise(name: "Bench Press")
        let gym = Gym(name: "Lb Gym", defaultUnit: .lb)
        let machine = MachineInstance(label: "Press", defaultUnit: .kg, gym: gym)
        for object in [prefs, exercise, gym, machine] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()

        // Machine default wins over the gym's.
        let workout = try session.startWorkout(at: gym)
        let machineEntry = try session.addEntry(
            for: exercise, to: workout, machine: machine)
        #expect(WorkoutSession.orderedSets(of: machineEntry).first?.weightUnit == .kg)

        // No machine → gym default.
        let gymEntry = try session.addEntry(
            for: exercise, to: workout, freeWeightTag: .barbell)
        let gymSet = try #require(WorkoutSession.orderedSets(of: gymEntry).first)
        #expect(gymSet.weightUnit == .lb)

        // A toggled unit persists as entered and carries to the next set.
        try session.commitWeight("100", for: gymSet)
        try session.toggleUnit(of: gymSet)
        #expect(gymSet.weightUnit == .kg)
        #expect(gymSet.weightValue == 100) // as entered, never converted
        #expect(gymSet.normalizedKg == 100)
        let nextSet = try session.addSet(to: gymEntry)
        #expect(nextSet.weightUnit == .kg)
        try session.finish(workout)

        // No gym at all → app preference.
        let homeWorkout = try session.startWorkout(at: nil)
        let homeEntry = try session.addEntry(
            for: exercise, to: homeWorkout, freeWeightTag: .barbell)
        #expect(WorkoutSession.orderedSets(of: homeEntry).first?.weightUnit == .kg)
    }

    // MARK: Finish & cancel

    /// Finish deletes uncompleted draft rows and entries with zero completed
    /// sets, stamps `finishedAt`, and all of it persists across reopen.
    @Test func finishCleansDraftsAndEmptyEntries() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        var workoutID = UUID()
        var keptEntryID = UUID()
        let finishedAt = Date(timeIntervalSinceReferenceDate: 762_000_000)

        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            _ = try seedFixture(in: context)
            let session = WorkoutSession(context: context)
            let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
            let exercise = try #require(try context.fetch(
                FetchDescriptor<Exercise>(
                    predicate: #Predicate { $0.isSeeded == false })).first)

            let workout = try session.startWorkout(at: gym)
            workoutID = workout.id

            // Entry A: one completed set + one draft → keeps the completed set.
            let entryA = try session.addEntry(for: exercise, to: workout)
            keptEntryID = entryA.id
            let setA1 = try #require(WorkoutSession.orderedSets(of: entryA).first)
            try session.commitWeight("60", for: setA1)
            try session.commitReps("10", for: setA1)
            try session.toggleCompletion(of: setA1)
            _ = try session.addSet(to: entryA)

            // Entry B: only drafts → deleted wholesale.
            let entryB = try session.addEntry(for: exercise, to: workout)
            _ = try session.addSet(to: entryB)

            try session.finish(workout, at: finishedAt)
        }()

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let workout = try fetchWorkout(workoutID, in: context)
        #expect(workout.finishedAt == finishedAt)
        let entries = WorkoutSession.orderedEntries(of: workout)
        try #require(entries.count == 1)
        #expect(entries[0].id == keptEntryID)
        let sets = WorkoutSession.orderedSets(of: entries[0])
        try #require(sets.count == 1)
        #expect(sets[0].completedAt != nil)
        // Nothing uncompleted reached history.
        #expect(try context.fetch(FetchDescriptor<SetRecord>(
            predicate: #Predicate { $0.completedAt == nil })).isEmpty)
    }

    /// Cancel deletes the workout and all children; the catalog and gym
    /// graph survive.
    @Test func cancelDeletesWholeGraph() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let fixture = try seedFixture(in: context)
            let session = WorkoutSession(context: context)
            let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
            let exercise = try #require(try context.fetch(
                FetchDescriptor<Exercise>(
                    predicate: #Predicate { $0.isSeeded == false })).first)
            let machine1ID = fixture.machine1ID
            let machine1 = try #require(try context.fetch(
                FetchDescriptor<MachineInstance>(
                    predicate: #Predicate { $0.id == machine1ID })).first)

            let workout = try session.startWorkout(at: gym)
            let entry = try session.addEntry(
                for: exercise, to: workout, machine: machine1)
            let set = try #require(WorkoutSession.orderedSets(of: entry).first)
            try session.commitWeight("60", for: set)
            try session.toggleCompletion(of: set)
            _ = try session.addSet(to: entry)

            try session.cancel(workout)
        }()

        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == 0)
        // Catalog/gym graph untouched.
        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MachineInstance>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }
}
