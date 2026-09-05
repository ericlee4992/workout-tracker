import Foundation

// Scanner accuracy, ticket 02 — repairing what the camera did to the words
// BEFORE the catalog is ranked against them. Pure: no UI, no Vision.
//
// The corpus (`.scratch/scanner-accuracy/reports/`) showed one dominant
// failure: a brand printed as a logo comes back as a corrupted token —
// `SCYBEX` (the swoosh read as a letter), `LAMMED STRENGTH`, `YAMMER RENGTH`,
// `LieFitness`, `HOISI` — and `manufacturerMatched` needs the exact token, so a
// plate whose model name read perfectly could still never preselect. Second:
// a slash reads as the letter I, gluing two known words into one unknown one
// (`DIP/CHIN` → `DIPICHIN`).
//
// Both are repaired here, conservatively. Every rule refuses when the token is
// a word the catalog already knows (`row` is never a misread brand), when it
// is too short to be safe, or when two different brands are equally near — an
// ambiguity is left for the matcher to treat as unknown, never resolved by a
// guess. What breaks if this is loosened: a repaired token is trusted as if
// the camera had read it, so a wrong repair is a wrong brand with full
// confidence, which is the D33 failure this whole pipeline exists to avoid.

struct MachineLabelRepair {

    /// A brand as the repair knows it: its tokens, and the glued form a
    /// script logo reads as (`LifeFitness` → `lifefitness`).
    struct Brand: Equatable {
        let name: String
        let tokens: [String]
        var glued: String { tokens.joined() }
    }

    private let brands: [Brand]
    /// Every brand token of ≥ `minimumBrandTokenLength` characters, with the
    /// brand(s) it belongs to. `strength` maps to Hammer Strength only; a
    /// token shared by two brands is still repaired (the token is right), the
    /// brand it implies is the matcher's business.
    private let brandTokens: [String]
    private let gluedForms: [(glued: String, brand: Brand)]
    private let isKnown: (String) -> Bool

    /// Tokens shorter than this are never repaired: too many real words are
    /// one edit from each other at three letters.
    static let minimumBrandTokenLength = 4
    /// Halves of a split must each be a real word of at least this length.
    static let minimumSplitHalfLength = 3

    init(manufacturers: [String], isKnown: @escaping (String) -> Bool) {
        let brands = manufacturers.compactMap { name -> Brand? in
            let tokens = MachineLabelText.tokens(name)
            return tokens.isEmpty ? nil : Brand(name: name, tokens: tokens)
        }
        self.brands = brands
        self.brandTokens = Array(Set(brands.flatMap(\.tokens)
            .filter { $0.count >= Self.minimumBrandTokenLength })).sorted()
        self.gluedForms = brands
            .filter { $0.tokens.count > 1 }
            .map { ($0.glued, $0) }
            .sorted { $0.glued < $1.glued }
        self.isKnown = isKnown
    }

    /// The reading with every line's tokens repaired. Line structure,
    /// confidence and height are preserved; only the words change.
    func repaired(_ reading: LabelReading) -> LabelReading {
        var copy = reading
        copy.lines = reading.lines.map { line in
            var repairedLine = line
            repairedLine.text = repairedText(line.text)
            return repairedLine
        }
        return copy
    }

    /// One line's tokens, repaired and rejoined with single spaces. A line
    /// with nothing to repair comes back normalised but otherwise unchanged.
    func repairedText(_ text: String) -> String {
        MachineLabelText.readingTokens(text)
            .flatMap { repair($0) }
            .joined(separator: " ")
    }

    /// One token → the tokens it should have been. Known words pass through
    /// untouched; so does anything the rules below cannot repair safely.
    func repair(_ token: String) -> [String] {
        if isKnown(token) { return [token] }
        if let brand = repairedBrandToken(token) { return [brand] }
        if let words = repairedGluedBrand(token) { return words }
        if let halves = split(token) { return halves }
        return [token]
    }

    // MARK: Brand tokens

    /// `scybex` → `cybex`, `hoisi` → `hoist`, `lammed` → `hammer`,
    /// `rength` → `strength`. nil when nothing is safely near.
    func repairedBrandToken(_ token: String) -> String? {
        guard token.count >= Self.minimumBrandTokenLength else { return nil }
        // One stray character at either end around an exact brand token: the
        // swoosh, a registered-mark, a scratch. Exact, so it wins outright.
        let strippedLeading = String(token.dropFirst())
        let strippedTrailing = String(token.dropLast())
        if brandTokens.contains(strippedLeading) { return strippedLeading }
        if brandTokens.contains(strippedTrailing) { return strippedTrailing }

        let allowed = token.count >= 6 ? 2 : 1
        var nearest: [(token: String, distance: Int)] = []
        for brand in brandTokens {
            guard abs(brand.count - token.count) <= allowed else { continue }
            guard let distance = CatalogMatcher.editDistance(token, brand, limit: allowed) else { continue }
            nearest.append((brand, distance))
        }
        guard let best = nearest.min(by: { $0.distance < $1.distance }) else { return nil }
        // Two different brand tokens equally near: ambiguous, leave it.
        let tied = nearest.filter { $0.distance == best.distance }.map(\.token)
        guard Set(tied).count == 1 else { return nil }
        return best.token
    }

    /// `liefitness` / `lifefilness` → `["life", "fitness"]`: a script logo
    /// read as one word, within two edits of a multi-word brand's glued form.
    func repairedGluedBrand(_ token: String) -> [String]? {
        guard token.count >= 8 else { return nil }
        var nearest: [(brand: Brand, distance: Int)] = []
        for (glued, brand) in gluedForms {
            guard abs(glued.count - token.count) <= 2 else { continue }
            guard let distance = CatalogMatcher.editDistance(token, glued, limit: 2) else { continue }
            nearest.append((brand, distance))
        }
        guard let best = nearest.min(by: { $0.distance < $1.distance }) else { return nil }
        let tied = nearest.filter { $0.distance == best.distance }.map(\.brand.glued)
        guard Set(tied).count == 1 else { return nil }
        return best.brand.tokens
    }

    // MARK: Glued words

    /// `dipichin` → `["dip", "chin"]` (a slash read as I) and `dipchin` →
    /// `["dip", "chin"]` (no separator at all): an unknown token that is two
    /// known words, optionally joined by one of the characters a slash or
    /// bar becomes. nil unless BOTH halves are real catalog words.
    func split(_ token: String) -> [String]? {
        let characters = Array(token)
        guard characters.count >= Self.minimumSplitHalfLength * 2 else { return nil }
        let separators: Set<Character> = ["i", "l", "1"]
        var candidates: [[String]] = []
        for cut in Self.minimumSplitHalfLength...(characters.count - Self.minimumSplitHalfLength) {
            let left = String(characters[..<cut])
            let right = String(characters[cut...])
            if isKnown(left), isKnown(right) { candidates.append([left, right]) }
            // With a separator character consumed.
            if characters.count - cut - 1 >= Self.minimumSplitHalfLength,
               separators.contains(characters[cut]) {
                let rightAfter = String(characters[(cut + 1)...])
                if isKnown(left), isKnown(rightAfter) { candidates.append([left, rightAfter]) }
            }
        }
        // Exactly one way to read it as two words, or nothing.
        guard candidates.count == 1 else { return nil }
        return candidates[0]
    }
}
