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
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
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
            Text(badge.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.15))
                .foregroundStyle(Color.purple)
                .clipShape(Capsule())
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
