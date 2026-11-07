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
    // ROUND 5 (2026-11-07, the user's idea): one column per day — the date, then a ring that fills
    // toward the calorie goal in the macros' colours, with a workout mark inside it on days you
    // trained. A one-line key says what the ring and the mark mean. AX sizes: one row per day.
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared

    var body: some View {
        let days = store.weekSummary.days
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.system(.headline, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                Text(summary(days)).font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            if typeSize.isAccessibilitySize {
                list(days)
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                        VStack(spacing: 8) {
                            VStack(spacing: 1) {
                                Text(day.letter).font(.system(.caption2, weight: .semibold))
                                Text(day.date.formatted(.dateTime.day())).font(.system(.subheadline, weight: .semibold)).monospacedDigit()
                            }
                            .foregroundStyle(day.isToday ? look.onAction : (day.isFuture ? look.textTertiary : look.textPrimary))
                            .frame(width: 34, height: 40)
                            .background { if day.isToday { Capsule().fill(look.action) } }
                            DayRing(calories: calories(day, i), macros: macros(day), goal: nutrition.calorieGoal,
                                    workout: workoutKind(day), future: day.isFuture, size: 40)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spoken(day, i))
                    }
                }
                key
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }

    /// The key: what the ring and the mark mean.
    private var key: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                DayRing(calories: 1500, macros: (0.3, 0.47, 0.23), goal: 2000, workout: nil, future: false, size: 16, line: 2.5)
                Text("Calories toward goal").font(.system(.caption, weight: .medium)).foregroundStyle(look.textSecondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(look.onAction)
                    .frame(width: 16, height: 16).background(look.textPrimary, in: Circle())
                Text("Worked out").font(.system(.caption, weight: .medium)).foregroundStyle(look.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private func calories(_ day: WeekDaySummary, _ i: Int) -> Int? {
        if day.isFuture { return nil }
        return day.isToday ? nutrition.eaten : (i < nutrition.week.count ? nutrition.week[i] : nil)
    }

    /// Calorie shares of protein / carbs / fat (today's real ones; a typical split on past days).
    private func macros(_ day: WeekDaySummary) -> (Double, Double, Double) {
        guard day.isToday else { return (0.31, 0.47, 0.22) }
        let p = Double(nutrition.eaten(.protein) * 4), c = Double(nutrition.eaten(.carbs) * 4), f = Double(nutrition.eaten(.fat) * 9)
        let sum = max(1, p + c + f)
        return (p / sum, c / sum, f / sum)
    }

    private func workoutKind(_ day: WeekDaySummary) -> DayRing.Mark? {
        guard !day.workouts.isEmpty else { return nil }
        if day.workouts.allSatisfy({ if case .cardio = $0.kind { true } else { false } }) { return .cardio }
        return .lifting
    }

    private func list(_ days: [WeekDaySummary]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(days.enumerated()).filter { !$0.element.isFuture }, id: \.element.id) { i, day in
                if i > 0 { LookDivider() }
                HStack(spacing: 14) {
                    DayRing(calories: calories(day, i), macros: macros(day), goal: nutrition.calorieGoal,
                            workout: workoutKind(day), future: false, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.isToday ? "Today" : day.date.formatted(.dateTime.weekday(.wide).day()))
                            .font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                        Text(spoken(day, i, includeDay: false)).font(.system(.body)).foregroundStyle(look.textSecondary)
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }

    private func summary(_ days: [WeekDaySummary]) -> String {
        let workouts = days.reduce(0) { $0 + $1.workouts.count }
        let logged = nutrition.week.compactMap { $0 }.count
        return "\(workouts) workout\(workouts == 1 ? "" : "s") · \(logged) days logged"
    }

    private func spoken(_ day: WeekDaySummary, _ i: Int, includeDay: Bool = true) -> String {
        var parts: [String] = []
        if includeDay { parts.append(day.isToday ? "Today" : Format.weekday(day.date)) }
        parts.append(day.workouts.isEmpty ? (day.isFuture ? "Upcoming" : "Rest day") : day.workouts.map(\.title).joined(separator: ", "))
        if let c = calories(day, i) { parts.append("\(c.formatted()) of \(nutrition.calorieGoal.formatted()) cal") }
        else if !day.isFuture { parts.append("No food logged") }
        return parts.joined(separator: " · ")
    }
}

/// One day: a ring filling toward the calorie goal in the macros' colours; a workout mark inside.
struct DayRing: View {
    enum Mark { case lifting, cardio }
    var calories: Int?
    var macros: (Double, Double, Double)
    var goal: Int
    var workout: Mark?
    var future: Bool
    var size: CGFloat
    var line: CGFloat = 4.5
    @Environment(\.look) private var look

    var body: some View {
        ZStack {
            if let calories, !future {
                let filled = min(1, Double(calories) / Double(goal))
                Circle().stroke(look.ringTrack, lineWidth: line).padding(line / 2)
                arc(from: 0, to: filled * macros.0, SoftMacro.protein.color)
                arc(from: filled * macros.0, to: filled * (macros.0 + macros.1), SoftMacro.carbs.color)
                arc(from: filled * (macros.0 + macros.1), to: filled, SoftMacro.fat.color)
            } else {
                Circle().strokeBorder(look.textTertiary.opacity(future ? 0.25 : 0.55),
                                      style: StrokeStyle(lineWidth: 1.5, dash: future ? [] : [3, 3]))
            }
            if let workout, !future {
                Image(systemName: workout == .cardio ? "figure.run" : "dumbbell.fill")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(look.onAction)
                    .frame(width: size * 0.56, height: size * 0.56)
                    .background(look.textPrimary, in: Circle())
            }
        }
        .frame(width: size, height: size)
    }

    private func arc(from a: Double, to b: Double, _ color: Color) -> some View {
        Circle()
            .trim(from: a + (b - a > 0.02 ? 0.006 : 0), to: max(a, b))
            .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .butt))
            .rotationEffect(.degrees(-90))
            .padding(line / 2)
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
