import SwiftUI

// H01 History (tab root) and H07 empty. The month on top: three figures and a heat strip of
// every day (A lit bulbs · B family bars · C punches), then the workouts as LISTS grouped by
// week. Older months open with their own totals. The calendar sits in the toolbar.

struct HistoryScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var pendingDelete: Workout?
    /// Capture demo: the first row starts with its Delete tile revealed.
    @State private var demoSwipe = false

    var body: some View {
        let months = store.historyMonthSections()
        let weeks = months.flatMap(\.weeks)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("History")
                if months.isEmpty {
                    HistoryEmptyState()
                } else {
                    HistoryMonthCard(month: store.now)
                    ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                        if index > 0 || !Calendar.app.isDate(month.month, equalTo: store.now, toGranularity: .month) {
                            HistoryMonthBreak(month: month.month).id("month-\(index)")
                        }
                        ForEach(month.weeks) { week in
                            weekSection(week).id("week-\(weeks.firstIndex(of: week) ?? 0)")
                        }
                    }
                }
                Color.clear.frame(height: 1).id(HistoryAnchor.bottom)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .proposalScreen("history")
        .historyInlineTitle("History", after: 40) {
            // Nothing to show on a calendar yet: the button appears with the first workout.
            if !months.isEmpty {
                Button { router.present(.calendar) } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Calendar")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .historyCaptureVariant(.h01, anchor: { variant in
            switch variant {
            case "p2": "week-1"
            case "p3": months.count > 1 ? "month-1" : "week-3"
            case "p4": "week-\(min(5, max(0, weeks.count - 1)))"
            default: nil
            }
        }, onVariant: { variant in
            switch variant {
            case "swipe": demoSwipe = true
            case "delete":
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pendingDelete = store.history.first }
            case "mixed":
                // A workout logged in both units (Leg Day, Sep 16), opened from the list.
                let id = SampleData.workoutID("2026-09-16")
                HistoryCaptureHandoff.pending = (id, "mixed")
                router.push(.workoutDetail(workoutID: id))
            default: break
            }
        })
    }

    private func weekSection(_ week: HistoryWeekSection) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            HStack(alignment: .firstTextBaseline) {
                Text(week.title)
                    .font(look.id.isPaperClub ? look.font.title3 : look.font.headline)
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(HistoryFormat.workouts(week.workouts.count))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .padding(.horizontal, 4)
            HistoryListPanel(separatorInset: 70) {
                ForEach(Array(week.workouts.enumerated()), id: \.element.id) { index, workout in
                    // The date tile only on a day's first workout; a second one that day
                    // leaves the column empty.
                    let sameDay = index > 0 && Calendar.app.isDate(week.workouts[index - 1].startedAt,
                                                                   inSameDayAs: workout.startedAt)
                    HistorySwipeRow(startsOpen: demoSwipe && workout.id == store.history.first?.id,
                                    onDelete: { pendingDelete = workout }) {
                        HistoryWorkoutRow(workout: workout, dateStyle: sameDay ? .continued : .shown) {
                            router.push(.workoutDetail(workoutID: workout.id))
                        }
                    }
                    // On the row, so the dialog rises from the workout it deletes.
                    .confirmationDialog("Delete this workout?", isPresented: Binding(
                        get: { pendingDelete?.id == workout.id }, set: { if !$0 { pendingDelete = nil } }),
                                        titleVisibility: .visible) {
                        Button("Delete Workout", role: .destructive) {
                            withAnimation(.snappy) { store.deleteWorkout(workout.id) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(HistoryDeleteCopy.workout(workout, store: store))
                    }
                }
            }
        }
    }
}

// MARK: - Month card

/// The month's figures (workouts · sets · time) over its heat strip. A: one scoreboard divided
/// by hairlines; B: a card with free figures and family bars; C: a ticket with vertical rules
/// and punches. Tapping the strip opens the calendar.
struct HistoryMonthCard: View {
    var month: Date
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let summary = store.monthSummary(for: month)
        let calendar = store.calendarMonth(containing: month)
        let days = calendar.weeks.flatMap { $0 }.compactMap { $0 }
        VStack(alignment: .leading, spacing: look.space.header) {
            if look.id != .anatomy {
                SectionHeader(Format.monthName(month))
            }
            VStack(alignment: .leading, spacing: 0) {
                if look.id == .anatomy {
                    Text(Format.monthName(month))
                        .font(look.font.sectionTitle)
                        .foregroundStyle(look.textPrimary)
                        .padding(.horizontal, 16).padding(.top, 16)
                        .accessibilityAddTraits(.isHeader)
                }
                figures(summary)
                    .padding(.horizontal, look.id == .floodlight ? 0 : 16)
                    .padding(.vertical, look.id == .anatomy ? 12 : 0)
                if look.id != .anatomy { LookDivider() }
                Button { router.present(.calendar) } label: {
                    HistoryMonthStrip(days: days, signals: store.historyDaySignals)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.lookPressable)
                .accessibilityHint("Opens the calendar")
            }
            .lookSurface(.panel)
        }
    }

    @ViewBuilder
    private func figures(_ summary: MonthSummary) -> some View {
        let minutes = Int((summary.hours * 60).rounded())
        let stacked = typeSize.isAccessibilitySize
        let lower = look.id.isPaperClub
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        let ruled = look.id != .anatomy
        layout {
            cell(label: lower ? "workouts" : "Workouts", row: stacked, first: true) {
                CountUpText(summary.workouts).font(look.font.bigNumber).foregroundStyle(look.textPrimary)
            }
            if ruled { LookDivider(vertical: !stacked) }
            cell(label: lower ? "sets" : "Sets", row: stacked, first: false) {
                CountUpText(summary.sets).font(look.font.bigNumber).foregroundStyle(look.textPrimary)
            }
            if ruled { LookDivider(vertical: !stacked) }
            cell(label: lower ? "time" : "Time", row: stacked, first: false) {
                // "7.9 h": one number fits the scoreboard column ("7 h 54 min" did not).
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(HistoryFormat.hoursNumber(summary.hours))
                        .font(look.font.bigNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText())
                    Text("h")
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                        .foregroundStyle(look.textSecondary)
                }
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(minutes / 60) hours \(minutes % 60) minutes")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func cell<V: View>(label: String, row: Bool, first: Bool, @ViewBuilder value: () -> V) -> some View {
        if row {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                value()
                Spacer(minLength: 8)
                Text(label).font(look.historyFigureLabel).foregroundStyle(look.textSecondary)
            }
            .padding(.horizontal, look.id == .floodlight ? 16 : 0)
            .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                value()
                Text(label).font(look.historyFigureLabel).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, look.id == .anatomy ? 0 : (first && look.id != .floodlight ? 0 : 16))
            .padding(.vertical, look.id == .anatomy ? 0 : 14)
        }
    }
}

/// An older month opens with its name and totals in one line.
struct HistoryMonthBreak: View {
    var month: Date
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        let summary = store.monthSummary(for: month)
        VStack(alignment: .leading, spacing: 4) {
            Text(Format.monthName(month))
                .font(look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("\(HistoryFormat.workouts(summary.workouts)) · \(Format.count(summary.sets, "set")) · \(Format.hours(summary.hours))")
                .font(look.font.subhead)
                .monospacedDigit()
                .foregroundStyle(look.textSecondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Empty (H07)

/// Empty is an invitation: the look's own empty mark (an unlit ring / an open stamp), the
/// title, and one command. No month card and no calendar until there is something to show.
struct HistoryEmptyState: View {
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 22) {
            HistoryEmptyMark(size: 132)
            Text("No workouts yet")
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .multilineTextAlignment(.center)
            StartCapsule(title: "Start Lifting", symbol: "figure.strengthtraining.traditional") {
                _ = store.startLifting()
            }
            .fixedSize()
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

// MARK: - Confirmation copy (existing strings; the volume now uses the app unit)

enum HistoryDeleteCopy {
    /// The existing set message; when it is the exercise's only set, it also says the exercise
    /// goes (deleting the last set removes the entry).
    static func set(exerciseName: String?, isOnlySet: Bool) -> String {
        var text = "This set is removed permanently, and records and volume are recalculated without it."
        if isOnlySet, let exerciseName { text += " \(exerciseName) has no other sets, so it is removed from this workout too." }
        return text
    }

    static func workout(_ workout: Workout, store: Store) -> String {
        let impact = store.deleteImpact(workoutID: workout.id)
        var text: String
        if impact.sets > 0 {
            text = "\(Format.count(impact.sets, "set")) across \(Format.count(impact.exercises, "exercise"))"
            if impact.volumeKg > 0 { text += ", \(Format.volume(kilograms: impact.volumeKg, in: store.displayUnit)) of volume," }
            text += " permanently deleted. Records are recalculated without them."
        } else {
            text = "This workout is permanently deleted."
        }
        if workout.hasCardio { text += " Recorded cardio and any routes will also be deleted." }
        return text
    }
}
