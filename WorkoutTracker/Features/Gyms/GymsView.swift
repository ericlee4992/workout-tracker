import SwiftData
import SwiftUI

struct GymsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name)
    private var gyms: [Gym]
    @Query private var allPreferences: [AppPreferences]
    @State private var showingAddGym = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(gyms) { gym in
                        NavigationLink(value: gym.id) {
                            GymRow(gym: gym)
                        }
                    }
                    Button("Add Gym…", systemImage: "plus") {
                        showingAddGym = true
                    }
                } footer: {
                    Text("A gym's unit is the default for sets logged there — machines can override it, and so can you on any set.")
                }

                Section {
                    Picker("App unit preference", selection: appUnitBinding) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Settings")
                } footer: {
                    Text("Used when neither the machine nor the gym sets a unit.")
                }
            }
            .navigationTitle("Gyms")
            .navigationDestination(for: UUID.self) { gymID in
                if let gym = gyms.first(where: { $0.id == gymID }) {
                    GymDetailView(gym: gym)
                }
            }
            .sheet(isPresented: $showingAddGym) {
                AddGymSheet()
            }
        }
    }

    /// Binding onto the canonical persisted preference row. The row exists
    /// after first-launch bootstrap; reads fall back to the locale default.
    private var appUnitBinding: Binding<WeightUnit> {
        Binding(
            get: {
                AppPreferences.canonical(of: allPreferences)?.unitPreference
                    ?? UnitPrecedence.firstLaunchDefault(
                        for: Locale.current.measurementSystem)
            },
            set: { newValue in
                do {
                    let preferences = try AppPreferences.canonical(in: modelContext)
                    preferences.unitPreference = newValue
                    preferences.updatedAt = .now
                    try modelContext.save()
                } catch {
                    assertionFailure("Failed to save unit preference: \(error)")
                }
            }
        )
    }
}

private struct GymRow: View {
    var gym: Gym

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(gym.name)
                    .font(.headline)
                if let city = gym.city {
                    Text(city)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let unit = gym.defaultUnit {
                UnitBadge(unit: unit)
            } else {
                Text("app default")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GymDetailView: View {
    var gym: Gym

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Default unit")
                    Spacer()
                    if let unit = gym.defaultUnit {
                        UnitBadge(unit: unit)
                    } else {
                        Text("App preference")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("City")
                    Spacer()
                    Text(gym.city ?? "—").foregroundStyle(.secondary)
                }
            }

            // Machine management lands in ticket 06 — until then the list
            // only reflects the (empty) persisted relationship.
            Section("Machines") {
                ForEach(activeMachines) { machine in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.label)
                            .font(.body.weight(.medium))
                        Text(machine.model?.displayName ?? "Unknown model")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                if activeMachines.isEmpty {
                    Text("No machines yet")
                        .foregroundStyle(.secondary)
                }
                Button("Add Machine…", systemImage: "plus") {}
                    .disabled(true)
            }
        }
        .navigationTitle(gym.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var activeMachines: [MachineInstance] {
        (gym.machines ?? [])
            .filter { !$0.archived }
            .sorted { $0.label < $1.label }
    }
}

private struct AddGymSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var defaultUnit: WeightUnit?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("City (optional)", text: $city)
                }
                Section {
                    Picker("Default unit", selection: $defaultUnit) {
                        Text("App preference").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue).tag(WeightUnit?.some(unit))
                        }
                    }
                } footer: {
                    Text("Leave on App preference to fall through to your app-wide unit.")
                }
            }
            .navigationTitle("New Gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addGym() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addGym() {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(Gym(
            name: trimmedName,
            city: trimmedCity.isEmpty ? nil : trimmedCity,
            defaultUnit: defaultUnit))
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save new gym: \(error)")
        }
        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    container.mainContext.insert(Gym(name: "Gangnam Fitness", city: "Seoul", defaultUnit: .kg))
    container.mainContext.insert(Gym(name: "Hotel Gym"))
    return GymsView()
        .modelContainer(container)
}
