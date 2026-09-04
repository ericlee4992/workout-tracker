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

    @Test @MainActor func theExportCarriesTheNameBesideTheTemplateInJSONAndAsItsOwnCSVColumn() throws {
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
        let templateColumn = try #require(ExportCSV.header.firstIndex(of: "workoutName"))
        let typedColumn = try #require(ExportCSV.header.firstIndex(of: "workoutTypedName"))
        // Column 4 keeps meaning the template (provenance); the typed name is
        // its own, appended column (codex-review 02).
        #expect(Set(rows.dropFirst().map { String($0[templateColumn]) }) == ["Push Day", "Pull Day"])
        #expect(Set(rows.dropFirst().map { String($0[typedColumn]) }) == ["Heavy day", ""])
    }

    @Test @MainActor func aNamedWorkoutSurvivesTheJSONRoundTripAndAV5FileStillDecodes() throws {
        let ctx = try context()
        let named = Workout(startedAt: Date(timeIntervalSince1970: 100), finishedAt: Date(timeIntervalSince1970: 200),
                            name: "Heavy day", sourceTemplateName: "Push Day")
        ctx.insert(named)
        let entry = ExerciseEntry(
            order: 0, workout: named, snapshotCapturedAt: named.startedAt,
            snapshotExerciseID: UUID(), snapshotLoadType: .weighted, snapshotExerciseName: "Row")
        ctx.insert(entry)
        let set = SetRecord(order: 0, type: .working, entry: entry)
        set.reps = 5; set.weightValue = 50; set.weightUnit = .kg; set.normalizedKg = 50
        set.completedAt = named.startedAt.addingTimeInterval(60)
        ctx.insert(set)
        try ctx.save()

        var snapshot = try ExportCollector(appVersion: "test").snapshot(from: ctx)
        #expect(snapshot.schemaVersion == 6)
        let decoded = try ExportJSON.decode(try ExportJSON.data(snapshot))
        #expect(decoded.workouts.first?.name == "Heavy day")
        #expect(decoded.workouts.first?.sourceTemplateName == "Push Day", "provenance travels beside the name")

        // A v5 file has no `name` key at all. Encoding nil omits the key, so
        // this IS the v5 shape for that object; it must decode with name nil.
        snapshot.schemaVersion = 5
        snapshot.workouts[0].name = nil
        let v5 = try ExportJSON.data(snapshot)
        #expect(String(decoding: v5, as: UTF8.self).contains("\"name\"") == false)
        let old = try ExportJSON.decode(v5)
        #expect(old.workouts.first?.name == nil)
        #expect(old.workouts.first?.sourceTemplateName == "Push Day")
    }

    // MARK: Lifecycle guards (codex-review 02)

    /// The live path must not be able to rename LOGGED history unmarked.
    @Test @MainActor func theLivePathRefusesAFinishedWorkout() throws {
        let ctx = try context()
        let session = WorkoutSession(context: ctx, notifications: SilentNotifications())
        let workout = Workout(startedAt: .now, finishedAt: .now, name: "Logged")
        ctx.insert(workout)
        #expect(try session.rename(workout, to: "Sneaky") == false)
        #expect(workout.name == "Logged")
        #expect(workout.historyEditedAt == nil)
    }

    /// The history path must not stamp a RUNNING workout as edited history.
    @Test @MainActor func theHistoryPathRefusesARunningWorkout() throws {
        let ctx = try context()
        let workout = Workout(startedAt: .now)
        ctx.insert(workout)
        #expect(HistoryEditing.rename(workout, to: "Too early") == false)
        #expect(workout.name == nil)
        #expect(workout.historyEditedAt == nil)
    }

    // MARK: Persistence (codex-review 02, high)

    /// The History alert saves explicitly. This proves the saved shape: rename,
    /// save, open the SAME store from disk in a new container, and both the
    /// name and the mark are there.
    @Test @MainActor func aHistoryRenameIsOnDiskAfterSave() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "rename-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Store.store")
        let id: UUID
        do {
            let ctx = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
            let workout = Workout(startedAt: .now, finishedAt: .now)
            id = workout.id
            ctx.insert(workout)
            try ctx.save()
            #expect(HistoryEditing.rename(workout, to: "Persisted"))
            try ctx.save()
        }
        let reopened = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
        let workouts = try reopened.fetch(FetchDescriptor<Workout>())
        let again = try #require(workouts.first { $0.id == id })
        #expect(again.name == "Persisted")
        #expect(again.historyEditedAt != nil)
    }
}
