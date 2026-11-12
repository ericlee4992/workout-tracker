import AuthenticationServices
import SwiftUI

/// N13 (D84): the first-launch cover — the welcome page, then the required goal setup (no way out until the plan is
/// saved). The plan's Start saves and opens the app; Show Me Around saves and starts the tour.
struct FirstLaunchView: View {
    var welcome: WelcomeView
    @Environment(OnboardingCoordinator.self) private var onboarding
    @Environment(AccountStore.self) private var account
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var saveFailure: String?

    var body: some View {
        Group {
            if let draft = onboarding.setup {
                GoalSetupFlow(draft: draft,
                              onFinish: { finish($0, thenTour: false) },
                              onClose: nil,
                              onTour: { finish($0, thenTour: true) },
                              generator: GoalPlanService.generator(account))
                    .transition(.opacity)
            } else {
                welcome
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: onboarding.setup == nil)
        .interactiveDismissDisabled()
        .alert("Couldn't save", isPresented: Binding(get: { saveFailure != nil }, set: { if !$0 { saveFailure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveFailure ?? "") }
    }

    private func finish(_ answers: GoalSetupStore.Answers, thenTour: Bool) {
        do { try onboarding.finishSetup(answers, in: modelContext, thenTour: thenTour) }
        catch { saveFailure = error.localizedDescription }
    }
}
