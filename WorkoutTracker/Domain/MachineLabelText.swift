import Foundation

// Photo machine capture, ticket 01 — what a name plate said, and how to read
// meaning out of it. Pure: no UI, no SwiftData, no Vision.
//
// `MachineLabelOCR` produces a `LabelReading`; `CatalogMatcher` ranks the
// catalog against it; the create-new path uses the guesses at the bottom of
// this file. Everything here is text handling, so everything here is testable
// without a camera.

/// One photographed label, as text.
struct LabelReading: Equatable {

    /// A single recognised line, top of the plate first.
    struct Line: Equatable {
        var text: String
        /// Vision's own confidence, 0–1.
        var confidence: Double
        /// Line height as a fraction of the image. The model name is almost
        /// always the biggest text on a name plate and the manufacturer sits
        /// above it in smaller type, so size is a real signal about which line
        /// is which — more reliable than position alone.
        var heightFraction: Double

        init(text: String, confidence: Double = 1, heightFraction: Double = 0) {
            self.text = text
            self.confidence = confidence
            self.heightFraction = heightFraction
        }
    }

    var lines: [Line] = []

    var isEmpty: Bool { lines.allSatisfy { $0.text.trimmed.isEmpty } }

    /// The whole plate as the user will see it echoed back in the sheet.
    var text: String {
        lines.map(\.text).joined(separator: "\n")
    }

    static func lines(_ texts: [String]) -> LabelReading {
        LabelReading(lines: texts.map { Line(text: $0) })
    }
}

// MARK: - Normalisation

enum MachineLabelText {

    /// Case-folded, diacritic-free, punctuation-free, single-spaced.
    ///
    /// Name plates are shouted in capitals, sometimes stylised
    /// (`LIFE FITNESS®`, `Hammer Strength™`), and Vision reproduces whatever
    /// it sees. Comparison happens in one flat form or not at all.
    static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// Normalised tokens of a **catalog row**. Nothing is dropped: shipped
    /// identities turn on single characters — `4 Station` vs `5 Station`,
    /// `R-4` vs `R-6`, PRIME's `2:1` vs `4:1`. Filtering them made distinct
    /// catalog UUIDs indistinguishable, which is the D23 history-splitting
    /// failure in its purest form (codex-review, finding 2).
    static func tokens(_ text: String) -> [String] {
        normalized(text)
            .split(separator: " ")
            .map(String.init)
    }

    /// Normalised tokens of a **photograph** — the same rule as the catalog
    /// side, deliberately.
    ///
    /// An earlier version dropped lone letters here as OCR noise, and that
    /// quietly recreated the identity bug it was meant to avoid on the other
    /// side of the comparison: `T-Bar` becomes `t bar` and `D.Y.` becomes
    /// `d y`, so dropping lone letters turned a photo of an Iso-Lateral
    /// **T-Bar** Row into evidence for plain `Iso-Lateral Row` — which then
    /// preselected, because it explained everything that was left. Noise is
    /// filtered by weighting and by the preselection gate, not by length.
    static func readingTokens(_ text: String) -> [String] {
        tokens(text)
    }

    // MARK: Junk lines

    /// Whole words that appear on name plates and never in a model name.
    ///
    /// Matched as **tokens**, not substrings. A substring rule looked tidy and
    /// classified 73 shipped model names as furniture: `min` matched every
    /// `Abdominal`, `rev` matched `Reverse`, `max` matched Gym80's `Basic Max
    /// Rack` (codex-review-2, finding 4). A line wrongly called junk is dropped
    /// from the create-new name guess *and* from the evidence a candidate has
    /// to explain, which is exactly the term that keeps generic rows honest.
    private static let junkWords: Set<String> = [
        "warning", "caution", "danger", "patent", "instructions",
        "serial", "sn", "www", "com",
    ]

    /// Phrases, matched as consecutive tokens.
    private static let junkPhrases: [[String]] = [
        ["read", "manual"], ["read", "instructions"], ["before", "use"],
        ["made", "in"], ["part", "no"], ["weight", "stack", "capacity"],
        ["maximum", "capacity"], ["max", "capacity"], ["user", "weight"],
    ]

    /// Whether a line is plate furniture rather than the hardware's name:
    /// load ratings, warnings, URLs, part numbers, pure digits.
    ///
    /// Used only for *guessing* what to call a new model. Matching keeps these
    /// lines, because a line the eye reads as junk sometimes carries the one
    /// token that identifies the row — Precor's catalogue names really do
    /// include codes like `VSL019BP`.
    static func isJunkLine(_ text: String) -> Bool {
        let normalized = normalized(text)
        guard !normalized.isEmpty else { return true }
        // No letters at all: a number, a date, a stack rating.
        if !normalized.contains(where: \.isLetter) { return true }

        let tokens = tokens(text)
        if tokens.contains(where: junkWords.contains) { return true }
        for phrase in junkPhrases where contains(phrase, in: tokens) { return true }
        // "300 lb" / "150 kg" style ratings — the numeric context is what makes
        // "max" furniture, not the word on its own.
        if normalized.range(of: #"\d+\s?(lb|lbs|kg|kgs)\b"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func contains(_ phrase: [String], in tokens: [String]) -> Bool {
        guard !phrase.isEmpty, tokens.count >= phrase.count else { return false }
        for start in 0...(tokens.count - phrase.count) {
            if Array(tokens[start..<(start + phrase.count)]) == phrase { return true }
        }
        return false
    }

    // MARK: Guessing a name for a new model (D35)

    /// The manufacturer the plate names, in the catalog's own spelling when the
    /// catalog knows it.
    ///
    /// Canonical spelling matters: a user-created model that says
    /// `LIFE FITNESS` sorts and reads as a different brand from the 200 seeded
    /// rows that say `Life Fitness`, for no reason the user would accept.
    static func guessManufacturer(
        in reading: LabelReading, knownManufacturers: [String]
    ) -> String? {
        let brandLine = reading.lines.first { !isJunkLine($0.text) }

        // Longest match first: "Hammer Strength" must beat "Hammer".
        let ranked = knownManufacturers
            .sorted { lhs, rhs in
                let left = tokens(lhs).count, right = tokens(rhs).count
                return left == right ? lhs < rhs : left > right
            }

        func knownBrand(in text: String) -> String? {
            let candidates = Set(readingTokens(text))
            guard !candidates.isEmpty else { return nil }
            return ranked.first { manufacturer in
                let needed = Set(readingTokens(manufacturer))
                return !needed.isEmpty && needed.isSubset(of: candidates)
            }
        }

        // The brand line first (codex-review, finding 9). Scanning the whole
        // photo lets a *neighbouring* machine's brand — or a brand word printed
        // in a warning — overwrite a genuinely new manufacturer's name.
        if let brandLine, let known = knownBrand(in: brandLine.text) { return known }

        // Then the rest of the plate, but only when exactly one known brand
        // appears in it: two brands in one photograph is a photograph of two
        // machines, and guessing between them is worse than not guessing.
        let elsewhere = reading.lines
            .filter { !isJunkLine($0.text) && $0.text != brandLine?.text }
            .compactMap { knownBrand(in: $0.text) }
        if Set(elsewhere).count == 1, let only = elsewhere.first { return only }

        // Nothing known: the brand is conventionally the top line of a plate,
        // as long as that line is not furniture. Preserved verbatim — a new
        // manufacturer is exactly the case where inventing a spelling is wrong.
        return brandLine.map { $0.text.trimmed }
    }

    /// The best candidate for a model name: the largest non-junk line that is
    /// not just the manufacturer repeated. Falls back to the first usable line,
    /// then to the raw text, because an editable wrong guess beats an empty
    /// field the user has to fill in standing at the machine.
    static func guessModelName(in reading: LabelReading, manufacturer: String?) -> String {
        let manufacturerTokens = Set(readingTokens(manufacturer ?? ""))
        let usable = reading.lines.filter { line in
            guard !isJunkLine(line.text) else { return false }
            let lineTokens = Set(readingTokens(line.text))
            guard !lineTokens.isEmpty else { return false }
            // Drop a line that says nothing but the brand.
            return !manufacturerTokens.isEmpty ? !lineTokens.isSubset(of: manufacturerTokens) : true
        }
        let byPresence = usable.max {
            ($0.heightFraction, $0.confidence) < ($1.heightFraction, $1.confidence)
        }
        return (byPresence ?? usable.first).map { $0.text.trimmed }
            ?? reading.text.trimmed
    }
}

/// Local convenience only — the codebase's idiom elsewhere is a `trimmedName`
/// computed property per view, and a module-wide `String.trimmed` would be a
/// bigger change than this feature is entitled to make.
private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
