import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Public beta ticket 02: the guided tour, when one runs (nil otherwise).
    @Environment(TourController.self) private var tour: TourController?
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name)
    private var gyms: [Gym]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query private var allPreferences: [AppPreferences]
    /// C1: a minimised workout keeps running, so the tab must offer the way
    /// back in. Newest first — the same newest-active-wins rule the recovery
    /// path uses.
    @Query(
        filter: #Predicate<Workout> { $0.finishedAt == nil },
        sort: [SortDescriptor(\Workout.startedAt, order: .reverse)])
    private var activeWorkouts: [Workout]
    /// History behind "This week" and the tiles' last-run dates.
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil })
    private var finishedWorkouts: [Workout]
    @State private var selectedGym: Gym?
    /// D1: the stored pick is read once per screen lifetime — re-reading it
    /// would fight the user's in-session choice.
    @State private var restoredSelectedGym = false
    /// The start flow's trigger (`WorkoutStartFlow`, ticket 11).
    @State private var startRequest: WorkoutStartRequest?
    /// The template whose detail is pushed (ticket 11: a tile opens the
    /// template; Start lives on the detail).
    @State private var viewingTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showingTemplateEditor = false
    @State private var showingCardioPicker = false
    @State private var showingAIRoutine = false
    /// Soft redesign S5 (D77): the user's split and Today's "Not today" choice (view preferences), so the leading card
    /// shows the same template as Today; `now` follows the day (`refreshingNow`).
    @AppStorage(MySplitStore.key) private var splitData = Data()
    @AppStorage(UpNextOverride.key) private var overrideData = Data()
    @State private var showingMySplit = false
    @State private var now = Date.now
    /// Scrolled past the large title: the inline "Workout" takes over in the bar.
    @State private var titleInBar = false
    /// Called with the workout to present — freshly started or resumed.
    var onWorkoutStarted: (Workout) -> Void
    /// Set by History's empty screen ("Start Lifting"): runs this tab's own Start Lifting flow
    /// once, then resets (ticket 05).
    @Binding var startLiftingRequest: Bool

    init(onWorkoutStarted: @escaping (Workout) -> Void, startLiftingRequest: Binding<Bool> = .constant(false)) {
        self.onWorkoutStarted = onWorkoutStarted
        _startLiftingRequest = startLiftingRequest
    }

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    var body: some View {
        NavigationStack {
          ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Train", subtitle: WorkoutDates.homeSubtitle(.now))
                    // Soft redesign S3 (Direction A's order, the prototype's Train): the template due next leads with
                    // ONE Start, Start Lifting / Start Cardio step down to a quiet pair, the other templates follow,
                    // and "This week" moves to the end (a look back, not the reason to open the tab).
                    VStack(spacing: 12) {
                        gymPicker
                            .tourAnchor("tour.gymPicker").id("tour.gymPicker")
                        if leadTemplate != nil {
                            upNextCard
                        }
                        startControl
                            .tourAnchor("tour.start").id("tour.start")
                    }
                    templatesSection
                    weekCard
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 2)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            // Public beta ticket 02: the guided tour scrolls its highlighted control into view.
            .onChange(of: tour?.current?.anchor) { _, anchor in
                guard let anchor, anchor.hasPrefix("tour.") else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { scroller.scrollTo(anchor, anchor: .center) }
            }
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > (dynamicTypeSize.isAccessibilitySize ? 70 : 46)
            } action: { _, past in
                withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
            }
            .lookScreenBackground()
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.inline)
            // Scrolled: the bar takes the solid ground, so nothing shows through under the title.
            .toolbarBackground(look.ground, for: .navigationBar)
            .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                // Soft redesign S2 (D68): Train's switch (Templates | Gyms | Exercises) in the bar.
                // Settings moved from a gear here to the Profile tab.
                ToolbarItem(placement: .principal) {
                    InlineTitleOrTrainSwitcher(title: "Train", visible: titleInBar, trainRoot: true)
                }
            }
          }
            .workoutStartFlow(request: $startRequest, gym: selectedGym, onWorkoutStarted: onWorkoutStarted)
            .navigationDestination(item: $viewingTemplate) { template in
                // The detail runs the same flow with its own dialogs; a
                // started workout pops it, so minimising lands on Start.
                TemplateDetailView(template: template, gym: selectedGym) { workout in
                    viewingTemplate = nil
                    onWorkoutStarted(workout)
                }
            }
            .sheet(isPresented: $showingMySplit) {
                MySplitSheet(templates: templates)
            }
            .refreshingNow($now)
            .fullScreenCover(isPresented: $showingAIRoutine) {
                // Floodlight ticket 10: a saved template's tile opens it here once the cover has gone.
                AIRoutineSheet(gym: selectedGym, onSelectGym: select, onOpenTemplate: { template in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { viewingTemplate = template }
                })
            }
            .sheet(isPresented: $showingCardioPicker) {
                CardioActivityPicker { choice in
                    showingCardioPicker = false
                    startRequest = WorkoutStartRequest(template: nil, cardioActivity: choice.activity)
                }
            }
            .sheet(isPresented: $showingTemplateEditor) {
                TemplateEditorSheet(template: editingTemplate)
            }
            .onAppear(perform: restoreSelectedGym)
            // A gym deleted (archived) elsewhere — Gyms → Edit Gym → Delete Gym… — while it is the
            // selection: drop it here too, or the next workout would start at an archived gym
            // (Codex review 06). Delete Gym… also clears the remembered id.
            .onChange(of: selectedGym?.archived) { _, archived in
                if archived == true { selectedGym = nil }
            }
            .onAppear(perform: consumeStartLiftingRequest)
            .onChange(of: startLiftingRequest) { _, _ in consumeStartLiftingRequest() }
        }
    }

    private func consumeStartLiftingRequest() {
        guard startLiftingRequest else { return }
        startLiftingRequest = false
        // A running workout is resumed from this tab instead; Start stays the Start pair's.
        guard activeWorkouts.isEmpty else { return }
        startRequest = WorkoutStartRequest(template: nil)
    }

    // MARK: Start / Resume

    /// Idle: the two equal Start capsules, side by side, stacking only when a label can't fit.
    /// Live: ONE Resume capsule returns to the minimised workout.
    private var startControl: some View {
        ZStack {
            if let active = activeWorkouts.first, !active.isDeleted {
                WorkoutResumeCapsule(
                    symbol: active.unfinishedCardio?.activity.symbol ?? "figure.strengthtraining.traditional",
                    detail: Self.resumeDetail(active),
                    startedAt: active.startedAt,
                    elapsedAt: { active.isDeleted ? 0 : active.trainingSeconds(at: $0) },
                    action: resumeActive)
                    .accessibilityIdentifier("resumeWorkout")
                    .transition(swapTransition)
            } else if leadTemplate != nil {
                TrainQuickStarts(startLifting: { startRequest = WorkoutStartRequest(template: nil) },
                                 startCardio: { showingCardioPicker = true })
                    .sensoryFeedback(.workoutStart, trigger: activeWorkouts.count)
                    .transition(swapTransition)
            } else {
                // No template to lead: the Start pair stays the screen's primary action.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { startCapsules }
                    VStack(spacing: 12) { startCapsules }
                }
                .transition(swapTransition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82),
                   value: activeWorkouts.first?.id)
    }

    @ViewBuilder private var startCapsules: some View {
        StartCapsule(title: "Start Lifting", symbol: "figure.strengthtraining.traditional") {
            startRequest = WorkoutStartRequest(template: nil)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.workoutStart, trigger: activeWorkouts.count)
        .accessibilityIdentifier("startEmptyWorkout")
        StartCapsule(title: "Start Cardio", symbol: "figure.run") { showingCardioPicker = true }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("startCardio")
    }

    private var swapTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    /// What is running: the cardio activity, or the workout's title with its set progress.
    /// Also Today's Resume capsule (S2).
    static func resumeDetail(_ workout: Workout) -> String {
        if let cardio = workout.unfinishedCardio { return cardio.activity.name }
        let sets = WorkoutSession.orderedEntries(of: workout).flatMap { $0.sets ?? [] }
        let title = workout.historyTitle
        guard !sets.isEmpty else { return title }
        return "\(title) · \(sets.filter { $0.completedAt != nil }.count)/\(sets.count) sets"
    }

    // MARK: Start flow — `WorkoutStartFlow` (ticket 11); Resume needs no dialog.

    private func resumeActive() {
        if let workout = try? session.resumableWorkout() {
            onWorkoutStarted(workout)
        }
    }

    // MARK: This week

    @ViewBuilder private var weekCard: some View {
        let summary = WeekSummaryMath.summary(ofWorkouts: finishedWorkouts, now: .now)
        // The query holds finished workouts only, so "none at all" is the store's whole history being empty.
        if finishedWorkouts.isEmpty && activeWorkouts.isEmpty {
            // First run: no scoreboard of zeros, just the week waiting for its first workout.
            WorkoutFirstWeekCard(days: summary.days)
        } else {
            WeekWidget(summary: summary)
        }
    }

    // MARK: Templates

    /// The template up next, leading the screen while no workout runs — Today's template (S5, D77: learned order or
    /// My split, with the day's "Not today" choice). A rest day leads with nothing.
    private var leadTemplate: WorkoutTemplate? {
        guard activeWorkouts.first == nil else { return nil }
        return UpNextReading.make(templates: templates, finished: finishedWorkouts, splitData: splitData,
                                  overrideData: overrideData, now: now).template
    }

    private var upNextCard: some View {
        let template = leadTemplate!
        let stats = templateStats[template.id]
        let items = WorkoutTemplateService.orderedItems(of: template)
        let names = items.compactMap { $0.exercise?.name } + template.plannedCardio.map { $0.activity.name }
        let count = items.count
        let subtitle = [selectedGym?.name, count == 0 ? nil : (count == 1 ? "1 exercise" : "\(count) exercises")]
            .compactMap { $0 }.joined(separator: " · ")
        return TrainUpNextCard(name: template.name,
                               families: MuscleFamily.families(of: items.map { $0.exercise?.muscleGroup }),
                               exercises: names, lastRun: stats?.lastRun, averageSeconds: stats?.averageDurationSeconds,
                               startSubtitle: subtitle.isEmpty ? nil : subtitle,
                               open: { viewingTemplate = template },
                               start: { startRequest = WorkoutStartRequest(template: template) })
            // The only template: the tour's "templates" step highlights the card instead of a tile.
            .tourAnchor("tour.templates", when: otherTemplates.isEmpty)
            .id(otherTemplates.isEmpty ? "tour.templates" : "upNext")
    }

    /// Every template except the one leading the screen.
    private var otherTemplates: [WorkoutTemplate] {
        let lead = leadTemplate?.id
        return templates.filter { $0.id != lead }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            if templates.isEmpty {
                SectionHeader("Templates", level: .page)
                // First run: an invitation that shows what a template becomes (its family maps).
                VStack(spacing: look.space.grid) {
                    WorkoutTemplateInvite(action: newTemplate)
                    askAIRow
                }
            } else {
                SectionHeader(leadTemplate == nil ? "Templates" : "Other templates", level: .page)
                VStack(spacing: look.space.grid) {
                    if dynamicTypeSize.isAccessibilitySize {
                        ForEach(otherTemplates) { tile($0, stats: templateStats) }
                    } else if !otherTemplates.isEmpty {
                        grid
                    }
                    TrainMakeRow(title: "New Template…", symbol: "plus", action: newTemplate)
                        .accessibilityIdentifier("newTemplate")
                    TrainMakeRow(title: "Ask AI for Templates", symbol: "sparkles") { showingAIRoutine = true }
                        .accessibilityIdentifier("askAIRoutine")
                        .tourAnchor("tour.askAI").id("tour.askAI")
                    TrainMakeRow(title: "My Split…", symbol: "repeat") { showingMySplit = true }
                        .accessibilityIdentifier("mySplit")
                }
            }
        }
    }

    /// Two columns of the other templates in an eager `Grid` (a nested lazy grid left the first row blank on iOS 27
    /// after an AI week save — ticket 07); an odd last tile sits alone at half width.
    private var grid: some View {
        let stats = templateStats
        let others = otherTemplates
        let rows = stride(from: 0, to: others.count, by: 2).map { Array(others[$0..<min($0 + 2, others.count)]) }
        return Grid(horizontalSpacing: look.space.grid, verticalSpacing: look.space.grid) {
            ForEach(rows, id: \.first!.id) { row in
                GridRow(alignment: .top) {
                    ForEach(row) { tile($0, stats: stats) }
                    if row.count == 1 { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                }
            }
        }
    }

    private var templateStats: [UUID: TemplateStats] { TemplateStats.byTemplate(finishedWorkouts) }

    /// A tile opens the template (ticket 11). No context menu: on the phone a long-press menu
    /// deleted the wrong template (ticket 15) — Edit and Delete live on the detail.
    private func tile(_ template: WorkoutTemplate, stats: [UUID: TemplateStats]) -> some View {
        let items = WorkoutTemplateService.orderedItems(of: template)
        let names = items.compactMap { $0.exercise?.name } + template.plannedCardio.map { $0.activity.name }
        let running = activeWorkouts.first?.sourceTemplateID == template.id
        let first = template.id == otherTemplates.first?.id
        return TemplateTile(name: template.name,
                            families: MuscleFamily.families(of: items.map { $0.exercise?.muscleGroup }),
                            exercises: names, lastDone: stats[template.id]?.lastRun, now: .now) {
            viewingTemplate = template
        }
        // The template that is running carries the live pulse beside its map strip.
        .overlay(alignment: .topTrailing) {
            if running {
                ZStack {
                    Circle().fill(look.surface).frame(width: 24, height: 24)
                    WorkoutLivePulse(color: look.live, size: 9)
                }
                .padding(10)
                .allowsHitTesting(false)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityValue(running ? "In progress" : "")
        .accessibilityIdentifier("templateTile.\(template.name)")
        .tourAnchor("tour.templates", when: first)
        .id(first ? "tour.templates" : "template.\(template.id)")
    }

    private var askAIRow: some View {
        WorkoutMakeRow(title: "Ask AI for Templates", symbol: "sparkles") { showingAIRoutine = true }
            .accessibilityIdentifier("askAIRoutine")
            .tourAnchor("tour.askAI").id("tour.askAI")
    }

    private func newTemplate() {
        editingTemplate = nil
        showingTemplateEditor = true
    }

    // MARK: Gym & units

    /// Gym-level unit for the currently picked gym, falling through to the
    /// app preference (T7; no machine context here).
    private var currentUnit: WeightUnit {
        UnitPrecedence.defaultUnit(
            machineUnit: nil,
            gymUnit: selectedGym?.defaultUnit,
            appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
    }

    /// D1: restore the remembered gym at launch. An archived or deleted gym
    /// resolves to "No gym" — archival is how a gym leaves the pickers.
    private func restoreSelectedGym() {
        guard !restoredSelectedGym else { return }
        restoredSelectedGym = true
        selectedGym = GymSelection.resolve(
            id: AppPreferences.canonical(of: allPreferences)?.selectedGymID,
            among: gyms)
    }

    /// D1: every pick is remembered — the gym is the anchor of the whole
    /// equipment model, so re-choosing it each launch was a tax on the
    /// differentiator. "No gym" is itself a remembered choice.
    private func select(_ gym: Gym?) {
        selectedGym = gym
        do { try GymSelection.remember(gym, in: modelContext) }
        catch { assertionFailure("Failed to remember gym selection: \(error)") }
    }

    /// The gym is a VALUE, not a command (codex-review-10): a neutral row, the system menu
    /// lists the gyms.
    private var gymPicker: some View {
        Menu {
            Button {
                select(nil)
            } label: {
                if selectedGym == nil {
                    Label("No gym", systemImage: "checkmark")
                } else {
                    Text("No gym")
                }
            }
            ForEach(gyms) { gym in
                Button {
                    select(gym)
                } label: {
                    let title = gym.city.map { "\(gym.name) · \($0)" } ?? gym.name
                    if gym.id == selectedGym?.id {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            GymPickerLabel(name: selectedGym?.name ?? "No gym", city: selectedGym?.city, unit: currentUnit)
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(GymPickerLabel.spoken(name: selectedGym?.name ?? "No gym",
                                                  city: selectedGym?.city, unit: currentUnit))
        .accessibilityIdentifier("gymPicker")
    }
}

/// A machine's default unit in the machine pickers ("kg" / "lb"): a quiet capsule, never a command.
struct UnitBadge: View {
    var unit: WeightUnit
    @Environment(\.look) private var look

    var body: some View {
        Text(unit.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(look.textSecondary)
            .background(look.textSecondary.opacity(0.12), in: Capsule())
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    container.mainContext.insert(Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg))
    return StartWorkoutView(onWorkoutStarted: { _ in })
        .modelContainer(container)
        .environment(WorkoutHeartRateCoordinator())
}
