import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Nutrition N15 (D87) — save any food you open: an entry's food, a new food from an entry with none, a photo's item,
/// and a photo meal as one meal in My meals; un-saving deletes nothing logged; no duplicates.
struct FoodSavingTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private func foods(_ context: ModelContext) throws -> [SavedFood] { try context.fetch(FetchDescriptor<SavedFood>()) }
    private func meals(_ context: ModelContext) throws -> [SavedMeal] { try context.fetch(FetchDescriptor<SavedMeal>()) }

    private func nutrition(_ entry: FoodEntry) -> FoodNutrition {
        FoodNutrition(calories: entry.calories, proteinGrams: entry.proteinGrams, carbsGrams: entry.carbsGrams,
                      fatGrams: entry.fatGrams, saturatedFatGrams: entry.saturatedFatGrams,
                      fiberGrams: entry.fiberGrams, sugarGrams: entry.sugarGrams,
                      sodiumMilligrams: entry.sodiumMilligrams)
    }

    // MARK: An entry

    /// An entry logged from a real food bookmarks THAT food — no new food.
    @Test func anEntryFromAFoodBookmarksThatFood() throws {
        let context = try context()
        let banana = SavedFood(name: "Banana", servingUnit: "medium", calories: 105, carbsGrams: 27)
        context.insert(banana)
        let entry = FoodEntry(logging: banana, meal: .breakfast, at: now)
        context.insert(entry)
        try context.save()
        #expect(!FoodSaving.isSaved(entry))

        let saved = try FoodSaving.toggle(entry, name: "Banana", perServing: nutrition(entry), at: now, in: context)
        #expect(saved === banana && banana.isSaved && FoodSaving.isSaved(entry))
        #expect(try foods(context).count == 1)

        try FoodSaving.toggle(entry, name: "Banana", perServing: nutrition(entry), at: now, in: context)
        #expect(!banana.isSaved && !FoodSaving.isSaved(entry))
        #expect(try foods(context).count == 1, "un-saving deletes nothing")
    }

    /// An entry with no food (photo, description, label, Manual Add) gets a new food made from it — its name, serving
    /// and the numbers on screen — in Saved foods, not My foods; tapped again it is the same food, never a second.
    @Test func anEntryWithNoFoodMakesOneAndNeverDuplicates() throws {
        let context = try context()
        let entry = FoodEntry(loggedAt: now, meal: .lunch, name: "Kimchi stew", brand: "Mom's", servings: 2,
                              servingValue: 1, servingUnit: "bowl", servingGrams: 400, calories: 380,
                              proteinGrams: 20, carbsGrams: 18, fatGrams: 22, sodiumMilligrams: 1_900,
                              source: .manual, barcode: "880123")
        context.insert(entry)
        try context.save()

        var onScreen = nutrition(entry)
        onScreen.calories = 400   // edited in the sheet, not yet saved there
        let food = try FoodSaving.toggle(entry, name: "Kimchi stew", perServing: onScreen, at: now, in: context)
        #expect(food.name == "Kimchi stew" && food.brand == "Mom's" && food.barcode == "880123")
        #expect(food.servingValue == 1 && food.servingUnit == "bowl" && food.servingGrams == 400)
        #expect(food.calories == 400 && food.proteinGrams == 20 && food.sodiumMilligrams == 1_900)
        #expect(food.isSaved && !food.createdByUser && food.databaseID == nil, "Saved foods, not My foods (D81)")
        #expect(entry.savedFood === food && FoodSaving.isSaved(entry))
        #expect(FoodLog.saved([food]) == [food] && FoodLog.mine([food]).isEmpty)

        try FoodSaving.toggle(entry, name: "Kimchi stew", perServing: onScreen, at: now, in: context)
        #expect(!FoodSaving.isSaved(entry) && entry.savedFood === food, "un-saved, still linked")
        try FoodSaving.toggle(entry, name: "Kimchi stew", perServing: onScreen, at: now, in: context)
        #expect(FoodSaving.isSaved(entry))
        #expect(try foods(context).count == 1, "the same food each time")
    }

    /// Un-saved, a food that only ever was a saved copy leaves every list (it is not lingering in All or Create meal's
    /// list), and nothing is deleted.
    @Test func anUnsavedCopyLeavesTheListsButStays() throws {
        let context = try context()
        let entry = FoodEntry(loggedAt: now, meal: .snacks, name: "", calories: 250, source: .quickAdd)
        context.insert(entry)
        try context.save()
        let food = try FoodSaving.toggle(entry, name: "Manual Add", perServing: nutrition(entry), at: now, in: context)
        #expect(food.name == "Manual Add", "a nameless entry is saved under the name on screen")
        #expect(FoodLog.all([food]) == [food])
        try FoodSaving.toggle(entry, name: "Manual Add", perServing: nutrition(entry), at: now, in: context)
        #expect(FoodLog.all([food]).isEmpty && FoodLog.saved([food]).isEmpty && FoodLog.recent([food]).isEmpty)
        #expect(try foods(context).count == 1 && entry.savedFood === food)
    }

    // MARK: A photo's item

    private let tuna = FoodEstimate.Item(name: "Tuna poke", portion: "1 cup", grams: 150, calories: 250, protein: 26,
                                         carbs: 4, fat: 14)

    @Test func anItemSavesAsAFoodByItsPortion() throws {
        let context = try context()
        #expect(!FoodSaving.isSaved(tuna, in: context))
        try FoodSaving.toggle(tuna, at: now, in: context)
        let food = try #require(try foods(context).first)
        #expect(food.name == "Tuna poke" && food.servingValue == 1 && food.servingUnit == "cup" && food.servingGrams == 150)
        #expect(food.calories == 250 && food.proteinGrams == 26 && food.carbsGrams == 4 && food.fatGrams == 14)
        #expect(food.isSaved && !food.createdByUser)
        #expect(FoodSaving.isSaved(tuna, in: context))

        try FoodSaving.toggle(tuna, at: now, in: context)
        #expect(!FoodSaving.isSaved(tuna, in: context))
        try FoodSaving.toggle(tuna, at: now, in: context)
        #expect(try foods(context).count == 1, "found again by content, never a second")

        // A blank portion is one serving.
        var rice = tuna
        rice.name = "Rice"; rice.portion = ""; rice.grams = nil
        #expect(FoodSaving.food(from: rice).servingUnit == "serving" && FoodSaving.food(from: rice).servingValue == 1)
    }

    /// Edited after saving, the item is another food: it reads as not saved (the user's choice: no link field).
    @Test func anEditedItemReadsAsNotSaved() throws {
        let context = try context()
        try FoodSaving.toggle(tuna, at: now, in: context)
        var edited = tuna
        edited.calories = 270
        #expect(!FoodSaving.isSaved(edited, in: context))
    }

    /// One of My foods with the same content is the user's own food, not the item's saved copy.
    @Test func theUsersOwnFoodIsNotAnItemsCopy() throws {
        let context = try context()
        let mine = FoodSaving.food(from: tuna)
        mine.createdByUser = true
        mine.isSaved = true
        context.insert(mine)
        try context.save()
        #expect(!FoodSaving.isSaved(tuna, in: context))
    }

    // MARK: A photo meal

    @Test func aMealPhotoSavesAsOneMealAndUnsavesByDeletingIt() throws {
        let context = try context()
        let rice = FoodEstimate.Item(name: "Rice", portion: "1 cup", grams: 160, calories: 200, protein: 4, carbs: 44,
                                     fat: 0.5)
        let items = [tuna, rice]
        #expect(FoodSaving.savedMeal(name: "Poke bowl", items: items, in: context) == nil)

        try FoodSaving.toggleMeal(name: "Poke bowl", meal: .lunch, items: items, at: now, in: context)
        let meal = try #require(try meals(context).first)
        #expect(meal.name == "Poke bowl" && meal.usualMeal == .lunch)
        #expect(meal.orderedItems.map(\.name) == ["Tuna poke", "Rice"])
        #expect(meal.orderedItems.map(\.servings) == [1, 1])
        #expect(meal.macros.calories == 450)
        #expect(FoodSaving.savedMeal(name: "Poke bowl", items: items, in: context) === meal)
        #expect(try foods(context).isEmpty, "saving the meal saves no foods")

        try FoodSaving.toggleMeal(name: "Poke bowl", meal: .lunch, items: items, at: now, in: context)
        #expect(try meals(context).isEmpty, "taken out of My meals")
    }

    @Test func aMealIsFoundOnlyWithTheSameNameAndItems() throws {
        let context = try context()
        try FoodSaving.toggleMeal(name: "Poke bowl", meal: .lunch, items: [tuna], at: now, in: context)
        #expect(FoodSaving.savedMeal(name: "Poke bowl ", items: [tuna], in: context) != nil, "the name is trimmed")
        #expect(FoodSaving.savedMeal(name: "Salad", items: [tuna], in: context) == nil)
        var edited = tuna
        edited.fat = 15
        #expect(FoodSaving.savedMeal(name: "Poke bowl", items: [edited], in: context) == nil)
    }
}
