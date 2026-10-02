import SwiftUI

/// Public beta ticket 02 (spec Q8b): the one welcome page on first launch — the name, the tagline, and the choice
/// to take the guided tour. Tickets 03/04 add the sign-in buttons here.
struct WelcomeView: View {
    var onTour: () -> Void
    var onSkip: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        OnboardingIllustration(kind: .welcome)
                        Text("Stacked")
                            .font(look.font.largeTitle)
                            .foregroundStyle(look.textPrimary)
                            .padding(.top, 12)
                            .accessibilityAddTraits(.isHeader)
                        Text("Know your numbers. Every machine. Every gym.")
                            .font(look.font.title3)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, look.space.margin)
                    .frame(minHeight: viewport.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            VStack(spacing: 4) {
                PrimaryButton("Show Me Around", action: onTour)
                    .accessibilityIdentifier("welcomeTour")
                Button(action: onSkip) {
                    Text("Skip")
                        .font(look.font.body.weight(.semibold))
                        .foregroundStyle(look.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("welcomeSkip")
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 8)
        }
        .background(look.ground.ignoresSafeArea())
    }
}
