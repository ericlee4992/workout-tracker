import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Public beta ticket 02 (spec Q8b): the welcome page's rule, and the guided tour's sample world — in memory,
/// the base sample only, and never the user's store.
@MainActor
struct OnboardingTests {

    private func onDiskContainer() throws -> (ModelContainer, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("onboarding-\(UUID().uuidString)").appendingPathExtension("store")
        return (try WorkoutTrackerStore.makeContainer(url: url), url)
    }

    private func remove(_ url: URL) {
        for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix)) }
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "onboarding-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func welcomeShowsOnlyOnAFreshPhoneAndOnlyWhenATestAsks() {
        #expect(OnboardingCoordinator.shouldShowWelcome(seen: false, hasWorkouts: false, isUITestReset: false, uiTestRequested: false))
        #expect(!OnboardingCoordinator.shouldShowWelcome(seen: true, hasWorkouts: false, isUITestReset: false, uiTestRequested: false))
        // The developer's phone (and any phone with history) never sees it automatically.
        #expect(!OnboardingCoordinator.shouldShowWelcome(seen: false, hasWorkouts: true, isUITestReset: false, uiTestRequested: false))
        // Every existing UI test starts from an empty store: the welcome must stay away unless asked for.
        #expect(!OnboardingCoordinator.shouldShowWelcome(seen: false, hasWorkouts: false, isUITestReset: true, uiTestRequested: false))
        #expect(OnboardingCoordinator.shouldShowWelcome(seen: false, hasWorkouts: false, isUITestReset: true, uiTestRequested: true))
    }

    @Test func theSampleWorldIsInMemoryAndHoldsOnlyTheBaseSample() throws {
        let container = try TourSampleStore.make()
        let inMemory = container.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        #expect(inMemory)
        let context = container.mainContext
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == DesignSampleFixture.sessions.count)
        // No unfinished workout: RootView would open it, and a live screen drives HealthKit and the Live Activity.
        let allFinished = workouts.allSatisfy { $0.finishedAt != nil }
        #expect(allFinished)
        let gyms = try context.fetch(FetchDescriptor<Gym>()).map(\.name)
        #expect(gyms == [DesignSampleFixture.gymName])
        #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 3)
    }

    @Test func makingTheSampleWorldLeavesTheUsersStoreUntouched() throws {
        let (real, url) = try onDiskContainer()
        defer { remove(url) }
        let context = ModelContext(real)
        context.insert(Gym(name: "My Gym", defaultUnit: .kg))
        try context.save()
        _ = try TourSampleStore.make()
        let reopened = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
        let gyms = try reopened.fetch(FetchDescriptor<Gym>()).map(\.name)
        #expect(gyms == ["My Gym"])
        #expect(try reopened.fetchCount(FetchDescriptor<Workout>()) == 0)
    }

    @Test func theTourStartsOnTheSampleWorldAndEndsCompletely() throws {
        let (real, url) = try onDiskContainer()
        defer { remove(url) }
        let defaults = isolatedDefaults()
        let coordinator = OnboardingCoordinator(defaults: defaults)
        coordinator.showsWelcome = true
        coordinator.startTour(realContext: ModelContext(real))
        #expect(coordinator.tour?.current?.id == TourStep.all.first?.id)
        let sampleInMemory = coordinator.sampleContainer?.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        #expect(sampleInMemory == true)
        #expect(!coordinator.showsWelcome)
        #expect(defaults.bool(forKey: OnboardingCoordinator.welcomeSeenKey))
        for _ in TourStep.all { coordinator.tour?.next() }
        #expect(coordinator.tour == nil)
        #expect(coordinator.sampleContainer == nil)
    }

    @Test func theTourRefusesWhileARealWorkoutRuns() throws {
        let (real, url) = try onDiskContainer()
        defer { remove(url) }
        let context = ModelContext(real)
        _ = try WorkoutSession(context: context).startWorkout(at: nil)
        try context.save()
        let coordinator = OnboardingCoordinator(defaults: isolatedDefaults())
        coordinator.startTour(realContext: context)
        #expect(coordinator.tour == nil)
        #expect(coordinator.sampleContainer == nil)
        #expect(coordinator.tourFailure == "Finish your workout first.")
    }

    @Test func skippingTheWelcomeIsRemembered() {
        let defaults = isolatedDefaults()
        let coordinator = OnboardingCoordinator(defaults: defaults)
        coordinator.showsWelcome = true
        coordinator.skipWelcome()
        #expect(!coordinator.showsWelcome)
        #expect(defaults.bool(forKey: OnboardingCoordinator.welcomeSeenKey))
    }
}
