import Foundation
import Testing

@testable import WorkoutTracker

/// Scanner accuracy, ticket 02 — the repair of corrupted brand tokens and
/// glued words. Every input below is a real misread from the plate corpus
/// (`.scratch/scanner-accuracy/reports/`), which is also the misread the
/// user reported from the gym.
struct MachineLabelRepairTests {

    private func index() throws -> CatalogMatchIndex {
        CatalogMatchIndex(models: try SeedCatalog.bundled().equipmentModels.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        })
    }

    private func repairedTokens(_ text: String) throws -> [String] {
        MachineLabelText.readingTokens(try index().repair.repairedText(text))
    }

    // MARK: Brand tokens

    @Test func aStrayCharacterAroundAnExactBrandTokenIsStripped() throws {
        #expect(try repairedTokens("SCYBEX") == ["cybex"], "the swoosh read as S")
        #expect(try repairedTokens("OCYBEX") == ["cybex"], "the swoosh read as O")
        #expect(try repairedTokens("CYBEX®") == ["cybex"], "punctuation is already gone; nothing to strip")
    }

    @Test func oneOrTwoEditsFromABrandTokenAreRepaired() throws {
        #expect(try repairedTokens("HOISI") == ["hoist"])
        #expect(try repairedTokens("LAMMED STRENGTH") == ["hammer", "strength"])
        #expect(try repairedTokens("YAMMER RENGTH") == ["hammer", "strength"])
        #expect(try repairedTokens("HAMMER STRENCTH") == ["hammer", "strength"])
    }

    @Test func aScriptLogoReadAsOneWordIsSplitBackIntoTheBrand() throws {
        #expect(try repairedTokens("LieFitness") == ["life", "fitness"])
        #expect(try repairedTokens("LifeFilness") == ["life", "fitness"])
        #expect(try repairedTokens("LifeFiness") == ["life", "fitness"])
    }

    @Test func refusals() throws {
        // A word the catalog knows is never a misread brand.
        #expect(try repairedTokens("ROW PRESS") == ["row", "press"])
        // Too short to be safe.
        #expect(try repairedTokens("WUH") == ["wuh"])
        // Nowhere near any brand: left alone, and the matcher treats it as unknown.
        #expect(try repairedTokens("BAEHA") == ["baeha"])
        #expect(try repairedTokens("LiTTes") == ["littes"])
        // Cyrillic junk from a logo is not a brand either.
        #expect(try repairedTokens("OLУBЕN").count == 1)
    }

    @Test func anAmbiguousRepairIsLeftAlone() {
        // Two invented brands one edit apart in each direction from the token.
        let repair = MachineLabelRepair(manufacturers: ["Zorbex", "Zorbax"], isKnown: { _ in false })
        #expect(repair.repairedBrandToken("zorbux") == nil, "equally near two brands: ambiguous")
        #expect(repair.repairedBrandToken("zorbex") == "zorbex", "exact still passes")
    }

    // MARK: Glued words

    @Test func aSlashReadAsIIsSplitIntoTheTwoKnownWords() throws {
        #expect(try repairedTokens("ASSIST DIPICHIN") == ["assist", "dip", "chin"])
        #expect(try repairedTokens("DIPCHIN") == ["dip", "chin"], "and with no separator at all")
    }

    @Test func aSplitNeedsBothHalvesToBeRealWordsAndExactlyOneWayToCut() {
        let repair = MachineLabelRepair(
            manufacturers: [], isKnown: { ["dip", "chin", "leg", "press", "ext"].contains($0) })
        #expect(repair.split("dipichin") == ["dip", "chin"])
        #expect(repair.split("dipxchin") == nil, "x is not a character a slash becomes")
        #expect(repair.split("dipizzz") == nil, "the right half is not a word")
        #expect(repair.split("legpressext") == nil, "three words, not two: left alone")
        #expect(repair.split("ab") == nil)
    }

    // MARK: What the user sees prefilled

    /// Only the repaired words change; everything else keeps its case and
    /// punctuation, because the create-new sheet prefills from this.
    @Test func untouchedWordsKeepTheirCaseAndPunctuation() throws {
        let repair = try index().repair
        #expect(repair.repairedText("Insignia Series Chest Press") == "Insignia Series Chest Press")
        #expect(repair.repairedText("Iso-Lateral Row & Half") == "Iso-Lateral Row & Half")
        #expect(repair.repairedText("SCYBEX") == "CYBEX", "a repaired word takes the case of the word it replaces")
        #expect(repair.repairedText("LieFitness") == "Life Fitness")
        #expect(repair.repairedText("Assist DIPICHIN") == "Assist DIP CHIN")
        #expect(repair.repairedText("lammed strength") == "hammer strength")
    }

    // MARK: Invariants

    /// Repair must never touch a token of any catalog row's own name — the
    /// self-recognition invariant (`everySampledCatalogRowRecognisesItself`)
    /// depends on a row's plate reading exactly as the row.
    @Test func noCatalogRowsOwnTokensAreEverRepaired() throws {
        let catalog = try SeedCatalog.bundled().equipmentModels
        let repair = try index().repair
        var touched: [String] = []
        for model in catalog {
            for token in MachineLabelText.tokens(model.manufacturer + " " + model.modelName) {
                if repair.repair(token) != [token] { touched.append(token) }
            }
        }
        #expect(touched.isEmpty, "repaired catalog tokens: \(Set(touched).sorted().prefix(20))")
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

    @Test func theCreateNewGuessUsesTheRepairedBrand() throws {
        let idx = try index()
        let reading = LabelReading.lines(["SCYBEX", "PLATE LOADED SQUAT PRESS"])
        let guess = MachineLabelText.guessManufacturer(in: idx.repaired(reading), knownManufacturers: idx.manufacturers)
        #expect(guess == "Cybex")
    }
}
