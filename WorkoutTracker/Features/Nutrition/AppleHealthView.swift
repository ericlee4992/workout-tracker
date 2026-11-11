import SwiftUI

/// Nutrition N9b (D74) — Profile → Goals & tracking → Apple Health: one switch per part, read and saved, each saying
/// what it shares. Turning a part on shows Health's permission sheet for it; a save Health refused says so under its
/// switch. In the default state the screen exists so the user can turn a part on in one tap; the eye lands on the
/// first switch group (Read from Health).
struct AppleHealthView: View {
    @Environment(HealthSync.self) private var health: HealthSync?
    @Environment(\.look) private var look

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Apple Health")
                if let health, health.isAvailable {
                    group("Read from Health", parts: [.readWeight, .readBurned], health: health)
                    group("Save to Health", parts: [.writeWeight, .writeFood], health: health)
                    if let failure = health.failure {
                        SettingsNotice(symbol: "exclamationmark.triangle", text: failure)
                            .accessibilityIdentifier("appleHealthFailure")
                    }
                    Text(AppleHealthCopy.footnote)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    EmptyStateView(symbol: "heart.text.square", title: AppleHealthCopy.unavailableTitle,
                                   message: AppleHealthCopy.unavailableMessage)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, parts: [HealthPart], health: HealthSync) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(title)
            LookList(separatorInset: 16) {
                ForEach(parts) { part in
                    LookToggleRow(AppleHealthCopy.title(part), subtitle: AppleHealthCopy.subtitle(part),
                                  isOn: Binding(get: { health.isOn(part) },
                                                set: { on in Task { await health.set(part, on: on) } }))
                        .disabled(health.requesting != nil)
                        .accessibilityIdentifier("appleHealth.\(part.rawValue)")
                }
            }
            ForEach(parts.filter(health.isRefused)) { part in
                SettingsNotice(symbol: "exclamationmark.triangle", text: AppleHealthCopy.refused(part))
                    .accessibilityIdentifier("appleHealthRefused.\(part.rawValue)")
            }
        }
    }
}

/// The page's words (N9b's new strings, listed in its ticket).
enum AppleHealthCopy {
    static let footnote = "Stacked doesn’t upload your Health data. Turning a switch off stops new changes; what’s already in Health stays there."
    static let unavailableTitle = "Health isn’t available"
    static let unavailableMessage = "This device doesn’t have Apple Health."

    static func title(_ part: HealthPart) -> String {
        switch part {
        case .readWeight, .writeWeight: "Body weight"
        case .readBurned: "Calories burned"
        case .writeFood: "Food"
        }
    }

    static func subtitle(_ part: HealthPart) -> String {
        switch part {
        case .readWeight: "Shown with the weights you log"
        case .readBurned: "Active energy, shown as Burned on Today"
        case .writeWeight: "Each weight you log"
        case .writeFood: "Calories, protein, carbs and fat of each entry"
        }
    }

    static func refused(_ part: HealthPart) -> String {
        let what = part == .writeFood ? "saving all of your food’s numbers" : "saving body weight"
        return "Health hasn’t allowed \(what). Allow it in the Health app: Profile → Apps → Stacked."
    }

    /// The Profile row's value.
    @MainActor static func status(_ health: HealthSync?) -> String { health?.anyOn == true ? "On" : "Off" }
}
