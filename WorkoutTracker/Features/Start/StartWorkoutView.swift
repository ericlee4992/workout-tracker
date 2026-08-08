import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @EnvironmentObject private var store: SampleStore
    // Persisted gyms (ticket 05). The rest of the workout flow stays on
    // SampleStore until ticket 07 rewires it onto SwiftData.
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name)
    private var savedGyms: [Gym]
    @Query private var allPreferences: [AppPreferences]
    @State private var selectedSavedGym: Gym?
    var startWorkout: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    gymPicker
                } footer: {
                    Text("Sets default to \(currentUnit.rawValue) here. You can switch units on any set.")
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

    /// Gym-level unit for the currently picked gym, falling through to the
    /// app preference when the gym doesn't set one (T7; no machine context here).
    private var currentUnit: WeightUnit {
        if let selectedSavedGym {
            return UnitPrecedence.defaultUnit(
                machineUnit: nil,
                gymUnit: selectedSavedGym.defaultUnit,
                appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
        }
        return store.currentGym.defaultUnit
    }

    private var currentGymName: String {
        selectedSavedGym?.name ?? store.currentGym.name
    }

    private var gymPicker: some View {
        Menu {
            ForEach(savedGyms) { gym in
                Button {
                    selectedSavedGym = gym
                } label: {
                    let title = gym.city.map { "\(gym.name) · \($0)" } ?? gym.name
                    if gym.id == selectedSavedGym?.id {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
            ForEach(store.gyms) { gym in
                Button {
                    selectedSavedGym = nil
                    store.currentGym = gym
                } label: {
                    if selectedSavedGym == nil, gym.id == store.currentGym.id {
                        Label("\(gym.name) · \(gym.city)", systemImage: "checkmark")
                    } else {
                        Text("\(gym.name) · \(gym.city)")
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentGymName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(selectedSavedGym.map { $0.city ?? "" } ?? store.currentGym.city)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UnitBadge(unit: currentUnit)
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
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    return StartWorkoutView(startWorkout: {})
        .environmentObject(SampleStore())
        .modelContainer(container)
}
