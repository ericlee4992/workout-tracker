import SwiftData
import SwiftUI

struct HistoryView: View {
    /// Only finished workouts are history; the active one (finishedAt nil)
    /// never appears here.
    @Query(
        filter: #Predicate<Workout> { $0.finishedAt != nil },
        sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var path: [Workout] = []

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
    }
}

private struct WorkoutSummaryRow: View {
    var workout: Workout

    var body: some View {
        let completedSets = workout.completedSets
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(workout.gym?.name ?? "No gym", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                Spacer()
                Text(workout.startedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                // Derived from the actual logged sets — never just the gym
                // default (SPEC "Units").
                if let badge = WorkoutUnitBadge.derive(fromCompleted: completedSets) {
                    WorkoutUnitBadgeView(badge: badge)
                }
                Spacer()
                Text("\(workout.entries?.count ?? 0) exercises · \(completedSets.count) sets · \(workout.durationMinutes ?? 0) min")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
