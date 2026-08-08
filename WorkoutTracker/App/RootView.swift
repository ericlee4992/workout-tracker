import SwiftUI

struct RootView: View {
    @StateObject private var store = SampleStore()
    @State private var selection: Tab = .workout
    @State private var showActiveWorkout = false

    enum Tab: Hashable {
        case workout, history, gyms, exercises
    }

    var body: some View {
        TabView(selection: $selection) {
            StartWorkoutView(startWorkout: { showActiveWorkout = true })
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
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView()
                .environmentObject(store)
        }
        .onAppear(perform: applyLaunchOverride)
    }

    // Lets scripted screenshot runs land on a specific screen:
    // SIMCTL_CHILD_PROTO_SCREEN=active|history|gyms|exercises
    private func applyLaunchOverride() {
        switch ProcessInfo.processInfo.environment["PROTO_SCREEN"] {
        case "active":
            showActiveWorkout = true
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
    RootView()
}
