import Foundation
import Testing
@testable import WorkoutTracker

/// Public beta ticket 14 (D62): when the What's New sheet shows — the user's rules.
struct WhatsNewTests {
    private let seven = WhatsNewEntry(build: 7, title: "Seven", items: [])
    private let nine = WhatsNewEntry(build: 9, title: "Nine", items: [])
    private var entries: [WhatsNewEntry] { [seven, nine] }

    /// A fresh install gets the tour, not What's New, and starts counting from its own build.
    @Test func aFreshInstallSeesNothingAndRecordsItsBuild() {
        let d = WhatsNew.decide(entries: entries, currentBuild: 9, lastSeen: nil, welcomeUnanswered: true, workoutInProgress: false)
        #expect(d == .init(show: nil, recordNow: 9))
    }

    /// codex-review-14 #2: onboarding interrupted on build 7 (baseline 7 recorded, welcome never answered) and then an
    /// update to build 9 — the welcome owns the launch; build 9's notes are not requested beside it.
    @Test func anUnansweredWelcomeWinsEvenWithABaseline() {
        let d = WhatsNew.decide(entries: entries, currentBuild: 9, lastSeen: 7, welcomeUnanswered: true, workoutInProgress: false)
        #expect(d == .init(show: nil, recordNow: 9))
    }

    /// codex-review-14 #1: a workout in progress comes first — nothing shown and nothing recorded, even on a launch
    /// that would otherwise record a baseline.
    @Test func aWorkoutInProgressRecordsNothingEvenWithTheWelcomeUnanswered() {
        let d = WhatsNew.decide(entries: entries, currentBuild: 9, lastSeen: nil, welcomeUnanswered: true, workoutInProgress: true)
        #expect(d == .init(show: nil, recordNow: nil))
    }

    /// Updating from a build before What's New existed (nothing recorded, but not fresh) shows the newest notes.
    @Test func anUpdateFromBeforeWhatsNewShowsTheNewest() {
        #expect(WhatsNew.decide(entries: entries, currentBuild: 7, lastSeen: nil, welcomeUnanswered: false, workoutInProgress: false)
                == .init(show: seven, recordNow: nil))
        #expect(WhatsNew.decide(entries: entries, currentBuild: 9, lastSeen: nil, welcomeUnanswered: false, workoutInProgress: false)
                == .init(show: nine, recordNow: nil))
    }

    @Test func seenNotesAndFutureNotesDoNotShow() {
        #expect(WhatsNew.decide(entries: entries, currentBuild: 8, lastSeen: 7, welcomeUnanswered: false, workoutInProgress: false).show == nil)
        #expect(WhatsNew.decide(entries: entries, currentBuild: 6, lastSeen: 6, welcomeUnanswered: false, workoutInProgress: false).show == nil)
        #expect(WhatsNew.decide(entries: entries, currentBuild: 9, lastSeen: 7, welcomeUnanswered: false, workoutInProgress: false).show == nine)
    }

    /// Never over a workout in progress, and nothing recorded, so the next launch still shows it.
    @Test func aWorkoutInProgressDefersIt() {
        #expect(WhatsNew.decide(entries: entries, currentBuild: 7, lastSeen: 6, welcomeUnanswered: false, workoutInProgress: true)
                == .init(show: nil, recordNow: nil))
    }

    @Test func markSeenNeverGoesBackwards() throws {
        let defaults = try #require(UserDefaults(suiteName: "WhatsNewTests-\(UUID())"))
        #expect(WhatsNew.lastSeen(defaults) == nil)
        WhatsNew.markSeen(9, defaults)
        WhatsNew.markSeen(7, defaults)
        #expect(WhatsNew.lastSeen(defaults) == 9)
    }

    /// The shipped entry is the one the user approved, for build 7.
    @Test func theProgressEntryIsBuildSevenAsApproved() throws {
        let latest = try #require(WhatsNew.latest)
        #expect(latest.build == 7)
        #expect(latest.title == "New: Progress")
        #expect(latest.items.map(\.text) == [
            "Pin any lift or cardio activity to the new Progress tab.",
            "Each chart shows your latest best and how far you've come since your first session.",
            "Long-press a chart to change what it shows, move it or remove it.",
        ])
    }
}
