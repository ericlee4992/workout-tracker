import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .frame(minHeight: 52)
            .padding(.horizontal, 16)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.inner))
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .foregroundStyle(Theme.text)
            .background(Theme.fill.opacity(configuration.isPressed ? 0.65 : 1),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.inner))
            .opacity(isEnabled ? 1 : 0.35)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: Self { .init() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: Self { .init() }
}
