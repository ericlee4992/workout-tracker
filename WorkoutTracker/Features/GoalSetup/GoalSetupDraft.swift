import Foundation
import Observation

/// Nutrition N13: the goal setup's answers while the flow runs, in memory until the plan's commit
/// (`GoalSetupStore.commit`). A new install starts empty; an existing user's run starts from `GoalSetupStore.Prefill`.
///
/// Height, current weight and desired weight are each kept as the **entered pair** `(value, unit)` at full precision —
/// the prefilled one until the user changes that answer, then what they set (D52). Metric ⇄ imperial only changes
/// what is shown; the calculation, the bounds and the commit all read the pairs, so a unit switch or a reopened
/// setup never rewrites a value the user did not touch (codex-review-n13 R1, R2, R4).
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
    private(set) var units: Units
    /// The height to save: as prefilled, or as last set on the wheel (whole cm or whole inches).
    private(set) var heightEntry: GoalSetupStore.Height
    /// The weight to save: as prefilled, or as last typed or stepped; nil while the field holds no valid weight.
    private(set) var weightEntry: GoalSetupStore.Weight?
    private var weightTextStorage = ""
    var workouts: GoalPlan.WorkoutsPerWeek?
    var goal: WeightGoal?
    /// The desired weight to save: as prefilled, or as last stepped; nil until the desired-weight page is reached.
    private(set) var desiredEntry: NutritionGoalStore.DesiredWeight?
    /// kg a week; 0 until the pace page is reached.
    var paceKg: Double = 0
    var overrides: NutritionGoals.Overrides = .none
    /// Opened from Nutrition goals (prefilled, can be closed) rather than on first launch (required).
    let isExistingUser: Bool
    let now: Date
    /// The stored activity: kept when the workouts answer is the one it maps to, so a finer level chosen on Nutrition
    /// goals (Sedentary, Extra active) survives a run that leaves the answer alone.
    private let storedActivity: ActivityLevel?

    /// `usCustomary`: a new install starts in the app's units (Settings, else the region's) — lb and ft/in in the US.
    init(prefill: GoalSetupStore.Prefill? = nil, usCustomary: Bool = false, now: Date = .now,
         calendar: Calendar = .current) {
        isExistingUser = prefill != nil
        self.now = now
        birthDate = calendar.date(byAdding: .year, value: -30, to: now) ?? now
        storedActivity = prefill?.choices?.activity
        let usesPounds = prefill?.weight.map { $0.unit == .lb }
            ?? prefill?.height.map { $0.unit == .inches } ?? usCustomary
        units = usesPounds ? .imperial : .metric
        heightEntry = prefill?.height ?? (usesPounds ? .init(value: 67, unit: .inches) : .init(value: 170, unit: .cm))
        guard let prefill else { return }
        sex = prefill.sex
        if let date = prefill.birthDate { birthDate = date }
        weightEntry = prefill.weight
        weightTextStorage = shownWeightText
        if let choices = prefill.choices {
            workouts = GoalPlan.WorkoutsPerWeek(activity: choices.activity)
            goal = choices.goal
            overrides = choices.overrides
            desiredEntry = choices.desired
            paceKg = choices.paceKgPerWeek ?? 0
        }
    }

    var weightUnit: WeightUnit { units == .metric ? .kg : .lb }

    // MARK: Height (the wheel shows the entry in the shown units)

    var height: GoalSetupStore.Height { heightEntry }

    /// The wheel's cm; setting it is an answer in cm.
    var heightCm: Int {
        get { Self.clamp(Int(heightEntry.cm.rounded()), Self.heightCmRange) }
        set { heightEntry = .init(value: Double(newValue), unit: .cm) }
    }

    /// The wheel's total inches; setting it is an answer in inches.
    var heightInches: Int {
        get { Self.clamp(Int((heightEntry.cm / 2.54).rounded()), Self.heightInchesRange) }
        set { heightEntry = .init(value: Double(newValue), unit: .inches) }
    }

    // MARK: Weight (the field shows the entry in the shown unit)

    /// The field's text; typing makes the typed number, in the shown unit, the answer.
    var weightText: String {
        get { weightTextStorage }
        set {
            weightTextStorage = newValue
            weightEntry = Double(newValue.replacingOccurrences(of: ",", with: "."))
                .flatMap { BodyWeightLog.range(for: weightUnit).contains($0) ? .init(value: $0, unit: weightUnit) : nil }
        }
    }

    /// The weight in the shown unit, full precision.
    var weight: Double? { weightEntry.map { WeightMath.convert($0.value, from: $0.unit, to: weightUnit) } }
    var weightKg: Double? { weightEntry?.kg }

    private var shownWeightText: String {
        guard let weightEntry else { return "" }
        if weightEntry.unit == weightUnit { return FoodNumber.text(weightEntry.value) }
        return FoodNumber.text((WeightMath.convert(weightEntry.value, from: weightEntry.unit, to: weightUnit) * 10).rounded() / 10)
    }

    func stepWeight(by sign: Double) {
        guard let weight else { return }
        let next = ((weight + sign * BodyWeightLog.step(for: weightUnit)) * 10).rounded() / 10
        if BodyWeightLog.range(for: weightUnit).contains(next) { weightText = FoodNumber.text(next) }
    }

    // MARK: Desired weight (shown in the shown unit; − / + move on whole steps)

    /// The desired weight in the shown unit, full precision; 0 before there is one.
    var desired: Double {
        desiredEntry.map { WeightMath.convert($0.value, from: $0.unit, to: weightUnit) } ?? 0
    }
    var desiredKg: Double { desiredEntry?.kg ?? 0 }
    var desiredStep: Double { weightUnit == .kg ? 0.5 : 1 }

    var ageYears: Int { NutritionGoals.age(birthDate: birthDate, on: now) }

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
        case .body: weightEntry != nil
        case .workouts: workouts != nil
        case .goal: goal != nil && goalBlocked == nil
        case .desired: desiredIsValid
        case .pace: paces != nil
        case .plan: answers != nil
        }
    }

    /// Why the chosen goal cannot be planned: losing when no desired weight (on the − / + steps) lies between the
    /// lowest healthy weight for the height and today's, or when any loss would take the calories under the floor.
    enum GoalBlock: Equatable { case atLowestWeight, calorieFloor(Double) }

    var goalBlocked: GoalBlock? {
        guard goal == .lose, let sex else { return nil }
        if selectableDesired == nil { return .atLowestWeight }
        if paces == nil { return .calorieFloor(NutritionGoals.calorieFloor(sex)) }
        return nil
    }

    var inputs: NutritionGoals.Inputs? {
        guard let sex, let weightKg, let activity, let goal else { return nil }
        return .init(weightKg: weightKg, heightCm: heightEntry.cm, ageYears: ageYears, sex: sex, activity: activity,
                     goal: goal, paceKgPerWeek: goal == .maintain ? nil : paceKg)
    }

    var paces: GoalPlan.Paces? { inputs.flatMap { GoalPlan.paces($0, unit: weightUnit) } }

    /// The allowed desired weights, kg, from the height that will be saved (full precision).
    var desiredRange: ClosedRange<Double>? {
        guard let goal, let weightKg else { return nil }
        return GoalPlan.desiredRange(goal: goal, currentKg: weightKg, heightCm: heightEntry.cm)
    }

    /// The whole steps (0.5 kg / 1 lb) inside the allowed range, in the shown unit; nil when none fits
    /// (codex-review-n13 R5).
    var selectableDesired: ClosedRange<Double>? {
        guard let range = desiredRange else { return nil }
        let step = desiredStep
        let low = (WeightMath.convert(range.lowerBound, from: .kg, to: weightUnit) / step - 1e-9).rounded(.up) * step
        let high = (WeightMath.convert(range.upperBound, from: .kg, to: weightUnit) / step + 1e-9).rounded(.down) * step
        guard low <= high, range.contains(WeightMath.normalizedKg(value: low, unit: weightUnit)) else { return nil }
        return low...high
    }

    private var desiredIsValid: Bool {
        guard let desiredEntry, let range = desiredRange else { return false }
        return range.contains(desiredEntry.kg)
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

    /// What the plan's commit saves — the entered pairs; nil while an answer is missing.
    var answers: GoalSetupStore.Answers? {
        guard let sex, let weightEntry, let activity, let goal, Self.ageRange.contains(ageYears) else { return nil }
        let losesOrGains = goal != .maintain
        if losesOrGains && (paceKg <= 0 || !desiredIsValid) { return nil }
        return .init(sex: sex, birthDate: birthDate, height: heightEntry, weight: weightEntry,
                     activity: activity, goal: goal,
                     desired: losesOrGains ? desiredEntry : nil,
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
    /// changed) becomes 5 kg (10 lb) from today's in the goal's direction, on a whole step inside the range; a pace
    /// outside the offered ones becomes the recommended pace. A valid prefilled desired weight is kept as entered.
    private func prepare(_ next: Step) {
        switch next {
        case .desired:
            guard !desiredIsValid, let selectable = selectableDesired, let weight else { return }
            let offset = weightUnit == .kg ? 5.0 : 10.0
            let start = rounded(goal == .gain ? weight + offset : weight - offset, step: desiredStep)
            desiredEntry = .init(value: min(max(start, selectable.lowerBound), selectable.upperBound), unit: weightUnit)
        case .pace:
            if let paces, !(paces.slow - 1e-9...paces.fast + 1e-9).contains(paceKg) { paceKg = paces.recommended }
        default:
            break
        }
    }

    /// − / +: to the next whole step in the shown unit (from an off-step prefilled value, the nearest step that way),
    /// kept inside the selectable steps.
    func stepDesired(by sign: Double) {
        guard let next = nextDesired(by: sign) else { return }
        desiredEntry = .init(value: next, unit: weightUnit)
    }

    /// Where − / + would go, in the shown unit; nil when that is outside the selectable steps.
    private func nextDesired(by sign: Double) -> Double? {
        guard let selectable = selectableDesired else { return nil }
        let position = desired / desiredStep
        let onStep = abs(position - position.rounded()) < 1e-6
        let target = onStep ? position.rounded() + sign : (sign > 0 ? position.rounded(.up) : position.rounded(.down))
        let next = target * desiredStep
        return selectable.contains(next) ? next : nil
    }

    /// No lower target is offered: − would leave the range (a BMI of 18.5). The same candidate as −'s
    /// (codex-review-n13 R2-2: an off-step 133.38 lb still has 133 lb below it).
    var desiredAtLowest: Bool {
        goal == .lose && selectableDesired != nil && nextDesired(by: -1) == nil
    }

    /// Metric ⇄ imperial: only what is shown changes; the entered pairs stay as they are.
    func switchUnits(to new: Units) {
        guard new != units else { return }
        units = new
        if weightEntry != nil { weightTextStorage = shownWeightText }
    }

    private func rounded(_ value: Double, step: Double) -> Double { (value / step).rounded() * step }
    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int { min(max(value, range.lowerBound), range.upperBound) }
}
