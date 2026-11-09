import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N2, acceptance 3: export v12 carries foods, saved foods, my meals, goals and body weights; the JSON reads
/// back equal; a v11 file (written before nutrition, no nutrition keys) still decodes; the CSV stays sets and cardio.
@MainActor
struct NutritionExportTests {
    private let collector = ExportCollector(
        dateFormat: ExportDateFormat(timeZone: TimeZone(secondsFromGMT: -5 * 3_600)!), appVersion: "test")

    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_793_000_000 + seconds) }

    private struct Rig {
        var food: SavedFood
        var bare: SavedFood
        var entry: FoodEntry
        var meal: SavedMeal
        var goal: NutritionGoal
        var weight: BodyWeightEntry
    }

    /// One of everything, every optional set on one row and none on another, so both a full and a bare row travel.
    private func seed(_ context: ModelContext) throws -> Rig {
        let food = SavedFood(name: "Greek yogurt", brand: "Fage", barcode: "5201054017029", databaseID: "usda:123",
                             servingValue: 170, servingUnit: "g", servingGrams: 170, calories: 100,
                             proteinGrams: 18, carbsGrams: 6, fatGrams: 0.5, fiberGrams: 0, sugarGrams: 6,
                             saturatedFatGrams: 0.2, sodiumMilligrams: 65, isSaved: true, createdAt: at(0))
        food.servingOptions = [ServingOption(value: 1, unit: "cup", grams: 227), ServingOption(value: 1, unit: "tub")]
        food.lastUsedAt = at(3_600)
        let bare = SavedFood(name: "Coffee", calories: 2, createdAt: at(10))
        context.insert(food)
        context.insert(bare)

        let entry = FoodEntry(logging: food, servings: 1.5, meal: .breakfast, at: at(3_600))
        entry.healthSampleID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        let quick = FoodEntry(loggedAt: at(7_200), meal: .snacks, name: "Quick add", calories: 250,
                              source: .quickAdd, createdAt: at(7_200))
        context.insert(entry)
        context.insert(quick)

        let meal = SavedMeal(name: "Usual breakfast", usualMeal: .breakfast, createdAt: at(20))
        meal.lastUsedAt = at(3_600)
        context.insert(meal)
        let second = SavedMealItem(order: 1, name: "Coffee", calories: 2, savedFood: bare)
        let first = SavedMealItem(order: 0, name: "Greek yogurt", brand: "Fage", servings: 2, servingValue: 170,
                                  servingUnit: "g", servingGrams: 170, calories: 100, proteinGrams: 18,
                                  carbsGrams: 6, fatGrams: 0.5, fiberGrams: 0, sugarGrams: 6,
                                  saturatedFatGrams: 0.2, sodiumMilligrams: 65, barcode: "5201054017029",
                                  savedFood: food)
        for item in [second, first] {
            item.meal = meal
            context.insert(item)
        }

        let goal = NutritionGoal(effectiveFrom: at(0), calories: 2_400, proteinGrams: 180, carbsGrams: 250,
                                 fatGrams: 75, createdAt: at(0))
        goal.weightKg = 82
        goal.heightCm = 180
        goal.ageYears = 34
        goal.sex = .male
        goal.activity = .moderate
        goal.goal = .lose
        goal.proteinOverridden = true
        let typed = NutritionGoal(effectiveFrom: at(86_400), calories: 2_200, proteinGrams: 170, carbsGrams: 220,
                                  fatGrams: 70, createdAt: at(86_400))
        context.insert(goal)
        context.insert(typed)

        let weight = BodyWeightEntry(measuredAt: at(600), value: 180.4, unit: .lb, source: .health,
                                     healthSampleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
                                     createdAt: at(600))
        context.insert(weight)
        context.insert(BodyWeightEntry(measuredAt: at(90_000), value: 81.5, unit: .kg, createdAt: at(90_000)))
        try context.save()
        return Rig(food: food, bare: bare, entry: entry, meal: meal, goal: goal, weight: weight)
    }

    @Test func v12CarriesEveryNutritionRowAndReadsBackEqual() throws {
        let context = try context()
        let rig = try seed(context)
        let snapshot = try collector.snapshot(from: context)

        #expect(snapshot.schemaVersion == 12)
        #expect(snapshot.counts.foodEntries == 2 && snapshot.counts.savedFoods == 2)
        #expect(snapshot.counts.savedMeals == 1 && snapshot.counts.bodyWeights == 2)

        let entries = try #require(snapshot.foodEntries)
        #expect(entries.map(\.name) == ["Greek yogurt", "Quick add"], "chronological by when it was eaten")
        let entry = try #require(entries.first)
        #expect(entry.id == rig.entry.id && entry.meal == .breakfast && entry.source == .saved)
        #expect(entry.servings == 1.5 && entry.servingValue == 170 && entry.servingUnit == "g")
        #expect(entry.calories == 100 && entry.proteinGrams == 18, "per serving, as stored")
        #expect(entry.sodiumMilligrams == 65 && entry.barcode == "5201054017029")
        #expect(entry.savedFoodID == rig.food.id && entry.healthSampleID == rig.entry.healthSampleID)
        #expect(entries.last?.savedFoodID == nil && entries.last?.source == .quickAdd)

        let foods = try #require(snapshot.savedFoods)
        #expect(foods.map(\.name) == ["Coffee", "Greek yogurt"])
        let yogurt = try #require(foods.last)
        #expect(yogurt.servingOptions == rig.food.servingOptions && yogurt.databaseID == "usda:123")
        #expect(yogurt.isSaved && yogurt.lastUsedAt != nil)
        #expect(foods.first?.servingOptions == nil, "no options is absent, not an empty list")

        let meal = try #require(snapshot.savedMeals?.first)
        #expect(meal.id == rig.meal.id && meal.usualMeal == .breakfast)
        #expect(meal.items.map(\.name) == ["Greek yogurt", "Coffee"], "items in their order")
        #expect(meal.items.map(\.savedFoodID) == [rig.food.id, rig.bare.id])
        #expect(meal.items.first?.servings == 2)

        let goals = try #require(snapshot.nutritionGoals)
        #expect(goals.map(\.calories) == [2_400, 2_200], "oldest goal first")
        let goal = try #require(goals.first)
        #expect(goal.id == rig.goal.id && goal.weightKg == 82 && goal.ageYears == 34)
        #expect(goal.sex == .male && goal.activity == .moderate && goal.goal == .lose)
        #expect(goal.proteinOverridden && !goal.caloriesOverridden)
        #expect(goals.last?.weightKg == nil && goals.last?.sex == nil)

        let weights = try #require(snapshot.bodyWeights)
        let pounds = try #require(weights.first)
        #expect(pounds.id == rig.weight.id && pounds.value == 180.4 && pounds.unit == .lb, "as entered")
        #expect(pounds.normalizedKg == 180.4 * WeightMath.kilogramsPerPound && pounds.source == .health)
        #expect(weights.last?.unit == .kg && weights.last?.healthSampleID == nil)

        let data = try ExportJSON.data(snapshot)
        #expect(try ExportJSON.decode(data) == snapshot)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("null"), "nil optionals are omitted on nutrition rows too")
        #expect(text.contains("\"schemaVersion\" : 12"))
    }

    @Test func nutritionDataLeavesTheCSVAsSetsAndCardio() throws {
        let context = try context()
        _ = try seed(context)
        let csv = ExportCSV.render(try collector.snapshot(from: context))
        #expect(try TestCSV.strictRows(csv) == [ExportCSV.header], "no workouts → the header alone")
    }

    @Test func anEmptyStoreExportsEmptyNutritionLists() throws {
        let snapshot = try collector.snapshot(from: try context())
        #expect(snapshot.foodEntries == [] && snapshot.savedFoods == [] && snapshot.savedMeals == [])
        #expect(snapshot.nutritionGoals == [] && snapshot.bodyWeights == [])
        #expect(snapshot.counts.foodEntries == 0 && snapshot.counts.bodyWeights == 0)
        #expect(try ExportJSON.decode(try ExportJSON.data(snapshot)) == snapshot)
    }

    /// A file written before nutrition has none of the v12 keys. It must still decode, its nutrition read as absent.
    @Test func aV11FileWithoutNutritionKeysStillDecodes() throws {
        let context = try context()
        _ = try seed(context)
        let v12 = try ExportJSON.data(try collector.snapshot(from: context))
        var object = try #require(try JSONSerialization.jsonObject(with: v12) as? [String: Any])
        for key in ["foodEntries", "savedFoods", "savedMeals", "nutritionGoals", "bodyWeights"] {
            #expect(object.removeValue(forKey: key) != nil, "\(key) was in the v12 file")
        }
        var counts = try #require(object["counts"] as? [String: Any])
        for key in ["foodEntries", "savedFoods", "savedMeals", "bodyWeights"] {
            #expect(counts.removeValue(forKey: key) != nil, "counts.\(key) was in the v12 file")
        }
        object["counts"] = counts
        object["schemaVersion"] = 11
        let v11 = try JSONSerialization.data(withJSONObject: object)

        let decoded = try ExportJSON.decode(v11)
        #expect(decoded.schemaVersion == 11)
        #expect(decoded.foodEntries == nil && decoded.savedFoods == nil && decoded.savedMeals == nil)
        #expect(decoded.nutritionGoals == nil && decoded.bodyWeights == nil)
        #expect(decoded.counts.foodEntries == nil && decoded.counts.bodyWeights == nil)
    }
}
