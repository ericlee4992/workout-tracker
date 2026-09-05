import Foundation

// Photo machine capture, ticket 01 — ranking the catalog against a photographed
// name plate. Pure: no UI, no SwiftData, no Vision.
//
// The job is not "find the best row" — it is "be right, or say you are not
// sure". D23 keys history, prefill and PRs on the model UUID, so a confident
// wrong match splits the user's own training history exactly the way duplicate
// catalog identities did (codex-review-4). Hence D33: this file proposes, the
// user confirms, and a weak or ambiguous best answer is reported as such.
//
// The first cross-review of this file (`.scratch/photo-machine-capture/
// codex-review.md`) found four ways to score a *confident wrong row*, and the
// shape below is what closes them:
//
//  - evidence the plate offers but a row cannot explain counts against that row,
//    including words the catalog has never seen ("NEWCO");
//  - a row whose manufacturer the plate contradicts cannot be preselected;
//  - a near-tie is an ambiguity to surface, never a winner to pick;
//  - one recognised word cannot stand in as evidence for two different catalog
//    words ("abduction" is not "adduction").

/// One ranked catalog row.
struct CatalogMatch: Equatable {
    let modelID: UUID
    let manufacturer: String
    let modelName: String
    /// 0–1. Comparable only against the thresholds below, not a probability.
    let score: Double
    /// The plate names this row's manufacturer.
    let manufacturerMatched: Bool
    /// The plate names a known manufacturer other than this row's — including
    /// when it *also* names this row's, because two brands in one photograph is
    /// a photograph of two machines (D33: "and no other known one").
    let manufacturerConflicts: Bool
    /// Share of the plate's own evidence this row accounts for, 0–1. A row that
    /// explains little of what the plate says is a poor answer even when every
    /// word of its own name was found.
    let explanation: Double

    var displayName: String { "\(manufacturer) \(modelName)" }
}

/// The catalog, prepared for matching: tokens per row plus the IDF weight of
/// every token across the whole catalog.
///
/// Weights are a property of the corpus, not of any one row: "series" and
/// "press" appear in hundreds of names and say almost nothing, while
/// "insignia", "sorinex" or "vsl019bp" nearly identify a row on their own. Term
/// frequency does that arithmetic for us instead of a hand-written stop-word
/// list that would need updating with the catalog.
struct CatalogMatchIndex {

    struct Entry {
        let id: UUID
        let manufacturer: String
        let modelName: String
        /// Everything the row says, manufacturer included, weight-descending so
        /// scoring consumes the most distinctive evidence first.
        let tokens: [String]
        let manufacturerTokens: [String]
        /// The model-name tokens alone. Coverage is measured over *these*: the
        /// brand is already worth its own bonus, and counting it twice let
        /// "Insignia Series Row" score 86% on a plate that plainly said Chest
        /// Press, purely because it shared "Life Fitness Insignia Series".
        let nameTokens: Set<String>
        /// Σ weight over `nameTokens` — the denominator for coverage.
        let nameWeight: Double
    }

    private(set) var entries: [Entry] = []
    private(set) var weights: [String: Double] = [:]
    /// Weight given to a word the catalog has never seen. Such a word is
    /// maximally distinctive — "NEWCO" on a plate is the single most
    /// informative thing about that machine — so treating it as weightless let
    /// an unknown brand's plate score 0.97 against a same-named row from a
    /// different manufacturer (codex-review, finding 1).
    private(set) var unknownTokenWeight: Double = 1
    /// Canonical manufacturer spellings, for the create-new guess.
    private(set) var manufacturers: [String] = []
    /// Token sets of every known manufacturer, for conflict detection.
    private(set) var manufacturerTokenSets: [(name: String, tokens: Set<String>)] = []
    /// Scanner accuracy, ticket 02: the repair of what the camera did to the
    /// words, built once with this catalog's vocabulary.
    private(set) var repair: MachineLabelRepair

    /// `isDictionaryWord` — an ordinary-English-word test (the app supplies
    /// UIKit's spell checker via `MachineLabelDictionary`). Without one the
    /// repair makes no edit-based brand repairs (`MachineLabelRepair`).
    init(
        models: [(id: UUID, manufacturer: String, modelName: String)],
        isDictionaryWord: ((String) -> Bool)? = nil
    ) {
        var documentFrequency: [String: Int] = [:]
        var tokenised: [(id: UUID, manufacturer: String, modelName: String,
                         tokens: [String], manufacturerTokens: [String],
                         nameTokens: [String])] = []
        tokenised.reserveCapacity(models.count)

        for model in models {
            let manufacturerTokens = MachineLabelText.tokens(model.manufacturer)
            let nameTokens = Array(Set(MachineLabelText.tokens(model.modelName))).sorted()
            let all = Array(Set(manufacturerTokens + nameTokens)).sorted()
            for token in all { documentFrequency[token, default: 0] += 1 }
            tokenised.append((model.id, model.manufacturer, model.modelName,
                              all, manufacturerTokens, nameTokens))
        }

        let count = Double(max(models.count, 1))
        weights = documentFrequency.mapValues { frequency in
            log(1 + count / (1 + Double(frequency)))
        }
        // A word seen nowhere in the catalog behaves like a word seen once.
        unknownTokenWeight = log(1 + count / 2)

        let weightTable = weights
        let weightOf: (String) -> Double = { weightTable[$0] ?? 0 }
        entries = tokenised.map { row in
            // A name that is nothing but the brand ("Cybex" by "Cybex") would
            // have no denominator; fall back to everything the row says.
            let nameTokens = row.nameTokens.isEmpty ? row.tokens : row.nameTokens
            return Entry(
                id: row.id, manufacturer: row.manufacturer, modelName: row.modelName,
                // Deterministic order regardless of hash seed: weight, then
                // the token itself (codex-review, finding 7).
                tokens: row.tokens.sorted {
                    weightOf($0) == weightOf($1) ? $0 < $1 : weightOf($0) > weightOf($1)
                },
                manufacturerTokens: row.manufacturerTokens,
                nameTokens: Set(nameTokens),
                nameWeight: nameTokens.reduce(0) { $0 + weightOf($1) })
        }
        manufacturers = Array(Set(models.map(\.manufacturer)))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted()
        manufacturerTokenSets = manufacturers.compactMap { name in
            let tokens = Set(MachineLabelText.readingTokens(name))
            return tokens.isEmpty ? nil : (name, tokens)
        }
        // Which pairs of words sit together in one row's name — the split
        // repair's corroboration (`dip` + `chin` ← Select Assist Dip Chin).
        var pairs: Set<String> = []
        for row in tokenised {
            let names = row.nameTokens
            for a in names { for b in names where a < b { pairs.insert(a + " " + b) } }
        }
        repair = MachineLabelRepair(
            manufacturers: manufacturers,
            isKnown: { weightTable[$0] != nil },
            shareARow: { a, b in pairs.contains(a < b ? a + " " + b : b + " " + a) },
            isDictionaryWord: isDictionaryWord)
    }

    /// The reading with corrupted brand tokens and glued words repaired
    /// (`MachineLabelRepair`). `rank` applies this itself; the sheet uses it
    /// for the create-new guesses so a plate read as `SCYBEX` proposes
    /// `Cybex`. The text the user is shown as read stays the raw reading.
    func repaired(_ reading: LabelReading) -> LabelReading {
        repair.repaired(reading)
    }

    /// IDF weight, with unseen words treated as maximally distinctive.
    func weight(_ token: String) -> Double { weights[token] ?? unknownTokenWeight }

    /// Whether the catalog knows this word at all.
    func isKnown(_ token: String) -> Bool { weights[token] != nil }

    /// Manufacturers the plate names outright.
    func manufacturersNamed(in readingTokens: Set<String>) -> Set<String> {
        Set(manufacturerTokenSets
            .filter { $0.tokens.isSubset(of: readingTokens) }
            .map(\.name))
    }
}

enum CatalogMatcher {

    /// At or above this a row *may* be preselected — see `preselection`, which
    /// also demands a named manufacturer and a clear margin. Still shown, still
    /// confirmed by a tap (D33), never applied behind the user's back.
    static let confidentScore = 0.85
    /// Below this, the sheet leads with "create new": the catalog probably does
    /// not have this machine, and offering a 30%-sure row as the answer invites
    /// the wrong tap.
    static let createNewBelow = 0.35
    /// Weak candidates are still worth listing; noise is not.
    static let candidateFloor = 0.25
    /// How far the top row must stand clear of the runner-up to be preselected.
    /// A photograph taken between two stations, or a short catalog name that is
    /// a prefix of a longer one, produces near-ties — and a near-tie resolved
    /// by lexical order is a coin flip on the user's history.
    static let preselectionMargin = 0.08

    /// Candidates for `reading`, best first. Deterministic: ties break by score,
    /// then display name, then id, so the same photo always ranks the same way.
    static func rank(
        _ rawReading: LabelReading, in index: CatalogMatchIndex, limit: Int = 5
    ) -> [CatalogMatch] {
        // Ticket 02 of the scanner-accuracy work: the camera's `SCYBEX` and
        // `DIPICHIN` become `cybex` and `dip chin` before anything is scored.
        let reading = index.repaired(rawReading)
        // Matching sees the whole plate — a code in a line that reads as
        // furniture ("VSL019BP") is still evidence. *Explanation* is measured
        // only over the lines that claim to name the machine, so warnings and
        // load ratings cannot make every row look unexplanatory.
        let allTokens = Set(MachineLabelText.readingTokens(reading.text))
        guard !allTokens.isEmpty else { return [] }
        let evidenceTokens = Set(reading.lines
            .filter { !MachineLabelText.isJunkLine($0.text) }
            .flatMap { MachineLabelText.readingTokens($0.text) })
        let evidence = evidenceTokens.isEmpty ? allTokens : evidenceTokens
        // Summed in sorted order: floating-point addition is not associative,
        // and a `Set`'s iteration order changes with the hash seed, so an
        // unsorted reduction made scores differ in the last bit between runs
        // (codex-review, finding 7).
        let evidenceWeight = evidence.sorted().reduce(0.0) { $0 + index.weight($1) }
        let namedManufacturers = index.manufacturersNamed(in: allTokens)

        var matches: [CatalogMatch] = []
        for entry in index.entries where entry.nameWeight > 0 {
            guard let match = score(
                entry, allTokens: allTokens, evidence: evidence,
                evidenceWeight: evidenceWeight,
                namedManufacturers: namedManufacturers, index: index)
            else { continue }
            matches.append(match)
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.displayName != rhs.displayName { return lhs.displayName < rhs.displayName }
                return lhs.modelID.uuidString < rhs.modelID.uuidString
            }
            .prefix(limit)
            .map { $0 }
    }

    /// The row to preselect, or nil when the app should not put its thumb on
    /// the scale (D33). Three conditions, each closing a way to be confidently
    /// wrong: a strong score, a manufacturer the plate actually names, and
    /// daylight between first and second.
    static func preselection(from matches: [CatalogMatch]) -> CatalogMatch? {
        guard let best = matches.first, best.score >= confidentScore else { return nil }
        guard best.manufacturerMatched, !best.manufacturerConflicts else { return nil }
        if matches.count > 1, best.score - matches[1].score < preselectionMargin { return nil }
        return best
    }

    // A "prefix sibling" exception to the margin was tried here (scanner
    // accuracy, ticket 02): a plate reading `ISO-LATERAL LOW ROW` perfectly
    // ties plain `Iso-Lateral Row` inside the margin, and the specific row is
    // plainly right. Two cuts of the exception were cross-reviewed and both
    // leaked: any test of "the distinguishing word is part of the name"
    // built on line layout let a stray `FIXED PULL` or `SEATED LEG` on the
    // plate preselect the longer sibling of a machine that never said it
    // (codex-review-02, 02b). It bought one preselection on the corpus. D33
    // is the rule: a near-tie is an ambiguity, and the user's tap resolves it.

    /// Whether the sheet should lead with creating a model instead.
    ///
    /// A low score is one reason; the other is a plate that says something
    /// distinctive no candidate can account for. `NEWCO PENDULUM SQUAT` scores
    /// 0.76 against Nautilus's pendulum squat — every word of that row's name
    /// is on the plate — but the plate also says NEWCO, and no catalog row
    /// explains that. The machine is almost certainly not in the catalog, which
    /// is precisely when create-new should lead (codex-review-2, finding 3).
    static func suggestsCreatingNew(_ matches: [CatalogMatch]) -> Bool {
        guard let best = matches.first else { return true }
        if best.score < createNewBelow { return true }
        // Named someone else's brand: at best this row resembles the machine.
        if best.manufacturerConflicts { return true }
        // The plate says things the best candidate cannot account for. True of
        // `NEWCO PENDULUM SQUAT` (an unlisted maker) and of
        // `ATLANTIS STRENGTH / PLATE LOADED BELT SQUAT` (a listed maker whose
        // belt squat the catalog does not carry) — in both cases the honest
        // lead is "add this as a new model", with the near misses still listed.
        return best.explanation < unexplainedEvidenceLimit
    }

    /// Below this share of the plate explained, an unbranded-to-us reading is
    /// treated as hardware the catalog does not have.
    static let unexplainedEvidenceLimit = 0.8

    // MARK: - Scoring one row

    private static func score(
        _ entry: CatalogMatchIndex.Entry,
        allTokens: Set<String>,
        evidence: Set<String>,
        evidenceWeight: Double,
        namedManufacturers: Set<String>,
        index: CatalogMatchIndex
    ) -> CatalogMatch? {
        // One reading word may serve as evidence for exactly one catalog word.
        // Without this, "abduction" covered both `Hip Abduction` and — through
        // a one-edit slip — `Hip Adduction`, tying two distinct machines at
        // 1.00 (codex-review, finding 4).
        var consumed: Set<String> = []
        var covered = 0.0
        var explained = 0.0
        var unmatched: [String] = []

        // Exact matches first, across *all* of the row's tokens, before any
        // fuzzy claim is staked. Interleaving the two let a high-weight token
        // fuzzily consume a word that a later token would have matched exactly
        // (codex-review-2, finding 5).
        for token in entry.tokens where !consumed.contains(token) {
            guard allTokens.contains(token) else {
                unmatched.append(token)
                continue
            }
            consumed.insert(token)
            let weight = index.weight(token)
            if entry.nameTokens.contains(token) { covered += weight }
            if evidence.contains(token) { explained += weight }
        }

        for token in unmatched {  // weight-descending, so distinctive first
            let weight = index.weight(token)
            guard let near = nearestToken(
                to: token, in: allTokens, excluding: consumed, weight: weight, index: index)
            else { continue }
            consumed.insert(near)
            // Fuzzy evidence is discounted: it is a guess about what the camera
            // saw, not something it read.
            if entry.nameTokens.contains(token) { covered += weight * 0.85 }
            if evidence.contains(near) { explained += index.weight(near) * 0.85 }
        }

        let coverage = covered / entry.nameWeight
        guard coverage > 0 else { return nil }
        // What share of what the plate *claims about this machine* the row
        // accounts for. This is what stops a short generic row ("Back
        // Extension") from fully explaining a plate that also said "Insignia
        // Series", and what makes an unknown brand cost a row real points.
        let explanation = evidenceWeight > 0 ? min(1, explained / evidenceWeight) : 0

        let manufacturerMatched = !entry.manufacturerTokens.isEmpty
            && Set(entry.manufacturerTokens.filter { $0.count > 1 }).isSubset(of: allTokens)
        // Strictly: *any* other known brand named on the plate conflicts, even
        // alongside this row's own. D33 says "and no other known manufacturer",
        // and a plate naming two makers is a photo of two machines
        // (codex-review-2, finding 2).
        let conflicts = namedManufacturers.contains { $0 != entry.manufacturer }

        var score = coverage * 0.60 + explanation * 0.30 + (manufacturerMatched ? 0.10 : 0)
        if conflicts {
            // The plate names someone else's brand. Whatever the words say,
            // this is not that machine — it is at best a hint about what the
            // machine resembles.
            score *= 0.6
        }
        score = min(1, score)
        guard score >= candidateFloor else { return nil }
        return CatalogMatch(
            modelID: entry.id, manufacturer: entry.manufacturer,
            modelName: entry.modelName, score: score,
            manufacturerMatched: manufacturerMatched,
            manufacturerConflicts: conflicts,
            explanation: explanation)
    }

    // MARK: - Fuzzy token matching

    /// A reading token within OCR-slip distance of `token`, or nil.
    ///
    /// Refuses to pair two words the catalog both knows: "adduction" is not a
    /// misreading of "abduction", it is a different machine. Only worth trying
    /// for tokens that carry weight — a near-miss on "series" buys nothing.
    private static func nearestToken(
        to token: String, in candidates: Set<String>, excluding consumed: Set<String>,
        weight: Double, index: CatalogMatchIndex
    ) -> String? {
        guard weight >= 1.5, token.count >= 4 else { return nil }
        let allowed = token.count >= 7 ? 2 : 1
        var best: (token: String, distance: Int)?
        // Sorted so the choice cannot depend on the hash seed
        // (codex-review, finding 7).
        for candidate in candidates.sorted() where !consumed.contains(candidate) {
            guard abs(candidate.count - token.count) <= allowed else { continue }
            // Both words are in the catalog's vocabulary: they are two real
            // names, not one name misread.
            guard !index.isKnown(candidate) || candidate == token else { continue }
            // OCR mangles the middle of a word far more often than both ends.
            guard candidate.first == token.first || candidate.last == token.last else { continue }
            guard let distance = editDistance(token, candidate, limit: allowed) else { continue }
            if distance < (best?.distance ?? Int.max) {
                best = (candidate, distance)
            }
        }
        return best?.token
    }

    /// Levenshtein distance, abandoned as soon as it exceeds `limit` (which is
    /// what makes it cheap enough to run against a 1877-row catalog inline).
    static func editDistance(_ lhs: String, _ rhs: String, limit: Int) -> Int? {
        if lhs == rhs { return 0 }
        let left = Array(lhs), right = Array(rhs)
        if abs(left.count - right.count) > limit { return nil }

        var previous = Array(0...right.count)
        var current = [Int](repeating: 0, count: right.count + 1)
        for i in 1...left.count {
            current[0] = i
            var rowBest = current[0]
            for j in 1...right.count {
                let substitution = previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1)
                current[j] = min(substitution, previous[j] + 1, current[j - 1] + 1)
                rowBest = min(rowBest, current[j])
            }
            if rowBest > limit { return nil }
            swap(&previous, &current)
        }
        let distance = previous[right.count]
        return distance <= limit ? distance : nil
    }
}
