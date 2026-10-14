import AuthenticationServices
import SwiftUI

/// Public beta ticket 03 (app half): Apple's own Sign in with Apple button, in the app's capsule shape and the
/// primary command's height. Black on light grounds, white on dark (Apple's HIG: the button must contrast with its
/// background); the label and logo are Apple's.
struct AppleSignInButton: View {
    var onRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onCompletion: (Result<ASAuthorization, any Error>) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56

    var body: some View {
        SignInWithAppleButton(.signIn, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .clipShape(Capsule())
            // Re-created per appearance: the style is read once when the underlying control is made.
            .id(colorScheme)
            .accessibilityIdentifier("signInWithApple")
    }
}

/// Public beta ticket 04: Google's sign-in button without Google's SDK, drawn to Google's published iOS branding — a
/// pill in Google's light (white, #747775 border, #1F1F1F text) or dark (#131314, #8E918F border, #E3E3E3 text) theme
/// with Google's own "G" (from Google's sign-in asset package, unmodified), its wording "Sign in with Google" in Google
/// Sans Medium and its iOS 12-point logo-to-label gap. The same height as Apple's button beside it and below it (Apple's
/// guideline: Sign in with Apple at least as prominent). The one place the app departs from the system font: a
/// provider's brand rule (codex-review-04 Standards #3); the label still scales with Dynamic Type.
struct GoogleSignInButton: View {
    /// Google Sans Medium, subset and renamed under the OFL (Resources/Fonts, Info.plist `UIAppFonts`).
    static let fontName = "StackedSignInLabel-Medium"

    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56
    @ScaledMetric(relativeTo: .headline) private var logo: CGFloat = 20
    @ScaledMetric(relativeTo: .headline) private var gap: CGFloat = 12
    /// Scales with the button, as Apple's label does beside it.
    @ScaledMetric(relativeTo: .headline) private var textSize: CGFloat = 20

    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        Button(action: action) {
            HStack(spacing: gap) {
                Image("GoogleG")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: logo, height: logo)
                    .accessibilityHidden(true)
                Text("Sign in with Google")
                    // Already scaled (`textSize`), so the font itself does not scale again.
                    .font(.custom(Self.fontName, fixedSize: textSize))
                    .foregroundStyle(dark ? Color(red: 0xE3 / 255, green: 0xE3 / 255, blue: 0xE3 / 255)
                                          : Color(red: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(Capsule().fill(dark ? Color(red: 0x13 / 255, green: 0x13 / 255, blue: 0x14 / 255) : .white))
            .overlay(Capsule().strokeBorder(dark ? Color(red: 0x8E / 255, green: 0x91 / 255, blue: 0x8F / 255)
                                                 : Color(red: 0x74 / 255, green: 0x77 / 255, blue: 0x75 / 255), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("Sign in with Google")
        .accessibilityIdentifier("signInWithGoogle")
    }
}

/// Settings → Account, signed out (the user's choice, 2026-10-13: a small sheet rather than Apple's sheet at once —
/// Google's button joins this one in ticket 04). The title, the two facts that make it safe to say yes, and Apple's
/// button in the thumb's reach (the user removed "For AI and a training profile.", 2026-10-13). The sheet only
/// shows, so it offers Close (no staged edits).
struct SignInSheet: View {
    /// One line under the button when the last attempt failed.
    var failure: String?
    /// While the server answers: the button gives way to a progress line, so it cannot be pressed twice.
    var busy = false
    var onRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onCompletion: (Result<ASAuthorization, any Error>) -> Void
    /// Ticket 04: Google's button under Apple's; nil in a build without a Google client ID.
    var onGoogle: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                GlassCapsuleButton("Close") { dismiss() }
                    .accessibilityIdentifier("signInClose")
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign In")
                        .font(look.font.largeTitle)
                        .foregroundStyle(look.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsNotice(symbol: "checkmark", text: "Your workouts stay on this iPhone.", emphasized: true)
                        SettingsNotice(symbol: "checkmark", text: "Delete your account any time.", emphasized: true)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, look.space.margin)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                if busy {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Signing in…")
                            .font(look.font.body.weight(.semibold))
                            .foregroundStyle(look.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .accessibilityIdentifier("signInBusy")
                } else {
                    AppleSignInButton(onRequest: onRequest, onCompletion: onCompletion)
                    if let onGoogle { GoogleSignInButton(action: onGoogle) }
                }
                if let failure {
                    Text(failure)
                        .font(look.font.footnote)
                        .foregroundStyle(look.destructive)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("signInFailure")
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 16)
        }
        .lookSheetGround()
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
    }
}

// MARK: - Delete account

/// The confirmation's words (spec → Accounts: it says the phone's workouts stay) and the follow-up when Apple's
/// token could not be revoked at once or was never kept: the user is told the iOS Settings route (Apple TN3194).
enum AccountDeletionCopy {
    static let title = "Delete your account?"
    static let message = "Your name, email, training profile and feedback are deleted from Stacked's server. "
        + "Your workouts on this iPhone stay."
    static let confirm = "Delete Account"

    static let doneTitle = "Account Deleted"
    static let failed = "Couldn't delete your account. Check your connection and try again."
    static let signedOut = "You've been signed out. Sign in again to delete your account."
    static let stopUsingApple = "One more step: in the Settings app, tap your name, then Sign-In & Security, "
        + "Sign in with Apple, Stacked, and stop using it."
}

/// The sign-in sheet on the app's account store: closes once signed in. Settings' Account row and every AI entry point
/// signed out (ticket 06: AI needs an account) open this one.
struct AccountSignInSheet: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SignInSheet(failure: account.signInFailure ?? ProfileSample.signInFailure, busy: account.signingIn,
                    onRequest: account.prepare,
                    onCompletion: { result in Task { if await account.complete(result) { dismiss() } } },
                    onGoogle: GoogleSignIn.isAvailable ? { Task { if await account.signInWithGoogle() { dismiss() } } } : nil)
            .onAppear {
                account.signInFailure = nil
                if ProfileSample.signsInAtOnce { account.completeSampleSignIn(); dismiss() }
            }
    }
}
