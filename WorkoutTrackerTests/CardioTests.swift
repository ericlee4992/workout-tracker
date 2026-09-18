import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@MainActor
struct CardioTests {
    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func cardioOnlyFinishPersistsAndDoesNotInventStrengthSets() throws {
        let context = try context()
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: nil, on: start)
        let segment = try CardioSession(context: context).start(.indoorRun, in: workout, at: start)
        segment.acceptDistance(1_000, source: .healthKit, since: start)
        #expect(try session.finish(workout, at: start.addingTimeInterval(300)) == .saved)
        #expect(workout.completedSets.isEmpty)
        #expect(workout.recordedCardio.count == 1)
        #expect(segment.activeDuration() == 300)
        #expect(workout.historyTitle == "Indoor Run")
        #expect(WorkoutSummaryBuilder.summary(for: workout).totalVolumeKg == 0)
        #expect(!WorkoutTemplateService.canSaveAsTemplate(workout))
    }

    @Test func pauseResumeAndAveragePaceExcludePausedTime() throws {
        let context = try context()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let session = CardioSession(context: context)
        let segment = try session.start(.indoorWalk, in: workout, at: start)
        try session.pause(segment, at: start.addingTimeInterval(120))
        try session.pause(segment, at: start.addingTimeInterval(180))
        #expect(segment.activeDuration(at: start.addingTimeInterval(600)) == 120)
        try session.resume(segment, at: start.addingTimeInterval(600))
        try session.end(segment, at: start.addingTimeInterval(780))
        #expect(segment.activeDuration() == 300)
        #expect(segment.intervals.count == 2)
        #expect(CardioMath.pace(seconds: segment.activeDuration(), meters: 1_000, unit: .km) == 300)
        #expect(CardioMath.paceText(300) == "5:00")
    }

    @Test func overlappingDistanceSourcesAreAlternativesAndPauseSpansAccumulate() throws {
        let context = try context()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let session = CardioSession(context: context)
        let segment = try session.start(.indoorRun, in: workout, at: start)
        segment.acceptDistance(100, source: .phoneMotion, since: start)
        segment.acceptDistance(110, source: .healthKit, since: start)
        #expect(segment.automaticDistanceMeters == 110)
        segment.acceptDistance(120, source: .phoneMotion, since: start)
        #expect(segment.automaticDistanceMeters == 110)
        try session.pause(segment, at: start.addingTimeInterval(30))
        segment.acceptDistance(5_000, source: .healthKit, since: start)
        #expect(segment.automaticDistanceMeters == 110)
        let resumed = start.addingTimeInterval(90)
        try session.resume(segment, at: resumed)
        segment.acceptDistance(40, source: .phoneMotion, since: resumed)
        #expect(segment.automaticDistanceMeters == 150)
        #expect(segment.source == .mixed)
        #expect(segment.distanceSpans.count == 2)
    }

    @Test func enteredDistancePreservesUnitAndDoesNotEraseSensorEvidence() throws {
        let context = try context()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let session = CardioSession(context: context)
        let segment = try session.start(.indoorCycle, in: workout, at: start)
        segment.acceptDistance(2_000, source: .healthKit, since: start)
        try session.enterDistance("1.25", unit: .mi, for: segment)
        #expect(segment.manualDistanceValue == 1.25)
        #expect(segment.manualDistanceUnitRawValue == "mi")
        #expect(segment.distanceMeters == 1.25 * 1_609.344)
        #expect(segment.automaticDistanceMeters == 2_000)
        try session.enterDistance("", unit: .km, for: segment)
        #expect(segment.distanceMeters == 2_000)
        #expect(throws: CardioSessionError.self) { try session.enterDistance("nan", unit: .km, for: segment) }
        #expect(throws: CardioSessionError.self) { try session.enterDistance("-1", unit: .km, for: segment) }
    }

    @Test func newActivityEndsPreviousSegmentAndFinishEndsTheLast() throws {
        let context = try context()
        let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
        let session = CardioSession(context: context)
        let first = try session.start(.indoorWalk, in: workout, at: start)
        let next = try session.start(.outdoorCycle, in: workout, at: start.addingTimeInterval(100))
        #expect(first.endedAt == next.startedAt)
        #expect(workout.unfinishedCardio?.id == next.id)
        try WorkoutSession(context: context).finish(workout, at: start.addingTimeInterval(300))
        #expect(next.endedAt == workout.finishedAt)
        #expect(workout.recordedCardio.count == 2)
    }

    @Test func cancelCascadesSegmentsAndAnEmptyStartStillDiscards() throws {
        let context = try context()
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: nil, on: start)
        try CardioSession(context: context).start(.rowing, in: workout, at: start)
        try session.cancel(workout)
        #expect(try context.fetch(FetchDescriptor<CardioSegment>()).isEmpty)
        let empty = try session.startWorkout(at: nil, on: start)
        #expect(try session.finish(empty, at: start) == .discardedEmpty)
    }

    @Test func gpsAndPaceRefuseMissingAndInvalidMeasurements() {
        #expect(CardioMath.pace(seconds: 300, meters: nil, unit: .km) == nil)
        #expect(CardioMath.pace(seconds: 300, meters: 0, unit: .km) == nil)
        #expect(CardioMath.pace(speed: .nan, unit: .km) == nil)
        #expect(CardioMath.pace(speed: 0, unit: .km) == nil)
        let point = CardioRoutePoint(latitude: 40, longitude: -73, date: start, accuracy: 5, portion: UUID())
        #expect(CardioMath.valid(point, asOf: start))
        #expect(!CardioMath.valid(point, asOf: start.addingTimeInterval(20)))
        var bad = point; bad.accuracy = 100
        #expect(!CardioMath.valid(bad, asOf: start))
        #expect(CardioMath.meters(between: point, and: point) == 0)
    }

    @Test func diskReopenRecoversPausedAtLastCheckpointAndKeepsRouteAndDistance() throws {
        let dir = URL.temporaryDirectory.appending(path: "cardio-reopen-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appending(path: "test.store")
        try autoreleasepool {
            let container = try WorkoutTrackerStore.makeContainer(url: url)
            let context = ModelContext(container)
            let workout = try WorkoutSession(context: context).startWorkout(at: nil, on: start)
            let segment = try CardioSession(context: context).start(.outdoorRun, in: workout, at: start)
            segment.lastCheckpointAt = start.addingTimeInterval(30)
            segment.acceptDistance(80, source: .gps, since: start)
            segment.route = [.init(latitude: 40, longitude: -73, date: start, accuracy: 5, portion: UUID())]
            try context.save()
        }
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let segment = try #require(try context.fetch(FetchDescriptor<CardioSegment>()).first)
        #expect(!segment.isRunning)
        #expect(segment.activeDuration(at: start.addingTimeInterval(9_999)) == 30)
        #expect(segment.distanceMeters == 80)
        #expect(segment.route.count == 1)
    }

    @Test func currentPreCardioStoreMigratesWithoutChangingHistory() throws {
        let bundle = Bundle(for: Marker.self)
        let source = try #require(bundle.url(forResource: "PreCardio", withExtension: "store"))
        let dir = URL.temporaryDirectory.appending(path: "cardio-migration-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let copy = dir.appending(path: "test.store")
        try FileManager.default.copyItem(at: source, to: copy)
        let context = ModelContext(try WorkoutTrackerStore.makeContainer(url: copy))
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        #expect(workout.name == "Before cardio")
        #expect(workout.orderedCardio.isEmpty)
        #expect(workout.heartRateSeriesHigh == [122, 127, 132])
        #expect(workout.activeEnergyKilocalories == 210)
        let set = try #require(workout.completedSets.first)
        #expect(set.weightValue == 62.25)
        #expect(set.reps == 8)
        #expect(set.entry?.snapshotPresetName == "Standing")
    }
    private final class Marker {}
}
