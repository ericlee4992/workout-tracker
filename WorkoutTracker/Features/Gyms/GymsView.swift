import SwiftUI

struct GymsView: View {
    @EnvironmentObject private var store: SampleStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.gyms) { gym in
                        NavigationLink(value: gym) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(gym.name)
                                        .font(.headline)
                                    Text("\(gym.city) · \(store.machines(at: gym).count) machines")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                UnitBadge(unit: gym.defaultUnit)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } footer: {
                    Text("A gym's unit is the default for sets logged there — machines can override it, and so can you on any set.")
                }

                Section {
                    Button("Add Gym…", systemImage: "plus") {}
                }
            }
            .navigationTitle("Gyms")
            .navigationDestination(for: SampleGym.self) { gym in
                GymDetailView(gym: gym)
            }
        }
    }
}

struct GymDetailView: View {
    @EnvironmentObject private var store: SampleStore
    var gym: SampleGym

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Default unit")
                    Spacer()
                    UnitBadge(unit: gym.defaultUnit)
                }
                HStack {
                    Text("City")
                    Spacer()
                    Text(gym.city).foregroundStyle(.secondary)
                }
            }

            Section("Machines") {
                ForEach(store.machines(at: gym)) { machine in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.label)
                            .font(.body.weight(.medium))
                        Text(machine.model?.displayName ?? "Unknown model")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                Button("Add Machine…", systemImage: "plus") {}
            }
        }
        .navigationTitle(gym.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    GymsView()
        .environmentObject(SampleStore())
}
