import SwiftData
import SwiftUI

struct HistoryView: View {
    /// Only finished workouts are history; the active one (finishedAt nil)
    /// never appears here.
    @Query(
        filter: #Predicate<Workout> { $0.finishedAt != nil },
        sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    /// C2: a workout the presenter wants opened — "View in History" on the
    /// post-finish receipt. Consumed (set back to nil) once pushed, so the
    /// same workout can be opened again later.
    @Binding private var target: Workout?
    @State private var path: [Workout] = []
    @Environment(\.modelContext) private var modelContext
    /// The workout a swipe is proposing to delete.
    @State private var confirmingDelete: Workout?
    /// Milestone 9, ticket 03: the calendar sheet, and the session it chose.
    /// The push happens in the sheet's onDismiss, not in the tap — pushing
    /// while a sheet is still presented lands on the list under the sheet.
    @State private var showCalendar = false
    @State private var calendarPick: Workout?

    private func deleteConfirmedWorkout() {
        defer { confirmingDelete = nil }
        guard let workout = confirmingDelete, !workout.isDeleted else { return }
        modelContext.delete(workout)
        do { try modelContext.save() }
        catch { assertionFailure("Failed to delete workout: \(error)") }
    }

    init(target: Binding<Workout?> = .constant(nil)) {
        _target = target
    }

    private var byMonth: [(month: String, workouts: [Workout])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var order: [String] = []
        var groups: [String: [Workout]] = [:]
        for workout in workouts {
            let key = formatter.string(from: workout.startedAt)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(workout)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if workouts.isEmpty {
                    // UI redesign ticket 06: the symbol illustration; the two
                    // strings are the ones this screen always had.
                    VStack(spacing: 0) {
                        EmptyState(title: "No workouts yet", symbol: "clock.arrow.circlepath")
                        Text("Finished workouts show up here.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                } else {
                    List {
                        ForEach(byMonth, id: \.month) { group in
                            Section {
                                ForEach(group.workouts) { workout in
                                    // A Button rather than a NavigationLink so
                                    // the card owns its whole row (a List draws
                                    // a link's chevron outside the label);
                                    // the push goes through the same path the
                                    // calendar and the receipt use.
                                    Button {
                                        path.append(workout)
                                    } label: {
                                        WorkoutSummaryRow(workout: workout)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("historyWorkoutRow")
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                    // Swipe to delete, requested 2026-08-26.
                                    // Still CONFIRMS: this is the only copy of
                                    // the training history, and a swipe is far
                                    // easier to do by accident than a menu.
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            confirmingDelete = workout
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(Theme.danger)
                                    }
                                }
                            } header: {
                                Text(group.month)
                                    .font(Theme.label)
                                    .foregroundStyle(Theme.secondary)
                                    .textCase(.uppercase)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Calendar", systemImage: "calendar") { showCalendar = true }
                        .accessibilityIdentifier("historyCalendar")
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
                HistoryCalendarSheet(
                    // `workouts` is already the finished-only query.
                    calendar: WorkoutCalendar(startedAt: workouts.map(\.startedAt))
                ) { day in
                    calendarPick = WorkoutCalendar.workoutToOpen(on: day, among: workouts)
                    showCalendar = false
                }
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
                    Text("\(impact.sets) set\(impact.sets == 1 ? "" : "s") across \(impact.exercises) exercise\(impact.exercises == 1 ? "" : "s") will be permanently deleted. Records are recalculated without them.")
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

/// E1–E4 (ticket 17): titled by what was actually done, with the gym demoted
/// to a subtitle and the unit badge sitting inline with the stats it
/// qualifies — so every row has the same left edge whether or not it has one.
/// UI redesign ticket 06: a card led by the day (the month is the section
/// header), the same strings as before.
private struct WorkoutSummaryRow: View {
    var workout: Workout

    var body: some View {
        let completedSets = workout.completedSets
        HStack(spacing: Theme.Space.medium) {
            VStack(spacing: 0) {
                Text(workout.startedAt, format: .dateTime.day())
                    .font(Theme.stat)
                    .monospacedDigit()
                Text(workout.startedAt, format: .dateTime.weekday(.abbreviated))
                    .font(Theme.label)
                    .foregroundStyle(Theme.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 52, height: 56)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.inner))
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.historyTitle)
                    .font(Theme.cardTitle)
                    .lineLimit(1)
                Label(workout.historyGymName ?? "No gym", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
                HStack(spacing: 6) {
                    Text(HistoryRendering.statsLine(
                        exerciseCount: workout.entries?.count ?? 0,
                        setCount: completedSets.count,
                        duration: workout.duration))
                        .font(.caption)
                        .foregroundStyle(Theme.tertiary)
                    // Derived from the actual logged sets — never just the gym
                    // default (SPEC "Units").
                    if let badge = WorkoutUnitBadge.derive(fromCompleted: completedSets) {
                        WorkoutUnitBadgeView(badge: badge)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tertiary)
        }
        .padding(Theme.Space.inset)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// kg/lb reuse the standard unit badge; Mixed gets its own tint.
struct WorkoutUnitBadgeView: View {
    var badge: WorkoutUnitBadge

    var body: some View {
        switch badge {
        case .single(let unit):
            UnitBadge(unit: unit)
        case .mixed:
            Chip(tint: Theme.unitMixed) { Text(badge.label) }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    return HistoryView()
        .modelContainer(container)
}
