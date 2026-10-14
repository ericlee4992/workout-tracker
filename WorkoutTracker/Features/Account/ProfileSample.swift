import SwiftUI

/// Public beta ticket 05, UI-first stage: the profile page and editor on sample data, reachable only under
/// `-uiTestReset` with a sample flag (no sign-in exists in the app before 03's app half).
///
/// - `-uiTestProfileSample`: signed in with a training profile.
/// - `-uiTestProfileNoTraining`: signed in, no training profile yet.
/// - `-uiTestProfileSignedOut`: the Settings row signed out ("Sign In"); tapping it opens the sign-in sheet (ticket 03).
/// - `-uiTestSignInFailed`: the sign-in sheet shows its failure line (ticket 03's mock).
/// - `-uiTestWelcomeSignedIn`: the welcome page after signing in there (ticket 03's mock).
/// - `-uiTestAccountUnavailable`: signed in, but the profile could not be loaded (offline at launch).
/// Ask AI for Templates is filled in from the sample's training profile whenever it is signed in (ticket 05).
enum ProfileSample {
    private static func flag(_ name: String) -> Bool {
        WorkoutTrackerStore.isUITestReset && ProcessInfo.processInfo.arguments.contains(name)
    }

    static var showsAccountRow: Bool { signedIn || unavailable || flag("-uiTestProfileSignedOut") }
    static var unavailable: Bool { flag("-uiTestAccountUnavailable") }
    /// `-uiTestSampleSignIn`: the sign-in sheet signs the sample store in at once (ticket 06's recovery test).
    static var signsInAtOnce: Bool { flag("-uiTestSampleSignIn") }
    /// `-uiTestProfileSaveFails`: the sample's training-profile saves fail (Ask AI's switch, ticket 05).
    static var trainingSaveFails: Bool { flag("-uiTestProfileSaveFails") }
    static var signedIn: Bool { flag("-uiTestProfileSample") || flag("-uiTestProfileNoTraining") }
    static var signInFailure: String? { flag("-uiTestSignInFailed") ? SignInFailure.unreachable : nil }
    static var welcomeSignedInName: String? { flag("-uiTestWelcomeSignedIn") ? "Alex Kim" : nil }

    static var profile: AccountProfile? {
        guard signedIn else { return nil }
        return AccountProfile(
            displayName: "Alex Kim", email: "alex@privaterelay.appleid.com", provider: "Apple",
            memberSince: Date(timeIntervalSince1970: 1_790_985_600),   // 2026-10-03
            training: flag("-uiTestProfileNoTraining") ? nil : training,
            aiUsage: [
                .init(flow: "scan-machine", title: "Machine scans", used: 12, limit: 60),
                .init(flow: "routine-week", title: "Template weeks", used: 2, limit: 10),
                .init(flow: "model-exercises", title: "Exercise suggestions", used: 0, limit: 60),
            ],
            aiResetsAt: AIResetCopy.nextReset(), aiPaused: flag("-uiTestAIPaused"))
    }

    static let training = TrainingProfile(
        goals: "Build strength. Get back to a bodyweight pull-up by spring.", experience: "Intermediate",
        days: 4, minutes: 45, height: BodyMeasure(value: 70, unit: .inches), weight: BodyMeasure(value: 180, unit: .lb))
}

/// The pushed screen: the page plus its sheets and alerts, on the account store (ticket 03's wiring; the sample
/// store under the UI-first flags). Signed in without a loaded profile (offline at launch), it offers Try Again and
/// Sign Out (codex-review-03-app #3). Signing out or a deletion leaves the page; a deletion's follow-up (the iOS
/// Settings step, or "signed out, nothing deleted") is shown by Settings, which outlives the page.
struct ProfileScreen: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    var usCustomary: Bool
    var onDeleteOutcome: (AccountStore.DeleteOutcome) -> Void
    @State private var editing = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var problem: String?

    var body: some View {
        Group {
            if let profile = account.profile {
                ProfileView(profile: profile,
                            onEditTraining: { editing = true },
                            onEditName: { newName = profile.displayName; renaming = true },
                            onSignOut: signOut,
                            onDelete: { Task { await delete() } })
                    .sheet(isPresented: $editing) {
                        TrainingProfileEditor(profile: profile.training, usCustomary: usCustomary) { training in
                            Task { if !(await account.saveTraining(training)) { problem = AccountDisplayCopy.saveFailed } }
                        }
                    }
            } else if account.isSignedIn {
                AccountUnavailableView(loading: !account.loadFailed,
                                       onTryAgain: { Task { await account.refresh() } }, onSignOut: signOut)
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .task { await account.refresh() }
        .alert(AccountDisplayCopy.nameTitle, isPresented: $renaming) {
            TextField(AccountDisplayCopy.nameTitle, text: $newName)
                .textContentType(.name)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, name != account.profile?.displayName else { return }
                Task { if !(await account.rename(String(name.prefix(50)))) { problem = AccountDisplayCopy.saveFailed } }
            }
        }
        .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK") {}
        }
    }

    private func signOut() {
        Task { await account.signOut(); dismiss() }
    }

    private func delete() async {
        let outcome = await account.deleteAccount()
        switch outcome {
        case .failed(let message): problem = message
        case .superseded: break
        case .deleted, .deletedNeedsAppleStep, .signedOut:
            onDeleteOutcome(outcome)
            dismiss()
        }
    }
}

/// The profile page while a signed-in session's profile is loading, or after its load failed: the account's
/// commands stay reachable offline (Sign Out forgets the session on this phone either way).
struct AccountUnavailableView: View {
    var loading: Bool
    var onTryAgain: () -> Void
    var onSignOut: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle(AccountDisplayCopy.loading)
                if loading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading…")
                            .font(look.font.body.weight(.semibold))
                            .foregroundStyle(look.textSecondary)
                    }
                } else {
                    SettingsNotice(symbol: "wifi.exclamationmark", text: AccountDisplayCopy.unavailable)
                        .accessibilityIdentifier("accountUnavailable")
                }
                LookList {
                    LookRow(AccountDisplayCopy.tryAgain, symbol: "arrow.clockwise", showsChevron: false, action: onTryAgain)
                        .accessibilityIdentifier("accountTryAgain")
                    LookDivider().padding(.leading, 16)
                    LookRow("Sign Out", symbol: "rectangle.portrait.and.arrow.right", showsChevron: false,
                            action: onSignOut)
                        .accessibilityIdentifier("profileSignOut")
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .lookScreenBackground()
    }
}

/// The sign-in sheet's one-line failures.
enum SignInFailure {
    static let unreachable = "Can't reach Stacked right now. Try again later."
    static let generic = "Couldn't sign in. Try again."
}
