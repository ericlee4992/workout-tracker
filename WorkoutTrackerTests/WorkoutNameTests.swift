import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Milestone 9, ticket 02 — a workout the user can name.
///
/// Two paths, deliberately different: naming a RUNNING workout is just typing
/// (nothing has been logged yet), while renaming a LOGGED one is a history
/// edit and is marked as such (D47). These pin that difference, the title
/// precedence, and that the name reaches the export.
struct WorkoutNameTests {

    private func exercise(_ name: String) -> HistoryExercise {
        HistoryExercise(id: UUID(), name: name)
    }

    @MainActor
    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private final class SilentNotifications: RestNotificationScheduling {
        func requestAuthorization() {}
        func schedule(at date: Date) {}
        func schedule(at date: Date, title: String, body: String) {}
        func cancel() {}
    }

    // MARK: Title precedence

    @Test func aTypedNameOutranksTheTemplateAndTheExercises() {
        #expect(HistoryRendering.title(
            name: "Heavy day", templateName: "Push Day",
            exercises: [exercise("Chest Press")]) == "Heavy day")
    }

    /// Whitespace is not a name, and a nil name changes nothing that existed
    /// before names did.
    @Test func aBlankNameFallsThroughToTheDerivedTitle() {
        #expect(HistoryRendering.title(
            name: "   ", templateName: "Push Day", exercises: []) == "Push Day")
        #expect(HistoryRendering.title(
            name: nil, templateName: nil, exercises: [exercise("Row"), exercise("Curl")]) == "Row +1")
    }

    // MARK: Renaming a logged workout is a marked edit

    @Test @MainActor func renamingLoggedHistoryMarksItEdited() throws {
        let ctx = try context()
        let workout = Workout(startedAt: .now, finishedAt: .now)
        ctx.insert(workout)
        let when = Date(timeIntervalSince1970: 1_000)
        #expect(HistoryEditing.rename(workout, to: "  Leg day  ", at: when))
        #expect(workout.name == "Leg day", "trimmed, stored as typed otherwise")
        #expect(workout.historyEditedAt == when)
        #expect(workout.historyTitle == "Leg day")
    }

    @Test @MainActor func renamingToTheSameNameMarksNothing() throws {
        let ctx = try context()
        let workout = Workout(startedAt: .now, finishedAt: .now, name: "Leg day")
        ctx.insert(workout)
        #expect(HistoryEditing.rename(workout, to: "Leg day") == false)
        #expect(workout.historyEditedAt == nil, "an edit that changed nothing must not claim to have")
    }

    @Test @MainActor func clearingTheNameRestoresTheDerivedTitleAndIsStillAnEdit() throws {
        let ctx = try context()
        let workout = Workout(startedAt: .now, finishedAt: .now, name: "Leg day", sourceTemplateName: "Legs")
        ctx.insert(workout)
        #expect(HistoryEditing.rename(workout, to: ""))
        #expect(workout.name == nil)
        #expect(workout.historyTitle == "Legs")
        #expect(workout.historyEditedAt != nil)
    }

    // MARK: Naming a running workout is not an edit

    @Test @MainActor func namingARunningWorkoutDoesNotMarkIt() throws {
        let ctx = try context()
        let session = WorkoutSession(context: ctx, notifications: SilentNotifications())
        let workout = try session.startWorkout(at: nil)
        try session.rename(workout, to: "Push A")
        #expect(workout.name == "Push A")
        #expect(workout.historyEditedAt == nil, "nothing was logged yet, so nothing was edited")
        try session.rename(workout, to: "   ")
        #expect(workout.name == nil)
    }

    // MARK: Export

    @Test @MainActor func theExportCarriesTheNameAndTheCSVPrefersItToTheTemplate() throws {
        let ctx = try context()
        let named = Workout(startedAt: Date(timeIntervalSince1970: 100), finishedAt: Date(timeIntervalSince1970: 200),
                            name: "Heavy day", sourceTemplateName: "Push Day")
        let unnamed = Workout(startedAt: Date(timeIntervalSince1970: 300), finishedAt: Date(timeIntervalSince1970: 400),
                              sourceTemplateName: "Pull Day")
        ctx.insert(named); ctx.insert(unnamed)
        for w in [named, unnamed] {
            let entry = ExerciseEntry(
                order: 0, workout: w, snapshotCapturedAt: w.startedAt,
                snapshotExerciseID: UUID(), snapshotLoadType: .weighted, snapshotExerciseName: "Row")
            ctx.insert(entry)
            let set = SetRecord(order: 0, type: .working, entry: entry)
            set.reps = 5; set.weightValue = 50; set.weightUnit = .kg; set.normalizedKg = 50
            set.completedAt = w.startedAt.addingTimeInterval(60)
            ctx.insert(set)
        }
        try ctx.save()
        let snapshot = try ExportCollector(appVersion: "test").snapshot(from: ctx)
        let byName = Dictionary(uniqueKeysWithValues: snapshot.workouts.map { ($0.sourceTemplateName ?? "", $0.name) })
        #expect(byName["Push Day"] == "Heavy day")
        #expect(byName["Pull Day"] == .some(nil), "no typed name is absent, not empty")

        let rows = ExportCSV.render(snapshot).split(separator: "\r\n").map { $0.split(separator: ",", omittingEmptySubsequences: false) }
        let nameColumn = try #require(ExportCSV.header.firstIndex(of: "workoutName"))
        let names = Set(rows.dropFirst().map { String($0[nameColumn]) })
        #expect(names == ["Heavy day", "Pull Day"], "typed name when present, else the template, got \(names)")
    }
}
