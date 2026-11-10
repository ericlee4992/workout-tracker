import Foundation
import SwiftData

/// Nutrition N3: keeps the stored goal in step with Personal details (D80) and the user's choices (D70).
///
/// The goal in force is the latest `NutritionGoal`. Every change goes through `update`: it reads Personal details,
/// applies the change to the activity / goal / typed numbers, resolves the numbers (`NutritionGoals.resolve`) and
/// writes them — into today's goal when one already starts today, else as a new goal effective from the start of
/// today, so a past day keeps the goal it had (frozen history). Nothing is written while Personal details are
/// incomplete, or when nothing changed.
enum NutritionGoalStore {

    enum Failure: Error, LocalizedError, Equatable {
        /// A change was asked for while Personal details are incomplete (e.g. the date of birth cleared in the
        /// zones sheet): it cannot be calculated, so it is refused rather than dropped silently (codex-review-n3).
        case detailsIncomplete

        var errorDescription: String? { "Add your personal details first." }
    }

    /// Personal details as the calculation needs them; nil when any is missing.
    struct Details: Equatable {
        var weightKg: Double
        var heightCm: Double
        var birthDate: Date
        var sex: BiologicalSex
    }

    /// The user's choices around the calculation.
    struct Choices: Equatable {
        var activity: ActivityLevel = .moderate
        var goal: WeightGoal = .maintain
        var overrides: NutritionGoals.Overrides = .none
    }

    static func details(in context: ModelContext) throws -> Details? {
        let preferences = AppPreferences.canonical(of: try context.fetch(FetchDescriptor<AppPreferences>()))
        guard let weight = try latestWeight(in: context), let preferences,
              let heightCm = preferences.heightCm, let birthDate = preferences.birthDate, let sex = preferences.sex
        else { return nil }
        return Details(weightKg: weight.normalizedKg, heightCm: heightCm, birthDate: birthDate, sex: sex)
    }

    /// The most recent body weight (Personal details shows it; N9 adds history).
    static func latestWeight(in context: ModelContext) throws -> BodyWeightEntry? {
        var descriptor = FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.measuredAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    static func latestGoal(in context: ModelContext) throws -> NutritionGoal? {
        try context.fetch(FetchDescriptor<NutritionGoal>()).max {
            ($0.effectiveFrom, $0.createdAt, $0.id.uuidString) < ($1.effectiveFrom, $1.createdAt, $1.id.uuidString)
        }
    }

    /// The choices a stored goal carries: its activity and goal, and each overridden number as typed.
    static func choices(of goal: NutritionGoal?) -> Choices {
        guard let goal else { return Choices() }
        return Choices(
            activity: goal.activity ?? .moderate, goal: goal.goal ?? .maintain,
            overrides: .init(calories: goal.caloriesOverridden ? goal.calories : nil,
                             proteinGrams: goal.proteinOverridden ? goal.proteinGrams : nil,
                             carbsGrams: goal.carbsOverridden ? goal.carbsGrams : nil,
                             fatGrams: goal.fatOverridden ? goal.fatGrams : nil))
    }

    static func inputs(_ details: Details, _ choices: Choices, on date: Date,
                       calendar: Calendar = .current) -> NutritionGoals.Inputs {
        .init(weightKg: details.weightKg, heightCm: details.heightCm,
              ageYears: NutritionGoals.age(birthDate: details.birthDate, on: date, calendar: calendar),
              sex: details.sex, activity: choices.activity, goal: choices.goal)
    }

    /// Applies `change` to the current choices and stores the result (see the type's comment). Returns the goal in
    /// force afterwards. Without a change (a refresh after Personal details changed) incomplete details write
    /// nothing; with one they throw `Failure.detailsIncomplete`.
    @discardableResult
    static func update(in context: ModelContext, now: Date = .now, calendar: Calendar = .current,
                       change: ((inout Choices) -> Void)? = nil) throws -> NutritionGoal? {
        let latest = try latestGoal(in: context)
        guard let details = try details(in: context) else {
            if change != nil { throw Failure.detailsIncomplete }
            return latest
        }
        var choices = choices(of: latest)
        change?(&choices)
        let inputs = inputs(details, choices, on: now, calendar: calendar)
        let numbers = NutritionGoals.resolve(inputs, overrides: choices.overrides)
        if let latest, matches(latest, inputs: inputs, choices: choices, numbers: numbers) { return latest }

        let today = calendar.startOfDay(for: now)
        let goal: NutritionGoal
        if let latest, calendar.isDate(latest.effectiveFrom, inSameDayAs: today), latest.effectiveFrom >= today {
            goal = latest
        } else {
            goal = NutritionGoal(effectiveFrom: today, calories: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0,
                                 createdAt: now)
            context.insert(goal)
        }
        goal.calories = numbers.calories
        goal.proteinGrams = numbers.proteinGrams
        goal.carbsGrams = numbers.carbsGrams
        goal.fatGrams = numbers.fatGrams
        goal.weightKg = inputs.weightKg
        goal.heightCm = inputs.heightCm
        goal.ageYears = inputs.ageYears
        goal.sex = inputs.sex
        goal.activity = inputs.activity
        goal.goal = inputs.goal
        goal.caloriesOverridden = choices.overrides.calories != nil
        goal.proteinOverridden = choices.overrides.proteinGrams != nil
        goal.carbsOverridden = choices.overrides.carbsGrams != nil
        goal.fatOverridden = choices.overrides.fatGrams != nil
        try context.save()
        return goal
    }

    /// The ticket's prefill (N3): a height or weight Personal details lack comes from the AI training profile (ticket
    /// 05), as entered there — never over a value already given. Returns whether anything was filled; the goal follows.
    @discardableResult
    static func prefillMissing(from training: TrainingProfile, in context: ModelContext, now: Date = .now) throws -> Bool {
        let preferences = try AppPreferences.canonical(in: context)
        var filled = false
        if preferences.heightCm == nil, let height = training.height {
            switch height.unit {
            case .cm: preferences.setHeight(value: height.value, unit: .cm); filled = true
            case .inches: preferences.setHeight(value: height.value, unit: .inches); filled = true
            case .kg, .lb: break
            }
        }
        if try latestWeight(in: context) == nil, let weight = training.weight {
            switch weight.unit {
            case .kg: context.insert(BodyWeightEntry(measuredAt: now, value: weight.value, unit: .kg, createdAt: now)); filled = true
            case .lb: context.insert(BodyWeightEntry(measuredAt: now, value: weight.value, unit: .lb, createdAt: now)); filled = true
            case .cm, .inches: break
            }
        }
        guard filled else { return false }
        preferences.updatedAt = now
        try context.save()
        try update(in: context, now: now)
        return true
    }

    private static func matches(_ goal: NutritionGoal, inputs: NutritionGoals.Inputs, choices: Choices,
                                numbers: Macros) -> Bool {
        goal.calories == numbers.calories && goal.proteinGrams == numbers.proteinGrams
            && goal.carbsGrams == numbers.carbsGrams && goal.fatGrams == numbers.fatGrams
            && goal.weightKg == inputs.weightKg && goal.heightCm == inputs.heightCm
            && goal.ageYears == inputs.ageYears && goal.sex == inputs.sex
            && goal.activity == inputs.activity && goal.goal == inputs.goal
            && goal.caloriesOverridden == (choices.overrides.calories != nil)
            && goal.proteinOverridden == (choices.overrides.proteinGrams != nil)
            && goal.carbsOverridden == (choices.overrides.carbsGrams != nil)
            && goal.fatOverridden == (choices.overrides.fatGrams != nil)
    }
}
