import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// N16 (D92): picking a day on Today — which day and week show, the way back, earlier weeks, when the pick resets —
/// and logging to a picked day: that day at the meal's time, with `createdAt` and "last used" left at now.
@MainActor
struct TodayDayPickTests {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 1
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    /// 2026-11-20 is a Friday; its week runs Sunday 15 – Saturday 21.
    private func day(_ day: Int, month: Int = 11, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private var now: Date { day(20, hour: 14) }

    // MARK: Picking

    @Test func aPastRingShowsThatDayAndTodaysRingGoesBack() {
        var pick = TodayDayPick()
        #expect(!pick.showsPastDay(now: now, calendar: calendar) && pick.shownDay(now: now, calendar: calendar) == now)
        pick.pick(day(17, hour: 9), now: now, calendar: calendar)
        #expect(pick.shownDay(now: now, calendar: calendar) == day(17))
        #expect(pick.logDay(now: now, calendar: calendar) == day(17))
        #expect(pick.shownWeek(now: now, calendar: calendar) == nil, "Tuesday is in this week")
        pick.pick(day(20, hour: 8), now: now, calendar: calendar)
        #expect(pick == TodayDayPick(), "today's ring goes back")
        #expect(pick.logDay(now: now, calendar: calendar) == nil)
    }

    @Test func aDayAheadIsNotPicked() {
        var pick = TodayDayPick()
        pick.pick(day(17), now: now, calendar: calendar)
        pick.pick(day(21), now: now, calendar: calendar)
        #expect(pick.shownDay(now: now, calendar: calendar) == day(17))
    }

    @Test func todayFollowsTheClockAndAPickedDayStays() {
        var pick = TodayDayPick()
        let nextMorning = day(21, hour: 0, minute: 5)
        #expect(pick.shownDay(now: nextMorning, calendar: calendar) == nextMorning, "today follows midnight")
        pick.pick(day(18), now: now, calendar: calendar)
        #expect(pick.shownDay(now: nextMorning, calendar: calendar) == day(18), "a picked day stays")
    }

    @Test func aDayPickedThisWeekStaysInViewIntoTheNextWeek() {
        var pick = TodayDayPick()
        pick.pick(day(19), now: now, calendar: calendar)
        let sunday = day(22, hour: 0, minute: 10)
        #expect(pick.shownDay(now: sunday, calendar: calendar) == day(19))
        #expect(TodayDayPick.weekTitle(week: pick.shownWeek(now: sunday, calendar: calendar), now: sunday,
                                       calendar: calendar) == "Last week")
    }

    @Test func aPickedDayThatIsNoLongerPastShowsToday() {
        // The clock or the time zone moved back so the picked day is today: today shows, and logs at now.
        var pick = TodayDayPick()
        pick.pick(day(19), now: now, calendar: calendar)
        let earlier = day(19, hour: 20)
        #expect(!pick.showsPastDay(now: earlier, calendar: calendar))
        #expect(pick.shownDay(now: earlier, calendar: calendar) == earlier)
        #expect(pick.logDay(now: earlier, calendar: calendar) == nil)
    }

    // MARK: Earlier weeks

    @Test func theWeekMovesAndPicksTheSameWeekday() {
        var pick = TodayDayPick()
        pick.moveWeek(by: -1, now: now, calendar: calendar)
        #expect(pick.shownDay(now: now, calendar: calendar) == day(13), "Friday last week")
        #expect(pick.shownWeek(now: now, calendar: calendar) != nil)
        #expect(TodayDayPick.weekTitle(week: pick.shownWeek(now: now, calendar: calendar), now: now,
                                       calendar: calendar) == "Last week")
        pick.moveWeek(by: -1, now: now, calendar: calendar)
        #expect(pick.shownDay(now: now, calendar: calendar) == day(6))
        pick.moveWeek(by: 1, now: now, calendar: calendar)
        pick.moveWeek(by: 1, now: now, calendar: calendar)
        #expect(pick == TodayDayPick(), "back in this week on today's weekday: today")
        pick.moveWeek(by: 1, now: now, calendar: calendar)
        #expect(pick == TodayDayPick(), "never past this week")
    }

    @Test func backToThisWeekFromAnEarlierWeekdayPicksThatDay() {
        var pick = TodayDayPick()
        pick.pick(day(16), now: now, calendar: calendar)
        pick.moveWeek(by: -1, now: now, calendar: calendar)
        #expect(pick.shownDay(now: now, calendar: calendar) == day(9))
        pick.moveWeek(by: 1, now: now, calendar: calendar)
        #expect(pick.shownDay(now: now, calendar: calendar) == day(16))
        #expect(pick.shownWeek(now: now, calendar: calendar) == nil)
    }

    @Test func aDayTappedInAnEarlierWeekKeepsThatWeek() {
        var pick = TodayDayPick()
        pick.moveWeek(by: -2, now: now, calendar: calendar)
        pick.pick(day(3), now: now, calendar: calendar)
        #expect(pick.shownDay(now: now, calendar: calendar) == day(3))
        #expect(TodayDayPick.weekTitle(week: pick.shownWeek(now: now, calendar: calendar), now: now,
                                       calendar: calendar) == "Nov 1 – 7")
    }

    @Test func weekTitles() {
        #expect(TodayDayPick.weekTitle(week: nil, now: now, calendar: calendar) == "This week")
        #expect(TodayDayPick.weekTitle(week: day(12), now: now, calendar: calendar) == "Last week")
        #expect(TodayDayPick.weekTitle(week: day(4), now: now, calendar: calendar) == "Nov 1 – 7")
        #expect(TodayDayPick.weekTitle(week: day(28, month: 10), now: now, calendar: calendar) == "Oct 25 – 31")
        #expect(TodayDayPick.weekTitle(week: day(27, month: 9), now: now, calendar: calendar) == "Sep 27 – Oct 3")
    }

    @Test func anEarlierWeeksSummaryHasNoTodayOrDaysAhead() {
        let tuesday = WeekSummaryInput(id: UUID(), title: "Pull Day", startedAt: day(10, hour: 7), durationSeconds: 3_600,
                                       hasLifting: true, hasCardio: false, familySets: [.back: 6])
        let thisWeek = WeekSummaryInput(id: UUID(), title: "Push Day", startedAt: day(17, hour: 7),
                                        durationSeconds: 3_600, hasLifting: true, hasCardio: false, familySets: [.chest: 4])
        let summary = WeekSummaryMath.summary(of: [tuesday, thisWeek], now: now, weekOf: day(12), calendar: calendar)
        #expect(summary.days.first?.date == day(8) && summary.days.count == 7)
        #expect(summary.days.allSatisfy { !$0.isToday && !$0.isFuture })
        #expect(summary.workoutCount == 1 && summary.days[2].workouts.first?.title == "Pull Day")
        let current = WeekSummaryMath.summary(of: [tuesday, thisWeek], now: now, calendar: calendar)
        #expect(current.workoutCount == 1 && current.lastWeekWorkoutCount == 1)
        #expect(current.days[5].isToday && current.days[6].isFuture)
    }

    // MARK: The reset rule

    @Test func thePickResetsAfterAnHourAwayOrOnAnotherDay() {
        let left = day(20, hour: 14)
        #expect(!TodayDayPick.resetsOnReturn(backgroundedAt: left, now: day(20, hour: 14, minute: 59), calendar: calendar))
        #expect(TodayDayPick.resetsOnReturn(backgroundedAt: left, now: day(20, hour: 15), calendar: calendar))
        #expect(TodayDayPick.resetsOnReturn(backgroundedAt: day(20, hour: 23, minute: 55),
                                            now: day(21, hour: 0, minute: 5), calendar: calendar), "a new day")
    }

    // MARK: Logging to a picked day

    @Test func aPickedDayLogsAtTheMealsUsualTime() {
        #expect(FoodLogDay.loggedAt(meal: .dinner, on: nil, now: now, calendar: calendar) == nil)
        #expect(FoodLogDay.loggedAt(meal: .dinner, on: day(20, hour: 3), now: now, calendar: calendar) == nil,
                "today: now")
        #expect(FoodLogDay.loggedAt(meal: .breakfast, on: day(17, hour: 22), now: now, calendar: calendar)
                == day(17, hour: 8))
        #expect(FoodLogDay.loggedAt(meal: .lunch, on: day(17), now: now, calendar: calendar) == day(17, hour: 12, minute: 30))
        #expect(FoodLogDay.loggedAt(meal: .snacks, on: day(17), now: now, calendar: calendar) == day(17, hour: 15, minute: 30))
        #expect(FoodLogDay.loggedAt(meal: .dinner, on: day(17), now: now, calendar: calendar) == day(17, hour: 18, minute: 30))
    }

    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private func food(_ context: ModelContext) -> SavedFood {
        let food = SavedFood(name: "Banana", servingValue: 1, servingUnit: "medium", calories: 105, proteinGrams: 1.3,
                             carbsGrams: 27, fatGrams: 0.4)
        context.insert(food)
        return food
    }

    @Test func loggingToAPickedDayMovesOnlyTheEntrysDay() throws {
        let context = try context()
        let banana = food(context)
        let tuesday = day(17, hour: 8)
        try FoodLog.log(banana, meal: .breakfast, at: now, loggedAt: tuesday, in: context)
        let entry = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        #expect(entry.loggedAt == tuesday)
        #expect(entry.createdAt == now, "created now")
        #expect(banana.lastUsedAt == now, "Recently logged keeps it at the top")
        #expect(NutritionMath.entries([entry], on: day(17, hour: 12), calendar: calendar).count == 1)
    }

    @Test func aMealAManualAddAndALabelLogToThePickedDay() throws {
        let context = try context()
        let tuesday = day(17, hour: 18, minute: 30)
        let meal = SavedMeal(name: "Lunch box", createdAt: now)
        context.insert(meal)
        meal.items = [SavedMealItem(order: 0, name: "Rice", servings: 1, servingValue: 1, servingUnit: "bowl",
                                    calories: 300, proteinGrams: 6, carbsGrams: 66, fatGrams: 1)]
        try FoodLog.log(meal, meal: .dinner, at: now, loggedAt: tuesday, in: context)
        #expect(meal.lastUsedAt == now)
        try FoodLog.logManual(name: "Cookie", serving: nil, nutrition: FoodNutrition(calories: 200), meal: .dinner,
                              at: now, loggedAt: tuesday, in: context)
        let draft = FoodDraft(name: "Granola", serving: ServingText(value: 1, unit: "cup"),
                              nutrition: FoodNutrition(calories: 400))
        try FoodScan.logLabel(draft, servings: 1, meal: .dinner, saveToMyFoods: true, at: now, loggedAt: tuesday,
                              in: context)
        try FoodScan.logLabel(draft, servings: 1, meal: .dinner, saveToMyFoods: false, at: now, loggedAt: tuesday,
                              in: context)
        let entries = try context.fetch(FetchDescriptor<FoodEntry>())
        #expect(entries.count == 4)
        #expect(entries.allSatisfy { $0.loggedAt == tuesday && $0.createdAt == now })
        let granola = try #require(try context.fetch(FetchDescriptor<SavedFood>()).first { $0.name == "Granola" })
        #expect(granola.lastUsedAt == now && granola.createdAt == now)
    }

    @Test func withoutAPickedDayLoggingIsUnchanged() throws {
        let context = try context()
        let banana = food(context)
        try FoodLog.log(banana, meal: .snacks, at: now, in: context)
        let entry = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        #expect(entry.loggedAt == now && entry.createdAt == now)
    }
}
