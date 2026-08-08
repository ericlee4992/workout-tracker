import SwiftUI

struct MachinePickerSheet: View {
    @EnvironmentObject private var store: SampleStore
    @Environment(\.dismiss) private var dismiss
    var entryID: UUID

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.machines(at: store.currentGym)) { machine in
                        Button {
                            select(machine: machine)
                        } label: {
                            machineRow(machine)
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Add Machine…", systemImage: "plus") {}
                } header: {
                    Text("Machines at \(store.currentGym.name)")
                } footer: {
                    Text("History and records attach to the machine you pick — numbers on a different model aren't treated as comparable.")
                }

                Section("Free weights") {
                    ForEach([EquipmentTag.barbell, .dumbbell, .cable, .smith, .bodyweight]) { tag in
                        Button {
                            select(freeWeight: tag)
                        } label: {
                            HStack {
                                Label(tag.rawValue, systemImage: "dumbbell")
                                Spacer()
                                if isSelected(freeWeight: tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func machineRow(_ machine: Machine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.label)
                    .font(.body.weight(.medium))
                Text(machine.model?.displayName ?? "Unknown model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let unit = machine.defaultUnit {
                UnitBadge(unit: unit)
            }
            if isSelected(machine: machine) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }

    private var entryIndex: Int? {
        store.activeWorkout.entries.firstIndex { $0.id == entryID }
    }

    private func isSelected(machine: Machine) -> Bool {
        guard let entryIndex else { return false }
        return store.activeWorkout.entries[entryIndex].machine?.id == machine.id
    }

    private func isSelected(freeWeight tag: EquipmentTag) -> Bool {
        guard let entryIndex else { return false }
        let entry = store.activeWorkout.entries[entryIndex]
        return entry.machine == nil && entry.freeWeightTag == tag
    }

    private func select(machine: Machine) {
        guard let entryIndex else { return }
        store.activeWorkout.entries[entryIndex].machine = machine
        store.activeWorkout.entries[entryIndex].freeWeightTag = nil
        dismiss()
    }

    private func select(freeWeight tag: EquipmentTag) {
        guard let entryIndex else { return }
        store.activeWorkout.entries[entryIndex].machine = nil
        store.activeWorkout.entries[entryIndex].freeWeightTag = tag
        dismiss()
    }
}
