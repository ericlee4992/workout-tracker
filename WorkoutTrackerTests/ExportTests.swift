import Foundation
import Testing

@testable import WorkoutTracker

// Milestone 3, ticket 01 — the encoders, tested on value types alone.
// `ExportFidelityTests` covers the collector against a real store.

struct ExportTests {

    // MARK: - Fixture

    /// Fixed ids so expectations can name exact strings.
    private enum ID {
        static let gym = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        static let machine = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        static let model = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!
        static let exercise = UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!
        static let workout = UUID(uuidString: "00000000-0000-0000-0000-0000000000A5")!
        static let entry = UUID(uuidString: "00000000-0000-0000-0000-0000000000A6")!
        static let set1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000A7")!
        static let set2 = UUID(uuidString: "00000000-0000-0000-0000-0000000000A8")!
        static let freeEntry = UUID(uuidString: "00000000-0000-0000-0000-0000000000A9")!
        static let freeSet = UUID(uuidString: "00000000-0000-0000-0000-0000000000B0")!
        static let activeWorkout = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        static let activeEntry = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        static let draftSet = UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!
    }

    /// Pinned to +09:00 (where this app is used) so every timestamp assertion
    /// is exact regardless of the machine running the tests.
    private let dateFormat = ExportDateFormat(
        timeZone: TimeZone(secondsFromGMT: 9 * 3_600)!)

    private func stamp(_ offset: TimeInterval) -> String {
        dateFormat.string(from: Date(timeIntervalSince1970: offset))
    }

    /// A snapshot exercising every optional: machine and free-weight entries,
    /// kg and lb, a warmup, a finished workout and a running one with a draft
    /// set, plus text that has to survive CSV quoting.
    private func makeSnapshot() -> ExportSnapshot {
        let machineEntry = ExportSnapshot.Entry(
            id: ID.entry, order: 0,
            snapshotCapturedAt: stamp(1_000),
            exerciseID: ID.exercise, exerciseName: "Seated Chest Press",
            loadType: .weighted, freeWeightTag: nil,
            machineID: ID.machine, machineLabel: "Chest Press #2",
            modelID: ID.model, modelDisplayName: "Life Fitness Insignia Chest Press",
            modelManufacturer: "Life Fitness",
            gymID: ID.gym, gymName: "Gold's Gym, Gangnam",
            sets: [
                ExportSnapshot.SetRow(
                    id: ID.set1, order: 0, type: .warmup, reps: 12, weight: 40,
                    unit: .kg, weightKg: 40, completedAt: stamp(1_000)),
                ExportSnapshot.SetRow(
                    id: ID.set2, order: 1, type: .working, reps: 8, weight: 135,
                    unit: .lb, weightKg: 135 * WeightMath.kilogramsPerPound,
                    completedAt: stamp(1_200)),
            ])
        let freeEntry = ExportSnapshot.Entry(
            id: ID.freeEntry, order: 1,
            snapshotCapturedAt: stamp(1_400),
            exerciseID: ID.exercise, exerciseName: "Dumbbell Row",
            loadType: .weighted, freeWeightTag: .dumbbell,
            machineID: nil, machineLabel: nil, modelID: nil, modelDisplayName: nil,
            modelManufacturer: nil, gymID: ID.gym, gymName: "Gold's Gym, Gangnam",
            sets: [
                ExportSnapshot.SetRow(
                    id: ID.freeSet, order: 0, type: .drop, reps: 6, weight: 22.5,
                    unit: .kg, weightKg: 22.5, completedAt: stamp(1_400)),
            ])
        let finished = ExportSnapshot.Workout(
            id: ID.workout, startedAt: stamp(900), finishedAt: stamp(1_500),
            notes: "Felt strong; said \"one more\", then did three.",
            sourceTemplateID: nil, sourceTemplateName: "Push Day",
            gymID: ID.gym, gymName: "Gold's Gym, Gangnam",
            entries: [machineEntry, freeEntry])
        // D30: still running, one uncompleted draft set.
        let active = ExportSnapshot.Workout(
            id: ID.activeWorkout, startedAt: stamp(9_000), finishedAt: nil,
            notes: "", sourceTemplateID: nil, sourceTemplateName: nil,
            gymID: nil, gymName: nil,
            entries: [
                ExportSnapshot.Entry(
                    id: ID.activeEntry, order: 0, snapshotCapturedAt: nil,
                    exerciseID: ID.exercise, exerciseName: "Pull-up",
                    loadType: .bodyweight, freeWeightTag: .bodyweight,
                    machineID: nil, machineLabel: nil, modelID: nil, modelDisplayName: nil,
                    modelManufacturer: nil, gymID: nil, gymName: nil,
                    sets: [
                        ExportSnapshot.SetRow(
                            id: ID.draftSet, order: 0, type: .working, reps: nil,
                            weight: nil, unit: .kg, weightKg: nil, completedAt: nil),
                    ]),
            ])

        return ExportSnapshot(
            exportedAt: stamp(10_000),
            appVersion: "1.0 (3)",
            seededCatalogVersion: 4,
            counts: ExportSnapshot.Counts(
                workouts: 2, entries: 3, sets: 4, completedSets: 3,
                gyms: 1, machines: 1, exercises: 1, equipmentModels: 1, templates: 0),
            preferences: ExportSnapshot.Preferences(
                unitPreference: .kg, driftPromptSuppressed: false,
                globalWorkingRestSeconds: 120, globalWarmupRestSeconds: 60,
                seededCatalogVersion: 4, notificationPermissionRequested: true,
                selectedGymID: ID.gym, updatedAt: stamp(2_000)),
            gyms: [
                ExportSnapshot.Gym(
                    id: ID.gym, name: "Gold's Gym, Gangnam", city: "Seoul",
                    defaultUnit: .kg, notes: "", archived: false),
            ],
            machines: [
                ExportSnapshot.Machine(
                    id: ID.machine, label: "Chest Press #2", gymID: ID.gym,
                    modelID: ID.model, defaultUnit: nil, archived: false),
            ],
            exercises: [
                ExportSnapshot.Exercise(
                    id: ID.exercise, name: "Seated Chest Press", loadType: .weighted,
                    equipmentTypeTags: [.machine], muscleGroup: "Chest", isSeeded: true),
            ],
            equipmentModels: [
                ExportSnapshot.EquipmentModel(
                    id: ID.model, manufacturer: "Life Fitness",
                    modelName: "Insignia Chest Press", exerciseIDs: [ID.exercise],
                    equipmentType: .selectorized, isSeeded: true),
            ],
            templates: [],
            workouts: [finished, active],
            gymExerciseMemory: [],
            exerciseRestOverrides: [])
    }

    private func csvRows(_ snapshot: ExportSnapshot) -> [[String]] {
        TestCSV.rows(ExportCSV.render(snapshot))
    }

    private func column(_ name: String, of row: [String]) throws -> String {
        try #require(TestCSV.value(name, in: row), "unknown column \(name)")
    }

    // MARK: - JSON

    @Test func jsonRoundTripsExactly() throws {
        let snapshot = makeSnapshot()
        let decoded = try ExportJSON.decode(try ExportJSON.data(snapshot))
        #expect(decoded == snapshot)
    }

    @Test func jsonCarriesVersionAndOmitsNilRatherThanNull() throws {
        let text = try #require(
            String(data: try ExportJSON.data(makeSnapshot()), encoding: .utf8))
        #expect(text.contains("\"schemaVersion\" : 9"), "milestone 9 moved the shape to v6 (name), v7 (D51 provenance), v8 (heart-rate series); the finish graph to v9 (series low/high)")
        #expect(!text.contains("null"), "nil optionals must be omitted, not encoded as null")
        // Sorted keys make the file diffable: `appVersion` precedes `counts`.
        let appVersion = try #require(text.range(of: "\"appVersion\""))
        let counts = try #require(text.range(of: "\"counts\""))
        #expect(appVersion.lowerBound < counts.lowerBound)
    }

    /// D30 — the running workout and its uncompleted set are in the file.
    @Test func jsonKeepsTheActiveWorkoutAndItsDraftSet() throws {
        let decoded = try ExportJSON.decode(try ExportJSON.data(makeSnapshot()))
        let active = try #require(decoded.workouts.first { $0.id == ID.activeWorkout })
        #expect(active.finishedAt == nil)
        let draft = try #require(active.entries.first?.sets.first)
        #expect(draft.completedAt == nil)
        #expect(draft.reps == nil)
        #expect(draft.weight == nil)
    }

    /// D29 — weights survive as entered *and* normalized, at full precision.
    @Test func jsonKeepsAsEnteredAndNormalizedWeights() throws {
        let decoded = try ExportJSON.decode(try ExportJSON.data(makeSnapshot()))
        let entry = try #require(decoded.workouts.first?.entries.first)
        let pounds = try #require(entry.sets.first { $0.unit == .lb })
        #expect(pounds.weight == 135)
        #expect(pounds.weightKg == 135 * WeightMath.kilogramsPerPound)
    }

    /// A nil *object property* is omitted; a nil *array position* is `null`,
    /// because dropping it would shift every later set target by one
    /// (codex-review, finding 9). Both survive the round trip.
    @Test func jsonKeepsNilArrayPositionsAsNull() throws {
        var snapshot = makeSnapshot()
        snapshot.templates = [
            ExportSnapshot.Template(
                id: ID.gym, name: "Push Day",
                items: [
                    ExportSnapshot.TemplateItem(
                        id: ID.machine, order: 0, exerciseID: ID.exercise,
                        exerciseName: "Seated Chest Press", targetSets: 3,
                        targetReps: nil, targetRepsBySet: [8, nil, 10]),
                ]),
        ]
        let data = try ExportJSON.data(snapshot)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("null"), "a skipped set target keeps its position")
        #expect(!text.contains("\"targetReps\" :"), "a nil property is omitted entirely")
        #expect(try ExportJSON.decode(data) == snapshot)
    }

    /// D31 with fractional seconds: `CanonicalRow` resolves duplicate rows by
    /// `updatedAt` before falling back to the id, so two updates inside one
    /// second must not export as the same instant (codex-review, finding 4).
    @Test func timestampsKeepSubSecondPrecision() throws {
        let base = Date(timeIntervalSince1970: 1_000)
        let first = dateFormat.string(from: base.addingTimeInterval(0.100))
        let second = dateFormat.string(from: base.addingTimeInterval(0.900))
        #expect(first == "1970-01-01T09:16:40.100+09:00")
        #expect(first != second)
        #expect(first < second, "string order must match instant order")
    }

    // MARK: - CSV shape

    @Test func csvHeaderIsTheDocumentedColumnsInOrder() throws {
        let rows = csvRows(makeSnapshot())
        #expect(rows.first == ExportCSV.header)
        #expect(ExportCSV.header.count == 37)
        #expect(ExportCSV.header.first == "workoutID")
        // Presets (D36) appended two columns and the bar (D39) two more; the
        // first 27 are unchanged, so a reader of a version-1 export still reads
        // them correctly.
        #expect(Array(ExportCSV.header[27...28]) == ["presetID", "presetName"])
        #expect(Array(ExportCSV.header[29...30]) == ["barWeight", "barWeightKg"])
        #expect(
            Array(ExportCSV.header[31...33])
                == ["workoutAvgHeartRate", "workoutMaxHeartRate", "workoutActiveCalories"])
        // v5 (D48). Appended, never inserted — the first 34 columns are
        // untouched, so a reader of any earlier export still reads them.
        #expect(ExportCSV.header[34] == "supersetGroupID")
        // v6 (milestone 9): the typed name is appended; column 4 still means
        // the template, so a v1–v5 reader of provenance is not lied to.
        #expect(ExportCSV.header[35] == "workoutTypedName")
        #expect(ExportCSV.header[3] == "workoutName")
        // v7 (D51): the reclassification's provenance rides on the rows.
        #expect(ExportCSV.header.last == "reclassifiedFrom")
        #expect(ExportCSV.header[26] == "completedAt")
    }

    @Test func csvHasOneRowPerSetInSnapshotOrder() throws {
        let rows = csvRows(makeSnapshot())
        let ids = try rows.dropFirst().map { try column("setID", of: $0) }
        #expect(ids == [
            ID.set1.uuidString, ID.set2.uuidString, ID.freeSet.uuidString,
            ID.draftSet.uuidString,
        ])
    }

    @Test func csvUsesCRLFAndAUTF8BOM() throws {
        let snapshot = makeSnapshot()
        let text = ExportCSV.render(snapshot)
        #expect(text.hasSuffix(ExportCSV.lineTerminator))
        // Byte-level, because Swift reads CRLF as one Character: every LF byte
        // must be preceded by a CR byte, and there must be one pair per row.
        let bytes = Array(text.utf8)
        let lineFeeds = bytes.enumerated().filter { $0.element == 0x0A }
        #expect(lineFeeds.count == 5, "header + four set rows")
        #expect(lineFeeds.allSatisfy { $0.offset > 0 && bytes[$0.offset - 1] == 0x0D })
        let data = ExportCSV.data(snapshot)
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
    }

    @Test func csvIsDeterministic() throws {
        #expect(ExportCSV.render(makeSnapshot()) == ExportCSV.render(makeSnapshot()))
    }

    @Test func emptySnapshotExportsAHeaderOnlyFile() throws {
        let empty = ExportSnapshot(
            exportedAt: stamp(0), appVersion: "", seededCatalogVersion: 0,
            counts: ExportSnapshot.Counts(), preferences: nil)
        #expect(csvRows(empty) == [ExportCSV.header])
        #expect(try ExportJSON.decode(try ExportJSON.data(empty)) == empty)
    }

    // MARK: - CSV content

    @Test func csvRowCarriesFullEquipmentContext() throws {
        let row = csvRows(makeSnapshot())[2]  // the 135 lb working set
        #expect(try column("workoutID", of: row) == ID.workout.uuidString)
        #expect(try column("workoutName", of: row) == "Push Day")
        #expect(try column("gymName", of: row) == "Gold's Gym, Gangnam")
        #expect(try column("exerciseName", of: row) == "Seated Chest Press")
        #expect(try column("loadType", of: row) == "weighted")
        #expect(try column("machineLabel", of: row) == "Chest Press #2")
        #expect(try column("manufacturer", of: row) == "Life Fitness")
        #expect(try column("modelDisplayName", of: row) == "Life Fitness Insignia Chest Press")
        #expect(try column("modelID", of: row) == ID.model.uuidString)
        #expect(try column("setType", of: row) == "working")
        #expect(try column("reps", of: row) == "8")
        #expect(try column("completed", of: row) == "true")
    }

    /// D29 — three columns, no conversion, no ≈ anywhere in the file.
    @Test func csvKeepsAsEnteredAndNormalizedWeights() throws {
        let text = ExportCSV.render(makeSnapshot())
        #expect(!text.contains("≈"))

        let pounds = csvRows(makeSnapshot())[2]
        #expect(try column("weight", of: pounds) == "135.0")
        #expect(try column("unit", of: pounds) == "lb")
        let kg = try #require(Double(try column("weightKg", of: pounds)))
        #expect(abs(kg - 135 * WeightMath.kilogramsPerPound) < 1e-9)

        // A fractional kg entry keeps its `.` separator whatever the locale of
        // the machine running this — `storageNumber` is not locale-formatted.
        let dumbbell = csvRows(makeSnapshot())[3]
        #expect(try column("weight", of: dumbbell) == "22.5")
        #expect(try column("weightKg", of: dumbbell) == "22.5")
    }

    /// D30 — the draft set is a row, flagged, with empty rather than invented
    /// values; the running workout has an empty `workoutFinishedAt`.
    @Test func csvKeepsDraftSetsFlaggedRatherThanDroppingThem() throws {
        let row = csvRows(makeSnapshot())[4]
        #expect(try column("setID", of: row) == ID.draftSet.uuidString)
        #expect(try column("completed", of: row) == "false")
        #expect(try column("completedAt", of: row) == "")
        #expect(try column("reps", of: row) == "")
        #expect(try column("weight", of: row) == "")
        #expect(try column("weightKg", of: row) == "")
        #expect(try column("workoutFinishedAt", of: row) == "")
        // A machineless entry states its free-weight tag and nothing else.
        #expect(try column("equipmentTag", of: row) == "bodyweight")
        #expect(try column("machineID", of: row) == "")
        #expect(try column("gymName", of: row) == "")
    }

    @Test func csvTimestampsCarryTheirUTCOffset() throws {
        let row = csvRows(makeSnapshot())[1]
        let started = try column("workoutStartedAt", of: row)
        #expect(started == "1970-01-01T09:15:00.000+09:00")
        #expect(try column("completedAt", of: row) == "1970-01-01T09:16:40.000+09:00")
    }

    /// The export uses storage serialization, not display formatting: under a
    /// comma-decimal locale the *display* helper would write "22,5" — which in
    /// a comma-separated file is not a rounding nuisance but a shifted column.
    @Test func csvNumbersAreStorageSerializedNotLocaleFormatted() throws {
        let commaLocale = Locale(identifier: "de_DE")
        #expect(WeightMath.displayNumber(22.5, locale: commaLocale) == "22,5")

        let text = ExportCSV.render(makeSnapshot())
        #expect(!text.contains("22,5"))
        #expect(try column("weight", of: csvRows(makeSnapshot())[3]) == "22.5")
    }

    // MARK: - CSV escaping (D32)

    @Test func csvQuotesOnlyWhatMustBeQuoted() {
        #expect(ExportCSV.escaped("Push Day") == "Push Day")
        #expect(ExportCSV.escaped("Gold's Gym, Gangnam") == "\"Gold's Gym, Gangnam\"")
        #expect(ExportCSV.escaped("said \"go\"") == "\"said \"\"go\"\"\"")
        #expect(ExportCSV.escaped("two\nlines") == "\"two\nlines\"")
        #expect(ExportCSV.escaped("") == "")
    }

    /// Swift reads CRLF as one Character, so a Windows newline pasted into a
    /// note slipped past a Character-wise check and left the field unquoted —
    /// which splits the record in any strict reader (codex-review, finding 3).
    @Test func csvQuotesEveryFlavourOfEmbeddedNewline() throws {
        #expect(ExportCSV.escaped("two\r\nlines") == "\"two\r\nlines\"")
        #expect(ExportCSV.escaped("carriage\rreturn") == "\"carriage\rreturn\"")

        for note in ["two\r\nlines", "carriage\rreturn", "line\nfeed"] {
            var snapshot = makeSnapshot()
            snapshot.workouts[0].notes = note
            let rows = try TestCSV.strictRows(ExportCSV.render(snapshot))
            #expect(rows.count == 5, "header + four sets, whatever the note contains")
            #expect(TestCSV.value("workoutNotes", in: rows[1]) == note)
        }
    }

    /// The whole file parses under a reader that refuses anything the dialect
    /// does not allow — bare CR/LF terminators, stray text after a closing
    /// quote, an unclosed quote, or a record with the wrong field count.
    @Test func csvParsesUnderAStrictReader() throws {
        let rows = try TestCSV.strictRows(ExportCSV.render(makeSnapshot()))
        #expect(rows.count == 5)
        #expect(rows.allSatisfy { $0.count == ExportCSV.header.count })
        #expect(rows[0] == ExportCSV.header)

        // And the strict reader is actually strict.
        #expect(throws: TestCSV.ParseError.self) {
            try TestCSV.strictRows("a,b\nc,d\n")
        }
        #expect(throws: TestCSV.ParseError.self) {
            try TestCSV.strictRows("\"unclosed\r\n")
        }
    }

    @Test func csvNotesWithQuotesAndCommasSurviveARoundTrip() throws {
        let row = csvRows(makeSnapshot())[1]
        #expect(try column("workoutNotes", of: row)
            == "Felt strong; said \"one more\", then did three.")
        #expect(try column("gymName", of: row) == "Gold's Gym, Gangnam")
    }

    /// D32 — user text goes in verbatim. A note that begins with `=` is the
    /// user's note, not ours to rewrite.
    @Test func csvDoesNotRewriteFormulaLookingText() throws {
        var snapshot = makeSnapshot()
        snapshot.workouts[0].notes = "=2+2 felt easy"
        let row = csvRows(snapshot)[1]
        #expect(try column("workoutNotes", of: row) == "=2+2 felt easy")
    }

    // MARK: - Filenames

    @Test func exportFilenamesAreSortableAndFormatted() {
        let date = Date(timeIntervalSince1970: 1_786_000_000)
        let csv = ExportFileWriter.filename(format: .csv, at: date, dateFormat: dateFormat)
        let json = ExportFileWriter.filename(format: .json, at: date, dateFormat: dateFormat)
        #expect(csv == "workout-tracker-2026-08-06-1606.csv")
        #expect(json == "workout-tracker-2026-08-06-1606.json")
    }

    /// Each export is staged in its own directory, swept on the *next* export
    /// and deletable the moment the share sheet is done with it — so nothing is
    /// pulled out from under an activity still reading it, and a failed write
    /// cannot destroy the previous good file (codex-review, finding 10).
    @Test func eachExportIsStagedSeparatelyAndSweptOnTheNextOne() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "export-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try ExportFileWriter.write(
            Data("a".utf8), format: .csv, at: Date(timeIntervalSince1970: 0),
            dateFormat: dateFormat, in: directory)
        #expect(try Data(contentsOf: first) == Data("a".utf8))
        #expect(first.deletingLastPathComponent() != directory, "staged in its own subdirectory")

        let second = try ExportFileWriter.write(
            Data("b".utf8), format: .json, at: Date(timeIntervalSince1970: 86_400),
            dateFormat: dateFormat, in: directory)
        #expect(!FileManager.default.fileExists(atPath: first.path), "swept by the next export")
        #expect(try Data(contentsOf: second) == Data("b".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)

        ExportFileWriter.discard(at: second)
        #expect(!FileManager.default.fileExists(atPath: second.path))
    }
}
