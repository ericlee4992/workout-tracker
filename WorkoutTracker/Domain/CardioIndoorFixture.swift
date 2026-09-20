import Foundation
import SwiftData

/// Automatic indoor distance for UI verification, never evidence of device delivery.
@MainActor
enum CardioIndoorFixture {
    static let launchArgument = "-uiTestIndoorDistance"
    static var isEnabled: Bool { WorkoutTrackerStore.fixtureIsEnabled(launchArgument) }
    static func seed(in context: ModelContext, now: Date = .now) throws {
        let start = now.addingTimeInterval(-300)
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: start, unit: .km)
        segment.acceptDistance(1_000, source: .phoneMotion, since: start, at: now, asOf: now)
        segment.lastCheckpointAt = now
        try context.save()
    }
}
