import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Ticket 17 A1 + B1 — the two honesty/speed rules of the set row:
/// a set may only be completed once it says something true, and a new set
/// inherits what the last completed one said.
struct SetLoggingTests {
    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private struct Rig {
        var context: ModelContext
        var session: WorkoutSession
        var exercise: Exercise
        var gym: Gym
        var machine: MachineInstance
    }

    private func makeRig(loadType: LoadType = .weighted) throws -> Rig {
        let context = try makeContext()
        let exercise = Exercise(name: "Press", loadType: loadType)
        let model = EquipmentModel(
            manufacturer: "Life Fitness", modelName: "Insignia",
            exerciseIDs: [exercise.id])
        let gym = Gym(name: "Gym", defaultUnit: .kg)
        let machine = MachineInstance(label: "Press 1", gym: gym, model: model)
        for object in [exercise, model, gym, machine] as [any PersistentModel] {
            context.insert(object)
        }
        try context.save()
        return Rig(
            context: context, session: WorkoutSession(context: context),
            exercise: exercise, gym: gym, machine: machine)
    }

    private func firstDraft(_ rig: Rig, at date: Date = Date(timeIntervalSince1970: 100))
        throws -> (workout: Workout, entry: ExerciseEntry, set: SetRecord) {
        let workout = try rig.session.startWorkout(at: rig.gym, on: date)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        return (workout, entry, set)
    }

    // MARK: - A1: an empty set cannot be completed

    /// The predicate itself, over every load type: reps must be positive, and
    /// only plain bodyweight may log without a weight value. Zero is a real
    /// answer for assisted/bodyweightPlus; nil never is.
    @Test func loggabilityRulesPerLoadType() {
        for loadType in LoadType.allCases {
            // No reps at all.
            #expect(!WorkoutSession.isLoggable(
                reps: nil, weightValue: 60, loadType: loadType))
            // Zero reps is not a set.
            #expect(!WorkoutSession.isLoggable(
                reps: 0, weightValue: 60, loadType: loadType))
            // Reps + a weight value always works.
            #expect(WorkoutSession.isLoggable(
                reps: 10, weightValue: 60, loadType: loadType))
        }

        // Reps alone: only plain bodyweight.
        #expect(WorkoutSession.isLoggable(
            reps: 10, weightValue: nil, loadType: .bodyweight))
        #expect(!WorkoutSession.isLoggable(
            reps: 10, weightValue: nil, loadType: .weighted))
        #expect(!WorkoutSession.isLoggable(
            reps: 10, weightValue: nil, loadType: .assisted))
        #expect(!WorkoutSession.isLoggable(
            reps: 10, weightValue: nil, loadType: .bodyweightPlus))

        // Zero load is meaningful where it means "unassisted" / "no added
        // weight" (ticket 12 eligibility) — and harmless elsewhere.
        #expect(WorkoutSession.isLoggable(
            reps: 10, weightValue: 0, loadType: .assisted))
        #expect(WorkoutSession.isLoggable(
            reps: 10, weightValue: 0, loadType: .bodyweightPlus))
    }

    /// A1: the empty row that used to persist as `— × —` now refuses, and
    /// leaves no trace — no completion stamp, no D23 snapshot, no memory row.
    @Test func completingAnEmptySetThrowsAndChangesNothing() throws {
        let rig = try makeRig()
        let (_, entry, set) = try firstDraft(rig)

        #expect(throws: WorkoutSessionError.setNotLoggable) {
            try rig.session.toggleCompletion(of: set)
        }
        #expect(set.completedAt == nil)
        #expect(entry.snapshotCapturedAt == nil)
        #expect(try rig.context.fetch(FetchDescriptor<GymExerciseMemory>()).isEmpty)

        // Reps alone are still not enough for a weighted exercise.
        try rig.session.commitReps("10", for: set)
        #expect(throws: WorkoutSessionError.setNotLoggable) {
            try rig.session.toggleCompletion(of: set)
        }
        // Zero reps is not a set either.
        try rig.session.commitWeight("60", for: set)
        try rig.session.commitReps("0", for: set)
        #expect(throws: WorkoutSessionError.setNotLoggable) {
            try rig.session.toggleCompletion(of: set)
        }

        try rig.session.commitReps("10", for: set)
        try rig.session.toggleCompletion(of: set)
        #expect(set.completedAt != nil)
        #expect(entry.snapshotCapturedAt != nil)
    }

    /// Plain bodyweight logs on reps alone; the other three load types need a
    /// value, but accept zero.
    @Test func loadTypeSpecificCompletionRules() throws {
        // bodyweight: reps only.
        let bodyweight = try makeRig(loadType: .bodyweight)
        let bwRow = try firstDraft(bodyweight).set
        try bodyweight.session.commitReps("20", for: bwRow)
        try bodyweight.session.toggleCompletion(of: bwRow)
        #expect(bwRow.completedAt != nil)

        // assisted: zero assistance is a real answer, nil is not.
        let assisted = try makeRig(loadType: .assisted)
        let assistedRow = try firstDraft(assisted).set
        try assisted.session.commitReps("8", for: assistedRow)
        #expect(throws: WorkoutSessionError.setNotLoggable) {
            try assisted.session.toggleCompletion(of: assistedRow)
        }
        try assisted.session.commitWeight("0", for: assistedRow)
        try assisted.session.toggleCompletion(of: assistedRow)
        #expect(assistedRow.completedAt != nil)
        #expect(assistedRow.weightValue == 0)

        // bodyweightPlus: same — zero added weight logs.
        let plus = try makeRig(loadType: .bodyweightPlus)
        let plusRow = try firstDraft(plus).set
        try plus.session.commitReps("6", for: plusRow)
        #expect(throws: WorkoutSessionError.setNotLoggable) {
            try plus.session.toggleCompletion(of: plusRow)
        }
        try plus.session.commitWeight("0", for: plusRow)
        try plus.session.toggleCompletion(of: plusRow)
        #expect(plusRow.completedAt != nil)
    }

    /// Post-review regression (D19/D23): once the entry's snapshot is frozen,
    /// the SNAPSHOT's load type decides what the remaining rows must carry. A
    /// catalog reconciliation or an exercise edit mid-workout used to relax
    /// the rule under a half-logged exercise, so a weighted snapshot would
    /// accept reps-only and put `— × reps` rows back into history.
    @Test func frozenEntriesValidateWithTheSnapshotLoadTypeNotTheLiveOne() throws {
        let rig = try makeRig(loadType: .weighted)
        let (_, entry, first) = try firstDraft(rig)
        try rig.session.commitWeight("60", for: first)
        try rig.session.commitReps("10", for: first)
        try rig.session.toggleCompletion(of: first)
        #expect(entry.snapshotCapturedAt != nil)
        #expect(entry.snapshotLoadType == .weighted)

        // The live catalog row changes underneath the frozen entry.
        rig.exercise.loadType = .bodyweight
        try rig.context.save()

        #expect(entry.effectiveLoadType == .weighted)
        let second = try rig.session.addSet(to: entry)
        try rig.session.commitWeight("", for: second)
        try rig.session.commitReps("12", for: second)
        #expect(WorkoutSession.loadType(of: second) == .weighted)
        #expect(!WorkoutSession.isLoggable(second))
        #expect(throws: WorkoutSessionError.setNotLoggable) {
            try rig.session.toggleCompletion(of: second)
        }
        #expect(second.completedAt == nil)

        // Before the freeze the live exercise still owns the answer: a fresh
        // entry for the same (now bodyweight) exercise logs on reps alone.
        let workout = try #require(entry.workout)
        let fresh = try rig.session.addEntry(for: rig.exercise, to: workout)
        let freshSet = try #require(WorkoutSession.orderedSets(of: fresh).first)
        #expect(fresh.effectiveLoadType == .bodyweight)
        try rig.session.commitReps("15", for: freshSet)
        try rig.session.toggleCompletion(of: freshSet)
        #expect(freshSet.completedAt != nil)
    }

    /// The UI judges the text on screen; the store judges the parsed values.
    /// They must be one rule — a negative, NaN, or infinite weight used to
    /// enable the checkmark and then be rejected, so the tap did nothing.
    @Test func onScreenLoggabilityMatchesWhatTheStoreAccepts() throws {
        #expect(WorkoutSession.weightValue(from: "60") == 60)
        #expect(WorkoutSession.weightValue(from: " 60,5 ") == 60.5)
        #expect(WorkoutSession.weightValue(from: "0") == 0)
        for rejected in ["-5", "nan", "inf", "-inf", "abc", ""] {
            #expect(
                WorkoutSession.weightValue(from: rejected) == nil,
                "\(rejected) is not a weight")
            #expect(!WorkoutSession.isLoggable(
                weightText: rejected, repsText: "10", loadType: .weighted))
        }
        #expect(WorkoutSession.isLoggable(
            weightText: "60", repsText: "10", loadType: .weighted))
        // Bodyweight ignores the weight field entirely, invalid or not.
        #expect(WorkoutSession.isLoggable(
            weightText: "-5", repsText: "10", loadType: .bodyweight))

        // And the store agrees: an invalid weight leaves the row unloggable.
        let rig = try makeRig()
        let set = try firstDraft(rig).set
        try rig.session.commitWeight("-5", for: set)
        try rig.session.commitReps("10", for: set)
        #expect(set.weightValue == nil)
        #expect(!WorkoutSession.isLoggable(set))
        #expect(throws: WorkoutSessionError.setNotLoggable) {
            try rig.session.toggleCompletion(of: set)
        }
    }

    /// The guard only ever blocks the completing direction: an already
    /// completed row — including one stored before the rule existed — can
    /// always be un-completed.
    @Test func alreadyCompletedSetsAreNeverInvalidatedByTheGuard() throws {
        let rig = try makeRig()
        let (_, entry, set) = try firstDraft(rig)
        try rig.session.commitWeight("60", for: set)
        try rig.session.commitReps("10", for: set)
        try rig.session.toggleCompletion(of: set)
        try rig.session.toggleCompletion(of: set) // undo, values intact
        #expect(set.completedAt == nil)
        #expect(set.weightValue == 60)
        try rig.session.toggleCompletion(of: set) // and back again
        #expect(set.completedAt != nil)

        // Legacy row: completed with nothing logged. Un-completing it must
        // not throw.
        let legacy = SetRecord(
            order: 9, completedAt: Date(timeIntervalSince1970: 1), entry: entry)
        rig.context.insert(legacy)
        try rig.context.save()
        try rig.session.toggleCompletion(of: legacy)
        #expect(legacy.completedAt == nil)
    }

    // MARK: - B1: within-session carry-forward

    /// A new row inherits weight value, unit and reps from the last completed
    /// set of the same entry — populated but uncompleted, so one tap logs it.
    @Test func addSetCarriesForwardTheLastCompletedSet() throws {
        let rig = try makeRig()
        let (_, entry, first) = try firstDraft(rig)
        try rig.session.commitWeight("60", for: first)
        try rig.session.commitReps("10", for: first)
        try rig.session.toggleUnit(of: first) // kg → lb, as entered
        try rig.session.toggleCompletion(of: first)

        let second = try rig.session.addSet(to: entry)
        #expect(second.weightValue == 60)
        #expect(second.weightUnit == .lb)
        #expect(second.reps == 10)
        #expect(second.normalizedKg == first.normalizedKg)
        // Arrives as a draft: carry-forward proposes, it never logs.
        #expect(second.completedAt == nil)

        // One tap, no typing.
        try rig.session.toggleCompletion(of: second)
        #expect(second.completedAt != nil)

        // A third row keeps following the newest completed set.
        try rig.session.commitWeight("65", for: second)
        let third = try rig.session.addSet(to: entry)
        #expect(third.weightValue == 65)
        #expect(third.reps == 10)
    }

    /// With nothing completed yet, `addSet` behaves exactly as before: an
    /// empty row carrying only the unit, left for ticket 11's cross-workout
    /// prefill to populate.
    @Test func addSetWithoutACompletedSetKeepsTheOldBehaviour() throws {
        let rig = try makeRig()
        let (_, entry, first) = try firstDraft(rig)
        try rig.session.commitWeight("60", for: first)
        try rig.session.commitReps("10", for: first) // typed, never completed
        try rig.session.toggleUnit(of: first)

        let second = try rig.session.addSet(to: entry)
        #expect(second.weightValue == nil)
        #expect(second.reps == nil)
        #expect(second.normalizedKg == nil)
        #expect(second.weightUnit == .lb) // unit still follows the last row
        #expect(second.completedAt == nil)
    }

    /// The source is the last *completed* set, not the last row — a draft
    /// row someone half-typed into does not become the template.
    @Test func carryForwardIgnoresLaterDraftRows() throws {
        let rig = try makeRig()
        let (_, entry, first) = try firstDraft(rig)
        try rig.session.commitWeight("60", for: first)
        try rig.session.commitReps("10", for: first)
        try rig.session.toggleCompletion(of: first)

        let second = try rig.session.addSet(to: entry)
        try rig.session.commitWeight("999", for: second) // draft, uncompleted

        let third = try rig.session.addSet(to: entry)
        #expect(third.weightValue == 60)
        #expect(third.reps == 10)
        #expect(third.order == 2)
    }

    /// Today's numbers outrank last week's: the cross-workout candidate is
    /// still selected (the PREVIOUS column keeps its meaning) but it must not
    /// overwrite a carried-forward row.
    @Test func carryForwardSurvivesCrossWorkoutPrefill() throws {
        let rig = try makeRig()
        // A finished workout on the same machine: 100 kg × 5, then 90 kg × 5.
        let past = try rig.session.startWorkout(
            at: rig.gym, on: Date(timeIntervalSince1970: 100))
        let pastEntry = try rig.session.addEntry(
            for: rig.exercise, to: past, machine: rig.machine)
        for (index, weight) in ["100", "90"].enumerated() {
            let row = index == 0
                ? try #require(WorkoutSession.orderedSets(of: pastEntry).first)
                : try rig.session.addSet(to: pastEntry)
            try rig.session.commitWeight(weight, for: row)
            try rig.session.commitReps("5", for: row)
            try rig.session.toggleCompletion(
                of: row, at: Date(timeIntervalSince1970: TimeInterval(110 + index)))
        }
        try rig.session.finish(past, at: Date(timeIntervalSince1970: 200))

        let (_, entry, first) = try firstDraft(rig, at: Date(timeIntervalSince1970: 300))
        try rig.session.commitWeight("60", for: first)
        try rig.session.commitReps("10", for: first)
        try rig.session.toggleCompletion(of: first, at: Date(timeIntervalSince1970: 310))

        let second = try rig.session.addSet(to: entry)
        let history = PerformanceHistory(context: rig.context)
        // The reference label still resolves to the historical set…
        let candidate = try #require(try history.prefill(for: second))
        #expect(candidate.displayLabel == "90 kg × 5")
        // …but it does not touch the inputs.
        #expect(try !history.applyPrefill(candidate, to: second, isDirty: false))
        #expect(second.weightValue == 60)
        #expect(second.reps == 10)
    }

    // MARK: - Ticket 18 B: the consequences of deleting a set

    /// Deleting a completed set has to be a real undo, not a cosmetic one:
    /// the entry's remaining sets renumber, records and volume recompute
    /// without it, and carry-forward re-seeds from the NEW last completed set.
    @Test func deletingTheLastCompletedSetReseedsCarryForwardAndRecomputes() throws {
        let rig = try makeRig()
        let (_, entry, first) = try firstDraft(rig)
        try rig.session.commitWeight("60", for: first)
        try rig.session.commitReps("10", for: first)
        try rig.session.toggleCompletion(of: first, at: Date(timeIntervalSince1970: 110))

        let second = try rig.session.addSet(to: entry)
        try rig.session.commitWeight("100", for: second)
        try rig.session.commitReps("3", for: second)
        try rig.session.toggleCompletion(of: second, at: Date(timeIntervalSince1970: 120))

        // A third row follows the newest completed set (100 × 3)…
        let third = try rig.session.addSet(to: entry)
        #expect(third.weightValue == 100)
        #expect(third.reps == 3)

        // …until that set is deleted as a mistake.
        try rig.session.deleteSet(second)
        try rig.session.deleteSet(third)
        #expect(WorkoutSession.orderedSets(of: entry).count == 1)
        #expect(WorkoutSession.orderedSets(of: entry).map(\.order) == [0])

        let replacement = try rig.session.addSet(to: entry)
        #expect(replacement.weightValue == 60, "Carry-forward must re-seed from 60 × 10")
        #expect(replacement.reps == 10)
        #expect(replacement.order == 1)

        // Records and volume are derived, so they lose the deleted set too:
        // 60 × 10 only, and no 3-rep record at all.
        let inputs = WorkoutSession.orderedSets(of: entry)
            .filter { $0.completedAt != nil }
            .map { set in
                RecordSetInput(
                    loadType: entry.snapshotLoadType,
                    exerciseID: entry.snapshotExerciseID,
                    machineID: entry.snapshotMachineID,
                    setType: set.type,
                    reps: set.reps,
                    weightValue: set.weightValue,
                    weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg,
                    completedAt: set.completedAt)
            }
        #expect(abs(RecordsMath.totalVolumeKg(among: inputs) - 600) < 1e-9)
        let bests = RecordsMath.repCountBests(among: inputs, loadType: .weighted)
        #expect(bests[3] == nil, "The deleted set must not hold a record")
        #expect(try #require(bests[10]).weightValue == 60)
    }

    /// Deleting an entry's only set leaves the entry standing and usable —
    /// empty-entry pruning is ticket 17's *finish* step, not something that
    /// happens under the user mid-workout.
    @Test func deletingTheOnlySetLeavesTheEntryIntactAndUsable() throws {
        let rig = try makeRig()
        let (workout, entry, only) = try firstDraft(rig)
        try rig.session.commitWeight("60", for: only)
        try rig.session.commitReps("10", for: only)
        try rig.session.toggleCompletion(of: only, at: Date(timeIntervalSince1970: 110))

        try rig.session.deleteSet(only)
        #expect(!entry.isDeleted, "The entry must survive losing its last set")
        #expect(WorkoutSession.orderedSets(of: entry).isEmpty)
        #expect(WorkoutSession.orderedEntries(of: workout).count == 1)

        // Still usable: a fresh row logs normally.
        let replacement = try rig.session.addSet(to: entry)
        #expect(replacement.order == 0)
        #expect(replacement.completedAt == nil)
        try rig.session.commitWeight("65", for: replacement)
        try rig.session.commitReps("8", for: replacement)
        try rig.session.toggleCompletion(
            of: replacement, at: Date(timeIntervalSince1970: 120))
        #expect(replacement.completedAt == Date(timeIntervalSince1970: 120))

        // And it reaches history, because it was never orphaned.
        #expect(try rig.session.finish(
            workout, at: Date(timeIntervalSince1970: 200)) == .saved)
        #expect(workout.finishedAt == Date(timeIntervalSince1970: 200))
    }
}
