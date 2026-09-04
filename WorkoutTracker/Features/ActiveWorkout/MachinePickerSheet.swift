import SwiftData
import SwiftUI

struct MachinePickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var entry: ExerciseEntry
    @State private var showingAddMachine = false

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    private var gym: Gym? { entry.workout?.gym }

    private var machines: [MachineInstance] { gym?.activeMachines ?? [] }

    /// After one completed set the entry's equipment is frozen (D19) —
    /// picking different equipment starts a new entry.
    private var isFrozen: Bool { entry.snapshotCapturedAt != nil }

    var body: some View {
        NavigationStack {
            List {
                if let gym {
                    Section {
                        ForEach(machines) { machine in
                            Button {
                                select(machine: machine)
                            } label: {
                                machineRow(machine)
                            }
                            .buttonStyle(.plain)
                        }
                        if machines.isEmpty {
                            Text("No machines yet")
                                .foregroundStyle(.secondary)
                        }
                        Button("Add Machine…", systemImage: "plus") {
                            showingAddMachine = true
                        }
                    } header: {
                        Text("Machines at \(gym.name)")
                    } footer: {
                        Text("History and records attach to the machine you pick — numbers on a different model aren't treated as comparable.")
                    }
                }

                Section {
                    ForEach([EquipmentTag.barbell, .dumbbell, .cable, .smith, .bodyweight]) { tag in
                        if tag == .dumbbell, let pair = counterpartPair {
                            // Milestone 9, ticket 04 / D51: this movement has a
                            // dumbbell exercise of its own. Offering the tag
                            // here is how the split re-grows, so offer the
                            // exercise instead — and NEVER fall back to the
                            // tag, even if the row is momentarily missing
                            // (codex-review 04): the row is disabled and named
                            // from the mapping until the seeder heals the store.
                            let row = counterpartRow
                            Button {
                                switchToCounterpart()
                            } label: {
                                HStack {
                                    Label("Log as \(row?.name ?? pair.targetName) instead", systemImage: "dumbbell")
                                    Spacer()
                                    Image(systemName: row == nil ? "exclamationmark.triangle" : "arrow.turn.down.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(row == nil)
                            .accessibilityIdentifier("logAsCounterpart")
                        } else {
                            Button {
                                select(freeWeight: tag)
                            } label: {
                                HStack {
                                    Label(tag.label, systemImage: "dumbbell")
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
                } header: {
                    Text("Free weights")
                } footer: {
                    if isFrozen {
                        Text("This exercise already has a completed set, so its equipment is locked in — picking something else continues in a new entry.")
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
            .sheet(isPresented: $showingAddMachine) {
                if let gym {
                    MachineEditorSheet(gym: gym)
                }
            }
        }
    }

    private func machineRow(_ machine: MachineInstance) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.label)
                    .font(.body.weight(.medium))
                Text(machine.model?.displayName ?? "No model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let unit = machine.defaultUnit {
                UnitBadge(unit: unit)
            }
            if entry.machine?.id == machine.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }

    private func isSelected(freeWeight tag: EquipmentTag) -> Bool {
        entry.machine == nil && entry.freeWeightTag == tag
    }

    /// The mapping entry for this movement, if it has a dumbbell counterpart.
    private var counterpartPair: DumbbellCounterparts.Pair? {
        guard !entry.isDeleted, let sourceID = entry.exercise?.id else { return nil }
        return DumbbellCounterparts.pair(forSource: sourceID)
    }

    /// The counterpart's row in the store — nil only for a partial store the
    /// next launch's seeder heals.
    private var counterpartRow: Exercise? {
        guard let targetID = counterpartPair?.target else { return nil }
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == targetID })
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func switchToCounterpart() {
        do {
            guard try session.switchToDumbbellCounterpart(of: entry) != nil else { return }
        } catch {
            assertionFailure("Failed to switch exercise: \(error)")
        }
        dismiss()
    }

    /// Equipment choice boundary: the service edits the draft entry in place,
    /// or — once frozen (D19) — starts a new entry and moves the draft rows.
    private func select(machine: MachineInstance) {
        choose(machine: machine, tag: nil)
    }

    private func select(freeWeight tag: EquipmentTag) {
        choose(machine: nil, tag: tag)
    }

    private func choose(machine: MachineInstance?, tag: EquipmentTag?) {
        do {
            try session.chooseEquipment(for: entry, machine: machine, freeWeightTag: tag)
        } catch {
            assertionFailure("Failed to choose equipment: \(error)")
        }
        dismiss()
    }
}
