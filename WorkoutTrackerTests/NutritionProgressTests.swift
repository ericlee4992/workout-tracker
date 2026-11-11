import Foundation
import Testing

@testable import WorkoutTracker

/// Nutrition N10: the body and food charts' series (trend smoothing, dated goals, missing days), History's food line and
/// journal, and pins — the new charts decode, and old pins still decode beside them.
@MainActor
struct NutritionProgressTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 15))! }

    private func day(_ offset: Int, hour: Int = 8) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!.addingTimeInterval(Double(hour) * 3_600)
    }

    // MARK: Weight

    @Test func dailyWeightsAverageEachDaysWeighInsInKilograms() {
        let entries = [BodyWeightEntry(measuredAt: day(-1, hour: 7), value: 80, unit: .kg),
                       BodyWeightEntry(measuredAt: day(-1, hour: 20), value: 81, unit: .kg),
                       BodyWeightEntry(measuredAt: day(0), value: 176.4, unit: .lb)]
        let daily = NutritionProgressMath.dailyWeights(entries, calendar: calendar)
        #expect(daily.count == 2)
        #expect(daily[0].date == calendar.startOfDay(for: day(-1)) && daily[0].kg == 80.5)
        #expect(abs(daily[1].kg - 80.0128) < 0.001, "lb entries count by their kg")
    }

    @Test func theTrendAveragesTheWeekEndingEachDayAndSkipsMissingDays() {
        let daily = [WeightPoint(date: day(-10), kg: 90), WeightPoint(date: day(-6), kg: 82),
                     WeightPoint(date: day(-3), kg: 80), WeightPoint(date: day(0), kg: 78)].map {
            WeightPoint(date: calendar.startOfDay(for: $0.date), kg: $0.kg)
        }
        let trend = NutritionProgressMath.trend(daily, calendar: calendar)
        let expected: [Double] = [90, 86, 81, 80]
        #expect(trend.map(\.kg) == expected, "a window of 7 days ending each day; empty days are not zeros")
    }

    @Test func weeklyRateAndChange() {
        // 82 kg four weeks ago, down 0.5 kg a week to 80.
        let points: [WeightPoint] = stride(from: -28, through: 0, by: 7).map { (offset: Int) -> WeightPoint in
            let kg: Double = 80 - Double(offset) / 14
            return WeightPoint(date: calendar.startOfDay(for: day(offset)), kg: kg)
        }
        #expect(abs((NutritionProgressMath.weeklyRate(points, calendar: calendar) ?? 0) - -0.5) < 0.001)
        let change = NutritionProgressMath.change(points)
        #expect(change?.weeks == 4 && abs((change?.kg ?? 0) - -2) < 0.001)
        #expect(NutritionProgressMath.weeklyRate(Array(points.suffix(1)), calendar: calendar) == nil)
        #expect(NutritionProgressMath.change(Array(points.suffix(1))) == nil)
    }

    @Test func aWeightReadingIsInTheAppsUnitWithItsChange() {
        let entries = [BodyWeightEntry(measuredAt: day(-84), value: 184, unit: .lb),
                       BodyWeightEntry(measuredAt: day(0), value: 176.4, unit: .lb)]
        let reading = ProgressReading.nutrition(.bodyWeight, range: .days90, weights: entries, entries: [], goals: [],
                                                unit: .lb, now: today, calendar: calendar)
        #expect(reading.value == "176.4" && reading.unit == "lb")
        #expect(reading.caption == "−7.6 lb in 12 weeks")
        #expect(reading.points.count == 2 && reading.style == .line)
        let kg = ProgressReading.nutrition(.bodyWeight, range: .days90, weights: entries, entries: [], goals: [],
                                           unit: .kg, now: today, calendar: calendar)
        #expect(kg.unit == "kg" && kg.value == "80.0")
        let older = ProgressReading.nutrition(.bodyWeight, range: .days90,
                                              weights: [BodyWeightEntry(measuredAt: day(-120), value: 80, unit: .kg)],
                                              entries: [], goals: [], unit: .kg, now: today, calendar: calendar)
        #expect(older.state == .empty, "outside the panel's 90 days")
        #expect(ProgressReading.signed(0.04) == "0.0" && ProgressReading.signed(-1.25).hasPrefix("−"))
    }

    // MARK: Food

    private func entry(_ offset: Int, calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0,
                       servings: Double = 1) -> FoodEntry {
        FoodEntry(loggedAt: day(offset), meal: .lunch, name: "Food", servings: servings, calories: calories,
                  proteinGrams: protein, carbsGrams: carbs, fatGrams: fat, createdAt: day(offset))
    }

    @Test func foodDaysCoverTheSpanWithEachDaysOwnGoal() {
        let old = NutritionGoal(effectiveFrom: day(-10), calories: 2_000, proteinGrams: 120, carbsGrams: 200, fatGrams: 60)
        let new = NutritionGoal(effectiveFrom: day(-2), calories: 2_400, proteinGrams: 150, carbsGrams: 250, fatGrams: 70)
        let entries = [entry(-6, calories: 1_800, protein: 100), entry(-1, calories: 500, servings: 2),
                       entry(-1, calories: 1_000), entry(-30, calories: 9_999)]
        let days = NutritionProgressMath.foodDays(entries, goals: [old, new], from: day(-6), through: today,
                                                  calendar: calendar)
        #expect(days.count == 7 && days.first?.date == calendar.startOfDay(for: day(-6)))
        #expect(days.filter(\.isLogged).count == 2, "missing days stay in the list, not logged")
        #expect(days[0].goal?.calories == 2_000 && days[5].goal?.calories == 2_400, "each day's goal (D70)")
        #expect(days[5].eaten.calories == 2_000, "servings count")
        #expect(NutritionProgressMath.average(days) { $0.eaten.calories } == 1_900, "averaged over logged days only")
        #expect(NutritionProgressMath.average([days[1]]) { $0.eaten.calories } == nil)
    }

    @Test func aCaloriesReadingDrawsLoggedDaysAgainstTheLatestGoal() {
        let goal = NutritionGoal(effectiveFrom: day(-30), calories: 2_400, proteinGrams: 150, carbsGrams: 250, fatGrams: 70)
        let entries = [entry(-6, calories: 1_800, protein: 100), entry(0, calories: 2_200, protein: 140)]
        let calories = ProgressReading.nutrition(.calories, range: .week, weights: [], entries: entries, goals: [goal],
                                                 unit: .kg, now: today, calendar: calendar)
        #expect(calories.value == "2,000" && calories.unit == "cal")
        #expect(calories.caption == "Daily average · 2 of 7 days logged")
        #expect(calories.style == .bars && calories.goal == 2_400 && calories.points.count == 2)
        #expect(calories.xDomain == calendar.startOfDay(for: day(-6))...calendar.startOfDay(for: today))
        let protein = ProgressReading.nutrition(.protein, range: .week, weights: [], entries: entries, goals: [goal],
                                                unit: .kg, now: today, calendar: calendar)
        #expect(protein.value == "120" && protein.caption == "Daily average · goal 150 g" && protein.goal == 150)
        let none = ProgressReading.nutrition(.calories, range: .week, weights: [], entries: [], goals: [goal],
                                             unit: .kg, now: today, calendar: calendar)
        #expect(none.state == .empty)
    }

    @Test func macrosAreCalorieSharesInWholePercentsThatAddUpTo100() {
        let entries = [entry(0, calories: 500, protein: 25, carbs: 50, fat: 20)]  // 100 · 200 · 180 cal
        let days = NutritionProgressMath.foodDays(entries, goals: [], from: day(-6), through: today, calendar: calendar)
        let shares = NutritionProgressMath.macroShares(days)!
        #expect(abs(shares.protein - 100.0 / 480) < 0.0001)
        let percents = NutritionProgressMath.percents(shares)
        #expect(percents == [21, 42, 37] && percents.reduce(0, +) == 100)
        #expect(NutritionProgressMath.percents((1.0 / 3, 1.0 / 3, 1.0 / 3)).reduce(0, +) == 100)
        let reading = ProgressReading.nutrition(.macros, range: .week, weights: [], entries: entries, goals: [],
                                                unit: .kg, now: today, calendar: calendar)
        #expect(reading.value == "21 / 42 / 37" && reading.unit == "%" && reading.style == .macros)
        #expect(reading.points.first?.parts == [100, 200, 180])
        let caloriesOnly = NutritionProgressMath.foodDays([entry(0, calories: 300)], goals: [], from: day(0),
                                                          through: today, calendar: calendar)
        #expect(NutritionProgressMath.macroShares(caloriesOnly) == nil)
    }

    @Test func rangesStartWhereTheyShould() {
        let start = calendar.startOfDay(for: today)
        #expect(NutritionRange.week.start(endingAt: today, calendar: calendar) == calendar.date(byAdding: .day, value: -6, to: start))
        #expect(NutritionRange.days90.start(endingAt: today, calendar: calendar) == calendar.date(byAdding: .day, value: -89, to: start))
        #expect(NutritionRange.all.start(endingAt: today, calendar: calendar) == nil)
        #expect(NutritionRange.choices(for: .weightTrend) == [.days90, .months6, .year, .all])
        #expect(NutritionRange.choices(for: .protein) == [.week, .month, .days90])
    }

    // MARK: History

    @Test func historysFoodLineSaysUnderOverOrAtGoal() {
        let goal = DayGoal(calories: 2_288, proteinGrams: 1, carbsGrams: 1, fatGrams: 1)
        func line(_ eaten: Double, goal: DayGoal?) -> HistoryFoodLine {
            HistoryFoodLine(FoodDay(eaten: Macros(calories: eaten, proteinGrams: 0, carbsGrams: 0, fatGrams: 0),
                                    entryCount: 1, goal: goal, burned: 0))
        }
        #expect(line(1_240, goal: goal) == HistoryFoodLine.make("1,240 cal eaten", "1,048 under goal"))
        #expect(line(2_600, goal: goal).detail == "312 over goal")
        #expect(line(2_288.2, goal: goal).detail == "At goal")
        #expect(line(900, goal: nil).detail == nil)
    }

    @Test func loggedDaysKeyEachDayWithItsGoal() {
        let goal = NutritionGoal(effectiveFrom: day(-1), calories: 2_000, proteinGrams: 1, carbsGrams: 1, fatGrams: 1)
        let days = FoodDayMath.loggedDays([entry(-3, calories: 100), entry(0, calories: 300), entry(0, calories: 200)],
                                          goals: [goal], calendar: calendar)
        #expect(days.count == 2)
        #expect(days[calendar.startOfDay(for: today)]?.eaten.calories == 500)
        #expect(days[calendar.startOfDay(for: today)]?.goal?.calories == 2_000)
        #expect(days[calendar.startOfDay(for: day(-3))]?.goal == nil, "before the first goal")
    }

    @Test func theJournalHasDaysWithFoodAndNoWorkout() {
        let workout = HistoryWorkoutFacts(id: UUID(), startedAt: day(-2, hour: 18), durationSeconds: 3_600, sets: 10, hasLifting: true, hasCardio: false)
        let later = HistoryWorkoutFacts(id: UUID(), startedAt: day(-2, hour: 19), durationSeconds: 3_600, sets: 10, hasLifting: true, hasCardio: false)
        let months = HistoryOverviewMath.journal([workout, later], foodDays: [day(-1), day(-2), day(-40)], now: today,
                                                 calendar: calendar)
        let days = months.flatMap(\.days)
        #expect(days.map(\.day) == [day(-1), day(-2), day(-40)].map { calendar.startOfDay(for: $0) })
        #expect(days[0].workoutIDs.isEmpty && days[0].title == "Yesterday")
        #expect(days[1].workoutIDs == [later.id, workout.id], "newest first, as before")
        #expect(months.count == 2)
        #expect(HistoryOverviewMath.journal([workout, later], now: today, calendar: calendar).flatMap(\.days).count == 1,
                "without food, unchanged")
    }

    // MARK: Pins

    @Test func nutritionPinsRoundTripAndOldPinsStillDecode() throws {
        let pins = NutritionChart.allCases.map { ProgressPin(subject: .nutrition($0), metric: .time) }
            + [ProgressPin(subject: .training(.workoutsPerWeek), metric: .time),
               ProgressPin(subject: .cardio(activity: CardioActivity.outdoorRun.rawValue), metric: .distance)]
        #expect(ProgressPinStore.decode(ProgressPinStore.encode(pins)) == pins)
        let json = String(decoding: ProgressPinStore.encode([pins[2]]), as: UTF8.self)
        #expect(json.contains("\"cardio\"") && json.contains("nutrition.calories"),
                "stored as an activity, so an older build skips it")
        // A chart a later build adds reads as an unknown activity: kept, not shown — and the other pins still load.
        let future = #"[{"id":"\#(UUID().uuidString)","subject":{"cardio":{"activity":"nutrition.water"}},"metric":"time"},"#
            + #"{"id":"\#(UUID().uuidString)","subject":{"cardio":{"activity":"training.workoutsPerWeek"}},"metric":"time"}]"#
        let decoded = ProgressPinStore.decode(Data(future.utf8))
        #expect(decoded.count == 2 && decoded[0].activity == nil && decoded[0].nutrition == nil)
        #expect(decoded[1].training == .workoutsPerWeek)
    }

    // MARK: codex-review-n10

    /// S3: Body weight's points are the weigh-ins as measured (two in a day are two points); the trend averages by day.
    @Test func bodyWeightKeepsEachWeighIn() {
        let entries = [BodyWeightEntry(measuredAt: day(0, hour: 7), value: 80, unit: .kg),
                       BodyWeightEntry(measuredAt: day(0, hour: 20), value: 82, unit: .kg)]
        #expect(NutritionProgressMath.weighIns(entries).map(\.kg) == [80, 82])
        let reading = ProgressReading.nutrition(.bodyWeight, range: .days90, weights: entries, entries: [], goals: [],
                                                unit: .kg, now: today, calendar: calendar)
        #expect(reading.value == "82.0" && reading.points.count == 2, "the latest measurement, not the day's 81")
        let trend = ProgressReading.nutrition(.weightTrend, range: .days90, weights: entries, entries: [], goals: [],
                                              unit: .kg, now: today, calendar: calendar)
        #expect(trend.value == "81.0" && trend.points.count == 1)
    }

    /// S2: a week across a daylight-saving change is still seven days (spring: 167 hours; fall: 169).
    @Test func theWeeklyRateCountsCalendarDaysAcrossDaylightSaving() throws {
        func point(_ month: Int, _ dayOfMonth: Int, _ kg: Double) -> WeightPoint {
            WeightPoint(date: calendar.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth))!, kg: kg)
        }
        let spring = try #require(NutritionProgressMath.weeklyRate([point(3, 2, 80), point(3, 9, 79)], calendar: calendar))
        #expect(abs(spring - -1) < 1e-9)
        let fall = try #require(NutritionProgressMath.weeklyRate([point(10, 29, 80), point(11, 5, 79)], calendar: calendar))
        #expect(abs(fall - -1) < 1e-9)
        #expect(NutritionProgressMath.change([point(3, 2, 80), point(3, 9, 79)], calendar: calendar)?.days == 7)
    }

    /// The sliding-window trend equals averaging each window outright.
    @Test func theTrendMatchesAPlainWindowAverage() {
        var generator = SystemRandomNumberGenerator()
        var daily: [WeightPoint] = []
        var date = calendar.startOfDay(for: day(-400))
        for _ in 0..<200 {
            date = calendar.date(byAdding: .day, value: Int.random(in: 1...4, using: &generator), to: date)!
            daily.append(WeightPoint(date: date, kg: Double.random(in: 70...90, using: &generator)))
        }
        let fast = NutritionProgressMath.trend(daily, calendar: calendar)
        for (index, point) in daily.enumerated() {
            let from = calendar.date(byAdding: .day, value: -6, to: point.date)!
            let window = daily.filter { $0.date >= from && $0.date <= point.date }
            #expect(abs(fast[index].kg - window.map(\.kg).reduce(0, +) / Double(window.count)) < 1e-9)
        }
    }

    /// R2-S1: two weigh-ins at the same instant are two points with their own, stable identities.
    @Test func weighInsAtTheSameTimeKeepTheirOwnIdentity() {
        let at = day(0, hour: 7)
        let first = BodyWeightEntry(measuredAt: at, value: 80, unit: .kg)
        let second = BodyWeightEntry(measuredAt: at, value: 82, unit: .kg, source: .health, healthSampleID: UUID())
        func reading(_ entries: [BodyWeightEntry]) -> ProgressReading {
            ProgressReading.nutrition(.bodyWeight, range: .days90, weights: entries, entries: [], goals: [], unit: .kg,
                                      now: today, calendar: calendar)
        }
        let both = reading([first, second])
        #expect(Set(both.points.map(\.id)) == [first.id.uuidString, second.id.uuidString])
        #expect(reading([second, first]).points == both.points, "the order does not depend on the input's")
        second.set(value: 81, unit: .kg)
        #expect(reading([first, second]).points.map(\.id) == both.points.map(\.id), "an edit keeps both identities")
        #expect(reading([first]).points.map(\.id) == [first.id.uuidString], "a delete leaves the other's")
        let daily = ProgressReading.nutrition(.weightTrend, range: .days90, weights: [first, second], entries: [],
                                              goals: [], unit: .kg, now: today, calendar: calendar)
        #expect(daily.points.count == 1 && daily.points[0].key == nil, "a day's average keeps its date key")
    }
}

extension HistoryFoodLine {
    static func make(_ title: String, _ detail: String?) -> HistoryFoodLine {
        var line = HistoryFoodLine(FoodDay(eaten: .zero, entryCount: 0, goal: nil, burned: 0))
        line.title = title
        line.detail = detail
        return line
    }
}
