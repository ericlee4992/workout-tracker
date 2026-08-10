import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Tab = .workout
    @State private var activeWorkout: Workout?
    /// C2/A2: the finish that just happened, awaiting its confirmation sheet.
    @State private var finishConfirmation: FinishConfirmation?

    enum Tab: Hashable {
        case workout, history, gyms, exercises
    }

    /// The subject of the post-finish sheet. `workout` is nil when the
    /// workout was empty and got discarded (A2) — the sheet still shows, it
    /// just reports a different outcome. Identity is per-finish rather than
    /// per-workout so the discarded case can be presented at all.
    private struct FinishConfirmation: Identifiable {
        let id = UUID()
        let workout: Workout?
    }

    var body: some View {
        TabView(selection: $selection) {
            StartWorkoutView(onWorkoutStarted: { activeWorkout = $0 })
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.workout)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            GymsView()
                .tabItem { Label("Gyms", systemImage: "building.2") }
                .tag(Tab.gyms)

            ExercisesView()
                .tabItem { Label("Exercises", systemImage: "list.bullet.rectangle") }
                .tag(Tab.exercises)
        }
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(
                workout: workout,
                // C1: minimising drops the cover and leaves the workout
                // active; StartWorkoutView shows the resume affordance.
                onMinimize: { activeWorkout = nil },
                onFinished: { finished in
                    activeWorkout = nil
                    finishConfirmation = FinishConfirmation(workout: finished)
                })
        }
        .sheet(item: $finishConfirmation) { confirmation in
            WorkoutFinishedSheet(
                workout: confirmation.workout,
                viewInHistory: {
                    finishConfirmation = nil
                    selection = .history
                },
                done: { finishConfirmation = nil })
            .presentationDetents([.medium])
        }
        .onAppear(perform: recoverActiveWorkout)
        .onAppear(perform: applyLaunchOverride)
    }

    /// Relaunch resumes the newest active workout; older strays are
    /// auto-finished by the service (exactly-one-active invariant).
    private func recoverActiveWorkout() {
        guard activeWorkout == nil else { return }
        activeWorkout = try? WorkoutSession(context: modelContext).resumableWorkout()
    }

    // Lets scripted screenshot runs land on a specific screen:
    // SIMCTL_CHILD_PROTO_SCREEN=gyms|exercises
    // ("active", "history", and "detail" were milestone-1 deep links; those
    // screens now render real persisted data.)
    private func applyLaunchOverride() {
        switch ProcessInfo.processInfo.environment["PROTO_SCREEN"] {
        case "gyms":
            selection = .gyms
        case "exercises":
            selection = .exercises
        default:
            break
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    return RootView()
        .modelContainer(container)
}
