import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Milestone 7, ticket 04 — the two halves that can be proven without a wrist:
// the wire format the phone and watch share, and the rule that merges two
// sensors into one feed.
//
// What CANNOT be proven here is stated in the ticket: no simulator has an
// optical sensor, and `WCSession` needs a paired watch. These tests cover the
// logic either side of that gap.

struct WatchLinkTests {

    private let t0 = Date(timeIntervalSince1970: 5_000_000)

    // MARK: Wire format

    @Test func heartRateRoundTripsThroughTheWireFormat() throws {
        let message = WatchLink.heartRateMessage(bpm: 138, at: t0)
        let parsed = try #require(WatchLink.heartRate(from: message))
        #expect(parsed.bpm == 138)
        #expect(abs(parsed.date.timeIntervalSince(t0)) < 0.001)
    }

    @Test func workoutStateRoundTrips() throws {
        let restEnd = t0.addingTimeInterval(120)
        let message = WatchLink.workoutStateMessage(isActive: true, restEndsAt: restEnd)
        let parsed = try #require(WatchLink.workoutState(from: message))
        #expect(parsed.isActive)
        #expect(abs((parsed.restEndsAt ?? .distantPast).timeIntervalSince(restEnd)) < 0.001)

        let ended = WatchLink.workoutStateMessage(isActive: false, restEndsAt: nil)
        let parsedEnded = try #require(WatchLink.workoutState(from: ended))
        #expect(!parsedEnded.isActive)
        #expect(parsedEnded.restEndsAt == nil)
    }

    /// The two apps are signed and installed separately and WILL be out of step
    /// at some point. Anything unrecognised is ignored rather than guessed at.
    @Test func unrecognisedMessagesAreIgnoredRatherThanGuessedAt() {
        #expect(WatchLink.heartRate(from: [:]) == nil)
        #expect(WatchLink.heartRate(from: ["kind": "somethingNewer", "bpm": 120]) == nil)
        // A message of the right kind but missing its payload is not a reading.
        #expect(WatchLink.heartRate(from: ["kind": "heartRate"]) == nil)
        // Nor is a nonsense value.
        #expect(WatchLink.heartRate(from: [
            "kind": "heartRate", "bpm": 0, "ts": t0.timeIntervalSince1970]) == nil)
        #expect(WatchLink.workoutState(from: ["kind": "heartRate"]) == nil)
    }

    /// A heart-rate message must not parse as a workout-state message or vice
    /// versa: the two ends dispatch on `kind` alone.
    @Test func theTwoMessageKindsDoNotParseAsEachOther() {
        let heartRate = WatchLink.heartRateMessage(bpm: 120, at: t0)
        let state = WatchLink.workoutStateMessage(isActive: true, restEndsAt: nil)
        #expect(WatchLink.workoutState(from: heartRate) == nil)
        #expect(WatchLink.heartRate(from: state) == nil)
    }

    // MARK: Merging two sensors (D41)

    @Test func aLiveSourceWinsOverEveryOtherState() {
        #expect(
            CompositeHeartRateProvider.combined([.waitingForSensor, .live(.watch)])
                == .live(.watch))
        #expect(
            CompositeHeartRateProvider.combined([.denied, .live(.airPods)])
                == .live(.airPods))
    }

    /// One working sensor makes the other's permission irrelevant: a user with
    /// AirPods reporting must not be told heart rate is off because they never
    /// authorised the watch.
    @Test func anythingWaitingBeatsARefusal() {
        #expect(
            CompositeHeartRateProvider.combined([.denied, .waitingForSensor])
                == .waitingForSensor)
        #expect(
            CompositeHeartRateProvider.combined([.unavailable, .waitingForSensor])
                == .waitingForSensor)
    }

    /// "Denied" beats "unavailable" because it is the one the user can fix.
    @Test func aFixableProblemIsReportedOverAnUnfixableOne() {
        #expect(CompositeHeartRateProvider.combined([.unavailable, .denied]) == .denied)
        #expect(
            CompositeHeartRateProvider.combined([.unavailable, .needsAuthorization])
                == .needsAuthorization)
    }

    @Test func noSourcesAtAllIsIdle() {
        #expect(CompositeHeartRateProvider.combined([]) == .idle)
    }

    // MARK: Precedence over the merged stream

    /// Two sensors, one series: the merged feed shows the Watch while it is
    /// reporting, and falls to the ears the moment the wrist goes quiet —
    /// without double-counting either.
    @Test func theMergedFeedFollowsThePrecedenceRule() {
        let watch = HeartRateSample(bpm: 140, date: t0, source: .watch)
        let ears = HeartRateSample(bpm: 132, date: t0, source: .airPods)
        let both = [ears, watch]
        #expect(both.current(asOf: t0.addingTimeInterval(2))?.source == .watch)

        // The wrist stops reporting; the ears keep going.
        let laterEars = HeartRateSample(
            bpm: 128, date: t0.addingTimeInterval(60), source: .airPods)
        let after = both + [laterEars]
        let chosen = after.current(asOf: t0.addingTimeInterval(62))
        #expect(chosen?.source == .airPods)
        #expect(chosen?.bpm == 128, "not the watch's last known number")
    }
}

// MARK: - The rest mirror

@MainActor
private final class SpyWatchProvider: HeartRateProviding, WatchRestBroadcasting {
    let stream: AsyncStream<HeartRateSample> = AsyncStream { $0.finish() }
    let activeEnergyKilocalories: Double? = nil
    private(set) var rests: [Date?] = []
    func start() async -> HeartRateFeedState { .waitingForSensor }
    func stop() async {}
    func sendRest(endsAt: Date?) { rests.append(endsAt) }
}

@MainActor
private final class SpyPlainProvider: HeartRateProviding {
    let stream: AsyncStream<HeartRateSample> = AsyncStream { $0.finish() }
    let activeEnergyKilocalories: Double? = nil
    func start() async -> HeartRateFeedState { .waitingForSensor }
    func stop() async {}
}

/// The watch screen was written to mirror the phone's rest timer and for a day
/// showed nothing: `start`/`stop` were the only messages ever sent, and both
/// passed `restEndsAt: nil`.
@MainActor
struct WatchRestMirrorTests {

    private let t0 = Date(timeIntervalSince1970: 8_000_000)

    @Test func theCompositeForwardsRestOnlyToASourceThatCanReachAWatch() {
        let watch = SpyWatchProvider()
        let composite = CompositeHeartRateProvider(providers: [SpyPlainProvider(), watch])

        composite.sendRest(endsAt: t0)
        composite.sendRest(endsAt: nil)

        #expect(watch.rests.count == 2)
        #expect(watch.rests.first ?? nil == t0)
        #expect(watch.rests.last ?? Date() == nil, "the end of a rest is mirrored too")
    }

    @Test func aFeedWithNoWatchIgnoresTheMirrorRatherThanFailing() {
        let composite = CompositeHeartRateProvider(providers: [SpyPlainProvider()])
        composite.sendRest(endsAt: t0)  // must simply do nothing
    }

    @Test func theCoordinatorForwardsToTheRunningSession() throws {
        let schema = WorkoutTrackerStore.schema
        let context = ModelContext(try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
        let workout = Workout(startedAt: t0)
        context.insert(workout)

        let watch = SpyWatchProvider()
        let coordinator = WorkoutHeartRateCoordinator()
        coordinator.adoptForTesting(
            monitor: HeartRateMonitor(provider: watch), workoutID: workout.id)

        coordinator.broadcastRest(endsAt: t0.addingTimeInterval(120))

        #expect(watch.rests.count == 1)
        #expect(watch.rests.first ?? nil == t0.addingTimeInterval(120))
    }

    /// A rest that ends must clear the wrist, or the watch counts down to a
    /// rest the phone has already finished.
    @Test func theWireFormatCarriesBothARestAndItsAbsence() throws {
        let withRest = WatchLink.workoutStateMessage(
            isActive: true, restEndsAt: t0, workoutID: "w1")
        let parsed = try #require(WatchLink.workoutState(from: withRest))
        #expect(parsed.restEndsAt != nil)

        let cleared = WatchLink.workoutStateMessage(
            isActive: true, restEndsAt: nil, workoutID: "w1")
        let parsedCleared = try #require(WatchLink.workoutState(from: cleared))
        #expect(parsedCleared.isActive, "still training…")
        #expect(parsedCleared.restEndsAt == nil, "…but no longer resting")
    }
}
