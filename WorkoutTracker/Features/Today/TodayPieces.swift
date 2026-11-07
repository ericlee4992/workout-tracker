import SwiftUI

// Soft redesign S2: Today's pieces. The week as day rings follows the prototype's round 5 (the user's idea,
// 2026-11-07): "a row for each day, and below each day a ring … and inside the ring shows whether you worked
// out". In Phase 1 the ring is its track only (no food yet): dashed for a past day with nothing logged, faint for
// days ahead; a black disc with a dumbbell (a runner for a cardio-only day) inside on days trained. Nutrition N5
// fills the rings with the day's calories in macro colours.

struct TodayWeekRings: View {
    var summary: WeekSummary
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
                            TodayDayRing(day: day, size: ring * 1.1)
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
                            TodayDayRing(day: day, size: ring)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spoken(day))
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(look.textPrimary).frame(width: 8, height: 8)
                    Text("Worked out").font(look.font.caption).foregroundStyle(look.textSecondary)
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

    private var headline: String {
        let count = summary.workoutCount
        return count == 1 ? "1 workout" : "\(count) workouts"
    }

    private func detail(_ day: WeekDaySummary) -> String {
        if day.workouts.isEmpty { return day.isFuture ? "Ahead" : "Rest day" }
        return day.workouts.map(\.title).joined(separator: ", ") + " · \(day.minutes) min"
    }

    private func spoken(_ day: WeekDaySummary) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day())
        let today = day.isToday ? ", today" : ""
        if day.workouts.isEmpty { return date + today + (day.isFuture ? "" : ", no workout") }
        return date + today + ", " + day.workouts.map(\.title).joined(separator: ", ")
    }
}

/// One day's ring: the track (dashed when a past day has nothing logged, faint ahead) with the workout mark.
struct TodayDayRing: View {
    var day: WeekDaySummary
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
            } else if mark == nil {
                Circle().stroke(look.dash, style: StrokeStyle(lineWidth: max(1.5, width * 0.45), dash: [3, 3]))
            } else {
                Circle().stroke(look.ringTrack, lineWidth: width)
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

/// The template up next (the one done longest ago) with its own Start.
struct TodayUpNextCard: View {
    var name: String
    var families: [MuscleFamily]
    var lastRun: Date?
    var start: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Up next").font(look.font.footnote.weight(.medium)).foregroundStyle(look.textSecondary)
                Text(name).font(look.font.cardTitle).foregroundStyle(look.textPrimary).lineLimit(2)
                if !families.isEmpty { FamilyStrip(families: families, size: 26) }
                Text(lastRunText).font(look.font.footnote).foregroundStyle(look.textSecondary)
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
        .padding(look.space.panelPadding)
        .lookSurface(.panel)
    }

    private var lastRunText: String {
        guard let lastRun else { return "Not done yet" }
        return "Last done " + lastRun.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// No template yet: a quiet row into Train → Templates.
struct TodayNoTemplateRow: View {
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No templates yet").font(look.font.headline).foregroundStyle(look.textPrimary)
                    Text("Make one in Train.").font(look.font.subhead).foregroundStyle(look.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(look.textTertiary)
            }
            .padding(look.space.panelPadding)
            .lookSurface(.panel)
        }
        .buttonStyle(.lookPressable)
        .accessibilityIdentifier("todayOpenTrain")
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

    private func caption(_ input: WeekSummaryInput?) -> String {
        let time = workout.startedAt.formatted(date: .omitted, time: .shortened)
        guard let input else { return time }
        return "\(time) · \(input.durationSeconds / 60) min"
    }
}
