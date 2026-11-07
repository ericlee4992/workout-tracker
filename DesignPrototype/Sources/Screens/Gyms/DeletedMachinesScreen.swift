import SwiftUI

// G07 Deleted Machines. Each deleted machine keeps its glyph, label, model and the day it
// was deleted; Restore brings it back with a check, a success tap, and the row folding away.
// Newest deletion first. "Nothing deleted" when the gym has none (variant "empty" opens
// Gangnam Fitness). The default capture state (and "history") adds a deletion that still
// carries its workouts: the Pec Deck, deleted today. "restoring" holds the first row's check.

struct DeletedMachinesScreen: View {
    let gymID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var restoring: Set<UUID> = []
    @State private var restoredTick = 0
    @State private var titleVisible = false
    @State private var appeared = false

    var body: some View {
        let machines = store.deletedMachines(gymID: gymID)
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section - 4) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deleted Machines")
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let gym = store.gym(gymID) {
                        Text(gym.name)
                            .font(.system(.subheadline, weight: look.id == .floodlight ? .regular : .semibold))
                            .foregroundStyle(look.textSecondary)
                    }
                }
                if machines.isEmpty {
                    EmptyStateView(symbol: "trash", title: "Nothing deleted")
                        .padding(.top, 60)
                        .transition(.opacity)
                } else {
                    LookList(separatorInset: 68) {
                        ForEach(machines) { machine in
                            GymsDeletedRow(machine: machine, restoring: restoring.contains(machine.id)) { restore(machine) }
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .gymsScrolledPast(40, into: $titleVisible)
        .lookScreenBackground()
        .gymsInlineTitle("Deleted Machines", visible: titleVisible)
        .sensoryFeedback(.success, trigger: restoredTick)
        .onAppear(perform: appear)
    }

    private func appear() {
        guard !appeared else { return }
        appeared = true
        guard gymID == store.screenTarget.gymID, store.currentScreen == .g07 else { return }
        switch router.variant {
        case nil, "history", "restoring":
            let restoringFirst = router.variant == "restoring"
            router.variant = "gyms-applied"
            store.deleteMachine(GymsCapture.machine("Pec Deck"))
            // Hold the check on the newest row (the fold follows a real tap).
            if restoringFirst { restoring.insert(GymsCapture.machine("Pec Deck")) }
        default: break
        }
    }

    private func restore(_ machine: Machine) {
        guard !restoring.contains(machine.id) else { return }
        restoredTick += 1
        if reduceMotion {
            store.restoreMachine(machine.id)
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = restoring.insert(machine.id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                store.restoreMachine(machine.id)
                restoring.remove(machine.id)
            }
        }
    }
}

private struct GymsDeletedRow: View {
    var machine: Machine
    var restoring: Bool
    var restore: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            HStack(alignment: .center, spacing: 12) {
                GymsEquipmentDisc(category: store.gymsCategory(of: machine), size: 40)
                    .opacity(0.72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.label)
                        .font(.system(.body, weight: look.id == .anatomy ? .bold : .semibold))
                        .foregroundStyle(look.textPrimary)
                    Text(store.model(machine.modelID)?.modelName ?? "No model")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let line = detailLine {
                        Text(line)
                            .font(look.font.caption)
                            .foregroundStyle(look.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Button(action: restore) {
                ZStack {
                    Text("Restore").opacity(restoring ? 0 : 1)
                    Image(systemName: "checkmark")
                        .font(.system(.subheadline, weight: .heavy))
                        .opacity(restoring ? 1 : 0)
                        .scaleEffect(restoring ? 1 : 0.4)
                }
            }
            .buttonStyle(GymsQuietPillStyle())
            .disabled(restoring)
            .accessibilityLabel("Restore \(machine.label)")
            .padding(.leading, typeSize.isAccessibilitySize ? 52 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
    }

    /// "Deleted Sep 2 · 4 workouts": when it went, and the history it still carries.
    private var detailLine: String? {
        let used = store.machineStats(machine.id).timesUsed
        let parts = [machine.deletedAt.map { GymsDate.deleted($0, now: store.now) },
                     used > 0 ? Format.count(used, "workout") : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
