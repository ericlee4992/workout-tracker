import Foundation
import Testing
@testable import WorkoutTracker

// Barbell ticket 01 — the bar catalog and the arithmetic (D39–D40).
// Expected values are independent literals from the ticket, not recomputed
// from the code under test.

struct BarbellMathTests {

    // MARK: Total (the invariant)

    @Test func total_isBarPlusBothSides() {
        #expect(BarbellMath.total(barWeight: 45, platesPerSide: 45) == 135)
        #expect(BarbellMath.total(barWeight: 20, platesPerSide: 20) == 60)
        #expect(BarbellMath.total(barWeight: 45, platesPerSide: 2.5) == 50)
    }

    @Test func emptyBar_isARealSet() {
        // A1 accepts 0 plates: warming up on an empty bar is work that happened.
        #expect(BarbellMath.total(barWeight: 20, platesPerSide: 0) == 20)
        #expect(BarbellMath.total(barWeight: 45, platesPerSide: 0) == 45)
    }

    // MARK: Plates per side (the inverse)

    @Test func platesPerSide_invertsTotal() {
        #expect(BarbellMath.platesPerSide(total: 135, barWeight: 45) == 45)
        #expect(BarbellMath.platesPerSide(total: 60, barWeight: 20) == 20)
        #expect(BarbellMath.platesPerSide(total: 45, barWeight: 45) == 0)
    }

    @Test func platesPerSide_belowTheBar_isNil() {
        // A negative plate stack is not a thing. `-12.5` in the input field,
        // committed, would log a lighter set than the user performed.
        #expect(BarbellMath.platesPerSide(total: 20, barWeight: 45) == nil)
        #expect(BarbellMath.platesPerSide(total: 0, barWeight: 20) == nil)
        #expect(BarbellMath.platesPerSide(total: .nan, barWeight: 20) == nil)
        #expect(BarbellMath.platesPerSide(total: .infinity, barWeight: 20) == nil)
    }

    @Test func roundTrip_isExact_forEveryPresetAndPlateValue() {
        // The field is seeded from the stored total, so a lossy inverse would
        // rewrite the user's numbers every time a row was redrawn.
        let plates: [Double] = [0, 1.25, 2.5, 5, 10, 20, 45, 62.5, 100]
        for bar in BarbellMath.presets {
            for perSide in plates {
                let total = BarbellMath.total(
                    barWeight: bar.value, platesPerSide: perSide)
                #expect(
                    BarbellMath.platesPerSide(total: total, barWeight: bar.value)
                        == perSide,
                    "\(bar.id) with \(perSide) a side")
            }
        }
    }

    // MARK: Bar validity

    @Test func barWeightValidity_rejectsZeroAndNonsense() {
        #expect(BarbellMath.isValidBarWeight(45))
        #expect(BarbellMath.isValidBarWeight(0.5))
        // Zero is not a bar — "no bar" is nil, and two encodings of the same
        // state is one too many.
        #expect(!BarbellMath.isValidBarWeight(0))
        #expect(!BarbellMath.isValidBarWeight(-45))
        #expect(!BarbellMath.isValidBarWeight(.nan))
        #expect(!BarbellMath.isValidBarWeight(.infinity))
    }

    // MARK: The catalog

    @Test func presetIDs_areUnique() {
        let ids = BarbellMath.presets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func presetsExistInBothUnits_andAreNotConversions() throws {
        let kg = BarbellMath.presets(in: .kg)
        let lb = BarbellMath.presets(in: .lb)
        #expect(!kg.isEmpty)
        #expect(!lb.isEmpty)
        #expect(kg.allSatisfy { $0.unit == .kg })
        #expect(lb.allSatisfy { $0.unit == .lb })

        // D40: the 45 lb bar is a different object from the 20 kg bar, not a
        // rendering of it. 20 kg is 44.09 lb — if these ever became conversions
        // of each other, picking a bar would start converting silently.
        let olympicKg = try #require(BarbellMath.presets.first { $0.id == "olympic-20kg" })
        let olympicLb = try #require(BarbellMath.presets.first { $0.id == "olympic-45lb" })
        let convertedToLb = WeightMath.convert(olympicKg.value, from: .kg, to: .lb)
        #expect(abs(convertedToLb - olympicLb.value) > 0.5)
    }

    @Test func variableWeightBars_areCustomRatherThanGuessed() {
        #expect(!BarbellMath.presets.contains { $0.name.contains("EZ curl") })
        #expect(!BarbellMath.presets.contains { $0.name.contains("Trap") })
    }

    // MARK: Display

    @Test func totalLabel_showsTheRowsOwnUnit() {
        #expect(
            BarbellMath.totalLabel(
                barWeight: 45, platesPerSide: 45, unit: .lb, locale: Locale(identifier: "en_US"))
                == "= 135 lb")
        #expect(
            BarbellMath.totalLabel(
                barWeight: 20, platesPerSide: 2.5, unit: .kg, locale: Locale(identifier: "en_US"))
                == "= 25 kg")
    }

    @Test func breakdownLabel_showsTheArithmetic() {
        let en = Locale(identifier: "en_US")
        #expect(
            BarbellMath.breakdownLabel(barWeight: 45, total: 135, unit: .lb, locale: en)
                == "45 + 45 × 2 = 135 lb")
        // Trailing zeros trimmed (D25), so 2.5 never renders as 2.50.
        #expect(
            BarbellMath.breakdownLabel(barWeight: 20, total: 25, unit: .kg, locale: en)
                == "20 + 2.5 × 2 = 25 kg")
    }

    @Test func breakdownLabel_emptyBar_readsAsABar_notAsZeroPlates() {
        let en = Locale(identifier: "en_US")
        #expect(
            BarbellMath.breakdownLabel(barWeight: 20, total: 20, unit: .kg, locale: en)
                == "20 kg bar = 20 kg")
        // Below the bar there is no honest breakdown to render.
        #expect(
            BarbellMath.breakdownLabel(barWeight: 45, total: 20, unit: .lb, locale: en) == nil)
    }
}
