import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Barbell ticket 02 — the bar as a logging input (D39–D40).
///
/// The test that matters most is the first one: what gets stored is the TOTAL.
/// Everything downstream — records, volume, e1RM, the export's weight columns —
/// reads `weightValue` and knows nothing about bars, so a plates-only store
/// would drop every barbell PR by the weight of a bar without a single error.
struct BarbellLoggingTests {

    private struct Rig {
        var context: ModelContext
        var session: WorkoutSession
        var exercise: Exercise
        var gym: Gym
        var machine: MachineInstance
    }

    private func makeRig() throws -> Rig {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let exercise = Exercise(name: "Bench Press", equipmentTypeTags: [.barbell])
        let model = EquipmentModel(
            manufacturer: "Life Fitness", modelName: "Insignia Chest Press",
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

    /// A barbell entry with one draft row, ready for a bar.
    private func barbellEntry(
        _ rig: Rig, at date: Date = Date(timeIntervalSince1970: 100)
    ) throws -> (workout: Workout, entry: ExerciseEntry, set: SetRecord) {
        let workout = try rig.session.startWorkout(at: rig.gym, on: date)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .barbell)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        return (workout, entry, set)
    }

    private let olympicLb = BarPreset(
        id: "olympic-45lb", name: "Olympic barbell", value: 45, unit: .lb)
    private let olympicKg = BarPreset(
        id: "olympic-20kg", name: "Olympic barbell", value: 20, unit: .kg)

    // MARK: - The invariant: stored weight is the total

    @Test func perSideCommit_storesTheTotal() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)

        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("45", for: set)

        #expect(set.weightValue == 135)
        #expect(set.barWeightValue == 45)
        #expect(set.barNormalizedKg == 45 * WeightMath.kilogramsPerPound)
        #expect(set.weightUnit == .lb)
        // Normalized from the total, not from the plates (D25).
        let expectedKg = try #require(set.normalizedKg)
        #expect(abs(expectedKg - 135 * 0.45359237) < 1e-9)
    }

    @Test func recordsSeeTheTotal_notThePlates() throws {
        let rig = try makeRig()
        let (workout, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("45", for: set)
        try rig.session.commitReps("5", for: set)
        try rig.session.toggleCompletion(of: set)
        try rig.session.finish(workout)

        // A fresh entry in the same context, so the record layer has to read
        // history rather than the live row.
        let next = try rig.session.startWorkout(at: rig.gym)
        let nextEntry = try rig.session.addEntry(
            for: rig.exercise, to: next, freeWeightTag: .barbell)
        let summary = try PerformanceHistory(context: rig.context)
            .recordSummary(for: nextEntry, layer: .thisEquipment)
        let best = try #require(summary.repCountBests[5])
        #expect(best.weightValue == 135)
    }

    @Test func emptyBar_isARealSet() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicKg, for: entry)
        try rig.session.commitPerSide("0", for: set)
        try rig.session.commitReps("10", for: set)

        #expect(set.weightValue == 20)
        #expect(WorkoutSession.isLoggable(set))
        try rig.session.toggleCompletion(of: set)
        #expect(set.completedAt != nil)
    }

    @Test func emptyPerSideField_isNotLoggable() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicKg, for: entry)
        try rig.session.commitPerSide("", for: set)
        try rig.session.commitReps("10", for: set)

        #expect(set.weightValue == nil)
        #expect(!WorkoutSession.isLoggable(set))
    }

    @Test func platesPerSide_readsBackWhatWasTyped() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("22.5", for: set)

        #expect(set.weightValue == 90)
        #expect(WorkoutSession.platesPerSide(of: set) == 22.5)
    }

    // MARK: - Choosing and clearing a bar

    @Test func chooseBar_leavesCompletedSetsAlone() throws {
        let rig = try makeRig()
        let (_, entry, first) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("45", for: first)
        try rig.session.commitReps("5", for: first)
        try rig.session.toggleCompletion(of: first)

        let draft = try rig.session.addSet(to: entry)
        try rig.session.chooseBar(olympicKg, for: entry)

        // History is not rewritten by picking up a different bar.
        #expect(first.weightValue == 135)
        #expect(first.barWeightValue == 45)
        #expect(first.weightUnit == .lb)
        #expect(draft.barWeightValue == 20)
        #expect(draft.weightUnit == .kg)
    }

    @Test func chooseBar_matchingUnit_keepsTheTotal() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        // Typed as a total in lb, then a bar is chosen.
        try rig.session.toggleUnit(of: set)
        #expect(set.weightUnit == .lb)
        try rig.session.commitWeight("135", for: set)

        try rig.session.chooseBar(olympicLb, for: entry)

        // The stored number never meant anything but the total, so it stays —
        // only what the field displays changes.
        #expect(set.weightValue == 135)
        #expect(WorkoutSession.platesPerSide(of: set) == 45)
    }

    @Test func chooseBar_otherUnit_dropsTheValueRatherThanReinterpretIt() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.commitWeight("60", for: set) // 60 kg total

        try rig.session.chooseBar(olympicLb, for: entry)

        // D25/D40: 60 kg is not 60 lb, and the app converts nothing silently.
        #expect(set.weightValue == nil)
        #expect(set.normalizedKg == nil)
        #expect(set.weightUnit == .lb)
        #expect(set.barWeightValue == 45)
        #expect(set.barNormalizedKg == 45 * WeightMath.kilogramsPerPound)
    }

    @Test func chooseBar_totalLighterThanTheBar_dropsTheValue() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.toggleUnit(of: set)
        try rig.session.commitWeight("20", for: set) // 20 lb total

        try rig.session.chooseBar(olympicLb, for: entry) // 45 lb bar

        // There is no honest plate count for 20 lb on a 45 lb bar.
        #expect(set.weightValue == nil)
        #expect(set.barWeightValue == 45)
    }

    @Test func clearingTheBar_keepsTheTotal() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("45", for: set)

        try rig.session.chooseBar(nil, for: entry)

        #expect(set.barWeightValue == nil)
        #expect(set.barNormalizedKg == nil)
        #expect(set.weightValue == 135, "the stored number was always the total")
    }

    @Test func customBar_acceptsAnyPositiveWeight_andRejectsTheRest() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)

        try rig.session.chooseBar(weight: 15.5, unit: .kg, for: entry)
        #expect(set.barWeightValue == 15.5)

        // Zero is not a bar — "no bar" is nil, and two encodings of one state
        // is one too many.
        try rig.session.chooseBar(weight: 0, unit: .kg, for: entry)
        #expect(set.barWeightValue == nil)
    }

    @Test func choosingABar_withEveryRowLogged_makesTheRowItAppliesTo() throws {
        let rig = try makeRig()
        let (_, entry, first) = try barbellEntry(rig)
        try rig.session.commitWeight("60", for: first)
        try rig.session.commitReps("10", for: first)
        // Every row of the entry is now logged, which is the ordinary state
        // after finishing a set — nothing is waiting to receive the bar.
        try rig.session.toggleCompletion(of: first)

        try rig.session.chooseBar(olympicLb, for: entry)

        // A control that silently does nothing is worse than one that acts.
        let draft = try #require(
            WorkoutSession.orderedSets(of: entry).first { $0.completedAt == nil })
        #expect(draft.barWeightValue == 45)
        #expect(draft.weightUnit == .lb)
        #expect(first.barWeightValue == nil, "the logged set is untouched")
        #expect(first.weightValue == 60)
    }

    @Test func unitToggle_isRefusedInBarMode() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicKg, for: entry)

        try rig.session.toggleUnit(of: set)

        // A 20 kg bar must not become a 20 lb bar on a stray tap (D40).
        #expect(set.weightUnit == .kg)
        #expect(set.barWeightValue == 20)
    }

    @Test func barIsOfferedForBarbellWorkOnly_recordedEitherWay() throws {
        let rig = try makeRig()
        let workout = try rig.session.startWorkout(at: rig.gym)

        let barbell = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .barbell)
        #expect(WorkoutSession.offersBar(barbell))

        let smith = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .smith)
        #expect(WorkoutSession.offersBar(smith))

        let cable = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .cable)
        #expect(!WorkoutSession.offersBar(cable))

        // A selectorized machine loads no bar.
        let machine = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        #expect(!WorkoutSession.offersBar(machine))

        // …but a rack or Smith picked from the catalog is barbell work
        // recorded as a machine, and it is exactly where the bar's weight is
        // hardest to guess.
        let rackModel = EquipmentModel(
            manufacturer: "Rogue", modelName: "Monster Rack",
            exerciseIDs: [rig.exercise.id], equipmentType: .rackOrSmith)
        let rack = MachineInstance(label: "Rack 1", gym: rig.gym, model: rackModel)
        rig.context.insert(rackModel)
        rig.context.insert(rack)
        try rig.context.save()
        let rackEntry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rack)
        #expect(WorkoutSession.offersBar(rackEntry))
    }

    // MARK: - The bar follows the numbers it explains

    @Test func carryForward_copiesTheBar() throws {
        let rig = try makeRig()
        let (_, entry, first) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("45", for: first)
        try rig.session.commitReps("5", for: first)
        try rig.session.toggleCompletion(of: first)

        let next = try rig.session.addSet(to: entry)
        #expect(next.barWeightValue == 45)
        #expect(next.barNormalizedKg == 45 * WeightMath.kilogramsPerPound)
        #expect(next.weightUnit == .lb)
        #expect(next.weightValue == 135)
        #expect(next.reps == 5)
        #expect(next.prefilledAt != nil, "inherited, not typed")
    }

    @Test func carryForward_takesBarAndUnitFromTheSameCompletedSet() throws {
        let rig = try makeRig()
        let (_, entry, completed) = try barbellEntry(rig)
        try rig.session.commitWeight("60", for: completed)
        try rig.session.commitReps("8", for: completed)
        try rig.session.toggleCompletion(of: completed)

        // Configure the existing draft differently without logging it. Add Set
        // must not splice this draft's 45 lb bar onto the completed kg set's
        // weight/unit/reps.
        let differentlyConfiguredDraft = try rig.session.addSet(to: entry)
        try rig.session.chooseBar(olympicLb, for: entry)
        #expect(differentlyConfiguredDraft.barWeightValue == 45)
        #expect(differentlyConfiguredDraft.weightUnit == .lb)

        let next = try rig.session.addSet(to: entry)

        #expect(next.weightValue == 60)
        #expect(next.weightUnit == .kg)
        #expect(next.reps == 8)
        #expect(
            next.barWeightValue == nil,
            "bar, unit, total, and reps must come from one carry-forward source")
    }

    @Test func prefill_carriesTheBarAcrossWorkouts() throws {
        let rig = try makeRig()
        let (workout, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("45", for: set)
        try rig.session.commitReps("5", for: set)
        try rig.session.toggleCompletion(of: set)
        try rig.session.finish(workout)

        let today = try rig.session.startWorkout(at: rig.gym)
        let todayEntry = try rig.session.addEntry(
            for: rig.exercise, to: today, freeWeightTag: .barbell)
        let row = try #require(WorkoutSession.orderedSets(of: todayEntry).first)
        let history = PerformanceHistory(context: rig.context)
        let candidate = try #require(try history.prefill(for: row))
        #expect(candidate.barWeight?.value == 45)
        #expect(try history.applyPrefill(candidate, to: row, isDirty: false))

        // Without the bar, the row would show last session's *total* in a field
        // the user reads as plates.
        #expect(row.barWeightValue == 45)
        #expect(row.barNormalizedKg == 45 * WeightMath.kilogramsPerPound)
        #expect(row.weightValue == 135)
        #expect(WorkoutSession.platesPerSide(of: row) == 45)
    }

    @Test func presetChange_keepsTheBar() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        let preset = ExercisePreset(name: "Close grip", order: 0, exercise: rig.exercise)
        rig.context.insert(preset)
        try rig.context.save()

        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.choosePreset(preset, for: entry)

        // Changing grip does not put a different bar in the user's hands.
        #expect(set.barWeightValue == 45)
    }

    @Test func equipmentChange_dropsTheBar() throws {
        let rig = try makeRig()
        let (_, entry, set) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)

        try rig.session.chooseEquipment(for: entry, machine: rig.machine, freeWeightTag: nil)

        // A 45 lb bar on a selectorized press would add a bar's weight to sets
        // performed without one.
        #expect(set.barWeightValue == nil)
    }

    @Test func equipmentChange_afterFreeze_dropsTheBarOnMovedDraftsOnly() throws {
        let rig = try makeRig()
        let (_, entry, first) = try barbellEntry(rig)
        try rig.session.chooseBar(olympicLb, for: entry)
        try rig.session.commitPerSide("45", for: first)
        try rig.session.commitReps("5", for: first)
        try rig.session.toggleCompletion(of: first)
        let draft = try rig.session.addSet(to: entry)

        let split = try rig.session.chooseEquipment(
            for: entry, machine: rig.machine, freeWeightTag: nil)

        #expect(split.id != entry.id, "a frozen entry splits (D19)")
        #expect(draft.entry?.id == split.id)
        #expect(draft.barWeightValue == nil)
        // The completed set stays behind, with its bar and its total intact.
        #expect(first.entry?.id == entry.id)
        #expect(first.barWeightValue == 45)
        #expect(first.weightValue == 135)
    }

    @Test func openingAStoreBackfillsAndPersistsMissingBarNormalization() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "bar-repair-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "WorkoutTracker.store")

        // Reproduce the short-lived installed schema's state: valid bar value
        // and row unit, but no persisted normalized bar value.
        do {
            let schema = WorkoutTrackerStore.schema
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            context.insert(SetRecord(
                order: 0, weightUnit: .lb,
                barWeightValue: 45, barNormalizedKg: nil))
            try context.save()
        }

        let reopened = try WorkoutTrackerStore.makeContainer(url: url)
        let reopenedContext = ModelContext(reopened)
        let repaired = try #require(
            try reopenedContext.fetch(FetchDescriptor<SetRecord>()).first)
        #expect(repaired.barWeightValue == 45)
        #expect(repaired.weightUnit == .lb)
        #expect(repaired.barNormalizedKg == 45 * WeightMath.kilogramsPerPound)

        // The repair is persisted, not merely derived by the accessor.
        #expect(try BarWeightStoreRepair.backfill(in: reopenedContext) == 0)
    }
}
