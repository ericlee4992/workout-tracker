import Foundation

// Milestone 3, ticket 02 — what an export is called and where it is written.
// Domain rather than feature code: naming is part of the format, and the
// filename is the only label the user will see once the file is in Files.

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv
    case json

    var id: String { rawValue }
    var fileExtension: String { rawValue }
    var label: String { rawValue.uppercased() }
}

enum ExportFileWriter {

    /// `workout-tracker-2026-08-11-1830.csv` — local time (D31's reasoning
    /// applies to the name too), zero-padded so the files sort chronologically
    /// in Files.
    static func filename(
        format: ExportFormat, at date: Date, dateFormat: ExportDateFormat = ExportDateFormat()
    ) -> String {
        "workout-tracker-\(dateFormat.fileStamp(from: date)).\(format.fileExtension)"
    }

    /// Root of the staging area: a dedicated temp subdirectory, so cleaning up
    /// old exports can never touch anything else.
    static var defaultDirectory: URL {
        FileManager.default.temporaryDirectory
            .appending(path: "Exports", directoryHint: .isDirectory)
    }

    /// Writes `data` as a fresh export file and returns its URL.
    ///
    /// Each export gets its own subdirectory, so a file is never pulled out
    /// from under an activity that is still consuming it — the caller deletes
    /// `url.deletingLastPathComponent()` when the share sheet reports it is
    /// done (`discard(at:)`). Earlier staging that was never claimed is swept
    /// on the next export rather than up front, so a write that fails does not
    /// also destroy the last good file (codex-review, finding 10).
    @discardableResult
    static func write(
        _ data: Data,
        format: ExportFormat,
        at date: Date = .now,
        dateFormat: ExportDateFormat = ExportDateFormat(),
        in directory: URL? = nil
    ) throws -> URL {
        let root = directory ?? defaultDirectory
        let staging = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: staging, withIntermediateDirectories: true)
        let url = staging.appending(
            path: filename(format: format, at: date, dateFormat: dateFormat))
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
        sweep(root, keeping: staging)
        return url
    }

    /// Removes one export's staging directory once the share sheet is finished
    /// with it. Best-effort: the OS clears the temp directory anyway, so a
    /// failure here costs nothing.
    static func discard(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private static func sweep(_ root: URL, keeping staging: URL) {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.lastPathComponent != staging.lastPathComponent {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
