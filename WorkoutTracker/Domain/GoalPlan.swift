import Foundation

/// Nutrition N13: the goal setup's arithmetic — the pace a week, its safe bounds, the daily calories it gives and the
/// date the desired weight is reached. Pure; no store access. Calculated on the phone only (the user, 2026-11-11).
///
/// Safe rates (stated in the N13 ticket):
/// - **Lose** 0.25 % / 0.5 % / 1 % of body weight a week (slow / recommended / fast), never more than 0.9 kg (2 lb) a
///   week — the CDC's "1 to 2 pounds a week", and 0.5–1 % a week for people who lift (Helms et al., 2014), which keeps
///   muscle.
/// - **Gain** 0.125 % / 0.25 % / 0.5 % a week, never more than 0.5 kg — a lean gain (Iraki et al., 2019: 0.25–0.5 %).
/// - The daily calories never go below `NutritionGoals.calorieFloor`; a pace that would need fewer is not offered (the
///   fastest pace is held to what the floor allows).
/// - A desired weight to lose to is never below a BMI of 18.5 for the height (the WHO's underweight line).
enum GoalPlan {

    /// About 7,700 kcal of energy in a kilogram of body weight.
    static let caloriesPerKilogram = 7_700.0

    /// Lose 0.25 / 0.5 / 1 %, gain 0.125 / 0.25 / 0.5 % of body weight a week.
    static func shares(_ goal: WeightGoal) -> (slow: Double, recommended: Double, fast: Double)? {
        switch goal {
        case .lose: (0.0025, 0.005, 0.01)
        case .maintain: nil
        case .gain: (0.00125, 0.0025, 0.005)
        }
    }

    static func maximumKgPerWeek(_ goal: WeightGoal) -> Double {
        switch goal {
        case .lose: 0.9
        case .maintain: 0
        case .gain: 0.5
        }
    }

    /// The paces offered, kg a week, rounded to the unit's step (0.05 kg, 0.1 lb). nil for maintain, or when even the
    /// slowest loss would go below the calorie floor.
    struct Paces: Equatable {
        var slow: Double
        var recommended: Double
        var fast: Double
        /// The fastest pace was held down so the calories stay at or above the floor.
        var heldByFloor: Bool
    }

    /// The paces for this person and goal, in kg a week (rounded in `unit`).
    static func paces(_ inputs: NutritionGoals.Inputs, unit: WeightUnit) -> Paces? {
        guard let shares = shares(inputs.goal) else { return nil }
        let cap = maximumKgPerWeek(inputs.goal)
        var fast = min(shares.fast * inputs.weightKg, cap)
        var held = false
        if inputs.goal == .lose {
            // The deficit the floor allows, as a pace.
            let allowed = (maintenanceCalories(inputs) - NutritionGoals.calorieFloor(inputs.sex)) * 7 / caloriesPerKilogram
            if allowed < fast { fast = allowed; held = true }
        }
        let step = paceStepKg(unit)
        fast = roundDown(fast, step: step)
        guard fast >= step else { return nil }
        let slow = min(max(round(shares.slow * inputs.weightKg, step: step), step), fast)
        let recommended = min(max(round(shares.recommended * inputs.weightKg, step: step), slow), fast)
        return Paces(slow: slow, recommended: recommended, fast: fast, heldByFloor: held)
    }

    /// 0.05 kg or 0.1 lb, in kg.
    static func paceStepKg(_ unit: WeightUnit) -> Double {
        unit == .kg ? 0.05 : 0.1 * WeightMath.kilogramsPerPound
    }

    /// Resting energy × activity: the calories that keep today's weight.
    static func maintenanceCalories(_ inputs: NutritionGoals.Inputs) -> Double {
        NutritionGoals.restingEnergy(inputs) * NutritionGoals.activityFactor(inputs.activity)
    }

    /// The daily change a pace asks for: −(loss) or +(gain) kcal a day, whole kcal.
    static func dailyAdjustment(goal: WeightGoal, kgPerWeek: Double) -> Double {
        let amount = (kgPerWeek * caloriesPerKilogram / 7).rounded()
        switch goal {
        case .lose: return -amount
        case .maintain: return 0
        case .gain: return amount
        }
    }

    /// The calculated daily calories at a pace, never below the floor. Whole kcal.
    static func calories(_ inputs: NutritionGoals.Inputs, kgPerWeek: Double) -> Double {
        var inputs = inputs
        inputs.paceKgPerWeek = kgPerWeek
        return NutritionGoals.calories(inputs)
    }

    /// Weeks to the desired weight at a pace (fractional); nil when there is nothing to reach or no pace.
    static func weeks(fromKg current: Double, toKg desired: Double, kgPerWeek: Double) -> Double? {
        let distance = abs(desired - current)
        guard kgPerWeek > 0, distance > 0 else { return nil }
        return distance / kgPerWeek
    }

    /// The day the desired weight is reached (whole days, rounded up).
    static func arrival(fromKg current: Double, toKg desired: Double, kgPerWeek: Double, now: Date = .now,
                        calendar: Calendar = .current) -> Date? {
        guard let weeks = weeks(fromKg: current, toKg: desired, kgPerWeek: kgPerWeek) else { return nil }
        // A hair of tolerance: 5 kg at 0.35 kg a week is 100 days, not 101 through floating-point noise.
        return calendar.date(byAdding: .day, value: Int((weeks * 7 - 1e-9).rounded(.up)), to: calendar.startOfDay(for: now))
    }

    /// The desired weights offered, kg: losing, from a BMI of 18.5 to just under today's weight; gaining, from just
    /// over today's weight to 30 kg more. nil for maintain or when today's weight is already at the lower line.
    static func desiredRange(goal: WeightGoal, currentKg: Double, heightCm: Double) -> ClosedRange<Double>? {
        let margin = 0.5
        switch goal {
        case .maintain:
            return nil
        case .lose:
            let meters = heightCm / 100
            let lowest = 18.5 * meters * meters
            let highest = currentKg - margin
            return lowest <= highest ? lowest...highest : nil
        case .gain:
            return (currentKg + margin)...(currentKg + 30)
        }
    }

    /// Workouts a week (the setup's question) → the activity factor's level.
    enum WorkoutsPerWeek: String, CaseIterable, Codable {
        case few, some, many

        var activity: ActivityLevel {
            switch self {
            case .few: .light
            case .some: .moderate
            case .many: .veryActive
            }
        }

        /// An existing goal's activity, shown as the nearest answer.
        init(activity: ActivityLevel) {
            switch activity {
            case .sedentary, .light: self = .few
            case .moderate: self = .some
            case .veryActive, .extraActive: self = .many
            }
        }
    }

    private static func round(_ value: Double, step: Double) -> Double { (value / step).rounded() * step }
    private static func roundDown(_ value: Double, step: Double) -> Double {
        // A hair of tolerance so 0.9 kg stays 0.9 rather than 0.85 through floating-point division.
        ((value / step) + 1e-9).rounded(.down) * step
    }
}
