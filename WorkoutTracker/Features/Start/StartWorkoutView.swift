import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    /// To bank the active workout's heart-rate summary before "Finish it and
    /// start new" auto-finishes it inside `startWorkout` (codex-review 05).
    @Environment(WorkoutHeartRateCoordinator.self) private var heartRateCoordinator
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
    /// One template column at accessibility sizes: two tiles of five icons,
    /// a name and two lines do not share 390 pt at AccessibilityL.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedGym: Gym?
    /// D1: the stored pick is read once per screen lifetime — re-reading it
    /// would fight the user's in-session choice.
    @State private var restoredSelectedGym = false
    @State private var showingResumeDialog = false
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showingTemplateEditor = false
    @State private var replacementWorkout: Workout?
    @State private var replacementSourceTemplate: WorkoutTemplate?
    @State private var showingReplacementDrift = false
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

                Section("Templates") {
                    // Ticket 10: a two-column grid of tiles (the user chose
                    // direction C's templates). The tile IS the start button;
                    // Edit/Delete live on the long-press menu — a grid has no
                    // swipe, and deleting a plan is not a record lost (D23).
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                              spacing: 10) {
                        ForEach(templates) { template in
                            Button { startTapped(template: template) } label: {
                                TemplateTile(template: template)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("templateTile.\(template.name)")
                            .contextMenu {
                                Button("Edit…") {
                                    editingTemplate = template
                                    showingTemplateEditor = true
                                }
                                Button("Delete", role: .destructive) {
                                    delete(template)
                                }
                            }
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
            .confirmationDialog(
                "A workout is already in progress",
                isPresented: $showingResumeDialog,
                titleVisibility: .visible
            ) {
                Button("Resume Workout") { resumeActive() }
                Button("Finish It & Start New") { finishActiveThenStartTapped() }
                Button("Cancel", role: .cancel) {}
            } message: {
                // A consequence, not a tutorial: finishing discards every
                // uncompleted set (codex-review 06).
                Text("Only its completed sets are kept.")
            }
            .templateDriftDialog(
                isPresented: $showingReplacementDrift,
                message: "The active workout differs from the template it started from. Choose how to save that template before starting the next workout.",
                cancelLabel: "Keep Current Workout",
                resolve: resolveReplacementDrift)
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
                                 symbol: "figure.strengthtraining.traditional", trailing: "chevron.right",
                                 live: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumeWorkout")
        } else {
            Button { startTapped(template: nil) } label: {
                HeroCapsuleLabel(title: "Start Empty Workout", subtitle: nil,
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
        let exercises = "\(count) \(count == 1 ? "exercise" : "exercises")"
        guard let gymName = workout.gym?.name else { return "In progress · \(exercises)" }
        return "\(gymName) · \(exercises)"
    }

    // MARK: Start flow

    /// Start-while-active offers Resume or Finish-and-start-new.
    private func startTapped(template: WorkoutTemplate?) {
        pendingTemplate = template
        if (try? session.resumableWorkout()) != nil {
            showingResumeDialog = true
        } else {
            startNew()
        }
    }

    private func startNew() {
        do {
            // Any still-active workout is auto-finished by `startWorkout`,
            // which ends its rest timer and pending notification — but NOT its
            // heart-rate session, which lives in the coordinator. Bank and end
            // it here first, or the replaced workout reaches History with no
            // summary (codex-review 05, critical).
            if let active = try session.resumableWorkout() {
                heartRateCoordinator.end(active)
            }
            let workout: Workout
            if let template = pendingTemplate {
                workout = try WorkoutTemplateService(context: modelContext)
                    .start(template, at: selectedGym)
            } else {
                workout = try session.startWorkout(at: selectedGym)
            }
            pendingTemplate = nil
            onWorkoutStarted(workout)
        } catch {
            assertionFailure("Failed to start workout: \(error)")
        }
    }

    private func finishActiveThenStartTapped() {
        do {
            guard let active = try session.resumableWorkout() else {
                startNew()
                return
            }
            let drift = TemplateDriftService(context: modelContext)
            if let template = try drift.sourceTemplate(for: active),
               try drift.shouldPrompt(for: active, template: template) {
                replacementWorkout = active
                replacementSourceTemplate = template
                showingReplacementDrift = true
            } else {
                startNew()
            }
        } catch {
            assertionFailure("Failed to inspect active workout drift: \(error)")
        }
    }

    private func resolveReplacementDrift(_ resolution: TemplateDriftResolution) {
        do {
            if let workout = replacementWorkout,
               let template = replacementSourceTemplate {
                // BEFORE resolve, which finishes and saves the workout: after
                // that it is no longer resumable, `startNew` would find nothing
                // to end, and the summary would be lost (codex-review 05b,
                // critical). Banked here while this view still holds it.
                heartRateCoordinator.end(workout)
                try TemplateDriftService(context: modelContext).resolve(
                    resolution, workout: workout, to: template)
            }
            replacementWorkout = nil
            replacementSourceTemplate = nil
            startNew()
        } catch {
            assertionFailure("Failed to resolve template before starting: \(error)")
        }
    }

    private func resumeActive() {
        pendingTemplate = nil
        if let workout = try? session.resumableWorkout() {
            onWorkoutStarted(workout)
        }
    }

    private func delete(_ template: WorkoutTemplate) {
        do { try WorkoutTemplateService(context: modelContext).delete(template) }
        catch { assertionFailure("Failed to delete template: \(error)") }
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
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedGym?.name ?? "No gym")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(selectedGym.map { $0.city ?? "" } ?? "Home / no location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UnitBadge(unit: currentUnit)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("gymPicker")
    }
}

/// Ticket 10: the amber capsule — the figure in an ink disc, one or two
/// lines, a trailing symbol. Hugging, not a slab: the user found the
/// full-width hero "too big and too mundane".
private struct HeroCapsuleLabel: View {
    var title: String
    var subtitle: String?
    var symbol: String
    var trailing: String
    var live: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Space.medium) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.onAccent, in: Circle())
                if live {
                    // Inside the ink disc — amber on ink; at its edge the dot
                    // sat amber on the amber capsule and vanished.
                    Image(systemName: "circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                        .offset(x: -5, y: 5)
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
/// exercises on two lines. The whole tile starts the template.
private struct TemplateTile: View {
    var template: WorkoutTemplate

    var body: some View {
        let items = WorkoutTemplateService.orderedItems(of: template)
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            WrapLayout {
                ForEach(Array(items.prefix(5))) { item in
                    MuscleIcon(group: item.exercise?.muscleGroup, size: 24)
                }
            }
            Text(template.name)
                .font(Theme.cardTitle)
            Text(items.compactMap { $0.exercise?.name }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .lineLimit(2)
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
