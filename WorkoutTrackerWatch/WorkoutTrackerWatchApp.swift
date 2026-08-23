import SwiftUI

// Milestone 7, ticket 02 — the watchOS companion's shell. The session and the
// streaming land in ticket 04; this exists so the target is real, buildable and
// installable before any of that is written.

@main
struct WorkoutTrackerWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
