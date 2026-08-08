import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 05 — gym creation, app unit preference, and the unit-default
// precedence chain machine → gym → app preference (T7).

struct UnitPrecedenceTests {

    @Test func machineDefaultWinsOverGymAndAppPreference() {
        #expect(UnitPrecedence.defaultUnit(
            machineUnit: .lb, gymUnit: .kg, appPreference: .kg) == .lb)
    }

    @Test func machineNilFallsThroughToGymDefault() {
        #expect(UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: .lb, appPreference: .kg) == .lb)
    }

    @Test func machineAndGymNilFallThroughToAppPreference() {
        #expect(UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil, appPreference: .lb) == .lb)
        #expect(UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil, appPreference: .kg) == .kg)
    }

    /// Model-graph overload: a machine whose gym has a default but the
    /// machine itself doesn't; then no machine; then no gym at all.
    @Test func modelOverloadHandlesMissingContext() {
        let gym = Gym(name: "Gangnam", defaultUnit: .kg)
        let machine = MachineInstance(label: "Shoulder Press", defaultUnit: .lb, gym: gym)
        let unsetMachine = MachineInstance(label: "Chest Press", gym: gym)

        #expect(UnitPrecedence.defaultUnit(
            machine: machine, gym: gym, appPreference: .kg) == .lb)
        #expect(UnitPrecedence.defaultUnit(
            machine: unsetMachine, gym: gym, appPreference: .lb) == .kg)
        #expect(UnitPrecedence.defaultUnit(
            machine: nil, gym: gym, appPreference: .lb) == .kg)
        // No gym at all → app preference.
        #expect(UnitPrecedence.defaultUnit(
            machine: nil, gym: nil, appPreference: .lb) == .lb)
        // Gym exists but sets no unit → app preference.
        let unitlessGym = Gym(name: "Hotel Gym")
        #expect(UnitPrecedence.defaultUnit(
            machine: nil, gym: unitlessGym, appPreference: .kg) == .kg)
    }

    // MARK: First-launch default

    @Test func firstLaunchDefaultDerivesFromMeasurementSystem() {
        #expect(UnitPrecedence.firstLaunchDefault(for: .us) == .lb)
        #expect(UnitPrecedence.firstLaunchDefault(for: .metric) == .kg)
        #expect(UnitPrecedence.firstLaunchDefault(for: .uk) == .kg)
    }

    /// The full chain with a nil app preference (pre-bootstrap) falls back to
    /// the injected locale's measurement system, not the test host's locale.
    @Test func nilAppPreferenceFallsBackToLocale() {
        let us = Locale(identifier: "en_US")
        let kr = Locale(identifier: "ko_KR")
        #expect(UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil, appPreference: nil, locale: us) == .lb)
        #expect(UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil, appPreference: nil, locale: kr) == .kg)
    }
}

struct AppUnitPreferenceBootstrapTests {

    private func makeInMemoryContext() throws -> ModelContext {
        let configuration = ModelConfiguration(
            schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutTrackerStore.schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test func firstLaunchCreatesPreferenceFromInjectedMeasurementSystem() throws {
        let usContext = try makeInMemoryContext()
        let usPreferences = try AppPreferences.ensureUnitPreference(
            in: usContext, measurementSystem: .us)
        #expect(usPreferences.unitPreference == .lb)

        let metricContext = try makeInMemoryContext()
        let metricPreferences = try AppPreferences.ensureUnitPreference(
            in: metricContext, measurementSystem: .metric)
        #expect(metricPreferences.unitPreference == .kg)

        // Exactly one persisted row.
        let rows = try metricContext.fetch(FetchDescriptor<AppPreferences>())
        #expect(rows.count == 1)
    }

    @Test func existingPreferenceIsNeverOverwritten() throws {
        let context = try makeInMemoryContext()
        try AppPreferences.ensureUnitPreference(in: context, measurementSystem: .metric)

        // User edits the preference; a later bootstrap run must not touch it.
        let preferences = try AppPreferences.canonical(in: context)
        preferences.unitPreference = .lb
        try context.save()

        let after = try AppPreferences.ensureUnitPreference(
            in: context, measurementSystem: .metric)
        #expect(after.unitPreference == .lb)
        #expect(try context.fetch(FetchDescriptor<AppPreferences>()).count == 1)
    }
}

struct GymPersistenceTests {

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gym-test-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// Created gyms survive a container teardown/reopen (relaunch stand-in),
    /// including the optional-city and optional-unit shapes.
    @Test func createdGymsSurviveRelaunch() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }

        let fullID = UUID()
        let minimalID = UUID()

        // "First launch": create two gyms, save, tear the container down.
        do {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            context.insert(Gym(
                id: fullID, name: "Gangnam Fitness", city: "Seoul", defaultUnit: .kg))
            context.insert(Gym(id: minimalID, name: "Hotel Gym"))
            try context.save()
        }

        // "Relaunch": a fresh container over the same store.
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let gyms = try context.fetch(FetchDescriptor<Gym>(sortBy: [SortDescriptor(\.name)]))
        try #require(gyms.count == 2)

        let full = try #require(gyms.first { $0.id == fullID })
        #expect(full.name == "Gangnam Fitness")
        #expect(full.city == "Seoul")
        #expect(full.defaultUnit == .kg)
        #expect(full.archived == false)

        let minimal = try #require(gyms.first { $0.id == minimalID })
        #expect(minimal.name == "Hotel Gym")
        #expect(minimal.city == nil)
        #expect(minimal.defaultUnit == nil)
        #expect(minimal.archived == false)
    }
}
