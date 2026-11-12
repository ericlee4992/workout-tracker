import Foundation
import SwiftData

/// Nutrition N13 (D84): what the goal setup reads and writes. Pure of UI; the flow's draft turns into `Answers`.
///
/// Finishing writes Personal details (sex, date of birth, height), the current weight as a body-weight entry (N9; Apple
/// Health follows the save when that is on), and the goal through `NutritionGoalStore` — a new dated goal, or today's
/// goal updated, so past days keep theirs (D70). A value the user left as prefilled is not written again: the stored
/// height keeps the unit and precision it was entered in, and an unchanged weight adds no entry (D52).
enum GoalSetupStore {

    struct Height: Equatable {
        var value: Double
        var unit: HeightUnit
        var cm: Double { unit == .cm ? value : value * 2.54 }
    }

    struct Weight: Equatable {
        var value: Double
        var unit: WeightUnit
        var kg: Double { WeightMath.normalizedKg(value: value, unit: unit) }
    }

    struct Answers: Equatable {
        var sex: BiologicalSex
        var birthDate: Date
        var height: Height
        var weight: Weight
        var activity: ActivityLevel
        var goal: WeightGoal
        /// nil for maintain.
        var desired: NutritionGoalStore.DesiredWeight?
        /// kg a week; nil for maintain.
        var paceKgPerWeek: Double?
        var overrides: NutritionGoals.Overrides = .none
        /// N14 (D85): the server's plan for these answers; nil = calculated on the phone.
        var generated: Macros? = nil
    }

    /// What an existing user's run starts from: Personal details, the latest weight and the current goal. Any of them
    /// may be missing (a field the user never filled).
    struct Prefill: Equatable {
        var sex: BiologicalSex?
        var birthDate: Date?
        var height: Height?
        var weight: Weight?
        var choices: NutritionGoalStore.Choices?
    }

    static func prefill(in context: ModelContext) throws -> Prefill {
        let preferences = AppPreferences.canonical(of: try context.fetch(FetchDescriptor<AppPreferences>()))
        var height: Height?
        if let value = preferences?.heightValue, let unit = preferences?.heightUnit { height = .init(value: value, unit: unit) }
        // N14 (D85): the latest weight entered in Stacked, never one read from Apple Health — the answers may go to the
        // server for the plan, and Stacked does not upload Health data (N9b's approved wording).
        let weight = try NutritionGoalStore.latestEnteredWeight(in: context).map { Weight(value: $0.value, unit: $0.unit) }
        let goal = try NutritionGoalStore.latestGoal(in: context)
        return Prefill(sex: preferences?.sex, birthDate: preferences?.birthDate, height: height, weight: weight,
                       choices: goal.map { NutritionGoalStore.choices(of: $0) })
    }

    /// Whether the answer is the stored pair itself. The flow keeps an untouched answer as the stored `(value, unit)`
    /// (`GoalSetupDraft`), so any difference is a real edit — even one inside a display rounding (codex-review-n13
    /// R2-1: 180.49 → 181 → 180 cm must save 180 cm, which the BMI bound was checked against).
    static func isUnchanged(_ answer: Height, stored: Height?) -> Bool {
        guard let stored else { return false }
        return answer.unit == stored.unit && abs(answer.value - stored.value) < 1e-9
    }

    /// Whether the answer is the latest weight's pair itself (176.37 → 176.36 lb is a new weigh-in).
    static func isUnchanged(_ answer: Weight, stored: Weight?) -> Bool {
        guard let stored else { return false }
        return answer.unit == stored.unit && abs(answer.value - stored.value) < 1e-9
    }

    /// Saves the answers (see the type's comment). Returns the goal in force.
    @discardableResult
    static func commit(_ answers: Answers, in context: ModelContext, now: Date = .now,
                       calendar: Calendar = .current) throws -> NutritionGoal? {
        let before = try prefill(in: context)
        let preferences = try AppPreferences.canonical(in: context)
        preferences.sex = answers.sex
        preferences.birthDate = answers.birthDate
        if !isUnchanged(answers.height, stored: before.height) {
            preferences.setHeight(value: answers.height.value, unit: answers.height.unit)
        }
        preferences.updatedAt = now
        // The weigh-in is compared with the latest weight from any source (codex-review-n14 R4): the prefill shows only
        // weights entered in Stacked, so when Apple Health has a newer one, the confirmed answer is recorded as today's
        // weight — the goal is then calculated from the weight the user confirmed, as the plan page showed.
        let latest = try NutritionGoalStore.latestWeight(in: context).map { Weight(value: $0.value, unit: $0.unit) }
        if !isUnchanged(answers.weight, stored: latest) {
            context.insert(BodyWeightEntry(measuredAt: now, value: answers.weight.value, unit: answers.weight.unit,
                                           createdAt: now))
        }
        try context.save()
        return try NutritionGoalStore.update(in: context, now: now, calendar: calendar) { choices in
            choices.activity = answers.activity
            choices.goal = answers.goal
            choices.overrides = answers.overrides
            choices.desired = answers.goal == .maintain ? nil : answers.desired
            choices.paceKgPerWeek = answers.goal == .maintain ? nil : answers.paceKgPerWeek
            choices.generated = answers.generated
        }
    }
}
