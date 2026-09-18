import Foundation

struct CardioSensorReading: Equatable, Sendable {
    var distanceMeters: Double
    var date: Date
}

@MainActor
protocol CardioMetricNotifying: AnyObject {
    var onCardioMetrics: (() -> Void)? { get set }
}

struct WorkoutSensorConfiguration: Equatable, Sendable {
    var segmentID: UUID?
    var activity: CardioActivity?
    var paused: Bool = false
    static let lifting = Self(segmentID: nil, activity: nil)
}

/// Keeps one app-facing stream while consecutive, correctly typed HealthKit
/// sessions replace one another. Summing overlapping providers would double energy;
/// we sum only finished phases, and each phase chooses one provider's figure.
@MainActor
final class WorkoutActivityProvider: HeartRateProviding, WatchRestBroadcasting, CardioMetricNotifying {
    typealias Factory = @MainActor (WorkoutSensorConfiguration) -> any HeartRateProviding
    private let factory: Factory
    private var desired: WorkoutSensorConfiguration
    private var applied: WorkoutSensorConfiguration?
    private var current: (any HeartRateProviding)?
    private var continuation: AsyncStream<HeartRateSample>.Continuation?
    private var pump: Task<Void, Never>?
    private var transition: Task<Void, Never>?
    private var started = false
    private var stopped = false
    private var bankedActive: Double?
    private var bankedBasal: Double?
    private var feedState: HeartRateFeedState = .idle
    let stream: AsyncStream<HeartRateSample>
    var onCardioMetrics: (() -> Void)?

    init(configuration: WorkoutSensorConfiguration = .lifting, factory: @escaping Factory) {
        desired = configuration
        self.factory = factory
        var captured: AsyncStream<HeartRateSample>.Continuation!
        stream = AsyncStream { captured = $0 }
        continuation = captured
    }
    var activeEnergyKilocalories: Double? { Self.sum(bankedActive, current?.activeEnergyKilocalories) }
    var basalEnergyKilocalories: Double? { Self.sum(bankedBasal, current?.basalEnergyKilocalories) }
    var cardioReading: CardioSensorReading? { current?.cardioReading }
    var phaseActiveEnergy: Double? { current?.activeEnergyKilocalories }
    var phaseBasalEnergy: Double? { current?.basalEnergyKilocalories }
    var configuration: WorkoutSensorConfiguration? { applied }

    static func sum(_ left: Double?, _ right: Double?) -> Double? {
        guard left != nil || right != nil else { return nil }
        return (left ?? 0) + (right ?? 0)
    }
    func start() async -> HeartRateFeedState {
        guard !stopped else { return .unavailable }
        started = true
        await configure(desired)
        return feedState
    }
    func configure(_ configuration: WorkoutSensorConfiguration) async {
        guard !stopped else { return }
        desired = configuration
        guard started else { return }
        let previous = transition
        let task = Task { [weak self] in
            await previous?.value
            await self?.applyDesired()
        }
        transition = task
        await task.value
    }
    private func applyDesired() async {
        guard !stopped else { return }
        let next = desired
        if let applied, applied.segmentID == next.segmentID, applied.activity == next.activity, let current {
            await current.setPaused(next.paused)
            self.applied = next
            return
        }
        pump?.cancel(); pump = nil
        if let old = current {
            (old as? CardioMetricNotifying)?.onCardioMetrics = nil
            await old.stop()
            bankedActive = Self.sum(bankedActive, old.activeEnergyKilocalories)
            bankedBasal = Self.sum(bankedBasal, old.basalEnergyKilocalories)
        }
        current = nil; applied = nil
        guard !stopped, next == desired else { return }
        let provider = factory(next)
        current = provider
        feedState = await provider.start()
        guard !stopped, next == desired else {
            await provider.stop()
            // Keep the provider until the queued transition banks its final energy.
            return
        }
        applied = next
        await provider.setPaused(next.paused)
        (provider as? CardioMetricNotifying)?.onCardioMetrics = { [weak self] in self?.onCardioMetrics?() }
        pump = Task { [weak self, weak provider] in
            guard let provider else { return }
            for await sample in provider.stream {
                guard !Task.isCancelled else { break }
                self?.continuation?.yield(sample)
            }
        }
        onCardioMetrics?()
    }
    func setPaused(_ paused: Bool) async {
        var next = desired; next.paused = paused
        await configure(next)
    }
    func sendRest(endsAt: Date?) { (current as? WatchRestBroadcasting)?.sendRest(endsAt: endsAt) }
    func stop() async {
        stopped = true
        await transition?.value
        pump?.cancel(); pump = nil
        if let current {
            (current as? CardioMetricNotifying)?.onCardioMetrics = nil
            await current.stop()
            bankedActive = Self.sum(bankedActive, current.activeEnergyKilocalories)
            bankedBasal = Self.sum(bankedBasal, current.basalEnergyKilocalories)
        }
        current = nil; applied = nil
        continuation?.finish()
    }
}
