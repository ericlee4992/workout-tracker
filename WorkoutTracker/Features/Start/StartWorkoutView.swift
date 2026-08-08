import SwiftUI

struct StartWorkoutView: View {
    @EnvironmentObject private var store: SampleStore
    var startWorkout: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    gymPicker
                } footer: {
                    Text("Sets default to \(store.currentGym.defaultUnit.rawValue) here. You can switch units on any set.")
                }

                Section {
                    Button(action: startWorkout) {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }

                Section("Templates") {
                    ForEach(store.templates) { template in
                        TemplateRow(template: template, start: startWorkout)
                    }
                }
            }
            .navigationTitle("Workout")
        }
    }

    private var gymPicker: some View {
        Menu {
            ForEach(store.gyms) { gym in
                Button {
                    store.currentGym = gym
                } label: {
                    if gym.id == store.currentGym.id {
                        Label("\(gym.name) · \(gym.city)", systemImage: "checkmark")
                    } else {
                        Text("\(gym.name) · \(gym.city)")
                    }
                }
            }
            Button("Add Gym…", systemImage: "plus") {}
        } label: {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.currentGym.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(store.currentGym.city)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UnitBadge(unit: store.currentGym.defaultUnit)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TemplateRow: View {
    @EnvironmentObject private var store: SampleStore
    var template: SampleWorkoutTemplate
    var start: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                Text(template.exerciseNames.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Machines resolve to your last-used at \(store.currentGym.name)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Start", action: start)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

struct UnitBadge: View {
    var unit: WeightUnit

    var body: some View {
        Text(unit.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(unit == .kg ? Color.blue.opacity(0.15) : Color.orange.opacity(0.18))
            .foregroundStyle(unit == .kg ? Color.blue : Color.orange)
            .clipShape(Capsule())
    }
}

#Preview {
    StartWorkoutView(startWorkout: {})
        .environmentObject(SampleStore())
}
