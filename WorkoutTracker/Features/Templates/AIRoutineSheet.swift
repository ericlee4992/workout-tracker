import SwiftUI
import SwiftData

/// Ask AI for Templates (Floodlight ticket 10): a full-screen stepped flow — goals → equipment →
/// generating (or error) → your week (→ edit session) → saved — replacing the single form. The
/// request, eligibility (`RoutineAvailability`), consent flag, Terra call, validation and atomic
/// save are unchanged (D56–D58). Cancel while generating stops it and closes; leaving an unsaved
/// week asks first (ticket 10, decision 3). Machines scanned or added here are saved at once and
/// survive cancelling the routine.
struct AIRoutineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name) private var gyms: [Gym]
    @Query(filter: #Predicate<MachineInstance> { !$0.archived }) private var machines: [MachineInstance]
    @Query private var allPreferences: [AppPreferences]
    @Query private var templates: [WorkoutTemplate]
    @State var gym: Gym?
    var onSelectGym: (Gym?) -> Void = { _ in }
    /// A saved template's tile: close the flow and open it on the Workout tab.
    var onOpenTemplate: (WorkoutTemplate) -> Void = { _ in }

    @State private var model = AIRoutineFlowModel()
    @State private var path: [UUID] = []
    @AppStorage(TerraAccess.routineConsentKey) private var consent = false
    @State private var keyHint: String? = AskAIKeyStore.read().map(AskAIKeyHint.masked)
    @State private var showingSettings = false
    @State private var showingNewGym = false
    @State private var scanningGym: Gym?
    @State private var manualGymPending: Gym?
    @State private var manualGym: Gym?
    @State private var confirmingLeave: AIRoutineLeave?

    private var availableMachines: [MachineInstance] {
        guard let gym, !gym.archived else { return [] }
        return machines.filter { $0.gym?.id == gym.id }
    }

    private var options: [RoutineExerciseOption] {
        RoutineAvailability.exercises(exercises, machines: availableMachines, extras: model.extras)
    }

    /// What the editor and the week use: the SENT request's options (the week was built from them).
    private var sentOptions: [RoutineExerciseOption] { model.sentRequest?.exercises ?? options }
    private var names: [UUID: String] { Dictionary(sentOptions.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }) }
    private var groups: [UUID: String] { Dictionary(sentOptions.map { ($0.id, $0.muscleGroup) }, uniquingKeysWith: { a, _ in a }) }
    private var machineLabels: [UUID: String] {
        var labels: [UUID: String] = [:]
        for machine in availableMachines.sorted(by: { $0.label < $1.label }) {
            for id in machine.supportedExerciseIDs where labels[id] == nil { labels[id] = machine.label }
        }
        return labels
    }

    private var usCustomary: Bool {
        AppUnitSystem.resolve(preference: AppPreferences.canonical(of: allPreferences)?.unitPreference) == .usCustomary
    }

    private var permitted: Bool { consent || TerraAccess.bypassesConsent }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                look.ground.ignoresSafeArea()
                stepView
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.9),
                       value: model.step)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { dayID in
                AIDayEditor(dayID: dayID, model: model, options: model.sentRequest?.exercises ?? [],
                            activities: model.sentRequest?.cardioActivities ?? [], names: names, groups: groups,
                            machineLabels: machineLabels, onBack: { if !path.isEmpty { path.removeLast() } })
            }
        }
        // System controls (keyboard Done, menus) take the text colour: violet marks only the step's
        // one command.
        .tint(look.textPrimary)
        .sensoryFeedback(trigger: model.step) { _, new in
            switch new {
            case .preview, .saved: .success
            case .error: .error
            default: nil
            }
        }
        .onChange(of: model.step) { _, step in if step != .preview && !path.isEmpty { path = [] } }
        // Withdrawing consent mid-flow stops a request and drops an unsaved week (as before).
        .onChange(of: consent) { _, allowed in
            if !allowed && !TerraAccess.bypassesConsent {
                model.cancelGeneration()
                if model.step == .preview || model.step == .error { model.back() }
            }
        }
        .onDisappear { model.cancelTasks() }
        .confirmationDialog("Discard this week?", isPresented: Binding(get: { confirmingLeave != nil },
                                                                     set: { if !$0 { confirmingLeave = nil } }),
                            titleVisibility: .visible, presenting: confirmingLeave) { leave in
            Button("Discard Week", role: .destructive) { perform(leave) }
            Button("Keep Editing", role: .cancel) {}
        }
        .sheet(isPresented: $showingSettings, onDismiss: { keyHint = AskAIKeyStore.read().map(AskAIKeyHint.masked) }) {
            AskAISettingsSheet()
        }
        .sheet(isPresented: $showingNewGym) {
            GymEditorSheet(onSave: { created in select(created) })
        }
        .sheet(item: $scanningGym, onDismiss: {
            if let pending = manualGymPending { manualGymPending = nil; manualGym = pending }
        }) { gym in
            // Floodlight ticket 07 (user decision 1): the scan adds the machine itself;
            // "Choose a catalog model" opens the machine form once the scan has closed.
            IdentifyEquipmentSheet(addingTo: gym, onManual: { manualGymPending = gym })
        }
        .sheet(item: $manualGym) { gym in MachineEditorSheet(gym: gym) }
    }

    @ViewBuilder private var stepView: some View {
        switch model.step {
        case .goals:
            AIGoalsStep(model: model, usCustomary: usCustomary, onCancel: close)
                .transition(stepTransition)
        case .equipment:
            AIEquipmentStep(model: model, gyms: gyms, gym: gym, machines: availableMachines, options: options,
                            consent: $consent, consentBypassed: TerraAccess.bypassesConsent, keyHint: keyHint,
                            onSelectGym: select, onAddGym: { showingNewGym = true },
                            onScan: { scanningGym = $0 }, onOpenSettings: { showingSettings = true },
                            onGenerate: generate, onCancel: close)
                .transition(stepTransition)
        case .generating:
            AIGeneratingStep(model: model, gymName: gym?.name, families: AIRoutineReadouts.eligibleFamilies(options),
                             onCancel: close)
                .transition(stepTransition)
        case .error:
            AIErrorStep(model: model, gymName: gym?.name, canRetry: permitted, onRetry: generate, onCancel: close)
                .transition(stepTransition)
        case .preview:
            AIWeekPreview(model: model, gymName: gym?.name, names: names, groups: groups,
                          onOpenDay: { path.append($0) }, onLeave: leave,
                          onSave: { model.save(gymID: gym?.id, container: context.container) })
                .transition(stepTransition)
        case .saved:
            let saved = model.savedTemplateIDs.compactMap { id in templates.first { $0.id == id } }
            AISavedStep(templates: saved,
                        runs: AIRoutineReadouts.weekFamilyCounts(model.routine?.sessions ?? [], groups: groups)
                            .map { RingRun(family: $0.family, sets: $0.sets) },
                        gymName: gym?.name,
                        onOpenTemplate: { template in dismiss(); onOpenTemplate(template) },
                        onDone: close)
                .transition(stepTransition)
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: model.forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .opacity)
    }

    // MARK: Actions

    private func select(_ newGym: Gym?) {
        gym = newGym
        onSelectGym(newGym)
    }

    private func generate() {
        model.generate(options: options, gymName: gym?.name, permitted: permitted)
    }

    /// Cancel: stops a running request and closes. From an unsaved week it asks first.
    private func close() {
        if model.hasUnsavedWeek { confirmingLeave = .close; return }
        model.cancelTasks()
        dismiss()
    }

    /// Back, Cancel or Change preferences from Your week: each would lose the week, so ask.
    private func leave(_ leave: AIRoutineLeave) {
        if model.hasUnsavedWeek { confirmingLeave = leave } else { perform(leave) }
    }

    private func perform(_ leave: AIRoutineLeave) {
        confirmingLeave = nil
        switch leave {
        case .close:
            model.cancelTasks()
            dismiss()
        case .back:
            model.back()
        case .changePreferences:
            model.changePreferences()
        }
    }
}
