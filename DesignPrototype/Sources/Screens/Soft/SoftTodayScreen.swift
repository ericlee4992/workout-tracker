import SwiftUI

// EXPLORATION (2026-11-07) — Soft "Today": food and training on one page. The week strip, the
// calories card, three macro cards, today's training (the next template, or what was done), and
// today's log (foods and workouts, newest first).

struct SoftTodayScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var nutrition = SoftNutrition.shared
    @State private var showLeft = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                // PROPOSAL round 2: the week balance and the fuel card (SoftTodayTop.swift) replace the
                // reference-like day circles, calorie ring and macro ring cards.
                SoftWeekBalance()
                SoftFuelCard()
                SoftSectionTitle(title: "Training").padding(.top, 8)
                trainingCard
                SoftSectionTitle(title: "Today's log").padding(.top, 8)
                VStack(spacing: 12) {
                    ForEach(nutrition.today.reversed()) { SoftFoodRow(food: $0) }
                    if let workout = store.history.first { SoftWorkoutRow(workout: workout) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .proposalScreen("today")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today").font(.system(.largeTitle, weight: .bold)).foregroundStyle(look.textPrimary)
                Text(store.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    private var caloriesCard: some View {
        let left = max(0, nutrition.calorieGoal - nutrition.eaten)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                if showLeft {
                    SoftFigure(value: left.formatted())
                } else {
                    SoftFigure(value: nutrition.eaten.formatted(), goal: nutrition.calorieGoal.formatted())
                }
                Button {
                    withAnimation(.snappy) { showLeft.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showLeft ? "Calories left" : "Calories eaten")
                        Image(systemName: "chevron.up.chevron.down").font(.system(.caption, weight: .semibold))
                    }
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(look.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 8)
            SoftRing(progress: Double(nutrition.eaten) / Double(nutrition.calorieGoal), symbol: "flame.fill",
                     tint: look.textPrimary, size: typeSize.isAccessibilitySize ? 96 : 112, line: 10)
        }
        .padding(22)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    private var macroRow: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            ForEach(SoftMacro.allCases) { macro in
                let eaten = nutrition.eaten(macro), goal = nutrition.goals[macro] ?? 1
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(eaten)").font(.system(.title3, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(look.textPrimary).contentTransition(.numericText())
                            Text("/\(goal)g").font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                        }
                        Text(macro.name).font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                    }
                    SoftRing(progress: Double(eaten) / Double(goal), symbol: macro.symbol, tint: macro.color, size: 58, line: 6)
                        .frame(maxWidth: .infinity)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lookSurface(.card)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(macro.name), \(eaten) of \(goal) grams")
            }
        }
    }

    /// The next template with Start (Mono pill), or a link to the Train tab.
    @ViewBuilder private var trainingCard: some View {
        if let next = nextTemplate {
            let names = next.items.compactMap { store.exercise($0.exerciseID)?.name }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    FamilyStrip(families: store.families(ofTemplate: next.id), size: 30, spacing: 3)
                    Spacer()
                    Text("Up next").font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                }
                Text(next.name).font(.system(.title2, weight: .bold)).foregroundStyle(look.textPrimary)
                Text(names.prefix(3).joined(separator: " · ") + (names.count > 3 ? " · +\(names.count - 3)" : ""))
                    .font(.system(.subheadline)).foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    SoftPillButton(title: "Start", symbol: "play.fill") { _ = store.startLifting(templateID: next.id) }
                    Spacer()
                    Button { router.push(.templateDetail(templateID: next.id)) } label: {
                        Text("View").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                            .padding(.horizontal, 14).frame(minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .lookSurface(.panel)
        }
    }

    private var nextTemplate: Template? {
        store.sortedTemplates.min { a, b in
            (store.templateStats(a.id).lastRun ?? .distantPast) < (store.templateStats(b.id).lastRun ?? .distantPast)
        }
    }
}

// MARK: - Week strip

/// Seven days as small rings: dashed = nothing logged, the ring fills with the day's calories
/// against the goal; today sits on a white card.
struct SoftWeekStrip: View {
    var week: [Int?]
    var todayIndex: Int
    var todayProgress: Double
    @Environment(\.look) private var look
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let dates = [2, 3, 4, 5, 6, 7, 8]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let isToday = i == todayIndex
                let future = i > todayIndex
                let progress: Double? = isToday ? todayProgress : week[i].map { Double($0) / 2288 }
                VStack(spacing: 8) {
                    Text(days[i]).font(.system(.caption, weight: isToday ? .semibold : .medium))
                        .foregroundStyle(future ? look.textTertiary : (isToday ? look.textPrimary : look.textSecondary))
                    ZStack {
                        if let progress, !future {
                            SoftRing(progress: progress, symbol: nil, tint: look.textPrimary, size: 36, line: 3)
                        } else {
                            Circle().strokeBorder(look.textTertiary.opacity(future ? 0.35 : 0.6),
                                                  style: StrokeStyle(lineWidth: 1.5, dash: future ? [] : [3, 3]))
                                .frame(width: 36, height: 36)
                        }
                        Text("\(dates[i])").font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(future ? look.textTertiary : look.textPrimary)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(look.surface)
                            .shadow(color: .black.opacity(look.isDark ? 0 : 0.05), radius: 10, y: 3)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isToday ? "Today" : days[i])
            }
        }
    }
}

// MARK: - Log rows

struct SoftFoodRow: View {
    let food: SoftFood
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(look.surfaceRaised)
                Image(systemName: "fork.knife").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(food.name).font(.system(.headline)).foregroundStyle(look.textPrimary)
                    Spacer()
                    Text(food.time).font(.system(.footnote)).foregroundStyle(look.textSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(food.calories)").font(.system(.title3, weight: .semibold)).monospacedDigit()
                    Text("cal").font(.system(.subheadline)).foregroundStyle(look.textSecondary)
                }
                .foregroundStyle(look.textPrimary)
                HStack(spacing: 14) {
                    macro(.protein, food.protein)
                    macro(.carbs, food.carbs)
                    macro(.fat, food.fat)
                }
            }
        }
        .padding(16)
        .lookSurface(.card)
        .accessibilityElement(children: .combine)
    }

    private func macro(_ m: SoftMacro, _ grams: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: m.symbol).font(.system(.caption2, weight: .semibold)).foregroundStyle(m.color)
            Text("\(grams)g").font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary).monospacedDigit()
        }
    }
}

struct SoftWorkoutRow: View {
    let workout: Workout
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(look.surfaceRaised)
                Image(systemName: "dumbbell.fill").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.title).font(.system(.headline)).foregroundStyle(look.textPrimary)
                    Spacer()
                    Text(workout.startedAt.formatted(date: .omitted, time: .shortened)).font(.system(.footnote)).foregroundStyle(look.textSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(workout.activeCalories ?? 0)").font(.system(.title3, weight: .semibold)).monospacedDigit()
                    Text("cal burned").font(.system(.subheadline)).foregroundStyle(look.textSecondary)
                }
                .foregroundStyle(look.textPrimary)
                HStack(spacing: 14) {
                    Label("\(workout.durationSeconds / 60) min", systemImage: "timer")
                    Label(Format.count(workout.setCount, "set"), systemImage: "square.stack.3d.up")
                }
                .font(.system(.footnote, weight: .medium))
                .foregroundStyle(look.textSecondary)
            }
        }
        .padding(16)
        .lookSurface(.card)
        .accessibilityElement(children: .combine)
    }
}
