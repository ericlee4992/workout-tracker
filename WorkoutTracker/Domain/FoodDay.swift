import Foundation

// Nutrition N5: what Today shows of a day's food — the totals, the goal in force that day, what is left or over, the
// calories burned (shown beside, never added: D71) and the ring's fill in the macros' calorie shares. Pure; the
// screens pass in the entries, goals and workouts they query.

/// The goal numbers in force on a day (a dated `NutritionGoal`, D70), copied so the view holds no model.
struct DayGoal: Equatable {
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    init(calories: Double, proteinGrams: Double, carbsGrams: Double, fatGrams: Double) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
    }

    init(_ goal: NutritionGoal) {
        self.init(calories: goal.calories, proteinGrams: goal.proteinGrams, carbsGrams: goal.carbsGrams,
                  fatGrams: goal.fatGrams)
    }

    func grams(_ macro: FoodDay.Macro) -> Double {
        switch macro {
        case .protein: proteinGrams
        case .carbs: carbsGrams
        case .fat: fatGrams
        }
    }
}

/// One day's food against its goal.
struct FoodDay: Equatable {
    enum Macro: CaseIterable { case protein, carbs, fat }

    /// Everything eaten that day (each entry's nutrition × its servings).
    var eaten: Macros
    /// How many entries — 0 means "nothing logged" (the dashed ring), not "0 calories eaten".
    var entryCount: Int
    /// The goal in force that day; nil before the first goal.
    var goal: DayGoal?
    /// The day's workout calories the app knows (N9 adds Health's active energy). Shown, never added (D71).
    var burned: Double

    var isLogged: Bool { entryCount > 0 }

    /// Calories left to the goal (≥ 0), nil without a goal. Burned plays no part (D71).
    var left: Double? { goal.map { max(0, $0.calories - eaten.calories) } }

    /// Calories over the goal (> 0 only when over), nil without a goal.
    var over: Double? { goal.map { max(0, eaten.calories - $0.calories) } }

    var isOver: Bool { (over ?? 0) > 0.5 }

    /// How far the ring and the bar fill toward the goal: 0…1. Without a goal a logged day reads full (its macro
    /// split still shows what was eaten; there is nothing to fill toward).
    var fill: Double {
        guard isLogged else { return 0 }
        guard let goal, goal.calories > 0 else { return 1 }
        return min(1, max(0, eaten.calories / goal.calories))
    }

    /// The protein · carbs · fat shares of the macros' calories (4/4/9), summing to 1; all zero when no macro was
    /// logged (a calories-only Manual Add) — the ring then fills in the neutral colour.
    var macroShares: (protein: Double, carbs: Double, fat: Double) {
        let protein = eaten.proteinGrams * NutritionMath.caloriesPerGramProtein
        let carbs = eaten.carbsGrams * NutritionMath.caloriesPerGramCarbs
        let fat = eaten.fatGrams * NutritionMath.caloriesPerGramFat
        let sum = protein + carbs + fat
        guard sum > 0 else { return (0, 0, 0) }
        return (protein / sum, carbs / sum, fat / sum)
    }

    func eatenGrams(_ macro: Macro) -> Double {
        switch macro {
        case .protein: eaten.proteinGrams
        case .carbs: eaten.carbsGrams
        case .fat: eaten.fatGrams
        }
    }

    /// Grams still to go toward the macro's goal (≥ 0); nil without a goal.
    func toGo(_ macro: Macro) -> Double? { goal.map { max(0, $0.grams(macro) - eatenGrams(macro)) } }
}

enum FoodDayMath {
    /// The local day containing `day`: its entries, the goal in force then, and its workouts' calories.
    static func day(_ day: Date, entries: [FoodEntry], goals: [NutritionGoal], workouts: [Workout],
                    calendar: Calendar = .current) -> FoodDay {
        let todays = NutritionMath.entries(entries, on: day, calendar: calendar)
        return FoodDay(
            eaten: todays.reduce(.zero) { $0 + NutritionMath.totals(of: $1) },
            entryCount: todays.count,
            goal: NutritionMath.goal(on: day, among: goals, calendar: calendar).map(DayGoal.init),
            burned: workouts.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + (burned(by: $1) ?? 0) })
    }

    /// Each day of the week summary, keyed by its start of day.
    static func week(_ days: [Date], entries: [FoodEntry], goals: [NutritionGoal], workouts: [Workout],
                     calendar: Calendar = .current) -> [Date: FoodDay] {
        Dictionary(uniqueKeysWithValues: days.map {
            (calendar.startOfDay(for: $0), day($0, entries: entries, goals: goals, workouts: workouts, calendar: calendar))
        })
    }

    /// A workout's active calories: the workout's own figure, else its cardio segments' together; nil when no sensor
    /// measured any (not zero — "no sensor ran" is a different fact, as in History).
    static func burned(by workout: Workout) -> Double? {
        if let total = workout.activeEnergyKilocalories { return total }
        let parts = (workout.cardioSegments ?? []).compactMap(\.activeEnergyKilocalories)
        return parts.isEmpty ? nil : parts.reduce(0, +)
    }

    /// The week header's "5 days logged": past and present days with at least one entry.
    static func daysLogged(_ week: [Date: FoodDay]) -> Int { week.values.filter(\.isLogged).count }
}
