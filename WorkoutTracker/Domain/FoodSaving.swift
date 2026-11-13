import Foundation
import SwiftData

/// Nutrition N15 (D87): save any food you open — a Today log entry, a meal photo's item, a meal photo as a meal.
///
/// No stored-format change: a food saved from an entry is an ordinary `SavedFood` (`isSaved`, neither made by the user
/// — it belongs in Saved foods, not My foods, D81 — nor from a database), and a meal is an ordinary `SavedMeal`.
///
/// - An entry is linked to the food behind it (`FoodEntry.savedFood`): one from a real food (search, barcode, My foods,
///   a recent food) bookmarks that food; one with none (photo, description, label, Manual Add) gets a NEW food made from
///   it and is linked to it, so a second tap finds that food and never makes a duplicate.
/// - A photo's item and a photo meal have no link field (adding one would change the stored format, Gate S), so they
///   find their saved copy by CONTENT: the same name, serving and numbers. Edit the item after saving and it reads as
///   not saved; saving again then makes a second food — the honest reading of "this exact food is not in Saved foods".
/// - Un-saving takes a food out of Saved foods (`isSaved` false) and deletes nothing: entries keep their own copy, and
///   a food that was only ever a saved copy leaves every list (`SavedFood.isCachedLookup`). A meal has no saved flag —
///   My meals IS the saved list — so un-saving a meal deletes that meal; entries logged from it stay (D81).
enum FoodSaving {

    // MARK: An entry

    /// The entry's food is in Saved foods.
    static func isSaved(_ entry: FoodEntry) -> Bool {
        guard let food = entry.savedFood, isLive(food) else { return false }
        return food.isSaved
    }

    /// The bookmark on an entry: in or out of Saved foods. `name` is the name on screen ("Manual Add" for a nameless
    /// entry); `perServing` the numbers on screen, so the food saved is the one the user is looking at.
    @discardableResult
    static func toggle(_ entry: FoodEntry, name: String, perServing: FoodNutrition, at date: Date = .now,
                       in context: ModelContext) throws -> SavedFood {
        if let food = entry.savedFood, isLive(food) {
            food.isSaved.toggle()
            food.updatedAt = date
            try context.save()
            return food
        }
        let food = SavedFood(
            name: name, brand: entry.brand, barcode: entry.barcode, servingValue: entry.servingValue,
            servingUnit: entry.servingUnit, servingGrams: entry.servingGrams, calories: perServing.calories,
            proteinGrams: perServing.proteinGrams, carbsGrams: perServing.carbsGrams, fatGrams: perServing.fatGrams,
            fiberGrams: perServing.fiberGrams, sugarGrams: perServing.sugarGrams,
            saturatedFatGrams: perServing.saturatedFatGrams, sodiumMilligrams: perServing.sodiumMilligrams,
            isSaved: true, createdAt: date)
        context.insert(food)
        entry.savedFood = food
        try context.save()
        return food
    }

    // MARK: A photo's item

    /// The saved copy of `item`, if one exists: a food saved from an item (not the user's, not a database's) with the
    /// same name, serving and numbers.
    static func savedFood(for item: FoodEstimate.Item, in context: ModelContext) -> SavedFood? {
        let draft = food(from: item)
        let foods = (try? context.fetch(FetchDescriptor<SavedFood>())) ?? []
        return foods.first { candidate in
            !candidate.createdByUser && candidate.databaseID == nil && sameContent(candidate, draft)
        }
    }

    static func isSaved(_ item: FoodEstimate.Item, in context: ModelContext) -> Bool {
        savedFood(for: item, in: context)?.isSaved == true
    }

    /// The bookmark on a photo's item: its saved copy in or out of Saved foods, or a new one.
    static func toggle(_ item: FoodEstimate.Item, at date: Date = .now, in context: ModelContext) throws {
        if let food = savedFood(for: item, in: context) {
            food.isSaved.toggle()
            food.updatedAt = date
        } else {
            let food = food(from: item)
            food.isSaved = true
            food.createdAt = date
            food.updatedAt = date
            context.insert(food)
        }
        try context.save()
    }

    /// An item as a food: its name; one serving of its portion ("1 cup" → 1 cup, blank → 1 serving) with its weight;
    /// the item's numbers for that serving. Not inserted.
    static func food(from item: FoodEstimate.Item) -> SavedFood {
        let serving = ServingText.parse(item.portion) ?? ServingText(value: 1, unit: ServingText.defaultUnit)
        return SavedFood(
            name: item.name.trimmingCharacters(in: .whitespacesAndNewlines), servingValue: serving.value,
            servingUnit: serving.unit, servingGrams: serving.grams ?? item.grams, calories: item.calories,
            proteinGrams: item.protein, carbsGrams: item.carbs, fatGrams: item.fat)
    }

    // MARK: A photo meal

    /// The meal in My meals that is this one: the same name and the same items in order (each item one serving of its
    /// portion, as `food(from:)`).
    static func savedMeal(name: String, items: [FoodEstimate.Item], in context: ModelContext) -> SavedMeal? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let wanted = items.map(food(from:))
        let meals = (try? context.fetch(FetchDescriptor<SavedMeal>())) ?? []
        return meals.first { meal in
            let have = meal.orderedItems
            return meal.name == trimmed && have.count == wanted.count
                && zip(have, wanted).allSatisfy { item, food in item.servings == 1 && sameContent(item, food) }
        }
    }

    /// The bookmark on a photo meal: saved as one meal in My meals (its items, one serving each, usually for the meal
    /// it was logged to), or — already there — taken out of My meals.
    static func toggleMeal(name: String, meal: MealSlot, items: [FoodEstimate.Item], at date: Date = .now,
                           in context: ModelContext) throws {
        if let existing = savedMeal(name: name, items: items, in: context) {
            try FoodLog.delete(existing, in: context)
            return
        }
        let drafts = items.map { item in
            var draft = MealDraftItem(food: food(from: item))
            draft.savedFood = nil   // the food above is a template, never inserted
            return draft
        }
        try FoodLog.saveMeal(nil, name: name, usualMeal: meal, items: drafts, at: date, in: context)
    }

    // MARK: Helpers

    private static func isLive(_ model: some PersistentModel) -> Bool { model.modelContext != nil && !model.isDeleted }

    private static func sameContent(_ food: SavedFood, _ other: SavedFood) -> Bool {
        food.name == other.name && food.servingValue == other.servingValue && food.servingUnit == other.servingUnit
            && food.servingGrams == other.servingGrams && food.calories == other.calories
            && food.proteinGrams == other.proteinGrams && food.carbsGrams == other.carbsGrams
            && food.fatGrams == other.fatGrams
    }

    private static func sameContent(_ item: SavedMealItem, _ food: SavedFood) -> Bool {
        item.name == food.name && item.servingValue == food.servingValue && item.servingUnit == food.servingUnit
            && item.servingGrams == food.servingGrams && item.calories == food.calories
            && item.proteinGrams == food.proteinGrams && item.carbsGrams == food.carbsGrams
            && item.fatGrams == food.fatGrams
    }
}
