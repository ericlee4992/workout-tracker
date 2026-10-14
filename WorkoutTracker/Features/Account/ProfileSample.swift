import SwiftUI

/// Public beta ticket 05, UI-first stage: the profile page and editor on sample data, reachable only under
/// `-uiTestReset` with a sample flag (no sign-in exists in the app before 03's app half).
///
/// - `-uiTestProfileSample`: signed in with a training profile.
/// - `-uiTestProfileNoTraining`: signed in, no training profile yet.
/// - `-uiTestProfileSignedOut`: the Settings row signed out ("Sign In"); tapping it opens the sign-in sheet (ticket 03).
/// - `-uiTestSignInFailed`: the sign-in sheet shows its failure line (ticket 03's mock).
/// - `-uiTestWelcomeSignedIn`: the welcome page after signing in there (ticket 03's mock).
enum ProfileSample {
    private static func flag(_ name: String) -> Bool {
        WorkoutTrackerStore.isUITestReset && ProcessInfo.processInfo.arguments.contains(name)
    }

    static var showsAccountRow: Bool { signedIn || flag("-uiTestProfileSignedOut") }
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
            aiResetsAt: .now, aiPaused: false)
    }

    /// `-uiTestProfilePrefill` (with the sample): Ask AI opens prefilled from the profile and offers "Save to my
    /// training profile" — the option the user decides on in ticket 05's mock.
    static var prefillsAskAI: Bool { flag("-uiTestProfilePrefill") && profile?.training != nil }

    @MainActor static func prefilledRoutineModel() -> AIRoutineFlowModel {
        let model = AIRoutineFlowModel()
        guard prefillsAskAI else { return model }
        model.goals = training.goals
        model.experience = training.experience
        model.days = training.days
        model.minutes = training.minutes
        model.heightCm = training.height?.centimetres
        model.weightKg = training.weight?.kilograms
        return model
    }

    static let training = TrainingProfile(
        goals: "Build strength. Get back to a bodyweight pull-up by spring.", experience: "Intermediate",
        days: 4, minutes: 45, height: BodyMeasure(value: 70, unit: .inches), weight: BodyMeasure(value: 180, unit: .lb))
}

/// The pushed screen: the page plus its sheets and alerts, on the account store (ticket 03's wiring; the sample
/// store under the UI-first flags). Signing out or deleting leaves the page; Settings shows the follow-up after a
/// deletion that needs the iOS Settings step (the page is gone by then).
struct ProfileScreen: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    var usCustomary: Bool
    var onAppleStep: () -> Void
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
                            onSignOut: { Task { await account.signOut(); dismiss() } },
                            onDelete: { Task { await delete() } })
                    .sheet(isPresented: $editing) {
                        TrainingProfileEditor(profile: profile.training, usCustomary: usCustomary) { training in
                            Task { if !(await account.saveTraining(training)) { problem = AccountDisplayCopy.saveFailed } }
                        }
                    }
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

    private func delete() async {
        switch await account.deleteAccount() {
        case .deleted: dismiss()
        case .deletedNeedsAppleStep:
            onAppleStep()
            dismiss()
        case .failed(let message): problem = message
        }
    }
}

/// The sign-in sheet's one-line failures.
enum SignInFailure {
    static let unreachable = "Can't reach Stacked right now. Try again later."
    static let generic = "Couldn't sign in. Try again."
}
