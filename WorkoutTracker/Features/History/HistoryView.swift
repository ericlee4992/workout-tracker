import SwiftData
import SwiftUI

/// The History tab (Floodlight redesign ticket 05): the month card over the workouts grouped by
/// week, each week one panel. A native `List`, so rows keep their swipe-to-delete.
struct HistoryView: View {
    /// Only finished workouts are history; the active one (finishedAt nil)
    /// never appears here.
    @Query(
        filter: #Predicate<Workout> { $0.finishedAt != nil },
        sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @Query private var allPreferences: [AppPreferences]
    /// C2: a workout the presenter wants opened — "View in History" on the
    /// post-finish receipt. Consumed (set back to nil) once pushed, so the
    /// same workout can be opened again later.
    @Binding private var target: Workout?
    /// The empty screen's one command: the Workout tab's Start Lifting.
    private var onStartLifting: () -> Void
    @State private var path: [Workout] = []
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The workout a swipe is proposing to delete.
    @State private var confirmingDelete: Workout?
    /// Milestone 9, ticket 03: the calendar sheet, and the session it chose.
    /// The push happens in the sheet's onDismiss, not in the tap — pushing
    /// while a sheet is still presented lands on the list under the sheet.
    @State private var showCalendar = false
    @State private var calendarPick: Workout?
    /// Each row's derived marks, rebuilt when history changes — not per render: the new-best
    /// counts read every scope's past.
    @State private var facts: [UUID: HistoryWorkoutFacts] = [:]
    /// Scrolled past the large title: the inline "History" takes over in the bar.
    @State private var titleInBar = false

    init(target: Binding<Workout?> = .constant(nil), onStartLifting: @escaping () -> Void = {}) {
        _target = target
        self.onStartLifting = onStartLifting
    }

    private func deleteConfirmedWorkout() {
        defer { confirmingDelete = nil }
        guard let workout = confirmingDelete, !workout.isDeleted else { return }
        modelContext.delete(workout)
        do { try modelContext.save() }
        catch { assertionFailure("Failed to delete workout: \(error)") }
        rebuildFacts()
    }

    /// The app's default weight unit (D2/T7 precedence, app level) — the unit of every row's volume.
    private var appUnit: WeightUnit {
        UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil,
            appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
    }

    /// Changes whenever a row's facts could: a workout added or deleted, or any history edit
    /// (every edit stamps `historyEditedAt`, D47).
    private var historySignature: [String] {
        workouts.map { "\($0.id)|\($0.historyEditedAt?.timeIntervalSince1970 ?? 0)" }
    }

    private func rebuildFacts() {
        let finished = workouts.filter { !$0.isDeleted }
        let entries = (try? SetBadgeMath.finishedEntries(in: modelContext)) ?? []
        facts = HistoryOverviewMath.facts(for: finished, finishedEntries: entries)
    }

    private var allFacts: [HistoryWorkoutFacts] {
        workouts.compactMap { facts[$0.id] }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if workouts.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .lookScreenBackground()
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(look.ground, for: .navigationBar)
            .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .opacity(titleInBar ? 1 : 0)
                        .accessibilityHidden(!titleInBar)
                }
                // Nothing to show on a calendar yet: the button arrives with the first workout
                // (the user's decision, 2026-09-27).
                if !workouts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Calendar", systemImage: "calendar") { showCalendar = true }
                            .tint(look.textPrimary)
                            .accessibilityIdentifier("historyCalendar")
                    }
                }
            }
            .sheet(isPresented: $showCalendar, onDismiss: {
                // Re-validated here, not at the tap, and the C2 target wins
                // if one arrived while the sheet was up (codex-review 03).
                let pick = calendarPick
                calendarPick = nil
                if let destination = WorkoutCalendar.destinationAfterCalendar(
                    pick: pick, otherNavigationPending: target != nil || !path.isEmpty) {
                    path = [destination]
                }
            }) {
                HistoryCalendarSheet(workouts: workouts, facts: facts, appUnit: appUnit) { workout in
                    calendarPick = workout
                    showCalendar = false
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
        // The tab may only be created once the presenter has already asked
        // for a workout, so the arrival is handled on appear as well as on
        // change — otherwise "View in History" would land on the list.
        .onAppear(perform: openTarget)
        .onChange(of: target?.id) { _, _ in openTarget() }
        .onAppear(perform: rebuildFacts)
        .onChange(of: historySignature) { _, _ in rebuildFacts() }
    }

    // MARK: List

    private var list: some View {
        let now = Date.now
        let sections = HistoryOverviewMath.sections(allFacts, now: now)
        let byID = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let thisMonth = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        return List {
            LookNavTitle("History")
                .historyPageRow(top: 2, bottom: 6)
            HistoryMonthCard(
                summary: HistoryOverviewMath.monthSummary(allFacts, month: now),
                days: HistoryOverviewMath.days(inMonthOf: now, facts: allFacts, now: now),
                onOpenCalendar: { showCalendar = true })
                .historyPageRow(top: 16, bottom: 8)
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, month in
                if index > 0 || month.month != thisMonth {
                    HistoryMonthBreak(summary: HistoryOverviewMath.monthSummary(allFacts, month: month.month))
                        .historyPageRow(top: 24, bottom: 0)
                }
                ForEach(month.weeks) { week in
                    HistoryWeekHeader(title: week.title, count: week.workoutIDs.count)
                        .historyPageRow(top: 22, bottom: 10)
                    let rows = week.workoutIDs.compactMap { byID[$0] }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, workout in
                        // The date only on a day's first row; a second workout that day leaves
                        // the column empty.
                        let sameDay = rowIndex > 0
                            && Calendar.current.isDate(rows[rowIndex - 1].startedAt, inSameDayAs: workout.startedAt)
                        row(workout, dateStyle: sameDay ? .continued : .shown)
                            .historyPanelRow(first: rowIndex == 0, last: rowIndex == rows.count - 1,
                                             separatorInset: dynamicTypeSize.isAccessibilitySize ? 16 : 70)
                    }
                }
            }
            Color.clear.frame(height: 24).historyPageRow()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (dynamicTypeSize.isAccessibilitySize ? 70 : 46)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: Binding(
                get: { confirmingDelete != nil },
                set: { if !$0 { confirmingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive) { deleteConfirmedWorkout() }
            Button("Cancel", role: .cancel) { confirmingDelete = nil }
        } message: {
            if let workout = confirmingDelete, !workout.isDeleted {
                let impact = HistoryEditing.impact(ofDeleting: workout)
                let cardio = workout.recordedCardio.isEmpty ? "" : " Recorded cardio and any routes will also be deleted."
                Text("\(impact.sets) set\(impact.sets == 1 ? "" : "s") across \(impact.exercises) exercise\(impact.exercises == 1 ? "" : "s") will be permanently deleted. Records are recalculated without them.\(cardio)")
            }
        }
    }

    private func row(_ workout: Workout, dateStyle: HistoryRowDateStyle) -> some View {
        // A Button rather than a NavigationLink so the row owns its whole width (a List draws a
        // link's chevron outside the label); the push goes through the same path the calendar
        // and the receipt use.
        Button {
            path.append(workout)
        } label: {
            HistoryWorkoutRow(workout: workout, facts: facts[workout.id], appUnit: appUnit, dateStyle: dateStyle)
        }
        .buttonStyle(HistoryRowPressStyle())
        .accessibilityIdentifier("historyWorkoutRow")
        // Swipe to delete, requested 2026-08-26. Still CONFIRMS: this is the only copy of the
        // training history, and a swipe is far easier to do by accident than a menu.
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                confirmingDelete = workout
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(look.destructive)
        }
    }

    // MARK: Empty

    /// Empty is an invitation: the unlit ring, the existing title, and one command.
    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LookNavTitle("History")
                VStack(spacing: 22) {
                    HistoryEmptyMark(size: 132)
                    Text("No workouts yet")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                    StartCapsule(title: "Start Lifting", symbol: "figure.strengthtraining.traditional",
                                 action: onStartLifting)
                        .fixedSize()
                        .padding(.top, 6)
                        .accessibilityIdentifier("historyStartLifting")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 90)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
        }
        .scrollIndicators(.hidden)
    }

    /// C2: opens the requested workout's detail rather than merely selecting
    /// the tab. A deleted workout is dropped — the receipt's link outlives
    /// nothing.
    private func openTarget() {
        guard let workout = target else { return }
        target = nil
        guard !workout.isDeleted, workout.finishedAt != nil else { return }
        path = [workout]
    }
}

/// Rows highlight with the pressed fill (no scale, so lists don't wobble).
struct HistoryRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.pressedFill : Color.clear)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    return HistoryView()
        .modelContainer(container)
}
