import SwiftData
import SwiftUI

@main
struct WorkoutTrackerApp: App {
    /// On-disk SwiftData store (Domain/Models.swift). The UI still renders
    /// prototype sample data until ticket 07 rewires it onto this container.
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try WorkoutTrackerStore.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
