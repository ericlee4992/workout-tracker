import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 06 — machine, user-model & user-exercise creation.

struct MachineCreationTests {

    // MARK: Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = WorkoutTrackerStore.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Fresh on-disk store location in its own directory (removed with all
    /// sqlite sidecar files by the caller's defer).
    private func makeStoreDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("machine-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // Small programmatic catalogs mirroring SeedingTests' version-transition
    // fixtures.

    private let seededExerciseID = UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000011")!
    private let seededModelID = UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000011")!

    private func catalog(version: Int, exerciseName: String) -> SeedCatalog {
        SeedCatalog(
            version: version,
            exercises: [
                SeedExercise(
                    id: seededExerciseID, name: exerciseName, loadType: .weighted,
                    equipmentTypeTags: [.machine], muscleGroup: "Chest"),
            ],
            equipmentModels: [
                SeedEquipmentModel(
                    id: seededModelID, manufacturer: "Life Fitness",
                    modelName: "Insignia Chest Press", exerciseIDs: [seededExerciseID]),
            ])
    }

    // MARK: Machine creation round-trip

    /// Machines created at a gym — with a model and model-less — survive a
    /// relaunch (fresh container over the same on-disk store) with label,
    /// gym link, model link, and default unit intact.
    @Test func machinesSurviveRelaunch() throws {
        let directory = try makeStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")

        let gymID = UUID()
        let modelID = UUID()

        // "First launch": create gym, user model, and two machines.
        do {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let gym = Gym(id: gymID, name: "Gangnam Fitness", defaultUnit: .kg)
            let model = EquipmentModel(
                id: modelID, manufacturer: "Matrix", modelName: "Ultra Chest Press",
                exerciseIDs: [UUID()], isSeeded: false)
            context.insert(gym)
            context.insert(model)
            context.insert(MachineInstance(
                label: "Chest press by the window", defaultUnit: .lb,
                gym: gym, model: model))
            // Model-less machine — allowed; logging opens the full exercise picker.
            context.insert(MachineInstance(
                label: "Mystery plate-loaded thing", gym: gym))
            try context.save()
        }

        // "Relaunch": fresh container over the same file.
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let machines = try context.fetch(FetchDescriptor<MachineInstance>())
        #expect(machines.count == 2)

        let modeled = try #require(
            machines.first { $0.label == "Chest press by the window" })
        #expect(modeled.gym?.id == gymID)
        #expect(modeled.model?.id == modelID)
        #expect(modeled.model?.displayName == "Matrix Ultra Chest Press")
        #expect(modeled.defaultUnit == .lb)
        #expect(modeled.archived == false)

        let modelLess = try #require(
            machines.first { $0.label == "Mystery plate-loaded thing" })
        #expect(modelLess.gym?.id == gymID)
        #expect(modelLess.model == nil)
        #expect(modelLess.defaultUnit == nil)

        // The gym's inverse relationship resolves both machines.
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        let gym = try #require(gyms.first { $0.id == gymID })
        #expect(Set((gym.machines ?? []).map(\.label))
            == ["Chest press by the window", "Mystery plate-loaded thing"])
    }

    // MARK: User-created rows

    /// User-created exercises persist with all four load types and land in
    /// the user ID space (`isSeeded == false`), alongside seeded rows.
    @Test func userExercisesSupportAllLoadTypes() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalog(version: 1, exerciseName: "Chest Press"), in: context)

        for (index, loadType) in LoadType.allCases.enumerated() {
            context.insert(Exercise(
                name: "Custom \(index)", loadType: loadType,
                equipmentTypeTags: [.machine, .cable], isSeeded: false))
        }
        try context.save()

        let userRows = try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isSeeded }))
        #expect(userRows.count == LoadType.allCases.count)
        #expect(Set(userRows.map(\.loadType)) == Set(LoadType.allCases))
        let allTagged = userRows.allSatisfy { $0.equipmentTypeTags == [.machine, .cable] }
        #expect(allTagged)

        // Seeded and user rows coexist in one catalog query.
        let all = try context.fetch(FetchDescriptor<Exercise>())
        #expect(all.count == LoadType.allCases.count + 1)
    }

    /// A user-created model persists with its exercise links and stays
    /// distinguishable from seeded rows via `isSeeded == false`.
    @Test func userModelPersistsWithExerciseLinks() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalog(version: 1, exerciseName: "Chest Press"), in: context)

        let userExercise = Exercise(name: "Landmine Press", isSeeded: false)
        context.insert(userExercise)
        context.insert(EquipmentModel(
            manufacturer: "Homemade", modelName: "Garage Landmine",
            exerciseIDs: [userExercise.id, seededExerciseID], isSeeded: false))
        try context.save()

        let userModels = try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { !$0.isSeeded }))
        #expect(userModels.count == 1)
        let model = try #require(userModels.first)
        #expect(model.displayName == "Homemade Garage Landmine")
        #expect(model.exerciseIDs == [userExercise.id, seededExerciseID])

        let seededModels = try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.isSeeded }))
        #expect(seededModels.count == 1)
    }

    // MARK: Reconciliation rerun safety

    /// Rerunning catalog reconciliation — same version and a version upgrade —
    /// leaves user models, user exercises, and machines (including their
    /// model/gym links) byte-for-byte untouched.
    @Test func reconciliationRerunLeavesUserRowsAndMachinesUntouched() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(catalog(version: 1, exerciseName: "Chest Press"), in: context)

        // User-created rows plus machines pointing at both ID spaces.
        let gym = Gym(name: "Hotel Gym")
        let userExercise = Exercise(
            name: "Landmine Press", loadType: .weighted,
            equipmentTypeTags: [.barbell], isSeeded: false)
        let userModel = EquipmentModel(
            manufacturer: "Homemade", modelName: "Garage Landmine",
            exerciseIDs: [userExercise.id], isSeeded: false)
        context.insert(gym)
        context.insert(userExercise)
        context.insert(userModel)
        let seededModel = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.isSeeded })).first)
        let machineOnUserModel = MachineInstance(
            label: "Landmine corner", defaultUnit: .kg, gym: gym, model: userModel)
        let machineOnSeededModel = MachineInstance(
            label: "Chest press #1", gym: gym, model: seededModel)
        let machineWithoutModel = MachineInstance(label: "Unlabeled stack", gym: gym)
        context.insert(machineOnUserModel)
        context.insert(machineOnSeededModel)
        context.insert(machineWithoutModel)
        try context.save()

        // Same-version rerun, then a version upgrade that renames the seeded
        // exercise — neither may touch user rows or machines.
        try CatalogSeeder.reconcile(catalog(version: 1, exerciseName: "Chest Press"), in: context)
        try CatalogSeeder.reconcile(
            catalog(version: 2, exerciseName: "Seated Chest Press"), in: context)

        #expect(try context.fetchCount(FetchDescriptor<MachineInstance>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<EquipmentModel>()) == 2)

        // The upgrade did land on the seeded row…
        let seededExerciseID = self.seededExerciseID
        let seededExercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == seededExerciseID })).first)
        #expect(seededExercise.name == "Seated Chest Press")

        // …while user rows kept every field.
        let survivingUserExercise = try #require(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isSeeded })).first)
        #expect(survivingUserExercise.name == "Landmine Press")
        #expect(survivingUserExercise.equipmentTypeTags == [.barbell])
        let survivingUserModel = try #require(try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { !$0.isSeeded })).first)
        #expect(survivingUserModel.manufacturer == "Homemade")
        #expect(survivingUserModel.exerciseIDs == [userExercise.id])

        // …and machines kept labels, units, and links across both ID spaces.
        let machines = try context.fetch(FetchDescriptor<MachineInstance>())
        let landmine = try #require(machines.first { $0.label == "Landmine corner" })
        #expect(landmine.model?.id == userModel.id)
        #expect(landmine.defaultUnit == .kg)
        let chestPress = try #require(machines.first { $0.label == "Chest press #1" })
        #expect(chestPress.model?.id == seededModel.id)
        let unlabeled = try #require(machines.first { $0.label == "Unlabeled stack" })
        #expect(unlabeled.model == nil)
        let allAtGym = machines.allSatisfy { $0.gym?.id == gym.id }
        #expect(allAtGym)
    }
}
