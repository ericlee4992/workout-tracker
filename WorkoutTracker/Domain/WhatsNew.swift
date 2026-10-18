import Foundation

// Public beta ticket 14 (D62): the one-time "What's New" sheet for big changes. Small fixes get only TestFlight's
// What to Test note; a build with a big change adds an entry here (its build number, a title, a few lines).
//
// The user's rules (2026-10-17): shown once, on the first launch of a build at or after the entry's, to people who
// UPDATED — a fresh install gets the guided tour instead; never over a workout in progress (it waits for the next
// launch); readable again from Settings. The last build whose notes were seen lives in UserDefaults.

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

    /// Newest last. The user approved this entry's wording (ticket 14, 2026-10-17).
    static let entries: [WhatsNewEntry] = [
        WhatsNewEntry(build: 7, title: "New: Progress", items: [
            .init(symbol: "chart.line.uptrend.xyaxis", text: "Pin any lift or cardio activity to the new Progress tab."),
            .init(symbol: "arrow.up.right", text: "Each chart shows your latest best and how far you've come since your first session."),
            .init(symbol: "hand.tap", text: "Long-press a chart to change what it shows, move it or remove it."),
        ]),
    ]

    static var latest: WhatsNewEntry? { entries.max { $0.build < $1.build } }

    struct Decision: Equatable {
        /// The notes to show now, if any.
        var show: WhatsNewEntry?
        /// What to save as the last build seen right away (a fresh install), or nil to leave it until dismissal.
        var recordNow: Int?
    }

    /// The launch-time rule. `lastSeen` nil means this build never recorded anything: a fresh install (no welcome
    /// answered, no workout) starts at the current build; anyone else is an update from before What's New existed.
    static func decide(entries: [WhatsNewEntry] = entries, currentBuild: Int, lastSeen: Int?, freshInstall: Bool,
                       workoutInProgress: Bool) -> Decision {
        if lastSeen == nil && freshInstall { return Decision(show: nil, recordNow: currentBuild) }
        let since = lastSeen ?? 0
        let pending = entries.filter { $0.build > since && $0.build <= currentBuild }.max { $0.build < $1.build }
        // Never over a workout in progress: nothing is recorded, so the next launch shows it.
        guard let pending, !workoutInProgress else { return Decision(show: nil, recordNow: nil) }
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
