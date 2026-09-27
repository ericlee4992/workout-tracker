import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Floodlight redesign ticket 07 — what a scan confirms and saves, and a model correction's reach.

@MainActor
struct ScanMachineTests {

    private func container() throws -> ModelContainer {
        let schema = WorkoutTrackerStore.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func proposal(_ identity: String = "specific", label: String = "Chest press",
                          manufacturer: String = "Life Fitness", model: String = "Insignia Series Chest Press",
                          exercises: [UUID] = [], edited: Bool = false) -> EquipmentIdentification {
        var result = EquipmentIdentification(identity: identity, label: label, manufacturer: manufacturer,
                                             modelName: model, visibleText: "\(manufacturer) \(model)",
                                             exerciseIDs: exercises)
        result.labelWasEdited = edited
        return result
    }

    // MARK: Label

    @Test func anUneditedCatalogMatchIsNamedByItsMovement() {
        let label = ScanMachine.prefilledLabel(for: proposal(), catalogModelName: "Insignia Series Chest Press",
                                               modelExerciseNames: ["Seated Chest Press"])
        #expect(label == "Seated Chest Press")
    }

    @Test func aStationKeepsItsModelNameAndAnEditedNameIsKept() {
        #expect(ScanMachine.prefilledLabel(for: proposal(), catalogModelName: "Cable Crossover",
                                           modelExerciseNames: ["Cable Fly", "Triceps Pushdown"]) == "Cable Crossover")
        #expect(ScanMachine.prefilledLabel(for: proposal(label: "Press by window", edited: true),
                                           catalogModelName: "Insignia Series Chest Press",
                                           modelExerciseNames: ["Seated Chest Press"]) == "Press by window")
        #expect(ScanMachine.prefilledLabel(for: proposal("generic"), catalogModelName: nil,
                                           modelExerciseNames: []) == "Chest press")
    }

    @Test func anUneditedNameFollowsTheIdentityAndATypedOneStays() {
        // The answer now matches the shoulder press: the name follows its movement…
        var answer = proposal(label: "Seated Chest Press")
        #expect(ScanMachine.reconciledLabel(answer, aiLabel: "Chest press", catalogModelName: "Insignia Series Shoulder Press",
                                            modelExerciseNames: ["Machine Shoulder Press"]) == "Machine Shoulder Press")
        // …and back to the AI's own label when nothing is matched any more.
        #expect(ScanMachine.reconciledLabel(answer, aiLabel: "Chest press", catalogModelName: nil,
                                            modelExerciseNames: []) == "Chest press")
        answer.labelWasEdited = true
        answer.label = "Press by window"
        #expect(ScanMachine.reconciledLabel(answer, aiLabel: "Chest press", catalogModelName: "Insignia Series Shoulder Press",
                                            modelExerciseNames: ["Machine Shoulder Press"]) == "Press by window")
    }

    // MARK: Confirmation

    @Test func aCatalogMatchSuppliesItsExercisesAndGenericClearsTheIdentity() {
        let ai = UUID(), catalogExercise = UUID()
        let model = EquipmentModel(manufacturer: "Life Fitness", modelName: "Insignia Series Chest Press",
                                   exerciseIDs: [catalogExercise], isSeeded: true)
        let answer = proposal(label: "  Chest press ", exercises: [ai])

        let matched = ScanMachine.confirmed(answer, resolution: .catalog(model), genericChosen: false)
        #expect(matched.exerciseIDs == [catalogExercise])
        #expect(matched.identity == "specific")
        #expect(matched.label == "Chest press")

        // Set aside: the AI's own exercises come back, and no model can be re-claimed later.
        let generic = ScanMachine.confirmed(answer, resolution: .catalog(model), genericChosen: true)
        #expect(generic.exerciseIDs == [ai])
        #expect(generic.identity == "generic")
        #expect(generic.manufacturer.isEmpty && generic.modelName.isEmpty)

        let ambiguous = ScanMachine.confirmed(answer, resolution: .ambiguous, genericChosen: false)
        #expect(ambiguous.identity == "generic")
        let newModel = ScanMachine.confirmed(answer, resolution: .newModel(manufacturer: "Life Fitness", name: "X"),
                                             genericChosen: false)
        #expect(newModel.identity == "specific" && newModel.exerciseIDs == [ai])
    }

    @Test func addNeedsANameAndAnExercise() {
        #expect(!ScanMachine.canConfirm(label: "  ", exerciseIDs: [UUID()]))
        #expect(!ScanMachine.canConfirm(label: "Press", exerciseIDs: []))
        #expect(ScanMachine.canConfirm(label: "Press", exerciseIDs: [UUID()]))
    }

    // MARK: Suggested exercises

    @Test func suggestedExercisesLeadWithTheAIsThenSameGroupMachines() {
        let press = ScanMachine.ExerciseOption(id: UUID(), name: "Seated Chest Press", muscleGroup: "Chest", isMachine: true)
        let fly = ScanMachine.ExerciseOption(id: UUID(), name: "Pec Deck", muscleGroup: "Chest", isMachine: true)
        let incline = ScanMachine.ExerciseOption(id: UUID(), name: "Incline Machine Press", muscleGroup: "Chest", isMachine: true)
        let bench = ScanMachine.ExerciseOption(id: UUID(), name: "Bench Press", muscleGroup: "Chest", isMachine: false)
        let row = ScanMachine.ExerciseOption(id: UUID(), name: "Seated Row", muscleGroup: "Back", isMachine: true)
        let result = ScanMachine.suggestedExercises(proposed: [press.id], selected: [press.id],
                                                    among: [row, bench, fly, press, incline])
        #expect(result == [press.id, incline.id, fly.id])
    }

    // MARK: SwiftData

    @Test func addResolvesEachIdentityOnce() throws {
        let context = ModelContext(try container())
        let exercise = Exercise(name: "Seated Chest Press", equipmentTypeTags: [.machine], muscleGroup: "Chest", isSeeded: true)
        let catalog = EquipmentModel(manufacturer: "Life Fitness", modelName: "Insignia Series Chest Press",
                                     exerciseIDs: [exercise.id], isSeeded: true)
        let gym = Gym(name: "Iron Temple")
        context.insert(exercise); context.insert(catalog); context.insert(gym)
        try context.save()

        // Catalog: the model's exercises, none copied onto the machine.
        let matched = try ScanMachine.add(ScanMachine.confirmed(proposal(exercises: [exercise.id]),
                                                                resolution: .catalog(catalog), genericChosen: false),
                                          to: gym, context: context)
        #expect(matched.model?.id == catalog.id)
        #expect(matched.recognizedExerciseIDs.isEmpty)

        // A visible model the catalog lacks: a user model (never seeded) carrying the exercises.
        let created = try ScanMachine.add(proposal(model: "Printed Test Press", exercises: [exercise.id]),
                                          to: gym, context: context)
        #expect(created.model?.isSeeded == false)
        #expect(created.model?.modelName == "Printed Test Press")
        #expect(created.model?.exerciseIDs == [exercise.id])

        // Generic: no model claimed, instance-local exercises.
        let generic = try ScanMachine.add(proposal("generic", manufacturer: "", model: "", exercises: [exercise.id]),
                                          to: gym, context: context)
        #expect(generic.model == nil)
        #expect(generic.recognizedExerciseIDs == [exercise.id])
        #expect(generic.gym?.id == gym.id)

        // A movement-only "model" stays model-less (D56).
        let movement = try ScanMachine.add(proposal(model: "Seated Chest Press", exercises: [exercise.id]),
                                           to: gym, context: context)
        #expect(movement.model == nil)
    }

    @Test func theDuplicateWarningIgnoresDeletedMachinesAndOtherGyms() throws {
        let context = ModelContext(try container())
        let model = EquipmentModel(manufacturer: "Matrix", modelName: "MG-PL71 Hack Squat", isSeeded: true)
        let gym = Gym(name: "Iron Temple"), other = Gym(name: "Hotel Gym")
        let deleted = MachineInstance(label: "Old Squat", archived: true, gym: gym, model: model)
        let elsewhere = MachineInstance(label: "Hotel Squat", gym: other, model: model)
        context.insert(model); context.insert(gym); context.insert(other)
        context.insert(deleted); context.insert(elsewhere)
        try context.save()
        #expect(ScanMachine.existing(modelID: model.id, at: gym) == nil)

        let live = MachineInstance(label: "Hack Squat", gym: gym, model: model)
        context.insert(live)
        try context.save()
        #expect(ScanMachine.existing(modelID: model.id, at: gym)?.id == live.id)
    }

    // MARK: Correct Model

    @Test func correctionImpactCountsDistinctWorkoutsAndCompletedSets() {
        let a = UUID(), b = UUID()
        let impact = ModelCorrection.impact(of: [
            .init(workoutID: a, completedSets: 3), .init(workoutID: a, completedSets: 2),
            .init(workoutID: b, completedSets: 0), .init(workoutID: nil, completedSets: 1),
        ])
        #expect(impact == ModelCorrection.Impact(workouts: 2, sets: 6))
    }

    @Test func correctionImpactReadsSnapshotsOfThisMachineOnly() throws {
        let context = ModelContext(try container())
        let gym = Gym(name: "Iron Temple")
        let machine = MachineInstance(label: "Lat Pulldown", gym: gym)
        let other = MachineInstance(label: "Row", gym: gym)
        context.insert(gym); context.insert(machine); context.insert(other)
        for (target, completed) in [(machine, 2), (machine, 1), (other, 4)] {
            let workout = Workout(startedAt: .now)
            let entry = ExerciseEntry(order: 0, workout: workout, snapshotExerciseID: UUID(),
                                      snapshotMachineID: target.id, snapshotLoadType: .weighted,
                                      snapshotExerciseName: "Lat Pulldown")
            context.insert(workout); context.insert(entry)
            for index in 0..<completed { context.insert(SetRecord(order: index, completedAt: .now, entry: entry)) }
            context.insert(SetRecord(order: 9, entry: entry))
        }
        try context.save()
        #expect(try ModelCorrection.impact(of: machine, context: context) == .init(workouts: 2, sets: 3))
    }

    @Test func correctionSuggestionsLeadWithTheMovementThenSharedExercises() {
        let pulldown = UUID(), row = UUID()
        func option(_ name: String, _ exercises: [UUID]) -> ModelCorrection.ModelOption {
            .init(id: UUID(), modelName: name, displayName: "Maker \(name)", exerciseIDs: exercises)
        }
        let current = option("Insignia Series Pulldown", [pulldown])
        let named = option("G7 Lat Pulldown", [pulldown])
        let both = option("Dual Pulley", [pulldown, row])
        let one = option("Adjustable Pulley", [pulldown])
        let unrelated = option("Leg Press", [UUID()])
        let result = ModelCorrection.suggestions(machineLabel: "Lat Pulldown", exerciseIDs: [pulldown, row],
                                                 currentModelID: current.id,
                                                 among: [unrelated, one, both, named, current])
        #expect(result == [named.id, both.id, one.id])
        #expect(ModelCorrection.suggestions(machineLabel: "X", exerciseIDs: [], currentModelID: nil,
                                            among: [named]).isEmpty)
    }
}
