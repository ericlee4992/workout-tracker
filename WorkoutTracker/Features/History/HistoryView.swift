import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: SampleStore
    @State private var path: [SampleWorkout] = []

    private var byMonth: [(month: String, workouts: [SampleWorkout])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var order: [String] = []
        var groups: [String: [SampleWorkout]] = [:]
        for workout in store.history.sorted(by: { $0.date > $1.date }) {
            let key = formatter.string(from: workout.date)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(workout)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack(path: $path) {
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
            .navigationTitle("History")
            .navigationDestination(for: SampleWorkout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .onAppear {
                // Screenshot deep-link (milestone 1 only)
                if ProcessInfo.processInfo.environment["PROTO_SCREEN"] == "detail",
                   let first = store.history.first {
                    path = [first]
                }
            }
        }
    }
}

private struct WorkoutSummaryRow: View {
    var workout: SampleWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.name)
                    .font(.headline)
                Spacer()
                Text(workout.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if let gym = workout.gym {
                    Label(gym.name, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    UnitBadge(unit: gym.defaultUnit)
                }
                Spacer()
                Text("\(workout.entries.count) exercises · \(workout.totalSets) sets · \(workout.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HistoryView()
        .environmentObject(SampleStore())
}
