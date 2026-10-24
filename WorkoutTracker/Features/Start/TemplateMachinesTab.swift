import SwiftData
import SwiftUI

/// Public beta ticket 23 (the user, 2026-10-23: "When adding new template on my own, i can't add new machine or scan
/// machine"): the template editor's Machines tab. The machines at a gym — the Workout tab's selected gym first, a menu
/// to switch (the switch stays in this sheet) — then Add Machine… (its form has Scan equipment…). Picking a
/// one-exercise machine adds its exercise; a station asks which (D7). The editor remembers the machine for that
/// exercise at that gym when the template is saved (D66). Stays open for more, like the Exercises tab.
struct TemplateMachinesTab: View {
    var onPick: (UUID, MachineInstance) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Query(sort: \Gym.name) private var allGyms: [Gym]
    @Query private var allPreferences: [AppPreferences]
    @State private var gymID: UUID?
    @State private var chooser: AddByMachineSheet.ExerciseChoice?
    @State private var addingMachine = false
    @State private var picked: Set<UUID> = []

    private var gyms: [Gym] { allGyms.filter { !$0.archived } }
    private var gym: Gym? { gyms.first { $0.id == gymID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if gyms.isEmpty {
                EmptyStateView(symbol: "building.2", title: "No gyms yet")
                Text("Add a gym in Gyms to choose its machines here.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("templateMachinesNoGym")
            } else if let gym {
                gymMenu(gym)
                let machines = gym.activeMachines
                if machines.isEmpty {
                    EmptyStateView(symbol: "dumbbell", title: "No machines yet")
                } else {
                    LookList(header: "Machines at \(gym.name)") {
                        ForEach(machines) { machine in row(machine) }
                    }
                }
                Button("Add Machine…", systemImage: "plus") { addingMachine = true }
                    .buttonStyle(.lookSecondary)
                    .accessibilityIdentifier("templateAddMachine")
            }
        }
        .onAppear(perform: chooseInitialGym)
        .navigationDestination(item: $chooser) { choice in
            MachineExerciseList(choice: choice) { exercise in
                pick(exercise.id, choice.machine)
                chooser = nil
            }
        }
        .sheet(isPresented: $addingMachine) {
            if let gym { MachineEditorSheet(gym: gym) }
        }
    }

    /// The Workout tab's gym (D1 of milestone 2 ticket 17) when it has one, else the first gym.
    private func chooseInitialGym() {
        guard gymID == nil else { return }
        let selected = GymSelection.resolve(id: AppPreferences.canonical(of: allPreferences)?.selectedGymID, among: gyms)
        gymID = (selected ?? gyms.first)?.id
    }

    private func gymMenu(_ gym: Gym) -> some View {
        Menu {
            Picker("Gym", selection: Binding(get: { gymID }, set: { gymID = $0 })) {
                ForEach(gyms) { Text($0.name).tag(Optional($0.id)) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: look.gymSymbol)
                Text(gym.name).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .lookSurface(.panel)
        }
        .accessibilityLabel("Gym, \(gym.name)")
        .accessibilityIdentifier("templateMachinesGym")
    }

    private func row(_ machine: MachineInstance) -> some View {
        LookRow(machine.label, subtitle: machine.model?.displayName ?? "No model", symbol: LookIcon.machine,
                showsChevron: false, action: { select(machine) }) {
            Image(systemName: picked.contains(machine.id) ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(picked.contains(machine.id) ? look.done : look.textSecondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(machine.label)
        .accessibilityValue(picked.contains(machine.id) ? "Added" : "")
        .accessibilityIdentifier("machineOption.\(machine.label)")
    }

    /// D7, as in the live workout: one linked exercise → added; several → which one; none → the full catalog.
    private func select(_ machine: MachineInstance) {
        let linked = (try? WorkoutSession(context: modelContext).exercisesFor(machine: machine)) ?? []
        if linked.count == 1 {
            pick(linked[0].id, machine)
        } else {
            chooser = AddByMachineSheet.ExerciseChoice(machine: machine, linked: linked.isEmpty ? nil : linked)
        }
    }

    private func pick(_ exerciseID: UUID, _ machine: MachineInstance) {
        picked.insert(machine.id)
        onPick(exerciseID, machine)
    }
}
