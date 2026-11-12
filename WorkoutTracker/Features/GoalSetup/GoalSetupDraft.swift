import Foundation
import Observation

/// Nutrition N13: the goal setup's answers while the flow runs, in memory until the plan's commit
/// (`GoalSetupStore.commit`). A new install starts empty; an existing user's run starts from `GoalSetupStore.Prefill`.
@Observable
@MainActor
final class GoalSetupDraft: Identifiable {
    enum Step: Int, CaseIterable, Comparable {
        case sex, birthDate, body, workouts, goal, desired, pace, plan
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }

    enum Units: Int, CaseIterable { case metric, imperial }

    static let heightCmRange = 120...230
    /// 4 ft 0 in … 7 ft 11 in.
    static let heightInchesRange = 48...95

    var step: Step = .sex
    var sex: BiologicalSex?
    var birthDate: Date
    var units: Units
    /// The height as shown: whole cm, or whole inches.
    var heightCm: Int = 170
    var heightInches: Int = 67
    var weightText: String = ""
    var workouts: GoalPlan.WorkoutsPerWeek?
    var goal: WeightGoal?
    /// In the weight's unit; 0 until the desired-weight page is reached.
    var desired: Double = 0
    /// kg a week; 0 until the pace page is reached.
    var paceKg: Double = 0
    var overrides: NutritionGoals.Overrides = .none
    /// Opened from Nutrition goals (prefilled, can be closed) rather than on first launch (required).
    let isExistingUser: Bool
    let now: Date
    /// The stored activity: kept when the workouts answer is the one it maps to, so a finer level chosen on Nutrition
    /// goals (Sedentary, Extra active) survives a run that leaves the answer alone.
    private let storedActivity: ActivityLevel?

    init(prefill: GoalSetupStore.Prefill? = nil, now: Date = .now, calendar: Calendar = .current) {
        isExistingUser = prefill != nil
        self.now = now
        birthDate = calendar.date(byAdding: .year, value: -30, to: now) ?? now
        storedActivity = prefill?.choices?.activity
        let usesPounds = prefill?.weight?.unit == .lb
            || (prefill?.weight == nil && prefill?.height?.unit == .inches)
        units = usesPounds ? .imperial : .metric
        guard let prefill else { return }
        sex = prefill.sex
        if let date = prefill.birthDate { birthDate = date }
        if let height = prefill.height {
            heightCm = Self.clamp(Int(height.cm.rounded()), Self.heightCmRange)
            heightInches = Self.clamp(Int((height.cm / 2.54).rounded()), Self.heightInchesRange)
        }
        if let weight = prefill.weight {
            let shown = WeightMath.convert(weight.value, from: weight.unit, to: weightUnit)
            weightText = FoodNumber.text((shown * 10).rounded() / 10)
        }
        if let choices = prefill.choices {
            workouts = GoalPlan.WorkoutsPerWeek(activity: choices.activity)
            goal = choices.goal
            overrides = choices.overrides
            if let stored = choices.desired {
                desired = rounded(WeightMath.convert(stored.value, from: stored.unit, to: weightUnit), step: desiredStep)
            }
            paceKg = choices.paceKgPerWeek ?? 0
        }
    }

    var weightUnit: WeightUnit { units == .metric ? .kg : .lb }
    var weight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: ".")).flatMap {
            BodyWeightLog.range(for: weightUnit).contains($0) ? $0 : nil
        }
    }
    var weightKg: Double? { weight.map { WeightMath.normalizedKg(value: $0, unit: weightUnit) } }
    var height: GoalSetupStore.Height {
        units == .metric ? .init(value: Double(heightCm), unit: .cm) : .init(value: Double(heightInches), unit: .inches)
    }
    var ageYears: Int { NutritionGoals.age(birthDate: birthDate, on: now) }
    var desiredKg: Double { WeightMath.normalizedKg(value: desired, unit: weightUnit) }

    var activity: ActivityLevel? {
        guard let workouts else { return nil }
        if let storedActivity, GoalPlan.WorkoutsPerWeek(activity: storedActivity) == workouts { return storedActivity }
        return workouts.activity
    }

    /// The steps this run shows: maintain skips the desired weight and the pace.
    var steps: [Step] {
        goal == .maintain ? Step.allCases.filter { $0 != .desired && $0 != .pace } : Step.allCases
    }

    static let ageRange = 13...110

    var canContinue: Bool {
        switch step {
        case .sex: sex != nil
        case .birthDate: Self.ageRange.contains(ageYears)
        case .body: weight != nil
        case .workouts: workouts != nil
        case .goal: goal != nil && goalBlocked == nil
        case .desired: desiredRange?.contains(desiredKg) ?? false
        case .pace: paces != nil
        case .plan: answers != nil
        }
    }

    /// Why the chosen goal cannot be planned: losing when today's weight is already at the lowest healthy weight for
    /// the height, or when any loss would take the calories under the floor.
    enum GoalBlock: Equatable { case atLowestWeight, calorieFloor(Double) }

    var goalBlocked: GoalBlock? {
        guard goal == .lose, let sex else { return nil }
        if desiredRange == nil { return .atLowestWeight }
        if paces == nil { return .calorieFloor(NutritionGoals.calorieFloor(sex)) }
        return nil
    }

    var inputs: NutritionGoals.Inputs? {
        guard let sex, let weightKg, let activity, let goal else { return nil }
        return .init(weightKg: weightKg, heightCm: height.cm, ageYears: ageYears, sex: sex, activity: activity,
                     goal: goal, paceKgPerWeek: goal == .maintain ? nil : paceKg)
    }

    var paces: GoalPlan.Paces? { inputs.flatMap { GoalPlan.paces($0, unit: weightUnit) } }

    var desiredRange: ClosedRange<Double>? {
        guard let goal, let weightKg else { return nil }
        return GoalPlan.desiredRange(goal: goal, currentKg: weightKg, heightCm: height.cm)
    }

    /// The calories at the chosen pace (maintain: no adjustment).
    var calculatedCalories: Double? { inputs.map(NutritionGoals.calories) }

    /// The plan in force: the calculation with the typed-over numbers.
    var plan: Macros? { inputs.map { NutritionGoals.resolve($0, overrides: overrides) } }

    var arrival: Date? {
        guard let weightKg, goal != .maintain else { return nil }
        return GoalPlan.arrival(fromKg: weightKg, toKg: desiredKg, kgPerWeek: paceKg, now: now)
    }

    var weeks: Double? {
        guard let weightKg, goal != .maintain else { return nil }
        return GoalPlan.weeks(fromKg: weightKg, toKg: desiredKg, kgPerWeek: paceKg)
    }

    /// What the plan's commit saves; nil while an answer is missing.
    var answers: GoalSetupStore.Answers? {
        guard let sex, let weight, let activity, let goal, Self.ageRange.contains(ageYears) else { return nil }
        let losesOrGains = goal != .maintain
        if losesOrGains && (paceKg <= 0 || !(desiredRange?.contains(desiredKg) ?? false)) { return nil }
        return .init(sex: sex, birthDate: birthDate, height: height, weight: .init(value: weight, unit: weightUnit),
                     activity: activity, goal: goal,
                     desired: losesOrGains ? .init(value: desired, unit: weightUnit) : nil,
                     paceKgPerWeek: losesOrGains ? paceKg : nil, overrides: overrides)
    }

    // MARK: Moving

    var isFirst: Bool { steps.first == step }

    func advance() {
        guard canContinue, let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        let next = steps[index + 1]
        prepare(next)
        step = next
    }

    func back() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    /// Defaults a page needs when it is reached: a desired weight outside its range (none yet, or the goal or weight
    /// changed) becomes 5 kg (10 lb) from today's in the goal's direction, kept inside the range; a pace outside the
    /// offered ones becomes the recommended pace.
    private func prepare(_ next: Step) {
        switch next {
        case .desired:
            guard let range = desiredRange, let weight, !range.contains(desiredKg) else { return }
            let offset = weightUnit == .kg ? 5.0 : 10.0
            let start = WeightMath.normalizedKg(value: goal == .gain ? weight + offset : weight - offset, unit: weightUnit)
            let kg = min(max(start, range.lowerBound), range.upperBound)
            desired = inside(rounded(WeightMath.convert(kg, from: .kg, to: weightUnit), step: desiredStep), range)
        case .pace:
            if let paces, !(paces.slow - 1e-9...paces.fast + 1e-9).contains(paceKg) { paceKg = paces.recommended }
        default:
            break
        }
    }

    /// A rounded desired weight nudged back inside the range by whole steps.
    private func inside(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        var value = value
        while WeightMath.normalizedKg(value: value, unit: weightUnit) < range.lowerBound { value += desiredStep }
        while WeightMath.normalizedKg(value: value, unit: weightUnit) > range.upperBound { value -= desiredStep }
        return value
    }

    var desiredStep: Double { weightUnit == .kg ? 0.5 : 1 }

    func stepDesired(by sign: Double) {
        guard let range = desiredRange else { return }
        let next = rounded(desired + sign * desiredStep, step: desiredStep)
        if range.contains(WeightMath.normalizedKg(value: next, unit: weightUnit)) { desired = next }
    }

    /// The desired weight is at the lowest offered (a BMI of 18.5).
    var desiredAtLowest: Bool {
        guard goal == .lose, let range = desiredRange else { return false }
        return !range.contains(WeightMath.normalizedKg(value: desired - desiredStep, unit: weightUnit))
    }

    func stepWeight(by sign: Double) {
        guard let weight else { return }
        let next = ((weight + sign * BodyWeightLog.step(for: weightUnit)) * 10).rounded() / 10
        if BodyWeightLog.range(for: weightUnit).contains(next) { weightText = FoodNumber.text(next) }
    }

    /// Metric ⇄ imperial converts what is on screen (nothing stored is rewritten until the commit, and then only what
    /// changed — `GoalSetupStore`).
    func switchUnits(to new: Units) {
        guard new != units else { return }
        let oldUnit = weightUnit
        if new == .imperial {
            heightInches = Self.clamp(Int((Double(heightCm) / 2.54).rounded()), Self.heightInchesRange)
        } else {
            heightCm = Self.clamp(Int((Double(heightInches) * 2.54).rounded()), Self.heightCmRange)
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
    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int { min(max(value, range.lowerBound), range.upperBound) }
}
