import SwiftData
import SwiftUI

// PROTOTYPE (N13, throwaway): the goal setup on sample answers, saving nothing, with a floating switcher for the
// question the user decides — where the welcome page and the guided tour go relative to the setup — and for a new
// install vs an existing user (from Nutrition goals). Shown only under `-uiTestReset -goalSetupPrototype`. Removed
// once the user has chosen; the chosen order is then built into `OnboardingCoordinator`.

@Observable
@MainActor
final class GoalSetupPrototypeState {
    static let shared = GoalSetupPrototypeState()
    static var isEnabled: Bool {
        WorkoutTrackerStore.isUITestReset && ProcessInfo.processInfo.arguments.contains("-goalSetupPrototype")
    }
    /// Hides the switcher for the captures.
    static var hidesSwitcher: Bool { ProcessInfo.processInfo.arguments.contains("-goalSetupPrototypeCapture") }

    enum Order: String, CaseIterable, Identifiable {
        case welcomeFirst = "A · Welcome, then setup"
        case setupFirst = "B · Setup, then welcome"
        case setupOnly = "C · Setup only"
        var id: String { rawValue }
        var letter: String { String(rawValue.prefix(1)) }
    }

    enum Phase { case welcome, setup, welcomeAfter, app }

    var order: Order = .welcomeFirst
    var existing = false
    var phase: Phase = .welcome
    var draft = GoalSetupDraft(existing: false)

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-goalSetupPrototypeOrder"), index + 1 < arguments.count {
            order = Order.allCases.first { $0.letter == arguments[index + 1] } ?? .welcomeFirst
        }
        existing = arguments.contains("-goalSetupPrototypeExisting")
        restart()
        // Captures: start at a named step with the sample answers filled in.
        if let index = arguments.firstIndex(of: "-goalSetupPrototypeStep"), index + 1 < arguments.count,
           let raw = Int(arguments[index + 1]), let step = GoalSetupDraft.Step(rawValue: raw) {
            phase = .setup
            fillSample()
            if arguments.contains("-goalSetupPrototypeMaintain") { draft.goal = .maintain }
            while draft.step < step, draft.steps.contains(where: { $0 > draft.step }) { draft.advance() }
        }
    }

    func restart() {
        draft = GoalSetupDraft(existing: existing)
        phase = existing ? .setup : (order == .welcomeFirst ? .welcome : .setup)
    }

    func finishSetup() {
        phase = (!existing && order == .setupFirst) ? .welcomeAfter : .app
    }

    /// The new-install answers the captures start from (as if typed).
    private func fillSample() {
        guard !existing else { return }
        draft.sex = .female
        draft.birthDate = Calendar.current.date(from: DateComponents(year: 1996, month: 8, day: 2)) ?? draft.birthDate
        draft.heightCm = 168
        draft.weightText = "68.5"
        draft.workouts = .some
        draft.goal = .lose
    }
}

/// On the app's root under the prototype flag: the flow as a cover, and the switcher.
struct GoalSetupPrototypeModifier: ViewModifier {
    @Environment(OnboardingCoordinator.self) private var onboarding
    @Environment(\.modelContext) private var modelContext
    @State private var state = GoalSetupPrototypeState.shared

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: Binding(get: { state.phase != .app }, set: { if !$0 { state.phase = .app } })) {
                cover
                    .lookLayer()
                    .interactiveDismissDisabled()
                    .safeAreaInset(edge: .top, spacing: 0) { if !GoalSetupPrototypeState.hidesSwitcher { switcher } }
            }
            .overlay(alignment: .top) {
                if state.phase == .app && !GoalSetupPrototypeState.hidesSwitcher { switcher }
            }
    }

    @ViewBuilder private var cover: some View {
        switch state.phase {
        case .welcome:
            PrototypeWelcome(onStart: { withAnimation { state.phase = .setup } })
        case .setup, .app:
            GoalSetupFlow(draft: state.draft,
                          onFinish: { state.finishSetup() },
                          onClose: state.existing ? { state.phase = .app } : nil,
                          onTour: state.order == .welcomeFirst ? { startTour() } : nil)
        case .welcomeAfter:
            WelcomeView(onTour: { startTour() }, onSkip: { state.phase = .app })
        }
    }

    private func startTour() {
        state.phase = .app
        onboarding.startTour(realContext: modelContext)
    }

    private var switcher: some View {
        Menu {
            Picker("Order", selection: Binding(get: { state.order }, set: { state.order = $0; state.restart() })) {
                ForEach(GoalSetupPrototypeState.Order.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Who", selection: Binding(get: { state.existing }, set: { state.existing = $0; state.restart() })) {
                Text("New install").tag(false)
                Text("Existing user (Nutrition goals)").tag(true)
            }
            Button("Restart", systemImage: "arrow.counterclockwise") { state.restart() }
        } label: {
            Text("Prototype · \(state.order.letter) · \(state.existing ? "Existing" : "New")")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.orange, in: Capsule())
        }
        .padding(.top, 2)
        .accessibilityIdentifier("goalSetupPrototypeSwitcher")
    }
}

/// Option A's welcome page: today's page with one command, Get Started, into the setup — no Skip (the setup is
/// required). Sign-in would stay under it in a build with a server.
private struct PrototypeWelcome: View {
    var onStart: () -> Void
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
            PrimaryButton("Get Started", action: onStart)
                .accessibilityIdentifier("welcomeGetStarted")
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 8)
        }
        .background(look.ground.ignoresSafeArea())
    }
}

extension View {
    @ViewBuilder func goalSetupPrototype() -> some View {
        if GoalSetupPrototypeState.isEnabled { modifier(GoalSetupPrototypeModifier()) } else { self }
    }
}
