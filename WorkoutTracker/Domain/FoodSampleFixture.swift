import Foundation
import SwiftData

/// Nutrition N4's UI tests and captures (`-uiTestFoodSample`, with `-uiTestReset`): the user's foods and two meals, as
/// the approved mock showed them. Recently logged comes from each food's "last used" time; no entry is written, so
/// Today stays empty. Requires `-uiTestReset` (`WorkoutTrackerStore.fixtureIsEnabled`), so it never seeds a real store.
enum FoodSampleFixture {
    static let launchArgument = "-uiTestFoodSample"

    static var isEnabled: Bool { WorkoutTrackerStore.fixtureIsEnabled(launchArgument) }

    static func seed(in context: ModelContext, now: Date = .now) throws {
        func food(_ name: String, brand: String? = nil, serving: String, _ calories: Double, _ protein: Double,
                  _ carbs: Double, _ fat: Double, saturatedFat: Double? = nil, fiber: Double? = nil,
                  sugar: Double? = nil, sodium: Double? = nil, perContainer: Double? = nil, mine: Bool = false,
                  saved: Bool = false, hoursAgo: Double?) -> SavedFood {
            let parsed = ServingText.parse(serving)!
            let food = SavedFood(name: name, brand: brand, servingValue: parsed.value, servingUnit: parsed.unit,
                                 servingGrams: parsed.grams, calories: calories, proteinGrams: protein,
                                 carbsGrams: carbs, fatGrams: fat, fiberGrams: fiber, sugarGrams: sugar,
                                 saturatedFatGrams: saturatedFat, sodiumMilligrams: sodium, isSaved: saved,
                                 createdByUser: mine, servingsPerContainer: perContainer,
                                 createdAt: now.addingTimeInterval(-30 * 86_400))
            food.lastUsedAt = hoursAgo.map { now.addingTimeInterval(-$0 * 3_600) }
            context.insert(food)
            return food
        }
        _ = food("Greek yogurt", brand: "Fage", serving: "1 container (170 g)", 100, 18, 6, 0.5, saturatedFat: 0.3,
                 fiber: 0, sugar: 6, sodium: 65, saved: true, hoursAgo: 1)
        let oats = food("Overnight oats", serving: "1 jar", 380, 22, 52, 9, saturatedFat: 2, fiber: 8, sugar: 14,
                        sodium: 120, mine: true, saved: true, hoursAgo: 2)
        _ = food("Chicken breast", serving: "100 g", 165, 31, 0, 3.6, saturatedFat: 1, sodium: 74, saved: true,
                 hoursAgo: 20)
        let banana = food("Banana", serving: "1 medium", 105, 1.3, 27, 0.4, fiber: 3.1, sugar: 14, hoursAgo: 24)
        let shake = food("Protein shake", brand: "Optimum", serving: "1 scoop (31 g)", 120, 24, 3, 1.5,
                         perContainer: 74, saved: true, hoursAgo: 30)
        _ = food("Turkey chili", serving: "1 bowl", 420, 38, 34, 14, saturatedFat: 4, fiber: 9, sodium: 780,
                 perContainer: 6, mine: true, hoursAgo: 50)
        _ = food("Protein pancakes", serving: "3 pancakes", 310, 28, 30, 8, mine: true, hoursAgo: nil)
        try FoodLog.saveMeal(nil, name: "Usual breakfast", usualMeal: .breakfast,
                             items: [MealDraftItem(food: oats), MealDraftItem(food: banana)], at: now, in: context)
        try FoodLog.saveMeal(nil, name: "Post-workout", usualMeal: nil,
                             items: [MealDraftItem(food: shake), MealDraftItem(food: banana)], at: now, in: context)
    }
}
