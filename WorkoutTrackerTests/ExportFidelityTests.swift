import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

// Milestone 3, ticket 03 — the collector against a store built the way the app
// builds one: the real seeded catalog, workouts logged through
// `WorkoutSession`. Ticket 01's tests prove the encoders; these prove that what
// reaches them is the user's actual training history, whole.

struct ExportFidelityTests {

    // MARK: - Rig

    private struct Rig {
        var context: ModelContext
        var session: WorkoutSession
        var gym: Gym
        var machine: MachineInstance
        var model: EquipmentModel
        var exercise: Exercise
        var collector: ExportCollector
    }

    /// An in-memory store carrying the shipped catalog (D24 reconciliation, the
    /// same call the app makes at launch), one gym, and one machine whose model
    /// is a real catalog row linked to a real weighted exercise.
    private func makeRig() throws -> Rig {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exercisesByID = Dictionary(
            exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // A catalog model whose first linked exercise is weighted — volume (D21)
        // only counts weighted work, and this rig's whole point is to reconcile
        // exported rows against it.
        let model = try #require(
            try context.fetch(FetchDescriptor<EquipmentModel>())
                .sorted { $0.displayName < $1.displayName }
                .first {
                    guard let first = $0.exerciseIDs.first else { return false }
                    return exercisesByID[first]?.loadType == .weighted
                },
            "the seeded catalog must contain a weighted machine")
        let exerciseID = try #require(model.exerciseIDs.first)
        let exercise = try #require(exercisesByID[exerciseID])

        let gym = Gym(name: "Gold's Gym, Gangnam", city: "Seoul", defaultUnit: .kg)
        let machine = MachineInstance(label: "Chest Press #2", gym: gym, model: model)
        context.insert(gym)
        context.insert(machine)
        try context.save()

        return Rig(
            context: context,
            session: WorkoutSession(context: context),
            gym: gym, machine: machine, model: model, exercise: exercise,
            collector: ExportCollector(
                dateFormat: ExportDateFormat(timeZone: TimeZone(secondsFromGMT: 9 * 3_600)!),
                appVersion: "test"))
    }

    /// Logs `sets` (weight, reps, type) on the rig's machine and finishes the
    /// workout, exactly as the app's own flow would.
    @discardableResult
    private func logWorkout(
        _ rig: Rig,
        sets: [(weight: Double, reps: Int, type: SetType)],
        startingAt start: Date = Date(timeIntervalSince1970: 1_000_000)
    ) throws -> Workout {
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        for (index, plan) in sets.enumerated() {
            let set: SetRecord
            if index == 0 {
                // Every entry arrives with one draft row already.
                set = try #require(WorkoutSession.orderedSets(of: entry).first)
            } else {
                set = try rig.session.addSet(to: entry)
            }
            try rig.session.setType(plan.type, of: set)
            try rig.session.commitWeight(String(plan.weight), for: set)
            try rig.session.commitReps(String(plan.reps), for: set)
            try rig.session.toggleCompletion(
                of: set, at: start.addingTimeInterval(Double(index + 1) * 60))
        }
        _ = try rig.session.finish(
            workout, at: start.addingTimeInterval(Double(sets.count + 1) * 60))
        return workout
    }

    private func exportRows(_ rig: Rig) throws -> [[String]] {
        let snapshot = try rig.collector.snapshot(from: rig.context)
        return Array(TestCSV.rows(ExportCSV.render(snapshot)).dropFirst())
    }

    // MARK: - D28: the user's data, not the shipped catalog

    @Test func exportCarriesOnlyTheCatalogRowsTheUsersDataReferences() throws {
        let rig = try makeRig()
        try logWorkout(rig, sets: [(60, 10, .working)])

        let storedModels = try rig.context.fetchCount(FetchDescriptor<EquipmentModel>())
        let storedExercises = try rig.context.fetchCount(FetchDescriptor<Exercise>())
        #expect(storedModels > 1_000, "sanity: the rig really did seed the catalog")

        let snapshot = try rig.collector.snapshot(from: rig.context)
        #expect(snapshot.equipmentModels.map(\.id) == [rig.model.id])
        #expect(snapshot.exercises.map(\.id) == [rig.exercise.id])
        #expect(snapshot.equipmentModels.count < storedModels)
        #expect(snapshot.exercises.count < storedExercises)
        // The version is recorded so the omitted rows stay reproducible.
        #expect(snapshot.seededCatalogVersion == (try SeedCatalog.bundled().version))
    }

    /// A user-created exercise is theirs, referenced or not — it cannot be
    /// reproduced from the app the way a seeded row can.
    @Test func exportKeepsUserCreatedRowsEvenWhenNothingReferencesThem() throws {
        let rig = try makeRig()
        let invented = Exercise(name: "Standing Calf Thing", loadType: .weighted)
        let inventedModel = EquipmentModel(
            manufacturer: "Unknown", modelName: "Corner machine, no badge")
        rig.context.insert(invented)
        rig.context.insert(inventedModel)
        try rig.context.save()

        let snapshot = try rig.collector.snapshot(from: rig.context)
        #expect(snapshot.exercises.contains { $0.id == invented.id })
        #expect(snapshot.equipmentModels.contains { $0.id == inventedModel.id })
    }

    // MARK: - D23: snapshots, not live rows

    @Test func renamingAGymDoesNotRewriteAlreadyExportedHistory() throws {
        let rig = try makeRig()
        try logWorkout(rig, sets: [(60, 10, .working)])

        rig.gym.name = "Some Other Gym"
        rig.machine.label = "Renamed Machine"
        try rig.context.save()

        let row = try #require(try exportRows(rig).first)
        #expect(TestCSV.value("gymName", in: row) == "Gold's Gym, Gangnam")
        #expect(TestCSV.value("machineLabel", in: row) == "Chest Press #2")
        // The live gym row exports under its current name — the export is not
        // stale, the *history* is snapshotted.
        let snapshot = try rig.collector.snapshot(from: rig.context)
        #expect(snapshot.gyms.first?.name == "Some Other Gym")
    }

    // MARK: - D30: nothing silently dropped

    @Test func everyLoggedSetAppearsExactlyOnce() throws {
        let rig = try makeRig()
        try logWorkout(
            rig,
            sets: [(40, 12, .warmup), (60, 10, .working), (60, 8, .working), (45, 6, .drop)])

        let rows = try exportRows(rig)
        #expect(rows.count == 4)
        let ids = rows.compactMap { TestCSV.value("setID", in: $0) }
        #expect(Set(ids).count == 4, "no set may appear twice")
        #expect(rows.compactMap { TestCSV.value("setType", in: $0) }
            == ["warmup", "working", "working", "drop"])
        #expect(rows.allSatisfy { TestCSV.value("completed", in: $0) == "true" })
    }

    @Test func theWorkoutStillInProgressExportsToo() throws {
        let rig = try makeRig()
        try logWorkout(rig, sets: [(60, 10, .working)])

        // A second workout, started and left running with an untouched draft row.
        let active = try rig.session.startWorkout(
            at: rig.gym, on: Date(timeIntervalSince1970: 2_000_000))
        try rig.session.addEntry(for: rig.exercise, to: active, machine: rig.machine)

        let rows = try exportRows(rig)
        #expect(rows.count == 2)
        let draft = try #require(rows.last)
        #expect(TestCSV.value("workoutID", in: draft) == active.id.uuidString)
        #expect(TestCSV.value("completed", in: draft) == "false")
        #expect(TestCSV.value("workoutFinishedAt", in: draft) == "")
        #expect(TestCSV.value("reps", in: draft) == "")

        let snapshot = try rig.collector.snapshot(from: rig.context)
        #expect(snapshot.counts.sets == 2)
        #expect(snapshot.counts.completedSets == 1)
    }

    /// An entry the user has assigned to a machine but not yet logged a set on
    /// has **no** D23 snapshot (capture happens at first completion, D19), and
    /// `chooseEquipment` writes to the live relationship. Reading snapshot
    /// fields there exported "no gym, no machine" for an entry the user had
    /// just set up (codex-review, finding 1).
    @Test func aDraftEntryExportsTheEquipmentTheUserJustChose() throws {
        let rig = try makeRig()
        let workout = try rig.session.startWorkout(
            at: rig.gym, on: Date(timeIntervalSince1970: 1_000_000))
        let entry = try rig.session.addEntry(for: rig.exercise, to: workout)
        _ = try rig.session.chooseEquipment(
            for: entry, machine: rig.machine, freeWeightTag: nil)
        #expect(entry.snapshotCapturedAt == nil, "precondition: still a draft")

        let row = try #require(try exportRows(rig).first)
        #expect(TestCSV.value("machineID", in: row) == rig.machine.id.uuidString)
        #expect(TestCSV.value("machineLabel", in: row) == "Chest Press #2")
        #expect(TestCSV.value("modelID", in: row) == rig.model.id.uuidString)
        #expect(TestCSV.value("modelDisplayName", in: row) == rig.model.displayName)
        #expect(TestCSV.value("manufacturer", in: row) == rig.model.manufacturer)
        #expect(TestCSV.value("gymID", in: row) == rig.gym.id.uuidString)
        #expect(TestCSV.value("gymName", in: row) == "Gold's Gym, Gangnam")
        #expect(TestCSV.value("exerciseName", in: row) == rig.exercise.name)

        // And a machineless draft reports its free-weight tag, not a stale nil.
        let barbellEntry = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .barbell)
        let barbellRow = try #require(try exportRows(rig).last)
        #expect(barbellRow != row)
        #expect(TestCSV.value("entryID", in: barbellRow) == barbellEntry.id.uuidString)
        #expect(TestCSV.value("equipmentTag", in: barbellRow) == "barbell")
        #expect(TestCSV.value("machineID", in: barbellRow) == "")
    }

    /// D27 lets a user attach an invented exercise to a *seeded* model. That
    /// link is user data, so the model has to survive D28's filter even after
    /// the only machine naming it has been corrected away (codex-review,
    /// finding 2).
    @Test func aSeededModelCarryingAUserLinkIsNeverFilteredOut() throws {
        let rig = try makeRig()
        let invented = Exercise(name: "Corner Machine Row", loadType: .weighted)
        rig.context.insert(invented)
        rig.model.exerciseIDs.append(invented.id)

        // The only machine that named this model is corrected to another one,
        // and nothing was ever logged on it.
        let otherModel = try #require(
            try rig.context.fetch(FetchDescriptor<EquipmentModel>())
                .first { $0.id != rig.model.id && $0.isSeeded })
        rig.machine.model = otherModel
        try rig.context.save()

        let snapshot = try rig.collector.snapshot(from: rig.context)
        #expect(
            snapshot.equipmentModels.contains { $0.id == rig.model.id },
            "the station the user attached their own movement to must export")
        #expect(snapshot.exercises.contains { $0.id == invented.id })
        let exported = try #require(snapshot.equipmentModels.first { $0.id == rig.model.id })
        #expect(exported.exerciseIDs.contains(invented.id), "and the link itself")
    }

    // MARK: - The export agrees with the app

    /// The check that catches a dropped or duplicated row: volume recomputed
    /// from the CSV must equal the app's own (D21 — completed, non-warmup,
    /// weighted, Σ normalizedKg × reps).
    @Test func csvVolumeReconcilesWithRecordsMath() throws {
        let rig = try makeRig()
        try logWorkout(
            rig,
            sets: [(40, 12, .warmup), (60, 10, .working), (100, 5, .failure), (45, 8, .drop)])

        let fromApp = RecordsMath.totalVolumeKg(
            among: try rig.context.fetch(FetchDescriptor<SetRecord>()).map { set in
                RecordSetInput(
                    loadType: set.entry?.snapshotLoadType ?? .weighted,
                    exerciseID: set.entry?.snapshotExerciseID ?? UUID(),
                    machineID: set.entry?.snapshotMachineID,
                    setType: set.type, reps: set.reps,
                    weightValue: set.weightValue, weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg, completedAt: set.completedAt)
            })

        let fromCSV = try exportRows(rig).reduce(0.0) { total, row in
            guard TestCSV.value("completed", in: row) == "true",
                  TestCSV.value("setType", in: row) != SetType.warmup.rawValue,
                  TestCSV.value("loadType", in: row) == LoadType.weighted.rawValue,
                  let kgText = TestCSV.value("weightKg", in: row), let kg = Double(kgText),
                  let repsText = TestCSV.value("reps", in: row), let reps = Int(repsText)
            else { return total }
            return total + kg * Double(reps)
        }

        #expect(fromApp > 0)
        #expect(abs(fromCSV - fromApp) < 1e-9)
    }

    /// Pound entries keep both numbers: what the user typed, and the kg the
    /// app computes from it (D25/D29).
    @Test func poundSetsExportAsEnteredAndNormalized() throws {
        let rig = try makeRig()
        let workout = try rig.session.startWorkout(
            at: rig.gym, on: Date(timeIntervalSince1970: 1_000_000))
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try rig.session.toggleUnit(of: set)  // gym default is kg → lb
        try rig.session.commitWeight("135", for: set)
        try rig.session.commitReps("8", for: set)
        try rig.session.toggleCompletion(of: set)

        let row = try #require(try exportRows(rig).first)
        #expect(TestCSV.value("unit", in: row) == "lb")
        #expect(TestCSV.value("weight", in: row) == "135.0")
        let weightKgText = try #require(TestCSV.value("weightKg", in: row))
        let kg = try #require(Double(weightKgText))
        #expect(abs(kg - 135 * WeightMath.kilogramsPerPound) < 1e-9)
    }

    /// D36 in the export: the variation a set was performed in is part of what
    /// was performed, so it has to leave the phone with it (D30).
    @Test func theExportCarriesThePresetASetWasLoggedUnder() throws {
        let rig = try makeRig()
        let preset = ExercisePreset(name: "Wide grip", order: 0, exercise: rig.exercise)
        rig.context.insert(preset)
        try rig.context.save()

        let start = Date(timeIntervalSince1970: 1_000_000)
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)
        let entry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        try rig.session.choosePreset(preset, for: entry)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try rig.session.setType(.working, of: set)
        try rig.session.commitWeight("70", for: set)
        try rig.session.commitReps("8", for: set)
        try rig.session.toggleCompletion(of: set, at: start.addingTimeInterval(60))

        let row = try #require(try exportRows(rig).first)
        #expect(TestCSV.value("presetID", in: row) == preset.id.uuidString)
        #expect(TestCSV.value("presetName", in: row) == "Wide grip")

        let snapshot = try rig.collector.snapshot(from: rig.context)
        let exported = try #require(snapshot.workouts.first?.entries.first)
        #expect(exported.presetID == preset.id)
        #expect(exported.presetName == "Wide grip")
        #expect(snapshot.schemaVersion == 9)
        #expect(try ExportJSON.decode(try ExportJSON.data(snapshot)) == snapshot)
    }

    /// D39 in the export: `weight` is the total lifted in bar mode exactly as in
    /// total mode, and the bar rides alongside as provenance. A consumer that
    /// adds the two is counting the bar twice — which is why the total-entry set
    /// in this test has to come back empty rather than zero.
    @Test func theExportCarriesTheBarWithoutMovingTheWeight() throws {
        let rig = try makeRig()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let workout = try rig.session.startWorkout(at: rig.gym, on: start)

        // Bar mode: 45 lb bar, 45 a side.
        let barbell = try rig.session.addEntry(
            for: rig.exercise, to: workout, freeWeightTag: .barbell)
        try rig.session.chooseBar(
            BarPreset(id: "olympic-45lb", name: "Olympic barbell", value: 45, unit: .lb),
            for: barbell)
        let barSet = try #require(WorkoutSession.orderedSets(of: barbell).first)
        try rig.session.commitPerSide("45", for: barSet)
        try rig.session.commitReps("5", for: barSet)
        try rig.session.toggleCompletion(of: barSet, at: start.addingTimeInterval(60))

        // Total entry on the machine, in the same export.
        let machineEntry = try rig.session.addEntry(
            for: rig.exercise, to: workout, machine: rig.machine)
        let plainSet = try #require(WorkoutSession.orderedSets(of: machineEntry).first)
        try rig.session.commitWeight("70", for: plainSet)
        try rig.session.commitReps("8", for: plainSet)
        try rig.session.toggleCompletion(of: plainSet, at: start.addingTimeInterval(120))

        let rows = try exportRows(rig)
        let barRow = try #require(rows.first { TestCSV.value("setID", in: $0) == barSet.id.uuidString })
        #expect(TestCSV.value("weight", in: barRow) == "135.0", "the total, not the plates")
        #expect(TestCSV.value("unit", in: barRow) == "lb")
        #expect(TestCSV.value("barWeight", in: barRow) == "45.0")
        let barKgText = try #require(TestCSV.value("barWeightKg", in: barRow))
        let barKg = try #require(Double(barKgText))
        #expect(abs(barKg - 45 * WeightMath.kilogramsPerPound) < 1e-9)

        let plainRow = try #require(
            rows.first { TestCSV.value("setID", in: $0) == plainSet.id.uuidString })
        #expect(TestCSV.value("barWeight", in: plainRow) == "")
        #expect(TestCSV.value("barWeightKg", in: plainRow) == "")

        let snapshot = try rig.collector.snapshot(from: rig.context)
        let exportedSets = snapshot.workouts.flatMap { $0.entries.flatMap(\.sets) }
        let exportedBarSet = try #require(exportedSets.first { $0.id == barSet.id })
        #expect(exportedBarSet.weight == 135)
        #expect(exportedBarSet.barWeight == 45)
        let exportedPlain = try #require(exportedSets.first { $0.id == plainSet.id })
        #expect(exportedPlain.barWeight == nil, "omitted, not zero")
        #expect(try ExportJSON.decode(try ExportJSON.data(snapshot)) == snapshot)
    }

    // MARK: - Whole-store shape

    @Test func exportCoversTemplatesMemoryOverridesAndPreferences() throws {
        let rig = try makeRig()
        try logWorkout(rig, sets: [(60, 10, .working)])  // writes GymExerciseMemory

        let template = WorkoutTemplate(name: "Push Day")
        let item = TemplateItem(order: 0, targetSets: 3, targetReps: 10, exercise: rig.exercise)
        item.template = template
        let override = ExerciseRestOverride(
            exerciseID: rig.exercise.id, workingRestSeconds: 180)
        rig.context.insert(template)
        rig.context.insert(item)
        rig.context.insert(override)
        let preferences = try AppPreferences.canonical(in: rig.context)
        preferences.unitPreference = .kg
        try rig.context.save()

        let snapshot = try rig.collector.snapshot(from: rig.context)
        #expect(snapshot.templates.map(\.name) == ["Push Day"])
        #expect(snapshot.templates.first?.items.first?.exerciseID == rig.exercise.id)
        #expect(snapshot.templates.first?.items.first?.exerciseName == rig.exercise.name)
        #expect(snapshot.gymExerciseMemory.count == 1)
        #expect(snapshot.gymExerciseMemory.first?.machineID == rig.machine.id)
        #expect(snapshot.exerciseRestOverrides.first?.workingRestSeconds == 180)
        #expect(snapshot.preferences?.unitPreference == .kg)
        #expect(snapshot.gyms.count == 1)
        #expect(snapshot.machines.first?.modelID == rig.model.id)

        // And it survives a JSON round trip whole.
        #expect(try ExportJSON.decode(try ExportJSON.data(snapshot)) == snapshot)
    }

    /// The one thing CSV cannot say: a workout that holds no set at all has no
    /// row in a one-row-per-set file. JSON is the complete backup and keeps it
    /// (codex-review, finding 6 — D30 amended to state this rather than claim
    /// both files carry everything).
    @Test func aWorkoutWithNoSetsLivesInJSONOnly() throws {
        let rig = try makeRig()
        let empty = try rig.session.startWorkout(
            at: rig.gym, on: Date(timeIntervalSince1970: 3_000_000))

        #expect(try exportRows(rig).isEmpty, "no sets, so no CSV rows")
        let snapshot = try rig.collector.snapshot(from: rig.context)
        #expect(snapshot.workouts.map(\.id) == [empty.id])
        #expect(snapshot.counts.workouts == 1)
        #expect(snapshot.counts.sets == 0)
    }

    /// Scale sanity: the export is built synchronously when the user taps, so
    /// it has to stay linear in the size of the history. Bound is deliberately
    /// loose — it is there to catch quadratic behaviour, not to time a phone.
    @Test func exportingALargeHistoryStaysLinear() throws {
        let rig = try makeRig()
        let workoutCount = 60
        let setsPerWorkout = 30
        for index in 0..<workoutCount {
            let start = Date(timeIntervalSince1970: 1_000_000 + Double(index) * 86_400)
            let workout = Workout(startedAt: start, finishedAt: start.addingTimeInterval(3_600))
            workout.gym = rig.gym
            rig.context.insert(workout)
            let entry = ExerciseEntry(
                order: 0, workout: workout, exercise: rig.exercise, machine: rig.machine,
                snapshotCapturedAt: start,
                snapshotExerciseID: rig.exercise.id,
                snapshotMachineID: rig.machine.id,
                snapshotModelID: rig.model.id,
                snapshotGymID: rig.gym.id,
                snapshotLoadType: .weighted,
                snapshotExerciseName: rig.exercise.name,
                snapshotMachineLabel: rig.machine.label,
                snapshotModelName: rig.model.displayName,
                snapshotGymName: rig.gym.name)
            rig.context.insert(entry)
            for order in 0..<setsPerWorkout {
                rig.context.insert(SetRecord(
                    order: order, type: .working, reps: 10, weightValue: 60,
                    weightUnit: .kg, normalizedKg: 60,
                    completedAt: start.addingTimeInterval(Double(order) * 90),
                    entry: entry))
            }
        }
        try rig.context.save()

        let started = Date()
        let snapshot = try rig.collector.snapshot(from: rig.context)
        let csv = ExportCSV.render(snapshot)
        let elapsed = Date().timeIntervalSince(started)

        #expect(snapshot.counts.sets == workoutCount * setsPerWorkout)
        #expect(try TestCSV.strictRows(csv).count == workoutCount * setsPerWorkout + 1)
        #expect(elapsed < 10, "1,800 sets took \(elapsed)s — something is superlinear")
    }

    @Test func anEmptyStoreExportsAnEmptyFileRatherThanFailing() throws {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let snapshot = try ExportCollector(appVersion: "test").snapshot(from: context)
        #expect(snapshot.counts.workouts == 0)
        #expect(snapshot.workouts.isEmpty)
        #expect(snapshot.preferences == nil)
        #expect(TestCSV.rows(ExportCSV.render(snapshot)) == [ExportCSV.header])
    }
}
