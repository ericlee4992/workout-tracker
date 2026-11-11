import Foundation

// Nutrition N10: a body or food chart's reading — the figure, its line and the points — from `NutritionProgressMath`.
// The panel shows the panel's span (90 days of weight, 7 days of food); the chart's own page shows the span picked.

extension ProgressReading {
    static func nutrition(_ chart: NutritionChart, range: NutritionRange, weights: [BodyWeightEntry],
                          entries: [FoodEntry], goals: [NutritionGoal], unit: WeightUnit, now: Date,
                          calendar: Calendar = .current) -> ProgressReading {
        switch chart.group {
        case .body:
            return weight(chart, range: range, weights: weights, unit: unit, now: now, calendar: calendar)
        case .food:
            return food(chart, range: range, entries: entries, goals: goals, now: now, calendar: calendar)
        }
    }

    // MARK: Weight

    private static func weight(_ chart: NutritionChart, range: NutritionRange, weights: [BodyWeightEntry],
                               unit: WeightUnit, now: Date, calendar: Calendar) -> ProgressReading {
        let daily = NutritionProgressMath.dailyWeights(weights, calendar: calendar)
        // The trend is worked out over every weigh-in, then cut to the span (its first days still average the week
        // before them).
        let series = chart == .weightTrend ? NutritionProgressMath.trend(daily, calendar: calendar) : daily
        let shown = NutritionProgressMath.points(series, from: range.start(endingAt: now, calendar: calendar))
        func inUnit(_ kg: Double) -> Double { WeightMath.convert(kg, from: .kg, to: unit) }
        func text(_ kg: Double) -> String { inUnit(kg).formatted(.number.precision(.fractionLength(1))) }
        guard let latest = shown.last else { return ProgressReading(value: "—", unit: "", caption: "", points: []) }
        var caption = HistoryFormat.shortDayTitle(latest.date)
        if chart == .weightTrend, let rate = NutritionProgressMath.weeklyRate(series, calendar: calendar) {
            caption = "\(signed(inUnit(rate))) \(unit.rawValue) a week"
        } else if chart == .bodyWeight, let change = NutritionProgressMath.change(shown) {
            let span = change.weeks >= 2 ? "\(change.weeks) weeks" : HistoryRendering.pluralized(change.days, "day", "days")
            caption = "\(signed(inUnit(change.kg))) \(unit.rawValue) in \(span)"
        }
        return ProgressReading(
            value: text(latest.kg), unit: unit.rawValue, caption: caption, change: nil,
            points: shown.map { Point(date: $0.date, value: inUnit($0.kg), isBest: false) },
            axisLabel: { $0.formatted(.number.precision(.fractionLength(0...1))) },
            singleNote: "One weigh-in")
    }

    /// "−7.6", "+0.4", "0.0": one decimal with its sign (a real minus).
    static func signed(_ value: Double) -> String {
        let text = abs(value).formatted(.number.precision(.fractionLength(1)))
        if text == 0.0.formatted(.number.precision(.fractionLength(1))) { return text }
        return (value < 0 ? "−" : "+") + text
    }

    // MARK: Food

    private static func food(_ chart: NutritionChart, range: NutritionRange, entries: [FoodEntry],
                             goals: [NutritionGoal], now: Date, calendar: Calendar) -> ProgressReading {
        let start = range.start(endingAt: now, calendar: calendar) ?? calendar.startOfDay(for: now)
        let days = NutritionProgressMath.foodDays(entries, goals: goals, from: start, through: now, calendar: calendar)
        let logged = days.filter(\.isLogged)
        let domain = (days.first?.date ?? start)...(days.last?.date ?? start)
        let goal = days.last(where: { $0.goal != nil })?.goal
        let count = "\(logged.count) of \(days.count) days logged"
        guard !logged.isEmpty else { return ProgressReading(value: "—", unit: "", caption: "", points: []) }
        let grouped: (Double) -> String = { $0.rounded().formatted(.number.precision(.fractionLength(0))) }
        switch chart {
        case .calories:
            let average = NutritionProgressMath.average(days) { $0.eaten.calories } ?? 0
            return ProgressReading(
                value: grouped(average), unit: "cal", caption: "Daily average · \(count)", change: nil,
                points: logged.map { Point(date: $0.date, value: $0.eaten.calories, isBest: false) },
                axisLabel: grouped, singleNote: "One day", style: .bars, goal: goal?.calories, xDomain: domain)
        case .protein:
            let average = NutritionProgressMath.average(days) { $0.eaten.proteinGrams } ?? 0
            let target = goal.map { " · goal \(grouped($0.proteinGrams)) g" } ?? ""
            return ProgressReading(
                value: grouped(average), unit: "g", caption: "Daily average\(target)", change: nil,
                points: logged.map { Point(date: $0.date, value: $0.eaten.proteinGrams, isBest: false) },
                axisLabel: grouped, singleNote: "One day", style: .bars, goal: goal?.proteinGrams, xDomain: domain)
        default:
            let shares = NutritionProgressMath.macroShares(days)
            let value = shares.map { NutritionProgressMath.percents($0).map(String.init).joined(separator: " / ") } ?? "—"
            return ProgressReading(
                value: value, unit: shares == nil ? "" : "%", caption: "Protein / carbs / fat · \(count)", change: nil,
                points: logged.map { day in
                    let parts = [day.eaten.proteinGrams * NutritionMath.caloriesPerGramProtein,
                                 day.eaten.carbsGrams * NutritionMath.caloriesPerGramCarbs,
                                 day.eaten.fatGrams * NutritionMath.caloriesPerGramFat]
                    return Point(date: day.date, value: parts.reduce(0, +), isBest: false, parts: parts)
                },
                axisLabel: grouped, singleNote: "One day", style: .macros, goal: goal?.calories, xDomain: domain)
        }
    }
}
