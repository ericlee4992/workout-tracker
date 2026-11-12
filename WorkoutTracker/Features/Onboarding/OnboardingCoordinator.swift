import SwiftData
import SwiftUI

/// Public beta ticket 02 (spec Q8b): owns first launch — whether the welcome page shows — and the guided tour's
/// lifetime, including the temporary sample world it runs in. Lives at the app level so Settings → Show Tour and the
/// plan page start the same tour.
///
/// N13 (D84): a new install's welcome page leads into the goal setup (Get Started; no Skip) and the cover stays until the
/// plan is saved — quitting part-way brings the welcome back at the next launch, because the page counts as answered
/// only once the setup is saved. The plan page's Show Me Around saves, then starts the tour.
@Observable
@MainActor
final class OnboardingCoordinator {
    /// Set once the welcome page has been answered — since N13, once the goal setup it leads into is saved; a new
    /// version shows it again.
    static let welcomeSeenKey = "onboarding.welcomeSeen.v1"
    /// UI tests start from an empty store, which would show the welcome page in every one of them; it shows under
    /// `-uiTestReset` only when a test asks for it with this argument.
    static let uiTestArgument = "-uiTestOnboarding"

    var showsWelcome = false
    /// N13: the goal setup's answers once Get Started is tapped; nil while the welcome page shows.
    private(set) var setup: GoalSetupDraft?
    private(set) var tour: TourController?
    /// The tour's world: in memory only, discarded when the tour ends.
    private(set) var sampleContainer: ModelContainer?
    var tourFailure: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The welcome page's rule: never answered, no workout logged, and (in UI tests) explicitly requested.
    static func shouldShowWelcome(seen: Bool, hasWorkouts: Bool, isUITestReset: Bool, uiTestRequested: Bool) -> Bool {
        if isUITestReset && !uiTestRequested { return false }
        return !seen && !hasWorkouts
    }

    func evaluateFirstLaunch(in context: ModelContext) {
        let hasWorkouts = ((try? context.fetchCount(FetchDescriptor<Workout>())) ?? 0) > 0
        showsWelcome = Self.shouldShowWelcome(
            seen: defaults.bool(forKey: Self.welcomeSeenKey), hasWorkouts: hasWorkouts,
            isUITestReset: WorkoutTrackerStore.isUITestReset,
            uiTestRequested: ProcessInfo.processInfo.arguments.contains(Self.uiTestArgument))
    }

    /// Get Started: into the goal setup, inside the same cover, in the app's units.
    func beginSetup(in context: ModelContext? = nil, now: Date = .now) {
        let preferences = context.flatMap { try? AppPreferences.canonical(of: $0.fetch(FetchDescriptor<AppPreferences>())) }
        let system = AppUnitSystem.resolve(preference: preferences?.unitPreference)
        setup = GoalSetupDraft(usCustomary: system == .usCustomary, now: now)
    }

    /// The plan's Start (or Show Me Around): saves the answers, marks the welcome answered and closes the cover; with
    /// `thenTour`, starts the tour. Throws when the save fails — the cover stays, with the answers.
    func finishSetup(_ answers: GoalSetupStore.Answers, in context: ModelContext, thenTour: Bool,
                     now: Date = .now) throws {
        try GoalSetupStore.commit(answers, in: context, now: now)
        defaults.set(true, forKey: Self.welcomeSeenKey)
        showsWelcome = false
        setup = nil
        if thenTour { startTour(realContext: context) }
    }

    /// Starts the tour on a fresh in-memory sample store. Refuses while a real workout runs: the tour swaps the
    /// whole app to the sample world, and the running workout's screen must not be torn down under the user.
    func startTour(realContext: ModelContext) {
        // Only Profile → Show Tour and the saved plan start it (N13): the welcome cover is never left unfinished.
        guard !showsWelcome else { return }
        // Read-only and fail-closed (codex-review-02): an unknown answer refuses rather than starting.
        let unfinished = try? realContext.fetchCount(FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt == nil }))
        guard let unfinished else {
            tourFailure = "The tour could not start."
            return
        }
        guard unfinished == 0 else {
            tourFailure = "Finish your workout first."
            return
        }
        do {
            sampleContainer = try TourSampleStore.make()
            let controller = TourController(onEnd: { [weak self] in self?.endTour() })
            controller.start()
            tour = controller
        } catch {
            sampleContainer = nil
            tourFailure = "The tour could not start."
        }
    }

    func endTour() {
        tour = nil
        sampleContainer = nil
    }
}

/// The guided tour's sample world: the bundled catalog plus `DesignSampleFixture`'s base sample (a gym, three
/// templates, six finished workouts), in memory only. Never the user's store; nothing in it is ever saved to disk.
@MainActor
enum TourSampleStore {
    static func make(now: Date = .now) throws -> ModelContainer {
        let schema = WorkoutTrackerStore.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: context)
        try AppPreferences.ensureUnitPreference(in: context)
        // No launch variants: no live workout, no Settings extras, whatever the launch arguments say.
        try DesignSampleFixture.seed(in: context, now: now, launchVariants: false)
        return container
    }
}
