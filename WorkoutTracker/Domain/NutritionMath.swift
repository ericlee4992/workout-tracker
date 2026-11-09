import Foundation

/// Calories and the three macros, as a value — a day's total, a meal's, one entry's.
struct Macros: Equatable {
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0

    static let zero = Macros()

    static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(calories: lhs.calories + rhs.calories, proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
               carbsGrams: lhs.carbsGrams + rhs.carbsGrams, fatGrams: lhs.fatGrams + rhs.fatGrams)
    }

    func scaled(by factor: Double) -> Macros {
        Macros(calories: calories * factor, proteinGrams: proteinGrams * factor,
               carbsGrams: carbsGrams * factor, fatGrams: fatGrams * factor)
    }
}

/// Nutrition N2: the arithmetic every food screen shares. Pure; no store access.
enum NutritionMath {
    /// Energy per gram of each macro (the Atwater factors): protein 4, carbohydrate 4, fat 9.
    static let caloriesPerGramProtein = 4.0
    static let caloriesPerGramCarbs = 4.0
    static let caloriesPerGramFat = 9.0

    /// The calories the three macros account for — the day rings' protein · carbs · fat split (N5).
    static func macroCalories(proteinGrams: Double, carbsGrams: Double, fatGrams: Double) -> Double {
        proteinGrams * caloriesPerGramProtein + carbsGrams * caloriesPerGramCarbs + fatGrams * caloriesPerGramFat
    }

    /// One entry's totals: its per-serving nutrition × the servings eaten.
    static func totals(of entry: FoodEntry) -> Macros {
        Macros(calories: entry.calories, proteinGrams: entry.proteinGrams, carbsGrams: entry.carbsGrams,
               fatGrams: entry.fatGrams).scaled(by: entry.servings)
    }

    /// The entries that count towards the local day containing `day`.
    static func entries(_ entries: [FoodEntry], on day: Date, calendar: Calendar = .current) -> [FoodEntry] {
        entries.filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
    }

    static func dayTotals(_ entries: [FoodEntry], on day: Date, calendar: Calendar = .current) -> Macros {
        self.entries(entries, on: day, calendar: calendar).reduce(.zero) { $0 + totals(of: $1) }
    }

    /// Each meal's totals for the day; a meal with nothing logged is absent (not zero).
    static func mealTotals(_ entries: [FoodEntry], on day: Date, calendar: Calendar = .current) -> [MealSlot: Macros] {
        self.entries(entries, on: day, calendar: calendar).reduce(into: [:]) { result, entry in
            result[entry.meal, default: .zero] = result[entry.meal, default: .zero] + totals(of: entry)
        }
    }

    /// How many servings `grams` is, when a serving's weight is known (logging by weight).
    static func servings(forGrams grams: Double, servingGrams: Double?) -> Double? {
        guard let servingGrams, servingGrams > 0, grams >= 0 else { return nil }
        return grams / servingGrams
    }

    /// The goal in force on the local day containing `day`: the latest one effective by the end of that day. A past
    /// day keeps the goal it had (D70); nil before the first goal.
    static func goal(on day: Date, among goals: [NutritionGoal], calendar: Calendar = .current) -> NutritionGoal? {
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else { return nil }
        return goals
            .filter { $0.effectiveFrom < endOfDay }
            .max { ($0.effectiveFrom, $0.createdAt) < ($1.effectiveFrom, $1.createdAt) }
    }
}
