import AuthenticationServices
import SwiftUI

/// Public beta ticket 02 (spec Q8b): the one welcome page on first launch — the name, the tagline, and the choice
/// to take the guided tour. Ticket 03 (the user's choice, 2026-10-13): Sign in with Apple sits under the tour, so the
/// tour stays the one primary command and the app reads as usable without an account (guideline 5.1.1(v)); once
/// signed in, the button gives way to "Signed in as …" and the tour / Skip choice stays. Ticket 04 adds Google here.
struct WelcomeView: View {
    var onTour: () -> Void
    var onSkip: () -> Void
    /// False in a build without a server (and in UI tests without a sample flag): no sign-in on this page.
    var showsSignIn = false
    /// The name once signed in; nil shows Apple's button.
    var signedInName: String? = nil
    var signInFailure: String? = nil
    var signingIn = false
    var onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void = { _ in }
    var onAppleCompletion: (Result<ASAuthorization, any Error>) -> Void = { _ in }
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
            VStack(spacing: 10) {
                PrimaryButton("Show Me Around", action: onTour)
                    .accessibilityIdentifier("welcomeTour")
                if let signedInName {
                    SettingsNotice(symbol: "checkmark", text: "Signed in as \(signedInName).", emphasized: true)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("welcomeSignedIn")
                } else if signingIn {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Signing in…")
                            .font(look.font.body.weight(.semibold))
                            .foregroundStyle(look.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                } else if showsSignIn {
                    AppleSignInButton(onRequest: onAppleRequest, onCompletion: onAppleCompletion)
                    if let signInFailure {
                        Text(signInFailure)
                            .font(look.font.footnote)
                            .foregroundStyle(look.destructive)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("signInFailure")
                    }
                }
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
