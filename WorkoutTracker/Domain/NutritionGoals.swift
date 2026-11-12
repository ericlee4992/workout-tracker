import Foundation

/// Nutrition N3: the suggested daily goal (D70; the calculation the user approved 2026-11-09). Pure; no store access.
///
/// Calories: Mifflin–St Jeor resting energy × an activity factor, then the goal's adjustment, never below a floor
/// unless the user types a lower number. Protein 1.8 g per kg (set for lifting), fat 25 % of calories, carbs the rest.
/// Every number can be typed over; a typed number stays when the inputs change (`resolve`).
enum NutritionGoals {

    /// What the calculation needs. Weight and height normalized (kg, cm); the entered units live with Personal details.
    struct Inputs: Equatable {
        var weightKg: Double
        var heightCm: Double
        var ageYears: Int
        var sex: BiologicalSex
        var activity: ActivityLevel
        var goal: WeightGoal
        /// N13: the chosen pace, kg a week; nil = N3's fixed adjustment (`goalAdjustment`). Ignored for maintain.
        var paceKgPerWeek: Double? = nil
    }

    /// The numbers the user typed over the calculation; nil = follow the calculation.
    struct Overrides: Equatable {
        var calories: Double?
        var proteinGrams: Double?
        var carbsGrams: Double?
        var fatGrams: Double?

        static let none = Overrides()
    }

    static let proteinGramsPerKg = 1.8
    static let fatShareOfCalories = 0.25

    /// Mifflin–St Jeor: 10 × kg + 6.25 × cm − 5 × years + s, with s = +5 (male), −161 (female); "Prefer not to say"
    /// uses the average of the two (−78).
    static func restingEnergy(_ inputs: Inputs) -> Double {
        10 * inputs.weightKg + 6.25 * inputs.heightCm - 5 * Double(inputs.ageYears) + sexConstant(inputs.sex)
    }

    static func sexConstant(_ sex: BiologicalSex) -> Double {
        switch sex {
        case .male: 5
        case .female: -161
        case .unspecified: (5 - 161) / 2
        }
    }

    static func activityFactor(_ activity: ActivityLevel) -> Double {
        switch activity {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }

    /// Lose about 0.5 kg a week, maintain, or a lean gain.
    static func goalAdjustment(_ goal: WeightGoal) -> Double {
        switch goal {
        case .lose: -500
        case .maintain: 0
        case .gain: 250
        }
    }

    /// The lowest the calculation suggests: 1,200 kcal (women), 1,500 (men); "Prefer not to say" the average, 1,350.
    /// A number the user types may go lower.
    static func calorieFloor(_ sex: BiologicalSex) -> Double {
        switch sex {
        case .male: 1_500
        case .female: 1_200
        case .unspecified: 1_350
        }
    }

    /// The calculated daily calories, whole kcal: the pace's adjustment when there is one (N13, `GoalPlan`), else
    /// N3's fixed one.
    static func calories(_ inputs: Inputs) -> Double {
        let adjustment = inputs.goal == .maintain ? 0 : inputs.paceKgPerWeek.map {
            GoalPlan.dailyAdjustment(goal: inputs.goal, kgPerWeek: $0)
        } ?? goalAdjustment(inputs.goal)
        let energy = restingEnergy(inputs) * activityFactor(inputs.activity) + adjustment
        return max(energy, calorieFloor(inputs.sex)).rounded()
    }

    /// The suggestion with nothing typed over.
    static func suggested(_ inputs: Inputs) -> Macros {
        resolve(inputs, overrides: .none)
    }

    /// The goal in force: each typed number as typed, the rest calculated around it — fat is 25 % of the calories in
    /// force (typed or calculated), carbs what is left after protein and fat (never negative). Whole numbers.
    static func resolve(_ inputs: Inputs, overrides: Overrides) -> Macros {
        let calories = overrides.calories ?? calories(inputs)
        let protein = overrides.proteinGrams ?? (proteinGramsPerKg * inputs.weightKg).rounded()
        let fat = overrides.fatGrams
            ?? (fatShareOfCalories * calories / NutritionMath.caloriesPerGramFat).rounded()
        let carbs = overrides.carbsGrams ?? max(0, ((calories
            - protein * NutritionMath.caloriesPerGramProtein
            - fat * NutritionMath.caloriesPerGramFat) / NutritionMath.caloriesPerGramCarbs).rounded())
        return Macros(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat)
    }

    /// Whole years old on `date` (a birthday later this year not yet counted).
    static func age(birthDate: Date, on date: Date, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0)
    }
}
