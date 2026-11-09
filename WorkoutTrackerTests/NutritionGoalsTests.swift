import Foundation
import Testing

@testable import WorkoutTracker

/// Nutrition N3: the approved goal calculation, checked against hand-worked examples (the arithmetic is in each test's
/// comment so a reader can redo it).
struct NutritionGoalsTests {
    private func inputs(_ kg: Double, _ cm: Double, _ age: Int, _ sex: BiologicalSex,
                        _ activity: ActivityLevel, _ goal: WeightGoal) -> NutritionGoals.Inputs {
        .init(weightKg: kg, heightCm: cm, ageYears: age, sex: sex, activity: activity, goal: goal)
    }

    /// 80 kg, 180 cm, 30, male: 800 + 1125 − 150 + 5 = 1780; × 1.55 = 2759. Protein 1.8 × 80 = 144;
    /// fat 0.25 × 2759 / 9 = 76.6 → 77; carbs (2759 − 576 − 693) / 4 = 372.5 → 373.
    @Test func maleModerateMaintain() {
        let goal = NutritionGoals.suggested(inputs(80, 180, 30, .male, .moderate, .maintain))
        #expect(goal == Macros(calories: 2759, proteinGrams: 144, carbsGrams: 373, fatGrams: 77))
    }

    /// 60 kg, 165 cm, 25, female: 600 + 1031.25 − 125 − 161 = 1345.25; × 1.375 = 1849.7; − 500 = 1349.7 → 1350.
    /// Protein 108; fat 0.25 × 1350 / 9 = 37.5 → 38; carbs (1350 − 432 − 342) / 4 = 144.
    @Test func femaleLightLose() {
        let goal = NutritionGoals.suggested(inputs(60, 165, 25, .female, .light, .lose))
        #expect(goal == Macros(calories: 1350, proteinGrams: 108, carbsGrams: 144, fatGrams: 38))
    }

    /// 70 kg, 175 cm, 40, prefer not to say: 700 + 1093.75 − 200 − 78 = 1515.75; × 1.725 = 2614.7; + 250 = 2864.7
    /// → 2865. Protein 126; fat 79.6 → 80; carbs (2865 − 504 − 720) / 4 = 410.25 → 410.
    @Test func unspecifiedVeryActiveGainUsesTheAverageConstant() {
        let goal = NutritionGoals.suggested(inputs(70, 175, 40, .unspecified, .veryActive, .gain))
        #expect(goal == Macros(calories: 2865, proteinGrams: 126, carbsGrams: 410, fatGrams: 80))
        #expect(NutritionGoals.sexConstant(.unspecified) == -78)
    }

    /// 45 kg, 150 cm, 60, female, sedentary, lose: 450 + 937.5 − 300 − 161 = 926.5; × 1.2 = 1111.8; − 500 = 611.8 —
    /// below the floor, so 1200. A typed number may go lower.
    @Test func theFloorHoldsUntilTheUserTypesLower() {
        let small = inputs(45, 150, 60, .female, .sedentary, .lose)
        #expect(NutritionGoals.calories(small) == 1200)
        #expect(NutritionGoals.calories(inputs(50, 160, 70, .male, .sedentary, .lose)) == 1500)
        #expect(NutritionGoals.calories(inputs(45, 150, 60, .unspecified, .sedentary, .lose)) == 1350)
        let typed = NutritionGoals.resolve(small, overrides: .init(calories: 1000))
        #expect(typed.calories == 1000, "a typed number is the user's to choose")
    }

    @Test func everyActivityFactorAndGoalAdjustment() {
        #expect(ActivityLevel.allCases.map(NutritionGoals.activityFactor) == [1.2, 1.375, 1.55, 1.725, 1.9])
        #expect(WeightGoal.allCases.map(NutritionGoals.goalAdjustment) == [-500, 0, 250])
    }

    /// A typed number stays when the inputs change; the untyped ones follow — fat from the calories in force.
    @Test func typedNumbersStayAndTheRestFollow() {
        let before = inputs(80, 180, 30, .male, .moderate, .maintain)
        let overrides = NutritionGoals.Overrides(calories: 2500, proteinGrams: 180)
        let goal = NutritionGoals.resolve(before, overrides: overrides)
        // fat 0.25 × 2500 / 9 = 69.4 → 69; carbs (2500 − 720 − 621) / 4 = 289.75 → 290.
        #expect(goal == Macros(calories: 2500, proteinGrams: 180, carbsGrams: 290, fatGrams: 69))

        var heavier = before
        heavier.weightKg = 90
        let after = NutritionGoals.resolve(heavier, overrides: overrides)
        #expect(after.calories == 2500 && after.proteinGrams == 180, "typed numbers do not move with the weight")
        #expect(NutritionGoals.suggested(heavier).proteinGrams == 162, "Recalculate (no overrides) follows it")
    }

    @Test func carbsNeverGoNegative() {
        let goal = NutritionGoals.resolve(inputs(80, 180, 30, .male, .moderate, .maintain),
                                          overrides: .init(calories: 1200, proteinGrams: 300))
        #expect(goal.carbsGrams == 0)
    }

    @Test func ageCountsWholeYearsOnTheDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let birth = calendar.date(from: DateComponents(year: 2000, month: 11, day: 10))!
        let dayBefore = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9))!
        let birthday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        #expect(NutritionGoals.age(birthDate: birth, on: dayBefore, calendar: calendar) == 25)
        #expect(NutritionGoals.age(birthDate: birth, on: birthday, calendar: calendar) == 26)
    }
}
