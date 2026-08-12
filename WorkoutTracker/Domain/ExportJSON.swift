import Foundation

// Milestone 3, ticket 01 — the machine-readable export: the whole object
// graph, versioned. Pure `ExportSnapshot → Data`; no UI, no SwiftData.
//
// Written so it can be read back: stable UUIDs throughout, no derived values,
// nothing collapsed. Restoring from it is milestone 3's sequel, not milestone 3.

enum ExportJSON {

    enum Failure: Error, LocalizedError {
        case encodingFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .encodingFailed(let underlying):
                "Could not encode the export: \(underlying.localizedDescription)"
            }
        }
    }

    static func data(_ snapshot: ExportSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        // Sorted keys + pretty printing: the file is meant to be opened, read
        // and diffed by a human as well as parsed. Determinism also means two
        // exports of unchanged data differ only in `exportedAt`.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Dates are already ISO 8601 strings in the snapshot (D31); nothing
        // here re-formats them. Nil optionals are omitted by Swift's synthesized
        // `encodeIfPresent`, so an absent value is absent rather than `null`.
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw Failure.encodingFailed(underlying: error)
        }
    }

    /// Reads back a snapshot this app wrote. Present so the format's
    /// round-trip is testable now, and so a future importer has one decoder to
    /// share rather than two that drift.
    static func decode(_ data: Data) throws -> ExportSnapshot {
        try JSONDecoder().decode(ExportSnapshot.self, from: data)
    }
}
