import Foundation
import SwiftData

/// Cardio states for the Floodlight captures (ticket 12). UI-test stores only (`-uiTestReset`);
/// never evidence that a sensor, GPS or a Watch delivered anything.
///
/// - `-uiTestCardioTarget`: an Indoor Run recording against a 20-minute planned target, 12:48 in,
///   2.36 km measured (`-uiTestCardioTargetMet`: the target is 12 minutes, so it is met).
/// - `-uiTestCardioPlanned`: a running workout with two completed lifting sets, an ended Indoor
///   Walk and an unstarted 20-minute Indoor Run target; a finished Indoor Run last week.
/// - `-uiTestCardioLost`: an Outdoor Run recording with its location unavailable.
/// - `-uiTestCardioSplits`: a running workout whose only content is an ended 3.3 km Outdoor Run
///   with a one-minute pause (two route portions) — Finish shows the route and splits.
@MainActor
enum CardioDesignFixture {
    static let targetArgument = "-uiTestCardioTarget"
    static let targetMetArgument = "-uiTestCardioTargetMet"
    static let plannedArgument = "-uiTestCardioPlanned"
    static let lostArgument = "-uiTestCardioLost"
    static let splitsArgument = "-uiTestCardioSplits"

    static var isEnabled: Bool {
        [targetArgument, plannedArgument, lostArgument, splitsArgument].contains { WorkoutTrackerStore.fixtureIsEnabled($0) }
    }

    /// The recorder's location message while this fixture runs (the recorder collects no sensors
    /// under UI tests, so nothing else would set it).
    static var locationMessage: String? {
        WorkoutTrackerStore.fixtureIsEnabled(lostArgument) ? CardioLocationStatus.unavailable : nil
    }

    static func seed(in context: ModelContext, now: Date = .now) throws {
        if WorkoutTrackerStore.fixtureIsEnabled(targetArgument) { try seedTarget(in: context, now: now) }
        if WorkoutTrackerStore.fixtureIsEnabled(plannedArgument) { try seedPlanned(in: context, now: now) }
        if WorkoutTrackerStore.fixtureIsEnabled(lostArgument) { try seedLost(in: context, now: now) }
        if WorkoutTrackerStore.fixtureIsEnabled(splitsArgument) { try seedSplits(in: context, now: now) }
    }

    private static func seedTarget(in context: ModelContext, now: Date) throws {
        let met = WorkoutTrackerStore.fixtureIsEnabled(targetMetArgument)
        let start = now.addingTimeInterval(met ? -735 : -768)
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let target = PlannedCardio(activity: .indoorRun, minutes: met ? 12 : 20, unit: .km)
        workout.plannedCardio = [target]
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: start, unit: .km,
                                                               plannedTargetID: target.id)
        segment.acceptDistance(2_360, source: .phoneMotion, since: start, at: now, asOf: now)
        segment.activeEnergyKilocalories = 142
        segment.lastCheckpointAt = now
        try context.save()
    }

    private static func seedPlanned(in context: ModelContext, now: Date) throws {
        let cardio = CardioSession(context: context)
        let sessions = WorkoutSession(context: context)
        // Last week's Indoor Run: the target's "Last Indoor Run" fact and the picker's last-done line.
        let lastStart = now.addingTimeInterval(-7 * 86_400)
        let last = try sessions.startWorkout(at: nil, on: lastStart)
        let lastRun = try cardio.start(.indoorRun, in: last, at: lastStart, unit: .km)
        try cardio.end(lastRun, at: lastStart.addingTimeInterval(1_720))
        try cardio.enterDistance("5", unit: .km, for: lastRun)
        _ = try sessions.finish(last, at: lastStart.addingTimeInterval(1_800))

        let start = now.addingTimeInterval(-1_500)
        let workout = try sessions.startWorkout(at: nil, on: start)
        let exercise = Exercise(name: "Seated Chest Press")
        context.insert(exercise)
        let entry = try sessions.addEntry(for: exercise, to: workout)
        if let set = entry.sets?.first {
            try sessions.commitWeight("60", for: set)
            try sessions.commitReps("10", for: set)
            try sessions.toggleCompletion(of: set)
        }
        let walk = try cardio.start(.indoorWalk, in: workout, at: start.addingTimeInterval(60), unit: .km)
        walk.averageHeartRate = 104
        walk.activeEnergyKilocalories = 31
        try cardio.end(walk, at: start.addingTimeInterval(360))
        try cardio.enterDistance("0.5", unit: .km, for: walk)
        workout.plannedCardio = [PlannedCardio(activity: .indoorRun, minutes: 20, unit: .km)]
        try context.save()
    }

    private static func seedLost(in context: ModelContext, now: Date) throws {
        let start = now.addingTimeInterval(-492)
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let segment = try CardioSession(context: context).start(.outdoorRun, in: workout, at: start, unit: .km)
        let route = straightRoute(from: start, seconds: 300, every: 10, meters: { _ in 31 }, portion: UUID())
        segment.route = route
        segment.acceptDistance(routeMeters(route), source: .gps, since: start, at: start.addingTimeInterval(300), asOf: now)
        segment.lastCheckpointAt = now
        try context.save()
    }

    private static func seedSplits(in context: ModelContext, now: Date) throws {
        let cardio = CardioSession(context: context)
        let start = now.addingTimeInterval(-1_300)
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let segment = try cardio.start(.outdoorRun, in: workout, at: start, unit: .km)
        // About 3.3 km: a steady first kilometre, a faster second, a pause, then an easy finish.
        let pace: (Int) -> Double = { step in step < 33 ? 30 : (step < 60 ? 33 : 27) }
        let first = straightRoute(from: start, seconds: 600, every: 10, meters: pace, portion: UUID())
        try cardio.pause(segment, at: start.addingTimeInterval(600))
        try cardio.resume(segment, at: start.addingTimeInterval(660))
        let second = straightRoute(from: start.addingTimeInterval(660), seconds: 480, every: 10,
                                   meters: { pace($0 + 61) }, portion: UUID(), after: first.last)
        segment.route = first + second
        try cardio.end(segment, at: start.addingTimeInterval(1_140))
        segment.automaticDistanceMeters = routeMeters(first) + routeMeters(second)
        segment.distanceSourceRawValue = CardioDistanceSource.gps.rawValue
        segment.averageHeartRate = 152
        segment.maxHeartRate = 171
        segment.activeEnergyKilocalories = 248
        try context.save()
    }

    /// A gently curving route, one point every `every` seconds, `meters(step)` apart.
    private static func straightRoute(from start: Date, seconds: Int, every: Int, meters: (Int) -> Double,
                                      portion: UUID, after previous: CardioRoutePoint? = nil) -> [CardioRoutePoint] {
        let degreesPerMeter = 1 / 111_194.93
        var latitude = previous?.latitude ?? 37.5445
        var longitude = previous?.longitude ?? 127.0374
        var points: [CardioRoutePoint] = []
        for step in 0...(seconds / every) {
            if step > 0 || previous != nil {
                let heading = Double(points.count + (previous == nil ? 0 : 61)) / 18
                let d = meters(step)
                latitude += cos(heading) * d * degreesPerMeter
                longitude += sin(heading) * d * degreesPerMeter / cos(latitude * .pi / 180)
            }
            points.append(CardioRoutePoint(latitude: latitude, longitude: longitude,
                                           date: start.addingTimeInterval(Double(step * every)), accuracy: 5, portion: portion))
        }
        return points
    }

    private static func routeMeters(_ route: [CardioRoutePoint]) -> Double {
        zip(route, route.dropFirst()).reduce(0) { $0 + CardioMath.meters(between: $1.0, and: $1.1) }
    }
}
