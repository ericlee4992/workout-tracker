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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                if let active = activeWorkouts.first, !active.isDeleted {
                    Section {
                        resumeRow(active)
                            .padding(16)
                            .card()
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.accent.opacity(0.5)))
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section {
                    gymPicker
                        .padding(20)
                        .card()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    Button { startTapped(template: nil) } label: {
                        HStack {
                            Text("Start Empty Workout").font(Theme.stat)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.title2.weight(.bold))
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.primary)
                    .sensoryFeedback(.workoutStart, trigger: activeWorkouts.count)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("startEmptyWorkout")
                }

                Section("Templates") {
                    ForEach(templates) { template in
                        TemplateRow(
                            template: template,
                            gymName: selectedGym?.name ?? "your gym",
                            start: { startTapped(template: template) })
                        .padding(16)
                        .card()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .contextMenu {
                            Button("Edit…") {
                                editingTemplate = template
                                showingTemplateEditor = true
                            }
                            Button("Delete", role: .destructive) {
                                delete(template)
                            }
                        }
                        // Swipe to delete as well as the long-press menu
                        // (requested 2026-08-26). No confirmation here, unlike
                        // history: deleting a template loses a plan, not a
                        // record of something that happened — and D23 keeps the
                        // workouts it produced, since they carry their own
                        // snapshot of its name.
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    Button("New Template…", systemImage: "plus") {
                        editingTemplate = nil
                        showingTemplateEditor = true
                    }
                    .buttonStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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

    /// The way back into a minimised workout (C1). Resuming re-presents the
    /// newest active workout, auto-finishing older strays exactly as the
    /// relaunch recovery does.
    private func resumeRow(_ workout: Workout) -> some View {
        Button {
            resumeActive()
        } label: {
            HStack {
                // Ticket 04: a live workout gets a pulsing accent dot beside
                // the figure — the banner is the one thing on the screen that
                // is happening right now.
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.accent)
                        // Explicitly still under Reduce Motion (codex-review-0405).
                        .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                        .offset(x: 2, y: -2)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resume workout")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(resumeSubtitle(workout))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("resumeWorkout")
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

private struct TemplateRow: View {
    var template: WorkoutTemplate
    var gymName: String
    var start: () -> Void
    /// At accessibility sizes the Start button sits UNDER the text instead of
    /// beside it, and the icon strip wraps — five scaled tiles no longer fit
    /// one line (UI redesign ticket 08, codex-review-08).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.medium))
            : AnyLayout(HStackLayout(alignment: .center))
        layout {
            VStack(alignment: .leading, spacing: 12) {
                WrapLayout {
                    ForEach(Array(WorkoutTemplateService.orderedItems(of: template).prefix(5))) { item in
                        MuscleIcon(group: item.exercise?.muscleGroup)
                    }
                }
                Text(template.name)
                    .font(.headline)
                Text(WorkoutTemplateService.orderedItems(of: template)
                    .compactMap { $0.exercise?.name }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Machines resolve to your last-used at \(gymName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !stacked { Spacer() }
            Button("Start", action: start)
                .buttonStyle(.primary)
        }
        .padding(.vertical, 4)
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
