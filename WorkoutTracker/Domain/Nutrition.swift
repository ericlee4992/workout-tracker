import Foundation
import SwiftData

// Nutrition N2: the stored data for food, goals and body weight (D69–D74, D78). CloudKit-compatible like every model:
// UUID ids, defaults on every stored property, optional relationships, no unique constraints.
//
// A logged food is history: each `FoodEntry` keeps its own copy of the name, serving and nutrition, so editing or
// deleting a saved food never changes a past day. Links from an entry (or a meal item) to the food it came from are
// `.nullify`; a saved meal owns its items (`.cascade`).
//
// Nutrition on entries, saved foods and meal items is stored PER SERVING; an entry's totals are per serving × servings
// (`NutritionMath`). Every number an AI or a database proposed is stored as a plain, editable number — no "estimated"
// flag (D78); `source` keeps where the entry came from.

/// The four meals of a day (Log Food's chips).
enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks
    var id: String { rawValue }
}

/// Where a food entry came from. Stored; renaming a case strands old rows (`StoreFormatGuardTests`).
enum FoodSource: String, Codable, CaseIterable {
    case manual, quickAdd, saved, recent, myMeal, barcode, search, photo, label, describe
}

/// The direction of a nutrition goal (D70).
enum WeightGoal: String, Codable, CaseIterable {
    case lose, maintain, gain
}

/// Activity factor for the energy estimate (N3).
enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary, light, moderate, veryActive, extraActive
}

/// For the resting-energy formula only (N3); `unspecified` is "Prefer not to say".
enum BiologicalSex: String, Codable, CaseIterable {
    case male, female, unspecified
}

/// Where a body weight came from (N9: the app's own entry or Apple Health).
/// N3 (D80): the unit a height was entered in (Personal details). Stored; renaming a case strands old rows.
enum HeightUnit: String, Codable, CaseIterable {
    case cm
    case inches = "in"
}

enum BodyWeightSource: String, Codable, CaseIterable {
    case app, health
}

/// One alternative serving of a saved food ("1 cup", "100 g"), kept as JSON in `SavedFood.servingOptionsData`.
struct ServingOption: Codable, Equatable, Hashable {
    var value: Double
    var unit: String
    var grams: Double?
}

// MARK: - Food entry

@Model
final class FoodEntry {
    var id: UUID = UUID()
    /// When it was eaten (the day it counts towards is this instant's local day).
    var loggedAt: Date = Date()
    var meal: MealSlot = MealSlot.breakfast
    var name: String = ""
    var brand: String?
    /// How many servings were eaten.
    var servings: Double = 1
    /// One serving as the user entered or the source gave it: `(value, unit)`, and its grams when known.
    var servingValue: Double = 1
    var servingUnit: String = "serving"
    var servingGrams: Double?
    // Per serving.
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double?
    var sugarGrams: Double?
    var saturatedFatGrams: Double?
    var sodiumMilligrams: Double?
    var source: FoodSource = FoodSource.manual
    var barcode: String?
    /// The Apple Health sample this entry wrote (N9), so an edit or a delete follows it there.
    var healthSampleID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// The saved food it came from; `.nullify` from the food's side, so the entry outlives it.
    var savedFood: SavedFood?
    /// N7 (D82): a scanned meal's photo, kept on the phone with its entry (the JPEG sent for the estimate, ≤ 1568 px) and
    /// deleted with it (`.cascade`). Its own row INSIDE the database file — not `.externalStorage`, whose files beside
    /// the store the safety copy (N1) does not carry (codex-review-n7 T1) — and a relationship, so fetching entries
    /// (Today queries them all) never loads photo bytes until a thumbnail asks. Not in the JSON export.
    @Relationship(deleteRule: .cascade, inverse: \FoodPhoto.entry)
    var photo: FoodPhoto?

    /// The photo's JPEG, if the entry has one.
    var photoData: Data? { photo?.data }
    /// N7 (D83): a scanned meal or a description is ONE entry named for the meal; these are its items, each editable.
    /// Owned rows: `.cascade`, so deleting the entry deletes them. The entry's numbers are their sum (one serving).
    @Relationship(deleteRule: .cascade, inverse: \FoodEntryItem.entry)
    var items: [FoodEntryItem]? = []

    /// The items in their order; empty for an entry logged any other way.
    var orderedItems: [FoodEntryItem] { (items ?? []).sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) } }

    init(
        id: UUID = UUID(), loggedAt: Date = .now, meal: MealSlot, name: String, brand: String? = nil,
        servings: Double = 1, servingValue: Double = 1, servingUnit: String = "serving", servingGrams: Double? = nil,
        calories: Double, proteinGrams: Double = 0, carbsGrams: Double = 0, fatGrams: Double = 0,
        fiberGrams: Double? = nil, sugarGrams: Double? = nil, saturatedFatGrams: Double? = nil,
        sodiumMilligrams: Double? = nil, source: FoodSource = .manual, barcode: String? = nil,
        savedFood: SavedFood? = nil, createdAt: Date = .now
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.meal = meal
        self.name = name
        self.brand = brand
        self.servings = servings
        self.servingValue = servingValue
        self.servingUnit = servingUnit
        self.servingGrams = servingGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.saturatedFatGrams = saturatedFatGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.source = source
        self.barcode = barcode
        self.savedFood = savedFood
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Logs `food`: a snapshot of its name, serving and nutrition, so a later edit or delete of the food leaves this
    /// entry as it was eaten.
    convenience init(logging food: SavedFood, servings: Double = 1, meal: MealSlot, at date: Date = .now,
                     source: FoodSource = .saved) {
        self.init(loggedAt: date, meal: meal, name: food.name, brand: food.brand, servings: servings,
                  servingValue: food.servingValue, servingUnit: food.servingUnit, servingGrams: food.servingGrams,
                  calories: food.calories, proteinGrams: food.proteinGrams, carbsGrams: food.carbsGrams,
                  fatGrams: food.fatGrams, fiberGrams: food.fiberGrams, sugarGrams: food.sugarGrams,
                  saturatedFatGrams: food.saturatedFatGrams, sodiumMilligrams: food.sodiumMilligrams,
                  source: source, barcode: food.barcode, savedFood: food, createdAt: date)
    }
}

// MARK: - Food photo (N7)

/// A scanned meal's photo (D82), owned by its entry. The bytes live in the database row so a safety copy is complete.
@Model
final class FoodPhoto {
    var id: UUID = UUID()
    var data: Data?
    var entry: FoodEntry?

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
    }
}

// MARK: - Food entry item (N7)

/// One item of a scanned meal or a description (N7, D83): what the estimate said, as the user corrected it. Its entry's
/// numbers are the sum of its items.
@Model
final class FoodEntryItem {
    var id: UUID = UUID()
    var order: Int = 0
    var name: String = ""
    /// The portion in everyday words ("1 cup").
    var portion: String = ""
    var grams: Double?
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var entry: FoodEntry?

    init(id: UUID = UUID(), order: Int, name: String, portion: String, grams: Double?, calories: Double,
         proteinGrams: Double, carbsGrams: Double, fatGrams: Double) {
        self.id = id
        self.order = order
        self.name = name
        self.portion = portion
        self.grams = grams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
    }
}

// MARK: - Saved food

@Model
final class SavedFood {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String?
    var barcode: String?
    /// A food database's identity for a cached hit (N8), e.g. `off:3017620422003` or `usda:171705`.
    var databaseID: String?
    var servingValue: Double = 1
    var servingUnit: String = "serving"
    var servingGrams: Double?
    // Per serving.
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double?
    var sugarGrams: Double?
    var saturatedFatGrams: Double?
    var sodiumMilligrams: Double?
    /// Other servings the food can be logged by: `[ServingOption]` as JSON. nil = only the main serving.
    var servingOptionsData: Data?
    /// In Saved foods: bookmarked by the user from anywhere (D81). N2 read it as "in My foods"; nothing shipped with that
    /// meaning (nutrition ships at R), so no row needs rewriting.
    var isSaved: Bool = false
    /// In My foods: created by the user with Add food (D81). False for foods cached from a scan or a search (N7/N8).
    var createdByUser: Bool = false
    /// How many servings a package holds, when the user gave it (Add food, optional; D81).
    var servingsPerContainer: Double?
    var lastUsedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \FoodEntry.savedFood)
    var entries: [FoodEntry]? = []
    @Relationship(deleteRule: .nullify, inverse: \SavedMealItem.savedFood)
    var mealItems: [SavedMealItem]? = []

    init(
        id: UUID = UUID(), name: String, brand: String? = nil, barcode: String? = nil, databaseID: String? = nil,
        servingValue: Double = 1, servingUnit: String = "serving", servingGrams: Double? = nil,
        calories: Double, proteinGrams: Double = 0, carbsGrams: Double = 0, fatGrams: Double = 0,
        fiberGrams: Double? = nil, sugarGrams: Double? = nil, saturatedFatGrams: Double? = nil,
        sodiumMilligrams: Double? = nil, isSaved: Bool = false, createdByUser: Bool = false,
        servingsPerContainer: Double? = nil, createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.databaseID = databaseID
        self.servingValue = servingValue
        self.servingUnit = servingUnit
        self.servingGrams = servingGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.saturatedFatGrams = saturatedFatGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.isSaved = isSaved
        self.createdByUser = createdByUser
        self.servingsPerContainer = servingsPerContainer
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// The other servings (decoded; an unreadable payload reads as none, never as a crash).
    var servingOptions: [ServingOption] {
        get { servingOptionsData.flatMap { try? JSONDecoder().decode([ServingOption].self, from: $0) } ?? [] }
        set { servingOptionsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }
}

// MARK: - My meals

/// "My meals": a named group of foods logged together in one tap (the user, 2026-11-09).
@Model
final class SavedMeal {
    var id: UUID = UUID()
    var name: String = ""
    /// The meal chip it usually goes to; nil = whichever the user is logging.
    var usualMeal: MealSlot?
    var lastUsedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SavedMealItem.meal)
    var items: [SavedMealItem]? = []

    init(id: UUID = UUID(), name: String, usualMeal: MealSlot? = nil, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.usualMeal = usualMeal
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var orderedItems: [SavedMealItem] { (items ?? []).sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) } }
}

/// One food in a saved meal: its own snapshot (like a log entry), so the meal still logs the same food after the saved
/// food it came from is edited or deleted.
@Model
final class SavedMealItem {
    var id: UUID = UUID()
    var order: Int = 0
    var name: String = ""
    var brand: String?
    var servings: Double = 1
    var servingValue: Double = 1
    var servingUnit: String = "serving"
    var servingGrams: Double?
    // Per serving.
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double?
    var sugarGrams: Double?
    var saturatedFatGrams: Double?
    var sodiumMilligrams: Double?
    var barcode: String?
    var meal: SavedMeal?
    var savedFood: SavedFood?

    init(id: UUID = UUID(), order: Int, name: String, brand: String? = nil, servings: Double = 1,
         servingValue: Double = 1, servingUnit: String = "serving", servingGrams: Double? = nil,
         calories: Double, proteinGrams: Double = 0, carbsGrams: Double = 0, fatGrams: Double = 0,
         fiberGrams: Double? = nil, sugarGrams: Double? = nil, saturatedFatGrams: Double? = nil,
         sodiumMilligrams: Double? = nil, barcode: String? = nil, savedFood: SavedFood? = nil) {
        self.id = id
        self.order = order
        self.name = name
        self.brand = brand
        self.servings = servings
        self.servingValue = servingValue
        self.servingUnit = servingUnit
        self.servingGrams = servingGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.saturatedFatGrams = saturatedFatGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.barcode = barcode
        self.savedFood = savedFood
    }
}

// MARK: - Goals

/// A daily nutrition goal, in force from `effectiveFrom` until the next one (D70): a change makes a new goal, so a past
/// day is judged against the goal it had (frozen history).
@Model
final class NutritionGoal {
    var id: UUID = UUID()
    var effectiveFrom: Date = Date()
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    // The inputs it was calculated from (N3); nil when typed without a calculation.
    var weightKg: Double?
    var heightCm: Double?
    var ageYears: Int?
    var sex: BiologicalSex?
    var activity: ActivityLevel?
    var goal: WeightGoal?
    // Numbers the user typed over the calculation; they stay when the inputs change (N3).
    var caloriesOverridden: Bool = false
    var proteinOverridden: Bool = false
    var carbsOverridden: Bool = false
    var fatOverridden: Bool = false
    var createdAt: Date = Date()
    // N13 (D84): the goal setup's desired weight as entered `(value, unit)` with its kg (D52), and the pace in kg a
    // week. nil for maintain, for a goal made before N13 (it keeps N3's fixed −500 / +250 adjustment) or typed only.
    // Additive optionals: SwiftData migrates 0.2.0's store lightweightly (`GoalSetupMigrationTests`).
    var desiredWeightValue: Double?
    var desiredWeightUnit: WeightUnit?
    var desiredWeightKg: Double?
    var paceKgPerWeek: Double?

    init(id: UUID = UUID(), effectiveFrom: Date, calories: Double, proteinGrams: Double, carbsGrams: Double,
         fatGrams: Double, createdAt: Date = .now) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.createdAt = createdAt
    }
}

// MARK: - Body weight

/// One body weight (N9). Keeps the entered `(value, unit)` and `normalizedKg`, like every stored weight (D25, D52).
@Model
final class BodyWeightEntry {
    var id: UUID = UUID()
    var measuredAt: Date = Date()
    var value: Double = 0
    var unit: WeightUnit = WeightUnit.kg
    var normalizedKg: Double = 0
    var source: BodyWeightSource = BodyWeightSource.app
    var healthSampleID: UUID?
    var createdAt: Date = Date()

    init(id: UUID = UUID(), measuredAt: Date, value: Double, unit: WeightUnit, source: BodyWeightSource = .app,
         healthSampleID: UUID? = nil, createdAt: Date = .now) {
        self.id = id
        self.measuredAt = measuredAt
        self.value = value
        self.unit = unit
        self.normalizedKg = WeightMath.normalizedKg(value: value, unit: unit)
        self.source = source
        self.healthSampleID = healthSampleID
        self.createdAt = createdAt
    }

    /// Changes the weight, keeping `normalizedKg` in step (never set one without the other).
    func set(value: Double, unit: WeightUnit) {
        self.value = value
        self.unit = unit
        normalizedKg = WeightMath.normalizedKg(value: value, unit: unit)
    }
}
