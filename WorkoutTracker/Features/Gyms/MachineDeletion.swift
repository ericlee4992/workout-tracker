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

/// The context-menu item, the same on both screens (codex-review-01).
struct DeleteMachineMenuItem: View {
    let machine: MachineInstance
    let ask: (MachineInstance) -> Void

    var body: some View {
        Button("Delete Machine…", role: .destructive) { ask(machine) }
    }
}

/// The gym's deleted machines, each one tap from coming back (Floodlight redesign ticket 06, G07):
/// the glyph, label and model, and how many workouts it still carries; Restore brings it back
/// with a check, a success tap, and the row folding away.
struct DeletedMachinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let gym: Gym
    @State private var restoring: Set<UUID> = []
    @State private var restoredTick = 0
    @State private var titleInBar = false
    @State private var use: [UUID: MachineUse] = [:]

    var body: some View {
        let machines = gym.archivedMachines
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section - 4) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deleted Machines")
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(gym.name)
                        .font(.subheadline)
                        .foregroundStyle(look.textSecondary)
                }
                if machines.isEmpty {
                    // UI redesign ticket 09: the illustration; same string.
                    EmptyStateView(symbol: "trash", title: "Nothing deleted")
                        .padding(.top, 60)
                        .transition(.opacity)
                } else {
                    LookList(separatorInset: 68) {
                        ForEach(machines) { machine in
                            DeletedMachineRow(machine: machine, workouts: use[machine.id]?.workouts ?? 0,
                                              restoring: restoring.contains(machine.id)) { restore(machine) }
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .lookScreenBackground()
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > 40
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .gymsInlineTitle("Deleted Machines", visible: titleInBar)
        .sensoryFeedback(.success, trigger: restoredTick)
        .onAppear {
            let entries = (try? SetBadgeMath.finishedEntries(in: modelContext)) ?? []
            use = GymOverviewMath.machineUse(GymOverviewMath.machineSetInputs(finishedEntries: entries))
        }
    }

    private func restore(_ machine: MachineInstance) {
        guard !restoring.contains(machine.id) else { return }
        restoredTick += 1
        if reduceMotion { commit(machine); return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = restoring.insert(machine.id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                commit(machine)
                restoring.remove(machine.id)
            }
        }
    }

    private func commit(_ machine: MachineInstance) {
        do { try EquipmentLifecycle(context: modelContext).restore(machine) }
        catch { assertionFailure("Failed to restore machine: \(error)") }
    }
}

private struct DeletedMachineRow: View {
    var machine: MachineInstance
    var workouts: Int
    var restoring: Bool
    var restore: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            HStack(alignment: .center, spacing: 12) {
                EquipmentTile(category: machine.model?.equipmentType, size: 40, dimmed: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.label)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                    Text(machine.model?.modelName ?? "No model")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // The history it still carries (the app does not record when it was deleted).
                    if workouts > 0 {
                        Text("\(workouts) workout\(workouts == 1 ? "" : "s")")
                            .font(look.font.caption)
                            .foregroundStyle(look.textSecondary)
                    }
                }
            }
            if !ax { Spacer(minLength: 8) }
            Button(action: restore) {
                ZStack {
                    Text("Restore").opacity(restoring ? 0 : 1)
                    Image(systemName: "checkmark")
                        .font(.system(.subheadline, weight: .heavy))
                        .opacity(restoring ? 1 : 0)
                        .scaleEffect(restoring ? 1 : 0.4)
                }
            }
            .buttonStyle(QuietPillStyle())
            .disabled(restoring)
            .accessibilityLabel("Restore \(machine.label)")
            .accessibilityIdentifier("restoreMachine.\(machine.label)")
            .padding(.leading, ax ? 52 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
    }
}
