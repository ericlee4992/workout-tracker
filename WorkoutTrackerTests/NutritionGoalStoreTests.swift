import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N3: the stored goal follows Personal details and the user's choices; past days keep theirs (D70, D80).
@MainActor
struct NutritionGoalStoreTests {
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

    /// 80 kg (176.37 lb entered), 180 cm, born Nov 1, 1996 (30 on Nov 9, 2026), male.
    private func fillDetails(_ context: ModelContext) throws {
        let preferences = try AppPreferences.canonical(in: context)
        preferences.setHeight(value: 180, unit: .cm)
        preferences.birthDate = calendar.date(from: DateComponents(year: 1996, month: 11, day: 1))
        preferences.sex = .male
        context.insert(BodyWeightEntry(measuredAt: date(8), value: 80, unit: .kg, createdAt: date(8)))
        try context.save()
    }

    private func goals(_ context: ModelContext) throws -> [NutritionGoal] {
        try context.fetch(FetchDescriptor<NutritionGoal>()).sorted { $0.effectiveFrom < $1.effectiveFrom }
    }

    @Test func nothingIsStoredUntilPersonalDetailsAreComplete() throws {
        let context = try context()
        let preferences = try AppPreferences.canonical(in: context)
        preferences.setHeight(value: 70, unit: .inches)
        #expect(abs((preferences.heightCm ?? 0) - 177.8) < 1e-9)
        try context.save()
        #expect(try NutritionGoalStore.update(in: context, now: date(9), calendar: calendar) == nil)
        #expect(try goals(context).isEmpty)
    }

    /// The first complete details make the first goal: the calculation's numbers (NutritionGoalsTests' first example).
    @Test func completeDetailsMakeTheFirstGoalFromTheCalculation() throws {
        let context = try context()
        try fillDetails(context)
        let goal = try #require(try NutritionGoalStore.update(in: context, now: date(9), calendar: calendar))
        #expect(goal.calories == 2759 && goal.proteinGrams == 144 && goal.carbsGrams == 373 && goal.fatGrams == 77)
        #expect(goal.effectiveFrom == calendar.startOfDay(for: date(9)))
        #expect(goal.weightKg == 80 && goal.heightCm == 180 && goal.ageYears == 30 && goal.sex == .male)
        #expect(goal.activity == .moderate && goal.goal == .maintain && !goal.caloriesOverridden)
        #expect(try NutritionGoalStore.update(in: context, now: date(9, 15), calendar: calendar) === goal)
        #expect(try goals(context).count == 1, "nothing changed, nothing written")
    }

    @Test func sameDayChangesUpdateTodaysGoal() throws {
        let context = try context()
        try fillDetails(context)
        try NutritionGoalStore.update(in: context, now: date(9), calendar: calendar)
        let goal = try #require(try NutritionGoalStore.update(in: context, now: date(9, 14), calendar: calendar) {
            $0.goal = .lose
        })
        #expect(goal.calories == 2259 && goal.goal == .lose)
        #expect(try goals(context).count == 1)
    }

    /// A change on a later day starts a new goal; the earlier day still reads its own (frozen history).
    @Test func aLaterChangeStartsANewGoalAndThePastKeepsItsOwn() throws {
        let context = try context()
        try fillDetails(context)
        try NutritionGoalStore.update(in: context, now: date(9), calendar: calendar)
        try NutritionGoalStore.update(in: context, now: date(12), calendar: calendar) { $0.activity = .veryActive }
        let all = try goals(context)
        #expect(all.count == 2)
        #expect(NutritionMath.goal(on: date(10), among: all, calendar: calendar)?.calories == 2759)
        #expect(NutritionMath.goal(on: date(12), among: all, calendar: calendar)?.activity == .veryActive)
    }

    /// A typed number stays when the weight changes; the rest follow; Recalculate (no overrides) restores them.
    @Test func typedNumbersStayThroughAWeightChangeUntilRecalculate() throws {
        let context = try context()
        try fillDetails(context)
        try NutritionGoalStore.update(in: context, now: date(9), calendar: calendar) {
            $0.overrides.proteinGrams = 180
        }
        context.insert(BodyWeightEntry(measuredAt: date(9, 10), value: 90, unit: .kg, createdAt: date(9, 10)))
        try context.save()
        let after = try #require(try NutritionGoalStore.update(in: context, now: date(9, 11), calendar: calendar))
        #expect(after.proteinGrams == 180 && after.proteinOverridden, "typed")
        #expect(after.weightKg == 90 && after.calories > 2759, "the calories follow the new weight")
        let recalculated = try #require(try NutritionGoalStore.update(in: context, now: date(9, 12), calendar: calendar) {
            $0.overrides = .none
        })
        #expect(recalculated.proteinGrams == 162 && !recalculated.proteinOverridden)
    }

    /// codex-review-n3: once the details are incomplete (the date of birth cleared in the zones sheet), an edit is
    /// refused with an error rather than dropped silently; a plain refresh writes nothing and does not throw.
    @Test func anEditWithIncompleteDetailsIsRefusedNotDropped() throws {
        let context = try context()
        try fillDetails(context)
        let goal = try #require(try NutritionGoalStore.update(in: context, now: date(9), calendar: calendar))
        try AppPreferences.canonical(in: context).birthDate = nil
        try context.save()
        #expect(throws: NutritionGoalStore.Failure.detailsIncomplete) {
            try NutritionGoalStore.update(in: context, now: date(9, 12), calendar: calendar) { $0.goal = .gain }
        }
        #expect(try NutritionGoalStore.update(in: context, now: date(9, 12), calendar: calendar) === goal)
        #expect(goal.goal == .maintain, "unchanged")
    }

    /// The ticket's prefill: what Personal details lack comes from the training profile, as entered; never over a
    /// value already given; the goal follows.
    @Test func missingDetailsComeFromTheTrainingProfile() throws {
        let context = try context()
        let preferences = try AppPreferences.canonical(in: context)
        preferences.birthDate = calendar.date(from: DateComponents(year: 1996, month: 11, day: 1))
        preferences.sex = .male
        try context.save()
        let training = TrainingProfile(goals: "", experience: "Beginner", days: 3, minutes: 45,
                                       height: BodyMeasure(value: 70.5, unit: .inches),
                                       weight: BodyMeasure(value: 180.4, unit: .lb))
        #expect(try NutritionGoalStore.prefillMissing(from: training, in: context, now: date(9)))
        #expect(preferences.heightValue == 70.5 && preferences.heightUnit == .inches)
        let weight = try #require(try NutritionGoalStore.latestWeight(in: context))
        #expect(weight.value == 180.4 && weight.unit == .lb, "as entered")
        #expect(try goals(context).count == 1, "complete now: the goal follows")

        preferences.setHeight(value: 180, unit: .cm)
        try context.save()
        #expect(try !NutritionGoalStore.prefillMissing(from: training, in: context, now: date(10)), "never over a value")
        #expect(preferences.heightValue == 180 && preferences.heightUnit == .cm)
        #expect(try context.fetchCount(FetchDescriptor<BodyWeightEntry>()) == 1)
    }

    @Test func theChoicesComeBackFromTheStoredGoal() throws {
        let goal = NutritionGoal(effectiveFrom: date(9), calories: 2000, proteinGrams: 150, carbsGrams: 200,
                                 fatGrams: 60)
        goal.activity = .light
        goal.goal = .gain
        goal.caloriesOverridden = true
        let choices = NutritionGoalStore.choices(of: goal)
        #expect(choices.activity == .light && choices.goal == .gain)
        #expect(choices.overrides == .init(calories: 2000))
        #expect(NutritionGoalStore.choices(of: nil) == .init())
    }
}

/// codex-review-n3 #3: the height editor never rewrites an entered height (D52).
struct HeightFieldsTests {
    /// 180 cm stored, the app switched to U.S. units: the editor still shows cm, and an unchanged Save writes nothing.
    @Test func aStoredHeightKeepsItsUnitAndAnUnchangedSaveWritesNothing() throws {
        let unit = HeightFields.unit(stored: .cm, usCustomary: true)
        #expect(unit == .cm)
        let (cm, feet, inches) = HeightFields.fields(value: 180, unit: unit)
        #expect(cm == "180" && feet.isEmpty && inches.isEmpty)
        let parsed = try #require(HeightFields.parse(cm: cm, feet: feet, inches: inches, unit: unit))
        #expect(HeightFields.toSave(fields: [cm, feet, inches], shown: [cm, feet, inches], parsed: parsed) == nil)
    }

    /// 71.5 in reopens as 5 ft 11.5 in and parses back to exactly 71.5 in.
    @Test func fractionalInchesSurviveAReopen() throws {
        let (cm, feet, inches) = HeightFields.fields(value: 71.5, unit: .inches)
        #expect(feet == "5" && inches == "11.5")
        let parsed = try #require(HeightFields.parse(cm: cm, feet: feet, inches: inches, unit: .inches))
        #expect(parsed.0 == 71.5 && parsed.1 == .inches)
    }

    @Test func aNewHeightTakesTheAppsUnitsAndAnEditIsSaved() throws {
        #expect(HeightFields.unit(stored: nil, usCustomary: true) == .inches)
        #expect(HeightFields.unit(stored: nil, usCustomary: false) == .cm)
        let parsed = try #require(HeightFields.parse(cm: "", feet: "6", inches: "0", unit: .inches))
        #expect(parsed.0 == 72)
        #expect(HeightFields.toSave(fields: ["", "6", "0"], shown: ["", "5", "11.5"], parsed: parsed)?.0 == 72)
        #expect(HeightFields.parse(cm: "", feet: "5", inches: "12", unit: .inches) == nil, "inches under 12")
    }
}
