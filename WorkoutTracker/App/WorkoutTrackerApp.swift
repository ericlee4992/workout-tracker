import SwiftData
import SwiftUI

@main
struct WorkoutTrackerApp: App {
    /// On-disk SwiftData store (Domain/Models.swift). The UI still renders
    /// prototype sample data until ticket 07 rewires it onto this container.
    private let modelContainer: ModelContainer

    init() {
        do {
            // `-uiTestReset` starts from an empty throwaway store so UI tests
            // never inherit state from a previous run.
            modelContainer = WorkoutTrackerStore.isUITestReset
                ? try WorkoutTrackerStore.makeUITestContainer()
                : try WorkoutTrackerStore.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        // Versioned idempotent catalog seeding on every launch (D24). A
        // failure must not block launch — the catalog reconciles next run.
        do {
            let catalog = try SeedCatalog.bundled()
            try CatalogSeeder.reconcile(catalog, in: modelContainer.mainContext)
        } catch {
            assertionFailure("Catalog seeding failed: \(error)")
        }
        // A few weeks of history for one exercise, under a launch argument.
        // The simulator has no past, so a progress chart with a real series
        // cannot otherwise be tested or screenshotted (see ChartFixture).
        if ChartFixture.isEnabled {
            do {
                try ChartFixture.seed(in: modelContainer.mainContext)
            } catch {
                assertionFailure("Chart fixture seeding failed: \(error)")
            }
        }
        // One hour-long workout with a heart-rate series, for the same reason
        // (see HeartRateHistoryFixture).
        if HeartRateHistoryFixture.isEnabled {
            do {
                try HeartRateHistoryFixture.seed(in: modelContainer.mainContext)
            } catch {
                assertionFailure("Heart-rate history fixture seeding failed: \(error)")
            }
        }
        // First-launch unit preference: derive from the locale measurement
        // system (US → lb, else kg). Idempotent; never blocks launch.
        do {
            try AppPreferences.ensureUnitPreference(in: modelContainer.mainContext)
        } catch {
            assertionFailure("Unit-preference bootstrap failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
