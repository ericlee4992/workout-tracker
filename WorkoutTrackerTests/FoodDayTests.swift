import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N5: Today's food math — totals, left / over, the ring's fill and macro split against the goal in force
/// that day (a goal changed mid-week), and calories burned shown but never added (D71).
@MainActor
struct FoodDayTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func entry(_ day: Int, _ hour: Int, calories: Double, protein: Double = 0, carbs: Double = 0,
                       fat: Double = 0, servings: Double = 1) -> FoodEntry {
        FoodEntry(loggedAt: date(day, hour), meal: .lunch, name: "Food", servings: servings, calories: calories,
                  proteinGrams: protein, carbsGrams: carbs, fatGrams: fat, createdAt: date(day, hour))
    }

    private func goal(from day: Int, calories: Double, protein: Double = 150) -> NutritionGoal {
        NutritionGoal(effectiveFrom: calendar.startOfDay(for: date(day, 12)), calories: calories,
                      proteinGrams: protein, carbsGrams: 250, fatGrams: 70, createdAt: date(day, 0))
    }

    @Test func totalsLeftAndFillFollowTheEntriesAndTheGoal() {
        let entries = [entry(10, 8, calories: 400, protein: 30, carbs: 40, fat: 10, servings: 1.5),
                       entry(10, 13, calories: 300, protein: 20), entry(9, 20, calories: 999)]
        let day = FoodDayMath.day(date(10, 18), entries: entries, goals: [goal(from: 1, calories: 2_000)], workouts: [],
                                  calendar: calendar)
        #expect(day.entryCount == 2 && day.isLogged)
        #expect(day.eaten.calories == 900 && day.eaten.proteinGrams == 65, "servings × per serving; yesterday not counted")
        #expect(day.left == 1_100 && day.over == 0 && !day.isOver)
        #expect(day.fill == 0.45)
        #expect(day.toGo(.protein) == 85)
        let shares = day.macroShares
        #expect(abs(shares.protein + shares.carbs + shares.fat - 1) < 1e-9)
        #expect(abs(shares.protein - 260.0 / (260 + 240 + 135)) < 1e-9, "4/4/9 calories")
    }

    @Test func overTheGoalReadsOverAndTheRingStopsFull() {
        let day = FoodDayMath.day(date(10, 20), entries: [entry(10, 19, calories: 2_120)],
                                  goals: [goal(from: 1, calories: 2_000)], workouts: [], calendar: calendar)
        #expect(day.isOver && day.over == 120 && day.left == 0 && day.fill == 1)
        #expect(day.toGo(.protein) == 150)
    }

    @Test func aGoalChangedMidWeekJudgesEachDayByItsOwn() {
        let goals = [goal(from: 1, calories: 2_000), goal(from: 11, calories: 2_500)]
        let entries = [entry(10, 12, calories: 1_000), entry(11, 12, calories: 1_000)]
        let days = [date(9, 12), date(10, 12), date(11, 12)]
        let week = FoodDayMath.week(days, entries: entries, goals: goals, workouts: [], calendar: calendar)
        let tuesday = week[calendar.startOfDay(for: date(10, 12))]
        let wednesday = week[calendar.startOfDay(for: date(11, 12))]
        #expect(tuesday?.goal?.calories == 2_000 && tuesday?.fill == 0.5)
        #expect(wednesday?.goal?.calories == 2_500 && wednesday?.fill == 0.4, "the new goal from its own day")
        #expect(week[calendar.startOfDay(for: date(9, 12))]?.isLogged == false)
        #expect(FoodDayMath.daysLogged(week) == 2)
    }

    @Test func burnedIsShownAndNeverAdded() throws {
        let lifting = Workout(startedAt: date(10, 7), finishedAt: date(10, 8))
        lifting.activeEnergyKilocalories = 320
        let noSensor = Workout(startedAt: date(10, 17), finishedAt: date(10, 18))
        let yesterday = Workout(startedAt: date(9, 7), finishedAt: date(9, 8))
        yesterday.activeEnergyKilocalories = 999
        let day = FoodDayMath.day(date(10, 20), entries: [entry(10, 12, calories: 1_500)],
                                  goals: [goal(from: 1, calories: 2_000)], workouts: [lifting, noSensor, yesterday],
                                  calendar: calendar)
        #expect(day.burned == 320)
        #expect(day.left == 500 && day.fill == 0.75, "burned changes neither what is left nor the ring (D71)")
        #expect(FoodDayMath.burned(by: noSensor) == nil, "no sensor is not zero")
    }

    @Test func withoutAGoalALoggedDayIsFullAndNothingIsLeft() {
        let day = FoodDayMath.day(date(10, 20), entries: [entry(10, 12, calories: 800)], goals: [], workouts: [],
                                  calendar: calendar)
        #expect(day.goal == nil && day.left == nil && day.over == nil && !day.isOver)
        #expect(day.fill == 1)
        let empty = FoodDayMath.day(date(10, 20), entries: [], goals: [], workouts: [], calendar: calendar)
        #expect(!empty.isLogged && empty.fill == 0)
        #expect(empty.macroShares.protein == 0, "a calories-only day has no macro split")
    }

    @Test func editingAndDeletingAnEntryWithUndo() throws {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        let context = ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
        let food = SavedFood(name: "Oats", calories: 150, proteinGrams: 5)
        context.insert(food)
        let entry = FoodEntry(logging: food, meal: .breakfast, at: date(10, 8))
        entry.healthSampleID = UUID()
        context.insert(entry)
        try context.save()

        try FoodLog.update(entry, servings: 2, meal: .lunch, calories: 160, proteinGrams: 6, carbsGrams: 27,
                           fatGrams: 3, at: date(10, 9), in: context)
        #expect(entry.servings == 2 && entry.meal == .lunch && entry.calories == 160 && entry.carbsGrams == 27)
        #expect(entry.updatedAt == date(10, 9) && entry.savedFood === food)
        #expect(food.calories == 150, "the food stays as it was")

        let id = entry.id, sample = entry.healthSampleID
        let copy = try FoodLog.delete(entry, in: context)
        #expect(try context.fetch(FetchDescriptor<FoodEntry>()).isEmpty)
        let back = try FoodLog.restore(copy, in: context)
        let entries = try context.fetch(FetchDescriptor<FoodEntry>())
        #expect(entries.count == 1)
        #expect(back.id == id && back.servings == 2 && back.meal == .lunch && back.calories == 160)
        #expect(back.loggedAt == date(10, 8) && back.healthSampleID == sample && back.savedFood === food)
    }
}
