import Foundation

// Milestone 7, ticket 01 — heart rate as values (D41–D45). Pure logic:
// Foundation only. Nothing here imports HealthKit; the protocol that reaches
// HealthKit lives in ticket 03, and its implementation lives outside Domain/.
//
// The rule this file exists to enforce: a heart rate the app shows must be
// attributable and current. A number with no source invites trust the user
// cannot check, and a number that stopped updating twenty seconds ago is not a
// heart rate at all — it is the memory of one.

/// Where a sample came from. Shown on screen beside the number: the user is
/// entitled to know whether the app is reading their wrist or their ears,
/// because the two disagree and only one of them is on right now.
enum HeartRateSource: String, Codable, Sendable, CaseIterable {
    /// AirPods Pro 3 (or any heart-rate GATT wearable) feeding the phone's own
    /// `HKWorkoutSession`.
    case airPods
    /// The watchOS companion, streaming over `WCSession` (ticket 04).
    case watch
    /// A paired heart-rate monitor that is neither of the above — chest straps
    /// speak the same GATT profile and work identically.
    case otherMonitor
    /// The scripted series used by tests and previews. Named, not disguised:
    /// a fixture reading must never be mistaken for a measurement.
    case fixture

    var label: String {
        switch self {
        case .airPods: "AirPods"
        case .watch: "Apple Watch"
        case .otherMonitor: "Heart rate monitor"
        case .fixture: "Test data"
        }
    }

    /// Which source wins when two are live at once.
    ///
    /// The Watch outranks the ears: it is worn under load against the wrist,
    /// and it is the reading the user is more likely to trust when the two
    /// disagree. The point is not that the ranking is provably right — it is
    /// that *some* deterministic ranking must exist, or the displayed number
    /// flickers between two sensors and the average is silently computed from
    /// an interleaving of both.
    var precedence: Int {
        switch self {
        case .watch: 3
        case .otherMonitor: 2
        case .airPods: 1
        case .fixture: 0
        }
    }
}

/// One heart-rate reading.
struct HeartRateSample: Equatable, Sendable, Identifiable {
    var id: UUID
    var bpm: Int
    var date: Date
    var source: HeartRateSource

    init(id: UUID = UUID(), bpm: Int, date: Date, source: HeartRateSource) {
        self.id = id
        self.bpm = bpm
        self.date = date
        self.source = source
    }

    /// How long ago this reading was taken.
    func age(asOf now: Date) -> TimeInterval {
        now.timeIntervalSince(date)
    }

    /// Whether this reading is too old to be shown as the current heart rate.
    ///
    /// A sample exactly at the tolerance is still fresh; staleness begins
    /// *after* it. Stated because "> vs >=" here decides whether a reading
    /// blinks stale one sample early, and an accidental answer is one nobody
    /// can later tell was accidental.
    func isStale(asOf now: Date, tolerance: TimeInterval = HeartRateSample.stalenessTolerance)
        -> Bool {
        age(asOf: now) > tolerance
    }

    /// Sensors report every few seconds; 15s is several missed reports, which
    /// is a connection problem rather than jitter.
    static let stalenessTolerance: TimeInterval = 15
}

extension Collection where Element == HeartRateSample {
    /// The reading to display: the newest sample from the highest-precedence
    /// source that is currently reporting.
    ///
    /// Precedence is applied *within* what is live, not globally — a Watch that
    /// stopped reporting a minute ago must not outrank AirPods that are
    /// reporting now, or the screen freezes on a dead sensor while a working
    /// one sits ignored (`sourceDies` in the tests).
    func current(asOf now: Date, tolerance: TimeInterval = HeartRateSample.stalenessTolerance)
        -> HeartRateSample? {
        let live = filter { !$0.isStale(asOf: now, tolerance: tolerance) }
        guard !live.isEmpty else {
            // codex-review 3.5: with everything stale, precedence is
            // meaningless — no sensor is reporting, so "which do we trust" has
            // no answer. Show the most RECENT reading and let the UI mark its
            // age; a five-minute-old wrist value beside a twenty-second-old ear
            // value is the wrong one to freeze on.
            return self.max { $0.date < $1.date }
        }
        return live.max {
            ($0.source.precedence, $0.date) < ($1.source.precedence, $1.date)
        }
    }
}
