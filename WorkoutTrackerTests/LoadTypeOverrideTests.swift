import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Milestone 8, ticket 02 — correcting a wrong load type.
///
/// The user asked to "make sure the weight isn't counting as +weight" for
/// supported dips and pull-ups. The maths was already right; what was missing
/// was any way to FIX A WRONG TAG. These pin the three things that make the fix
/// real rather than cosmetic.
@MainActor
struct LoadTypeOverrideTests {

    private func catalog(
        version: Int, loadType: LoadType, id: UUID, name: String
    ) -> SeedCatalog {
        SeedCatalog(
            version: version,
            exercises: [SeedExercise(
                id: id, name: name, loadType: loadType,
                equipmentTypeTags: [], muscleGroup: nil)],
            equipmentModels: [])
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    /// THE TIME BOMB THIS TICKET EXISTS TO DEFUSE.
    ///
    /// `CatalogSeeder.reconcileExercises` runs `setIfChanged(&row.loadType,
    /// seed.loadType)` on every seeded row at each catalog version bump (D24).
    /// Without the override flag, a user who correctly re-tags a supported dip
    /// as assisted sees it work — and then silently revert at the next catalog
    /// version, flipping their records back to heaviest-wins with no error and
    /// no way to notice.
    @Test func aCorrectedLoadTypeSurvivesCatalogReconciliation() throws {
        let context = try makeContext()
        let seeded = Exercise(
            name: "Seated Dip", loadType: .weighted, isSeeded: true)
        context.insert(seeded)

        // The user corrects it, exactly as the sheet does.
        seeded.loadType = .assisted
        seeded.loadTypeUserOverridden = true
        try context.save()

        // The catalog reconciles at a higher version, insisting on `weighted`.
        try CatalogSeeder.reconcile(
            catalog(version: 99, loadType: .weighted, id: seeded.id, name: "Seated Dip"),
            in: context)

        #expect(
            seeded.loadType == .assisted,
            "the catalog overwrote a hand-corrected load type — the user's records just flipped direction silently")
    }

    /// The flag is not a blanket "never update": an untouched seeded row must
    /// still track the catalog, or D24's whole reconciliation stops working.
    @Test func anUntouchedSeededRowStillTracksTheCatalog() throws {
        let context = try makeContext()
        let seeded = Exercise(
            name: "Seated Dip", loadType: .weighted, isSeeded: true)
        context.insert(seeded)
        try context.save()

        try CatalogSeeder.reconcile(
            catalog(version: 99, loadType: .assisted, id: seeded.id, name: "Seated Dip"),
            in: context)

        #expect(seeded.loadType == .assisted, "an unedited row must follow the catalog")
    }

    /// D19/D23: an entry freezes its load type when its snapshot is captured,
    /// so correcting the exercise must NOT restate what past sets were judged
    /// under. The first draft of ticket 02 claimed the opposite; the code was
    /// right and the ticket was wrong.
    @Test func frozenHistoryKeepsTheLoadTypeItWasLoggedUnder() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Dip", loadType: .weighted)
        context.insert(exercise)
        let entry = ExerciseEntry(
            order: 0, exercise: exercise, snapshotCapturedAt: .now,
            snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
            snapshotExerciseName: exercise.name)
        context.insert(entry)
        try context.save()

        exercise.loadType = .assisted
        exercise.loadTypeUserOverridden = true
        try context.save()

        #expect(
            entry.effectiveLoadType == .weighted,
            "a frozen entry must keep its snapshot — correcting the exercise cannot rewrite how past sets were judged")
    }

    /// The other half: an entry that has NOT frozen yet follows the live
    /// exercise, so a correction made mid-workout takes effect immediately.
    @Test func anUnfrozenEntryFollowsTheCorrection() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Assisted Dip", loadType: .weighted)
        context.insert(exercise)
        // No `snapshotCapturedAt` — the entry has not frozen yet.
        let entry = ExerciseEntry(
            order: 0, exercise: exercise,
            snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
            snapshotExerciseName: exercise.name)
        context.insert(entry)
        try context.save()

        exercise.loadType = .assisted
        #expect(entry.effectiveLoadType == .assisted)
    }

    // MARK: - What the user actually asked for

    /// Ask 6: "for bodyweight exercises the user should be able to just enter 0
    /// for weight." Both already true — pinned so a later change cannot quietly
    /// demand a number again.
    @Test func zeroIsALoggableLoadWhereItMeansSomething() {
        #expect(WorkoutSession.isLoggable(reps: 8, weightValue: 0, loadType: .assisted),
                "0 assistance means unassisted — a real answer, not a missing one")
        #expect(WorkoutSession.isLoggable(reps: 8, weightValue: 0, loadType: .bodyweightPlus),
                "0 added weight means a plain set")
        #expect(WorkoutSession.isLoggable(reps: 8, weightValue: nil, loadType: .bodyweight),
                "a bodyweight movement needs reps alone")
        #expect(!WorkoutSession.isLoggable(reps: 8, weightValue: nil, loadType: .weighted),
                "nil is an unanswered question, not a zero")
    }

    /// Ask 2, the substance of it: assisted ranks the LEAST assistance best.
    /// Already true; pinned because it is the thing the user was worried about
    /// and a regression here is invisible until a PR is silently wrong.
    @Test func assistedRanksLessWeightAsBetter() {
        let exerciseID = UUID()
        func set(_ kg: Double) -> RecordSetInput {
            RecordSetInput(
                loadType: .assisted, exerciseID: exerciseID, setType: .working,
                reps: 8, weightValue: kg, weightUnit: .kg,
                normalizedKg: kg, completedAt: .now)
        }
        #expect(
            RecordsMath.outranks(set(20), set(40)),
            "less assistance is the better set; the other way inverts every supported-dip PR")
        #expect(
            !RecordsMath.outranks(set(40), set(20)),
            "more assistance must never outrank less")
    }
}

/// codex-review (critical): the backup dropped both new user-authored facts.
/// A restore followed by catalog reconciliation would silently revert a
/// corrected load type — and a restored history would claim never to have been
/// edited. The JSON is the ONLY backup that exists (D28–D32).
@MainActor
struct ExportCarriesUserAuthoredFactsTests {

    @Test func aCorrectedSeededExerciseIsExportedWithItsOverrideFlag() throws {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        // Seeded and referenced by nothing — the case the old filter dropped.
        let seeded = Exercise(name: "Seated Dip", loadType: .assisted, isSeeded: true)
        seeded.loadTypeUserOverridden = true
        context.insert(seeded)
        try context.save()

        let snapshot = try ExportCollector(appVersion: "test").snapshot(from: context)
        let exported = snapshot.exercises.first { $0.id == seeded.id }
        let row = try #require(
            exported,
            "a corrected seeded exercise was filtered out of the backup entirely")
        #expect(
            row.loadTypeUserOverridden == true,
            "without the flag, a restore reverts the correction at the next catalog version")
        #expect(row.loadType == .assisted)
    }

    @Test func anEditedWorkoutSaysSoInTheBackup() throws {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let workout = Workout()
        workout.finishedAt = .now
        workout.historyEditedAt = .now
        context.insert(workout)
        try context.save()

        let snapshot = try ExportCollector(appVersion: "test").snapshot(from: context)
        let row = try #require(snapshot.workouts.first { $0.id == workout.id })
        #expect(
            row.historyEditedAt != nil,
            "a backup that drops the edit mark restores a history claiming to be untouched (D47)")
    }
}
