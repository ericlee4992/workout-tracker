import Foundation

/// Nutrition N14 (D85): the goal setup's plan from the server (`POST /v1/ai/nutrition-goals`, signed in). The model
/// decides the numbers (the user, 2026-11-12); the app checks only that they are plausible — the editors' own bounds —
/// and otherwise, or whenever the server cannot answer, falls back to the on-phone calculation (`NutritionGoals`).
/// The request carries the setup's answers only (the weight as entered in Stacked — never one read from Apple Health).
enum GoalPlanAI {
    static let calorieRange = 500.0...10_000
    static let gramRange = 0.0...1_000

    /// The answers the server takes (server/README → AI; `nutrition-goals`).
    static func body(_ inputs: NutritionGoals.Inputs, desiredKg: Double?) -> [String: Any] {
        var body: [String: Any] = [
            "sex": inputs.sex.rawValue, "ageYears": inputs.ageYears,
            "heightCm": (inputs.heightCm * 10).rounded() / 10, "weightKg": (inputs.weightKg * 100).rounded() / 100,
            "activity": inputs.activity.rawValue, "goal": inputs.goal.rawValue,
        ]
        if inputs.goal != .maintain, let desiredKg, let pace = inputs.paceKgPerWeek {
            body["desiredWeightKg"] = (desiredKg * 100).rounded() / 100
            body["paceKgPerWeek"] = (pace * 1_000).rounded() / 1_000
        }
        return body
    }

    /// The reply's numbers, or nil when any is missing, not a whole number, or outside the editors' bounds.
    static func parse(_ data: Data) -> Macros? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func whole(_ key: String, _ range: ClosedRange<Double>) -> Double? {
            guard let number = object[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            let value = number.doubleValue
            return value.isFinite && value == value.rounded() && range.contains(value) ? value : nil
        }
        guard let calories = whole("calories", calorieRange), let protein = whole("protein", gramRange),
              let carbs = whole("carbs", gramRange), let fat = whole("fat", gramRange) else { return nil }
        return Macros(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat)
    }

    /// The UI tests' answer (`-uiTestTerra`): a fixed plan, or the fixture's failure.
    static let fixtureReply = Data(#"{"calories":2100,"protein":160,"carbs":215,"fat":68}"#.utf8)
}
