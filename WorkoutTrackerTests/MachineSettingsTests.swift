import CoreData
import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Machine settings 01 (D91): "My settings" — one note per gym machine × exercise, current (not history), owned by the
/// machine, with a blank canonical row meaning no note; the first-use check; and the JSON backup (export v15).
@MainActor
struct MachineSettingsTests {
    private struct SaveFailed: Error {}

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    /// A gym with a cable station and a second station of the same model, and two exercises.
    private func world() throws -> (ModelContext, gym: Gym, station: MachineInstance, other: MachineInstance,
                                    pushdown: Exercise, row: Exercise) {
        let context = try makeContext()
        let gym = Gym(name: "Iron Temple")
        let model = EquipmentModel(manufacturer: "Life Fitness", modelName: "Dual Adjustable Pulley", exerciseIDs: [])
        let pushdown = Exercise(name: "Triceps Pushdown")
        let row = Exercise(name: "Low Row")
        model.exerciseIDs = [pushdown.id, row.id]
        let station = MachineInstance(label: "Cable Station", gym: gym, model: model)
        let other = MachineInstance(label: "Cable Station 2", gym: gym, model: model)
        for item in [gym, model, pushdown, row, station, other] as [any PersistentModel] { context.insert(item) }
        try context.save()
        return (context, gym, station, other, pushdown, row)
    }

    private func notes(_ context: ModelContext) throws -> [MachineSettingsNote] {
        try context.fetch(FetchDescriptor<MachineSettingsNote>())
    }

    // MARK: The key: machine × exercise

    @Test func aStationKeepsOneNotePerExerciseAndNeverSharesIt() throws {
        let (context, _, station, other, pushdown, row) = try world()
        let settings = MachineSettings(context: context)
        try settings.save("  Rope · pulley at the top  ", on: station, exerciseID: pushdown.id)
        try settings.save("Seat 3 · chest pad 2", on: station, exerciseID: row.id)

        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == "Rope · pulley at the top", "trimmed")
        #expect(MachineSettings.note(on: station, exerciseID: row.id) == "Seat 3 · chest pad 2")
        // The same model's other machine, and the same exercise on it, have nothing.
        #expect(MachineSettings.note(on: other, exerciseID: pushdown.id) == nil)
        #expect(MachineSettings.note(on: nil, exerciseID: pushdown.id) == nil)
        #expect(MachineSettings.note(on: station, exerciseID: nil) == nil)
        #expect(try notes(context).count == 2)
    }

    @Test func savingAgainUpdatesTheSameRow() throws {
        let (context, _, station, _, pushdown, _) = try world()
        let settings = MachineSettings(context: context)
        try settings.save("Rope", on: station, exerciseID: pushdown.id, at: Date(timeIntervalSince1970: 100))
        try settings.save("Rope · top notch", on: station, exerciseID: pushdown.id, at: Date(timeIntervalSince1970: 200))
        let rows = try notes(context)
        #expect(rows.count == 1)
        #expect(rows.first?.text == "Rope · top notch" && rows.first?.updatedAt == Date(timeIntervalSince1970: 200))
    }

    @Test func blankClearsTheNoteAndAnUnchangedSaveWritesNothing() throws {
        let (context, _, station, _, pushdown, row) = try world()
        let settings = MachineSettings(context: context)
        // Blank with nothing stored adds no row.
        try settings.save("   ", on: station, exerciseID: row.id)
        #expect(try notes(context).isEmpty)

        try settings.save("Rope", on: station, exerciseID: pushdown.id, at: Date(timeIntervalSince1970: 100))
        var saves = 0
        try settings.save("Rope", on: station, exerciseID: pushdown.id, at: Date(timeIntervalSince1970: 300),
                          save: { saves += 1; try $0.save() })
        #expect(saves == 0, "the same text is not a change")
        #expect(try notes(context).first?.updatedAt == Date(timeIntervalSince1970: 100))

        try settings.save("\n ", on: station, exerciseID: pushdown.id)
        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == nil)
        #expect(try notes(context).first?.text == "", "cleared, kept as a blank row")
    }

    /// CloudKit can leave two rows for one key: the latest (then the id) counts, an edit updates that one, and a
    /// cleared note never lets an older duplicate resurface.
    @Test func duplicatesResolveToTheCanonicalRow() throws {
        let (context, _, station, _, pushdown, _) = try world()
        let older = MachineSettingsNote(exerciseID: pushdown.id, text: "Old", updatedAt: Date(timeIntervalSince1970: 100))
        let newer = MachineSettingsNote(exerciseID: pushdown.id, text: "New", updatedAt: Date(timeIntervalSince1970: 200))
        context.insert(older)
        context.insert(newer)
        older.machine = station
        newer.machine = station
        try context.save()
        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == "New")

        try MachineSettings(context: context).save("", on: station, exerciseID: pushdown.id,
                                                   at: Date(timeIntervalSince1970: 300))
        #expect(newer.text == "" && older.text == "Old")
        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == nil, "the older duplicate stays hidden")
    }

    /// codex-review-01 #1: the clock moved back. Clearing or editing the canonical row at an earlier time keeps it
    /// canonical, so the older duplicate never resurfaces and the edit is never lost.
    @Test func anEditAtAnEarlierTimeKeepsTheRowCanonical() throws {
        for clearing in [true, false] {
            let (context, _, station, _, pushdown, _) = try world()
            let older = MachineSettingsNote(exerciseID: pushdown.id, text: "Old", updatedAt: Date(timeIntervalSince1970: 200))
            let newer = MachineSettingsNote(exerciseID: pushdown.id, text: "New", updatedAt: Date(timeIntervalSince1970: 300))
            context.insert(older)
            context.insert(newer)
            older.machine = station
            newer.machine = station
            try context.save()

            try MachineSettings(context: context).save(clearing ? "" : "Edited", on: station, exerciseID: pushdown.id,
                                                       at: Date(timeIntervalSince1970: 100))
            #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == (clearing ? nil : "Edited"))
            #expect(newer.updatedAt == Date(timeIntervalSince1970: 300), "not moved back")
            #expect(older.text == "Old")
        }
    }

    /// Two rows with one date: the id breaks the tie, and an edit at an earlier time keeps the winner.
    @Test func anEqualDateTieStaysWithTheEditedRow() throws {
        let (context, _, station, _, pushdown, _) = try world()
        let date = Date(timeIntervalSince1970: 300)
        let low = MachineSettingsNote(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
                                      exerciseID: pushdown.id, text: "Low", updatedAt: date)
        let high = MachineSettingsNote(id: UUID(uuidString: "FFFFFFFF-0000-4000-8000-000000000001")!,
                                       exerciseID: pushdown.id, text: "High", updatedAt: date)
        context.insert(low)
        context.insert(high)
        low.machine = station
        high.machine = station
        try context.save()
        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == "High")

        try MachineSettings(context: context).save("", on: station, exerciseID: pushdown.id,
                                                   at: Date(timeIntervalSince1970: 100))
        #expect(high.text == "" && low.text == "Low")
        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == nil, "the tie still goes to the cleared row")
    }

    // MARK: A failed save leaves nothing pending

    @Test func aFailedEditPutsTheNoteBack() throws {
        let (context, _, station, _, pushdown, _) = try world()
        let settings = MachineSettings(context: context)
        try settings.save("Rope", on: station, exerciseID: pushdown.id, at: Date(timeIntervalSince1970: 100))
        #expect(throws: SaveFailed.self) {
            try settings.save("Bar", on: station, exerciseID: pushdown.id, save: { _ in throw SaveFailed() })
        }
        let row = try #require(try notes(context).first)
        #expect(row.text == "Rope" && row.updatedAt == Date(timeIntervalSince1970: 100))
        // A later save (any screen's) writes the note as it was, not the failed edit.
        try context.save()
        let stored = try ModelContext(context.container).fetch(FetchDescriptor<MachineSettingsNote>())
        #expect(stored.map(\.text) == ["Rope"], "nothing of the edit is pending")
    }

    @Test func aFailedFirstNoteLeavesNoRow() throws {
        let (context, _, station, _, pushdown, _) = try world()
        #expect(throws: SaveFailed.self) {
            try MachineSettings(context: context).save("Rope", on: station, exerciseID: pushdown.id,
                                                       save: { _ in throw SaveFailed() })
        }
        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == nil)
        try context.save()
        #expect(try notes(context).isEmpty)
    }

    // MARK: Owned by the machine

    @Test func deletingTheMachineDeletesItsNotesOnly() throws {
        let (context, _, station, other, pushdown, _) = try world()
        let settings = MachineSettings(context: context)
        try settings.save("Rope", on: station, exerciseID: pushdown.id)
        try settings.save("Bar", on: other, exerciseID: pushdown.id)
        context.delete(station)
        try context.save()
        #expect(try notes(context).map(\.text) == ["Bar"])
    }

    @Test func archivingTheMachineKeepsItsNotes() throws {
        let (context, _, station, _, pushdown, _) = try world()
        try MachineSettings(context: context).save("Rope", on: station, exerciseID: pushdown.id)
        try EquipmentLifecycle(context: context).archive(station)
        #expect(MachineSettings.note(on: station, exerciseID: pushdown.id) == "Rope")
    }

    // MARK: First use (the "Add My Settings" chip)

    @Test func historyCountsOnlyFinishedWorkoutsOnThisMachineForThisExercise() throws {
        let (context, gym, station, other, pushdown, row) = try world()
        let settings = MachineSettings(context: context)
        let session = WorkoutSession(context: context)
        #expect(try !settings.hasFinishedHistory(machineID: station.id, exerciseID: pushdown.id))

        // The first workout on it: logged, still running — still first use.
        let workout = try session.startWorkout(at: gym)
        let entry = try session.addEntry(for: pushdown, to: workout, machine: station)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.commitWeight("50", for: set)
        try session.commitReps("10", for: set)
        try session.toggleCompletion(of: set)
        #expect(entry.snapshotMachineID == station.id)
        #expect(try !settings.hasFinishedHistory(machineID: station.id, exerciseID: pushdown.id))

        try session.finish(workout)
        #expect(try settings.hasFinishedHistory(machineID: station.id, exerciseID: pushdown.id))
        // Another exercise on the station, and the same exercise on another machine, are still first use.
        #expect(try !settings.hasFinishedHistory(machineID: station.id, exerciseID: row.id))
        #expect(try !settings.hasFinishedHistory(machineID: other.id, exerciseID: pushdown.id))
    }

    // MARK: Current, not history

    @Test func aNoteIsNotPartOfTheSnapshot() throws {
        let (context, gym, station, _, pushdown, _) = try world()
        try MachineSettings(context: context).save("Rope", on: station, exerciseID: pushdown.id)
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: gym)
        let entry = try session.addEntry(for: pushdown, to: workout, machine: station)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.commitWeight("50", for: set)
        try session.commitReps("10", for: set)
        try session.toggleCompletion(of: set)
        try session.finish(workout)
        // Editing the note afterwards changes nothing logged; the snapshot holds only its D23 fields.
        try MachineSettings(context: context).save("Bar", on: station, exerciseID: pushdown.id)
        let exported = try ExportCollector().snapshot(from: context)
        let logged = try #require(exported.workouts.first?.entries.first)
        #expect(!String(describing: logged).contains("Rope") && !String(describing: logged).contains("Bar"))
    }

    // MARK: The JSON backup (v15)

    @Test func theBackupCarriesEveryNoteAndItsExercise() throws {
        let (context, _, station, _, pushdown, row) = try world()
        let settings = MachineSettings(context: context)
        try settings.save("Rope", on: station, exerciseID: pushdown.id, at: Date(timeIntervalSince1970: 100))
        try settings.save("Seat 3", on: station, exerciseID: row.id, at: Date(timeIntervalSince1970: 200))
        try settings.save("", on: station, exerciseID: row.id, at: Date(timeIntervalSince1970: 300))
        // Seeded exercises export only when referenced (D28): the note is the only reference here.
        pushdown.isSeeded = true
        try context.save()

        let snapshot = try ExportCollector().snapshot(from: context)
        #expect(snapshot.schemaVersion == 15)
        #expect(snapshot.counts.machineSettings == 2)
        let rows = try #require(snapshot.machineSettings)
        #expect(rows.map(\.text) == ["Rope", ""], "every row, as stored, oldest first")
        #expect(rows.allSatisfy { $0.machineID == station.id })
        #expect(rows.map(\.exerciseID) == [pushdown.id, row.id])
        #expect(snapshot.exercises.contains { $0.id == pushdown.id }, "the note's exercise exports with it")

        let decoded = try JSONDecoder().decode(ExportSnapshot.self, from: try JSONEncoder().encode(snapshot))
        #expect(decoded == snapshot)
    }

    @Test func aVersion14BackupStillDecodes() throws {
        let context = try makeContext()
        var snapshot = try ExportCollector().snapshot(from: context)
        snapshot.machineSettings = nil
        snapshot.counts.machineSettings = nil
        snapshot.schemaVersion = 14
        let decoded = try JSONDecoder().decode(ExportSnapshot.self, from: try JSONEncoder().encode(snapshot))
        #expect(decoded.machineSettings == nil && decoded.schemaVersion == 14)
    }
}

/// Machine settings 01 (D91): build 16's store — the format on testers' phones — opens with the new model, the safety
/// copy runs first, every row survives, and a note can be saved on an existing machine.
struct MachineSettingsMigrationTests {
    private final class BundleMarker {}

    private func fixtureURL() throws -> URL {
        try #require(Bundle(for: BundleMarker.self).url(forResource: "Build16", withExtension: "store"),
                     "the build 16 fixture must ship with the test bundle")
    }

    @Test func theFixtureIsInBuildSixteensFormat() throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: try fixtureURL())
        let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
        let hex = { (data: Data) in data.map { String(format: "%02x", $0) }.joined() }
        let lines = hashes.sorted { $0.key < $1.key }.map { "\($0.key):\(hex($0.value))" }
        #expect(hex(Data(SHA256.hash(data: Data(lines.joined(separator: "\n").utf8)))) == StoreFormatGuardTests.build16Fingerprint)
    }

    @Test func theSafetyCopySeesTheChangeBeforeTheOpen() throws {
        let model = NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes)
        #expect(SafetyCopies.storeNeedsCopy(at: try fixtureURL(), model: model))
    }

    @Test @MainActor func everyRowSurvivesAndANoteCanBeSaved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "build-16-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        try FileManager.default.copyItem(at: try fixtureURL(), to: url)
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        // The fixture: the design sample with its Gyms and History variants, written by 0.2.0 (16)'s format.
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 7)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == 58)
        #expect(try context.fetchCount(FetchDescriptor<MachineInstance>()) == 12)
        #expect(try context.fetchCount(FetchDescriptor<MachineSettingsNote>()) == 0)

        let station = try #require(try context.fetch(FetchDescriptor<MachineInstance>()).first { $0.label == "Cable Station" })
        let pushdown = try #require(try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Triceps Pushdown" })
        #expect(try MachineSettings(context: context).hasFinishedHistory(machineID: station.id, exerciseID: pushdown.id))
        try MachineSettings(context: context).save("Rope · top", on: station, exerciseID: pushdown.id)
        let reread = ModelContext(container)
        let note = try #require(try reread.fetch(FetchDescriptor<MachineSettingsNote>()).first)
        #expect(note.text == "Rope · top" && note.machine?.id == station.id && note.exerciseID == pushdown.id)
    }
}
