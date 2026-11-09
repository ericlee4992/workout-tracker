import CoreData
import CryptoKit
import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

// Nutrition N2: the first stored-format change since the beta began. `Fixtures/PreNutrition.store` is a store in the
// format every TestFlight build (1–9) uses — written 2026-11-09 by the app at `e8935eb` (no model change since build 1;
// `StoreFormatGuardTests.shippedFingerprint`), with the design sample, history, gyms, exercises, settings, progress,
// heart-rate history and cardio route fixtures: 21 workouts, 72 sets, 11 cardio segments, 3 templates, 3 gyms,
// 12 machines, 2 presets. The first test proves that format from the store's own metadata, so the fixture cannot
// silently be today's. Opened with today's model it must migrate with every table's row count and the key values below
// intact (a row-by-row comparison is the Simulator rehearsal's `compare_stores.py`), the new tables empty
// — and N1's safety copy must see the change first. The checksums were read from the fixture with sqlite3.

struct NutritionMigrationTests {
    private final class BundleMarker {}

    private func fixtureURL() throws -> URL {
        try #require(Bundle(for: BundleMarker.self).url(forResource: "PreNutrition", withExtension: "store"),
                     "the pre-nutrition fixture must ship with the test bundle")
    }

    /// A writable copy (SwiftData opens stores read-write and would migrate the bundle's copy in place).
    private func copiedFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "pre-nutrition-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let copy = directory.appending(path: "default.store")
        try FileManager.default.copyItem(at: try fixtureURL(), to: copy)
        return copy
    }

    @Test func theFixtureIsInTheFormatTestersHave() throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            type: .sqlite, at: try fixtureURL())
        let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
        let hex = { (data: Data) in data.map { String(format: "%02x", $0) }.joined() }
        let lines = hashes.sorted { $0.key < $1.key }.map { "\($0.key):\(hex($0.value))" }
        let fingerprint = hex(Data(SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))))
        #expect(fingerprint == StoreFormatGuardTests.shippedFingerprint)
    }

    @Test func theSafetyCopySeesTheChangeBeforeTheOpen() throws {
        let model = NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes)
        #expect(SafetyCopies.storeNeedsCopy(at: try fixtureURL(), model: model))
    }

    @Test func everyTableKeepsItsRowsAndKeyValuesThroughTheMigration() throws {
        let url = try copiedFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let context = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
        func count<T: PersistentModel>(_: T.Type) throws -> Int { try context.fetchCount(FetchDescriptor<T>()) }

        #expect(try count(Workout.self) == 21)
        #expect(try count(ExerciseEntry.self) == 33)
        #expect(try count(SetRecord.self) == 72)
        #expect(try count(CardioSegment.self) == 11)
        #expect(try count(WorkoutTemplate.self) == 3)
        #expect(try count(TemplateItem.self) == 13)
        #expect(try count(Gym.self) == 3)
        #expect(try count(MachineInstance.self) == 12)
        #expect(try count(ExercisePreset.self) == 2)
        #expect(try count(GymExerciseMemory.self) == 10)
        #expect(try count(AppPreferences.self) == 1)
        #expect(try count(Exercise.self) == 91)
        #expect(try count(EquipmentModel.self) == 1877)

        let sets = try context.fetch(FetchDescriptor<SetRecord>())
        #expect(abs(sets.compactMap(\.normalizedKg).reduce(0, +) - 2086.8783) < 0.001)
        #expect(sets.compactMap(\.reps).reduce(0, +) == 667)
        #expect(sets.filter { $0.completedAt != nil }.count == 72)
        let cardio = try context.fetch(FetchDescriptor<CardioSegment>())
        #expect(abs(cardio.compactMap(\.automaticDistanceMeters).reduce(0, +) - 33044.799) < 0.01)
        #expect(abs(cardio.map(\.accumulatedActiveSeconds).reduce(0, +) - 11406) < 0.1)
        #expect(try context.fetch(FetchDescriptor<Gym>()).map(\.name).sorted()
                == ["Gangnam Fitness", "Hotel Gym", "Iron Temple"])
        #expect(try context.fetch(FetchDescriptor<WorkoutTemplate>()).map(\.name).sorted()
                == ["Leg Day", "Pull Day", "Push Day"])
        #expect(try context.fetch(FetchDescriptor<MachineInstance>()).map(\.label).sorted() == [
            "Biceps Curl", "Cable Station", "Calf Raise", "Chest Press 2", "Incline Press", "Lat Pulldown",
            "Leg Extension", "Leg Press", "Old Row", "Pec Deck", "Seated Leg Curl", "Seated Row"])
        #expect(try context.fetch(FetchDescriptor<ExercisePreset>()).map(\.name).sorted() == ["Narrow grip", "Wide grip"])

        // The new tables arrive empty: the migration adds, it never invents.
        #expect(try count(FoodEntry.self) == 0)
        #expect(try count(SavedFood.self) == 0)
        #expect(try count(SavedMeal.self) == 0)
        #expect(try count(SavedMealItem.self) == 0)
        #expect(try count(NutritionGoal.self) == 0)
        #expect(try count(BodyWeightEntry.self) == 0)
    }

    @Test func theMigratedStoreKeepsNutritionDataAcrossAReopen() throws {
        let url = try copiedFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let foodID = UUID()
        do {
            let context = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
            let food = SavedFood(id: foodID, name: "Greek yogurt", servingValue: 170, servingUnit: "g",
                                 servingGrams: 170, calories: 100, proteinGrams: 17, carbsGrams: 6, fatGrams: 0.7,
                                 isSaved: true)
            food.servingOptions = [ServingOption(value: 1, unit: "cup", grams: 227)]
            context.insert(food)
            context.insert(FoodEntry(logging: food, servings: 1.5, meal: .breakfast))
            context.insert(BodyWeightEntry(measuredAt: .now, value: 180, unit: .lb))
            try context.save()
        }
        // After a migration, an ordinary launch makes no further copy: the store now matches the model.
        let model = NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes)
        #expect(!SafetyCopies.storeNeedsCopy(at: url, model: model))

        // A second container on the same file reads back what the first wrote, the old rows still beside it.
        let reopened = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
        let entry = try #require(try reopened.fetch(FetchDescriptor<FoodEntry>()).first)
        #expect(entry.name == "Greek yogurt" && entry.servings == 1.5 && entry.meal == .breakfast)
        #expect(entry.savedFood?.id == foodID && entry.source == .saved)
        #expect(NutritionMath.totals(of: entry).calories == 150)
        let food = try #require(try reopened.fetch(FetchDescriptor<SavedFood>()).first)
        #expect(food.servingOptions == [ServingOption(value: 1, unit: "cup", grams: 227)] && food.isSaved)
        let weight = try #require(try reopened.fetch(FetchDescriptor<BodyWeightEntry>()).first)
        #expect(weight.value == 180 && weight.unit == .lb)
        #expect(weight.normalizedKg == 180 * WeightMath.kilogramsPerPound)
        #expect(try reopened.fetchCount(FetchDescriptor<Workout>()) == 21)
        #expect(try reopened.fetchCount(FetchDescriptor<SetRecord>()) == 72)
    }
}
