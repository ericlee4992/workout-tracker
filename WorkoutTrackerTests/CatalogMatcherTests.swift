import Foundation
import Testing

@testable import WorkoutTracker

// Photo machine capture, ticket 01 — the matcher, which is the part that can
// be wrong in a way that costs the user something. A missed match costs a few
// taps; a confident wrong match attaches the user's sets to another machine's
// UUID and splits their history (D23), so several of these tests are about
// *refusing* to answer.

struct CatalogMatcherTests {

    // MARK: - Fixtures

    /// A small catalog with the properties that matter: repeated words across
    /// rows ("series", "chest", "press") so IDF has something to do, two rows
    /// that differ by one distinctive word, and two manufacturers.
    private func makeIndex() -> CatalogMatchIndex {
        CatalogMatchIndex(models: catalog.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        })
    }

    private struct Row {
        let id: UUID
        let manufacturer: String
        let modelName: String
    }

    private let catalog: [Row] = [
        Row(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            manufacturer: "Life Fitness", modelName: "Insignia Series Chest Press"),
        Row(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            manufacturer: "Life Fitness", modelName: "Insignia Series Shoulder Press"),
        Row(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            manufacturer: "Life Fitness", modelName: "Axiom Series Chest Press"),
        Row(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            manufacturer: "Hammer Strength", modelName: "Select Seated Leg Press"),
        Row(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            manufacturer: "Precor", modelName: "Vitality Series Seated Row VSL019BP"),
        Row(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            manufacturer: "Cybex", modelName: "Eagle NX Leg Extension"),
    ]

    private var insigniaChestPress: UUID { catalog[0].id }
    private var insigniaShoulderPress: UUID { catalog[1].id }
    private var hammerLegPress: UUID { catalog[3].id }
    private var precorRow: UUID { catalog[4].id }

    private func rank(_ lines: [String]) -> [CatalogMatch] {
        CatalogMatcher.rank(LabelReading.lines(lines), in: makeIndex())
    }

    /// What the sheet would preselect, which is the only thing that can be
    /// confidently *wrong* (D33).
    private func preselected(_ lines: [String]) -> CatalogMatch? {
        CatalogMatcher.preselection(from: rank(lines))
    }

    // MARK: - Finding the right row

    @Test func readsAPlainNamePlate() throws {
        let matches = rank(["LIFE FITNESS", "Insignia Series", "Chest Press"])
        let best = try #require(matches.first)
        #expect(best.modelID == insigniaChestPress)
        #expect(preselected(["LIFE FITNESS", "Insignia Series", "Chest Press"])?.modelID
            == insigniaChestPress)
    }

    /// Vision returns lines in reading order, but a plate photographed at an
    /// angle can come back out of order, and the brand is sometimes below.
    @Test func lineOrderDoesNotMatter() throws {
        let forward = rank(["LIFE FITNESS", "Insignia Series", "Chest Press"])
        let scrambled = rank(["Chest Press", "LIFE FITNESS", "Insignia Series"])
        #expect(forward.first?.modelID == scrambled.first?.modelID)
        #expect(forward.first?.score == scrambled.first?.score)
    }

    /// The failures OCR actually makes: a swapped letter, an `I` read as `l`,
    /// an `M` read as `H`.
    @Test func singleCharacterMisreadsStillFindTheRow() throws {
        for misread in ["Insigma Series Chest Press",
                        "lnsignia Series Chest Press",
                        "INSIGNIA SERIES CHEST PBESS"] {
            let best = try #require(rank(["LIFE FITNESS", misread]).first)
            #expect(best.modelID == insigniaChestPress, "failed on \(misread)")
        }
        let hammer = try #require(rank(["HAMIER STRENGTH", "Select Seated Leg Press"]).first)
        #expect(hammer.modelID == hammerLegPress)
    }

    @Test func plateFurnitureDoesNotSinkTheMatch() throws {
        let best = try #require(rank([
            "LIFE FITNESS",
            "Insignia Series Chest Press",
            "MAX 300 LB / 136 KG",
            "READ MANUAL BEFORE USE",
            "SN 84213-9920",
        ]).first)
        #expect(best.modelID == insigniaChestPress)
        #expect(
            preselected([
                "LIFE FITNESS", "Insignia Series Chest Press", "MAX 300 LB / 136 KG",
                "READ MANUAL BEFORE USE", "SN 84213-9920",
            ])?.modelID == insigniaChestPress,
            "warnings must not cost the row its preselection")
    }

    /// A model code on the plate is evidence, not noise — Precor's own names
    /// carry them.
    @Test func aModelCodeIsEvidence() throws {
        let best = try #require(rank(["VSL019BP"]).first)
        #expect(best.modelID == precorRow)
    }

    // MARK: - Ranking, not just picking

    @Test func siblingModelsRankInTheRightOrderAndBothAppear() throws {
        let matches = rank(["LIFE FITNESS", "Insignia Series", "Shoulder Press"])
        #expect(matches.first?.modelID == insigniaShoulderPress)
        #expect(
            matches.contains { $0.modelID == insigniaChestPress },
            "the sibling belongs in the list — the plate may have been misread")
        let shoulder = try #require(matches.first(where: { $0.modelID == insigniaShoulderPress }))
        let chest = try #require(matches.first(where: { $0.modelID == insigniaChestPress }))
        #expect(shoulder.score > chest.score)
    }

    @Test func rankingIsDeterministicAndBounded() throws {
        let index = makeIndex()
        let reading = LabelReading.lines(["LIFE FITNESS", "Series Press"])
        let first = CatalogMatcher.rank(reading, in: index, limit: 3)
        let second = CatalogMatcher.rank(reading, in: index, limit: 3)
        #expect(first == second)
        #expect(first.count <= 3)
        #expect(first.map(\.score) == first.map(\.score).sorted(by: >))
    }

    // MARK: - Refusing to answer

    /// Hardware the catalog does not have must not borrow a confident answer
    /// from a row that happens to share a common word.
    @Test func unknownHardwareScoresBelowTheCreateNewFloor() throws {
        let matches = rank(["ATLANTIS STRENGTH", "Plate Loaded Belt Squat", "Model C-227"])
        #expect(CatalogMatcher.suggestsCreatingNew(matches))
        #expect(CatalogMatcher.preselection(from: matches) == nil)
    }

    /// IDF doing its job: words shared by half the catalog identify nothing.
    @Test func commonWordsAloneAreNotAMatch() throws {
        let matches = rank(["SERIES", "PRESS"])
        #expect(CatalogMatcher.preselection(from: matches) == nil)
    }

    @Test func anEmptyOrUnreadableReadingRanksNothing() {
        #expect(rank([]).isEmpty)
        #expect(rank(["", "  "]).isEmpty)
        // Lone letters are noise; a lone digit is not (it is the whole
        // difference between "4 Station" and "5 Station"), but on its own it
        // matches nothing in this catalog.
        #expect(rank(["I", "®"]).isEmpty)
    }

    // MARK: - Edit distance

    @Test func editDistanceIsBoundedAndCorrect() {
        #expect(CatalogMatcher.editDistance("insignia", "insignia", limit: 2) == 0)
        // "insignia" → "insigma" is two edits (n→m, drop an i), which is why
        // the long-token allowance is 2 rather than 1.
        #expect(CatalogMatcher.editDistance("insignia", "insigma", limit: 2) == 2)
        #expect(CatalogMatcher.editDistance("insignia", "insigma", limit: 1) == nil)
        #expect(CatalogMatcher.editDistance("insignia", "lnsignia", limit: 2) == 1)
        // Beyond the limit it reports nothing rather than a large number, so
        // callers cannot accidentally treat "far apart" as "matched".
        #expect(CatalogMatcher.editDistance("insignia", "shoulder", limit: 2) == nil)
        #expect(CatalogMatcher.editDistance("press", "pressing", limit: 2) == nil)
    }

    // MARK: - Naming a new model (D35)

    @Test func manufacturerGuessUsesTheCatalogSpelling() {
        let index = makeIndex()
        let reading = LabelReading.lines(["LIFE FITNESS", "Some Unlisted Press"])
        #expect(
            MachineLabelText.guessManufacturer(
                in: reading, knownManufacturers: index.manufacturers) == "Life Fitness")
    }

    @Test func manufacturerGuessPrefersTheLongerBrandName() {
        let known = ["Hammer", "Hammer Strength"]
        let reading = LabelReading.lines(["HAMMER STRENGTH", "Iso-Lateral Row"])
        #expect(
            MachineLabelText.guessManufacturer(in: reading, knownManufacturers: known)
                == "Hammer Strength")
    }

    @Test func anUnknownBrandFallsBackToTheTopLine() {
        let reading = LabelReading.lines(["ATLANTIS", "Belt Squat", "MAX 400 LB"])
        #expect(
            MachineLabelText.guessManufacturer(in: reading, knownManufacturers: ["Cybex"])
                == "ATLANTIS")
    }

    @Test func modelNameGuessSkipsJunkAndTheBrandItself() {
        let reading = LabelReading(lines: [
            LabelReading.Line(text: "ATLANTIS", confidence: 1, heightFraction: 0.05),
            LabelReading.Line(text: "Belt Squat C-227", confidence: 1, heightFraction: 0.12),
            LabelReading.Line(text: "MAX 400 LB", confidence: 1, heightFraction: 0.04),
            LabelReading.Line(text: "READ MANUAL BEFORE USE", confidence: 1, heightFraction: 0.03),
        ])
        #expect(
            MachineLabelText.guessModelName(in: reading, manufacturer: "ATLANTIS")
                == "Belt Squat C-227")
    }

    @Test func junkLineDetection() {
        #expect(MachineLabelText.isJunkLine("MAX 300 LB"))
        #expect(MachineLabelText.isJunkLine("READ MANUAL BEFORE USE"))
        #expect(MachineLabelText.isJunkLine("www.lifefitness.com"))
        #expect(MachineLabelText.isJunkLine("84213-9920"))
        #expect(MachineLabelText.isJunkLine("   "))
        #expect(!MachineLabelText.isJunkLine("Insignia Series Chest Press"))
        #expect(!MachineLabelText.isJunkLine("Eagle NX Leg Extension"))
    }

    // MARK: - Normalisation

    @Test func normalisationFlattensPlateTypography() {
        #expect(MachineLabelText.normalized("LIFE FITNESS®") == "life fitness")
        #expect(MachineLabelText.normalized("Hammer  Strength™") == "hammer strength")
        #expect(MachineLabelText.normalized("Iso-Lateral / Row") == "iso lateral row")
        // Catalog side keeps everything — `4 Station` and `R-6` are identities.
        #expect(MachineLabelText.tokens("A Chest Press 2") == ["a", "chest", "press", "2"])
        // The photo side follows the same rule: dropping lone letters there
        // dissolved `T-Bar` and `D.Y.` and reopened the subset defect.
        #expect(MachineLabelText.readingTokens("A Chest Press 2") == ["a", "chest", "press", "2"])
        #expect(MachineLabelText.readingTokens("ISO-LATERAL T-BAR ROW")
            == ["iso", "lateral", "t", "bar", "row"])
        #expect(MachineLabelText.readingTokens("NAUTILUS 5 STATION") == ["nautilus", "5", "station"])
    }
}
