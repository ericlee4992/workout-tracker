import Foundation
import SwiftData

/// Nutrition N4's UI tests and captures (`-uiTestFoodSample`, with `-uiTestReset`): the user's foods and two meals, as
/// the approved mock showed them. Recently logged comes from each food's "last used" time; no entry is written, so
/// Today stays empty. Requires `-uiTestReset` (`WorkoutTrackerStore.fixtureIsEnabled`), so it never seeds a real store.
enum FoodSampleFixture {
    static let launchArgument = "-uiTestFoodSample"

    static var isEnabled: Bool { WorkoutTrackerStore.fixtureIsEnabled(launchArgument) }

    /// N5's Today captures (`-uiTestFoodDiary`, with `-uiTestFoodSample`): today's breakfast and lunch, a calories-only
    /// snack, and the earlier days of this week logged. With `-uiTestFoodOver` too: a big dinner takes today over
    /// the goal.
    static let diaryArgument = "-uiTestFoodDiary"
    static let overArgument = "-uiTestFoodOver"
    static var diaryIsEnabled: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains(diaryArgument)
    }

    static func seedDiary(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        let foods = try context.fetch(FetchDescriptor<SavedFood>())
        func food(_ name: String) -> SavedFood? { foods.first { $0.name == name } }
        let today = calendar.startOfDay(for: now)
        func at(_ day: Date, _ hour: Double) -> Date { day.addingTimeInterval(hour * 3_600) }
        // Today: up to now, so nothing sits in the future.
        let hour = min(Double(calendar.component(.hour, from: now)), 23)
        // Each a little after the last, in the order listed, even early in the day.
        func earlier(_ wanted: Double) -> Date { at(today, min(wanted, max(0, hour - 0.5)) + wanted / 100) }
        if let oats = food("Overnight oats") {
            context.insert(FoodEntry(logging: oats, meal: .breakfast, at: earlier(7.5)))
        }
        if let banana = food("Banana") {
            context.insert(FoodEntry(logging: banana, meal: .breakfast, at: earlier(7.6)))
        }
        if let chicken = food("Chicken breast") {
            context.insert(FoodEntry(logging: chicken, servings: 2, meal: .lunch, at: earlier(12.5)))
        }
        context.insert(FoodEntry(loggedAt: earlier(15), meal: .snacks, name: "", calories: 250, source: .quickAdd,
                                 createdAt: earlier(15)))
        if ProcessInfo.processInfo.arguments.contains(overArgument), let chili = food("Turkey chili") {
            context.insert(FoodEntry(logging: chili, servings: 5, meal: .dinner, at: earlier(19)))
        }
        // The earlier days of this week: a full day of a few foods each.
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        // With `-uiTestPersonalDetails` (seeded first) the goal starts today; back-date it so the week's rings fill
        // toward it too.
        for goal in try context.fetch(FetchDescriptor<NutritionGoal>()) where goal.effectiveFrom > weekStart {
            goal.effectiveFrom = calendar.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart
        }
        var day = weekStart
        var index = 0
        while day < today {
            let picks: [(String, Double, MealSlot)] = index % 3 == 2
                ? [("Greek yogurt", 1, .breakfast), ("Turkey chili", 2, .dinner)]
                : [("Overnight oats", 1, .breakfast), ("Chicken breast", 2.5, .lunch), ("Turkey chili", 2, .dinner),
                   ("Protein shake", 1, .snacks)]
            for (offset, pick) in picks.enumerated() {
                if let food = food(pick.0) {
                    context.insert(FoodEntry(logging: food, servings: pick.1, meal: pick.2,
                                             at: at(day, 8 + Double(offset) * 4)))
                }
            }
            index += 1
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? today
        }
        try context.save()
    }

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
