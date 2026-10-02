import Foundation

/// Public beta ticket 02: the first-launch walkthrough's content. Every string here is proposed copy awaiting
/// the user's decision (ios-design copy policy); the ticket lists them.
struct OnboardingPage: Identifiable, Hashable {
    enum Illustration: Hashable { case welcome, logging, machines, progress, ai }

    let id: Int
    let headline: String
    /// The poster direction's headline, set as three short lines.
    let posterLines: [String]
    let line: String
    /// The one-page direction's row glyph (an SF Symbol or `LookIcon.machine`).
    let symbol: String
    let illustration: Illustration

    static let all: [OnboardingPage] = [
        OnboardingPage(id: 0, headline: "Stacked", posterLines: ["STACKED"],
                       line: "Know your numbers. Every machine. Every gym.",
                       symbol: LookIcon.machine, illustration: .welcome),
        OnboardingPage(id: 1, headline: "Log a set in a tap", posterLines: ["LOG A", "SET IN", "A TAP"],
                       line: "Weight, reps, check. Rest starts on its own.",
                       symbol: "checkmark.circle.fill", illustration: .logging),
        OnboardingPage(id: 2, headline: "Every machine remembered", posterLines: ["EVERY", "MACHINE", "REMEMBERED"],
                       line: "Each gym keeps its machines and your numbers on them.",
                       symbol: "building.2.fill", illustration: .machines),
        OnboardingPage(id: 3, headline: "Watch your numbers climb", posterLines: ["WATCH", "THEM", "CLIMB"],
                       line: "History, records and new bests — per machine.",
                       symbol: "chart.line.uptrend.xyaxis", illustration: .progress),
        OnboardingPage(id: 4, headline: "AI does the setup", posterLines: ["AI DOES", "THE", "SETUP"],
                       line: "Scan a machine. Ask for a week of templates.",
                       symbol: "sparkles", illustration: .ai),
    ]

    var isLast: Bool { id == OnboardingPage.all.count - 1 }
}

/// The three structural directions shown to the user (ticket 02, Design). Only the chosen one survives.
enum OnboardingStyle: String, CaseIterable, Identifiable {
    case showcase = "A"
    case poster = "B"
    case onePage = "C"
    var id: String { rawValue }
}
