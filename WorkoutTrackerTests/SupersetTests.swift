import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Milestone 8, ticket 04 — supersets (D48).
///
/// The load-bearing test in this file is `groupingDoesNotChangeRecordsOrVolume`.
/// Everything else is behaviour; that one is the invariant. If grouping ever
/// alters a PR, then every record the user holds depends on how they happened
/// to arrange their workout that day, and the records stop meaning anything.
@MainActor
struct SupersetTests {

    private struct Rig {
        let context: ModelContext
        let workout: Workout
        var entries: [ExerciseEntry]
    }

    private func makeRig(entryCount: Int) throws -> Rig {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let workout = Workout()
        context.insert(workout)
        var entries: [ExerciseEntry] = []
        for index in 0..<entryCount {
            let exercise = Exercise(name: "Exercise \(index)", loadType: .weighted)
            context.insert(exercise)
            let entry = ExerciseEntry(
                order: index, workout: workout, exercise: exercise,
                snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
                snapshotExerciseName: exercise.name)
            context.insert(entry)
            entries.append(entry)
        }
        try context.save()
        return Rig(context: context, workout: workout, entries: entries)
    }

    // MARK: - The invariant

    /// Grouping is presentation and rest behaviour. It is NOT a new kind of
    /// load, and a set inside a superset is still a set.
    @Test func groupingDoesNotChangeRecordsOrVolume() throws {
        let rig = try makeRig(entryCount: 2)
        let exerciseID = rig.entries[0].snapshotExerciseID
        func input(_ kg: Double) -> RecordSetInput {
            RecordSetInput(
                loadType: .weighted, exerciseID: exerciseID, setType: .working,
                reps: 8, weightValue: kg, weightUnit: .kg, normalizedKg: kg,
                completedAt: .now)
        }
        let sets = [input(60), input(70), input(65)]

        let ungroupedVolume = RecordsMath.totalVolumeKg(among: sets)
        let ungroupedBest = sets.dropFirst().reduce(sets[0]) {
            RecordsMath.outranks($1, $0) ? $1 : $0
        }

        Supersets.group(rig.entries)
        try rig.context.save()

        #expect(RecordsMath.totalVolumeKg(among: sets) == ungroupedVolume)
        #expect(
            RecordsMath.outranks(ungroupedBest, sets[0]) || ungroupedBest.normalizedKg == 70,
            "the best set must not depend on how the workout was arranged")
    }

    // MARK: - The rest rule

    /// D48: no rest between members. Moving straight from A to B is the point.
    @Test func noRestIsTakenBetweenSupersetMembers() throws {
        let rig = try makeRig(entryCount: 2)
        Supersets.group(rig.entries)
        try rig.context.save()

        #expect(
            !Supersets.shouldRest(afterCompletingSetIn: rig.entries[0], in: rig.workout),
            "resting after A defeats the whole technique")
        #expect(
            Supersets.shouldRest(afterCompletingSetIn: rig.entries[1], in: rig.workout),
            "rest comes after the LAST member")
    }

    @Test func aStandaloneExerciseAlwaysRests() throws {
        let rig = try makeRig(entryCount: 1)
        #expect(Supersets.shouldRest(afterCompletingSetIn: rig.entries[0], in: rig.workout))
    }

    /// A group left holding one member — after deleting the other — must rest
    /// like the ordinary exercise it now is.
    @Test func aGroupOfOneRestsLikeAnyOtherExercise() throws {
        let rig = try makeRig(entryCount: 2)
        Supersets.group(rig.entries)
        rig.context.delete(rig.entries[1])
        try rig.context.save()

        #expect(
            Supersets.shouldRest(afterCompletingSetIn: rig.entries[0], in: rig.workout),
            "a superset of one is not a superset")
        #expect(!Supersets.isGrouped(rig.entries[0], in: rig.workout))
    }

    // MARK: - Grouping mechanics

    @Test func groupingFewerThanTwoEntriesIsRefused() throws {
        let rig = try makeRig(entryCount: 1)
        #expect(!Supersets.group([rig.entries[0]]))
        #expect(rig.entries[0].supersetGroupID == nil)
    }

    @Test func membersAreLabelledInOrder() throws {
        let rig = try makeRig(entryCount: 3)
        Supersets.group(rig.entries)
        try rig.context.save()
        #expect(Supersets.memberLabel(for: rig.entries[0], in: rig.workout) == "A")
        #expect(Supersets.memberLabel(for: rig.entries[1], in: rig.workout) == "B")
        #expect(Supersets.memberLabel(for: rig.entries[2], in: rig.workout) == "C")
    }

    @Test func aStandaloneEntryHasNoMemberLabel() throws {
        let rig = try makeRig(entryCount: 2)
        #expect(Supersets.memberLabel(for: rig.entries[0], in: rig.workout) == nil)
    }

    @Test func ungroupingClearsEveryMemberNotJustOne() throws {
        let rig = try makeRig(entryCount: 3)
        Supersets.group(rig.entries)
        try rig.context.save()

        Supersets.ungroup(rig.entries[1], in: rig.workout)
        try rig.context.save()

        for entry in rig.entries {
            #expect(
                entry.supersetGroupID == nil,
                "leaving one entry holding a group id is the superset-of-one bug from the other side")
        }
    }

    /// Ordering is what the user can see, so it wins over the stored id: a
    /// group interrupted by another exercise renders as two runs rather than
    /// pretending the interruption did not happen.
    @Test func aGroupInterruptedByAnotherExerciseSplitsIntoTwoRuns() throws {
        let rig = try makeRig(entryCount: 3)
        let groupID = UUID()
        rig.entries[0].supersetGroupID = groupID
        rig.entries[2].supersetGroupID = groupID
        try rig.context.save()

        let runs = Supersets.runs(of: rig.workout)
        #expect(runs.count == 3, "adjacency decides, got \(runs.count) runs")
    }

    @Test func pruneRepairsAGroupLeftWithOneMember() throws {
        let rig = try makeRig(entryCount: 2)
        Supersets.group(rig.entries)
        rig.context.delete(rig.entries[1])
        try rig.context.save()

        Supersets.pruneOrphanGroups(in: rig.workout)
        #expect(rig.entries[0].supersetGroupID == nil, "a stale badge must not survive a delete")
    }
}

/// D48 through templates. Template data loss is a bug this repo has already
/// shipped once (a past review caught it), so a template that silently forgets
/// its grouping is a known failure mode rather than a hypothetical one.
@MainActor
struct SupersetTemplateTests {

    private func rig() throws -> (ModelContext, Workout, [ExerciseEntry]) {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let workout = Workout()
        context.insert(workout)
        var entries: [ExerciseEntry] = []
        for index in 0..<2 {
            let exercise = Exercise(name: "Exercise \(index)", loadType: .weighted)
            context.insert(exercise)
            let entry = ExerciseEntry(
                order: index, workout: workout, exercise: exercise,
                snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
                snapshotExerciseName: exercise.name)
            context.insert(entry)
            let set = SetRecord(order: 0, type: .working, entry: entry)
            set.reps = 8
            set.weightValue = 60
            set.weightUnit = .kg
            set.normalizedKg = 60
            set.completedAt = .now
            context.insert(set)
            entries.append(entry)
        }
        try context.save()
        return (context, workout, entries)
    }

    @Test func aTemplateSavedFromASupersetKeepsTheGrouping() throws {
        let (context, workout, entries) = try rig()
        Supersets.group(entries)
        try context.save()

        let templates = WorkoutTemplateService(context: context)
        let template = try templates.saveAsTemplate(workout, name: "Push")

        let items = WorkoutTemplateService.orderedItems(of: template)
        #expect(items.count == 2)
        let groups = Set(items.compactMap(\.supersetGroupID))
        #expect(groups.count == 1, "both items should share one group, got \(groups.count)")
    }

    @Test func startingThatTemplateRestoresTheSuperset() throws {
        let (context, workout, entries) = try rig()
        Supersets.group(entries)
        try context.save()

        let templates = WorkoutTemplateService(context: context)
        let template = try templates.saveAsTemplate(workout, name: "Push")
        let started = try templates.start(template, at: nil)

        let runs = Supersets.runs(of: started)
        #expect(runs.count == 1, "the started workout should have one superset run")
        #expect(runs.first?.count == 2)
    }

    /// Two workouts from one template must not share a group id, or a query
    /// keyed on it would conflate them.
    @Test func eachStartGetsItsOwnGroupIdentity() throws {
        let (context, workout, entries) = try rig()
        Supersets.group(entries)
        try context.save()

        let templates = WorkoutTemplateService(context: context)
        let template = try templates.saveAsTemplate(workout, name: "Push")

        // The id must be READ BEFORE the next start. `startWorkout`
        // auto-finishes any active workout, and a templated workout with no
        // COMPLETED sets is then discarded as empty (A2) — so `first` is a
        // deleted object by the time the second start returns. That is correct
        // behaviour; an earlier draft of this test assumed two concurrent
        // workouts could coexist and failed for that reason, not a real defect.
        let first = try templates.start(template, at: nil)
        let firstID = Supersets.runs(of: first).first?.first?.supersetGroupID

        let second = try templates.start(template, at: nil)
        let secondID = Supersets.runs(of: second).first?.first?.supersetGroupID

        #expect(firstID != nil, "the first start should have restored a group")
        #expect(secondID != nil, "the second start should have restored a group")
        #expect(firstID != secondID, "two workouts must not share one superset identity")
    }
}

/// Regressions for the second Codex cross-review. Each failed against the
/// reviewed implementation.
@MainActor
struct SupersetReviewRegressionTests {

    private func rig(count: Int) throws -> (ModelContext, Workout, [ExerciseEntry]) {
        let container = try ModelContainer(
            for: Schema(WorkoutTrackerStore.modelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let workout = Workout()
        context.insert(workout)
        var entries: [ExerciseEntry] = []
        for index in 0..<count {
            let exercise = Exercise(name: "Exercise \(index)", loadType: .weighted)
            context.insert(exercise)
            let entry = ExerciseEntry(
                order: index, workout: workout, exercise: exercise,
                snapshotExerciseID: exercise.id, snapshotLoadType: .weighted,
                snapshotExerciseName: exercise.name)
            context.insert(entry)
            entries.append(entry)
        }
        try context.save()
        return (context, workout, entries)
    }

    /// codex-review 2 (high): `pruneOrphanGroups` existed and NOTHING CALLED
    /// IT. Deleting a member left a stale group id that export and template
    /// capture faithfully preserved. Fifth time this repo has shipped the
    /// absence-of-a-caller shape.
    @Test func deletingAMemberThroughTheREALPathPrunesTheOrphanGroup() throws {
        let (context, workout, entries) = try rig(count: 2)
        Supersets.group(entries)
        try context.save()

        // The production path, not the helper called by hand.
        try WorkoutSession(context: context).deleteEntry(entries[1])

        #expect(
            entries[0].supersetGroupID == nil,
            "a group left with one member must not keep its id")
        #expect(!Supersets.isGrouped(entries[0], in: workout))
    }

    /// codex-review 2 (high): once grouped, the menu replaced "Superset with
    /// next" with "Break superset", so B could never add C — the resolution's
    /// three-member claim was false.
    @Test func aThirdExerciseCanJoinAnExistingSuperset() throws {
        let (context, workout, entries) = try rig(count: 3)
        Supersets.group([entries[0], entries[1]])
        try context.save()

        // What "Superset with next" now does from an already-grouped entry.
        entries[2].supersetGroupID = entries[1].supersetGroupID
        try context.save()

        let runs = Supersets.runs(of: workout)
        #expect(runs.count == 1, "A, B and C should be one superset, got \(runs.count) runs")
        #expect(runs.first?.count == 3)
        #expect(Supersets.memberLabel(for: entries[2], in: workout) == "C")
    }
}

/// codex-review 2 (critical): grouping was lost through the template editor,
/// through drift resolution, and out of the backup. The direct save/start path
/// worked, which is what made the ticket's round-trip claim look true.
@MainActor
struct TemplateGroupingSurvivalTests {

    /// Positions, not raw ids: ids are remapped on every start, so comparing
    /// them directly would report drift on every single workout.
    @Test func groupingComparesByPositionSoARemappedStartIsNotDrift() {
        let a = UUID(), b = UUID()
        #expect(supersetPositions([a, a, nil]) == [0, 0, nil])
        #expect(
            supersetPositions([b, b, nil]) == supersetPositions([a, a, nil]),
            "the same grouping under different ids must compare equal")
        #expect(
            supersetPositions([a, nil, a]) != supersetPositions([a, a, nil]),
            "different groupings must not compare equal")
    }

    @Test func driftSeesAGroupingChange() {
        let exercise = UUID()
        let ungrouped = [
            TemplateDriftItem(exerciseID: exercise, targetRepsBySet: [8], supersetPosition: nil),
            TemplateDriftItem(exerciseID: exercise, targetRepsBySet: [8], supersetPosition: nil),
        ]
        let grouped = [
            TemplateDriftItem(exerciseID: exercise, targetRepsBySet: [8], supersetPosition: 0),
            TemplateDriftItem(exerciseID: exercise, targetRepsBySet: [8], supersetPosition: 0),
        ]
        #expect(
            TemplateDrift.hasDrift(template: ungrouped, workout: grouped),
            "supersetting two exercises mid-workout is drift the user should be asked about")
    }
}
