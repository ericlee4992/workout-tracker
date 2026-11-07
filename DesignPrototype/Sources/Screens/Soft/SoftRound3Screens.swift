import SwiftUI

// PROPOSAL (Soft, round 3, 2026-11-07) — "History is gone, I want to keep it… the + is only needed
// for logging food… at most 5 tabs." Train holds Templates | Gyms | Exercises; History is a daily
// journal of workouts and meals; layout B adds a Food tab.

// MARK: - Train: Templates | Gyms | Exercises

struct SoftTrainScreen: View {
    @Environment(\.look) private var look
    @State private var part = UserDefaults.standard.string(forKey: "softTrainPart") ?? "Templates"

    var body: some View {
        ZStack {
            switch part {
            case "Gyms": GymsScreen()
            case "Exercises": ExercisesScreen()
            default: WorkoutHomeScreen()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                SoftSegmented(options: ["Templates", "Gyms", "Exercises"], selection: $part)
                    .frame(width: 300)
            }
        }
        .proposalScreen("train")
    }
}

// MARK: - History: one journal of training and food

struct SoftHistoryScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared

    private struct Day: Identifiable {
        let date: Date
        let workouts: [Workout]
        var id: Date { date }
    }

    private var days: [Day] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: store.history.prefix(14)) { cal.startOfDay(for: $0.startedAt) }
        var keys = Set(groups.keys)
        // This week's days with food but no workout still get a day in the journal.
        let today = cal.startOfDay(for: store.now)
        for offset in 0..<6 { if let d = cal.date(byAdding: .day, value: -offset, to: today), food(on: d) != nil { keys.insert(d) } }
        return keys.sorted(by: >).map { Day(date: $0, workouts: groups[$0] ?? []) }
    }

    /// Sample: food for the last six days of this week (Monday first in SoftNutrition.week).
    private func food(on date: Date) -> Int? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: store.now)
        guard let back = cal.dateComponents([.day], from: date, to: today).day, back >= 0, back < 6 else { return nil }
        if back == 0 { return nutrition.eaten }
        let index = 5 - back
        return index >= 0 && index < nutrition.week.count ? nutrition.week[index] : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("History").font(.system(.largeTitle, weight: .bold)).foregroundStyle(look.textPrimary)
                        Text("\(store.history.count) workouts · food logged 5 of 7 days").font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(look.textSecondary)
                    }
                    Spacer()
                    Button { router.present(.calendar) } label: {
                        Image(systemName: "calendar").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                            .frame(width: 44, height: 44).background(look.surface, in: Circle())
                            .shadow(color: .black.opacity(look.isDark ? 0 : 0.06), radius: 8, y: 2)
                    }
                    .accessibilityLabel("Calendar")
                }
                .padding(.top, 6)
                ForEach(days) { day in dayCard(day) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .proposalScreen("history")
    }

    private func dayCard(_ day: Day) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
            ForEach(day.workouts) { w in
                Button { router.push(.workoutDetail(workoutID: w.id)) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(look.surfaceRaised)
                            Image(systemName: w.setCount > 0 ? "dumbbell.fill" : "figure.run").font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(look.textPrimary)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.title).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                            Text([Format.count(w.durationSeconds / 60, "min", "min"), w.setCount > 0 ? Format.count(w.setCount, "set") : nil, w.gymName]
                                    .compactMap { $0 }.joined(separator: " · "))
                                .font(.system(.footnote)).foregroundStyle(look.textSecondary)
                        }
                        Spacer()
                        FamilyStrip(families: MuscleFamily.ordered(w.entries.compactMap { store.exercise($0.exerciseID)?.family }), size: 22, spacing: 1)
                        Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textTertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if let cal = food(on: day.date) {
                if !day.workouts.isEmpty { LookDivider().padding(.leading, 68) }
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(look.surfaceRaised)
                        Image(systemName: "fork.knife").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cal.formatted()) cal eaten").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                        Text(cal >= nutrition.calorieGoal ? "At goal" : "\((nutrition.calorieGoal - cal).formatted()) under goal")
                            .font(.system(.footnote)).foregroundStyle(look.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textTertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            Spacer().frame(height: 6)
        }
        .lookSurface(.panel)
    }
}

// MARK: - Food (layout B)

struct SoftFoodScreen: View {
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Food").font(.system(.largeTitle, weight: .bold)).foregroundStyle(look.textPrimary)
                    Text("Today").font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textSecondary)
                }
                .padding(.top, 6)
                SoftFuelCard()
                ForEach(["Breakfast", "Lunch", "Dinner", "Snack"], id: \.self) { meal in
                    mealCard(meal)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .proposalScreen("food")
    }

    private func mealCard(_ meal: String) -> some View {
        let foods = nutrition.today.filter { $0.meal == meal }
        let total = foods.reduce(0) { $0 + $1.calories }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(meal).font(.system(.headline)).foregroundStyle(look.textPrimary)
                Spacer()
                if total > 0 {
                    Text("\(total) cal").font(.system(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(look.textSecondary)
                }
                Button { SoftNav.shared.cover = .logFood } label: {
                    Image(systemName: "plus").font(.system(.subheadline, weight: .bold)).foregroundStyle(look.textPrimary)
                        .frame(width: 34, height: 34).overlay { Circle().strokeBorder(look.textPrimary.opacity(0.18)) }
                }
                .accessibilityLabel("Add to \(meal)")
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            ForEach(foods) { food in
                LookDivider().padding(.leading, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(food.name).font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
                        HStack(spacing: 10) {
                            ForEach(SoftMacro.allCases) { m in
                                let g = m == .protein ? food.protein : (m == .carbs ? food.carbs : food.fat)
                                Label("\(g)g", systemImage: m.symbol).labelStyle(TintedIconLabel(tint: m.color))
                                    .font(.system(.caption, weight: .medium)).foregroundStyle(look.textSecondary)
                            }
                        }
                    }
                    Spacer()
                    Text("\(food.calories)").font(.system(.body, weight: .semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            if foods.isEmpty {
                Text("Nothing logged").font(.system(.footnote)).foregroundStyle(look.textTertiary)
                    .padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .lookSurface(.panel)
    }
}
