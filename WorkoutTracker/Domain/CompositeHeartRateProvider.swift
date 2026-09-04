import Foundation

// Milestone 7, ticket 04 — two sensors, one feed (D41).
//
// AirPods reach the phone through its own `HKWorkoutSession`; the Watch reaches
// it over `WCSession`. Both can be live at once, and the screen shows one
// number. Merging here — rather than in the view, or in the monitor — keeps the
// precedence rule (ticket 01) the single place that decides which wrist or ear
// the app is currently believing.

@MainActor
final class CompositeHeartRateProvider: HeartRateProviding, WatchRestBroadcasting {

    private let providers: [any HeartRateProviding]
    private var continuation: AsyncStream<HeartRateSample>.Continuation?
    private var pumps: [Task<Void, Never>] = []

    let stream: AsyncStream<HeartRateSample>

    /// The largest value any source reports.
    ///
    /// Not a sum: each source that accumulates energy accumulates it for the
    /// *same* workout, so adding them would double-count the calories. Not the
    /// first either — a source that starts late reports a smaller number, and
    /// the total shown to the user must never go backwards mid-workout.
    var basalEnergyKilocalories: Double? {
        providers.compactMap(\.basalEnergyKilocalories).max()
    }

    var activeEnergyKilocalories: Double? {
        providers.compactMap(\.activeEnergyKilocalories).max()
    }

    init(providers: [any HeartRateProviding]) {
        self.providers = providers
        var captured: AsyncStream<HeartRateSample>.Continuation!
        self.stream = AsyncStream { captured = $0 }
        self.continuation = captured
    }

    func start() async -> HeartRateFeedState {
        var states: [HeartRateFeedState] = []
        for provider in providers {
            states.append(await provider.start())
        }
        pumps = providers.map { provider in
            Task { [weak self] in
                for await sample in provider.stream {
                    self?.continuation?.yield(sample)
                }
            }
        }
        return Self.combined(states)
    }

    /// Forwards to whichever source can reach a watch; a no-op when none can.
    func sendRest(endsAt: Date?) {
        for provider in providers {
            (provider as? WatchRestBroadcasting)?.sendRest(endsAt: endsAt)
        }
    }

    func stop() async {
        for pump in pumps { pump.cancel() }
        pumps = []
        for provider in providers { await provider.stop() }
        continuation?.finish()
    }

    /// The feed's state when several sources disagree.
    ///
    /// `nonisolated` because it is a pure function of its argument — needing
    /// the main actor to decide which of two states wins would make the rule
    /// untestable without a running app, for no reason.
    ///
    /// Ordered by how much the user can do about it: something live beats
    /// something waiting; anything waiting beats a refusal, because one working
    /// sensor makes the other's permission irrelevant; and "denied" beats
    /// "unavailable" because it is the one the user can actually fix.
    nonisolated static func combined(_ states: [HeartRateFeedState]) -> HeartRateFeedState {
        if let live = states.first(where: { if case .live = $0 { return true } else { return false } }) {
            return live
        }
        if states.contains(.waitingForSensor) { return .waitingForSensor }
        if states.contains(.denied) { return .denied }
        if states.contains(.needsAuthorization) { return .needsAuthorization }
        if states.contains(.unavailable) { return .unavailable }
        return .idle
    }
}
