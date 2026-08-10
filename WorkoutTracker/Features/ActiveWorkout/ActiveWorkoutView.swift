import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var workout: Workout
    /// C1: dismisses the cover while the workout keeps running — the Workout
    /// tab then shows a resume affordance. Defaults to a plain dismiss.
    var onMinimize: (() -> Void)?
    /// C2: hands the finished workout back so the presenter can confirm what
    /// was saved. Not called when nothing survived the finish cleanup.
    var onFinished: ((Workout) -> Void)?

    @State private var restEnd: Date?
    @State private var restTotal: Double = 120
    @State private var machinePickerEntry: ExerciseEntry?
    @State private var performanceEntry: ExerciseEntry?
    @State private var showExercisePicker = false
    @State private var showMachinePicker = false
    @State private var confirmingCancel = false
    @State private var driftTemplate: WorkoutTemplate?
    @State private var choosingDriftResolution = false

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    private var entries: [ExerciseEntry] {
        workout.isDeleted ? [] : WorkoutSession.orderedEntries(of: workout)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    ForEach(entries) { entry in
                        ExerciseEntryCard(
                            entry: entry,
                            showMachinePicker: { machinePickerEntry = entry },
                            showPerformance: { performanceEntry = entry },
                            completionChanged: { set, completed in
                                updateRest(for: set, isCompleted: completed)
                            }
                        )
                    }

                    HStack(spacing: 12) {
                        Button {
                            showExercisePicker = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("addExercise")
                        // Machine-first path (D7): hidden for no-gym workouts —
                        // there are no machines to list.
                        if !workout.isDeleted, workout.gym != nil {
                            Button {
                                showMachinePicker = true
                            } label: {
                                Label("Add by Machine", systemImage: "figure.strengthtraining.traditional")
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityIdentifier("addByMachine")
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if let restEnd {
                    RestTimerBar(
                        restEnd: restEnd,
                        restTotal: restTotal,
                        addFifteen: addFifteen,
                        skip: skipRest,
                        expired: refreshRest)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // C1: leaving an active workout no longer means finishing or
                // discarding it — minimise keeps it running behind the tabs.
                ToolbarItem(placement: .topBarLeading) {
                    Button { minimize() } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityIdentifier("minimizeWorkout")
                    .accessibilityLabel("Minimize workout")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { confirmingCancel = true }
                        .tint(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finishTapped() }
                        .font(.headline)
                        .accessibilityIdentifier("finishWorkout")
                }
            }
            .confirmationDialog(
                "Cancel this workout?",
                isPresented: $confirmingCancel,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive) { cancelWorkout() }
                Button("Keep Logging", role: .cancel) {}
            } message: {
                Text("The workout and everything logged in it will be deleted.")
            }
            .templateDriftDialog(
                isPresented: $choosingDriftResolution,
                message: "This workout's completed exercises, set counts, or target reps differ from the template.",
                cancelLabel: "Keep Logging",
                resolve: finishTemplatedWorkout)
            .sheet(item: $machinePickerEntry) { entry in
                MachinePickerSheet(entry: entry)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $performanceEntry) { entry in
                PreviousPerformanceSheet(entry: entry)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercise in
                    addEntry(for: exercise)
                }
            }
            .sheet(isPresented: $showMachinePicker) {
                AddByMachineSheet(workout: workout)
                    .presentationDetents([.medium, .large])
            }
            .onAppear(perform: refreshRest)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshRest() }
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.tint)
            Text(workout.isDeleted ? "" : (workout.gym?.name ?? "No gym"))
                .font(.subheadline.weight(.medium))
            Spacer()
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                Label("\(elapsedMinutes(at: timeline.date)) min", systemImage: "timer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private func elapsedMinutes(at date: Date) -> Int {
        guard !workout.isDeleted else { return 0 }
        return max(0, Int(date.timeIntervalSince(workout.startedAt) / 60))
    }

    // MARK: Actions

    private func minimize() {
        if let onMinimize {
            onMinimize()
        } else {
            dismiss()
        }
    }

    /// B2: Finish finishes. A from-scratch workout gets no pre-finish
    /// interrogation — save-as-template moved to the post-finish confirmation
    /// (C2), where it is offered once the workout is safely stored. The
    /// template-drift prompt (D18) survives, but only for workouts that
    /// actually came from a template.
    private func finishTapped() {
        if workout.sourceTemplateID == nil {
            finishWorkout()
            return
        }
        do {
            let drift = TemplateDriftService(context: modelContext)
            if let template = try drift.sourceTemplate(for: workout),
               try drift.shouldPrompt(for: workout, template: template) {
                driftTemplate = template
                choosingDriftResolution = true
            } else {
                finishWorkout()
            }
        } catch {
            assertionFailure("Failed to inspect template drift: \(error)")
        }
    }

    // `session.finish` / `session.cancel` end the rest timer (state and
    // pending notification) themselves — call sites no longer skip first.
    private func finishWorkout() {
        do {
            try session.finish(workout)
        } catch {
            assertionFailure("Failed to finish workout: \(error)")
        }
        reportFinished()
    }

    private func finishTemplatedWorkout(using resolution: TemplateDriftResolution) {
        do {
            if let driftTemplate {
                try TemplateDriftService(context: modelContext).resolve(
                    resolution, workout: workout, to: driftTemplate)
            } else {
                try session.finish(workout)
            }
        } catch {
            assertionFailure("Failed to finish templated workout: \(error)")
        }
        driftTemplate = nil
        reportFinished()
    }

    /// C2: hand the stored workout to the presenter so it can confirm what
    /// was saved. A workout that finish cleanup emptied out (nothing logged)
    /// has nothing to confirm — and may have been deleted outright — so it
    /// just dismisses.
    private func reportFinished() {
        if let onFinished, !workout.isDeleted, workout.finishedAt != nil {
            onFinished(workout)
        } else {
            dismiss()
        }
    }

    private func cancelWorkout() {
        do {
            try session.cancel(workout)
        } catch {
            assertionFailure("Failed to cancel workout: \(error)")
        }
        dismiss()
    }

    private func addEntry(for exercise: Exercise) {
        do {
            try session.addEntry(
                for: exercise,
                to: workout,
                freeWeightTag: exercise.equipmentTypeTags.first { $0 != .machine })
        } catch {
            assertionFailure("Failed to add entry: \(error)")
        }
    }

    private var restTimer: RestTimerService {
        RestTimerService(context: modelContext)
    }

    private func updateRest(for set: SetRecord, isCompleted: Bool) {
        do {
            showRestTimer(try restTimer.handleCompletionChange(
                of: set, isCompleted: isCompleted))
        } catch {
            assertionFailure("Failed to update rest timer: \(error)")
        }
    }

    private func addFifteen() {
        do { showRestTimer(try restTimer.add(seconds: 15, to: workout)) }
        catch { assertionFailure("Failed to extend rest timer: \(error)") }
    }

    private func skipRest() {
        do {
            try restTimer.skip(workout)
            restEnd = nil
        } catch {
            assertionFailure("Failed to skip rest timer: \(error)")
        }
    }

    private func refreshRest() {
        do { showRestTimer(try restTimer.currentState(for: workout)) }
        catch { assertionFailure("Failed to restore rest timer: \(error)") }
    }

    /// Drives the rest bar from a timer state. The progress denominator is the
    /// state's *total* duration — using the remaining time would make a bar
    /// restored mid-rest jump straight back to full.
    private func showRestTimer(_ state: RestTimerState?) {
        restEnd = state?.end
        if let state { restTotal = max(1, state.total) }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let context = container.mainContext
    let gym = Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg)
    context.insert(gym)
    let workout = Workout(gym: gym)
    context.insert(workout)
    let exercise = Exercise(name: "Seated Chest Press")
    context.insert(exercise)
    try? WorkoutSession(context: context).addEntry(for: exercise, to: workout)
    return ActiveWorkoutView(workout: workout)
        .modelContainer(container)
}
