import SwiftUI

struct WorkoutDetailView: View {
    var workout: SampleWorkout

    var body: some View {
        List {
            Section {
                HStack {
                    Label(workout.gym?.name ?? "No gym", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text("\(workout.durationMinutes) min")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            ForEach(workout.entries) { entry in
                Section {
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { pair in
                        setLine(index: pair.offset, set: pair.element)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.exercise.name)
                        Text(equipmentSnapshot(for: entry))
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
            } footer: {
                Text("Equipment shown as it was when this workout was logged. Weights display in the unit you entered.")
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func equipmentSnapshot(for entry: WorkoutEntry) -> String {
        if let machine = entry.machine {
            let model = machine.model?.displayName ?? "unknown model"
            return "\(machine.label) · \(model)"
        }
        return entry.freeWeightTag?.label ?? "No equipment"
    }

    private func setLine(index: Int, set: LoggedSet) -> some View {
        HStack(spacing: 10) {
            Text(set.type.marker ?? "\(index + 1)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(set.type == .warmup ? .orange : set.type == .failure ? .red : .primary)
                .frame(width: 24)
            Text("\(set.weightText) \(set.unit.rawValue) × \(set.repsText)")
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: SampleStore().history[0])
    }
}
