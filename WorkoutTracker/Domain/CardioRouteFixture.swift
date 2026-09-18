import Foundation
import SwiftData

/// A recorded route for native UI captures only. Never seed a real store and
/// never use this fixture as evidence that physical GPS or AirPods delivered data.
@MainActor
enum CardioRouteFixture {
    static var isEnabled: Bool { WorkoutTrackerStore.fixtureIsEnabled("-uiTestCardioRoute") }
    static func seed(in context: ModelContext, now: Date = .now) throws {
        let start = now.addingTimeInterval(-300)
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let segment = try CardioSession(context: context).start(.outdoorRun, in: workout, at: start, unit: .km)
        let portion = UUID()
        let route = (0...30).map { i in
            CardioRoutePoint(latitude: 40.7725 + Double(i) * 0.0002,
                            longitude: -73.9744 + sin(Double(i) / 10) * 0.0004,
                            date: start.addingTimeInterval(Double(i) * 10), accuracy: 5, portion: portion)
        }
        segment.route = route
        let meters = zip(route, route.dropFirst()).reduce(0) { $0 + CardioMath.meters(between: $1.0, and: $1.1) }
        segment.acceptDistance(meters, source: .gps, since: start, at: now, asOf: now)
        segment.lastCheckpointAt = now
        try context.save()
    }
}
