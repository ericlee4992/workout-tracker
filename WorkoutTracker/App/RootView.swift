import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Tab = .workout
    @State private var activeWorkout: Workout?
    /// Owns the heart-rate session for whichever workout is running
    /// (codex-review-2 #2). Lives here, not on the workout screen, because
    /// minimise dismisses that screen while the workout keeps going.
    /// Created with the app by `WorkoutActivityCommands` (ticket 11: a lock-screen command can
    /// arrive before this view exists) and borrowed here.
    @State private var heartRateCoordinator = WorkoutActivityCommands.shared.coordinator
    /// Owned at the same level as the heart-rate session, and for the same
    /// reason (codex-review-2 #2): C1's minimise dismisses the workout SCREEN
    /// while the workout keeps running, so a screen-owned activity would end
    /// the moment the user left the app — which is exactly when a lock-screen
    /// card is worth having.
    @State private var workoutActivity = WorkoutActivityCommands.shared.activity
    /// C2/A2: the finish that just happened, awaiting its confirmation sheet.
    @State private var finishConfirmation: FinishConfirmation?
    /// C2: the workout History should open — selecting the tab is not the
    /// same as showing the workout that was just logged.
    @State private var historyTarget: Workout?
    /// History's empty screen asked for Start Lifting (ticket 05).
    @State private var startLiftingFromHistory = false
    /// Public beta ticket 02: the guided tour, when one runs; it selects each step's tab.
    @Environment(TourController.self) private var tour: TourController?

    enum Tab: Hashable {
        case workout, history, gyms, exercises
    }

    private static func tab(for step: TourStep.Tab) -> Tab {
        switch step {
        case .workout: .workout
        case .history: .history
        case .gyms: .gyms
        case .exercises: .exercises
        }
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
            StartWorkoutView(onWorkoutStarted: { activeWorkout = $0 },
                             startLiftingRequest: $startLiftingFromHistory)
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.workout)

            HistoryView(target: $historyTarget, onStartLifting: {
                selection = .workout
                startLiftingFromHistory = true
            })
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            GymsView()
                .tabItem { Label("Gyms", systemImage: "building.2") }
                .tag(Tab.gyms)

            ExercisesView()
                .tabItem { Label("Exercises", systemImage: "list.bullet.rectangle") }
                .tag(Tab.exercises)
        }
        // The coordinator is owned here and read by the Start screen too: it
        // must bank the active workout's summary before "Finish it and start
        // new" auto-finishes that workout (codex-review 05).
        .tint(Color.accentColor)
        .onChange(of: tour?.current?.tab) { _, tab in
            if let tab { selection = Self.tab(for: tab) }
        }
        // The tab bar is UIKit and ignores `.disabled`: VoiceOver or a keyboard can still switch tabs under the tour
        // (codex-review-02 #1). Harmless on the sample world, but the tour owns the tab: any other change snaps back.
        .onChange(of: selection) { _, new in
            guard let tab = tour?.current?.tab, new != Self.tab(for: tab) else { return }
            selection = Self.tab(for: tab)
        }
        .environment(heartRateCoordinator)
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
            .environment(heartRateCoordinator)
                .environment(workoutActivity)
        }
        .sheet(item: $finishConfirmation) { confirmation in
            WorkoutFinishedSheet(
                workout: confirmation.workout,
                viewInHistory: {
                    let finished = confirmation.workout
                    finishConfirmation = nil
                    selection = .history
                    historyTarget = finished
                },
                done: { finishConfirmation = nil })
            // The finish sheet sizes itself (`.large`): the workout summary
            // does not fit a medium detent, and hiding the actions under it is
            // how "View in History" became unreachable.
        }
        .onAppear(perform: recoverActiveWorkout)
        .onAppear(perform: applyLaunchOverride)
    }

    /// Relaunch resumes the newest active workout; older strays are
    /// auto-finished by the service (exactly-one-active invariant).
    private func recoverActiveWorkout() {
        // Never in the guided tour's sample world (ticket 02): opening a workout drives HealthKit, the Live
        // Activity and notifications, which the tour must not touch. Its sample has no unfinished workout anyway.
        guard tour == nil, activeWorkout == nil else { return }
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
