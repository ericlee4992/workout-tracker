import Foundation
import Testing

@testable import WorkoutTracker

/// Scanner accuracy, ticket 02 — the repair of corrupted brand tokens and
/// glued words. Every positive input below is a real misread from the plate
/// corpus (`.scratch/scanner-accuracy/reports/`), which is also the misread
/// the user reported from the gym. Every NEGATIVE input is a way the first
/// cut manufactured a brand or mangled a word (codex-review-02).
@MainActor
struct MachineLabelRepairTests {

    /// The index as the app builds it: the shipped catalog plus UIKit's
    /// spell checker as the English-word test.
    private func index() throws -> CatalogMatchIndex {
        CatalogMatchIndex(
            models: try SeedCatalog.bundled().equipmentModels.map {
                (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
            },
            isDictionaryWord: MachineLabelDictionary.closure)
    }

    /// The reading's lines after repair, as token arrays.
    private func repairedLines(_ lines: [String]) throws -> [[String]] {
        try index().repaired(LabelReading.lines(lines)).lines.map { MachineLabelText.readingTokens($0.text) }
    }

    // MARK: Brand lines — the corpus cases

    @Test func aLogoReadAsALoneCorruptedWordIsRepaired() throws {
        #expect(try repairedLines(["SCYBEX"]) == [["cybex"]], "the swoosh read as S")
        #expect(try repairedLines(["OCYBEX"]) == [["cybex"]], "the swoosh read as O")
        #expect(try repairedLines(["HOISI"]) == [["hoist"]])
        // `LAMMED STRENGTH` and `YAMMER RENGTH` (embossed badges) stay as
        // read: "lammed" and "yammer" are English words to the spell checker,
        // and the dictionary refusal outranks the corpus case (they are
        // brand-only badges; nothing to preselect either way).
        #expect(try repairedLines(["LAMMED", "STRENGTH"]) == [["lammed"], ["strength"]])
        #expect(try repairedLines(["HAMMER STRENCTH"]) == [["hammer", "strength"]])
        #expect(try repairedLines(["HAMMER", "STRENCTH"]) == [["hammer"], ["strength"]], "the brand split over two lines")
        #expect(try repairedLines(["YAMMER RENGTH"]) == [["yammer", "rength"]])
        // A non-word at two edits IS repaired when the other word corroborates.
        #expect(try repairedLines(["HAMMER STRENCTH"]) == [["hammer", "strength"]])
        #expect(try repairedLines(["HAMMR STREGTH"]) == [["hammer", "strength"]], "two non-words, one edit each")
    }

    @Test func aScriptLogoReadAsOneWordIsSplitBackIntoTheBrand() throws {
        #expect(try repairedLines(["LieFitness"]) == [["life", "fitness"]])
        #expect(try repairedLines(["LifeFilness"]) == [["life", "fitness"]])
        #expect(try repairedLines(["LifeFiness"]) == [["life", "fitness"]])
    }

    // MARK: Brand lines — what must NOT become a brand (codex-review-02 #1)

    @Test func prosePlateTextNeverManufacturesABrand() throws {
        // The critical finding: a near-brand word inside a model line. The
        // repair only ever acts on a line that is nothing but the brand.
        #expect(try repairedLines(["MOIST CHEST PRESS RS-2301"]) == [["moist", "chest", "press", "rs", "2301"]])
        #expect(try repairedLines(["PRICE FITNESS"]) == [["price", "fitness"]], "not PRIME Fitness: two brands' tokens are not one brand")
        #expect(try repairedLines(["FITNESS LINE"]) == [["fitness", "line"]], "order matters: not Life Fitness")
        #expect(try repairedLines(["HAMMER STRENGTH ISO-LATERAL ROW"]) == [["hammer", "strength", "iso", "lateral", "row"]], "already exact; untouched")
    }

    @Test func aLoneNearBrandWordIsRepairedOnlyWithinTheTightBand() throws {
        // Two edits need a long token or a corroborating second word.
        #expect(try repairedLines(["RECORD"]) == [["record"]], "not Precor")
        #expect(try repairedLines(["METRIC"]) == [["metric"]], "not Matrix")
        #expect(try repairedLines(["PRECUT"]) == [["precut"]])
        // A token longer than the brand is never shortened to it.
        #expect(try repairedLines(["START TRACK"]) == [["start", "track"]], "not Star Trac")
        #expect(try repairedLines(["HAMMERS"]) == [["hammers"]])
        #expect(try repairedLines(["HOISTS"]) == [["hoists"]])
        // Only a LEADING stray character is stripped.
        #expect(try repairedLines(["CYBEXS"]) == [["cybexs"]])
    }

    @Test func refusals() throws {
        #expect(try repairedLines(["ROW PRESS"]) == [["row", "press"]], "known words are never a misread brand")
        #expect(try repairedLines(["WUH"]) == [["wuh"]], "too short")
        #expect(try repairedLines(["BAEHA"]) == [["baeha"]], "nowhere near a brand")
        #expect(try repairedLines(["LiTTes"]) == [["littes"]])
        #expect(try repairedLines(["OLУBЕN"]).flatMap { $0 }.count == 1)
    }

    @Test func anAmbiguousRepairIsLeftAlone() {
        let repair = MachineLabelRepair(
            manufacturers: ["Zorbex", "Zorbax"], isKnown: { _ in false }, shareARow: { _, _ in false },
            isDictionaryWord: { _ in false })
        #expect(repair.repairedBrandLine(["zorbux"]) == nil, "equally near two brands: ambiguous")
        #expect(repair.repairedBrandLine(["zorbex"]) == nil, "exact needs no repair")
        #expect(repair.repairedBrandLine(["zorbez"]) == [["zorbex"]])
        // No dictionary at all: no edit repair, ever; the strip still works.
        let blind = MachineLabelRepair(manufacturers: ["Zorbex"], isKnown: { _ in false }, shareARow: { _, _ in false })
        #expect(blind.repairedBrandLine(["zorbez"]) == nil)
        #expect(blind.repairedBrandLine(["szorbex"]) == [["zorbex"]])
    }

    // MARK: Glued words

    @Test func aSlashReadAsIIsSplitIntoTheTwoWordsOfOneRowsName() throws {
        #expect(try repairedLines(["ASSIST DIPICHIN"]) == [["assist", "dip", "chin"]])
        #expect(try repairedLines(["HAMMER STRENGTH", "ASSIST DIPICHIN"]) == [["hammer", "strength"], ["assist", "dip", "chin"]])
    }

    @Test func realCompoundWordsAreNotSplitIntoCatalogWords() throws {
        // codex-review-02 #3: 350 dictionary words split into two catalog
        // words under the first cut. No separator, or halves that never share
        // a row's name, means no split.
        for word in ["AIRLIFT", "ARMCHAIR", "BACKGROUND", "COUNTERWEIGHT", "CROSSBAR", "FACEPLATE", "HANDGRIP", "LIGHTWEIGHT", "OVERRIDE", "PROFIT", "TRIPOD", "WITHSTAND", "DIPCHIN"] {
            #expect(try repairedLines([word]) == [[word.lowercased()]], Comment(rawValue: word))
        }
    }

    @Test func aSplitNeedsTheSeparatorBothHalvesKnownAndSharingARow() {
        let known: Set<String> = ["dip", "chin", "leg", "press", "ext", "air", "lift"]
        let repair = MachineLabelRepair(
            manufacturers: [], isKnown: { known.contains($0) },
            shareARow: { a, b in Set([a, b]) == ["dip", "chin"] || Set([a, b]) == ["leg", "press"] })
        #expect(repair.split("dipichin") == ["dip", "chin"])
        #expect(repair.split("diplchin") == ["dip", "chin"], "l is a slash too")
        #expect(repair.split("dipchin") == nil, "no separator character")
        #expect(repair.split("dipxchin") == nil, "x is not a character a slash becomes")
        #expect(repair.split("airilift") == nil, "known words that never share a row's name")
        #expect(repair.split("dipizzz") == nil)
        #expect(repair.split("ab") == nil)
    }

    // MARK: What the user sees prefilled

    /// Only the repaired run changes; every other character keeps its case,
    /// punctuation and spacing, because the create-new sheet prefills from
    /// this (codex-review-02 #5).
    @Test func untouchedCharactersArePreservedExactly() throws {
        let repair = try index().repair
        #expect(repair.repairedText("Insignia Series Chest Press") == "Insignia Series Chest Press")
        #expect(repair.repairedText("Iso-Lateral  Row & Half\t(PL)") == "Iso-Lateral  Row & Half\t(PL)", "double space and tab survive")
        #expect(repair.repairedText("SCYBEX") == "CYBEX", "a repaired word takes the case of the run it replaces")
        #expect(repair.repairedText("LieFitness") == "Life Fitness")
        #expect(repair.repairedText("Assist DIPICHIN") == "Assist DIP CHIN")
        #expect(repair.repairedText("HOISI") == "HOIST")
        #expect(repair.repairedText("HOISI-RS-2403") == "HOISI-RS-2403", "a line with a code is not a brand line; nothing changes")
    }

    // MARK: Invariants

    /// Repair must never touch a token of any catalog row's own name — the
    /// self-recognition invariant depends on a row's plate reading as the row.
    /// Each row is tried as ITS OWN LINE, which is the shape a name line has.
    @Test func noCatalogRowsOwnLineIsEverRepaired() throws {
        let catalog = try SeedCatalog.bundled().equipmentModels
        let repair = try index().repair
        var touched: [String] = []
        for model in catalog {
            for line in [model.manufacturer, model.modelName, model.manufacturer + " " + model.modelName] {
                let tokens = MachineLabelText.tokens(line)
                if repair.repairedTokens(tokens) != tokens.map { [$0] } { touched.append(line) }
            }
        }
        #expect(touched.isEmpty, "repaired catalog lines: \(touched.prefix(10))")
    }

    // MARK: Through the matcher

    @Test func aCorruptedBrandNoLongerBlocksPreselection() throws {
        let matches = CatalogMatcher.rank(
            LabelReading.lines(["HAMMER", "STRENCTH", "ISO-LATERAL", "ROW", "Start 12 lbs./5.4Kg."]),
            in: try index())
        let best = try #require(matches.first)
        #expect(best.modelName == "Iso-Lateral Row")
        #expect(best.manufacturerMatched, "STRENCTH repaired to strength: the plate names the brand")
    }

    @Test func aGluedNameReachesTheRow() throws {
        let matches = CatalogMatcher.rank(
            LabelReading.lines(["HAMMER STRENGTH", "ASSIST DIPICHIN"]), in: try index())
        let best = try #require(matches.first)
        #expect(best.modelName == "Select Assist Dip Chin")
        #expect(best.manufacturerMatched)
    }

    /// codex-review-02 #1, end to end: the plate never said Hoist, and the
    /// Hoist row must not be preselected.
    @Test func aNearBrandWordInProseDoesNotPreselectThatBrandsRow() throws {
        let matches = CatalogMatcher.rank(LabelReading.lines(["MOIST CHEST PRESS RS-2301"]), in: try index())
        #expect(matches.first?.manufacturerMatched != true)
        #expect(CatalogMatcher.preselection(from: matches) == nil)
    }

    @Test func theCreateNewGuessUsesTheRepairedBrand() throws {
        let idx = try index()
        let reading = LabelReading.lines(["SCYBEX", "PLATE LOADED SQUAT PRESS"])
        let guess = MachineLabelText.guessManufacturer(in: idx.repaired(reading), knownManufacturers: idx.manufacturers)
        #expect(guess == "Cybex")
    }
}
