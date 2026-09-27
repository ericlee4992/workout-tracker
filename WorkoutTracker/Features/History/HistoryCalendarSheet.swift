import SwiftUI

/// Floodlight redesign ticket 05 (was milestone 9, ticket 03) — when did I train? One month at a
/// time: its totals, day cells lit by the day's sets (cardio adds a run glyph), today dashed,
/// the selected day outlined, and every workout of the selected day under the grid. Tapping a
/// day selects it; tapping a workout opens it. Chevrons or a sideways swipe change the month.
///
/// Presentation only: `WorkoutCalendar` decides which months and cells exist and
/// `HistoryOverviewMath` what each day holds.
struct HistoryCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Finished workouts, newest first.
    let workouts: [Workout]
    let facts: [UUID: HistoryWorkoutFacts]
    let appUnit: WeightUnit
    /// Called with the workout to open; the presenter pushes it once the sheet has closed.
    let onOpen: (Workout) -> Void

    @State private var monthIndex: Int?
    @State private var selectedDay: Date?
    @State private var direction: Edge = .trailing
    @State private var ticks = 0

    private var calendar: WorkoutCalendar { WorkoutCalendar(startedAt: workouts.map(\.startedAt)) }
    private var allFacts: [HistoryWorkoutFacts] { workouts.compactMap { facts[$0.id] } }

    /// Opening on the latest training day (its month, selected), else today's month.
    private var initialDay: Date { Calendar.current.startOfDay(for: workouts.first?.startedAt ?? .now) }

    private func initialIndex(in months: [WorkoutCalendar.Month]) -> Int {
        months.lastIndex { Calendar.current.isDate($0.start, equalTo: initialDay, toGranularity: .month) }
            ?? max(0, months.count - 1)
    }

    var body: some View {
        let months = calendar.months
        let index = min(monthIndex ?? initialIndex(in: months), max(0, months.count - 1))
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if months.indices.contains(index) {
                        monthPanel(months[index], index: index, count: months.count)
                        selectedDaySection
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .lookSheetGround()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .tint(look.textPrimary)
                        .accessibilityIdentifier("closeCalendar")
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(look.groundSheet)
        .sensoryFeedback(.selection, trigger: ticks)
        .accessibilityIdentifier("historyCalendarSheet")
    }

    // MARK: Month

    private func monthPanel(_ month: WorkoutCalendar.Month, index: Int, count: Int) -> some View {
        let summary = HistoryOverviewMath.monthSummary(allFacts, month: month.start)
        let days = Dictionary(
            HistoryOverviewMath.days(inMonthOf: month.start, facts: allFacts, now: .now).map { ($0.date, $0) },
            uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 8) {
                    Text(HistoryFormat.monthYear(month.start))
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.opacity)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("calendarMonth")
                    Spacer(minLength: 4)
                    CardIconButton("chevron.left", accessibilityLabel: "Previous month") { page(-1, count: count) }
                        .disabled(index == 0)
                        .opacity(index == 0 ? 0.35 : 1)
                    CardIconButton("chevron.right", accessibilityLabel: "Next month") { page(1, count: count) }
                        .disabled(index >= count - 1)
                        .opacity(index >= count - 1 ? 0.35 : 1)
                }
                // Each total wraps as a whole phrase ("155 sets" never splits across lines).
                WrapLayout(spacing: 0, lineSpacing: 2) {
                    Text(HistoryFormat.workouts(summary.workouts) + " · ")
                    Text(HistoryRendering.pluralized(summary.sets, "set", "sets") + " · ")
                    Text("\(HistoryFormat.hoursNumber(summary.hours)) h")
                }
                .font(look.font.footnote)
                .monospacedDigit()
                .foregroundStyle(look.textSecondary)
                .accessibilityElement(children: .combine)
            }
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(Array(calendar.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)
                grid(month, days: days)
                    .id(month.id)
                    .transition(reduceMotion ? .opacity
                                : .asymmetric(insertion: .move(edge: direction).combined(with: .opacity), removal: .opacity))
            }
            .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0 { page(1, count: count) }
                if value.translation.width > 0 { page(-1, count: count) }
            })
        }
        .padding(16)
        .lookSurface(.panel)
    }

    private func grid(_ month: WorkoutCalendar.Month, days: [Date: HistoryDay]) -> some View {
        let weeks = stride(from: 0, to: month.cells.count, by: 7).map { Array(month.cells[$0..<min($0 + 7, month.cells.count)]) }
        let selected = selectedDay ?? initialDay
        return VStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                        if let cell {
                            HistoryCalendarDayCell(
                                day: cell, facts: days[cell.date],
                                isSelected: Calendar.current.isDate(selected, inSameDayAs: cell.date)
                            ) { select(cell) }
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                        }
                    }
                }
            }
        }
    }

    private func page(_ delta: Int, count: Int) {
        let current = monthIndex ?? initialIndex(in: calendar.months)
        let next = current + delta
        guard next >= 0, next < count else { return }
        direction = delta > 0 ? .trailing : .leading
        if reduceMotion { monthIndex = next } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { monthIndex = next }
        }
        ticks += 1
    }

    private func select(_ day: WorkoutCalendar.Day) {
        // A day that has not happened holds nothing — unless a (clock-shifted) workout is
        // dated there, which stays reachable (`markedFuture`).
        guard !day.isFuture || day.isMarked else { return }
        ticks += 1
        if reduceMotion { selectedDay = day.date } else {
            withAnimation(.snappy(duration: 0.25)) { selectedDay = day.date }
        }
    }

    // MARK: Selected day

    @ViewBuilder
    private var selectedDaySection: some View {
        let day = selectedDay ?? initialDay
        let dayWorkouts = workouts
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
            .sorted { $0.startedAt < $1.startedAt }
        VStack(alignment: .leading, spacing: look.space.header) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            layout {
                Text(HistoryFormat.dayTitle(day))
                    .font(look.font.sectionTitle)
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                if !dayWorkouts.isEmpty {
                    Text(HistoryFormat.workouts(dayWorkouts.count))
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
            }
            .padding(.horizontal, 4)
            if dayWorkouts.isEmpty {
                Text("No workouts")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .lookSurface(.panel)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dayWorkouts.enumerated()), id: \.element.id) { index, workout in
                        if index > 0 { LookDivider().padding(.leading, 16) }
                        Button { onOpen(workout) } label: {
                            HistoryWorkoutRow(workout: workout, facts: facts[workout.id], appUnit: appUnit, dateStyle: .hidden)
                        }
                        .buttonStyle(HistoryRowPressStyle())
                        .accessibilityIdentifier("calendarWorkoutRow")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
                .lookSurface(.panel)
            }
        }
        .id(day)
        .transition(.opacity)
    }
}

// MARK: - Day cell

/// A day: a bulb lit by the day's sets (four steps), its number on it; cardio adds the run
/// glyph; today dashed; future days outlined and inert; the selected day ringed.
struct HistoryCalendarDayCell: View {
    var day: WorkoutCalendar.Day
    var facts: HistoryDay?
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var heightScaled: CGFloat = 46

    private var height: CGFloat { min(heightScaled, 56) }
    private var trained: Bool { day.isMarked }
    private var intensity: Int { max(trained ? 1 : 0, facts?.intensity ?? 0) }

    var body: some View {
        Button(action: action) {
            bulb
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(day.isFuture && !trained)
        // The grid is a picture of the month: numbers stay inside their cells (capped), and the
        // selected day's list below carries full-size text. Long-press shows the large viewer.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer { Text(spoken) }
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("calendarDay.\(Self.key(day.date))")
    }

    private var spoken: String {
        var text = "\(LookFormat.weekday(day.date)), \(LookFormat.shortDate(day.date))"
        if day.isToday { text = "Today, " + text }
        if trained, let facts {
            let count = facts.workoutIDs.count
            text += ", \(count == 1 ? "1 workout" : "\(count) workouts")"
            if facts.sets > 0 { text += ", \(HistoryRendering.pluralized(facts.sets, "set", "sets"))" }
        }
        if day.emphasis == .markedFuture { text += ", dated in the future" }
        return text
    }

    private var bulb: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        // The lightest lit step keeps its number legible: at 0.62, white on Floodlight Light's
        // ink measures 5.6:1 (0.55 was 4.35:1 — Codex review 05).
        let levels: [Double] = [0, 0.62, 0.74, 0.87, 1]
        return ZStack {
            shape
                .fill(trained ? look.done.opacity(levels[min(4, intensity)])
                      : (day.isFuture || day.isToday ? Color.clear : look.surfaceRaised))
                .overlay {
                    if day.isToday && !trained {
                        shape.strokeBorder(look.textPrimary.opacity(0.62), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    } else if day.isFuture {
                        shape.strokeBorder(look.hairline, lineWidth: 1)
                    }
                }
                .padding(4)
            VStack(spacing: 1) {
                Text("\(day.dayOfMonth)")
                    .font(.system(.body, weight: trained || day.isToday ? .bold : .regular).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(trained ? look.onDone : (day.isFuture ? look.textTertiary : look.textSecondary))
                if facts?.hasCardio == true {
                    Image(systemName: "figure.run")
                        .font(.system(.caption2, weight: .bold))
                        .imageScale(.small)
                        .foregroundStyle(trained ? look.onDone.opacity(0.8) : look.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            if isSelected {
                shape.strokeBorder(look.textPrimary, lineWidth: 2)
            }
        }
    }

    /// A stable per-day identifier for tests, independent of locale.
    static func key(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
