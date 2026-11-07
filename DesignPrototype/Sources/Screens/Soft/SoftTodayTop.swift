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
    // ROUND 4 (2026-11-07, the user: "a little hard to read"): labelled rows with real numbers
    // instead of unlabelled bars around a baseline. Train: an ink tile with the minutes and a dot per
    // muscle family. Food: the calories (in thousands) and a thin bar toward the goal. Today's column
    // is the one with the black date. AX sizes: one line per day.
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared

    private let labelWidth: CGFloat = 50

    var body: some View {
        let days = store.weekSummary.days
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.system(.headline, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                Text(summary(days)).font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            if typeSize.isAccessibilitySize {
                list(days)
            } else {
                grid(days)
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }

    // MARK: Grid

    private func grid(_ days: [WeekDaySummary]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Color.clear.frame(width: labelWidth, height: 1)
                ForEach(Array(days.enumerated()), id: \.element.id) { _, day in
                    VStack(spacing: 1) {
                        Text(day.letter).font(.system(.caption2, weight: .semibold))
                        Text(day.date.formatted(.dateTime.day())).font(.system(.subheadline, weight: .semibold)).monospacedDigit()
                    }
                    .foregroundStyle(day.isToday ? look.onAction : (day.isFuture ? look.textTertiary : look.textPrimary))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background { if day.isToday { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(look.action) } }
                }
            }
            row("Train", days) { i, day in trainCell(day) }
            row("Food", days) { i, day in foodCell(day, index: i) }
        }
    }

    private func row<Cell: View>(_ label: String, _ days: [WeekDaySummary], @ViewBuilder cell: @escaping (Int, WeekDaySummary) -> Cell) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
            ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                cell(i, day).frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private func trainCell(_ day: WeekDaySummary) -> some View {
        let minutes = day.workouts.reduce(0) { $0 + $1.minutes }
        let families = MuscleFamily.ordered(day.workouts.flatMap(\.families))
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if minutes > 0 {
            VStack(spacing: 3) {
                Text("\(minutes)").font(.system(.subheadline, weight: .bold)).monospacedDigit()
                    .foregroundStyle(look.onDone).minimumScaleFactor(0.7).lineLimit(1)
                HStack(spacing: 2) {
                    ForEach(families.prefix(3)) { f in Circle().fill(look.family(f)).frame(width: 5, height: 5) }
                    if families.isEmpty { Circle().fill(look.onDone.opacity(0.5)).frame(width: 5, height: 5) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(shape.fill(look.done))
            .accessibilityLabel("\(Format.weekday(day.date)), trained \(minutes) minutes")
        } else {
            Text(day.isFuture ? "" : "–").font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background { if day.isFuture { shape.strokeBorder(look.hairline) } else { shape.fill(look.surfaceRaised) } }
                .accessibilityLabel("\(Format.weekday(day.date)), \(day.isFuture ? "upcoming" : "rest day")")
        }
    }

    @ViewBuilder private func foodCell(_ day: WeekDaySummary, index: Int) -> some View {
        let calories: Int? = day.isToday ? nutrition.eaten : (index < nutrition.week.count ? nutrition.week[index] : nil)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if let calories, !day.isFuture {
            let ratio = Double(calories) / Double(nutrition.calorieGoal)
            VStack(spacing: 5) {
                Text(short(calories)).font(.system(.footnote, weight: .bold)).monospacedDigit()
                    .foregroundStyle(look.textPrimary).minimumScaleFactor(0.7).lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(look.ringTrack)
                        Capsule().fill(day.isToday ? look.textPrimary : look.textPrimary.opacity(0.55))
                            .frame(width: geo.size.width * min(1, ratio))
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(shape.fill(look.surfaceRaised))
            .accessibilityLabel("\(Format.weekday(day.date)), \(calories) calories, goal \(nutrition.calorieGoal)")
        } else {
            Text(day.isFuture ? "" : "–").font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background { if day.isFuture { shape.strokeBorder(look.hairline) } else { shape.fill(look.surfaceRaised) } }
        }
    }

    // MARK: AX list

    private func list(_ days: [WeekDaySummary]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(days.enumerated()).filter { !$0.element.isFuture }, id: \.element.id) { i, day in
                if i > 0 { LookDivider() }
                let minutes = day.workouts.reduce(0) { $0 + $1.minutes }
                let calories: Int? = day.isToday ? nutrition.eaten : (i < nutrition.week.count ? nutrition.week[i] : nil)
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.isToday ? "Today" : day.date.formatted(.dateTime.weekday(.wide).day()))
                        .font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                    Text([minutes > 0 ? "\(day.workouts.map(\.title).joined(separator: ", ")), \(minutes) min" : "Rest day",
                          calories.map { "\($0.formatted()) cal" }].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(.body)).foregroundStyle(look.textSecondary)
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func short(_ calories: Int) -> String {
        calories >= 1000 ? String(format: "%.1fk", Double(calories) / 1000) : "\(calories)"
    }

    private func summary(_ days: [WeekDaySummary]) -> String {
        let workouts = days.reduce(0) { $0 + $1.workouts.count }
        let logged = nutrition.week.compactMap { $0 }
        let avg = logged.isEmpty ? 0 : logged.reduce(0, +) / logged.count
        return "\(workouts) workout\(workouts == 1 ? "" : "s") · \(avg.formatted()) cal avg"
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
