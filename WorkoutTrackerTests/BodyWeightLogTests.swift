import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N9a: body weight logging keeps the entered unit (D52), edits keep `normalizedKg` in step, and the goal
/// offers Recalculate only past about 2 kg.
@MainActor
struct BodyWeightLogTests {
    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private let now = Date(timeIntervalSince1970: 1_794_300_000)

    @Test func aWeightKeepsItsEnteredUnitAndEditsStayInStep() throws {
        let context = try context()
        let entry = try BodyWeightLog.log(value: 176.4, unit: .lb, at: now, in: context)
        #expect(entry.value == 176.4 && entry.unit == .lb && entry.source == .app)
        #expect(abs(entry.normalizedKg - 80.0128) < 0.001)
        try BodyWeightLog.update(entry, value: 80, unit: .kg, at: now.addingTimeInterval(-3_600), in: context)
        #expect(entry.value == 80 && entry.unit == .kg && entry.normalizedKg == 80)
        #expect(entry.measuredAt == now.addingTimeInterval(-3_600))
        try BodyWeightLog.delete(entry, in: context)
        #expect(try context.fetch(FetchDescriptor<BodyWeightEntry>()).isEmpty)
    }

    @Test func recalculateIsOfferedOnlyPastAboutTwoKilograms() {
        let goal = NutritionGoal(effectiveFrom: now, calories: 2_500, proteinGrams: 150, carbsGrams: 250, fatGrams: 70)
        goal.weightKg = 80
        let close = BodyWeightEntry(measuredAt: now, value: 81.9, unit: .kg)
        let far = BodyWeightEntry(measuredAt: now, value: 77.5, unit: .kg)
        let farInPounds = BodyWeightEntry(measuredAt: now, value: 182, unit: .lb)  // 82.6 kg
        #expect(!BodyWeightLog.goalNeedsRecalculating(goal: goal, latest: close))
        #expect(BodyWeightLog.goalNeedsRecalculating(goal: goal, latest: far))
        #expect(BodyWeightLog.goalNeedsRecalculating(goal: goal, latest: farInPounds), "compared in kg")
        #expect(!BodyWeightLog.goalNeedsRecalculating(goal: nil, latest: far))
        let typed = NutritionGoal(effectiveFrom: now, calories: 2_000, proteinGrams: 1, carbsGrams: 1, fatGrams: 1)
        #expect(!BodyWeightLog.goalNeedsRecalculating(goal: typed, latest: far), "a goal without a weight")
    }

    @Test func anUnchangedFigureKeepsItsStoredPrecision() {
        // codex-review-n9a: the sheet shows 176.46 for 176.456; saving without touching it keeps 176.456.
        let stored = EditableNumber(176.456)
        #expect(stored.text == "176.46")
        #expect(stored.resolve(stored.text) == .some(176.456))
        #expect(stored.resolve("176.4") == .some(176.4), "a typed change is the typed number")
    }

    @Test func recalculateClearsTypedNumbersAndUsesTheLatestWeight() throws {
        let context = try context()
        let preferences = try AppPreferences.canonical(in: context)
        preferences.setHeight(value: 180, unit: .cm)
        preferences.birthDate = Calendar.current.date(byAdding: .year, value: -30, to: now)
        preferences.sex = .male
        try BodyWeightLog.log(value: 80, unit: .kg, at: now.addingTimeInterval(-86_400 * 10), in: context)
        let typed = try #require(try NutritionGoalStore.update(in: context, now: now.addingTimeInterval(-86_400 * 10)) {
            $0.overrides.calories = 1_800
        })
        #expect(typed.caloriesOverridden && typed.calories == 1_800 && typed.weightKg == 80)

        let latest = try BodyWeightLog.log(value: 75, unit: .kg, at: now, in: context)
        #expect(BodyWeightLog.goalNeedsRecalculating(goal: typed, latest: latest))
        let goal = try #require(try BodyWeightLog.recalculateGoal(in: context, now: now))
        #expect(goal.weightKg == 75 && !goal.caloriesOverridden && goal.calories != 1_800)
        #expect(!BodyWeightLog.goalNeedsRecalculating(goal: goal, latest: latest))

        preferences.birthDate = nil
        #expect(throws: NutritionGoalStore.Failure.detailsIncomplete) { try BodyWeightLog.recalculateGoal(in: context, now: now) }
    }

    @Test func theSheetStepsAndRanges() {
        #expect(BodyWeightLog.step(for: .kg) == 0.1 && BodyWeightLog.step(for: .lb) == 0.2)
        #expect(BodyWeightLog.range(for: .kg).contains(20) && !BodyWeightLog.range(for: .kg).contains(361))
        #expect(BodyWeightLog.range(for: .lb).contains(800) && !BodyWeightLog.range(for: .lb).contains(49))
    }
}
