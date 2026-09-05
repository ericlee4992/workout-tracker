import Foundation
import Testing

@testable import WorkoutTracker

// Photo machine capture — the negatives, replayed against the **shipped**
// 1877-row catalog rather than a six-row fixture.
//
// Every case here was found by the first Codex cross-review
// (`.scratch/photo-machine-capture/codex-review.md`), and every one of them
// preselected a confidently wrong catalog UUID before the fixes: a plate saying
// NEWCO matched Nautilus at 0.97, `NAUTILUS 5 STATION` tied 4/5/9 Station at
// 1.00, and a photo of a Hip Abduction machine also scored Hip Adduction at
// 1.00. That is the D23 history-splitting failure D33 exists to prevent, so
// these run against the real corpus where the sibling rows actually live.

struct CatalogMatcherAdversarialTests {

    private func realIndex() throws -> CatalogMatchIndex {
        CatalogMatchIndex(models: try SeedCatalog.bundled().equipmentModels.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        })
    }

    private func rank(_ lines: [String], in index: CatalogMatchIndex) -> [CatalogMatch] {
        CatalogMatcher.rank(LabelReading.lines(lines), in: index, limit: 8)
    }

    private func describe(_ matches: [CatalogMatch]) -> String {
        matches.prefix(3)
            .map { "\($0.displayName) \(String(format: "%.2f", $0.score))" }
            .joined(separator: " | ")
    }

    // MARK: - A brand the catalog does not know

    /// An unlisted manufacturer whose machine shares a generic name with a
    /// catalog row. "NEWCO" is the most informative word on that plate; before
    /// the fix it weighed nothing, and Nautilus Pendulum Squat scored 0.97.
    @Test func anUnknownBrandDoesNotBorrowAnotherMakersRow() throws {
        let index = try realIndex()
        let matches = rank(["NEWCO", "PENDULUM SQUAT"], in: index)
        #expect(
            CatalogMatcher.preselection(from: matches) == nil,
            "preselected on an unknown brand: \(describe(matches))")
    }

    /// A brand the catalog *does* know, on a machine it does not list under
    /// that brand. Nothing may be preselected, and the row that does exist
    /// under the named brand must not be beaten by another maker's row.
    @Test func aKnownBrandsMissingModelDoesNotPreselectARivalsRow() throws {
        let index = try realIndex()
        let matches = rank(["MATRIX", "PENDULUM SQUAT"], in: index)
        let preselected = CatalogMatcher.preselection(from: matches)
        #expect(
            preselected == nil || preselected?.manufacturer == "Matrix",
            "preselected a rival maker: \(describe(matches))")
        if let best = matches.first, best.manufacturer != "Matrix" {
            #expect(
                best.manufacturerConflicts,
                "a row whose brand the plate contradicts must be marked as conflicting")
        }
    }

    @Test func unlistedHardwareLeadsToCreateNew() throws {
        let index = try realIndex()
        let matches = rank(
            ["ATLANTIS STRENGTH", "PLATE LOADED BELT SQUAT", "C-227"], in: index)
        #expect(
            CatalogMatcher.preselection(from: matches) == nil,
            "preselected unlisted hardware: \(describe(matches))")
    }

    // MARK: - Identities that live in single characters

    /// `4 Station`, `5 Station`, `9 Station` are three different machines. A
    /// tokenizer that drops one-character tokens made them the same row.
    @Test func stationCountsAreNotInterchangeable() throws {
        let index = try realIndex()
        let matches = rank(["NAUTILUS", "5 STATION"], in: index)
        let best = try #require(matches.first)
        #expect(
            best.modelName.contains("5"),
            "the station count is the identity, got: \(describe(matches))")
        if let second = matches.dropFirst().first {
            #expect(
                best.score > second.score,
                "sibling station counts must not tie: \(describe(matches))")
        }
    }

    /// No two shipped rows may reduce to the same matcher representation — that
    /// would make one of them unreachable and the other a coin flip.
    @Test func noTwoCatalogRowsNormaliseToTheSameIdentity() throws {
        let catalog = try SeedCatalog.bundled()
        var seen: [String: String] = [:]
        var collisions: [String] = []
        for model in catalog.equipmentModels {
            let key = (MachineLabelText.tokens(model.manufacturer)
                + MachineLabelText.tokens(model.modelName))
                .sorted().joined(separator: " ")
            let name = "\(model.manufacturer) \(model.modelName)"
            if let existing = seen[key], existing != name {
                collisions.append("\(existing) ≡ \(name)")
            }
            seen[key] = name
        }
        #expect(collisions.isEmpty, "identical matcher identities: \(collisions.prefix(5))")
    }

    // MARK: - Ambiguity is not a winner

    /// A short generic row is a subset of a longer specific one. Both explain
    /// their own tokens fully; only the longer row explains the plate.
    @Test func aGenericRowDoesNotOutrankTheSpecificOneItIsContainedIn() throws {
        let index = try realIndex()
        let matches = rank(["LIFE FITNESS", "INSIGNIA SERIES BACK EXTENSION"], in: index)
        let best = try #require(matches.first)
        #expect(
            best.modelName.lowercased().contains("insignia"),
            "the specific row must win: \(describe(matches))")
        if let preselected = CatalogMatcher.preselection(from: matches) {
            #expect(preselected.modelName.lowercased().contains("insignia"))
        }
    }

    /// A photograph taken between two stations names two machines. Neither is
    /// the answer, and picking one is a coin flip on the user's history.
    @Test func aPhotoOfTwoMachinesPreselectsNeither() throws {
        let index = try realIndex()
        let matches = rank(
            ["LIFE FITNESS", "INSIGNIA SERIES CHEST PRESS", "INSIGNIA SERIES SHOULDER PRESS"],
            in: index)
        #expect(
            CatalogMatcher.preselection(from: matches) == nil,
            "picked one of two machines in frame: \(describe(matches))")
    }

    /// One recognised word may not be evidence for two different catalog words:
    /// "abduction" is not a misreading of "adduction", it is another machine.
    @Test func abductionIsNotEvidenceForAdduction() throws {
        let index = try realIndex()
        let matches = rank(["LIFE FITNESS", "INSIGNIA SERIES HIP ABDUCTION"], in: index)
        let best = try #require(matches.first)
        #expect(
            best.modelName.lowercased().contains("abduction"),
            "got: \(describe(matches))")
        // An adduction-only row must not tie the abduction row it is not.
        let adductionOnly = matches.first {
            let name = $0.modelName.lowercased()
            return name.contains("adduction") && !name.contains("abduction")
        }
        if let adductionOnly {
            #expect(
                best.score - adductionOnly.score >= CatalogMatcher.preselectionMargin,
                "abduction and adduction are too close: \(describe(matches))")
        }
    }

    /// Hyphenated and dotted model codes are identities too, and they survive
    /// normalisation as one-character tokens: `T-Bar` becomes `t bar`, `D.Y.`
    /// becomes `d y`. Dropping those on the photo side made a plate that said
    /// **Iso-Lateral T-Bar Row** preselect plain `Iso-Lateral Row`, which
    /// explained everything that was left — the subset defect, recreated from
    /// the other side (found in the round-2 review transcript).
    @Test func hyphenatedModelCodesAreNotDissolved() throws {
        let index = try realIndex()

        let tBar = rank(["HAMMER STRENGTH", "ISO-LATERAL T-BAR ROW"], in: index)
        #expect(
            CatalogMatcher.preselection(from: tBar)?.modelName == "Iso-Lateral T-Bar Row",
            "got: \(describe(tBar))")

        let dy = rank(["HAMMER STRENGTH", "ISO-LATERAL D.Y. ROW"], in: index)
        #expect(
            CatalogMatcher.preselection(from: dy)?.modelName == "Iso-Lateral D.Y. Row",
            "got: \(describe(dy))")

        // And the plain row still wins when the plate really is the plain row.
        let plain = rank(["HAMMER STRENGTH", "ISO-LATERAL ROW"], in: index)
        #expect(
            CatalogMatcher.preselection(from: plain)?.modelName == "Iso-Lateral Row",
            "got: \(describe(plain))")

        let rogue = rank(["ROGUE FITNESS", "R-6 POWER RACK"], in: index)
        #expect(
            CatalogMatcher.preselection(from: rogue)?.modelName == "R-6 Power Rack",
            "got: \(describe(rogue))")

        // A ratio in the name is identity too: 2:1 and 4:1 are different racks.
        let prime = rank(
            ["PRIME FITNESS", "PRODIGY HLP SELECTORIZED RACK 2:1"], in: index)
        let primeBest = try #require(prime.first)
        #expect(primeBest.modelName.contains("2:1"), "got: \(describe(prime))")
        let fourToOne = prime.first { $0.modelName.contains("4:1") }
        if let fourToOne {
            #expect(
                primeBest.score - fourToOne.score >= CatalogMatcher.preselectionMargin,
                "2:1 and 4:1 are too close: \(describe(prime))")
        }
    }

    /// Keeping one-character tokens means OCR noise can produce them too. A
    /// stray bracket edge read as `I` must not derail a plate that otherwise
    /// reads perfectly — weighting and the margin gate handle that, which is
    /// why the length filter was not the right tool.
    @Test func strayCharactersDoNotDerailAGoodReading() throws {
        let index = try realIndex()
        let matches = rank(
            ["I", "l", "LIFE FITNESS", "INSIGNIA SERIES CHEST PRESS"], in: index)
        #expect(
            CatalogMatcher.preselection(from: matches)?.modelName
                == "Insignia Series Chest Press",
            "got: \(describe(matches))")
    }

    /// Codes that end in a lone letter (`CMJ-6600-S`) and ordinary words that
    /// happen to be one letter (`Rack & A Half`) are identity too — 88 shipped
    /// names carry one (codex-review-2, finding 1).
    @Test func oneLetterComponentsOfRealNamesSurvive() throws {
        let index = try realIndex()

        let hoist = rank(["HOIST", "6 STATION - SINGLE POD CMJ-6600-S"], in: index)
        #expect(
            CatalogMatcher.preselection(from: hoist)?.modelName
                == "6 Station - Single Pod CMJ-6600-S",
            "got: \(describe(hoist))")

        // "Rack & A Half" and "Half Rack" are the same bag of words apart from
        // the `a`. The right row must still rank first; bag-of-words cannot
        // separate them confidently, so no preselection is the honest outcome.
        let sorinex = rank(["SORINEX", "BASE CAMP RACK & A HALF"], in: index)
        #expect(sorinex.first?.modelName == "Base Camp Rack & A Half", "got: \(describe(sorinex))")
        #expect(CatalogMatcher.preselection(from: sorinex) == nil, "got: \(describe(sorinex))")
    }

    /// Every shipped manufacturer and model line must read as a *name*, not as
    /// plate furniture. A substring junk rule called 73 of them junk — `min`
    /// inside `Abdominal`, `rev` inside `Reverse` — which drops the line from
    /// the evidence a candidate has to explain (codex-review-2, finding 4).
    @Test func noShippedNameIsMistakenForPlateFurniture() throws {
        let catalog = try SeedCatalog.bundled()
        var wrong: [String] = []
        for model in catalog.equipmentModels {
            if MachineLabelText.isJunkLine(model.modelName) {
                wrong.append("\(model.manufacturer) | \(model.modelName)")
            }
            if MachineLabelText.isJunkLine(model.manufacturer) {
                wrong.append(model.manufacturer)
            }
        }
        #expect(wrong.isEmpty, "\(wrong.count) shipped names read as junk: \(wrong.prefix(5))")

        // The real furniture still is furniture.
        #expect(MachineLabelText.isJunkLine("MAX 300 LB"))
        #expect(MachineLabelText.isJunkLine("READ MANUAL BEFORE USE"))
        #expect(MachineLabelText.isJunkLine("SERIAL 84213-9920"))
        #expect(!MachineLabelText.isJunkLine("Insignia Series Abdominal"))
        #expect(!MachineLabelText.isJunkLine("4040 Basic Max Rack"))
    }

    /// D33 says the plate must name this row's manufacturer **and no other
    /// known one**. Two brands in one photograph is a photograph of two
    /// machines (codex-review-2, finding 2).
    @Test func aSecondKnownBrandOnThePlateBlocksPreselection() throws {
        let index = try realIndex()
        let matches = rank(
            ["LIFE FITNESS", "INSIGNIA SERIES CHEST PRESS", "MATRIX"], in: index)
        #expect(
            CatalogMatcher.preselection(from: matches) == nil,
            "two brands named, still preselected: \(describe(matches))")
        #expect(matches.first?.manufacturerConflicts == true)
    }

    /// Hardware the catalog does not carry must *lead* with create-new, not
    /// merely fail to preselect — the ticket's actual acceptance criterion
    /// (codex-review-2, finding 3).
    @Test func absentHardwareLeadsWithCreateNew() throws {
        let index = try realIndex()
        for lines in [
            ["NEWCO", "PENDULUM SQUAT"],
            ["ATLANTIS STRENGTH", "PLATE LOADED BELT SQUAT", "C-227"],
        ] {
            let matches = rank(lines, in: index)
            #expect(
                CatalogMatcher.suggestsCreatingNew(matches),
                "\(lines) should lead with create-new: \(describe(matches))")
        }
        // A plate the catalog *does* carry must not.
        let known = rank(["LIFE FITNESS", "INSIGNIA SERIES CHEST PRESS"], in: index)
        #expect(!CatalogMatcher.suggestsCreatingNew(known), "got: \(describe(known))")
    }

    /// The invariant that would have caught every identity defect in both
    /// reviews: read a row's own canonical name back through the photo-side
    /// tokenizer, and it must rank itself first — and never preselect anything
    /// else. Sampled with a fixed stride to keep the suite fast; the stride is
    /// coprime with nothing in particular, it just spreads across manufacturers.
    @Test func everySampledCatalogRowRecognisesItself() throws {
        let models = try SeedCatalog.bundled().equipmentModels
        let index = CatalogMatchIndex(models: models.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        })
        var notFirst: [String] = []
        var wrongPreselection: [String] = []

        for model in stride(from: 0, to: models.count, by: 13).map({ models[$0] }) {
            let reading = LabelReading.lines([model.manufacturer, model.modelName])
            let matches = CatalogMatcher.rank(reading, in: index, limit: 3)
            let name = "\(model.manufacturer) | \(model.modelName)"
            if matches.first?.modelID != model.id { notFirst.append(name) }
            if let preselected = CatalogMatcher.preselection(from: matches),
               preselected.modelID != model.id {
                wrongPreselection.append("\(name) → \(preselected.displayName)")
            }
        }
        #expect(
            wrongPreselection.isEmpty,
            "\(wrongPreselection.count) rows preselect a different UUID: \(wrongPreselection.prefix(5))")
        #expect(
            notFirst.isEmpty,
            "\(notFirst.count) rows do not rank themselves first: \(notFirst.prefix(5))")
    }

    // MARK: - Determinism

    /// The same photo must rank the same way whatever order the catalog arrived
    /// in and whatever this process's hash seed is.
    @Test func rankingDoesNotDependOnCatalogOrder() throws {
        let models = try SeedCatalog.bundled().equipmentModels.map {
            (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName)
        }
        let forward = CatalogMatchIndex(models: models)
        let backward = CatalogMatchIndex(models: models.reversed())
        let reading = LabelReading.lines(
            ["LIFE FITNESS", "Insignia Series Chest Press", "MAX 300 LB"])

        let first = CatalogMatcher.rank(reading, in: forward, limit: 5)
        let second = CatalogMatcher.rank(reading, in: backward, limit: 5)
        #expect(first == second)
        #expect(CatalogMatcher.preselection(from: first)
            == CatalogMatcher.preselection(from: second))
    }

    /// And the same reading assembled from differently ordered lines.
    @Test func rankingDoesNotDependOnLineOrder() throws {
        let index = try realIndex()
        let forward = rank(["LIFE FITNESS", "Insignia Series Chest Press"], in: index)
        let reversed = rank(["Insignia Series Chest Press", "LIFE FITNESS"], in: index)
        #expect(forward.map(\.modelID) == reversed.map(\.modelID))
        #expect(forward.map(\.score) == reversed.map(\.score))
    }

    // MARK: Prefix siblings (scanner accuracy, ticket 02)

    /// `ISO-LATERAL LOW ROW` read perfectly scored 100% and was never
    /// preselected: plain `Iso-Lateral Row` tied it within the margin. The
    /// generic row is the specific row's prefix, not a different machine.
    @Test func aPerfectlyReadSpecificRowIsNotBlockedByItsGenericPrefix() throws {
        let index = try realIndex()
        let matches = CatalogMatcher.rank(
            LabelReading.lines(["HAMMER", "STRENGTH", "ISO-LATERAL", "LOW ROW", "Start 8 lbs./3.6Kg."]),
            in: index)
        #expect(matches.first?.modelName == "Iso-Lateral Low Row")
        #expect(matches.dropFirst().first?.modelName == "Iso-Lateral Row", "the prefix sibling is the runner-up")
        let chosen = try #require(CatalogMatcher.preselection(from: matches))
        #expect(chosen.modelName == "Iso-Lateral Low Row")

        // A one-letter distinguisher does not unlock it: the Sorinex case in
        // `oneLetterComponentsOfRealNamesSurvive` stays unpreselected.
        let sorinex = CatalogMatcher.rank(LabelReading.lines(["SORINEX", "BASE CAMP RACK & A HALF"]), in: index)
        #expect(CatalogMatcher.preselection(from: sorinex) == nil)

        // The other way round is unchanged: a plate that says only ROW
        // preselects the plain row, and the longer sibling is not "near".
        let plain = CatalogMatcher.rank(
            LabelReading.lines(["HAMMER", "STRENGTH", "ISO-LATERAL", "ROW"]), in: index)
        #expect(CatalogMatcher.preselection(from: plain)?.modelName == "Iso-Lateral Row")
    }

    /// codex-review-02 #2: the distinguishing word must be read on a NAME
    /// LINE. A furniture word elsewhere on the plate — an instruction, a
    /// badge — must not unlock the longer sibling.
    @Test func aFurnitureWordElsewhereDoesNotUnlockTheLongerSibling() throws {
        let index = try realIndex()
        for (lines, wrong) in [
            (["NAUTILUS", "IMPACT LAT PULL DOWN", "FIXED"], "Impact Fixed Lat Pull Down"),
            (["LIFE FITNESS", "INSIGNIA SERIES LEG CURL", "Adjust the seat to the seated position"], "Insignia Series Seated Leg Curl"),
            (["ELEIKO", "PRESTERA HALF RACK", "FITNESS"], "Prestera Fitness Half Rack"),
        ] {
            let matches = CatalogMatcher.rank(LabelReading.lines(lines), in: index)
            let chosen = CatalogMatcher.preselection(from: matches)
            #expect(chosen?.modelName != wrong, "\(lines): preselected \(chosen?.displayName ?? "nothing")")
        }
        // Whereas the word ON the name line still counts.
        let seated = CatalogMatcher.rank(LabelReading.lines(["LIFE FITNESS", "INSIGNIA SERIES SEATED LEG CURL"]), in: index)
        #expect(CatalogMatcher.preselection(from: seated)?.modelName == "Insignia Series Seated Leg Curl")
    }

    /// The exception is only for a name read EXACTLY. A fuzzily-matched extra
    /// word is a guess, and a guess must not switch the margin off.
    @Test func aFuzzilyCoveredSpecificRowStillRespectsTheMargin() throws {
        let index = try realIndex()
        let matches = CatalogMatcher.rank(
            LabelReading.lines(["HAMMER", "STRENGTH", "ISO-LATERAL", "LOV ROW"]), in: index)
        guard let best = matches.first, best.modelName == "Iso-Lateral Low Row" else {
            return  // LOV did not even reach Low Row: nothing to protect against
        }
        #expect(!best.exactlyCovered)
        if matches.count > 1, best.score - matches[1].score < CatalogMatcher.preselectionMargin {
            #expect(CatalogMatcher.preselection(from: matches) == nil)
        }
    }
}
