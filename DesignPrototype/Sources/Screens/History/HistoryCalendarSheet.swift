import SwiftUI

// H02 Calendar: a month grid whose training days show how much was done (A brighter bulbs,
// B family rings that thicken, C bigger punches; cardio adds a heart-rate mark), month totals,
// and every workout of the selected day (not only one). Tap a day to select it; tap a workout
// to open it. Chevrons or a sideways swipe change the month.

struct HistoryCalendarSheet: View {
    var body: some View {
        HistoryCalendarContent().historySheetTypeOverride()
    }
}

/// The sheet itself (a child view, so an accessibility type override set on the sheet root
/// reaches its own layout decisions).
struct HistoryCalendarContent: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedMonth: Date?
    @State private var selectedDate: Date?
    @State private var direction: Edge = .trailing
    @State private var ticks = 0

    private var cal: Calendar { Calendar.app }

    var body: some View {
        let month = displayedMonth ?? initialDate
        let data = store.calendarMonth(containing: month, selected: selectedDate ?? initialDate)
        let summary = store.monthSummary(for: month)
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    monthPanel(data, summary: summary)
                    selectedDay(data)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .lookSheetGround()
        .presentationDetents([.large])
        .presentationBackground(look.groundSheet)
        .sensoryFeedback(.selection, trigger: ticks)
        .onAppear(perform: applyCaptureVariant)
    }

    /// Capture states: a day with no workouts ("empty"), and the sheet paged back to August
    /// with a day of that month selected ("aug").
    private func applyCaptureVariant() {
        guard store.currentScreen == .h02, let variant = router.variant else { return }
        let base = initialDate
        switch variant {
        case "empty":
            router.variant = nil
            selectedDate = cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: base))
        case "aug":
            router.variant = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                page(-1)
                let august = cal.date(byAdding: .month, value: -1, to: base) ?? base
                let day = store.history.first { cal.isDate($0.startedAt, equalTo: august, toGranularity: .month) }
                selectedDate = day.map { cal.startOfDay(for: $0.startedAt) }
            }
        default: break
        }
    }

    /// Opening: the capture's day (H02: Sep 21), else the latest training day, else today.
    private var initialDate: Date {
        if let date = store.screenTarget.date { return date }
        return store.history.first?.startedAt ?? store.now
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text("Calendar")
                .font(look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                GlassIconButton("xmark", accessibilityLabel: "Close") { router.dismissSheet() }
                Spacer()
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: Month

    private func monthPanel(_ data: CalendarMonth, summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Month and pager on one line, the month's totals under them (full width, so they
            // wrap as a unit at accessibility sizes).
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 8) {
                    Text(data.title)
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.opacity)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 4)
                    CardIconButton("chevron.left", accessibilityLabel: "Previous month") { page(-1) }
                        .disabled(!data.hasPrevious)
                        .opacity(data.hasPrevious ? 1 : 0.35)
                    CardIconButton("chevron.right", accessibilityLabel: "Next month") { page(1) }
                        .disabled(!data.hasNext)
                        .opacity(data.hasNext ? 1 : 0.35)
                }
                // Each total wraps as a whole phrase ("155 sets" never splits across lines).
                HistoryFlowLayout(spacing: 0, lineSpacing: 2) {
                    Text(HistoryFormat.workouts(summary.workouts) + " · ")
                    Text(Format.count(summary.sets, "set") + " · ")
                    Text(Format.hours(summary.hours))
                }
                .font(look.font.footnote)
                .monospacedDigit()
                .foregroundStyle(look.textSecondary)
                .padding(.top, -6)
                .accessibilityElement(children: .combine)
            }
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(Array(data.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)
                grid(data)
                    .id(data.month)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: direction).combined(with: .opacity),
                                                                     removal: .opacity))
            }
            .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0, data.hasNext { page(1) }
                if value.translation.width > 0, data.hasPrevious { page(-1) }
            })
        }
        .padding(16)
        .lookSurface(.panel)
    }

    private func grid(_ data: CalendarMonth) -> some View {
        let signals = store.historyDaySignals
        return VStack(spacing: 4) {
            ForEach(Array(data.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            HistoryCalendarDayCell(day: day, signal: signals[cal.startOfDay(for: day.date)]) {
                                select(day)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                        }
                    }
                }
            }
        }
    }

    private func page(_ delta: Int) {
        let current = displayedMonth ?? initialDate
        guard let next = cal.date(byAdding: .month, value: delta, to: current) else { return }
        direction = delta > 0 ? .trailing : .leading
        if reduceMotion { displayedMonth = next } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { displayedMonth = next }
        }
        ticks += 1
    }

    private func select(_ day: CalendarDay) {
        guard !day.isFuture else { return }
        ticks += 1
        if reduceMotion { selectedDate = day.date } else {
            withAnimation(.snappy(duration: 0.25)) { selectedDate = day.date }
        }
    }

    // MARK: Selected day

    @ViewBuilder
    private func selectedDay(_ data: CalendarMonth) -> some View {
        if let date = data.selectedDate {
            VStack(alignment: .leading, spacing: look.space.header) {
                let workouts = data.selectedWorkouts.compactMap { store.workout($0.workoutID) }
                let dayLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                dayLayout {
                    Text(HistoryFormat.dayTitle(date))
                        .font(look.font.sectionTitle)
                        .foregroundStyle(look.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    if !workouts.isEmpty {
                        Text(HistoryFormat.workouts(workouts.count))
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                    }
                }
                .padding(.horizontal, 4)
                if workouts.isEmpty {
                    Text("No workouts")
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .lookSurface(.panel)
                } else {
                    HistoryListPanel(separatorInset: 16) {
                        ForEach(workouts) { workout in
                            HistoryWorkoutRow(workout: workout, dateStyle: .hidden) { open(workout) }
                        }
                    }
                }
            }
            .id(date)
            .transition(.opacity)
        }
    }

    private func open(_ workout: Workout) {
        router.dismissSheet()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.select(.history)
            router.push(.workoutDetail(workoutID: workout.id))
        }
    }
}

// MARK: - Day cell

struct HistoryCalendarDayCell: View {
    var day: CalendarDay
    var signal: HistoryDaySignal?
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var heightScaled: CGFloat = 46

    private var height: CGFloat { min(heightScaled, 56) }
    private var trained: Bool { day.intensity > 0 }

    var body: some View {
        Button(action: action) {
            ZStack {
                switch look.id {
                case .floodlight: bulb
                case .anatomy: rings
                case .paper, .carbon: punch
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(day.isFuture)
        // The grid is a picture of the month: numbers stay inside their marks (capped), and the
        // selected day's list below carries full-size text. Long-press shows the large viewer.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer { Text(spoken) }
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(day.isSelected ? .isSelected : [])
    }

    private var spoken: String {
        var text = "\(Format.weekday(day.date)), \(Format.shortDate(day.date))"
        if day.isToday { text = "Today, " + text }
        if trained {
            text += ", \(day.workoutIDs.count == 1 ? "1 workout" : "\(day.workoutIDs.count) workouts")"
            if day.sets > 0 { text += ", \(Format.count(day.sets, "set"))" }
        }
        return text
    }

    private var number: some View {
        Text("\(day.dayNumber)")
            .font(.system(.body, design: look.id == .anatomy ? .rounded : .default,
                          weight: trained || day.isToday ? .bold : .regular).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    // A: a bulb lit by the day's work; selection is a floodlight ring outside the cell.
    private var bulb: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        let levels: [Double] = [0, 0.55, 0.7, 0.85, 1]
        return ZStack {
            shape
                .fill(trained ? look.done.opacity(levels[min(4, day.intensity)])
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
                number.foregroundStyle(trained ? look.onDone : (day.isFuture ? look.textTertiary : look.textSecondary))
                if signal?.hasCardio == true {
                    // Cardio: the run figure (scales with text; the heart stays heart rate's).
                    Image(systemName: "figure.run")
                        .font(.system(.caption2, weight: .bold))
                        .imageScale(.small)
                        .foregroundStyle(trained ? look.onDone.opacity(0.8) : look.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            if day.isSelected {
                shape.strokeBorder(look.textPrimary, lineWidth: 2)
            }
        }
    }

    // B: the day's families as a ring of arcs (thicker with more sets), cardio in heart-rate red.
    private var rings: some View {
        let widths: [CGFloat] = [0, 2.5, 3.5, 4.5, 5.5]
        let width = widths[min(4, day.intensity)]
        let side = height - 4
        var colors: [Color] = (signal?.families ?? []).map { look.family($0.family) }
        if signal?.hasCardio == true { colors.append(look.heartRate) }
        let count = max(1, colors.count)
        return ZStack {
            if day.isSelected {
                Circle().fill(look.textPrimary).frame(width: side - width * 2 - 3, height: side - width * 2 - 3)
            }
            if trained {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    let step = 1.0 / Double(count)
                    let gap = count > 1 ? 0.04 : 0
                    RingArc(start: Double(index) * step + gap / 2, end: Double(index + 1) * step - gap / 2)
                        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: count > 1 ? .round : .butt))
                        .padding(width / 2)
                }
                .frame(width: side, height: side)
            } else if day.isToday {
                // Today: a thin dashed hairline, never as heavy as a trained day's ring.
                Circle().strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5]))
                    .frame(width: side - 6, height: side - 6)
            } else if day.isSelected {
                EmptyView()
            }
            number.foregroundStyle(day.isSelected ? look.onAction
                                   : (trained || day.isToday ? look.textPrimary : (day.isFuture ? look.dayDotPast : look.textTertiary)))
        }
    }

    // C: trained days punched in ink (bigger with more work); cardio-only is a hollow punch;
    // today a dashed cobalt ring; the selection a cobalt ring.
    private var punch: some View {
        // Punch diameter grows with the day's work and with the text size (cell height scales).
        // Four clear steps by the day's sets, in size AND ink (a light day is a smaller, greyer
        // punch; a big day a full black one).
        let fractions: [CGFloat] = [0, 0.64, 0.75, 0.86, 0.98]
        let inks: [Double] = [0, 0.62, 0.78, 0.9, 1]
        let level = min(4, day.intensity)
        let side = height * fractions[level]
        let cardioOnly = signal?.hasCardio == true && signal?.hasLifting != true
        // The punch is never smaller than its number (large text grows the punch, not the overlap).
        return HistorySquare(minSide: trained ? side : height * 0.74) {
            number
                .foregroundStyle(trained && !cardioOnly ? look.onDone
                                 : (day.isFuture ? look.textSecondary.opacity(0.55) : look.textPrimary))
                .padding(3)
        }
        .background {
            if trained {
                if cardioOnly {
                    Circle().strokeBorder(look.textPrimary, lineWidth: 2.5)
                } else {
                    Circle().fill(look.done.opacity(inks[level]))
                }
            } else if day.isToday {
                Circle().strokeBorder(look.actionText, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            }
        }
        .overlay {
            if day.isSelected {
                Circle().strokeBorder(look.actionText, lineWidth: 2.5).padding(-3)
            }
        }
    }
}
