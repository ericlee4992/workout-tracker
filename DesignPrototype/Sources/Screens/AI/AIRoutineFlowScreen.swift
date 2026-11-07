import SwiftUI

// PROTOTYPE — Ask AI for Templates (A01–A05): a full-screen stepped flow driven by `store.ai`.
// goals → equipment → generating (or error) → your week (→ day editor) → saved.
// The shell presents this as a cover (`router.aiRoutinePresented`). Close / cancel keep
// today's semantics: Cancel stops a running generation and dismisses with no confirmation;
// "Change preferences" discards the week; edits in the day editor apply live.

/// The flow as it was when the cover last closed, so the next open from Home starts fresh.
enum AIFlowMemory {
    static var closedState: AIRoutineFlow?
    /// The scenario clock at that moment. `reset(to:)` winds the clock back to Thu 18:30, so a
    /// ScreenIndex jump to the same A-screen is never mistaken for a reopen from Home.
    static var closedAt: Date?
}

struct AIRoutineFlowScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The pushed day editor (A05), by day id.
    @State private var path: [UUID] = []
    /// Direction of the last step change: forward steps slide in from the trailing edge.
    @State private var forward = true
    @State private var launched = false
    /// Capture variant "p2" / "p3" for the step the flow opened on (used once).
    @State private var launchPage: Int?
    @State private var launchStep: AIStep?
    @State private var editorLaunch = AIEditorLaunch()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                look.ground.ignoresSafeArea()
                stepView
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.9),
                       value: store.ai.step)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { dayID in
                AIDayEditorView(dayID: dayID, launch: editorLaunch,
                                onBack: { if !path.isEmpty { path.removeLast() } })
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        // System controls (keyboard Done, menus) take the text colour: the action colour marks
        // only the step's one command.
        .tint(look.textPrimary)
        .environment(\.aiStill, store.currentScreen == .a03 && router.variant == "still")
        .onAppear(perform: applyLaunchState)
        .onChange(of: store.ai.step) { _, step in
            launchStep = nil
            if step != .preview && !path.isEmpty { path = [] }
            // A freshly generated (or discarded) week has no hand edits yet.
            if step != .preview { AIWeekEdits.edited = false }
        }
        // "Add Gym…" (G05 over this cover): a gym created here becomes the routine's gym.
        .onChange(of: store.activeGyms.map(\.id)) { old, new in
            guard store.ai.step == .equipment || store.ai.step == .goals,
                  let added = new.first(where: { !old.contains($0) }) else { return }
            store.aiUpdateRequest { $0.gymID = added }
        }
        .sensoryFeedback(trigger: store.ai.step) { _, new in
            switch new {
            case .preview, .saved: .success
            case .error: .error
            default: nil
            }
        }
        .onDisappear {
            if store.ai.step == .generating { store.aiCancelGeneration() }
        }
    }

    @ViewBuilder private var stepView: some View {
        switch store.ai.step {
        case .goals:
            AIGoalsStepView(initialPage: page(for: .goals), actions: actions).transition(stepTransition)
        case .equipment:
            AIEquipmentStepView(initialPage: page(for: .equipment), actions: actions).transition(stepTransition)
        case .generating:
            AIGeneratingStepView(actions: actions).transition(stepTransition)
        case .error:
            AIErrorStepView(actions: actions).transition(stepTransition)
        case .preview:
            AIWeekPreviewView(initialPage: page(for: .preview), actions: actions).transition(stepTransition)
        case .saved:
            AISavedStepView(actions: actions).transition(stepTransition)
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .opacity)
    }

    private func page(for step: AIStep) -> Int? { launchStep == step ? launchPage : nil }

    private var actions: AIFlowActions {
        AIFlowActions(
            next: { forward = true; store.aiNext() },
            back: { forward = false; store.aiBack() },
            generate: { forward = true; AIWeekEdits.edited = false; store.aiGenerate() },
            retry: {
                forward = true
                store.aiSetSimulateFailure(false)
                store.aiGenerate()
            },
            stopGenerating: { forward = false; store.aiCancelGeneration() },
            changePreferences: { forward = false; store.aiChangePreferences() },
            save: { forward = true; store.aiSave() },
            openDay: { id in path.append(id) },
            openTemplate: { id in
                rememberClose()
                router.aiRoutinePresented = false
                router.select(.workout)
                router.push(.templateDetail(templateID: id))
            },
            close: close)
    }

    /// Cancel / Done: stop a running generation and dismiss (no confirmation, as today).
    private func close() {
        if store.ai.step == .generating { store.aiCancelGeneration() }
        rememberClose()
        router.aiRoutinePresented = false
    }

    /// A close the user made (Cancel / Done / a saved tile), so the next open from Home is fresh.
    private func rememberClose() {
        AIFlowMemory.closedState = store.ai
        AIFlowMemory.closedAt = store.now
    }

    /// `-screen A0x` states (variants):
    /// - A01: `empty` (no goal: Next off), `emptyFocus` (and the cursor in the goal).
    /// - A02: `consentOff` (disclosure + the switch outlined), `noKey`, `noGym`, `hotel` (a gym
    ///   with no machines, pull-up bar + dip station: a partly lit readout), `nothing` (Hotel Gym, nothing chosen: Generate off).
    /// - A03: `failure`, `balancing` (65 %), `fitting` (90 %), `still` (Reduce Motion face).
    /// - A04: `saved`, `savedOpen` (a saved tile tapped → template detail), `invalid` (save
    ///   validation error), `days1` / `days6` / `noCardio` (regenerated; capture with SETTLE ≥ 6),
    ///   `discard` (an edited week: Cancel's confirmation).
    /// - A05: `picker`, `pickerEmpty` (search with no matches), `full` (10 exercises: Add off),
    ///   `day2` (a day with no cardio), `removed` (an exercise just removed: the undo bar).
    /// - "p2" / "p3" open a long step scrolled down.
    private func applyLaunchState() {
        guard !launched else { return }
        launched = true
        AIWeekEdits.edited = false
        // Opened from Home ("Ask AI for Templates"): start fresh at step 1 for Home's gym, as the
        // real cover does. A `-screen A0x` / ScreenIndex state has just been set by reset(to:)
        // and differs from both the untouched default and the flow as it was last closed.
        let reopened = store.ai == AIFlowMemory.closedState && store.now >= (AIFlowMemory.closedAt ?? .distantFuture)
        if reopened || (store.ai.step == .goals && store.ai.request == AIRoutineRequest() && store.ai.days.isEmpty) {
            store.aiBegin()
        }
        let pageVariant: Int? = switch router.variant {
        case "p2": 2
        case "p3": 3
        default: nil
        }
        applyStoreVariant()
        if store.currentScreen == .a05, store.ai.step == .preview,
           var dayID = store.screenTarget.aiDayID, store.ai.days.contains(where: { $0.id == dayID }) {
            if router.variant == "day2", store.ai.days.count > 1 { dayID = store.ai.days[1].id }
            if router.variant == "full", var day = store.ai.days.first(where: { $0.id == dayID }) {
                // Fill the session to the 10-exercise limit (Add exercise turns off).
                let extra = store.aiPickerSections(dayID: dayID, query: "").flatMap(\.exercises)
                for exercise in extra.prefix(max(0, 10 - day.items.count)) {
                    day.items.append(AIRoutineItem(id: UUID(), exerciseID: exercise.id, sets: 3, reps: 10, restSeconds: 60))
                }
                store.aiUpdateDay(day)
            }
            editorLaunch.page = pageVariant ?? (router.variant == "full" ? 2 : nil)
            let picker = router.variant == "picker" || router.variant == "pickerEmpty"
            editorLaunch.expandsFirst = !picker && router.variant != "full"
            editorLaunch.showsPicker = picker
            editorLaunch.pickerQuery = router.variant == "pickerEmpty" ? "Deadlift" : ""
            AIPickerLaunch.query = editorLaunch.pickerQuery
            editorLaunch.removesSecond = router.variant == "removed"
            DispatchQueue.main.async {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { path = [dayID] }
            }
        } else if let pageVariant {
            launchPage = pageVariant
            launchStep = store.ai.step
        }
        if store.currentScreen == .a04, store.ai.step == .preview,
           router.variant == "saved" || router.variant == "savedOpen" {
            store.aiSave()
            if router.variant == "savedOpen", let first = store.ai.savedTemplateIDs.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { actions.openTemplate(first) }
            }
        }
        if store.currentScreen == .a03, store.ai.step == .generating,
           let variant = router.variant, ["failure", "error"].contains(variant) {
            store.aiSetSimulateFailure(true)
            store.aiGenerate(resumeFrom: store.ai.progress)
        }
    }

    /// Store-level launch variants (they change the sample state before the step renders).
    private func applyStoreVariant() {
        guard let variant = router.variant, let screen = store.currentScreen else { return }
        let hotel = SampleData.gymID("Hotel Gym")
        switch (screen, variant) {
        case (.a01, "empty"), (.a01, "emptyFocus"):
            store.aiUpdateRequest { $0.goals = "" }
        case (.a02, "consentOff"):
            store.aiUpdateRequest { $0.consent = false }
        case (.a02, "noKey"):
            store.removeAIKey()
        case (.a02, "noGym"):
            store.aiUpdateRequest { $0.gymID = nil }
        case (.a02, "hotel"):
            store.aiUpdateRequest { r in r.gymID = hotel; r.equipment = [.pullupBar, .dipStation]; r.cardio = [] }
        case (.a02, "nothing"):
            store.aiUpdateRequest { r in r.gymID = hotel; r.equipment = []; r.cardio = [] }
        case (.a04, "invalid"):
            // A session left without a name: Save shows the real validation message.
            if var day = store.ai.days.dropFirst().first {
                day.name = ""
                store.aiUpdateDay(day)
                store.aiSave()
            }
        case (.a04, "days1"), (.a04, "days6"), (.a04, "noCardio"):
            store.aiUpdateRequest { r in
                if variant == "days1" { r.daysPerWeek = 1 }
                if variant == "days6" { r.daysPerWeek = 6 }
                if variant == "noCardio" { r.cardio = [] }
            }
            store.aiGenerate()
        default: break
        }
    }
}
