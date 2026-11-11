import Foundation

// Nutrition N10: Progress's body and food charts (the approved prototype's Body and Nutrition charts) and History's
// food line. Pure: the screens pass in the weights, entries and goals they query. Weights are worked in kilograms (each
// entry's `normalizedKg`) and shown in the app's unit; food uses `FoodDayMath`'s day (the goal in force that day, D70).

/// The five body and food charts Add Chart → Nutrition offers (the user, 2026-11-11: one Nutrition tab, two groups).
/// Stored in a pin by raw value — renaming a case makes that pin disappear quietly.
enum NutritionChart: String, CaseIterable, Codable, Sendable {
    case bodyWeight, weightTrend, calories, protein, macros

    enum Group { case body, food }

    var group: Group {
        switch self {
        case .bodyWeight, .weightTrend: .body
        case .calories, .protein, .macros: .food
        }
    }

    var title: String {
        switch self {
        case .bodyWeight: "Body weight"
        case .weightTrend: "Weight trend"
        case .calories: "Calories"
        case .protein: "Protein"
        case .macros: "Macros"
        }
    }

    /// What it measures, under the title (the prototype's lines).
    var measures: String {
        switch self {
        case .bodyWeight: "Each weigh-in"
        case .weightTrend: "7-day average"
        case .calories: "Eaten per day vs goal"
        case .protein: "Grams per day vs goal"
        case .macros: "Protein · carbs · fat per day"
        }
    }

    var glyph: String {
        switch self {
        case .bodyWeight, .weightTrend: "scalemass"
        case .calories: "flame"
        case .protein, .macros: "fork.knife"
        }
    }
}

/// A weight in kilograms: one weigh-in (with its entry's id), or a day's average at the day's start (no id).
struct WeightPoint: Equatable, Sendable {
    var date: Date
    var kg: Double
    /// The weigh-in's entry: its identity in a chart and a list (two weigh-ins can share a time).
    var entryID: UUID? = nil
}

/// One day of food for the charts: what was eaten and the goal in force that day.
struct FoodChartDay: Equatable {
    var date: Date
    var eaten: Macros
    var goal: DayGoal?
    var isLogged: Bool
}

/// The span a chart's detail shows.
enum NutritionRange: String, CaseIterable, Sendable {
    case week, month, days90, months6, year, all

    var title: String {
        switch self {
        case .week: "7D"
        case .month: "30D"
        case .days90: "90D"
        case .months6: "6M"
        case .year: "1Y"
        case .all: "All"
        }
    }

    /// Weight: 90D / 6M / 1Y / All (the ticket); food: 7D / 30D / 90D (a day each).
    static func choices(for chart: NutritionChart) -> [NutritionRange] {
        chart.group == .body ? [.days90, .months6, .year, .all] : [.week, .month, .days90]
    }

    /// What a panel shows: the last 90 days of weight, the last 7 days of food.
    static func panel(for chart: NutritionChart) -> NutritionRange { chart.group == .body ? .days90 : .week }

    /// The first day in the span ending today; nil for All.
    func start(endingAt now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let days: Int
        switch self {
        case .week: days = 7
        case .month: days = 30
        case .days90: days = 90
        case .months6: return calendar.date(byAdding: .month, value: -6, to: today)
        case .year: return calendar.date(byAdding: .year, value: -1, to: today)
        case .all: return nil
        }
        return calendar.date(byAdding: .day, value: -(days - 1), to: today)
    }
}

enum NutritionProgressMath {
    // MARK: Weight

    /// One point per day with a weigh-in — the day's weigh-ins averaged — oldest first. Every entry counts, the app's
    /// own and Apple Health's (N9b): this stays on the phone.
    static func dailyWeights(_ entries: [BodyWeightEntry], calendar: Calendar = .current) -> [WeightPoint] {
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.measuredAt) }
        return byDay.map { day, weights in
            WeightPoint(date: day, kg: weights.map(\.normalizedKg).reduce(0, +) / Double(weights.count))
        }
        .sorted { $0.date < $1.date }
    }

    /// Body weight's points (codex-review-n10 S3): each weigh-in as measured, oldest first — "Each weigh-in" means
    /// that; the trend averages by day instead.
    static func weighIns(_ entries: [BodyWeightEntry]) -> [WeightPoint] {
        // Equal times in a fixed order (by entry id), so the latest shown never flips between renders.
        entries.map { WeightPoint(date: $0.measuredAt, kg: $0.normalizedKg, entryID: $0.id) }
            .sorted { ($0.date, $0.entryID?.uuidString ?? "") < ($1.date, $1.entryID?.uuidString ?? "") }
    }

    /// The trend: each weigh-in day's value is the average of the daily weights in the 7 days ending that day (days
    /// without a weigh-in are skipped, not counted as zero). One pass with a sliding window (codex-review-n10: the
    /// whole history is averaged before a span is cut, so it must stay linear).
    static func trend(_ daily: [WeightPoint], days: Int = 7, calendar: Calendar = .current) -> [WeightPoint] {
        var result: [WeightPoint] = []
        result.reserveCapacity(daily.count)
        var first = 0
        var sum = 0.0
        for (index, point) in daily.enumerated() {
            sum += point.kg
            let from = calendar.date(byAdding: .day, value: -(days - 1), to: point.date) ?? point.date
            while daily[first].date < from {
                sum -= daily[first].kg
                first += 1
            }
            result.append(WeightPoint(date: point.date, kg: sum / Double(index - first + 1)))
        }
        return result
    }

    /// Whole calendar days between two instants' days — not seconds ÷ 86,400, which a daylight-saving change makes a
    /// day short or long (codex-review-n10 S2).
    static func days(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    /// The points from `start` on (all of them without one).
    static func points(_ points: [WeightPoint], from start: Date?) -> [WeightPoint] {
        guard let start else { return points }
        return points.filter { $0.date >= start }
    }

    /// The trend's change per week over its last four weeks (or what there is of them, at least a week); nil with too
    /// little to say.
    static func weeklyRate(_ trend: [WeightPoint], calendar: Calendar = .current) -> Double? {
        guard let last = trend.last,
              let from = calendar.date(byAdding: .day, value: -28, to: last.date),
              let first = trend.first(where: { $0.date >= from }) else { return nil }
        let span = days(from: first.date, to: last.date, calendar: calendar)
        guard span >= 7 else { return nil }
        return (last.kg - first.kg) / Double(span) * 7
    }

    /// The change over the points shown and the weeks it took ("−7.6 lb in 12 weeks"); nil with one point.
    static func change(_ points: [WeightPoint], calendar: Calendar = .current) -> (kg: Double, weeks: Int, days: Int)? {
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        let span = days(from: first.date, to: last.date, calendar: calendar)
        return (last.kg - first.kg, Int((Double(span) / 7).rounded()), span)
    }

    // MARK: Food

    /// Every day from `start` through `end`'s day, oldest first: what was eaten and that day's goal. Days without an
    /// entry are in the list, not logged (a chart leaves them blank; averages skip them).
    static func foodDays(_ entries: [FoodEntry], goals: [NutritionGoal], from start: Date, through end: Date,
                         calendar: Calendar = .current) -> [FoodChartDay] {
        let first = calendar.startOfDay(for: start), last = calendar.startOfDay(for: end)
        let byDay = Dictionary(grouping: entries.filter { $0.loggedAt >= first }) { calendar.startOfDay(for: $0.loggedAt) }
        var days: [FoodChartDay] = []
        var day = first
        while day <= last {
            let eaten = byDay[day] ?? []
            days.append(FoodChartDay(
                date: day, eaten: eaten.reduce(.zero) { $0 + NutritionMath.totals(of: $1) },
                goal: NutritionMath.goal(on: day, among: goals, calendar: calendar).map(DayGoal.init),
                isLogged: !eaten.isEmpty))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// The average over logged days; nil when none was logged.
    static func average(_ days: [FoodChartDay], _ value: (FoodChartDay) -> Double) -> Double? {
        let logged = days.filter(\.isLogged)
        guard !logged.isEmpty else { return nil }
        return logged.map(value).reduce(0, +) / Double(logged.count)
    }

    /// Protein · carbs · fat as shares of their calories (4/4/9) over the logged days, summing to 1; nil when no macro
    /// was logged.
    static func macroShares(_ days: [FoodChartDay]) -> (protein: Double, carbs: Double, fat: Double)? {
        let eaten = days.filter(\.isLogged).reduce(Macros.zero) { $0 + $1.eaten }
        let protein = eaten.proteinGrams * NutritionMath.caloriesPerGramProtein
        let carbs = eaten.carbsGrams * NutritionMath.caloriesPerGramCarbs
        let fat = eaten.fatGrams * NutritionMath.caloriesPerGramFat
        let sum = protein + carbs + fat
        guard sum > 0 else { return nil }
        return (protein / sum, carbs / sum, fat / sum)
    }

    /// Whole-percent shares that add up to 100 (the largest remainders get the leftover points).
    static func percents(_ shares: (protein: Double, carbs: Double, fat: Double)) -> [Int] {
        let raw = [shares.protein, shares.carbs, shares.fat].map { $0 * 100 }
        var whole = raw.map { Int($0.rounded(.down)) }
        let order = raw.indices.sorted { (raw[$0] - Double(whole[$0])) > (raw[$1] - Double(whole[$1])) }
        for index in order.prefix(max(0, 100 - whole.reduce(0, +))) { whole[index] += 1 }
        return whole
    }
}

// MARK: - History's food line

/// "1,240 cal eaten" and "1,048 under goal" / "312 over goal" / "At goal"; without a goal, no second line.
struct HistoryFoodLine: Equatable {
    var title: String
    var detail: String?

    init(_ day: FoodDay) {
        title = "\(Self.calories(day.eaten.calories)) cal eaten"
        guard let goal = day.goal else { detail = nil; return }
        let difference = goal.calories - day.eaten.calories
        if abs(difference) < 0.5 {
            detail = "At goal"
        } else if difference > 0 {
            detail = "\(Self.calories(difference)) under goal"
        } else {
            detail = "\(Self.calories(-difference)) over goal"
        }
    }

    static func calories(_ value: Double) -> String { value.rounded().formatted(.number.precision(.fractionLength(0))) }
}

extension FoodDayMath {
    /// Every day with food, keyed by its start, each against the goal in force that day (History's food lines). One
    /// pass over the entries; burned is left out (History shows the day's workouts beside it).
    static func loggedDays(_ entries: [FoodEntry], goals: [NutritionGoal], calendar: Calendar = .current) -> [Date: FoodDay] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.loggedAt) }.mapValues { eaten in
            let day = calendar.startOfDay(for: eaten[0].loggedAt)
            return FoodDay(eaten: eaten.reduce(.zero) { $0 + NutritionMath.totals(of: $1) }, entryCount: eaten.count,
                           goal: NutritionMath.goal(on: day, among: goals, calendar: calendar).map(DayGoal.init),
                           burned: 0)
        }
    }
}
