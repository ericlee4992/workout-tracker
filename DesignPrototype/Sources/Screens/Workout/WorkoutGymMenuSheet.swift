import SwiftUI

// PROTOTYPE — W04: the Home gym picker as a compact sheet (it was a system Menu that could not
// add a gym). Gyms by name with city, machine count and unit, a check on the current one,
// "No gym" (no unit: it belongs to no gym), then "Add Gym…". Every gym row reads the same way:
// city · machine count (0 included) and its unit. Choosing a gym moves the check, then the sheet
// closes. `-screen W04 -variant empty`: no gyms saved yet (only No gym and Add Gym…).

struct GymMenuSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @State private var picks = 0
    @State private var contentHeight: CGFloat = 420
    @State private var headerHeight: CGFloat = 74

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Gyms")
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                GlassCapsuleButton("Done") { dismiss() }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

            ScrollView {
                VStack(spacing: 14) {
                    LookList(separatorInset: 54) {
                        ForEach(store.activeGyms) { gym in
                            row(title: gym.name, subtitle: subtitle(gym), symbol: look.gymSymbol,
                                unit: gym.defaultUnit ?? store.displayUnit, selected: store.selectedGymID == gym.id) {
                                pick(gym.id)
                            }
                        }
                        row(title: "No gym", subtitle: nil, symbol: "mappin.slash", unit: nil,
                            selected: store.selectedGymID == nil) {
                            pick(nil)
                        }
                    }
                    WorkoutAddGymRow { router.present(.editGym(gymID: nil)) }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 12)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .lookSheetGround()
        // Compact: exactly as tall as its rows (header + list + Add Gym…), up to full height.
        .presentationDetents([.height(headerHeight + contentHeight + 4), .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: picks)
        .modifier(WorkoutTypeOverride(size: router.dynamicTypeOverride))
        .onAppear {
            if store.currentScreen == .w04, router.variant == "empty" {
                store.gyms = []
                store.selectGym(nil)
            }
        }
    }

    private func subtitle(_ gym: Gym) -> String? {
        let machines = store.activeMachines(gymID: gym.id).count
        return [gym.city, Format.count(machines, "machine")].compactMap { $0 }.joined(separator: " · ")
    }

    private func pick(_ id: UUID?) {
        picks += 1
        withAnimation(.snappy(duration: 0.22)) { store.selectGym(id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
    }

    private func row(title: String, subtitle: String?, symbol: String, unit: WeightUnit?, selected: Bool,
                     action: @escaping () -> Void) -> some View {
        LookRow(title, subtitle: subtitle, symbol: symbol, showsChevron: false, action: action) {
            HStack(spacing: 12) {
                if let unit {
                    Text(unit.label)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(look.textSecondary)
                }
                Image(systemName: "checkmark")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(look.selection)
                    .opacity(selected ? 1 : 0)
                    .scaleEffect(selected ? 1 : 0.4)
            }
        }
        .background { if selected { look.selectionFill.opacity(look.id.isPaperClub ? 1 : 0.6) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
