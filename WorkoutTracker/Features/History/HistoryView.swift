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
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished workouts show up here."))
                } else {
                    List {
                        ForEach(byMonth, id: \.month) { group in
                            Section(group.month) {
                                ForEach(group.workouts) { workout in
                                    NavigationLink(value: workout) {
                                        WorkoutSummaryRow(workout: workout)
                                    }
                                    .accessibilityIdentifier("historyWorkoutRow")
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
                                    }
                                }
                            }
                        }
                    }
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
private struct WorkoutSummaryRow: View {
    var workout: Workout

    var body: some View {
        let completedSets = workout.completedSets
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.historyTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(workout.startedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Label(workout.historyGymName ?? "No gym", systemImage: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(HistoryRendering.statsLine(
                    exerciseCount: workout.entries?.count ?? 0,
                    setCount: completedSets.count,
                    duration: workout.duration))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                // Derived from the actual logged sets — never just the gym
                // default (SPEC "Units").
                if let badge = WorkoutUnitBadge.derive(fromCompleted: completedSets) {
                    WorkoutUnitBadgeView(badge: badge)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 2)
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
