import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 09 — history rendering: unit-badge derivation from actual sets,
// snapshot-only equipment labels (D23) proven against live renames with the
// disk-backed reopen pattern, and convert-toggle formatting (D9/D25).

struct HistoryRenderingTests {

    // MARK: Unit badge derivation

    @Test func allKgSetsDeriveKgBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: [.kg, .kg, .kg]) == .single(.kg))
        #expect(WorkoutUnitBadge.derive(fromUnits: [.kg])?.label == "kg")
    }

    @Test func allLbSetsDeriveLbBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: [.lb, .lb]) == .single(.lb))
        #expect(WorkoutUnitBadge.derive(fromUnits: [.lb])?.label == "lb")
    }

    @Test func mixedUnitsDeriveMixedBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: [.kg, .lb, .kg]) == .mixed)
        #expect(WorkoutUnitBadge.mixed.label == "Mixed")
    }

    @Test func noSetsDeriveNoBadge() {
        #expect(WorkoutUnitBadge.derive(fromUnits: []) == nil)
        #expect(WorkoutUnitBadge.derive(fromCompleted: []) == nil)
    }

    /// Only completed sets feed the badge: a lingering lb draft must not turn
    /// an all-kg workout into Mixed.
    @Test func badgeIgnoresUncompletedDrafts() {
        let completed = SetRecord(
            order: 0, reps: 10, weightValue: 60, weightUnit: .kg,
            normalizedKg: 60, completedAt: .now)
        let draft = SetRecord(order: 1, weightUnit: .lb)
        #expect(WorkoutUnitBadge.derive(fromCompleted: [completed, draft]) == .single(.kg))
    }

    // MARK: Snapshot equipment labels

    @Test func machineEntryLabelIsMachineLabelDotModelDisplayName() {
        let entry = ExerciseEntry(
            order: 0,
            snapshotExerciseID: UUID(),
            snapshotLoadType: .weighted,
            snapshotExerciseName: "Seated Chest Press",
            snapshotMachineLabel: "Chest Press #1",
            snapshotModelName: "Life Fitness Insignia Chest Press")
        #expect(entry.snapshotEquipmentLabel == "Chest Press #1 · Life Fitness Insignia Chest Press")
    }

    @Test func freeWeightEntryLabelIsSnapshotTagLabel() {
        let entry = ExerciseEntry(
            order: 0,
            snapshotExerciseID: UUID(),
            snapshotLoadType: .weighted,
            snapshotFreeWeightTag: .barbell,
            snapshotExerciseName: "Bench Press")
        #expect(entry.snapshotEquipmentLabel == "Barbell")
    }

    /// Rendering source proof (D23): after logging, rename the live machine,
    /// model, and exercise — the labels history renders (snapshot display
    /// strings) survive a store reopen unchanged.
    @Test func historyLabelsSurviveLiveRenames() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-test-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: url.path + suffix))
            }
        }

        var workoutID = UUID()
        try {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let exercise = Exercise(name: "Seated Chest Press", loadType: .weighted)
            let model = EquipmentModel(
                manufacturer: "Life Fitness", modelName: "Insignia Chest Press",
                exerciseIDs: [exercise.id])
            let gym = Gym(name: "Gold's Gym Gangnam", defaultUnit: .kg)
            let machine = MachineInstance(label: "Chest Press #1", gym: gym, model: model)
            for object in [exercise, model, gym, machine] as [any PersistentModel] {
                context.insert(object)
            }
            try context.save()

            let session = WorkoutSession(context: context)
            let workout = try session.startWorkout(at: gym)
            workoutID = workout.id
            let entry = try session.addEntry(for: exercise, to: workout, machine: machine)
            let set = try #require(WorkoutSession.orderedSets(of: entry).first)
            try session.commitWeight("60", for: set)
            try session.commitReps("10", for: set)
            try session.toggleCompletion(of: set)
            try session.finish(workout)

            // Rename everything the entry points at through live relationships.
            machine.label = "Renamed Machine"
            model.manufacturer = "Rebranded"
            model.modelName = "Different Model"
            exercise.name = "Renamed Exercise"
            try context.save()
        }()

        // Reopen: history rendering reads snapshots, not the renamed rows.
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let workouts = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.id == workoutID }))
        let workout = try #require(workouts.first)
        let entry = try #require(WorkoutSession.orderedEntries(of: workout).first)

        // The live relationships did change...
        #expect(entry.machine?.label == "Renamed Machine")
        #expect(entry.exercise?.name == "Renamed Exercise")
        // ...but the snapshot strings history renders did not.
        #expect(entry.snapshotExerciseName == "Seated Chest Press")
        #expect(entry.snapshotEquipmentLabel == "Chest Press #1 · Life Fitness Insignia Chest Press")
        #expect(WorkoutUnitBadge.derive(fromCompleted: workout.completedSets) == .single(.kg))
    }

    // MARK: Convert-toggle formatting (D9/D25)

    private let enUS = Locale(identifier: "en_US")

    @Test func sameUnitRendersAsEnteredWithoutApproximation() throws {
        let kg = try #require(StoredWeight(value: 60, unit: .kg))
        let lb = try #require(StoredWeight(value: 135, unit: .lb))
        #expect(WeightMath.displayLabel(for: kg, in: .kg, locale: enUS) == "60 kg")
        #expect(WeightMath.displayLabel(for: lb, in: .lb, locale: enUS) == "135 lb")
    }

    @Test func convertedValuesAreApproximateMarked() throws {
        let kg = try #require(StoredWeight(value: 60, unit: .kg))
        let lb = try #require(StoredWeight(value: 135, unit: .lb))
        // 60 / 0.45359237 = 132.277… → ≈132.28 lb (2 decimals, half-up)
        #expect(WeightMath.displayLabel(for: kg, in: .lb, locale: enUS) == "≈132.28 lb")
        // 135 × 0.45359237 = 61.2349… → ≈61.23 kg
        #expect(WeightMath.displayLabel(for: lb, in: .kg, locale: enUS) == "≈61.23 kg")
    }
}
