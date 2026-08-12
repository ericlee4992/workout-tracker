import Foundation

// Exercise presets — the small rules about naming and ordering them. Pure: no
// UI, no SwiftData.
//
// Presets are user-created (D37) and records key on them (D36), so two presets
// that read the same to a human but differ as rows would split a PR table for
// no reason the user could see. That is the whole job of this file.

enum ExercisePresets {

    /// Names offered when adding a preset. Suggestions, not a catalog: they
    /// save typing at the gym and nothing more. D3's reasoning applies — a
    /// worldwide list of every grip on every machine is unknowable, so the app
    /// does not pretend to have one.
    static let suggestions = [
        "Wide grip", "Narrow grip", "Neutral grip", "Reverse grip",
        "Single arm", "Single leg", "Double leg",
        "High pulley", "Low pulley", "Feet high", "Feet low",
    ]

    /// What the user typed, trimmed. Names are stored as written — "Wide Grip"
    /// stays "Wide Grip" — because it is their label to read.
    static func cleanedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether `name` already exists among `existing`, ignoring case and
    /// spacing. "wide grip" and "Wide Grip" are one preset; letting both exist
    /// would split a rep-count table across two rows that look identical in the
    /// chips (D36).
    static func isDuplicate(_ name: String, among existing: [String]) -> Bool {
        let candidate = comparable(name)
        guard !candidate.isEmpty else { return false }
        return existing.contains { comparable($0) == candidate }
    }

    /// Whether a name can be added at all.
    static func isValid(_ name: String, existing: [String]) -> Bool {
        !cleanedName(name).isEmpty && !isDuplicate(name, among: existing)
    }

    /// Order for a preset appended to `existing` orders.
    static func nextOrder(after existing: [Int]) -> Int {
        (existing.max() ?? -1) + 1
    }

    /// Orders renumbered 0..<n in the given sequence, for after a move or a
    /// delete — scalar ordering, never implicit to-many order (T2).
    static func renumbered(_ count: Int) -> [Int] {
        Array(0..<count)
    }

    private static func comparable(_ name: String) -> String {
        cleanedName(name)
            .folding(options: [.caseInsensitive, .diacriticInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
