#if DEBUG
import SwiftUI

/// Public beta ticket 02, UI first: a tappable prototype of the three onboarding directions for the user's choice.
/// Opened with the launch argument `-onboardingPrototype` (optionally followed by `A`, `B` or `C`); DEBUG builds only.
/// Removed when the user has chosen and the real first-launch gate is wired.
enum OnboardingPrototype {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-onboardingPrototype") }

    static var initialStyle: OnboardingStyle {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-onboardingPrototype"), flag + 1 < arguments.count,
              let style = OnboardingStyle(rawValue: arguments[flag + 1]) else { return .showcase }
        return style
    }
}

struct OnboardingPrototypeView: View {
    @State private var style = OnboardingPrototype.initialStyle
    @State private var run = 0
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            // The prototype's own control (not part of the design): pick a direction, restart the walkthrough.
            HStack(spacing: 8) {
                Picker("Direction", selection: $style) {
                    ForEach(OnboardingStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("onboardingPrototypeStyle")
                Button("Restart") { run += 1 }
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.yellow.opacity(0.25))
            OnboardingView(style: style, onFinish: { run += 1 })
                .id("\(style.rawValue)-\(run)")
        }
        .background(look.ground.ignoresSafeArea())
    }
}
#endif
