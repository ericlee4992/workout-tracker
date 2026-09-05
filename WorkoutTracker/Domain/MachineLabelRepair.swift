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
// A repaired token is trusted downstream as if the camera had read it, so a
// wrong repair is a wrong brand with full confidence — D33's forbidden
// outcome. The first cut of this file repaired any unknown word within an
// edit or two of a brand token, and the cross-review (codex-review-02)
// showed what that manufactures: `MOIST CHEST PRESS RS-2301` became a Hoist
// plate and preselected the real Hoist row; `PRICE FITNESS` became PRIME;
// `START TRACK` became Star Trac; `RECORD` became Precor. Hence the shape now:
//
//  - a brand is repaired ONLY on a line that is nothing but that brand, its
//    tokens in order — which is exactly how a logo reads (every corpus case
//    was a lone token on its own line) and never how prose reads;
//  - only a LEADING stray character is stripped (the swoosh precedes the
//    word); a trailing letter is a plural or a code, never a smudge;
//  - an edit repair may not shorten the token (`START` is not `star`,
//    `HAMMERS` is not `hammer`), and two edits are allowed only for a long
//    token or one corroborated by the brand's other word read exactly;
//  - a glued split needs the separator character a slash becomes AND both
//    halves in ONE catalog row's name (`dip` + `chin` ← Select Assist Dip
//    Chin), never two catalog words that merely exist (`airlift`,
//    `counterweight`, `faceplate` all split into real catalog words).

struct MachineLabelRepair {

    /// A multi-word brand's tokens, in order, for the line-level match.
    private let brandTokenSequences: [[String]]
    /// Every brand token of ≥ `minimumBrandTokenLength` characters.
    private let brandTokens: Set<String>
    /// Glued forms of multi-word brands (`lifefitness`) → their tokens.
    private let gluedForms: [(glued: String, tokens: [String])]
    private let isKnown: (String) -> Bool
    /// Whether two tokens sit together in one catalog row's model name.
    private let shareARow: (String, String) -> Bool
    /// Whether a token is an ordinary English word. An EDIT repair (one or
    /// two letters changed) is refused for a real word: `PRICE` is not a
    /// misread `PRIME`, `MOIST` is not `HOIST`, `START TRACK` is not Star
    /// Trac (codex-review-02 #1). The camera's corruptions — `HOISI`,
    /// `LAMMED`, `STRENCTH`, `LieFitness` — are not words. nil means no
    /// dictionary is available, and then NO edit repair is made at all; only
    /// the stray-leading-character strip and the glued split remain.
    private let isDictionaryWord: ((String) -> Bool)?

    /// Tokens shorter than this are never repaired: too many real words are
    /// one edit from each other at three letters.
    static let minimumBrandTokenLength = 4
    /// Halves of a split must each be a real word of at least this length.
    static let minimumSplitHalfLength = 3
    /// The characters a slash or a bar reads as.
    static let slashConfusions: Set<Character> = ["i", "l", "1"]

    init(
        manufacturers: [String],
        isKnown: @escaping (String) -> Bool,
        shareARow: @escaping (String, String) -> Bool,
        isDictionaryWord: ((String) -> Bool)? = nil
    ) {
        let sequences = manufacturers.map(MachineLabelText.tokens).filter { !$0.isEmpty }
        self.brandTokenSequences = sequences
        self.brandTokens = Set(sequences.flatMap { $0 }.filter { $0.count >= Self.minimumBrandTokenLength })
        self.gluedForms = sequences.filter { $0.count > 1 }
            .map { ($0.joined(), $0) }
            .sorted { $0.glued < $1.glued }
        self.isKnown = isKnown
        self.shareARow = shareARow
        self.isDictionaryWord = isDictionaryWord
    }

    // MARK: Lines

    /// The reading with every line repaired. Line structure, confidence and
    /// height are preserved; only the words change.
    func repaired(_ reading: LabelReading) -> LabelReading {
        var copy = reading
        copy.lines = reading.lines.map { line in
            var repairedLine = line
            repairedLine.text = repairedText(line.text)
            return repairedLine
        }
        // A multi-word brand set over two lines — `LAMMED` above `STRENGTH`,
        // `HAMMER` above `STRENCTH` — is one brand line broken in two. Tried
        // only where the single-line pass changed nothing on either line.
        var index = 0
        while index + 1 < copy.lines.count {
            let upper = copy.lines[index], lower = copy.lines[index + 1]
            let upperTokens = MachineLabelText.readingTokens(upper.text)
            let lowerTokens = MachineLabelText.readingTokens(lower.text)
            if upper.text == reading.lines[index].text, lower.text == reading.lines[index + 1].text,
               !upperTokens.isEmpty, !lowerTokens.isEmpty,
               let repairedPair = repairedBrandLine(upperTokens + lowerTokens) {
                let upperWords = Array(repairedPair[..<upperTokens.count]).flatMap { $0 }
                let lowerWords = Array(repairedPair[upperTokens.count...]).flatMap { $0 }
                copy.lines[index].text = upperWords.map { Self.styled($0, like: upper.text) }.joined(separator: " ")
                copy.lines[index + 1].text = lowerWords.map { Self.styled($0, like: lower.text) }.joined(separator: " ")
                index += 2
            } else {
                index += 1
            }
        }
        return copy
    }

    /// One line's text with ONLY the repaired words rewritten. Every other
    /// character — case, punctuation, spacing — is exactly as read, because
    /// the create-new sheet prefills the model name from this and
    /// `Iso-Lateral Row` must stay `Iso-Lateral Row` (codex-review-02 #5:
    /// the first cut rejoined the whole line with single spaces and rebuilt
    /// `HOISI-RS-2403` as `HOIST RS 2403`). A repaired word takes the case
    /// style of the run it replaces (`SCYBEX` → `CYBEX`).
    func repairedText(_ text: String) -> String {
        let runs = Self.alphanumericRuns(in: text)
        let tokens = runs.map { MachineLabelText.normalized(String(text[$0])) }
        let replacements = repairedTokens(tokens)
        let untouched = tokens.map { [$0] }
        guard replacements != untouched else { return text }
        var result = ""
        var cursor = text.startIndex
        for (run, replacement) in zip(runs, replacements) {
            result += text[cursor..<run.lowerBound]
            let original = String(text[run])
            let token = MachineLabelText.normalized(original)
            if replacement == [token] {
                result += original
            } else {
                result += replacement.map { Self.styled($0, like: original) }.joined(separator: " ")
            }
            cursor = run.upperBound
        }
        result += text[cursor...]
        return result
    }

    /// The line's tokens → each token's replacement (itself when untouched).
    /// Brand repair is decided for the LINE; splits per token.
    func repairedTokens(_ tokens: [String]) -> [[String]] {
        if let brand = repairedBrandLine(tokens) { return brand }
        return tokens.map { split($0) ?? [$0] }
    }

    // MARK: Brand lines

    /// A line that is one brand and nothing else, with a corrupted word
    /// repaired: `["scybex"]` → `[["cybex"]]`, `["lammed", "strength"]` →
    /// `[["hammer"], ["strength"]]`, `["liefitness"]` → `[["life", "fitness"]]`.
    /// nil when the line is anything else — prose, a model name, a brand plus
    /// other words, or a line that already reads exactly as the brand.
    func repairedBrandLine(_ tokens: [String]) -> [[String]]? {
        // Something on the line must be unknown; a line of known words is
        // either the brand read exactly or not a brand line at all.
        guard tokens.contains(where: { !isKnown($0) }) else { return nil }
        // A glued script logo: one token, one brand.
        if tokens.count == 1, let words = repairedGluedBrand(tokens[0]) { return [words] }

        // Token-for-token against each brand's sequence, in order.
        var candidates: [[[String]]] = []
        for sequence in brandTokenSequences where sequence.count == tokens.count {
            var distances: [Int] = []   // per word: 0 exact/strip, 1, 2
            var ok = true
            for (token, brandToken) in zip(tokens, sequence) {
                if token == brandToken { distances.append(0); continue }
                guard !isKnown(token), let distance = repairDistance(token, to: brandToken) else { ok = false; break }
                // An edit repair of a real English word is a different word,
                // not a misread (`PRICE`, `MOIST`, `START`). No dictionary,
                // no edit repairs.
                if distance > 0 {
                    guard let isDictionaryWord, !isDictionaryWord(token) else { ok = false; break }
                }
                distances.append(distance)
            }
            guard ok else { continue }
            // Two edits in one word only when the token is long, or another
            // word of the same brand corroborates it (exact, stripped or one
            // edit): `RENGTH` beside `YAMMER`, never `RECORD` alone as Precor.
            let corroborated = zip(tokens, distances).contains { $0.1 <= 1 }
                && zip(distances, tokens).filter { $0.0 == 2 }.count < distances.count
            for (token, distance) in zip(tokens, distances) where distance == 2 {
                guard token.count >= 7 || corroborated else { ok = false; break }
            }
            guard ok else { continue }
            candidates.append(zip(tokens, sequence).map { [$0.1] })
        }
        // Exactly one brand fits, or nothing.
        guard candidates.count == 1 else { return nil }
        return candidates[0]
    }

    /// The distance at which `token` may become `brand`, or nil: a leading
    /// stray character before the exact brand token (distance 0 — the
    /// swoosh), else one or two edits; whether two is acceptable is decided
    /// by the line (`repairedBrandLine`). A token longer than the brand is
    /// never shortened to it (`START` is not `star`, `HAMMERS` not `hammer`).
    func repairDistance(_ token: String, to brand: String) -> Int? {
        guard token.count >= Self.minimumBrandTokenLength, brand.count >= Self.minimumBrandTokenLength else { return nil }
        if String(token.dropFirst()) == brand { return 0 }
        guard token.count <= brand.count else { return nil }
        guard let distance = CatalogMatcher.editDistance(token, brand, limit: 2), distance > 0 else { return nil }
        return distance
    }

    /// `liefitness` / `lifefilness` → `["life", "fitness"]`: a script logo
    /// read as one word, within two edits of a multi-word brand's glued form.
    func repairedGluedBrand(_ token: String) -> [String]? {
        guard token.count >= 8, !isKnown(token) else { return nil }
        // Same rule as an edit repair: a real word is not a misread logo.
        guard let isDictionaryWord, !isDictionaryWord(token) else { return nil }
        var nearest: [(tokens: [String], distance: Int)] = []
        for (glued, words) in gluedForms {
            guard abs(glued.count - token.count) <= 2 else { continue }
            guard let distance = CatalogMatcher.editDistance(token, glued, limit: 2) else { continue }
            nearest.append((words, distance))
        }
        guard let best = nearest.min(by: { $0.distance < $1.distance }) else { return nil }
        let tied = nearest.filter { $0.distance == best.distance }.map { $0.tokens.joined() }
        guard Set(tied).count == 1 else { return nil }
        return best.tokens
    }

    // MARK: Glued words

    /// `dipichin` → `["dip", "chin"]`: an unknown token that is two words
    /// joined by the character a slash reads as, where BOTH words sit in one
    /// catalog row's name. nil for anything else — including a real compound
    /// word that happens to be two catalog words (`airlift`, `faceplate`).
    func split(_ token: String) -> [String]? {
        guard !isKnown(token) else { return nil }
        let characters = Array(token)
        let minimum = Self.minimumSplitHalfLength
        guard characters.count >= minimum * 2 + 1 else { return nil }
        var candidates: [[String]] = []
        for cut in minimum..<(characters.count - minimum) where Self.slashConfusions.contains(characters[cut]) {
            let left = String(characters[..<cut])
            let right = String(characters[(cut + 1)...])
            guard right.count >= minimum, isKnown(left), isKnown(right), shareARow(left, right) else { continue }
            candidates.append([left, right])
        }
        guard candidates.count == 1 else { return nil }
        return candidates[0]
    }

    // MARK: Helpers

    /// Maximal runs of letters/digits in `text` — the units repair works on.
    static func alphanumericRuns(in text: String) -> [Range<String.Index>] {
        var runs: [Range<String.Index>] = []
        var start: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            let isWord = text[index].isLetter || text[index].isNumber
            if isWord, start == nil { start = index }
            if !isWord, let s = start { runs.append(s..<index); start = nil }
            index = text.index(after: index)
        }
        if let s = start { runs.append(s..<text.endIndex) }
        return runs
    }

    /// `token` in the case style of `sample`: all caps, Capitalised, or as is.
    static func styled(_ token: String, like sample: String) -> String {
        let letters = sample.filter(\.isLetter)
        if !letters.isEmpty, letters.allSatisfy(\.isUppercase) { return token.uppercased() }
        if letters.first?.isUppercase == true { return token.prefix(1).uppercased() + token.dropFirst() }
        return token
    }
}
