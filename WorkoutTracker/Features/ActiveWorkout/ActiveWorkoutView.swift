import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPreferences: [AppPreferences]
    var workout: Workout

    // Rest timer is UI state only in this ticket; ticket 14 persists it.
    @State private var restEnd: Date?
    @State private var restTotal: Double = 120
    @State private var machinePickerEntry: ExerciseEntry?
    @State private var performanceEntry: ExerciseEntry?
    @State private var showExercisePicker = false
    @State private var confirmingCancel = false

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
                            setCompleted: { setType in startRest(after: setType) }
                        )
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if restEnd != nil {
                    RestTimerBar(restEnd: $restEnd, restTotal: restTotal)
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
                    Button("Finish") { finishWorkout() }
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

    private func finishWorkout() {
        do {
            try session.finish(workout)
        } catch {
            assertionFailure("Failed to finish workout: \(error)")
        }
        dismiss()
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

    /// Auto-start rest on completion (D13). Global defaults for now —
    /// per-exercise overrides and persistence land with ticket 14. Failure
    /// sets use the working duration (D22).
    private func startRest(after setType: SetType) {
        let preferences = AppPreferences.canonical(of: allPreferences)
        let seconds = setType == .warmup
            ? preferences?.globalWarmupRestSeconds ?? 60
            : preferences?.globalWorkingRestSeconds ?? 120
        restTotal = Double(seconds)
        restEnd = Date().addingTimeInterval(Double(seconds))
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
