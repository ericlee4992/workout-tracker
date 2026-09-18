import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
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
    /// One template column at accessibility sizes: two tiles of icons, a
    /// name and the exercise line do not share 390 pt at AccessibilityL.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The pin tile grows with its glyph (`.title2`).
    @ScaledMetric(relativeTo: .title2) private var pinTile: CGFloat = 44
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
    /// Called with the workout to present — freshly started or resumed.
    var onWorkoutStarted: (Workout) -> Void

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    gymPicker
                        .padding(20)
                        .card()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                // Ticket 10: ONE action, one capsule. With a workout live it
                // reads Resume (the user's choice, 2026-09-11): the way back
                // in is the same button as the way in, never two amber
                // commands. Starting a template while live still goes
                // through the "already in progress" dialog.
                Section {
                    heroCapsule
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if activeWorkouts.isEmpty {
                    Section {
                        Button { showingCardioPicker = true } label: {
                            Label("Start Cardio", systemImage: "figure.run").frame(maxWidth: .infinity)
                        }.buttonStyle(.secondary).accessibilityIdentifier("startCardio")
                            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    }
                }
                Section("Templates") {
                    // Ticket 10: a two-column grid of tiles (the user chose
                    // direction C's templates). Ticket 11: the tile OPENS the
                    // template (its exercises, then Start) — the user asked to
                    // see the list before starting. Ticket 15: Edit and Delete
                    // are on the opened template, nowhere else.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                              spacing: 10) {
                        ForEach(templates) { template in
                            Button { viewingTemplate = template } label: {
                                TemplateTile(template: template)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("templateTile.\(template.name)")
                            // Ticket 15: no long-press menu. On the phone the
                            // tile's context menu deleted the OTHER template.
                            // Suspected cause, not proven (codex-review-15): the
                            // grid is one List row holding several context menus,
                            // and the press was attributed to the wrong one. Edit
                            // and Delete live on the opened template instead.
                        }
                        Button {
                            editingTemplate = nil
                            showingTemplateEditor = true
                        } label: {
                            VStack(spacing: Theme.Space.small) {
                                Image(systemName: "plus").font(.title3.weight(.semibold))
                                Text("New Template…").font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 118)
                            .padding(Theme.Space.medium)
                            .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    Text("Machines resolve to your last-used at \(selectedGym?.name ?? "your gym")")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 0))
                }
            }
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .background(Theme.background)
            .navigationTitle("Workout")
            // Ticket 05: Settings behind a gear here, not at the foot of the
            // Gyms list (the user's choice, 2026-09-10).
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("openSettings")
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
            .sheet(isPresented: $showingCardioPicker) {
                CardioActivityPicker { activity in
                    showingCardioPicker = false
                    startRequest = WorkoutStartRequest(template: nil, cardioActivity: activity)
                }
            }
            .sheet(isPresented: $showingTemplateEditor) {
                TemplateEditorSheet(template: editingTemplate)
            }
            .onAppear(perform: restoreSelectedGym)
        }
    }

    /// The screen's one action: Start Empty Workout, or — the moment a
    /// workout is live — Resume workout with where it stands (C1: the way
    /// back into a minimised workout). Same capsule, same place.
    @ViewBuilder
    private var heroCapsule: some View {
        if let active = activeWorkouts.first, !active.isDeleted {
            Button { resumeActive() } label: {
                HeroCapsuleLabel(title: "Resume workout", subtitle: resumeSubtitle(active),
                                 symbol: active.unfinishedCardio?.activity.symbol ?? "figure.strengthtraining.traditional", trailing: "chevron.right",
                                 live: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumeWorkout")
        } else {
            Button { startRequest = WorkoutStartRequest(template: nil) } label: {
                HeroCapsuleLabel(title: "Start Lifting", subtitle: nil,
                                 symbol: "figure.strengthtraining.traditional", trailing: "arrow.up.right",
                                 live: false)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.workoutStart, trigger: activeWorkouts.count)
            .accessibilityIdentifier("startEmptyWorkout")
        }
    }

    private func resumeSubtitle(_ workout: Workout) -> String {
        let count = WorkoutSession.orderedEntries(of: workout).count
        let exercises = count > 0 ? "\(count) \(count == 1 ? "exercise" : "exercises")"
            : (workout.unfinishedCardio?.activity.name
               ?? HistoryRendering.pluralized(workout.recordedCardio.count, "cardio activity", "cardio activities"))
        guard let gymName = workout.gym?.name else { return "In progress · \(exercises)" }
        return "\(gymName) · \(exercises)"
    }

    // MARK: Start flow — `WorkoutStartFlow` (ticket 11); Resume needs no dialog.

    private func resumeActive() {
        if let workout = try? session.resumableWorkout() {
            onWorkoutStarted(workout)
        }
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
            // Neutral text — a Menu tints its label with the accent, and the
            // gym is a VALUE, not a command (codex-review-10). Accessories
            // stack under the text at accessibility sizes.
            let stacked = dynamicTypeSize.isAccessibilitySize
            let layout = stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.small))
                : AnyLayout(HStackLayout(spacing: Theme.Space.medium))
            layout {
                HStack(spacing: Theme.Space.medium) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: pinTile, height: pinTile)
                        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedGym?.name ?? "No gym")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text(selectedGym.map { $0.city ?? "" } ?? "Home / no location")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                    if !stacked { Spacer(minLength: 0) }
                }
                HStack(spacing: Theme.Space.small) {
                    if stacked { Spacer(minLength: 0) }
                    UnitBadge(unit: currentUnit)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .accessibilityIdentifier("gymPicker")
    }
}

/// Ticket 10: the amber capsule — the figure in an ink disc, one or two
/// lines, a trailing symbol. Hugging, not a slab: the user found the
/// full-width hero "too big and too mundane". Ticket 11: the template
/// detail's Start wears it too.
struct HeroCapsuleLabel: View {
    var title: String
    var subtitle: String?
    var symbol: String
    var trailing: String
    var live: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The ink disc grows with its glyph (`.body`) — codex-review-10 saw the
    /// figure flush with a fixed 40 pt disc at AXL.
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var dot: CGFloat = 9
    @State private var breathing = false

    var body: some View {
        HStack(spacing: Theme.Space.medium) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: disc, height: disc)
                    .background(Theme.onAccent, in: Circle())
                if live {
                    // Inside the ink disc — amber on ink; at its edge the dot
                    // sat amber on the amber capsule and vanished. Geometry,
                    // scaled with the disc; it breathes unless Reduce Motion.
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: dot, height: dot)
                        .opacity(breathing || reduceMotion ? 1 : 0.35)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true), value: breathing)
                        .onAppear { breathing = true }
                        .offset(x: -dot * 0.55, y: dot * 0.55)
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body.weight(.bold))
                if let subtitle {
                    Text(subtitle).font(.caption.weight(.medium)).opacity(0.8)
                }
            }
            Image(systemName: trailing)
                .font(.body.weight(.bold))
        }
        .foregroundStyle(Theme.onAccent)
        .padding(.leading, 8)
        .padding(.trailing, 20)
        .frame(minHeight: 56)
        .background(Theme.accent, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Ticket 10: a template as a tile — its muscle icons, its name, its
/// exercises. The whole tile opens the template (ticket 11). The icons are
/// the FAMILIES the template trains (chest, back, shoulders, arms, legs),
/// each once, head to toe — not one per exercise (ticket 11, the user).
private struct TemplateTile: View {
    var template: WorkoutTemplate

    var body: some View {
        let items = WorkoutTemplateService.orderedItems(of: template)
        let families = MuscleFamily.families(of: items.map { $0.exercise?.muscleGroup })
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            if !families.isEmpty {
                MuscleFamilyStrip(families: families, size: 24)
            }
            Text(template.name)
                .font(Theme.cardTitle)
            // Whole, never truncated: the tile grows with its exercises
            // (codex-review-10); the grid row takes the tallest tile.
            Text(items.compactMap { $0.exercise?.name }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(Theme.Space.medium)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }
}

struct UnitBadge: View {
    var unit: WeightUnit

    var body: some View {
        UnitChip(unit: unit)
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
