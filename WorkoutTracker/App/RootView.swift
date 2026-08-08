import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    // History stays on sample data until ticket 09 rewires it.
    @StateObject private var store = SampleStore()
    @State private var selection: Tab = .workout
    @State private var activeWorkout: Workout?

    enum Tab: Hashable {
        case workout, history, gyms, exercises
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
        .environmentObject(store)
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(workout: workout)
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
    // SIMCTL_CHILD_PROTO_SCREEN=history|gyms|exercises
    // ("active" was a milestone-1 deep link; the live screen now requires a
    // real persisted workout.)
    private func applyLaunchOverride() {
        switch ProcessInfo.processInfo.environment["PROTO_SCREEN"] {
        case "history", "detail":
            selection = .history
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
