import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N2: the models' defaults and history rules, and `NutritionMath`.
@MainActor
struct NutritionModelTests {
    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    @Test func defaultsAreOneServingAndManual() {
        let entry = FoodEntry(meal: .lunch, name: "Apple", calories: 95)
        #expect(entry.servings == 1)
        #expect(entry.servingValue == 1 && entry.servingUnit == "serving")
        #expect(entry.source == .manual)
        #expect(entry.proteinGrams == 0 && entry.fiberGrams == nil)
        #expect(SavedFood(name: "Apple", calories: 95).isSaved == false)
    }

    @Test func anEntryIsTheFoodAsEatenEvenAfterTheFoodChangesOrGoes() throws {
        let context = try context()
        let food = SavedFood(name: "Oats", servingValue: 40, servingUnit: "g", servingGrams: 40,
                             calories: 150, proteinGrams: 5, carbsGrams: 27, fatGrams: 3, isSaved: true)
        context.insert(food)
        let entry = FoodEntry(logging: food, servings: 2, meal: .breakfast, at: date(9, 8))
        context.insert(entry)
        try context.save()
        #expect(entry.savedFood === food && entry.source == .saved)

        food.name = "Rolled oats"
        food.calories = 999
        try context.save()
        #expect(entry.name == "Oats" && entry.calories == 150, "an edit of the food leaves the entry as eaten")

        context.delete(food)
        try context.save()
        let kept = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        #expect(kept.savedFood == nil, "the link is cleared, the entry stays")
        #expect(kept.name == "Oats" && NutritionMath.totals(of: kept).calories == 300)
    }

    @Test func deletingASavedMealTakesItsItemsButNotTheFoods() throws {
        let context = try context()
        let food = SavedFood(name: "Banana", calories: 105, isSaved: true)
        let meal = SavedMeal(name: "Usual breakfast", usualMeal: .breakfast)
        context.insert(food)
        context.insert(meal)
        let item = SavedMealItem(order: 0, name: "Banana", calories: 105, savedFood: food)
        item.meal = meal
        context.insert(item)
        try context.save()
        #expect(meal.orderedItems.map(\.name) == ["Banana"])
        context.delete(meal)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SavedMealItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SavedFood>()) == 1)
    }

    @Test func totalsAreTheServingTimesServings() {
        let entry = FoodEntry(meal: .dinner, name: "Rice", servings: 1.5, calories: 200, proteinGrams: 4,
                              carbsGrams: 44, fatGrams: 0.4)
        let totals = NutritionMath.totals(of: entry)
        #expect(totals.calories == 300 && totals.proteinGrams == 6 && totals.carbsGrams == 66)
        #expect(abs(totals.fatGrams - 0.6) < 1e-9)
    }

    @Test func dayAndMealTotalsCountOnlyThatLocalDay() {
        let entries = [
            FoodEntry(loggedAt: date(9, 7), meal: .breakfast, name: "Eggs", servings: 2, calories: 70, proteinGrams: 6),
            FoodEntry(loggedAt: date(9, 13), meal: .lunch, name: "Wrap", calories: 450, proteinGrams: 30),
            FoodEntry(loggedAt: date(9, 23), meal: .snacks, name: "Bar", calories: 200, proteinGrams: 20),
            FoodEntry(loggedAt: date(10, 1), meal: .snacks, name: "Next day", calories: 999),
        ]
        let day = NutritionMath.dayTotals(entries, on: date(9, 12), calendar: calendar)
        #expect(day.calories == 790 && day.proteinGrams == 62)
        let meals = NutritionMath.mealTotals(entries, on: date(9, 12), calendar: calendar)
        #expect(meals[.breakfast]?.calories == 140)
        #expect(meals[.dinner] == nil, "a meal with nothing logged is absent, not zero")
    }

    @Test func macroCaloriesAreFourFourNine() {
        #expect(NutritionMath.macroCalories(proteinGrams: 10, carbsGrams: 20, fatGrams: 5) == 165)
    }

    @Test func servingsFromGramsNeedTheServingsWeight() {
        #expect(NutritionMath.servings(forGrams: 60, servingGrams: 40) == 1.5)
        #expect(NutritionMath.servings(forGrams: 60, servingGrams: nil) == nil)
        #expect(NutritionMath.servings(forGrams: 60, servingGrams: 0) == nil)
    }

    @Test func aPastDayKeepsTheGoalItHad() {
        let first = NutritionGoal(effectiveFrom: date(1, 9), calories: 2200, proteinGrams: 150, carbsGrams: 230, fatGrams: 70)
        let second = NutritionGoal(effectiveFrom: date(9, 15), calories: 2000, proteinGrams: 160, carbsGrams: 190, fatGrams: 65)
        #expect(NutritionMath.goal(on: date(5, 12), among: [first, second], calendar: calendar) === first)
        #expect(NutritionMath.goal(on: date(9, 8), among: [first, second], calendar: calendar) === second,
                "a goal set during a day applies to that whole day")
        #expect(NutritionMath.goal(on: date(10, 8), among: [first, second], calendar: calendar) === second)
        #expect(NutritionMath.goal(on: Calendar.current.date(byAdding: .month, value: -2, to: date(1, 9))!,
                                   among: [first, second], calendar: calendar) == nil)
    }

    @Test func bodyWeightKeepsTheEnteredUnitAndKilograms() {
        let weight = BodyWeightEntry(measuredAt: date(9, 7), value: 180, unit: .lb)
        #expect(weight.value == 180 && weight.unit == .lb)
        #expect(abs(weight.normalizedKg - 81.6466) < 0.001)
        weight.set(value: 80, unit: .kg)
        #expect(weight.normalizedKg == 80)
    }

    @Test func servingOptionsThatCannotBeReadAreNone() {
        let food = SavedFood(name: "x", calories: 1)
        food.servingOptionsData = Data("not json".utf8)
        #expect(food.servingOptions.isEmpty)
        food.servingOptions = []
        #expect(food.servingOptionsData == nil)
    }
}
