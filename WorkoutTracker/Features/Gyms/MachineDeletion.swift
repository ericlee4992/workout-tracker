import SwiftData
import SwiftUI

/// Deleting a machine (user's word) from a gym — on the Gyms tab and on the
/// mid-workout "Add by Machine" sheet — through one component, so the two
/// screens cannot drift: a trailing swipe action, a context-menu item, and
/// one confirmation dialog. Underneath, D10 still holds: the machine is
/// ARCHIVED, leaves every picker, and history keeps resolving; the gym's
/// "Deleted machines" list restores it.
///
/// No full swipe: a swipe reveals Delete, and the dialog always stands
/// between the tap and the deletion — a machine row sits next to the row the
/// thumb was aiming for.
extension View {
    func machineDeleteActions(_ machine: MachineInstance, ask: @escaping (MachineInstance) -> Void) -> some View {
        self
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    ask(machine)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("deleteMachine.\(machine.label)")
            }
    }

    /// The confirmation, hung off the list once; `pending` is the machine the
    /// user swiped or long-pressed, nil when none. An alert, not a
    /// confirmation dialog: on iOS 26 the dialog rendered as a centred sheet
    /// with the destructive action and NO Cancel (seen in the UI test's
    /// accessibility tree) — an alert always shows both.
    func deleteMachineConfirmation(
        _ pending: Binding<MachineInstance?>, onDelete: @escaping (MachineInstance) -> Void
    ) -> some View {
        alert(
            pending.wrappedValue.map { "Delete \($0.label)?" } ?? "Delete machine?",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }),
            presenting: pending.wrappedValue
        ) { machine in
            Button("Delete Machine", role: .destructive) { onDelete(machine) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It disappears from this gym. Workouts you already logged with it keep it.")
        }
    }
}

/// The gym's deleted machines, each one tap from coming back.
struct DeletedMachinesView: View {
    @Environment(\.modelContext) private var modelContext
    let gym: Gym

    var body: some View {
        List {
            Section {
                ForEach(gym.archivedMachines) { machine in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(machine.label)
                                .font(.body.weight(.medium))
                            Text(machine.model?.displayName ?? "No model")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restore") { restore(machine) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("restoreMachine.\(machine.label)")
                    }
                }
                if gym.archivedMachines.isEmpty {
                    Text("Nothing deleted")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("A restored machine returns to the pickers as it was. Your history never left.")
            }
        }
        .navigationTitle("Deleted Machines")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func restore(_ machine: MachineInstance) {
        do { try EquipmentLifecycle(context: modelContext).restore(machine) }
        catch { assertionFailure("Failed to restore machine: \(error)") }
    }
}
