import Foundation
import SwiftData

// Nutrition N4: logging food by hand (D69, D81) — the user's foods and meals, one-tap logging with Undo, Add food,
// Manual Add, bookmarks and My meals. Pure SwiftData, no UI.
//
// Every log writes a `FoodEntry` snapshot (N2): editing or deleting a food or a meal afterwards never changes a past
// entry. Undo deletes exactly the entries a log wrote and restores the "last used" time it moved, so Recently logged
// reads as before.

/// A typed number as the food forms read it: digits with at most one decimal separator (a comma is one); blank,
/// negative, scientific notation, anything else, or more than a million is nil. The text is never rewritten.
enum FoodNumber {
    static let maximum = 1_000_000.0

    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard cleaned.contains(where: \.isWholeNumberDigit),
              cleaned.allSatisfy({ $0.isWholeNumberDigit || $0 == "." }),
              cleaned.filter({ $0 == "." }).count <= 1,
              let value = Double(cleaned), value.isFinite, value <= maximum else { return nil }
        return value
    }

    /// A form's optional number: `.some(nil)` when blank, `.some(value)` when a number, nil when it is not a number.
    static func optional(_ text: String) -> Double?? {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? .some(nil) : parse(text).map { .some($0) }
    }

    /// A stored number for reading: "12", "0.5", "0.33"; a small non-zero value keeps two significant digits
    /// ("0.004"), so it never reads as 0. Blank for nil.
    static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        if value != 0, abs(value) < 0.01 {
            return value.formatted(.number.precision(.significantDigits(1...2)).grouping(.never))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

private extension Character {
    var isWholeNumberDigit: Bool { ("0"..."9").contains(self) }
}

/// A stored number in an edit form (codex-review-n4): the field shows it rounded for reading, and an unchanged field
/// keeps the stored value exactly — editing one field never rewrites another (the entered value is kept).
struct EditableNumber {
    let value: Double?
    let text: String

    init(_ value: Double?) {
        self.value = value
        text = FoodNumber.text(value)
    }

    /// `.some(stored)` when the field is unchanged; else as `FoodNumber.optional` reads the text.
    func resolve(_ current: String) -> Double?? { current == text ? .some(value) : FoodNumber.optional(current) }
}

/// One serving as typed ("1 jar (250 g)", "100 g", "1/2 cup", "jar") and as stored: `(value, unit)` plus its grams
/// when known. The parse keeps what the user typed — the unit is the rest of the text, verbatim.
struct ServingText: Equatable {
    var value: Double
    var unit: String
    var grams: Double?

    static let defaultUnit = "serving"

    static func isBlank(_ text: String) -> Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Nil for blank text and for an amount that is not a positive number ("1/0 cup", "-2 g", "0 g"). A text that
    /// starts with a letter is one of it ("jar" → 1 jar); "(250 g)" at the end gives the grams; a unit of g or grams
    /// is its own weight.
    static func parse(_ text: String) -> ServingText? {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else { return nil }
        var grams: Double?
        if let open = rest.lastIndex(of: "("), rest.hasSuffix(")") {
            let inside = rest[rest.index(after: open)..<rest.index(before: rest.endIndex)]
                .trimmingCharacters(in: .whitespaces).lowercased()
            if let suffix = ["grams", "gram", "g"].first(where: { inside.hasSuffix($0) }) {
                let amount = String(inside.dropLast(suffix.count))
                if let value = FoodNumber.parse(amount), value > 0 {
                    grams = value
                    rest = String(rest[..<open]).trimmingCharacters(in: .whitespaces)
                } else if startsAsNumber(amount.trimmingCharacters(in: .whitespaces)) {
                    return nil  // "(0 g)", "(-5 g)": a weight that is not one
                }
            }
        }
        let value: Double
        let unitText: String
        if startsAsNumber(rest) {
            guard let (number, remainder) = leadingNumber(of: rest) else { return nil }
            value = number
            unitText = remainder
        } else {
            value = 1
            unitText = rest
        }
        let unit = unitText.isEmpty ? defaultUnit : unitText
        if grams == nil, ["g", "gram", "grams"].contains(unit.lowercased()) { grams = value }
        return ServingText(value: value, unit: unit, grams: grams)
    }

    /// "1 jar (250 g)", "100 g", "1 serving".
    static func format(value: Double, unit: String, grams: Double?) -> String {
        let amount = "\(FoodNumber.text(value)) \(unit)"
        guard let grams, !["g", "gram", "grams"].contains(unit.lowercased()) else { return amount }
        return "\(amount) (\(FoodNumber.text(grams)) g)"
    }

    private static func startsAsNumber(_ text: String) -> Bool {
        guard let first = text.first else { return false }
        return first.isWholeNumberDigit || ".,-+".contains(first)
    }

    /// A leading "1", "1.5", "1,5" or "1/2" — positive and finite — and the rest of the text; nil when the amount is
    /// not one.
    private static func leadingNumber(of text: String) -> (Double, String)? {
        let digits = text.prefix { $0.isWholeNumberDigit || $0 == "." || $0 == "," || $0 == "/" }
        let rest = text.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        let parts = digits.split(separator: "/", omittingEmptySubsequences: false)
        let value: Double
        switch parts.count {
        case 1:
            guard let number = FoodNumber.parse(String(digits)) else { return nil }
            value = number
        case 2:
            guard let top = FoodNumber.parse(String(parts[0])), let bottom = FoodNumber.parse(String(parts[1])),
                  bottom > 0 else { return nil }
            value = top / bottom
        default:
            return nil
        }
        guard value.isFinite, value > 0, value <= FoodNumber.maximum else { return nil }
        return (value, rest)
    }
}

/// A stored serving in the Edit food form: unchanged text keeps the stored `(value, unit, grams)` exactly.
struct EditableServing {
    let serving: ServingText?
    let text: String

    init(value: Double, unit: String, grams: Double?) {
        serving = ServingText(value: value, unit: unit, grams: grams)
        text = ServingText.format(value: value, unit: unit, grams: grams)
    }

    init() {
        serving = nil
        text = ""
    }

    func resolve(_ current: String) -> ServingText? { current == text ? serving : ServingText.parse(current) }
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
    /// Not one of the user's foods: never logged, bookmarked or made by the user. N8: a food from a database that was
    /// only opened. N15: a food saved from an entry or a photo's item and then un-saved (it has no database id) — it
    /// leaves the lists rather than lingering in All, and is not deleted (entries linked to it keep the link).
    var isCachedLookup: Bool { !createdByUser && !isSaved && lastUsedAt == nil }

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

    /// Every food (search on All, and Create meal's list): the logged ones newest first, then the rest by name. A
    /// database food only opened, never logged or bookmarked (N8), is a cached lookup, not one of the user's foods.
    static func all(_ foods: [SavedFood]) -> [SavedFood] { foods.filter { !$0.isCachedLookup }.sorted(by: lastUsedFirst) }

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

    // MARK: Servings (N8)

    /// The servings `food` can be logged by: its own, then its other servings that have a weight — only when its own
    /// has one too, since the others' nutrition is scaled by weight from it. The first is the food's own.
    static func servingChoices(_ food: SavedFood) -> [ServingOption] {
        let main = ServingOption(value: food.servingValue, unit: food.servingUnit, grams: food.servingGrams)
        guard food.servingGrams != nil else { return [main] }
        return [main] + food.servingOptions.filter { $0 != main && scale(of: $0, in: food) != nil }
    }

    /// One serving of `option` as a multiple of the food's own serving, by weight; nil when either has none.
    static func scale(of option: ServingOption, in food: SavedFood) -> Double? {
        guard let grams = option.grams, grams > 0, let base = food.servingGrams, base > 0 else { return nil }
        return grams / base
    }

    // MARK: Logging

    /// Logs `servings` of `food` to `meal`: one entry (a snapshot), and the food moves to the top of Recently logged.
    /// `option` (N8): one of the food's other servings (`servingChoices`) — the entry then keeps that serving, its
    /// nutrition scaled by weight from the main serving.
    @discardableResult
    static func log(_ food: SavedFood, servings: Double = 1, option: ServingOption? = nil, meal: MealSlot,
                    at date: Date = .now, source: FoodSource = .saved, in context: ModelContext) throws -> FoodLogReceipt {
        let entry = FoodEntry(logging: food, servings: servings, meal: meal, at: date, source: source)
        if let option, let factor = scale(of: option, in: food) {
            entry.servingValue = option.value
            entry.servingUnit = option.unit
            entry.servingGrams = option.grams
            entry.calories = food.calories * factor
            entry.proteinGrams = food.proteinGrams * factor
            entry.carbsGrams = food.carbsGrams * factor
            entry.fatGrams = food.fatGrams * factor
            entry.saturatedFatGrams = food.saturatedFatGrams.map { $0 * factor }
            entry.fiberGrams = food.fiberGrams.map { $0 * factor }
            entry.sugarGrams = food.sugarGrams.map { $0 * factor }
            entry.sodiumMilligrams = food.sodiumMilligrams.map { $0 * factor }
        }
        context.insert(entry)
        let receipt = FoodLogReceipt(title: food.name, calories: entry.calories * servings, entries: [entry], food: food,
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
        receipt.entries.filter(\.isLive).forEach(context.delete)
        // The food or meal may have been deleted since the log; then there is no "last used" to put back.
        if let food = receipt.food, food.isLive { food.lastUsedAt = receipt.previousLastUsedAt }
        if let meal = receipt.meal, meal.isLive { meal.lastUsedAt = receipt.previousLastUsedAt }
        try context.save()
    }

    // MARK: Logged entries (N5: Today's log)

    /// Edit a logged entry (N5): how many servings, which meal, and its numbers per serving. Its food and its other
    /// numbers (fiber, sugar, …) stay; a later Health sync (N9) follows `updatedAt`.
    static func update(_ entry: FoodEntry, servings: Double, meal: MealSlot, calories: Double, proteinGrams: Double,
                       carbsGrams: Double, fatGrams: Double, at date: Date = .now, in context: ModelContext) throws {
        entry.servings = servings
        entry.meal = meal
        entry.calories = calories
        entry.proteinGrams = proteinGrams
        entry.carbsGrams = carbsGrams
        entry.fatGrams = fatGrams
        entry.updatedAt = date
        try context.save()
    }

    /// Delete a logged entry (N5), returning what Undo needs to put it back as it was.
    static func delete(_ entry: FoodEntry, in context: ModelContext) throws -> DeletedEntry {
        let copy = DeletedEntry(entry)
        context.delete(entry)
        try context.save()
        return copy
    }

    /// Undo of a delete: the same entry again — same id, numbers, times and, while it exists, its food.
    @discardableResult
    static func restore(_ copy: DeletedEntry, in context: ModelContext) throws -> FoodEntry {
        let entry = FoodEntry(
            id: copy.id, loggedAt: copy.loggedAt, meal: copy.meal, name: copy.name, brand: copy.brand,
            servings: copy.servings, servingValue: copy.servingValue, servingUnit: copy.servingUnit,
            servingGrams: copy.servingGrams, calories: copy.calories, proteinGrams: copy.proteinGrams,
            carbsGrams: copy.carbsGrams, fatGrams: copy.fatGrams, fiberGrams: copy.fiberGrams,
            sugarGrams: copy.sugarGrams, saturatedFatGrams: copy.saturatedFatGrams,
            sodiumMilligrams: copy.sodiumMilligrams, source: copy.source, barcode: copy.barcode,
            savedFood: copy.savedFood.flatMap { $0.isLive ? $0 : nil }, createdAt: copy.createdAt)
        entry.updatedAt = copy.updatedAt
        entry.healthSampleID = copy.healthSampleID
        context.insert(entry)
        if let photo = copy.photo { entry.photo = FoodPhoto(data: photo) }
        entry.items = copy.items.enumerated().map { index, item in
            FoodEntryItem(id: item.id, order: index, name: item.name, portion: item.portion, grams: item.grams,
                          calories: item.calories, proteinGrams: item.protein, carbsGrams: item.carbs, fatGrams: item.fat)
        }
        try context.save()
        return entry
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

    /// Delete Food… (the user, 2026-11-10: My foods can be deleted): the food goes; entries logged from it and meal
    /// items made from it keep their own copy (`.nullify`).
    static func delete(_ food: SavedFood, in context: ModelContext) throws {
        context.delete(food)
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

private extension PersistentModel {
    /// Still in a context and not deleted (after a save, a deleted model leaves its context).
    var isLive: Bool { modelContext != nil && !isDeleted }
}

/// A deleted entry's every field, held for Undo (N5).
struct DeletedEntry {
    var id: UUID
    var loggedAt: Date
    var meal: MealSlot
    var name: String
    var brand: String?
    var servings: Double
    var servingValue: Double
    var servingUnit: String
    var servingGrams: Double?
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?
    var sugarGrams: Double?
    var saturatedFatGrams: Double?
    var sodiumMilligrams: Double?
    var source: FoodSource
    var barcode: String?
    var healthSampleID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var savedFood: SavedFood?
    /// N7: a scanned meal's photo and items come back with it.
    var photo: Data?
    var items: [FoodEstimate.Item]

    init(_ entry: FoodEntry) {
        id = entry.id
        loggedAt = entry.loggedAt
        meal = entry.meal
        name = entry.name
        brand = entry.brand
        servings = entry.servings
        servingValue = entry.servingValue
        servingUnit = entry.servingUnit
        servingGrams = entry.servingGrams
        calories = entry.calories
        proteinGrams = entry.proteinGrams
        carbsGrams = entry.carbsGrams
        fatGrams = entry.fatGrams
        fiberGrams = entry.fiberGrams
        sugarGrams = entry.sugarGrams
        saturatedFatGrams = entry.saturatedFatGrams
        sodiumMilligrams = entry.sodiumMilligrams
        source = entry.source
        barcode = entry.barcode
        healthSampleID = entry.healthSampleID
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        savedFood = entry.savedFood
        photo = entry.photoData
        items = FoodScan.editable(entry)
    }
}
