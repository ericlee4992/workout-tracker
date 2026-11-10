import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N4 (D81): logging by hand — one tap logs exactly one serving and Undo takes exactly it back, Selected food
/// and Manual Add log the numbers entered, My foods / Saved foods / My meals, and editing a food or a meal never changes
/// an entry already logged.
@MainActor
struct FoodLogTests {
    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private let now = Date(timeIntervalSince1970: 1_794_300_000)

    private func yogurt(_ context: ModelContext, lastUsed: Date? = nil) -> SavedFood {
        let food = SavedFood(name: "Greek yogurt", brand: "Fage", servingValue: 1, servingUnit: "container",
                             servingGrams: 170, calories: 100, proteinGrams: 18, carbsGrams: 6, fatGrams: 0.5,
                             fiberGrams: 0, sugarGrams: 6, saturatedFatGrams: 0.3, sodiumMilligrams: 65)
        food.lastUsedAt = lastUsed
        context.insert(food)
        return food
    }

    private func entries(_ context: ModelContext) throws -> [FoodEntry] {
        try context.fetch(FetchDescriptor<FoodEntry>())
    }

    // MARK: One tap and Undo

    @Test func oneTapLogsExactlyOneServingToTheChosenMeal() throws {
        let context = try context()
        let food = yogurt(context)
        let receipt = try FoodLog.log(food, meal: .snacks, at: now, source: .recent, in: context)
        let logged = try entries(context)
        #expect(logged.count == 1)
        let entry = try #require(logged.first)
        #expect(entry.servings == 1 && entry.meal == .snacks && entry.loggedAt == now && entry.source == .recent)
        #expect(entry.name == "Greek yogurt" && entry.brand == "Fage" && entry.calories == 100)
        #expect(entry.servingUnit == "container" && entry.servingGrams == 170 && entry.savedFood === food)
        #expect(food.lastUsedAt == now, "it moves to the top of Recently logged")
        #expect(receipt.title == "Greek yogurt" && receipt.calories == 100)
    }

    @Test func undoRemovesExactlyThatEntryAndPutsRecentBack() throws {
        let context = try context()
        let earlier = now.addingTimeInterval(-86_400)
        let food = yogurt(context, lastUsed: earlier)
        let first = try FoodLog.log(food, meal: .breakfast, at: now.addingTimeInterval(-60), in: context)
        let second = try FoodLog.log(food, meal: .breakfast, at: now, in: context)
        #expect(try entries(context).count == 2)
        try FoodLog.undo(second, in: context)
        let left = try entries(context)
        #expect(left.map(\.id) == first.entries.map(\.id), "the earlier log stays")
        #expect(food.lastUsedAt == now.addingTimeInterval(-60))
        try FoodLog.undo(first, in: context)
        #expect(try entries(context).isEmpty)
        #expect(food.lastUsedAt == earlier)
    }

    @Test func selectedFoodLogsTheServingsChosen() throws {
        let context = try context()
        let food = yogurt(context)
        try FoodLog.log(food, servings: 2.5, meal: .lunch, at: now, in: context)
        let entry = try #require(try entries(context).first)
        #expect(entry.servings == 2.5 && entry.calories == 100, "nutrition per serving, as stored")
        #expect(NutritionMath.totals(of: entry) == Macros(calories: 250, proteinGrams: 45, carbsGrams: 15,
                                                          fatGrams: 1.25))
    }

    // MARK: Manual Add

    @Test func manualAddLogsTheNumbersEnteredAndCreatesNoFood() throws {
        let context = try context()
        let receipt = try FoodLog.logManual(name: "  Chicken burrito ", serving: ServingText.parse("1 bowl"),
                                            nutrition: FoodNutrition(calories: 420, proteinGrams: 30, carbsGrams: 40,
                                                                     fatGrams: 12),
                                            meal: .dinner, at: now, in: context)
        let entry = try #require(try entries(context).first)
        #expect(entry.name == "Chicken burrito" && entry.source == .manual && entry.meal == .dinner)
        #expect(entry.servings == 1 && entry.servingValue == 1 && entry.servingUnit == "bowl")
        #expect(entry.calories == 420 && entry.proteinGrams == 30 && entry.carbsGrams == 40 && entry.fatGrams == 12)
        #expect(entry.savedFood == nil)
        #expect(try context.fetch(FetchDescriptor<SavedFood>()).isEmpty, "Manual Add creates no food (D81)")
        #expect(receipt.title == "Chicken burrito")
    }

    @Test func manualAddWithoutANameIsAQuickAdd() throws {
        let context = try context()
        let receipt = try FoodLog.logManual(name: " ", serving: nil, nutrition: FoodNutrition(calories: 250),
                                            meal: .snacks, at: now, in: context)
        let entry = try #require(try entries(context).first)
        #expect(entry.name.isEmpty && entry.source == .quickAdd)
        #expect(entry.servingValue == 1 && entry.servingUnit == "serving")
        #expect(entry.calories == 250 && entry.proteinGrams == 0)
        #expect(receipt.title == nil && FoodCopy.logged(receipt, to: .snacks) == "Logged 250 cal to Snacks")
    }

    // MARK: My foods and Saved foods

    @Test func addFoodMakesOneOfMyFoodsAndEditingLeavesPastEntries() throws {
        let context = try context()
        let draft = FoodDraft(brand: " ", name: " Overnight oats ", serving: ServingText.parse("1 jar (250 g)")!,
                              servingsPerContainer: nil,
                              nutrition: FoodNutrition(calories: 380, proteinGrams: 22, carbsGrams: 52, fatGrams: 9,
                                                       saturatedFatGrams: 2))
        let food = try FoodLog.createFood(draft, at: now, in: context)
        #expect(food.createdByUser && !food.isSaved && food.brand == nil && food.name == "Overnight oats")
        #expect(food.servingValue == 1 && food.servingUnit == "jar" && food.servingGrams == 250)
        #expect(food.saturatedFatGrams == 2 && food.fiberGrams == nil)
        #expect(FoodLog.mine([food]) == [food] && FoodLog.saved([food]).isEmpty)

        try FoodLog.log(food, meal: .breakfast, at: now, in: context)
        var edited = draft
        edited.name = "Overnight oats (big)"
        edited.servingsPerContainer = 2
        edited.nutrition.calories = 500
        try FoodLog.update(food, with: edited, in: context)
        #expect(food.name == "Overnight oats (big)" && food.calories == 500 && food.servingsPerContainer == 2)
        let entry = try #require(try entries(context).first)
        #expect(entry.name == "Overnight oats" && entry.calories == 380, "the entry is the food as eaten (N2)")
    }

    @Test func theBookmarkPutsAnyFoodInSavedFoods() throws {
        let context = try context()
        let food = yogurt(context)
        try FoodLog.setSaved(food, true, in: context)
        #expect(FoodLog.saved([food]) == [food] && FoodLog.mine([food]).isEmpty, "saved is not made by the user")
        try FoodLog.setSaved(food, false, in: context)
        #expect(FoodLog.saved([food]).isEmpty)
    }

    @Test func listsAreOrderedAsTheTabsShowThem() throws {
        let context = try context()
        let old = SavedFood(name: "banana", calories: 105)
        old.lastUsedAt = now.addingTimeInterval(-7_200)
        let new = SavedFood(name: "Apple", calories: 95, isSaved: true)
        new.lastUsedAt = now
        let never = SavedFood(name: "Zucchini bread", calories: 200, isSaved: true, createdByUser: true)
        let mine = SavedFood(name: "Avocado toast", calories: 300, createdByUser: true)
        let foods = [old, never, new, mine]
        foods.forEach(context.insert)
        #expect(FoodLog.recent(foods).map(\.name) == ["Apple", "banana"], "logged ones only, newest first")
        #expect(FoodLog.mine(foods).map(\.name) == ["Avocado toast", "Zucchini bread"])
        #expect(FoodLog.saved(foods).map(\.name) == ["Apple", "Zucchini bread"])
        #expect(FoodLog.all(foods).map(\.name) == ["Apple", "banana", "Avocado toast", "Zucchini bread"])
        #expect(FoodLog.matching(foods, "AN").map(\.name) == ["banana"])
        let fage = yogurt(context)
        #expect(FoodLog.matching([fage], "fage") == [fage], "the brand is searched too")
    }

    // MARK: My meals

    @Test func aMealLogsEachOfItsFoodsAndUndoTakesThemAllBack() throws {
        let context = try context()
        let food = yogurt(context)
        let banana = SavedFood(name: "Banana", servingValue: 1, servingUnit: "medium", calories: 105, carbsGrams: 27)
        context.insert(banana)
        var second = MealDraftItem(food: banana)
        second.servings = 2
        let meal = try FoodLog.saveMeal(nil, name: " Usual breakfast ", usualMeal: .breakfast,
                                        items: [MealDraftItem(food: food), second], at: now, in: context)
        #expect(meal.name == "Usual breakfast" && meal.usualMeal == .breakfast)
        #expect(meal.orderedItems.map(\.name) == ["Greek yogurt", "Banana"])
        #expect(meal.macros.calories == 310)

        let receipt = try FoodLog.log(meal, meal: .lunch, at: now, in: context)
        let logged = try entries(context).sorted { $0.name > $1.name }
        #expect(logged.map(\.name) == ["Greek yogurt", "Banana"])
        #expect(logged.allSatisfy { $0.meal == .lunch && $0.source == .myMeal }, "it logs to the chosen meal")
        #expect(logged.last?.servings == 2 && logged.last?.savedFood === banana)
        #expect(meal.lastUsedAt == now && receipt.title == "Usual breakfast" && receipt.calories == 310)
        try FoodLog.undo(receipt, in: context)
        #expect(try entries(context).isEmpty && meal.lastUsedAt == nil)
    }

    @Test func editingOrDeletingAMealLeavesWhatWasLogged() throws {
        let context = try context()
        let food = yogurt(context)
        let meal = try FoodLog.saveMeal(nil, name: "Snack", usualMeal: nil, items: [MealDraftItem(food: food)],
                                        at: now, in: context)
        try FoodLog.log(meal, meal: .snacks, at: now, in: context)
        var items = meal.orderedItems.map(MealDraftItem.init(item:))
        items[0].servings = 3
        try FoodLog.saveMeal(meal, name: "Big snack", usualMeal: .snacks, items: items, in: context)
        #expect(meal.name == "Big snack" && meal.orderedItems.map(\.servings) == [3])
        #expect(try context.fetch(FetchDescriptor<SavedMealItem>()).count == 1, "the old item is replaced, not kept")
        #expect(try entries(context).first?.servings == 1)

        try FoodLog.delete(meal, in: context)
        #expect(try context.fetch(FetchDescriptor<SavedMeal>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SavedMealItem>()).isEmpty, "its items go with it")
        #expect(try entries(context).count == 1 && (try context.fetch(FetchDescriptor<SavedFood>())).count == 1)
    }

    @Test func myMealsLeadWithTheChosenMealsOwn() throws {
        let lunch = SavedMeal(name: "Salad", usualMeal: .lunch)
        let any = SavedMeal(name: "Shake")
        any.lastUsedAt = now
        let breakfast = SavedMeal(name: "Oats", usualMeal: .breakfast)
        #expect(FoodLog.meals([lunch, any, breakfast], for: .breakfast).map(\.name) == ["Oats", "Shake", "Salad"])
        #expect(FoodLog.meals([lunch, any, breakfast], for: .lunch).map(\.name) == ["Salad", "Shake", "Oats"])
    }

    // MARK: Typed numbers and servings

    @Test func servingTextKeepsWhatWasTyped() {
        #expect(ServingText.parse("1 jar (250 g)") == ServingText(value: 1, unit: "jar", grams: 250))
        #expect(ServingText.parse("100 g") == ServingText(value: 100, unit: "g", grams: 100))
        #expect(ServingText.parse("1/2 cup") == ServingText(value: 0.5, unit: "cup"))
        #expect(ServingText.parse("1,5 slices") == ServingText(value: 1.5, unit: "slices"))
        #expect(ServingText.parse("jar") == ServingText(value: 1, unit: "jar"))
        #expect(ServingText.parse("2") == ServingText(value: 2, unit: "serving"))
        #expect(ServingText.parse("1 scoop (31 grams)") == ServingText(value: 1, unit: "scoop", grams: 31))
        #expect(ServingText.parse("  ") == nil)
        #expect(ServingText.format(value: 1, unit: "jar", grams: 250) == "1 jar (250 g)")
        #expect(ServingText.format(value: 100, unit: "g", grams: 100) == "100 g")
        #expect(ServingText.format(value: 0.5, unit: "cup", grams: nil) == "0.5 cup")
    }

    @Test func aServingThatIsNotAPositiveAmountIsRefused() {
        // codex-review-n4: these were stored as units ("1/0 cup" → 1 × "1/0 cup") or as infinity.
        for text in ["1/0 cup", "-2 g", "0 g", "0/2 cup", "1/2/3 cup", "+1 cup", ".", "1 cup (0 g)", "1 cup (-5 g)",
                     "999999/0.000001 g"] {
            #expect(ServingText.parse(text) == nil, "\(text)")
        }
        #expect(ServingText.parse("2 x 50 g") == ServingText(value: 2, unit: "x 50 g"), "digits inside a unit stay")
        #expect(ServingText.parse("cup (abc g)") == ServingText(value: 1, unit: "cup (abc g)"))
        #expect(ServingText.isBlank("  ") && !ServingText.isBlank("jar"))
    }

    @Test func editingOneFieldKeepsTheOthersExactly() throws {
        // codex-review-n4: a field shows its stored value rounded; unchanged, it saves the stored value, not the text.
        let third = EditableNumber(1.0 / 3)
        #expect(third.text == "0.33" && third.resolve("0.33") == .some(1.0 / 3))
        #expect(third.resolve("0.5") == .some(0.5) && third.resolve("") == .some(nil) && third.resolve("x") == nil)
        #expect(EditableNumber(nil).resolve("") == .some(nil))
        let serving = EditableServing(value: 1.0 / 3, unit: "cup", grams: 0.004)
        #expect(serving.text == "0.33 cup (0.004 g)")
        #expect(serving.resolve(serving.text) == ServingText(value: 1.0 / 3, unit: "cup", grams: 0.004))
        #expect(serving.resolve("2 cup") == ServingText(value: 2, unit: "cup"))
        #expect(EditableServing().resolve("") == nil)

        let context = try context()
        let food = try FoodLog.createFood(
            FoodDraft(name: "Rice", serving: ServingText(value: 1.0 / 3, unit: "cup"), servingsPerContainer: 2.75,
                      nutrition: FoodNutrition(calories: 68.333, proteinGrams: 1.4167)), at: now, in: context)
        let stored = EditableServing(value: food.servingValue, unit: food.servingUnit, grams: food.servingGrams)
        let calories = EditableNumber(food.calories), protein = EditableNumber(food.proteinGrams)
        let draft = FoodDraft(name: "Brown rice", serving: try #require(stored.resolve(stored.text)),
                              servingsPerContainer: EditableNumber(2.75).resolve("2.75") ?? nil,
                              nutrition: FoodNutrition(calories: try #require(calories.resolve(calories.text) ?? nil),
                                                       proteinGrams: try #require(protein.resolve(protein.text) ?? nil)))
        try FoodLog.update(food, with: draft, in: context)
        #expect(food.name == "Brown rice" && food.servingValue == 1.0 / 3 && food.calories == 68.333)
        #expect(food.proteinGrams == 1.4167 && food.servingsPerContainer == 2.75)
    }

    @Test func deletingOneOfMyFoodsKeepsWhatWasLoggedAndUndoStillWorks() throws {
        let context = try context()
        let food = yogurt(context)
        let meal = try FoodLog.saveMeal(nil, name: "Snack", usualMeal: nil, items: [MealDraftItem(food: food)],
                                        at: now, in: context)
        let receipt = try FoodLog.log(food, meal: .snacks, at: now, in: context)
        try FoodLog.delete(food, in: context)
        #expect(try context.fetch(FetchDescriptor<SavedFood>()).isEmpty)
        let entry = try #require(try entries(context).first)
        #expect(entry.name == "Greek yogurt" && entry.savedFood == nil, "the entry keeps its copy (.nullify)")
        #expect(meal.orderedItems.first?.name == "Greek yogurt" && meal.orderedItems.first?.savedFood == nil)
        try FoodLog.undo(receipt, in: context)
        #expect(try entries(context).isEmpty, "Undo after the food is gone still removes the entry")
    }

    @Test func typedNumbersReadACommaAndRefuseTheRest() {
        #expect(FoodNumber.parse("12,5") == 12.5 && FoodNumber.parse(" 30 ") == 30)
        #expect(FoodNumber.parse("") == nil && FoodNumber.parse("abc") == nil && FoodNumber.parse("-3") == nil)
        #expect(FoodNumber.text(nil) == "" && FoodNumber.text(1_200) == "1200" && FoodNumber.text(0.25) == "0.25")
        #expect(FoodNumber.optional("") == .some(nil) && FoodNumber.optional("4") == .some(4))
        #expect(FoodNumber.optional("x") == nil)
        #expect(FoodNumber.parse("1e3") == nil && FoodNumber.parse("1.2.3") == nil && FoodNumber.parse("+5") == nil,
                "plain digits only (codex-review-n4)")
        #expect(FoodNumber.parse("1000000") == 1_000_000 && FoodNumber.parse("1000001") == nil)
        #expect(FoodNumber.text(0.004) == "0.004" && FoodNumber.text(1.0 / 3) == "0.33", "small values never read as 0")
    }
}
