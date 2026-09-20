import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

@MainActor
struct CardioExportTests {
    @Test func mixedWorkoutExportsStrengthAndCardioWithoutReusingColumns() throws {
        let schema = WorkoutTrackerStore.schema
        let context = ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
        let start = Date(timeIntervalSince1970: 1_800_000_000.125)
        let exercise = Exercise(name: "Press"); context.insert(exercise)
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: nil, on: start)
        let entry = try session.addEntry(for: exercise, to: workout)
        let set = try #require(entry.sets?.first)
        try session.commitWeight("62.25", for: set)
        try session.commitReps("8", for: set)
        try session.toggleCompletion(of: set)
        let cardio = try CardioSession(context: context).start(.outdoorRun, in: workout, at: start.addingTimeInterval(60))
        let cardioStart = try #require(cardio.activeStartedAt)
        cardio.acceptDistance(900, source: .gps, since: cardioStart)
        cardio.route = [.init(latitude: 40.1, longitude: -73.2, date: cardioStart, accuracy: 3, portion: UUID())]
        try CardioSession(context: context).enterDistance("1.25", unit: .mi, for: cardio)
        try session.finish(workout, at: start.addingTimeInterval(360))
        let snapshot = try ExportCollector().snapshot(from: context, now: start.addingTimeInterval(400))
        #expect(snapshot.schemaVersion == 11)
        #expect(snapshot.counts.completedSets == 1)
        #expect(snapshot.counts.cardioSegments == 1)
        let exported = try #require(snapshot.workouts.first?.cardioSegments?.first)
        #expect(exported.accumulatedActiveSeconds == 300)
        #expect(exported.automaticDistanceMeters == 900)
        #expect(exported.manualDistanceValue == 1.25)
        #expect(exported.manualDistanceUnit == "mi")
        #expect(exported.route.first?.latitude == 40.1)
        #expect(exported.distanceSpans.first?.readings["gps"] == 900)
        #expect(exported.intervals.count == 1)
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(ExportSnapshot.self, from: data) == snapshot)
        let rows = TestCSV.rows(ExportCSV.render(snapshot))
        #expect(rows.count == 3)
        #expect(rows.allSatisfy { $0.count == 51 })
        func value(_ row: Int, _ key: String) throws -> String { rows[row][try #require(rows[0].firstIndex(of: key))] }
        #expect(try value(1, "rowKind") == "strength")
        #expect(try value(1, "weight") == "62.25")
        #expect(try value(2, "rowKind") == "cardio")
        #expect(try value(2, "weight") == "")
        #expect(try value(2, "reps") == "")
        #expect(try value(2, "cardioEnteredDistance") == "1.25")
        #expect(Double(try value(2, "cardioActiveSeconds")) == 300)
    }
}
