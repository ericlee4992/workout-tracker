import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var workout: Workout

    @State private var restEnd: Date?
    @State private var restTotal: Double = 120
    @State private var machinePickerEntry: ExerciseEntry?
    @State private var performanceEntry: ExerciseEntry?
    @State private var showExercisePicker = false
    @State private var showMachinePicker = false
    @State private var confirmingCancel = false
    @State private var choosingFromScratchFinish = false
    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var templateFailure: String?
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
                        // Machine-first path (D7): hidden for no-gym workouts —
                        // there are no machines to list.
                        if !workout.isDeleted, workout.gym != nil {
                            Button {
                                showMachinePicker = true
                            } label: {
                                Label("Add by Machine", systemImage: "figure.strengthtraining.traditional")
                                    .frame(maxWidth: .infinity)
                            }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { confirmingCancel = true }
                        .tint(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finishTapped() }
                        .font(.headline)
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
            .confirmationDialog(
                "Finish workout",
                isPresented: $choosingFromScratchFinish,
                titleVisibility: .visible
            ) {
                // Only offered when it can actually succeed — see
                // `canSaveAsTemplate`.
                Button("Finish & Save as Template") {
                    templateName = defaultTemplateName
                    namingTemplate = true
                }
                Button("Finish") { finishWorkout() }
                Button("Keep Logging", role: .cancel) {}
            } message: {
                Text("You can keep the completed exercise and set structure as a reusable template.")
            }
            .alert("Save as Template", isPresented: $namingTemplate) {
                TextField("Template name", text: $templateName)
                Button("Save") { finishAndSaveTemplate() }
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Completed sets become target set and rep slots. Weights and rest times are not saved.")
            }
            .alert(
                "Couldn't Save Template",
                isPresented: Binding(
                    get: { templateFailure != nil },
                    set: { if !$0 { templateFailure = nil } })
            ) {
                Button("OK", role: .cancel) { templateFailure = nil }
            } message: {
                Text(templateFailure ?? "")
            }
            .confirmationDialog(
                "Update workout template?",
                isPresented: $choosingDriftResolution,
                titleVisibility: .visible
            ) {
                Button("Update Template") {
                    finishTemplatedWorkout(using: .updateTemplate)
                }
                Button("Update Values Only") {
                    finishTemplatedWorkout(using: .updateValuesOnly)
                }
                Button("Update Both") {
                    finishTemplatedWorkout(using: .updateBoth)
                }
                Button("Keep Original") {
                    finishTemplatedWorkout(using: .keepOriginal)
                }
                Button("Keep Logging", role: .cancel) {}
            } message: {
                Text("This workout's completed exercises, set counts, or target reps differ from the template.")
            }
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

    /// A from-scratch workout can only become a template once something has
    /// been completed — `saveAsTemplate` captures completed sets only and
    /// throws `noExercises` otherwise. Offering the option when it cannot
    /// succeed used to finish the workout and then fail.
    private var canSaveAsTemplate: Bool {
        WorkoutTemplateService.canSaveAsTemplate(workout)
    }

    private func finishTapped() {
        if workout.sourceTemplateID == nil {
            if canSaveAsTemplate {
                choosingFromScratchFinish = true
            } else {
                finishWorkout()
            }
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
        dismiss()
    }

    /// Capture the template BEFORE finishing: a failure must leave the
    /// workout untouched and tell the user, not finish it and swallow the
    /// error. Capture reads completed sets only, so the result is identical
    /// either side of `finish`.
    private func finishAndSaveTemplate() {
        do {
            try WorkoutTemplateService(context: modelContext).saveAsTemplate(
                workout,
                name: templateName)
        } catch {
            templateFailure = Self.templateFailureMessage(error)
            return
        }
        finishWorkout()
    }

    private static func templateFailureMessage(_ error: Error) -> String {
        switch error as? WorkoutTemplateError {
        case .emptyName:
            return "Give the template a name and try again."
        case .noExercises:
            return "This workout has no completed sets yet, so there is nothing to save as a template. Complete a set first, or finish without saving."
        case nil:
            return "The template could not be saved: \(error.localizedDescription)"
        }
    }

    private func finishTemplatedWorkout(using resolution: TemplateDriftResolution) {
        do {
            if let driftTemplate {
                try TemplateDriftService(context: modelContext).apply(
                    resolution, workout: workout, to: driftTemplate)
            }
            try session.finish(workout)
        } catch {
            assertionFailure("Failed to finish templated workout: \(error)")
        }
        driftTemplate = nil
        dismiss()
    }

    private var defaultTemplateName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Workout \(formatter.string(from: workout.startedAt))"
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
