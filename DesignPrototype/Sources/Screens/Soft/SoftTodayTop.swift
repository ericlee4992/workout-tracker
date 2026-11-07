import SwiftUI

// PROPOSAL (Soft, round 2, 2026-11-07) — the top of Today, redesigned to be ours rather than the
// reference's (circle strip + big calorie ring + three macro ring cards). The user: "It's exactly
// same as reference, so let's redesign it (make it even better)."
//
// 1. The week balance: one column per day around a baseline — training rises above it (a bar in
//    the muscle families trained, height = minutes), food hangs below it (calories eaten against
//    the goal; the goal is a mark at full depth). Only an app that logs both can draw this.
// 2. The fuel card: what's left is the headline; one bar fills toward the goal in the three macros'
//    shares of what was eaten; protein — the lifter's macro — leads with grams to go.

struct SoftWeekBalance: View {
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared
    @State private var selected: Int? = nil

    private let up: CGFloat = 54
    private let down: CGFloat = 34

    var body: some View {
        let days = store.weekSummary.days
        let todayIndex = days.firstIndex(where: \.isToday) ?? 5
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.system(.headline, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer()
                HStack(spacing: 12) {
                    legend(Circle().fill(look.family(.chest)), "Training")
                    legend(Circle().fill(look.textPrimary.opacity(0.28)), "Food")
                }
            }
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                    column(day: day, index: i, isToday: i == todayIndex)
                        .frame(maxWidth: .infinity)
                }
            }
            Text(summary(days)).font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .lookSurface(.panel)
    }

    private func column(day: WeekDaySummary, index: Int, isToday: Bool) -> some View {
        let minutes = day.workouts.reduce(0) { $0 + $1.minutes }
        let families = MuscleFamily.ordered(day.workouts.flatMap(\.families))
        let calories: Int? = isToday ? nutrition.eaten : (index < nutrition.week.count ? nutrition.week[index] : nil)
        return VStack(spacing: 3) {
            // Training, above the line.
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                if minutes > 0 {
                    let h = min(up, max(10, CGFloat(minutes) / 75 * up))
                    VStack(spacing: 2) {
                        if families.isEmpty {
                            Rectangle().fill(look.textSecondary)
                        } else {
                            ForEach(families.reversed()) { f in Rectangle().fill(look.family(f)) }
                        }
                    }
                    .frame(width: 14, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            .frame(height: up)
            // The baseline: each column draws its share, so the line runs across the card.
            Rectangle().fill(look.textPrimary.opacity(0.14)).frame(maxWidth: .infinity).frame(height: 1)
            // Food, below the line.
            VStack(spacing: 0) {
                if let calories, !day.isFuture {
                    let ratio = min(1.1, Double(calories) / Double(nutrition.calorieGoal))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isToday ? look.textPrimary : look.textPrimary.opacity(0.28))
                        .frame(width: 14, height: max(4, down * ratio))
                }
                Spacer(minLength: 0)
            }
            .frame(height: down)
            .overlay(alignment: .top) {
                // The goal's depth, a short tick.
                Rectangle().fill(look.textTertiary.opacity(day.isFuture ? 0.25 : 0.6)).frame(width: 20, height: 1).offset(y: down)
            }
            VStack(spacing: 1) {
                Text(day.letter).font(.system(.caption2, weight: isToday ? .bold : .medium))
                Text(day.date.formatted(.dateTime.day())).font(.system(.footnote, weight: isToday ? .bold : .semibold)).monospacedDigit()
            }
            .foregroundStyle(isToday ? look.onAction : (day.isFuture ? look.textTertiary : look.textPrimary))
            .padding(.horizontal, 4).padding(.vertical, 3)
            .frame(minWidth: 34, minHeight: 38)
            .background { if isToday { Capsule().fill(look.action) } }
            .padding(.top, 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(day: day, minutes: minutes, calories: calories, isToday: isToday))
    }

    private func legend<S: View>(_ swatch: S, _ text: String) -> some View {
        HStack(spacing: 4) {
            swatch.frame(width: 7, height: 7)
            Text(text).font(.system(.caption, weight: .medium)).foregroundStyle(look.textSecondary)
        }
    }

    private func summary(_ days: [WeekDaySummary]) -> String {
        let trained = days.filter { !$0.workouts.isEmpty }.count
        let logged = nutrition.week.compactMap { $0 }
        let avg = logged.isEmpty ? 0 : logged.reduce(0, +) / logged.count
        return "\(trained) training days · \(logged.count) days logged, \(avg.formatted()) cal on average"
    }

    private func spoken(day: WeekDaySummary, minutes: Int, calories: Int?, isToday: Bool) -> String {
        var parts = [isToday ? "Today" : Format.weekday(day.date)]
        if minutes > 0 { parts.append("trained \(minutes) minutes") }
        if let calories { parts.append("\(calories) calories") }
        return parts.joined(separator: ", ")
    }
}

struct SoftFuelCard: View {
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared

    var body: some View {
        let eaten = nutrition.eaten, goal = nutrition.calorieGoal
        let burned = store.history.first?.activeCalories ?? 0
        let left = max(0, goal - eaten)
        let ax = typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 16) {
            (ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(left.formatted()).font(.system(size: 44, weight: .semibold)).monospacedDigit()
                            .lineLimit(1).fixedSize()
                            .contentTransition(.numericText())
                        Text("cal left").font(.system(.title3, weight: .medium)).foregroundStyle(look.textSecondary)
                            .lineLimit(1).fixedSize()
                    }
                    .foregroundStyle(look.textPrimary)
                    Text("of \(goal.formatted()) today").font(.system(.subheadline)).foregroundStyle(look.textSecondary)
                }
                if !ax { Spacer(minLength: 8) }
                VStack(alignment: ax ? .leading : .trailing, spacing: 4) {
                    stat("Eaten", eaten.formatted())
                    stat("Burned", burned.formatted())
                }
            }
            fuelBar(eaten: eaten, goal: goal)
            VStack(spacing: 12) {
                protein
                (ax ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))) {
                    compact(.carbs)
                    compact(.fat)
                }
            }
        }
        .padding(20)
        .lookSurface(.panel)
    }

    /// One bar toward the goal, in the three macros' calorie shares of what was eaten.
    private func fuelBar(eaten: Int, goal: Int) -> some View {
        let p = Double(nutrition.eaten(.protein) * 4), c = Double(nutrition.eaten(.carbs) * 4), f = Double(nutrition.eaten(.fat) * 9)
        let sum = max(1, p + c + f)
        let filled = min(1, Double(eaten) / Double(goal))
        return GeometryReader { geo in
            let w = geo.size.width * filled
            HStack(spacing: 2) {
                Rectangle().fill(SoftMacro.protein.color).frame(width: max(0, w * p / sum - 2))
                Rectangle().fill(SoftMacro.carbs.color).frame(width: max(0, w * c / sum - 2))
                Rectangle().fill(SoftMacro.fat.color).frame(width: max(0, w * f / sum))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(look.ringTrack)
            .clipShape(Capsule())
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: eaten)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    /// Protein leads: the figure, the goal, and how far to go.
    private var protein: some View {
        let eaten = nutrition.eaten(.protein), goal = nutrition.goals[.protein] ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label("Protein", systemImage: SoftMacro.protein.symbol)
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                    .labelStyle(TintedIconLabel(tint: SoftMacro.protein.color))
                Spacer()
                Text("\(eaten)").font(.system(.title3, weight: .semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText())
                Text("/ \(goal) g").font(.system(.subheadline)).foregroundStyle(look.textSecondary)
            }
            line(progress: Double(eaten) / Double(goal), tint: SoftMacro.protein.color, height: 6)
            Text(eaten >= goal ? "Goal reached" : "\(goal - eaten) g to go")
                .font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func compact(_ m: SoftMacro) -> some View {
        let eaten = nutrition.eaten(m), goal = nutrition.goals[m] ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Label(m.name, systemImage: m.symbol).font(.system(.footnote, weight: .semibold))
                    .labelStyle(TintedIconLabel(tint: m.color)).foregroundStyle(look.textPrimary)
                Spacer(minLength: 2)
                Text("\(eaten)").font(.system(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
                Text("/\(goal)g").font(.system(.caption)).foregroundStyle(look.textSecondary)
            }
            line(progress: Double(eaten) / Double(goal), tint: m.color, height: 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func line(progress: Double, tint: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(look.ringTrack)
                Capsule().fill(tint).frame(width: geo.size.width * min(1, max(0.02, progress)))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(.footnote)).foregroundStyle(look.textSecondary)
            Text(value).font(.system(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
        }
    }
}

/// A label whose icon takes a tint while the title keeps the foreground style.
struct TintedIconLabel: LabelStyle {
    var tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(tint).font(.system(.caption, weight: .bold))
            configuration.title
        }
    }
}
