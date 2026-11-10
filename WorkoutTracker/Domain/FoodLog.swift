import Foundation
import SwiftData

// Nutrition N4: logging food by hand (D69, D81) — the user's foods and meals, one-tap logging with Undo, Add food,
// Manual Add, bookmarks and My meals. Pure SwiftData, no UI.
//
// Every log writes a `FoodEntry` snapshot (N2): editing or deleting a food or a meal afterwards never changes a past
// entry. Undo deletes exactly the entries a log wrote and restores the "last used" time it moved, so Recently logged
// reads as before.

/// A typed number as the food forms read it: a comma is a decimal separator; blank, negative or not a number is nil.
/// The text is never rewritten.
enum FoodNumber {
    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// A stored number for a form field: "12", "0.5"; blank for nil.
    static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

/// One serving as typed ("1 jar (250 g)", "100 g", "1/2 cup", "jar") and as stored: `(value, unit)` plus its grams
/// when known. The parse keeps what the user typed — the unit is the rest of the text, verbatim.
struct ServingText: Equatable {
    var value: Double
    var unit: String
    var grams: Double?

    static let defaultUnit = "serving"

    /// Nil for blank text. A text without a leading number is one of it ("jar" → 1 jar); "(250 g)" at the end gives the
    /// grams; a unit of g or grams is its own weight.
    static func parse(_ text: String) -> ServingText? {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else { return nil }
        var grams: Double?
        if let open = rest.lastIndex(of: "("), rest.hasSuffix(")") {
            let inside = rest[rest.index(after: open)..<rest.index(before: rest.endIndex)]
                .trimmingCharacters(in: .whitespaces).lowercased()
            for suffix in ["grams", "gram", "g"] where inside.hasSuffix(suffix) {
                if let value = FoodNumber.parse(String(inside.dropLast(suffix.count))), value > 0 {
                    grams = value
                    rest = String(rest[..<open]).trimmingCharacters(in: .whitespaces)
                }
                break
            }
        }
        let (number, unitText) = leadingNumber(of: rest)
        let unit = unitText.isEmpty ? defaultUnit : unitText
        let value = number ?? 1
        if grams == nil, ["g", "gram", "grams"].contains(unit.lowercased()) { grams = value }
        return ServingText(value: value, unit: unit, grams: grams)
    }

    /// "1 jar (250 g)", "100 g", "1 serving".
    static func format(value: Double, unit: String, grams: Double?) -> String {
        let amount = "\(FoodNumber.text(value)) \(unit)"
        guard let grams, !["g", "gram", "grams"].contains(unit.lowercased()) else { return amount }
        return "\(amount) (\(FoodNumber.text(grams)) g)"
    }

    /// A leading "1", "1.5", "1,5" or "1/2", and the rest of the text; nil when the text does not start with one.
    private static func leadingNumber(of text: String) -> (Double?, String) {
        let digits = text.prefix { $0.isNumber || $0 == "." || $0 == "," || $0 == "/" }
        guard !digits.isEmpty else { return (nil, text) }
        let rest = text.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        let parts = digits.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 2, let top = FoodNumber.parse(String(parts[0])), let bottom = FoodNumber.parse(String(parts[1])),
           bottom > 0 {
            return (top / bottom, rest)
        }
        guard parts.count == 1, let value = FoodNumber.parse(String(digits)), value > 0 else { return (nil, text) }
        return (value, rest)
    }
}

/// Nutrition per serving, as the forms collect it. Calories are required; the rest optional (macros 0 when blank).
struct FoodNutrition: Equatable {
    var calories: Double
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var saturatedFatGrams: Double?
    var fiberGrams: Double?
    var sugarGrams: Double?
    var sodiumMilligrams: Double?
}

/// What Add food / Edit food saves (D81): brand optional, a description (the food's name), one serving, optional
/// servings per container, and the nutrition of one serving.
struct FoodDraft: Equatable {
    var brand: String?
    var name: String
    var serving: ServingText
    var servingsPerContainer: Double?
    var nutrition: FoodNutrition
}

/// One food of a meal being created or edited: its own snapshot (like a `SavedMealItem`) and the food it came from.
struct MealDraftItem: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var brand: String?
    var servings: Double
    var servingValue: Double
    var servingUnit: String
    var servingGrams: Double?
    var nutrition: FoodNutrition
    var barcode: String?
    var savedFood: SavedFood?

    init(food: SavedFood, servings: Double = 1) {
        name = food.name
        brand = food.brand
        self.servings = servings
        servingValue = food.servingValue
        servingUnit = food.servingUnit
        servingGrams = food.servingGrams
        nutrition = FoodNutrition(food)
        barcode = food.barcode
        savedFood = food
    }

    init(item: SavedMealItem) {
        name = item.name
        brand = item.brand
        servings = item.servings
        servingValue = item.servingValue
        servingUnit = item.servingUnit
        servingGrams = item.servingGrams
        nutrition = FoodNutrition(calories: item.calories, proteinGrams: item.proteinGrams, carbsGrams: item.carbsGrams,
                                  fatGrams: item.fatGrams, saturatedFatGrams: item.saturatedFatGrams,
                                  fiberGrams: item.fiberGrams, sugarGrams: item.sugarGrams,
                                  sodiumMilligrams: item.sodiumMilligrams)
        barcode = item.barcode
        savedFood = item.savedFood
    }

    /// Calories for its servings.
    var calories: Double { nutrition.calories * servings }
}

extension FoodNutrition {
    init(_ food: SavedFood) {
        self.init(calories: food.calories, proteinGrams: food.proteinGrams, carbsGrams: food.carbsGrams,
                  fatGrams: food.fatGrams, saturatedFatGrams: food.saturatedFatGrams, fiberGrams: food.fiberGrams,
                  sugarGrams: food.sugarGrams, sodiumMilligrams: food.sodiumMilligrams)
    }
}

extension SavedFood {
    var macros: Macros {
        Macros(calories: calories, proteinGrams: proteinGrams, carbsGrams: carbsGrams, fatGrams: fatGrams)
    }

    var servingText: String { ServingText.format(value: servingValue, unit: servingUnit, grams: servingGrams) }
}

extension SavedMealItem {
    var servingText: String { ServingText.format(value: servingValue, unit: servingUnit, grams: servingGrams) }
}

extension SavedMeal {
    /// The meal's total: each item's nutrition × its servings.
    var macros: Macros {
        orderedItems.reduce(.zero) {
            $0 + Macros(calories: $1.calories, proteinGrams: $1.proteinGrams, carbsGrams: $1.carbsGrams,
                        fatGrams: $1.fatGrams).scaled(by: $1.servings)
        }
    }
}

/// What one log wrote, so Undo can take exactly it back.
struct FoodLogReceipt {
    /// "Greek yogurt", "Usual breakfast", or nil for a Manual Add without a name.
    var title: String?
    var calories: Double
    var entries: [FoodEntry]
    var food: SavedFood?
    var meal: SavedMeal?
    var previousLastUsedAt: Date?
}

enum FoodLog {

    // MARK: Lists (over the user's foods and meals, as the screens query them)

    /// Recently logged (All): the foods logged before, newest first.
    static func recent(_ foods: [SavedFood], limit: Int = 30) -> [SavedFood] {
        Array(foods.filter { $0.lastUsedAt != nil }.sorted(by: lastUsedFirst).prefix(limit))
    }

    /// My foods: the foods the user created, by name.
    static func mine(_ foods: [SavedFood]) -> [SavedFood] { foods.filter(\.createdByUser).sorted(by: byName) }

    /// Saved foods: the foods the user bookmarked, by name.
    static func saved(_ foods: [SavedFood]) -> [SavedFood] { foods.filter(\.isSaved).sorted(by: byName) }

    /// Every food (search on All, and Create meal's list): the logged ones newest first, then the rest by name.
    static func all(_ foods: [SavedFood]) -> [SavedFood] { foods.sorted(by: lastUsedFirst) }

    /// My meals: those usually for `meal` first, then the most recently logged, then by name.
    static func meals(_ meals: [SavedMeal], for meal: MealSlot) -> [SavedMeal] {
        meals.sorted { left, right in
            let leftFirst = left.usualMeal == meal, rightFirst = right.usualMeal == meal
            if leftFirst != rightFirst { return leftFirst }
            if left.lastUsedAt != right.lastUsedAt {
                return (left.lastUsedAt ?? .distantPast) > (right.lastUsedAt ?? .distantPast)
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    private static func byName(_ left: SavedFood, _ right: SavedFood) -> Bool {
        left.name.localizedStandardCompare(right.name) == .orderedAscending
    }

    private static func lastUsedFirst(_ left: SavedFood, _ right: SavedFood) -> Bool {
        switch (left.lastUsedAt, right.lastUsedAt) {
        case let (l?, r?) where l != r: l > r
        case (_?, nil): true
        case (nil, _?): false
        default: byName(left, right)
        }
    }

    /// The foods whose name or brand contains `text` (any case); all of them for blank text.
    static func matching(_ foods: [SavedFood], _ text: String) -> [SavedFood] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return foods }
        return foods.filter {
            $0.name.localizedCaseInsensitiveContains(query) || ($0.brand?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: Logging

    /// Logs `servings` of `food` to `meal`: one entry (a snapshot), and the food moves to the top of Recently logged.
    @discardableResult
    static func log(_ food: SavedFood, servings: Double = 1, meal: MealSlot, at date: Date = .now,
                    source: FoodSource = .saved, in context: ModelContext) throws -> FoodLogReceipt {
        let entry = FoodEntry(logging: food, servings: servings, meal: meal, at: date, source: source)
        context.insert(entry)
        let receipt = FoodLogReceipt(title: food.name, calories: food.calories * servings, entries: [entry], food: food,
                                     previousLastUsedAt: food.lastUsedAt)
        food.lastUsedAt = date
        try context.save()
        return receipt
    }

    /// Logs one of My meals to `meal`: one entry per item, from the item's own snapshot.
    @discardableResult
    static func log(_ savedMeal: SavedMeal, meal: MealSlot, at date: Date = .now,
                    in context: ModelContext) throws -> FoodLogReceipt {
        let entries = savedMeal.orderedItems.map { item in
            FoodEntry(loggedAt: date, meal: meal, name: item.name, brand: item.brand, servings: item.servings,
                      servingValue: item.servingValue, servingUnit: item.servingUnit, servingGrams: item.servingGrams,
                      calories: item.calories, proteinGrams: item.proteinGrams, carbsGrams: item.carbsGrams,
                      fatGrams: item.fatGrams, fiberGrams: item.fiberGrams, sugarGrams: item.sugarGrams,
                      saturatedFatGrams: item.saturatedFatGrams, sodiumMilligrams: item.sodiumMilligrams,
                      source: .myMeal, barcode: item.barcode, savedFood: item.savedFood, createdAt: date)
        }
        entries.forEach(context.insert)
        let receipt = FoodLogReceipt(title: savedMeal.name, calories: savedMeal.macros.calories, entries: entries,
                                     meal: savedMeal, previousLastUsedAt: savedMeal.lastUsedAt)
        savedMeal.lastUsedAt = date
        try context.save()
        return receipt
    }

    /// Manual Add (D81): a one-off entry that creates no food. The name is optional (blank = quick add); a blank serving
    /// is one serving.
    @discardableResult
    static func logManual(name: String, serving: ServingText?, nutrition: FoodNutrition, meal: MealSlot,
                          at date: Date = .now, in context: ModelContext) throws -> FoodLogReceipt {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let serving = serving ?? ServingText(value: 1, unit: ServingText.defaultUnit)
        let entry = FoodEntry(loggedAt: date, meal: meal, name: trimmed, servings: 1, servingValue: serving.value,
                              servingUnit: serving.unit, servingGrams: serving.grams, calories: nutrition.calories,
                              proteinGrams: nutrition.proteinGrams, carbsGrams: nutrition.carbsGrams,
                              fatGrams: nutrition.fatGrams, fiberGrams: nutrition.fiberGrams,
                              sugarGrams: nutrition.sugarGrams, saturatedFatGrams: nutrition.saturatedFatGrams,
                              sodiumMilligrams: nutrition.sodiumMilligrams,
                              source: trimmed.isEmpty ? .quickAdd : .manual, createdAt: date)
        context.insert(entry)
        try context.save()
        return FoodLogReceipt(title: trimmed.isEmpty ? nil : trimmed, calories: nutrition.calories, entries: [entry])
    }

    /// Undo: deletes the entries the log wrote and puts the food's or meal's "last used" back.
    static func undo(_ receipt: FoodLogReceipt, in context: ModelContext) throws {
        receipt.entries.forEach(context.delete)
        receipt.food?.lastUsedAt = receipt.previousLastUsedAt
        receipt.meal?.lastUsedAt = receipt.previousLastUsedAt
        try context.save()
    }

    // MARK: My foods and Saved foods

    /// Add food (D81): one of My foods.
    @discardableResult
    static func createFood(_ draft: FoodDraft, at date: Date = .now, in context: ModelContext) throws -> SavedFood {
        let food = SavedFood(name: draft.name, calories: draft.nutrition.calories, createdByUser: true, createdAt: date)
        apply(draft, to: food)
        food.updatedAt = date
        context.insert(food)
        try context.save()
        return food
    }

    /// Edit food: the food changes; entries already logged keep their own snapshot (N2).
    static func update(_ food: SavedFood, with draft: FoodDraft, at date: Date = .now, in context: ModelContext) throws {
        apply(draft, to: food)
        food.updatedAt = date
        try context.save()
    }

    /// The bookmark: in or out of Saved foods.
    static func setSaved(_ food: SavedFood, _ saved: Bool, in context: ModelContext) throws {
        food.isSaved = saved
        try context.save()
    }

    private static func apply(_ draft: FoodDraft, to food: SavedFood) {
        let brand = draft.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        food.brand = brand?.isEmpty == false ? brand : nil
        food.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        food.servingValue = draft.serving.value
        food.servingUnit = draft.serving.unit
        food.servingGrams = draft.serving.grams
        food.servingsPerContainer = draft.servingsPerContainer
        let n = draft.nutrition
        food.calories = n.calories
        food.proteinGrams = n.proteinGrams
        food.carbsGrams = n.carbsGrams
        food.fatGrams = n.fatGrams
        food.saturatedFatGrams = n.saturatedFatGrams
        food.fiberGrams = n.fiberGrams
        food.sugarGrams = n.sugarGrams
        food.sodiumMilligrams = n.sodiumMilligrams
    }

    // MARK: My meals

    /// Create meal (`existing` nil) or Edit meal: its name, the meal it is usually for, and its foods in order. Editing
    /// replaces the items; entries already logged from the meal are separate rows and stay as they were.
    @discardableResult
    static func saveMeal(_ existing: SavedMeal?, name: String, usualMeal: MealSlot?, items: [MealDraftItem],
                         at date: Date = .now, in context: ModelContext) throws -> SavedMeal {
        let meal = existing ?? SavedMeal(name: name, createdAt: date)
        if existing == nil { context.insert(meal) }
        meal.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        meal.usualMeal = usualMeal
        meal.updatedAt = date
        (meal.items ?? []).forEach(context.delete)
        meal.items = items.enumerated().map { order, draft in
            let n = draft.nutrition
            let item = SavedMealItem(order: order, name: draft.name, brand: draft.brand, servings: draft.servings,
                                     servingValue: draft.servingValue, servingUnit: draft.servingUnit,
                                     servingGrams: draft.servingGrams, calories: n.calories,
                                     proteinGrams: n.proteinGrams, carbsGrams: n.carbsGrams, fatGrams: n.fatGrams,
                                     fiberGrams: n.fiberGrams, sugarGrams: n.sugarGrams,
                                     saturatedFatGrams: n.saturatedFatGrams, sodiumMilligrams: n.sodiumMilligrams,
                                     barcode: draft.barcode, savedFood: draft.savedFood)
            context.insert(item)
            return item
        }
        try context.save()
        return meal
    }

    /// Delete Meal…: the meal and its items (`.cascade`); entries logged from it stay.
    static func delete(_ meal: SavedMeal, in context: ModelContext) throws {
        context.delete(meal)
        try context.save()
    }
}
