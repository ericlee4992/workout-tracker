import Foundation
import Testing
@testable import WorkoutTracker

@MainActor
struct WorkoutActivityProviderTests {
    private final class Trace { var events: [String] = []; var live = 0; var peak = 0 }
    private final class Feed: HeartRateProviding {
        let name: String
        let trace: Trace
        var activeEnergyKilocalories: Double?
        var basalEnergyKilocalories: Double? = 2
        let stream = AsyncStream<HeartRateSample> { _ in }
        var running = false
        var paused = false
        init(_ name: String, _ energy: Double, _ trace: Trace) {
            self.name = name; self.activeEnergyKilocalories = energy; self.trace = trace
        }
        func start() async -> HeartRateFeedState {
            running = true; trace.live += 1; trace.peak = max(trace.peak, trace.live)
            trace.events.append("start-" + name)
            return .waitingForSensor
        }
        func setPaused(_ paused: Bool) async { self.paused = paused; trace.events.append(paused ? "pause" : "resume") }
        func stop() async {
            if running { trace.live -= 1; trace.events.append("stop-" + name); running = false }
        }
    }
    @Test func transitionsNeverOverlapAndPauseDoesNotCreateAnotherWorkout() async {
        let trace = Trace()
        var feeds: [Feed] = []
        let provider = WorkoutActivityProvider { phase in
            let feed = Feed(phase.activity?.rawValue ?? "lifting", phase.activity == nil ? 10 : 20, trace)
            feeds.append(feed); return feed
        }
        _ = await provider.start()
        let id = UUID()
        await provider.configure(.init(segmentID: id, activity: .indoorRun))
        #expect(trace.peak == 1)
        #expect(provider.activeEnergyKilocalories == 30)
        #expect(provider.phaseActiveEnergy == 20)
        await provider.configure(.init(segmentID: id, activity: .indoorRun, paused: true))
        #expect(feeds.count == 2)
        #expect(feeds.last?.paused == true)
        await provider.configure(.init(segmentID: id, activity: .indoorRun, paused: false))
        #expect(feeds.count == 2)
        await provider.stop()
        #expect(trace.live == 0)
        #expect(provider.activeEnergyKilocalories == 30)
        await provider.configure(.lifting)
        #expect(feeds.count == 2, "ending cannot be undone by a late UI task")
        #expect(trace.events.first == "start-lifting")
        #expect(trace.events.firstIndex(of: "stop-lifting")! < trace.events.firstIndex(of: "start-indoorRun")!)
    }
    @Test func pausedRecoveryAndIdleDoNotStartPhantomWorkouts() async {
        let trace = Trace()
        let id = UUID()
        let provider = WorkoutActivityProvider(configuration: .init(segmentID: id, activity: .indoorRun, paused: true)) { phase in
            Feed(phase.activity?.rawValue ?? "lifting", 10, trace)
        }
        _ = await provider.start()
        #expect(trace.live == 0)
        await provider.configure(.init(segmentID: id, activity: .indoorRun))
        #expect(trace.live == 1)
        await provider.configure(.idle)
        #expect(trace.live == 0)
        #expect(trace.events.filter { $0.hasPrefix("start") } == ["start-indoorRun"])
        await provider.stop()
    }

    @Test func queuedChangesAndStopCannotLeaveASensorRunning() async {
        let trace = Trace()
        let provider = WorkoutActivityProvider { phase in Feed(phase.activity?.rawValue ?? "lifting", 10, trace) }
        _ = await provider.start()
        let first = Task { await provider.configure(.init(segmentID: UUID(), activity: .indoorRun)) }
        let second = Task { await provider.configure(.init(segmentID: UUID(), activity: .outdoorCycle)) }
        await provider.stop()
        await first.value; await second.value
        #expect(trace.live == 0)
        #expect(trace.peak == 1)
    }
}
