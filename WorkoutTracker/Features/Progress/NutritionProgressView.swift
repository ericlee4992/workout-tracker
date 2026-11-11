import SwiftData
import SwiftUI

/// Nutrition N10: a body or food chart, opened from its Progress panel — the span (weight 90D / 6M / 1Y / All, food
/// 7D / 30D / 90D), the chart large and the weigh-ins or days listed, newest first. A food day opens that day's food.
struct NutritionProgressView: View {
    let chart: NutritionChart
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Query private var weights: [BodyWeightEntry]
    @Query private var entries: [FoodEntry]
    @Query private var goals: [NutritionGoal]
    @Query private var preferences: [AppPreferences]
    @State private var range = 0
    @State private var now = Date.now

    private var ranges: [NutritionRange] { NutritionRange.choices(for: chart) }
    private var selected: NutritionRange { ranges.indices.contains(range) ? ranges[range] : ranges[0] }
    private var unit: WeightUnit { LiftProgressValues.displayUnit(preferences: preferences) }

    var body: some View {
        let reading = ProgressReading.nutrition(chart, range: selected, weights: weights, entries: entries, goals: goals,
                                                unit: unit, now: now)
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chart.title).font(look.font.title).foregroundStyle(look.textPrimary)
                    Text(chart.measures).font(look.font.subhead).foregroundStyle(look.textSecondary)
                }
                SegmentedPills(ranges.map(\.title), selection: $range)
                    .accessibilityIdentifier("nutritionChartRange")
                if reading.state == .empty {
                    Text("Nothing to chart here").font(look.font.subhead).foregroundStyle(look.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ProgressReadingHeader(reading: reading, numberFont: look.font.heroNumber)
                        if reading.state == .series || reading.style != .line {
                            ProgressPanelChart(reading: reading, height: 220)
                        }
                    }
                    .padding(16)
                    .lookSurface(.panel)
                    if chart.group == .body { weighIns(reading) } else { foodDays }
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 12)
        }
        .lookSheetGround()
        .navigationTitle(chart.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .refreshingNow($now)
    }

    /// Each day of the span, newest first (the trend's own values for the trend).
    private func weighIns(_ reading: ProgressReading) -> some View {
        LookList(header: chart == .weightTrend ? "7-day average" : "Weigh-ins") {
            ForEach(reading.points.reversed()) { point in
                HStack {
                    Text(HistoryFormat.shortDayTitle(point.date)).font(look.font.body).foregroundStyle(look.textPrimary)
                    Spacer()
                    Text("\(point.value.formatted(.number.precision(.fractionLength(1)))) \(unit.rawValue)")
                        .font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The logged days of the span, newest first; each opens that day's food.
    private var foodDays: some View {
        let start = selected.start(endingAt: now) ?? Calendar.current.startOfDay(for: now)
        let days = NutritionProgressMath.foodDays(entries, goals: goals, from: start, through: now).filter(\.isLogged)
        return LookList(header: "Days") {
            ForEach(days.reversed(), id: \.date) { day in
                NavigationLink {
                    DayFoodView(day: day.date)
                } label: {
                    LookRow(HistoryFormat.shortDayTitle(day.date), value: dayValue(day))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nutritionChartDay")
            }
        }
    }

    private func dayValue(_ day: FoodChartDay) -> String {
        let whole: (Double) -> String = { $0.rounded().formatted(.number.precision(.fractionLength(0))) }
        switch chart {
        case .protein: return "\(whole(day.eaten.proteinGrams)) g"
        case .macros:
            return "P \(whole(day.eaten.proteinGrams)) · C \(whole(day.eaten.carbsGrams)) · F \(whole(day.eaten.fatGrams)) g"
        default: return "\(whole(day.eaten.calories)) cal"
        }
    }
}
