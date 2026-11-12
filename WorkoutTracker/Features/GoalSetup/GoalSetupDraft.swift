import Foundation
import Observation

/// Nutrition N13: the goal setup's answers while the flow runs. In memory only until the plan step's commit (the
/// prototype commits nothing).
@Observable
@MainActor
final class GoalSetupDraft {
    enum Step: Int, CaseIterable, Comparable {
        case sex, birthDate, body, workouts, goal, desired, pace, plan
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }

    enum Units: Int, CaseIterable { case metric, imperial }

    var step: Step = .sex
    var sex: BiologicalSex?
    var birthDate: Date
    var units: Units
    /// Height as entered: whole cm, or whole inches (D52: kept in the unit it was entered in).
    var heightCm: Int = 175
    var heightInches: Int = 69
    var weightText: String
    var workouts: GoalPlan.WorkoutsPerWeek?
    var goal: WeightGoal?
    /// In the weight's unit.
    var desired: Double = 0
    /// kg a week.
    var paceKg: Double = 0
    var overrides: NutritionGoals.Overrides = .none
    /// Opened from Nutrition goals (prefilled, can be closed) rather than on first launch (required).
    let isExistingUser: Bool
    let now: Date

    init(existing: Bool, now: Date = .now) {
        isExistingUser = existing
        self.now = now
        birthDate = Calendar.current.date(byAdding: .year, value: -30, to: now) ?? now
        units = .metric
        weightText = ""
        if existing {
            // The prototype's prefill: Personal details, the latest weight and the current goal.
            sex = .male
            birthDate = Calendar.current.date(from: DateComponents(year: 1994, month: 5, day: 14)) ?? birthDate
            heightCm = 178
            weightText = "82.4"
            workouts = .some
            goal = .lose
            desired = 76
            step = .sex
        }
    }

    var weightUnit: WeightUnit { units == .metric ? .kg : .lb }
    var weight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: ".")).flatMap {
            BodyWeightLog.range(for: weightUnit).contains($0) ? $0 : nil
        }
    }
    var weightKg: Double? { weight.map { WeightMath.normalizedKg(value: $0, unit: weightUnit) } }
    var heightInCm: Double { units == .metric ? Double(heightCm) : Double(heightInches) * 2.54 }
    var ageYears: Int { NutritionGoals.age(birthDate: birthDate, on: now) }
    var desiredKg: Double { WeightMath.normalizedKg(value: desired, unit: weightUnit) }

    /// The steps this run shows: maintain skips the desired weight and the pace.
    var steps: [Step] {
        goal == .maintain ? Step.allCases.filter { $0 != .desired && $0 != .pace } : Step.allCases
    }

    var canContinue: Bool {
        switch step {
        case .sex: sex != nil
        case .birthDate: (13...110).contains(ageYears)
        case .body: weight != nil
        case .workouts: workouts != nil
        case .goal: goal != nil
        case .desired: desiredRange?.contains(desiredKg) ?? false
        case .pace: paces != nil
        case .plan: true
        }
    }

    var inputs: NutritionGoals.Inputs? {
        guard let sex, let weightKg, let workouts, let goal else { return nil }
        return .init(weightKg: weightKg, heightCm: heightInCm, ageYears: ageYears, sex: sex,
                     activity: workouts.activity, goal: goal)
    }

    var paces: GoalPlan.Paces? { inputs.flatMap { GoalPlan.paces($0, unit: weightUnit) } }

    var desiredRange: ClosedRange<Double>? {
        guard let goal, let weightKg else { return nil }
        return GoalPlan.desiredRange(goal: goal, currentKg: weightKg, heightCm: heightInCm)
    }

    /// The calories at the chosen pace (maintain: no adjustment).
    var calculatedCalories: Double? {
        guard let inputs else { return nil }
        return GoalPlan.calories(inputs, kgPerWeek: inputs.goal == .maintain ? 0 : paceKg)
    }

    var plan: Macros? {
        guard let inputs, let calories = calculatedCalories else { return nil }
        var overrides = overrides
        if overrides.calories == nil { overrides.calories = calories }
        return NutritionGoals.resolve(inputs, overrides: overrides)
    }

    var arrival: Date? {
        guard let weightKg, goal != .maintain else { return nil }
        return GoalPlan.arrival(fromKg: weightKg, toKg: desiredKg, kgPerWeek: paceKg, now: now)
    }

    var weeks: Double? {
        guard let weightKg, goal != .maintain else { return nil }
        return GoalPlan.weeks(fromKg: weightKg, toKg: desiredKg, kgPerWeek: paceKg)
    }

    // MARK: Moving

    var isFirst: Bool { steps.first == step }

    func advance() {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        let next = steps[index + 1]
        prepare(next)
        step = next
    }

    func back() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    /// Defaults a step needs when first reached: the desired weight 5 kg (10 lb) from today's in the goal's
    /// direction, inside its range; the recommended pace.
    private func prepare(_ next: Step) {
        switch next {
        case .desired:
            guard let range = desiredRange, let weight else { return }
            let offset = weightUnit == .kg ? 5.0 : 10.0
            let start = goal == .gain ? weight + offset : weight - offset
            if !range.contains(desiredKg) || !isExistingUser {
                let kg = min(max(WeightMath.normalizedKg(value: start, unit: weightUnit), range.lowerBound), range.upperBound)
                desired = rounded(WeightMath.convert(kg, from: .kg, to: weightUnit), step: desiredStep)
            }
        case .pace:
            if let paces, !(paces.slow...paces.fast).contains(paceKg) { paceKg = paces.recommended }
        default:
            break
        }
    }

    var desiredStep: Double { weightUnit == .kg ? 0.5 : 1 }

    func stepDesired(by sign: Double) {
        guard let range = desiredRange else { return }
        let next = rounded(desired + sign * desiredStep, step: desiredStep)
        let kg = WeightMath.normalizedKg(value: next, unit: weightUnit)
        if range.contains(kg) { desired = next }
    }

    func stepWeight(by sign: Double) {
        guard let weight else { return }
        let next = ((weight + sign * BodyWeightLog.step(for: weightUnit)) * 10).rounded() / 10
        if BodyWeightLog.range(for: weightUnit).contains(next) { weightText = FoodNumber.text(next) }
    }

    /// Metric ⇄ imperial converts what is on screen (a new entry; nothing stored is rewritten).
    func switchUnits(to new: Units) {
        guard new != units else { return }
        let oldUnit = weightUnit
        if new == .imperial {
            heightInches = Int((Double(heightCm) / 2.54).rounded())
        } else {
            heightCm = Int((Double(heightInches) * 2.54).rounded())
        }
        units = new
        if let value = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
            weightText = FoodNumber.text((WeightMath.convert(value, from: oldUnit, to: weightUnit) * 10).rounded() / 10)
        }
        if desired > 0 {
            desired = rounded(WeightMath.convert(desired, from: oldUnit, to: weightUnit), step: desiredStep)
        }
    }

    private func rounded(_ value: Double, step: Double) -> Double { (value / step).rounded() * step }
}
