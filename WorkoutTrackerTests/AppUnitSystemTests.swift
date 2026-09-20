import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@MainActor
struct AppUnitSystemTests {
    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema,
            configurations: [ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)]))
    }

    @Test func existingPreferencesOverrideLocaleForBothKindsOfUnits() {
        let metric = AppUnitSystem.resolve(preference: .kg, measurementSystem: .us)
        #expect(metric.weightUnit == .kg && metric.distanceUnit == .km)
        let us = AppUnitSystem.resolve(preference: .lb, measurementSystem: .metric)
        #expect(us.weightUnit == .lb && us.distanceUnit == .mi)
        #expect(AppUnitSystem.resolve(preference: nil, measurementSystem: .us) == .usCustomary)
        #expect(AppUnitSystem.resolve(preference: nil, measurementSystem: .uk) == .metric)
    }

    @Test func newCardioUsesCanonicalAppSystemNotGymWeightDefault() throws {
        let context = try context()
        context.insert(AppPreferences(unitPreference: .lb, updatedAt: Date(timeIntervalSince1970: 1)))
        let preferences = AppPreferences(unitPreference: .kg, updatedAt: Date(timeIntervalSince1970: 2))
        context.insert(preferences)
        let gym = Gym(name: "Pound machines", defaultUnit: .lb); context.insert(gym)
        let workout = try WorkoutSession(context: context).startWorkout(at: gym)
        let first = try CardioSession(context: context).start(.indoorRun, in: workout)
        #expect(first.unit == .km)
        preferences.unitPreference = .lb; preferences.updatedAt = .now; try context.save()
        let second = try CardioSession(context: context).start(.outdoorCycle, in: workout)
        #expect(second.unit == .mi)
        #expect(first.unit == .km, "A preference change must not rewrite recorded cardio")
        #expect(CardioMath.pace(seconds: 600, meters: 1_609.344, unit: second.unit) == 600)
    }

    @Test func explicitUnitsAndEnteredDistanceSurvivePreferenceChanges() throws {
        let context = try context()
        let preferences = AppPreferences(unitPreference: .lb); context.insert(preferences)
        let workout = try WorkoutSession(context: context).startWorkout(at: nil)
        let service = CardioSession(context: context)
        let segment = try service.start(.indoorRun, in: workout, unit: .km)
        #expect(segment.unit == .km, "An explicit unit overrides the app default")
        try service.enterDistance("1.25", unit: .mi, for: segment)
        preferences.unitPreference = .kg; try context.save()
        #expect(segment.manualDistanceValue == 1.25)
        #expect(segment.manualDistanceUnitRawValue == "mi")
        #expect(segment.distanceMeters == 1.25 * 1_609.344)
        #expect(segment.unit == .mi)
        let next = try service.start(.indoorCycle, in: workout)
        #expect(next.unit == .km)
    }

    @Test func indoorFixtureRequiresResetAndSeedsMeasuredPhoneMotion() throws {
        #expect(!WorkoutTrackerStore.fixtureIsEnabled(CardioIndoorFixture.launchArgument,
            in: [CardioIndoorFixture.launchArgument]))
        #expect(WorkoutTrackerStore.fixtureIsEnabled(CardioIndoorFixture.launchArgument,
            in: ["-uiTestReset", CardioIndoorFixture.launchArgument]))
        let context = try context()
        try CardioIndoorFixture.seed(in: context)
        let workout = try #require(context.fetch(FetchDescriptor<Workout>()).first)
        let segment = try #require(workout.unfinishedCardio)
        #expect(segment.source == .phoneMotion && segment.distanceMeters == 1_000)
        #expect(segment.manualDistanceValue == nil)
    }
}
