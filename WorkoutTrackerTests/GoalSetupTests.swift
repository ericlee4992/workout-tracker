import CoreData
import CryptoKit
import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N13 (D84), acceptance 2: the pace math and its safe bounds, the calorie floor, units, the time to the
/// desired weight; the setup's commit (what it writes and what it leaves as entered); the draft; export v13.
@MainActor
struct GoalSetupTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private func inputs(kg: Double = 80, cm: Double = 180, age: Int = 30, sex: BiologicalSex = .male,
                        activity: ActivityLevel = .moderate, goal: WeightGoal = .lose) -> NutritionGoals.Inputs {
        .init(weightKg: kg, heightCm: cm, ageYears: age, sex: sex, activity: activity, goal: goal)
    }

    private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-6) -> Bool { abs(a - b) < tolerance }

    // MARK: Paces and bounds

    @Test func lossPacesAreAQuarterHalfAndOnePercentOfBodyWeight() throws {
        let paces = try #require(GoalPlan.paces(inputs(kg: 80), unit: .kg))
        #expect(close(paces.slow, 0.2) && close(paces.recommended, 0.4) && close(paces.fast, 0.8))
        #expect(!paces.heldByFloor)
    }

    @Test func gainPacesAreAnEighthAQuarterAndHalfAPercent() throws {
        let paces = try #require(GoalPlan.paces(inputs(kg: 80, goal: .gain), unit: .kg))
        #expect(close(paces.slow, 0.1) && close(paces.recommended, 0.2) && close(paces.fast, 0.4))
    }

    @Test func theFastestPacesAreCapped() throws {
        let lose = try #require(GoalPlan.paces(inputs(kg: 130, cm: 190, activity: .veryActive), unit: .kg))
        #expect(close(lose.fast, 0.9), "1 % of 130 kg is 1.3 kg: capped at 0.9 kg (2 lb) a week")
        let gain = try #require(GoalPlan.paces(inputs(kg: 130, cm: 190, goal: .gain), unit: .kg))
        #expect(close(gain.fast, 0.5), "0.5 % of 130 kg is 0.65 kg: capped at 0.5 kg")
    }

    @Test func pacesRoundToATenthOfAPoundInPounds() throws {
        let paces = try #require(GoalPlan.paces(inputs(kg: 80), unit: .lb))
        let step = 0.1 * WeightMath.kilogramsPerPound
        for pace in [paces.slow, paces.recommended, paces.fast] {
            #expect(close((pace / step).rounded() * step, pace), "\(pace) kg is a whole number of 0.1 lb")
        }
        #expect(GoalSetupFormat.pace(paces.recommended, unit: .lb) == "0.9")
    }

    @Test func maintainHasNoPace() {
        #expect(GoalPlan.paces(inputs(goal: .maintain), unit: .kg) == nil)
        #expect(GoalPlan.desiredRange(goal: .maintain, currentKg: 80, heightCm: 180) == nil)
    }

    @Test func aLossThatWouldGoUnderTheFloorIsHeld() throws {
        // A small, light woman: maintenance ≈ 1,470; 1 % of 50 kg is 0.5 kg = 550 a day, which would leave 920.
        let small = inputs(kg: 50, cm: 155, age: 40, sex: .female, activity: .light)
        let maintenance = GoalPlan.maintenanceCalories(small)
        let paces = try #require(GoalPlan.paces(small, unit: .kg))
        #expect(paces.heldByFloor)
        #expect(GoalPlan.calories(small, kgPerWeek: paces.fast) >= 1_200)
        #expect(maintenance + GoalPlan.dailyAdjustment(goal: .lose, kgPerWeek: paces.fast) >= 1_200 - 1)
        #expect(paces.slow <= paces.recommended && paces.recommended <= paces.fast)
    }

    @Test func noLossIsOfferedWhenTheFloorLeavesNoRoom() {
        // Sedentary, 45 kg, 150 cm, 70 years: maintenance under the 1,200 floor.
        let tiny = inputs(kg: 45, cm: 150, age: 70, sex: .female, activity: .sedentary)
        #expect(GoalPlan.maintenanceCalories(tiny) < 1_200)
        #expect(GoalPlan.paces(tiny, unit: .kg) == nil)
    }

    @Test func aPaceIsSevenThousandSevenHundredCaloriesAKilogram() {
        #expect(GoalPlan.dailyAdjustment(goal: .lose, kgPerWeek: 0.5) == -550)
        #expect(GoalPlan.dailyAdjustment(goal: .gain, kgPerWeek: 0.25) == 275)
        #expect(GoalPlan.dailyAdjustment(goal: .maintain, kgPerWeek: 0.5) == 0)
        // 80 kg, 180 cm, 30, male, moderate: (800 + 1,125 − 150 + 5) × 1.55 = 2,759; −0.4 kg a week = −440.
        #expect(GoalPlan.calories(inputs(), kgPerWeek: 0.4) == 2_319)
    }

    @Test func aGoalWithoutAPaceKeepsTheFixedAdjustment() {
        var lose = inputs()
        #expect(NutritionGoals.calories(lose) == 2_259, "N3's −500 for a goal from before N13")
        lose.paceKgPerWeek = 0.4
        #expect(NutritionGoals.calories(lose) == 2_319)
        var maintain = inputs(goal: .maintain)
        maintain.paceKgPerWeek = 0.4
        #expect(NutritionGoals.calories(maintain) == 2_759, "maintain ignores a stray pace")
    }

    @Test func theCalorieFloorStillHolds() {
        let small = inputs(kg: 50, cm: 155, age: 40, sex: .female, activity: .light)
        #expect(GoalPlan.calories(small, kgPerWeek: 0.9) == 1_200)
    }

    @Test func timeToTheDesiredWeight() throws {
        #expect(GoalPlan.weeks(fromKg: 80, toKg: 75, kgPerWeek: 0.5) == 10)
        #expect(GoalPlan.weeks(fromKg: 80, toKg: 80, kgPerWeek: 0.5) == nil)
        #expect(GoalPlan.weeks(fromKg: 80, toKg: 75, kgPerWeek: 0) == nil)
        let arrival = try #require(GoalPlan.arrival(fromKg: 68.5, toKg: 63.5, kgPerWeek: 0.35, now: date(12, 14),
                                                    calendar: calendar))
        // 5 kg at 0.35 kg a week: 100 days after Nov 12.
        #expect(calendar.dateComponents([.year, .month, .day], from: arrival)
                == DateComponents(year: 2027, month: 2, day: 20))
        let partDay = try #require(GoalPlan.arrival(fromKg: 80, toKg: 79, kgPerWeek: 0.3, now: date(12, 14),
                                                    calendar: calendar))
        // 23.3 days → the 24th day.
        #expect(calendar.dateComponents([.month, .day], from: partDay) == DateComponents(month: 12, day: 6))
    }

    @Test func aDesiredWeightToLoseToStopsAtABMIOfEighteenAndAHalf() throws {
        let range = try #require(GoalPlan.desiredRange(goal: .lose, currentKg: 80, heightCm: 180))
        #expect(close(range.lowerBound, 18.5 * 1.8 * 1.8) && close(range.upperBound, 79.5))
        let gain = try #require(GoalPlan.desiredRange(goal: .gain, currentKg: 80, heightCm: 180))
        #expect(gain == 80.5...110)
        #expect(GoalPlan.desiredRange(goal: .lose, currentKg: 59, heightCm: 180) == nil, "already under BMI 18.5")
    }

    @Test func workoutsAWeekSetTheActivity() {
        #expect(GoalPlan.WorkoutsPerWeek.few.activity == .light)
        #expect(GoalPlan.WorkoutsPerWeek.some.activity == .moderate)
        #expect(GoalPlan.WorkoutsPerWeek.many.activity == .veryActive)
        #expect(GoalPlan.WorkoutsPerWeek(activity: .sedentary) == .few)
        #expect(GoalPlan.WorkoutsPerWeek(activity: .extraActive) == .many)
    }

    // MARK: The commit

    private func answers(height: GoalSetupStore.Height = .init(value: 180, unit: .cm),
                         weight: GoalSetupStore.Weight = .init(value: 80, unit: .kg),
                         goal: WeightGoal = .lose) -> GoalSetupStore.Answers {
        .init(sex: .male, birthDate: calendar.date(from: DateComponents(year: 1996, month: 11, day: 1))!,
              height: height, weight: weight, activity: .moderate, goal: goal,
              desired: goal == .maintain ? nil : .init(value: goal == .lose ? 75 : 85, unit: weight.unit),
              paceKgPerWeek: goal == .maintain ? nil : 0.4)
    }

    @Test func aNewInstallsCommitWritesPersonalDetailsTheWeightAndTheGoal() throws {
        let context = try context()
        let goal = try #require(try GoalSetupStore.commit(answers(), in: context, now: date(12), calendar: calendar))
        let preferences = try AppPreferences.canonical(in: context)
        #expect(preferences.sex == .male && preferences.heightValue == 180 && preferences.heightUnit == .cm)
        #expect(preferences.birthDate == calendar.date(from: DateComponents(year: 1996, month: 11, day: 1)))
        let weights = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        #expect(weights.count == 1 && weights.first?.value == 80 && weights.first?.unit == .kg)
        #expect(weights.first?.source == .app)
        #expect(goal.calories == 2_319 && goal.goal == .lose && goal.activity == .moderate)
        #expect(goal.desiredWeightValue == 75 && goal.desiredWeightUnit == .kg && goal.desiredWeightKg == 75)
        #expect(goal.paceKgPerWeek == 0.4)
        #expect(goal.effectiveFrom == calendar.startOfDay(for: date(12)))
        #expect(goal.proteinGrams == 144, "1.8 g a kg")
    }

    @Test func aPoundUserIsStoredInPoundsAndInches() throws {
        let context = try context()
        let weight = GoalSetupStore.Weight(value: 176.4, unit: .lb)
        var lb = answers(height: .init(value: 71, unit: .inches), weight: weight)
        lb.desired = .init(value: 165, unit: .lb)
        let goal = try #require(try GoalSetupStore.commit(lb, in: context, now: date(12), calendar: calendar))
        let preferences = try AppPreferences.canonical(in: context)
        #expect(preferences.heightValue == 71 && preferences.heightUnit == .inches)
        #expect(close(preferences.heightCm ?? 0, 180.34))
        #expect(goal.desiredWeightValue == 165 && goal.desiredWeightUnit == .lb)
        #expect(close(goal.desiredWeightKg ?? 0, 165 * WeightMath.kilogramsPerPound))
        #expect(close(goal.weightKg ?? 0, 176.4 * WeightMath.kilogramsPerPound))
    }

    @Test func anExistingUsersUnchangedHeightAndWeightStayAsEntered() throws {
        let context = try context()
        // Entered earlier: 70.9 in (shown as 71 in, or 180 cm), 176.37 lb.
        let preferences = try AppPreferences.canonical(in: context)
        preferences.setHeight(value: 70.9, unit: .inches)
        context.insert(BodyWeightEntry(measuredAt: date(8), value: 176.37, unit: .lb, createdAt: date(8)))
        try context.save()

        let prefill = try GoalSetupStore.prefill(in: context)
        let draft = GoalSetupDraft(prefill: prefill, now: date(12), calendar: calendar)
        #expect(draft.units == .imperial && draft.heightInches == 71 && draft.weightText == "176.37", "shown as entered")
        var shown = answers(height: draft.height, weight: .init(value: try #require(draft.weight), unit: .lb))
        shown.desired = .init(value: 165, unit: .lb)
        try GoalSetupStore.commit(shown, in: context, now: date(12), calendar: calendar)

        #expect(preferences.heightValue == 70.9 && preferences.heightUnit == .inches, "D52: not rewritten as 71")
        #expect(try context.fetchCount(FetchDescriptor<BodyWeightEntry>()) == 1, "no duplicate weigh-in")
    }

    @Test func aChangedWeightIsANewWeighIn() throws {
        let context = try context()
        try GoalSetupStore.commit(answers(), in: context, now: date(10), calendar: calendar)
        try GoalSetupStore.commit(answers(weight: .init(value: 79.2, unit: .kg)), in: context, now: date(12),
                                  calendar: calendar)
        let weights = try context.fetch(FetchDescriptor<BodyWeightEntry>()).map(\.value).sorted()
        #expect(weights == [79.2, 80])
    }

    @Test func aRunTheSameDayUpdatesTodaysGoalAndALaterDayAddsOne() throws {
        let context = try context()
        try GoalSetupStore.commit(answers(), in: context, now: date(10), calendar: calendar)
        try GoalSetupStore.commit(answers(goal: .gain), in: context, now: date(10, 15), calendar: calendar)
        #expect(try context.fetchCount(FetchDescriptor<NutritionGoal>()) == 1)
        try GoalSetupStore.commit(answers(goal: .maintain), in: context, now: date(12), calendar: calendar)
        let goals = try context.fetch(FetchDescriptor<NutritionGoal>()).sorted { $0.effectiveFrom < $1.effectiveFrom }
        #expect(goals.count == 2, "D70: past days keep their goal")
        #expect(goals[0].goal == .gain && goals[0].desiredWeightValue == 85)
        #expect(goals[1].goal == .maintain && goals[1].desiredWeightValue == nil && goals[1].paceKgPerWeek == nil)
        #expect(goals[1].calories == 2_759)
    }

    @Test func typedNumbersFromThePlanAreKept() throws {
        let context = try context()
        var typed = answers()
        typed.overrides.proteinGrams = 170
        let goal = try #require(try GoalSetupStore.commit(typed, in: context, now: date(12), calendar: calendar))
        #expect(goal.proteinGrams == 170 && goal.proteinOverridden && !goal.caloriesOverridden)
    }

    @Test func aLaterWeightKeepsThePace() throws {
        let context = try context()
        try GoalSetupStore.commit(answers(), in: context, now: date(10), calendar: calendar)
        context.insert(BodyWeightEntry(measuredAt: date(12), value: 78, unit: .kg, createdAt: date(12)))
        try context.save()
        let goal = try #require(try NutritionGoalStore.update(in: context, now: date(12), calendar: calendar))
        #expect(goal.paceKgPerWeek == 0.4 && goal.desiredWeightValue == 75)
        // (780 + 1,125 − 150 + 5) × 1.55 = 2,728 − 440.
        #expect(goal.calories == 2_288)
    }

    // MARK: The draft

    @Test func theDraftAsksEverythingAndMaintainSkipsTwoPages() {
        let draft = GoalSetupDraft(now: date(12), calendar: calendar)
        #expect(!draft.isExistingUser && draft.step == .sex && !draft.canContinue)
        #expect(draft.steps.count == 8)
        draft.goal = .maintain
        #expect(draft.steps == [.sex, .birthDate, .body, .workouts, .goal, .plan])
        #expect(draft.answers == nil)
    }

    @Test func walkingTheDraftReachesAPlan() throws {
        let draft = GoalSetupDraft(now: date(12), calendar: calendar)
        draft.sex = .female; draft.advance()
        draft.birthDate = calendar.date(from: DateComponents(year: 1996, month: 8, day: 2))!; draft.advance()
        draft.heightCm = 168; draft.weightText = "68.5"; draft.advance()
        draft.workouts = .some; draft.advance()
        draft.goal = .lose; draft.advance()
        #expect(draft.step == .desired && draft.desired == 63.5, "5 kg below today's weight")
        draft.advance()
        #expect(draft.step == .pace && close(draft.paceKg, 0.35), "the recommended pace")
        draft.advance()
        let answers = try #require(draft.answers)
        #expect(answers.desired == .init(value: 63.5, unit: .kg) && answers.paceKgPerWeek == draft.paceKg)
        #expect(answers.activity == .moderate && answers.height == .init(value: 168, unit: .cm))
        #expect(draft.plan?.calories == 1_822)
    }

    @Test func anExistingUsersFinerActivitySurvivesAnUntouchedAnswer() throws {
        var choices = NutritionGoalStore.Choices()
        choices.activity = .extraActive
        let draft = GoalSetupDraft(prefill: .init(sex: .male, choices: choices), now: date(12), calendar: calendar)
        #expect(draft.workouts == .many && draft.activity == .extraActive)
        draft.workouts = .some
        #expect(draft.activity == .moderate)
    }

    @Test func aLoseGoalAlreadyAtTheLowestWeightIsBlocked() {
        let draft = GoalSetupDraft(now: date(12), calendar: calendar)
        draft.sex = .female
        draft.heightCm = 180
        draft.weightText = "59"
        draft.workouts = .some
        draft.goal = .lose
        draft.step = .goal
        #expect(draft.goalBlocked == .atLowestWeight && !draft.canContinue)
        draft.goal = .gain
        #expect(draft.goalBlocked == nil && draft.canContinue)
    }

    @Test func switchingUnitsConvertsWhatIsShown() {
        let draft = GoalSetupDraft(now: date(12), calendar: calendar)
        draft.heightCm = 180
        draft.weightText = "80"
        draft.switchUnits(to: .imperial)
        #expect(draft.heightInches == 71 && draft.weightText == "176.4" && draft.weightUnit == .lb)
        draft.switchUnits(to: .metric)
        #expect(draft.heightCm == 180 && draft.weightText == "80")
    }

    // MARK: codex-review-n13 — entered pairs survive display conversions

    /// R1: Metric → Imperial → Metric on an untouched 171 cm / 100 lb rewrites neither (171 cm showed back as 170).
    @Test func unitSwitchesLeaveUntouchedMeasurementsAsEntered() throws {
        let context = try context()
        let preferences = try AppPreferences.canonical(in: context)
        preferences.setHeight(value: 171, unit: .cm)
        context.insert(BodyWeightEntry(measuredAt: date(8), value: 100, unit: .lb, createdAt: date(8)))
        try context.save()
        let draft = GoalSetupDraft(prefill: try GoalSetupStore.prefill(in: context), now: date(12), calendar: calendar)
        draft.sex = .male
        draft.workouts = .some
        draft.goal = .maintain
        #expect(draft.units == .imperial)
        draft.switchUnits(to: .metric)
        #expect(draft.weightText == "45.4" && draft.heightCm == 171)
        draft.switchUnits(to: .imperial)
        draft.switchUnits(to: .metric)
        #expect(draft.height == .init(value: 171, unit: .cm))
        let answers = try #require(draft.answers)
        #expect(answers.weight == .init(value: 100, unit: .lb), "shown as 45.4 kg, kept as entered")
        try GoalSetupStore.commit(answers, in: context, now: date(12), calendar: calendar)
        #expect(preferences.heightValue == 171 && preferences.heightUnit == .cm)
        #expect(try context.fetchCount(FetchDescriptor<BodyWeightEntry>()) == 1, "no weigh-in from a unit switch")

        // A wheel or field change is an answer in the shown unit.
        draft.heightCm = 172
        draft.weightText = "46"
        #expect(draft.height == .init(value: 172, unit: .cm) && draft.answers?.weight == .init(value: 46, unit: .kg))
    }

    /// R2: a 75 kg target, then a weigh-in in lb: reopening and saving unchanged keeps 75 kg (not 165 lb).
    @Test func reopeningKeepsAnUntouchedDesiredWeightAsEntered() throws {
        let context = try context()
        try GoalSetupStore.commit(answers(), in: context, now: date(10), calendar: calendar)
        context.insert(BodyWeightEntry(measuredAt: date(11), value: 176.4, unit: .lb, createdAt: date(11)))
        try context.save()
        let draft = GoalSetupDraft(prefill: try GoalSetupStore.prefill(in: context), now: date(12), calendar: calendar)
        #expect(draft.units == .imperial && abs(draft.desired - 75 / WeightMath.kilogramsPerPound) < 1e-9)
        draft.step = .goal
        draft.advance()
        #expect(draft.step == .desired && draft.desiredEntry == .init(value: 75, unit: .kg), "kept, not re-defaulted")
        let unchanged = try #require(draft.answers)
        let goal = try #require(try GoalSetupStore.commit(unchanged, in: context, now: date(12), calendar: calendar))
        #expect(goal.desiredWeightValue == 75 && goal.desiredWeightUnit == .kg && goal.desiredWeightKg == 75)
        // − moves to the next whole lb below 165.3 lb.
        draft.stepDesired(by: -1)
        #expect(draft.desiredEntry == .init(value: 165, unit: .lb))
    }

    /// R4: the bounds use the height that will be saved (180.49 cm), not the 180 cm shown — untouched, and after a wheel
    /// edit inside the same rounding (R2-1: 181 → 180 cm saves 180 cm, the height the bound was checked against).
    @Test func theLowestDesiredWeightUsesTheSavedHeight() throws {
        let precise = GoalSetupStore.Height(value: 180.49, unit: .cm)
        let born = calendar.date(from: DateComponents(year: 1990, month: 5, day: 1))!
        for units in [GoalSetupDraft.Units.metric, .imperial] {
            for editsHeight in [false, true] {
                let context = try context()
                let preferences = try AppPreferences.canonical(in: context)
                preferences.setHeight(value: 180.49, unit: .cm)
                preferences.birthDate = born
                preferences.sex = .male
                context.insert(BodyWeightEntry(measuredAt: date(8), value: 65, unit: .kg, createdAt: date(8)))
                try context.save()
                let draft = GoalSetupDraft(prefill: try GoalSetupStore.prefill(in: context), now: date(12),
                                           calendar: calendar)
                draft.switchUnits(to: units)
                if editsHeight { draft.heightCm = 181; draft.heightCm = 180 }
                draft.workouts = .some
                draft.goal = .lose
                draft.step = .goal
                draft.advance()
                #expect(draft.step == .desired)
                for _ in 0..<5 { draft.stepDesired(by: -1) }
                #expect(draft.desiredAtLowest)
                draft.step = .pace
                draft.paceKg = 0.3
                let answers = try #require(draft.answers, "\(units), edited \(editsHeight)")
                #expect(answers.height == (editsHeight ? .init(value: 180, unit: .cm) : precise))
                try GoalSetupStore.commit(answers, in: context, now: date(12), calendar: calendar)
                let saved = try #require(preferences.heightCm)
                let goal = try #require(try NutritionGoalStore.latestGoal(in: context))
                let bmi = try #require(goal.desiredWeightKg) / (saved / 100 * saved / 100)
                #expect(saved == (editsHeight ? 180 : 180.49), "the saved height is the answer")
                #expect(bmi >= 18.5, "\(units), edited \(editsHeight): BMI \(bmi)")
            }
        }
    }

    /// R2-1: a weight edit inside one display rounding is a new weigh-in.
    @Test func aSmallWeightEditIsANewWeighIn() throws {
        let context = try context()
        context.insert(BodyWeightEntry(measuredAt: date(8), value: 176.37, unit: .lb, createdAt: date(8)))
        try context.save()
        let draft = GoalSetupDraft(prefill: try GoalSetupStore.prefill(in: context), now: date(12), calendar: calendar)
        draft.weightText = "176.36"
        var edited = answers(height: .init(value: 71, unit: .inches), weight: try #require(draft.weightEntry))
        edited.desired = .init(value: 165, unit: .lb)
        try GoalSetupStore.commit(edited, in: context, now: date(12), calendar: calendar)
        let values = try context.fetch(FetchDescriptor<BodyWeightEntry>()).map(\.value).sorted()
        #expect(values == [176.36, 176.37])
    }

    /// R2-2: an off-step preserved target just above the lowest step is not "the lowest" until − reaches that step.
    @Test func theLowestCaptionFollowsTheMinusStep() throws {
        var choices = NutritionGoalStore.Choices()
        choices.goal = .lose
        choices.desired = .init(value: 60.5, unit: .kg)
        choices.paceKgPerWeek = 0.3
        let draft = GoalSetupDraft(prefill: .init(sex: .male, birthDate: date(1), height: .init(value: 180.49, unit: .cm),
                                                  weight: .init(value: 143.3, unit: .lb), choices: choices),
                                   now: date(12), calendar: calendar)
        draft.step = .goal
        draft.advance()
        #expect(draft.step == .desired && abs(draft.desired - 60.5 / WeightMath.kilogramsPerPound) < 1e-9)
        #expect(!draft.desiredAtLowest, "133 lb is still below 133.38 lb")
        draft.stepDesired(by: -1)
        #expect(draft.desiredEntry == .init(value: 133, unit: .lb) && draft.desiredAtLowest)
    }

    /// R5: a loss range narrower than one step is refused on the goal page; any admitted loss has a selectable
    /// desired weight, in kg and in lb.
    @Test func anAdmittedLossAlwaysHasASelectableDesiredWeight() throws {
        let narrow = GoalSetupDraft(prefill: .init(sex: .female, birthDate: date(1), height: .init(value: 171, unit: .cm),
                                                   weight: .init(value: 54.6, unit: .kg)), now: date(12), calendar: calendar)
        narrow.workouts = .some
        narrow.goal = .lose
        #expect(narrow.goalBlocked == .atLowestWeight)

        var admitted = 0
        for unit in [WeightUnit.kg, .lb] {
            for cm in stride(from: 150.0, through: 195.0, by: 1.37) {
                let lowest = 18.5 * cm * cm / 10_000
                for extra in stride(from: 0.3, through: 2.4, by: 0.07) {
                    let kg = lowest + extra
                    let value = unit == .kg ? kg : kg / WeightMath.kilogramsPerPound
                    let draft = GoalSetupDraft(
                        prefill: .init(sex: .male, birthDate: date(1), height: .init(value: cm, unit: .cm),
                                       weight: .init(value: value, unit: unit)), now: date(12), calendar: calendar)
                    draft.workouts = .some
                    draft.goal = .lose
                    draft.step = .goal
                    guard draft.goalBlocked == nil else { continue }
                    admitted += 1
                    draft.advance()
                    #expect(draft.step == .desired && draft.canContinue, "\(cm) cm, \(value) \(unit)")
                }
            }
        }
        #expect(admitted > 100)
    }

    // MARK: Export v13

    @Test func exportCarriesTheDesiredWeightAndPaceAndAV12FileStillDecodes() throws {
        let context = try context()
        try GoalSetupStore.commit(answers(), in: context, now: date(12), calendar: calendar)
        let collector = ExportCollector(dateFormat: ExportDateFormat(timeZone: calendar.timeZone), appVersion: "test")
        let snapshot = try collector.snapshot(from: context)
        #expect(snapshot.schemaVersion == 14)
        let row = try #require(snapshot.nutritionGoals?.first)
        #expect(row.desiredWeightValue == 75 && row.desiredWeightUnit == .kg && row.desiredWeightKg == 75)
        #expect(row.paceKgPerWeek == 0.4)
        let data = try ExportJSON.data(snapshot)
        #expect(try ExportJSON.decode(data) == snapshot)

        // v12: the goal rows have none of the four keys.
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var goals = try #require(object["nutritionGoals"] as? [[String: Any]])
        for key in ["desiredWeightValue", "desiredWeightUnit", "desiredWeightKg", "paceKgPerWeek"] {
            #expect(goals[0].removeValue(forKey: key) != nil, "\(key) was in the v13 file")
        }
        object["nutritionGoals"] = goals
        object["schemaVersion"] = 12
        let decoded = try ExportJSON.decode(try JSONSerialization.data(withJSONObject: object))
        let old = try #require(decoded.nutritionGoals?.first)
        #expect(old.desiredWeightValue == nil && old.paceKgPerWeek == nil && old.calories == row.calories)
    }

    @Test func aMaintainGoalExportsWithoutTheNewKeys() throws {
        let context = try context()
        try GoalSetupStore.commit(answers(goal: .maintain), in: context, now: date(12), calendar: calendar)
        let collector = ExportCollector(dateFormat: ExportDateFormat(timeZone: calendar.timeZone), appVersion: "test")
        let text = String(decoding: try ExportJSON.data(try collector.snapshot(from: context)), as: UTF8.self)
        #expect(!text.contains("desiredWeight") && !text.contains("paceKgPerWeek") && !text.contains("null"))
    }
}

/// N13's stored-format change: `Fixtures/Release020.store` is a store in 0.2.0's format (TestFlight build 10) — written
/// 2026-11-12 by the app at `main` `e6255e85` (no model change since 0.2.0's `e48ca60`) under `-uiTestReset` with the
/// design sample, Personal details, the food sample and diary, and the nutrition charts' weigh-ins: 7 workouts,
/// 58 sets, 3 templates, 18 food entries, 7 saved foods, 2 meals, 1 goal, 29 weights. The first test proves that format
/// from the store's own metadata. Opened with today's model it must migrate with the rows and key values intact (read
/// with sqlite3), the new goal fields empty, and the goal unchanged by a refresh — and the safety copy must see it first.
struct GoalSetupMigrationTests {
    private final class BundleMarker {}

    private func fixtureURL() throws -> URL {
        try #require(Bundle(for: BundleMarker.self).url(forResource: "Release020", withExtension: "store"),
                     "the 0.2.0 fixture must ship with the test bundle")
    }

    private func copiedFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "release-020-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let copy = directory.appending(path: "default.store")
        try FileManager.default.copyItem(at: try fixtureURL(), to: copy)
        return copy
    }

    @Test func theFixtureIsInZeroTwoZerosFormat() throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: try fixtureURL())
        let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
        let hex = { (data: Data) in data.map { String(format: "%02x", $0) }.joined() }
        let lines = hashes.sorted { $0.key < $1.key }.map { "\($0.key):\(hex($0.value))" }
        let fingerprint = hex(Data(SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))))
        #expect(fingerprint == StoreFormatGuardTests.release020Fingerprint)
    }

    @Test func theSafetyCopySeesTheChangeBeforeTheOpen() throws {
        let model = NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes)
        #expect(SafetyCopies.storeNeedsCopy(at: try fixtureURL(), model: model))
    }

    @Test @MainActor func everyRowAndTheGoalSurviveTheMigration() throws {
        let url = try copiedFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let context = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
        func count<T: PersistentModel>(_: T.Type) throws -> Int { try context.fetchCount(FetchDescriptor<T>()) }

        #expect(try count(Workout.self) == 7)
        #expect(try count(ExerciseEntry.self) == 26)
        #expect(try count(SetRecord.self) == 58)
        #expect(try count(WorkoutTemplate.self) == 3)
        #expect(try count(FoodEntry.self) == 18)
        #expect(try count(SavedFood.self) == 7)
        #expect(try count(SavedMeal.self) == 2)
        #expect(try count(SavedMealItem.self) == 4)
        #expect(try count(NutritionGoal.self) == 1)
        #expect(try count(BodyWeightEntry.self) == 29)
        #expect(try count(AppPreferences.self) == 1)
        #expect(try count(Exercise.self) == 90)
        #expect(try count(EquipmentModel.self) == 1877)

        let sets = try context.fetch(FetchDescriptor<SetRecord>())
        #expect(abs(sets.compactMap(\.normalizedKg).reduce(0, +) - 1610.2529) < 0.001)
        #expect(sets.compactMap(\.reps).reduce(0, +) == 540)
        let food = try context.fetch(FetchDescriptor<FoodEntry>())
        #expect(abs(food.map(\.calories).reduce(0, +) - 4675) < 0.01)
        let weights = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        #expect(abs(weights.map(\.normalizedKg).reduce(0, +) - 2369.158) < 0.001)
        let preferences = try #require(AppPreferences.canonical(of: try context.fetch(FetchDescriptor<AppPreferences>())))
        #expect(preferences.heightValue == 71 && preferences.heightUnit == .inches && preferences.sex == .male)

        let goal = try #require(try context.fetch(FetchDescriptor<NutritionGoal>()).first)
        #expect(goal.calories == 2_763 && goal.proteinGrams == 144 && goal.carbsGrams == 374 && goal.fatGrams == 77)
        #expect(goal.goal == .maintain && goal.activity == .moderate && goal.sex == .male && goal.ageYears == 30)
        #expect(goal.desiredWeightValue == nil && goal.desiredWeightUnit == nil && goal.desiredWeightKg == nil)
        #expect(goal.paceKgPerWeek == nil)
        #expect(NutritionGoalStore.choices(of: goal).desired == nil)

        // A refresh (Nutrition goals opening, a new weigh-in elsewhere) on the fixture's day leaves the migrated goal as
        // it was: no pace means N3's adjustment, and nothing differs (codex-review-n13).
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12))!
        let refreshed = try #require(try NutritionGoalStore.update(in: context, now: day, calendar: calendar))
        #expect(refreshed.id == goal.id && refreshed.calories == 2_763 && refreshed.paceKgPerWeek == nil)
        #expect(try count(NutritionGoal.self) == 1)
    }
}
