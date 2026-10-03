import SwiftUI

/// Public beta ticket 05, UI-first stage: the profile page and editor on sample data, reachable only under
/// `-uiTestReset` with a sample flag (no sign-in exists in the app before 03's app half).
///
/// - `-uiTestProfileSample`: signed in with a training profile.
/// - `-uiTestProfileNoTraining`: signed in, no training profile yet.
/// - `-uiTestProfileSignedOut`: the Settings row signed out ("Sign In").
enum ProfileSample {
    private static func flag(_ name: String) -> Bool {
        WorkoutTrackerStore.isUITestReset && ProcessInfo.processInfo.arguments.contains(name)
    }

    static var showsAccountRow: Bool { signedIn || flag("-uiTestProfileSignedOut") }
    static var signedIn: Bool { flag("-uiTestProfileSample") || flag("-uiTestProfileNoTraining") }

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

/// The pushed screen: the page plus its sheets, on the sample value (edits stay in memory).
struct ProfileScreen: View {
    @State var profile: AccountProfile
    var usCustomary: Bool
    @State private var editing = false

    var body: some View {
        ProfileView(profile: profile, onEditTraining: { editing = true })
            .sheet(isPresented: $editing) {
                TrainingProfileEditor(profile: profile.training, usCustomary: usCustomary) { profile.training = $0 }
            }
    }
}
