import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

struct GeneratePreCardioFixtureTests {
    @Test @MainActor func generate() throws {
        let directory = URL.documentsDirectory.appending(path: "PreCardioFixture", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "PreCardio.store")
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let gym = Gym(name: "Migration Gym", defaultUnit: .lb)
        let exercise = Exercise(name: "Migration Press", equipmentTypeTags: [.barbell])
        let preset = ExercisePreset(name: "Standing", exercise: exercise)
        context.insert(gym); context.insert(exercise); context.insert(preset)
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: gym, on: Date(timeIntervalSince1970: 1_780_000_000))
        workout.name = "Before cardio"
        let entry = try session.addEntry(for: exercise, to: workout)
        entry.preset = preset
        let set = try #require(entry.sets?.first)
        try session.commitWeight("62.25", for: set)
        try session.commitReps("8", for: set)
        try session.toggleCompletion(of: set, at: workout.startedAt.addingTimeInterval(60))
        workout.averageHeartRate = 125; workout.maxHeartRate = 160
        workout.activeEnergyKilocalories = 210; workout.basalEnergyKilocalories = 40
        workout.heartRateSeries = [120, 125, 130]
        workout.heartRateSeriesLow = [119, 124, 129]
        workout.heartRateSeriesHigh = [122, 127, 132]
        workout.heartRateSeriesIntervalSeconds = 15
        workout.zoneSeconds = [0, 10, 20, 30, 0, 0]
        workout.zonesFromEstimatedMax = true
        try session.finish(workout, at: workout.startedAt.addingTimeInterval(600))
        try context.save()
        print("PRE_CARDIO_FIXTURE=\(url.path)")
    }
}
