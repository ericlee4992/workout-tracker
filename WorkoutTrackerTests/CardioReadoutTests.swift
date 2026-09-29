import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Floodlight ticket 12: what the cardio screens derive from a segment.
@MainActor
struct CardioReadoutTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// One container for the whole test (a SwiftData object must not outlive its container).
    private final class Store {
        let container: ModelContainer
        let context: ModelContext
        init() throws {
            let schema = WorkoutTrackerStore.schema
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            context = ModelContext(container)
        }
    }

    // MARK: Ring

    @Test func ringCountsTheTargetTimeFirst() {
        let model = CardioRingModel.make(activeSeconds: 600, targetMinutes: 20, distanceMeters: 2_000, unit: .km)
        #expect(model.centre == .time(600))
        #expect(model.progress == 0.5)
        #expect(model.targetSeconds == 1_200)
        #expect(model.ticks == 20)
        #expect(!model.targetDone)
        #expect(!model.countsDistance)
        let met = CardioRingModel.make(activeSeconds: 1_205, targetMinutes: 20, distanceMeters: nil, unit: .km)
        #expect(met.targetDone && met.progress == 1)
        // Short targets keep twelve segments; long ones one per minute up to sixty.
        #expect(CardioRingModel.make(activeSeconds: 0, targetMinutes: 3, distanceMeters: nil, unit: .km).ticks == 12)
        #expect(CardioRingModel.make(activeSeconds: 0, targetMinutes: 90, distanceMeters: nil, unit: .km).ticks == 60)
    }

    @Test func ringCountsTowardTheNextUnitWithoutATarget() {
        let model = CardioRingModel.make(activeSeconds: 700, targetMinutes: nil, distanceMeters: 1.47 * 1_609.344, unit: .mi)
        #expect(model.countsDistance)
        guard case .distance(let units) = model.centre else { Issue.record("not a distance ring"); return }
        #expect(abs(units - 1.47) < 1e-9)
        #expect(abs(model.progress - 0.47) < 1e-9)
        #expect(model.nextUnit == 2)
        #expect(model.splitIndex == 1)
        #expect(model.targetSeconds == nil)
    }

    @Test func ringSweepsAMinuteWithNeitherTargetNorDistance() {
        let model = CardioRingModel.make(activeSeconds: 75, targetMinutes: nil, distanceMeters: 0, unit: .km)
        #expect(model.centre == .time(75))
        #expect(model.progress == 0.25)
        #expect(model.targetSeconds == nil && model.nextUnit == nil)
        #expect(!model.countsDistance)
    }

    // MARK: Pause, active time

    @Test func pauseDurationCountsFromThePause() throws {
        let store = try Store()
        let workout = try WorkoutSession(context: store.context).startWorkout(at: nil, on: start)
        let segment = try CardioSession(context: store.context).start(.indoorRun, in: workout, at: start, unit: .km)
        #expect(CardioReadout.pausedSeconds(segment, at: start.addingTimeInterval(30)) == nil)
        try CardioSession(context: store.context).pause(segment, at: start.addingTimeInterval(60))
        #expect(CardioReadout.pausedSeconds(segment, at: start.addingTimeInterval(102)) == 42)
        try CardioSession(context: store.context).resume(segment, at: start.addingTimeInterval(120))
        #expect(CardioReadout.pausedSeconds(segment, at: start.addingTimeInterval(130)) == nil)
        // Active time excludes the pause.
        #expect(CardioReadout.activeSeconds(segment, at: start.addingTimeInterval(150)) == 90)
        #expect(CardioReadout.activeSeconds(segment, at: start.addingTimeInterval(90)) == 60)
        try CardioSession(context: store.context).end(segment, at: start.addingTimeInterval(200))
        #expect(CardioReadout.pausedSeconds(segment, at: start.addingTimeInterval(300)) == nil)
    }

    // MARK: Splits

    /// A straight route north: `meters` per step every `seconds`.
    private func route(from origin: Date, steps: Int, metersPerStep: Double, secondsPerStep: Double,
                       portion: UUID = UUID(), latitude: Double = 40) -> [CardioRoutePoint] {
        let degreesPerMeter = 1 / 111_194.93
        return (0...steps).map { i in
            CardioRoutePoint(latitude: latitude + Double(i) * metersPerStep * degreesPerMeter, longitude: -73,
                             date: origin.addingTimeInterval(Double(i) * secondsPerStep), accuracy: 5, portion: portion)
        }
    }

    @Test func splitsFollowActiveTimeAndSkipPauses() throws {
        let store = try Store()
        let session = CardioSession(context: store.context)
        let workout = try WorkoutSession(context: store.context).startWorkout(at: nil, on: start)
        let segment = try session.start(.outdoorRun, in: workout, at: start, unit: .km)
        // 1 km in 300 s, a two-minute pause, then 0.5 km in 200 s (a new portion).
        let first = route(from: start, steps: 10, metersPerStep: 100, secondsPerStep: 30)
        try session.pause(segment, at: start.addingTimeInterval(300))
        try session.resume(segment, at: start.addingTimeInterval(420))
        let second = route(from: start.addingTimeInterval(420), steps: 5, metersPerStep: 100, secondsPerStep: 40,
                           latitude: first.last!.latitude)
        segment.route = first + second
        segment.automaticDistanceMeters = 1_500
        try session.end(segment, at: start.addingTimeInterval(620))
        let splits = CardioReadout.splits(segment)
        #expect(splits.count == 2)
        #expect(splits[0].seconds == 300)
        #expect(abs(splits[0].distance - 1) < 1e-6)
        #expect(!splits[0].isPartial)
        #expect(splits[1].seconds == 200)
        #expect(abs(splits[1].distance - 0.5) < 1e-6)
        #expect(splits[1].isPartial)
        #expect(splits[1].secondsPerUnit == 400)
    }

    @Test func splitsScaleToATypedDistanceAndNeedARoute() throws {
        let store = try Store()
        let session = CardioSession(context: store.context)
        let workout = try WorkoutSession(context: store.context).startWorkout(at: nil, on: start)
        let segment = try session.start(.outdoorRun, in: workout, at: start, unit: .km)
        #expect(CardioReadout.splits(segment).isEmpty)
        segment.route = route(from: start, steps: 10, metersPerStep: 100, secondsPerStep: 30)
        try session.end(segment, at: start.addingTimeInterval(300))
        #expect(CardioReadout.splits(segment).isEmpty, "no distance, no splits")
        // A typed 2 km stretches the 1 km trace: two splits of 150 s.
        try session.enterDistance("2", unit: .km, for: segment)
        let splits = CardioReadout.splits(segment)
        #expect(splits.map(\.seconds) == [150, 150])
    }

    // MARK: Last done

    @Test func lastDoneTakesTheNewestFinishedSegmentPerActivity() throws {
        let store = try Store()
        let session = CardioSession(context: store.context)
        let workouts = WorkoutSession(context: store.context)
        let old = try workouts.startWorkout(at: nil, on: start)
        let oldRun = try session.start(.indoorRun, in: old, at: start, unit: .km)
        try session.end(oldRun, at: start.addingTimeInterval(600))
        _ = try workouts.finish(old, at: start.addingTimeInterval(700))
        let newer = try workouts.startWorkout(at: nil, on: start.addingTimeInterval(86_400))
        let newRun = try session.start(.indoorRun, in: newer, at: start.addingTimeInterval(86_400), unit: .km)
        try session.end(newRun, at: start.addingTimeInterval(87_000))
        _ = try workouts.finish(newer, at: start.addingTimeInterval(87_100))
        // A segment in the running workout is not "last done".
        let live = try workouts.startWorkout(at: nil, on: start.addingTimeInterval(200_000))
        let liveRun = try session.start(.indoorRun, in: live, at: start.addingTimeInterval(200_000), unit: .km)
        try session.end(liveRun, at: start.addingTimeInterval(200_600))
        let all = try store.context.fetch(FetchDescriptor<CardioSegment>())
        let last = CardioReadout.lastDone(in: all)
        #expect(last[.indoorRun]?.id == newRun.id)
        #expect(last[.rowing] == nil)
    }

    // MARK: Heart trace

    @Test func heartTraceBucketsTheLastSixMinutes() {
        let now = start.addingTimeInterval(1_000)
        let samples = [
            HeartRateSample(bpm: 100, date: now.addingTimeInterval(-500), source: .airPods), // outside the window
            HeartRateSample(bpm: 120, date: now.addingTimeInterval(-350), source: .airPods),
            HeartRateSample(bpm: 130, date: now.addingTimeInterval(-10), source: .airPods),
            HeartRateSample(bpm: 140, date: now.addingTimeInterval(-5), source: .airPods),
        ]
        let points = CardioHeartTrace.points(samples, since: start, now: now)
        #expect(points.count == 2)
        #expect(points.last == CardioHeartPoint(index: 23, bpm: 135))
        #expect(points.first?.index == 0)
        // Nothing before the segment's start.
        #expect(CardioHeartTrace.points(samples, since: now.addingTimeInterval(-20), now: now).count == 1)
    }

    // MARK: Location status

    @Test func locationStatusShowsOnlyProblems() {
        #expect(CardioLocationStatus.of(message: nil, outdoor: true, running: true) == .fine)
        #expect(CardioLocationStatus.of(message: "Waiting for GPS…", outdoor: true, running: true) == .waiting("Waiting for GPS…"))
        #expect(CardioLocationStatus.of(message: "Location unavailable.", outdoor: true, running: true) == .lost)
        #expect(CardioLocationStatus.of(message: "GPS unavailable. Recording time continues.", outdoor: true, running: true) == .lost)
        #expect(CardioLocationStatus.of(message: "Location unavailable.", outdoor: true, running: false) == .fine)
        #expect(CardioLocationStatus.of(message: "Waiting for GPS…", outdoor: false, running: true) == .fine)
    }

    // MARK: codex-review-12

    @Test func absurdDistancesDeriveNoSplitsAndNeverTrap() throws {
        let store = try Store()
        let session = CardioSession(context: store.context)
        let workout = try WorkoutSession(context: store.context).startWorkout(at: nil, on: start)
        let segment = try session.start(.outdoorRun, in: workout, at: start, unit: .km)
        segment.route = route(from: start, steps: 10, metersPerStep: 100, secondsPerStep: 30)
        try session.end(segment, at: start.addingTimeInterval(300))
        try session.enterDistance("999999", unit: .km, for: segment)
        #expect(CardioReadout.splits(segment).isEmpty, "a mistyped distance must not expand into rows")
        try session.enterDistance("200", unit: .km, for: segment)
        #expect(CardioReadout.splits(segment).count == 200)
        // A finite but enormous stored value (the domain accepts it) must not trap the ring.
        let huge = CardioRingModel.make(activeSeconds: 90, targetMinutes: nil, distanceMeters: 1e19 * 1_000, unit: .km)
        #expect(huge.centre == .time(90) && !huge.countsDistance)
    }

    @Test func aSubMetreTailKeepsItsTimeInTheLastSplit() throws {
        let store = try Store()
        let session = CardioSession(context: store.context)
        let workout = try WorkoutSession(context: store.context).startWorkout(at: nil, on: start)
        let segment = try session.start(.outdoorRun, in: workout, at: start, unit: .km)
        segment.route = route(from: start, steps: 20, metersPerStep: 100, secondsPerStep: 30)
        try session.end(segment, at: start.addingTimeInterval(660))
        // 2 000.5 m: two whole kilometres at 300 s each, and the last 60 s go to the second.
        try session.enterDistance("2.0005", unit: .km, for: segment)
        let splits = CardioReadout.splits(segment)
        #expect(splits.count == 2)
        #expect(splits.map(\.seconds).reduce(0, +) == 660)
        #expect(splits.last?.seconds == 360)
    }

    @Test func aRecordedZeroIsAValueAndEntriesAreCheckedWhole() {
        #expect(CardioFormat.distance(0, .km) == "0.00")
        #expect(CardioFormat.distance(nil, .km) == "—")
        #expect(CardioFormat.distance(1_500, .km) == "1.50")
        // Stored values load unchanged and parse as the domain does.
        #expect(CardioFormat.parse("1e-06") == 0.000001)
        #expect(CardioFormat.parse("12.34567") == 12.34567)
        #expect(CardioFormat.parse("2,4") == 2.4)
        #expect(CardioFormat.parse("  ") == nil)
        #expect(!CardioFormat.isInvalidEntry("", unit: .km))
        #expect(!CardioFormat.isInvalidEntry("0", unit: .km))
        #expect(CardioFormat.isInvalidEntry("-1", unit: .km))
        #expect(CardioFormat.isInvalidEntry("1..2", unit: .km))
        #expect(CardioFormat.isInvalidEntry("1e400", unit: .km))
        #expect(!CardioFormat.isInvalidEntry("1e3", unit: .mi))
    }
}
