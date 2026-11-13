import Foundation

// Public beta ticket 14 (D62): the one-time "What's New" sheet for big changes. Small fixes get only TestFlight's
// What to Test note; a build with a big change adds an entry here (its build number, a title, a few lines).
//
// The user's rules (2026-10-17): shown once, on the first launch of a build at or after the entry's, to people who
// UPDATED — a fresh install gets the guided tour instead; never over a workout in progress (it waits for the next
// launch); readable again from Profile → What's New. The last build whose notes were seen lives in UserDefaults.

struct WhatsNewEntry: Equatable, Identifiable, Sendable {
    struct Item: Equatable, Sendable {
        let symbol: String
        let text: String
    }
    var id: Int { build }
    /// The first build these notes describe (CFBundleVersion).
    let build: Int
    let title: String
    let items: [Item]
}

enum WhatsNew {
    static let lastSeenKey = "whatsNew.lastSeenBuild.v1"
    /// UI tests never see the sheet unless they ask with this argument (it would cover every other test's screens).
    static let uiTestArgument = "-uiTestWhatsNew"

    /// Newest last. The user approved each entry's wording (build 7: ticket 14, 2026-10-17; build 10: release R, 2026-11-11).
    static let entries: [WhatsNewEntry] = [
        WhatsNewEntry(build: 7, title: "New: Progress", items: [
            .init(symbol: "chart.line.uptrend.xyaxis", text: "Pin any lift or cardio activity to the new Progress tab."),
            .init(symbol: "arrow.up.right", text: "Each chart shows your latest best and how far you've come since your first session."),
            .init(symbol: "hand.tap", text: "Long-press a chart to change what it shows, move it or remove it."),
        ]),
        // Build 12 (0.2.0, the user 2026-11-12: one combined page again, replacing build 11's): build 11's lines with
        // the goal-weight lines replaced by Generate Goals (N14), plus the Ask AI section's removal — named for the
        // features that still ask (food scanning and goal generation have no prompt, D83/D85).
        WhatsNewEntry(build: 12, title: "New: Food, goals and a fresh look", items: [
            .init(symbol: "fork.knife", text: "Log food from Today: search, scan a barcode or a label, or take a photo of your meal."),
            .init(symbol: "target", text: "Set calorie and protein goals; Today shows what's left."),
            .init(symbol: "flag", text: "Set the weight you're aiming for and how fast — slow, recommended or fast."),
            .init(symbol: "sparkles", text: "Tap Generate Goals in Profile → Nutrition goals: answer a few questions and get your plan."),
            .init(symbol: "iphone", text: "Signed in, your plan is made for you; otherwise it's calculated on your phone."),
            .init(symbol: "scalemass", text: "Track your body weight, with Apple Health if you like."),
            .init(symbol: "paintbrush", text: "A softer look across the app, with a new Profile."),
            .init(symbol: "bolt", text: "Smoother workouts: typing and scrolling no longer lag."),
            .init(symbol: "person.crop.circle", text: "The Ask AI section is gone: Scan Machine, exercise suggestions and Ask AI for Templates ask the first time you use them."),
        ]),
        // Build 13 (0.2.0, the user 2026-11-13: a small page of its own, knowing that only the newest unseen page is
        // shown — someone updating from build 11 or older sees this one, not build 12's): N12 Korean food data.
        WhatsNewEntry(build: 13, title: "New: Korean foods", items: [
            .init(symbol: "magnifyingglass", text: "Search in Korean for Korean dishes, plain foods and products — 김치찌개, 신라면, 닭가슴살."),
            .init(symbol: "barcode.viewfinder", text: "Scanning a Korean product finds more of them; if not, pick it from the matching Korean foods."),
        ]),
    ]

    static var latest: WhatsNewEntry? { entries.max { $0.build < $1.build } }

    struct Decision: Equatable {
        /// The notes to show now, if any.
        var show: WhatsNewEntry?
        /// What to save as the last build seen right away (a fresh install), or nil to leave it until dismissal.
        var recordNow: Int?
    }

    /// The launch-time rule, in order (codex-review-14 #1, #2):
    /// 1. A workout in progress: nothing shown, nothing recorded — the next launch decides again.
    /// 2. The welcome page still unanswered (`OnboardingCoordinator.shouldShowWelcome`'s rule: never answered, no
    ///    workout): the welcome owns this launch — a fresh install, or one whose onboarding was interrupted, even if
    ///    an older build recorded a baseline. Nothing shown; this build recorded, so its notes never follow the tour.
    /// 3. Otherwise the newest entry after the last build seen (none recorded = an update from before What's New)
    ///    and at or before this build.
    /// The caller decides only when it could read the store; an unknown count means no decision at all.
    static func decide(entries: [WhatsNewEntry] = entries, currentBuild: Int, lastSeen: Int?, welcomeUnanswered: Bool,
                       workoutInProgress: Bool) -> Decision {
        if workoutInProgress { return Decision(show: nil, recordNow: nil) }
        if welcomeUnanswered { return Decision(show: nil, recordNow: currentBuild) }
        let since = lastSeen ?? 0
        let pending = entries.filter { $0.build > since && $0.build <= currentBuild }.max { $0.build < $1.build }
        return Decision(show: pending, recordNow: nil)
    }

    static var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    static func lastSeen(_ defaults: UserDefaults = .standard) -> Int? {
        defaults.object(forKey: lastSeenKey) as? Int
    }

    /// Saved when the sheet is dismissed (Continue or a swipe), so a crash before then shows it again.
    static func markSeen(_ build: Int, _ defaults: UserDefaults = .standard) {
        defaults.set(max(build, lastSeen(defaults) ?? 0), forKey: lastSeenKey)
    }
}
