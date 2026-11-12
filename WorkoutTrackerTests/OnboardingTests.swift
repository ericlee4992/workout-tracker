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

    /// N13 (D84): the plan page's Show Me Around saves the setup, closes the welcome cover, then starts the tour.
    @Test func theTourStartsOnTheSampleWorldAndEndsCompletely() throws {
        let (real, url) = try onDiskContainer()
        defer { remove(url) }
        let defaults = isolatedDefaults()
        let coordinator = OnboardingCoordinator(defaults: defaults)
        coordinator.showsWelcome = true
        coordinator.beginSetup()
        try coordinator.finishSetup(Self.answers, in: ModelContext(real), thenTour: true)
        #expect(coordinator.tour?.current?.id == TourStep.all.first?.id)
        let sampleInMemory = coordinator.sampleContainer?.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        #expect(sampleInMemory == true)
        #expect(!coordinator.showsWelcome && coordinator.setup == nil)
        #expect(defaults.bool(forKey: OnboardingCoordinator.welcomeSeenKey))
        #expect(try ModelContext(real).fetchCount(FetchDescriptor<NutritionGoal>()) == 1, "saved before the tour")
        for _ in TourStep.all { coordinator.tour?.next() }
        #expect(coordinator.tour == nil)
        #expect(coordinator.sampleContainer == nil)
    }

    static let answers = GoalSetupStore.Answers(
        sex: .female, birthDate: Date(timeIntervalSince1970: 838_944_000), height: .init(value: 168, unit: .cm),
        weight: .init(value: 68.5, unit: .kg), activity: .moderate, goal: .lose,
        desired: .init(value: 63.5, unit: .kg), paceKgPerWeek: 0.35)

    /// The welcome cover cannot be left for the tour unfinished: only a saved setup (or Profile → Show Tour, with no
    /// cover up) starts it.
    @Test func theTourNeverStartsFromAnUnfinishedWelcome() throws {
        let (real, url) = try onDiskContainer()
        defer { remove(url) }
        let defaults = isolatedDefaults()
        let coordinator = OnboardingCoordinator(defaults: defaults)
        coordinator.showsWelcome = true
        coordinator.startTour(realContext: ModelContext(real))
        #expect(coordinator.tour == nil && coordinator.showsWelcome)
        #expect(!defaults.bool(forKey: OnboardingCoordinator.welcomeSeenKey))
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

    /// N13: Start saves and answers the welcome; until then nothing is marked, so quitting part-way brings the welcome
    /// (and the setup) back.
    @Test func startingSavesTheSetupAndAnswersTheWelcome() throws {
        let (real, url) = try onDiskContainer()
        defer { remove(url) }
        let defaults = isolatedDefaults()
        let coordinator = OnboardingCoordinator(defaults: defaults)
        coordinator.showsWelcome = true
        coordinator.beginSetup()
        #expect(coordinator.setup != nil && coordinator.showsWelcome)
        #expect(!defaults.bool(forKey: OnboardingCoordinator.welcomeSeenKey), "not answered until the plan is saved")
        try coordinator.finishSetup(Self.answers, in: ModelContext(real), thenTour: false)
        #expect(!coordinator.showsWelcome && coordinator.setup == nil && coordinator.tour == nil)
        #expect(defaults.bool(forKey: OnboardingCoordinator.welcomeSeenKey))
        let goal = try #require(try ModelContext(real).fetch(FetchDescriptor<NutritionGoal>()).first)
        #expect(goal.desiredWeightValue == 63.5 && goal.paceKgPerWeek == 0.35)
    }
}
