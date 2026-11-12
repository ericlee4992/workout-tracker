import Foundation
import SwiftData

// Nutrition N9: body weight logging. Each weight keeps the entered `(value, unit)` and `normalizedKg` (D25, D52): a
// weight entered in lb stays in lb. Logging, editing and deleting go through here so N9's Apple Health sync has one
// place to follow.

enum BodyWeightLog {
    /// The ± step of the Log weight sheet: 0.1 kg or 0.2 lb (the prototype's).
    static func step(for unit: WeightUnit) -> Double { unit == .kg ? 0.1 : 0.2 }

    /// The plausible range, as Personal details' weight editor allows.
    static func range(for unit: WeightUnit) -> ClosedRange<Double> { unit == .lb ? 50...800 : 20...360 }

    @discardableResult
    static func log(value: Double, unit: WeightUnit, at date: Date, in context: ModelContext) throws -> BodyWeightEntry {
        let entry = BodyWeightEntry(measuredAt: date, value: value, unit: unit)
        context.insert(entry)
        try context.save()
        return entry
    }

    static func update(_ entry: BodyWeightEntry, value: Double, unit: WeightUnit, at date: Date,
                       in context: ModelContext) throws {
        entry.set(value: value, unit: unit)
        entry.measuredAt = date
        try context.save()
    }

    static func delete(_ entry: BodyWeightEntry, in context: ModelContext) throws {
        context.delete(entry)
        try context.save()
    }

    /// Recalculate goals (the Body weight offer): N3's explicit Recalculate — the typed-over numbers go and the goal is
    /// calculated again from Personal details, now with the latest weight (codex-review-n9a). Throws
    /// `NutritionGoalStore.Failure.detailsIncomplete` when there is nothing to calculate from, rather than doing nothing.
    @discardableResult
    static func recalculateGoal(in context: ModelContext, now: Date = .now) throws -> NutritionGoal? {
        try NutritionGoalStore.update(in: context, now: now) { $0.overrides = .none; $0.generated = nil }
    }

    /// The goal was calculated at a weight more than about 2 kg from the latest one (N9: offer Recalculate rather than
    /// follow every day's fluctuation). False without a goal, a goal weight, or a weight.
    static func goalNeedsRecalculating(goal: NutritionGoal?, latest: BodyWeightEntry?, thresholdKg: Double = 2) -> Bool {
        guard let goalKg = goal?.weightKg, let latest else { return false }
        return abs(latest.normalizedKg - goalKg) > thresholdKg
    }
}
