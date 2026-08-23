import Foundation

// Milestone 7, ticket 01 — D43's rest rule, as a pure state machine.
//
// Rest ends when the heart rate drops below a threshold the user set, OR when a
// max-wait cap expires — whichever comes first — and the result says WHICH.
//
// Why the cap exists, stated where it can be deleted: without it, one dropped
// connection, one bad sample, or one genuinely brutal set leaves the user
// waiting for an alarm that never fires. The rest timer's whole job is to be
// the thing you do not have to watch (D13), so a rule that can wait forever has
// failed at the only thing it was for.
//
// Why the reason is carried rather than collapsed to a bool: "your heart rate
// came down" and "you have been sitting here four minutes" are different facts
// about the set you just did. A notification that says the first when it means
// the second is lying about the user's training.

/// Why a heart-rate rest ended.
enum HeartRateRestEnd: Equatable, Sendable {
    /// The heart rate fell below the threshold, at this sample.
    case recovered(at: Date, bpm: Int)
    /// The cap expired first. The heart rate never got there — or the sensor
    /// never said it did, which the app cannot distinguish and must not
    /// pretend to.
    case cap(at: Date)

    var isRecovered: Bool {
        if case .recovered = self { return true }
        return false
    }
}

enum HeartRateRestState: Equatable, Sendable {
    case resting(elapsed: TimeInterval)
    case finished(HeartRateRestEnd)
    /// No live heart rate to rest against. The caller falls back to the
    /// standard timer (D13/D22) and tells the user it did — silently behaving
    /// like a different feature is how a user stops trusting the one they set up.
    case degraded
}

/// The rule for one rest period. Value type, no clock of its own: every answer
/// is a pure function of (samples, now), so a test can drive an entire rest
/// from a literal array and no test ever sleeps.
struct HeartRateRestRule: Equatable, Sendable {
    /// Rest ends when a reading is **strictly below** this. "Drops below 110"
    /// means 109 ends it and 110 does not; a boundary that reads either way is
    /// a boundary that will be read both ways.
    var thresholdBpm: Int
    /// Longest the rest may run before the alarm fires anyway.
    var cap: TimeInterval
    /// How long to wait for a first live reading before declaring no source.
    /// Longer than `HeartRateSample.stalenessTolerance`, so a normal gap
    /// between reports never reads as a dead sensor.
    var graceBeforeDegraded: TimeInterval = 20

    static let defaultThresholdBpm = 110
    static let defaultCap: TimeInterval = 240

    func deadline(from start: Date) -> Date {
        start.addingTimeInterval(cap)
    }

    /// The state of a rest that began at `start`, given every sample seen.
    ///
    /// Order matters and is deliberate:
    /// 1. **Recovery**, if any qualifying sample landed inside the window. It
    ///    happened; a later cap does not un-happen it.
    /// 2. **Degraded**, if nothing fresh is arriving past the grace period —
    ///    including the case of no samples at all. Checked before the cap so a
    ///    rest with no sensor reports the truth ("nothing is reading you")
    ///    rather than a cap that merely describes the clock.
    /// 3. **Cap**, once the deadline passes.
    /// 4. Otherwise still resting.
    func evaluate(
        samples: [HeartRateSample],
        start: Date,
        asOf now: Date,
        stalenessTolerance: TimeInterval = HeartRateSample.stalenessTolerance
    ) -> HeartRateRestState {
        let deadline = deadline(from: start)

        // 0. The cap has already passed, so its alarm has already fired.
        // Allowing a sample that merely PREDATES the deadline to report
        // recovery afterwards would deliver "time is up — you did not recover"
        // followed by "heart rate down — ready", about the same rest
        // (codex-review 2.3, high).
        if now >= deadline {
            // Round 1's fix still let an older qualifying sample report recovery
            // here, so a backgrounded app could deliver "time is up" and then
            // "heart rate down" about the SAME rest (codex-review-2, #1). Once
            // the deadline passes the cap alarm has already gone out, and the
            // only honest answer is the one the user already heard.
            //
            // A recovery that was *observed* before the deadline ends the rest
            // at that moment through the normal path below — this branch is
            // only reached when nobody was watching.
            let hasAny = samples.contains { $0.date >= start && $0.date <= deadline }
            return hasAny ? .finished(.cap(at: deadline)) : .degraded
        }

        // 1. Recovery — only from samples taken during the rest and at or
        // before the deadline. A reading that arrives after the cap has passed
        // cannot retroactively end a rest that already timed out.
        let inWindow = samples
            .filter { $0.date >= start && $0.date <= deadline }
            .sorted { $0.date < $1.date }
        if let recovery = inWindow.first(where: { $0.bpm < thresholdBpm }) {
            return .finished(.recovered(at: recovery.date, bpm: recovery.bpm))
        }

        // 2. Nothing is reading the user.
        let elapsed = now.timeIntervalSince(start)
        let hasFresh = samples.contains {
            $0.date <= now && !$0.isStale(asOf: now, tolerance: stalenessTolerance)
        }
        if !hasFresh && elapsed > graceBeforeDegraded {
            return .degraded
        }

        // 3. Time is up.
        if now >= deadline {
            return .finished(.cap(at: deadline))
        }

        return .resting(elapsed: max(0, elapsed))
    }
}

/// How an exercise rests (D43). Stored per exercise beside the existing
/// duration overrides (D22), so one place owns the whole answer to "how does
/// this exercise rest".
enum RestMode: String, CaseIterable, Codable, Sendable {
    case standard
    case heartRate

    var label: String {
        switch self {
        case .standard: "Timer"
        case .heartRate: "Heart rate"
        }
    }
}
