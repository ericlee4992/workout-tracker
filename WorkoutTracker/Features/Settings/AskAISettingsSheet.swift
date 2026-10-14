import SwiftUI

/// X02 Ask AI settings (Floodlight ticket 09; public beta ticket 06). AI runs on the developer's server for a
/// signed-in account (D60): no key on the phone. The status card is the bold element — "On" with who is signed in,
/// "Off" with Sign In (the one filled command) when signed out, or "Paused" (the server's off switch). Signed in,
/// today's use against each limit follows (the profile page's tiles). Then one "Send to OpenAI" header over the three
/// permissions — what is sent · the feature that sends it — the policy link, and the line naming the server.
/// Each permission stays independent and revocable, and is still asked for at the point of use. Toggles apply at
/// once, so the only chrome is Done.
struct AskAISettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(AccountStore.self) private var account
    @State private var headerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0
    @State private var signingIn = false
    @AppStorage(TerraAccess.exerciseConsentKey) private var exerciseConsent = false
    @AppStorage(TerraAccess.photoConsentKey) private var photoConsent = false
    @AppStorage(TerraAccess.routineConsentKey) private var routineConsent = false

    private var ready: Bool { TerraAccess.ready(account) }
    private var paused: Bool { ready && account.profile?.aiPaused == true }

    var body: some View {
        VStack(spacing: 0) {
            header
                .exercisesMeasureHeight($headerHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    statusCard
                    if ready, let profile = account.profile, !profile.aiUsage.isEmpty {
                        AIUsageTiles(usage: profile.aiUsage, paused: profile.aiPaused, resetsAt: profile.aiResetsAt,
                                     idPrefix: "askAIUse")
                    }
                    permissions
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .exercisesMeasureContent($bodyHeight)
        }
        .exercisesSheetChrome(fitted: headerHeight + bodyHeight)
        .sheet(isPresented: $signingIn) { AccountSignInSheet() }
        // Today's figures and the off switch, fresh each time the sheet opens.
        .task { await account.refresh() }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text("Ask AI")
                .font(look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Spacer()
                GlassCapsuleButton("Done") { dismiss() }
                    .accessibilityIdentifier("askAIDone")
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: Status (the bold element)

    private var status: String { !ready ? "Off" : paused ? "Paused" : "On" }

    private var statusLine: String {
        if !ready { return AIServerError.signedOut.errorDescription ?? "" }
        if paused { return AIServerError.paused.errorDescription ?? "" }
        return account.profile.map { "Signed in as \($0.displayName)" } ?? AccountDisplayCopy.loading
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                IconDisc(symbol: "sparkles", size: 52, context: ready && !paused ? .onSurface : .make)
                VStack(alignment: .leading, spacing: 3) {
                    Text(status)
                        .font(look.font.bigNumber)
                        .foregroundStyle(ready && !paused ? look.textPrimary : look.textSecondary)
                        .contentTransition(.opacity)
                    Text(statusLine)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ask AI, \(status), \(statusLine)")
            .accessibilityIdentifier("askAIStatus")
            if !ready {
                Button { signingIn = true } label: {
                    Label("Sign In", systemImage: "person.crop.circle")
                }
                .buttonStyle(.lookPrimary)
                .accessibilityIdentifier("askAISignIn")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    // MARK: Permissions

    /// One header says where the data goes; each row names what is sent and the feature that sends
    /// it. VoiceOver (and the UI tests) keep the full "Send … to OpenAI" wording.
    private var permissions: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Send to OpenAI")
            LookList(separatorInset: 54) {
                consentRow("Equipment photos", feature: "Scan Machine", symbol: "camera.viewfinder",
                           label: "Send equipment photos to OpenAI", isOn: $photoConsent)
                consentRow("Routine details", feature: "Ask AI for Templates", symbol: "calendar",
                           label: "Send routine details to OpenAI", isOn: $routineConsent)
                consentRow("Model details", feature: "Suggest exercises with AI", symbol: "tag",
                           label: "Send model details to OpenAI", isOn: $exerciseConsent)
                Link(destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!) {
                    SettingsRow("OpenAI API data policies", symbol: "doc.text", trailingStaysInline: true) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(look.textTertiary)
                    }
                }
                .buttonStyle(.lookPressable)
            }
            SettingsNotice(symbol: "server.rack", text: "Sent through Stacked’s server, which keeps counts, never your photos or text.")
                .padding(.top, 2)
        }
    }

    private func consentRow(_ title: String, feature: String, symbol: String, label: String,
                            isOn: Binding<Bool>) -> some View {
        SettingsRow(title, subtitle: feature, symbol: symbol, trailingStaysInline: true) {
            Toggle(isOn: isOn) { Text(label) }
                .toggleStyle(.settings)
                .fixedSize()
        }
    }
}
