import SwiftUI

// Soft redesign S2: Today's pieces. The week as day rings follows the prototype's round 5 (the user's idea,
// 2026-11-07): "a row for each day, and below each day a ring … and inside the ring shows whether you worked
// out". In Phase 1 the ring is its track only (no food yet): dashed for a past day with nothing logged, faint for
// days ahead; a black disc with a dumbbell (a runner for a cardio-only day) inside on days trained. Nutrition N5
// fills the rings with the day's calories in macro colours.

struct TodayWeekRings: View {
    var summary: WeekSummary
    /// N5: each day's food, keyed by its start of day.
    var food: [Date: FoodDay] = [:]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var ring: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(look.font.sectionTitle).foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                Text(headline).font(look.font.subhead).foregroundStyle(look.textSecondary)
            }
            if typeSize.isAccessibilitySize {
                // AX sizes: one row per day, the ring larger and the day's workouts in words.
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summary.days) { day in
                        HStack(spacing: 14) {
                            TodayDayRing(day: day, food: food[day.date], size: ring * 1.1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.date, format: .dateTime.weekday(.wide).day())
                                    .font(look.font.headline).foregroundStyle(look.textPrimary)
                                Text(detail(day)).font(look.font.subhead).foregroundStyle(look.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(summary.days) { day in
                        VStack(spacing: 8) {
                            dayLabel(day)
                            TodayDayRing(day: day, food: food[day.date], size: ring)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spoken(day))
                    }
                }
                // The key: what the ring and the mark mean (N5).
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(look.ringTrack, lineWidth: 2.5)
                            DayRingFood(day: FoodDay(eaten: Macros(calories: 1_500, proteinGrams: 30, carbsGrams: 47,
                                                                   fatGrams: 10),
                                                     entryCount: 1, goal: DayGoal(calories: 2_000, proteinGrams: 0,
                                                                                  carbsGrams: 0, fatGrams: 0),
                                                     burned: 0),
                                        width: 2.5)
                        }
                        .frame(width: 14, height: 14)
                        Text("Calories toward goal").font(look.font.caption).foregroundStyle(look.textSecondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(look.textPrimary).frame(width: 8, height: 8)
                        Text("Worked out").font(look.font.caption).foregroundStyle(look.textSecondary)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(look.space.panelPadding)
        .lookSurface(.panel)
        .accessibilityIdentifier("todayWeek")
    }

    private func dayLabel(_ day: WeekDaySummary) -> some View {
        VStack(spacing: 2) {
            Text(day.letter).font(look.font.caption2).foregroundStyle(day.isToday ? look.onAction : look.textSecondary)
            Text(day.date, format: .dateTime.day())
                .font(look.font.subhead.weight(.semibold)).monospacedDigit()
                .foregroundStyle(day.isToday ? look.onAction : look.textPrimary)
        }
        .padding(.vertical, 5)
        .frame(minWidth: 34)
        .background { if day.isToday { Capsule().fill(look.action) } }
    }

    /// "3 workouts · 5 days logged" (N5).
    private var headline: String {
        let count = summary.workoutCount
        let workouts = count == 1 ? "1 workout" : "\(count) workouts"
        let logged = FoodDayMath.daysLogged(food)
        return workouts + " · " + (logged == 1 ? "1 day logged" : "\(logged) days logged")
    }

    /// AX rows: "Pull Day · 55 min · 2,140 of 2,288 cal".
    private func detail(_ day: WeekDaySummary) -> String {
        var parts = [day.workouts.isEmpty ? (day.isFuture ? "Ahead" : "Rest day")
                     : day.workouts.map(\.title).joined(separator: ", ") + " · \(day.minutes) min"]
        if !day.isFuture, let food = food[day.date] { parts.append(Self.food(food)) }
        return parts.joined(separator: " · ")
    }

    private func spoken(_ day: WeekDaySummary) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day())
        let today = day.isToday ? ", today" : ""
        var text = date + today
        if day.workouts.isEmpty { text += day.isFuture ? "" : ", no workout" }
        else { text += ", " + day.workouts.map(\.title).joined(separator: ", ") }
        if !day.isFuture, let food = food[day.date] { text += ", " + Self.food(food) }
        return text
    }

    /// "2,140 of 2,288 cal", "2,140 cal" without a goal, "No food logged".
    static func food(_ day: FoodDay) -> String {
        guard day.isLogged else { return "No food logged" }
        let eaten = TodayFoodCopy.calories(day.eaten.calories)
        guard let goal = day.goal else { return "\(eaten) cal" }
        return "\(eaten) of \(TodayFoodCopy.calories(goal.calories)) cal"
    }
}

/// One day's ring: the track (dashed when a past day has nothing logged, faint ahead) with the workout mark; N5 fills
/// it toward the day's calorie goal in the macros' colours.
struct TodayDayRing: View {
    var day: WeekDaySummary
    var food: FoodDay? = nil
    var size: CGFloat
    @Environment(\.look) private var look

    private var mark: String? {
        guard !day.workouts.isEmpty else { return nil }
        return day.workouts.allSatisfy { $0.kind == .cardio } ? "figure.run" : "dumbbell.fill"
    }

    var body: some View {
        let width = max(3, size * 0.11)
        ZStack {
            if day.isFuture {
                Circle().stroke(look.ringTrack.opacity(0.6), lineWidth: width)
            } else if let food, food.isLogged {
                Circle().stroke(look.ringTrack, lineWidth: width)
                DayRingFood(day: food, width: width)
            } else {
                // Nothing logged (N5: dashed means no food, whether or not the day had a workout).
                Circle().stroke(look.dash, style: StrokeStyle(lineWidth: max(1.5, width * 0.45), dash: [3, 3]))
            }
            if let mark {
                Circle().fill(look.textPrimary).padding(width + 2)
                Image(systemName: mark)
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(look.isDark ? Color.black : Color.white)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Soft redesign S5 (D77): the template up next — learned from the user's order or their split — with its own Start and
/// a "Not today" menu (Next in order / Choose template… / Back to plan).
struct TodayUpNextCard<NotToday: View>: View {
    var name: String
    var families: [MuscleFamily]
    var caption: String
    var start: () -> Void
    @ViewBuilder var notToday: () -> NotToday
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Up next").font(look.font.footnote.weight(.medium)).foregroundStyle(look.textSecondary)
                Spacer(minLength: 8)
                TodayNotTodayMenu(content: notToday)
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(look.font.cardTitle).foregroundStyle(look.textPrimary).lineLimit(2)
                    if !families.isEmpty { FamilyStrip(families: families, size: 26) }
                    Text(caption).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 8)
                Button("Start", action: start)
                    .font(look.font.button)
                    .foregroundStyle(look.onAction)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(look.action, in: Capsule())
                    .buttonStyle(.lookPressable)
                    .accessibilityLabel("Start \(name)")
                    .accessibilityIdentifier("todayStartUpNext")
            }
        }
        .padding(look.space.panelPadding)
        .lookSurface(.panel)
    }
}

/// "Not today ⌄": the menu on the up-next and rest-day cards.
struct TodayNotTodayMenu<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.look) private var look

    var body: some View {
        Menu(content: content) {
            HStack(spacing: 4) {
                Text("Not today")
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(look.font.footnote.weight(.medium))
            .foregroundStyle(look.textSecondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("todayNotToday")
    }
}

/// Soft redesign S5: the user's weekday split has nothing today.
struct TodayRestDayCard<Items: View>: View {
    @ViewBuilder var menu: () -> Items
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("My split").font(look.font.footnote.weight(.medium)).foregroundStyle(look.textSecondary)
                Spacer(minLength: 8)
                TodayNotTodayMenu(content: menu)
            }
            // The id on the title, not the card: a container's identifier would hide the menu's (`todayNotToday`).
            Text("Rest day").font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                .accessibilityIdentifier("todayRestDay")
            Text("Nothing in your split today.").font(look.font.footnote).foregroundStyle(look.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(look.space.panelPadding)
        .lookSurface(.panel)
    }
}

/// Soft redesign S5 (D77): no templates — the last workout with Repeat, an empty Start workout, and a way into
/// Train to make a template or Ask AI for a week. Without any workout yet: Start workout and the hint.
struct TodayNoTemplateCard: View {
    var lastWorkout: Workout?
    var repeatLast: () -> Void
    var startEmpty: () -> Void
    var openTrain: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lastWorkout {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last workout").font(look.font.footnote.weight(.medium)).foregroundStyle(look.textSecondary)
                    Text(lastWorkout.historyTitle).font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                        .lineLimit(2)
                    let families = families(of: lastWorkout)
                    if !families.isEmpty { FamilyStrip(families: families, size: 26) }
                    Text(lastWorkout.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { buttons }
                    VStack(spacing: 10) { buttons }
                }
            } else {
                Text("Start a workout").font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                startButton(primary: true)
            }
            Button(action: openTrain) {
                HStack(spacing: 8) {
                    Text("Make a template, or ask AI for a week, in Train.")
                        .font(look.font.subhead).foregroundStyle(look.textSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(look.textTertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("todayOpenTrain")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(look.space.panelPadding)
        .lookSurface(.panel)
    }

    @ViewBuilder private var buttons: some View {
        Button(action: repeatLast) {
            Label("Repeat", systemImage: "arrow.counterclockwise")
                .font(look.font.button)
                .fixedSize()
                .foregroundStyle(look.onAction)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(look.action, in: Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("Repeat \(lastWorkout?.historyTitle ?? "last workout")")
        .accessibilityIdentifier("todayRepeat")
        startButton(primary: false)
    }

    @ViewBuilder private func startButton(primary: Bool) -> some View {
        if primary {
            Button(action: startEmpty) {
                Label("Start workout", systemImage: "figure.strengthtraining.traditional")
                    .font(look.font.button)
                    .foregroundStyle(look.onAction)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(look.action, in: Capsule())
            }
            .buttonStyle(.lookPressable)
            .accessibilityIdentifier("todayStartWorkout")
        } else {
            // Full width measured (`fixedSize`), so `ViewThatFits` stacks the two buttons instead of wrapping or
            // truncating "Start workout".
            Button(action: startEmpty) { Label("Start workout", systemImage: "plus").fixedSize() }
                .buttonStyle(.lookSecondary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("todayStartWorkout")
        }
    }

    private func families(of workout: Workout) -> [MuscleFamily] {
        guard let input = WeekSummaryInput(workout: workout) else { return [] }
        return MuscleFamily.allCases.filter { (input.familySets[$0] ?? 0) > 0 }
    }
}

/// A finished workout of today: its name, families, start time and length.
struct TodayWorkoutRow: View {
    var workout: Workout
    @Environment(\.look) private var look

    var body: some View {
        let input = WeekSummaryInput(workout: workout)
        let families = input.map { Array($0.familySets.filter { $0.value > 0 }.keys) } ?? []
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.historyTitle).font(look.font.headline).foregroundStyle(look.textPrimary).lineLimit(2)
                Text(caption(input)).font(look.font.subhead).foregroundStyle(look.textSecondary)
            }
            Spacer(minLength: 8)
            if !families.isEmpty { FamilyStrip(families: families, size: 24) }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(look.textTertiary)
        }
        .padding(look.space.panelPadding)
        .contentShape(Rectangle())
    }

    /// "7:05 AM · 55 min · 320 cal" — the calories the workout burned when a sensor measured them (N5).
    private func caption(_ input: WeekSummaryInput?) -> String {
        var parts = [workout.startedAt.formatted(date: .omitted, time: .shortened)]
        if let input { parts.append("\(input.durationSeconds / 60) min") }
        if let burned = FoodDayMath.burned(by: workout) { parts.append("\(TodayFoodCopy.calories(burned)) cal") }
        return parts.joined(separator: " · ")
    }
}
