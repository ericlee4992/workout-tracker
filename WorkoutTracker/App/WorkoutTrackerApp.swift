import SwiftData
import SwiftUI

@main
struct WorkoutTrackerApp: App {
    /// On-disk SwiftData store; UI tests receive a disposable container.
    private let modelContainer: ModelContainer

    init() {
        if WorkoutTrackerStore.isUITestReset {
            UserDefaults.standard.removeObject(forKey: TerraAccess.photoConsentKey)
            UserDefaults.standard.removeObject(forKey: TerraAccess.exerciseConsentKey)
            UserDefaults.standard.removeObject(forKey: TerraAccess.routineConsentKey)
            // Per-device facts outside the store start fresh too (ticket 09).
            ExportRecord.clear()
        }
        do {
            // `-uiTestReset` starts from an empty throwaway store so UI tests
            // never inherit state from a previous run.
            modelContainer = WorkoutTrackerStore.isUITestReset
                ? try WorkoutTrackerStore.makeUITestContainer()
                : try WorkoutTrackerStore.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        // +15s / Skip / Pause pressed on the Lock Screen card land here (ticket 11). Installed
        // before anything else can run: a command can be what launched the app.
        WorkoutActivityCommands.shared.install(container: modelContainer)
        // Versioned idempotent catalog seeding on every launch (D24). A
        // failure must not block launch — the catalog reconciles next run.
        do {
            let catalog = try SeedCatalog.bundled()
            try CatalogSeeder.reconcile(catalog, in: modelContainer.mainContext)
        } catch {
            assertionFailure("Catalog seeding failed: \(error)")
        }
        if TerraAccess.fixture, ProcessInfo.processInfo.arguments.contains("-uiTestTerraAmbiguous") {
            let duplicate = EquipmentModel(manufacturer: "Life Fitness", modelName: "Insignia Series Chest Press", exerciseIDs: [])
            modelContainer.mainContext.insert(duplicate)
            try? modelContainer.mainContext.save()
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
        // One six-exercise template with a superset, for the template detail's
        // captures (see TemplateFixture).
        if TemplateFixture.isEnabled {
            do {
                try TemplateFixture.seed(in: modelContainer.mainContext)
            } catch {
                assertionFailure("Template fixture seeding failed: \(error)")
            }
        }
        // A gym, three templates and two weeks of workouts for the redesign's captures
        // (see DesignSampleFixture).
        if DesignSampleFixture.isEnabled {
            do { try DesignSampleFixture.seed(in: modelContainer.mainContext) }
            catch { assertionFailure("Design sample fixture failed: \(error)") }
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
        if CardioRouteFixture.isEnabled {
            do { try CardioRouteFixture.seed(in: modelContainer.mainContext) }
            catch { assertionFailure("Cardio route fixture failed: \(error)") }
        }
        if CardioIndoorFixture.isEnabled {
            do { try CardioIndoorFixture.seed(in: modelContainer.mainContext) }
            catch { assertionFailure("Indoor cardio fixture failed: \(error)") }
        }
        // The Settings captures (see DesignSampleFixture.seedSettings): with the saved key
        // (AskAIKeyStore), photo and routine permissions on, model details off.
        if DesignSampleFixture.settingsIsEnabled {
            do { try DesignSampleFixture.seedSettings(in: modelContainer.mainContext) }
            catch { assertionFailure("Settings fixture failed: \(error)") }
            UserDefaults.standard.set(true, forKey: TerraAccess.photoConsentKey)
            UserDefaults.standard.set(true, forKey: TerraAccess.routineConsentKey)
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
            Group {
                // Ticket 11, test-only: the Live Activity's views for captures.
                if let state = ActivityGallery.requestedState {
                    ActivityGalleryView(name: state)
                } else {
                    RootView()
                }
            }
                // Settings → Appearance (System / Light / Dark) picks the scheme and the
                // Floodlight token set (D54 reopened by the Floodlight redesign).
                .lookLayer()
        }
        .modelContainer(modelContainer)
    }
}
