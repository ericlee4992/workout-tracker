import Foundation

// Milestone 3, ticket 01 — the spreadsheet export: one row per logged set,
// fully denormalized. Pure `ExportSnapshot → String`; no UI, no SwiftData.
//
// This is the format Strong's export would be if it were honest: it carries the
// four things theirs cannot express (SPEC line 88) — an explicit unit per set,
// stable UUIDs, set types, and the full equipment context the set was performed
// in. Context columns come from the entry's D23 snapshot once it has one, so a
// gym renamed today does not rewrite last year's rows; a draft entry, which has
// no snapshot yet, reports its live equipment (see `ExportCollector.context`).
//
// Scope, stated plainly (D30 as amended by codex-review finding 6): this file
// is a complete ledger of *sets*. A workout or entry that holds no set at all
// has no row here — "one row per set" has nowhere to put it. The JSON export is
// the complete backup and does carry those objects.

enum ExportCSV {

    /// The 29 columns, in order. `../spec.md` documents each one's source; the
    /// order is part of the format — appending is safe, reordering is not.
    static let header = [
        "workoutID", "workoutStartedAt", "workoutFinishedAt", "workoutName", "workoutNotes",
        "gymID", "gymName",
        "entryID", "entryOrder", "exerciseID", "exerciseName", "loadType", "equipmentTag",
        "machineID", "machineLabel", "modelID", "manufacturer", "modelDisplayName",
        "setID", "setOrder", "setType", "reps", "weight", "unit", "weightKg",
        "completed", "completedAt",
        // Appended, never inserted: a consumer reading the first 27 columns of
        // a v1 export still reads them correctly here (D30).
        "presetID", "presetName",
    ]

    /// RFC 4180 line terminator. Excel on Windows still wants CRLF; every
    /// other reader tolerates it.
    static let lineTerminator = "\r\n"

    /// The file as text, without the BOM. Rows are ordered exactly as the
    /// snapshot is (workout `startedAt` → id → entry `order` → set `order`),
    /// so re-exporting unchanged data reproduces the same bytes.
    static func render(_ snapshot: ExportSnapshot) -> String {
        var lines = [row(header)]
        for workout in snapshot.workouts {
            for entry in workout.entries {
                for set in entry.sets {
                    lines.append(row(fields(workout: workout, entry: entry, set: set)))
                }
            }
        }
        // Trailing terminator: a text file's last line ends, and appending to
        // the file later cannot glue two rows together.
        return lines.joined(separator: lineTerminator) + lineTerminator
    }

    /// UTF-8 bytes with a byte-order mark (D32). The BOM is for Excel, which
    /// otherwise decodes a UTF-8 CSV as the system code page and mojibakes any
    /// gym or exercise name that is not ASCII.
    static func data(_ snapshot: ExportSnapshot) -> Data {
        Data("\u{FEFF}".utf8) + Data(render(snapshot).utf8)
    }

    // MARK: - Rows

    private static func fields(
        workout: ExportSnapshot.Workout,
        entry: ExportSnapshot.Entry,
        set: ExportSnapshot.SetRow
    ) -> [String] {
        [
            workout.id.uuidString,
            workout.startedAt,
            workout.finishedAt ?? "",
            workout.sourceTemplateName ?? "",
            workout.notes,
            entry.gymID?.uuidString ?? "",
            entry.gymName ?? "",
            entry.id.uuidString,
            String(entry.order),
            entry.exerciseID.uuidString,
            entry.exerciseName,
            entry.loadType.rawValue,
            entry.freeWeightTag?.rawValue ?? "",
            entry.machineID?.uuidString ?? "",
            entry.machineLabel ?? "",
            entry.modelID?.uuidString ?? "",
            entry.modelManufacturer ?? "",
            entry.modelDisplayName ?? "",
            set.id.uuidString,
            String(set.order),
            set.type.rawValue,
            set.reps.map(String.init) ?? "",
            // As entered and normalized, both at full precision, both with a
            // locale-independent decimal point (D29/D25). No converted value
            // and no ≈ ever reaches a file.
            set.weight.map(WeightMath.storageNumber) ?? "",
            set.unit.rawValue,
            set.weightKg.map(WeightMath.storageNumber) ?? "",
            set.completedAt == nil ? "false" : "true",
            set.completedAt ?? "",
            entry.presetID?.uuidString ?? "",
            entry.presetName ?? "",
        ]
    }

    private static func row(_ fields: [String]) -> String {
        fields.map(escaped).joined(separator: ",")
    }

    /// RFC 4180 quoting: quote a field only when it must be quoted, and double
    /// any quote inside it. User text goes in verbatim otherwise — no
    /// formula-injection prefixing (D32): silently editing the user's own notes
    /// to protect them from their own spreadsheet is the wrong trade in a file
    /// whose entire job is to be a faithful copy.
    static func escaped(_ field: String) -> String {
        // Scalars, not Characters: Swift reads a CRLF pair as ONE Character
        // ("\r\n"), so comparing Characters against "\r" and "\n" silently
        // misses a Windows newline pasted into a note — the field would go out
        // unquoted and a strict reader would see it as a new record, shifting
        // every row after it (codex-review, finding 3).
        let needsQuoting = field.unicodeScalars.contains {
            $0 == "\"" || $0 == "," || $0 == "\n" || $0 == "\r"
        }
        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
