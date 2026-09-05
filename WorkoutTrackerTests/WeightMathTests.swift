import Foundation
import Testing
@testable import WorkoutTracker

// Ticket 03 — unit conversion domain core (D25): exact constant, atomic
// normalizedKg recomputation, input validation, display formatting.
// Expected values are independent literals from the ticket/D25, not recomputed.

struct WeightMathTests {

    // MARK: Conversion constant & normalizedKg

    @Test func kgIdentity_normalizedKgEqualsValueExactly() throws {
        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        #expect(weight.normalizedKg == 60)

        let fractional = try #require(StoredWeight(value: 62.5, unit: .kg))
        #expect(fractional.normalizedKg == 62.5)
    }

    @Test func lbConversion_withinTolerance_ofExactConstant() throws {
        // 1 lb = 0.45359237 kg exactly (D25).
        let one = try #require(StoredWeight(value: 1, unit: .lb))
        #expect(abs(one.normalizedKg - 0.45359237) < 1e-9)

        let hundred = try #require(StoredWeight(value: 100, unit: .lb))
        #expect(abs(hundred.normalizedKg - 45.359237) < 1e-9)
    }

    // MARK: Atomic recompute on edits

    @Test func editValue_recomputesNormalizedKg() throws {
        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        let edited = try #require(weight.editingValue(80))
        #expect(edited.value == 80)
        #expect(edited.unit == .kg)
        #expect(edited.normalizedKg == 80)

        let lb = try #require(StoredWeight(value: 100, unit: .lb))
        let editedLb = try #require(lb.editingValue(135))
        #expect(abs(editedLb.normalizedKg - 61.23496995) < 1e-9)
    }

    @Test func toggleUnit_keepsValueAsEntered_recomputesNormalizedKg() throws {
        // Stored unit edits reinterpret the same as-entered value (never a
        // silent conversion); normalizedKg recomputes atomically.
        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        let toggled = weight.togglingUnit()
        #expect(toggled.value == 60)
        #expect(toggled.unit == .lb)
        #expect(abs(toggled.normalizedKg - 27.2155422) < 1e-9)

        let back = toggled.togglingUnit()
        #expect(back.value == 60)
        #expect(back.unit == .kg)
        #expect(back.normalizedKg == 60)
    }

    // MARK: Input validation

    @Test func invalidInput_nanInfiniteNegative_rejected() throws {
        #expect(StoredWeight(value: Double.nan, unit: .kg) == nil)
        #expect(StoredWeight(value: Double.infinity, unit: .kg) == nil)
        #expect(StoredWeight(value: -Double.infinity, unit: .lb) == nil)
        #expect(StoredWeight(value: -0.1, unit: .kg) == nil)
        #expect(StoredWeight(value: -60, unit: .lb) == nil)

        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        #expect(weight.editingValue(Double.nan) == nil)
        #expect(weight.editingValue(Double.infinity) == nil)
        #expect(weight.editingValue(-5) == nil)

        // Zero is a legal weight (bodyweight sets).
        #expect(StoredWeight(value: 0, unit: .kg) != nil)
    }

    // MARK: Display formatting (D25 exact expectations)

    private let posix = Locale(identifier: "en_US_POSIX")

    @Test func formatting_ticketExamples_verbatim() throws {
        #expect(WeightMath.displayNumber(60, locale: posix) == "60")   // not 60.0
        #expect(WeightMath.displayNumber(62.5, locale: posix) == "62.5")
        #expect(WeightMath.displayNumber(61.23, locale: posix) == "61.23")
    }

    @Test func formatting_twoDecimalCap_halfUp_trailingZerosTrimmed() throws {
        // 2-decimal cap
        #expect(WeightMath.displayNumber(61.234, locale: posix) == "61.23")
        // half-up on an exactly representable tie (0.125 is exact in binary)
        #expect(WeightMath.displayNumber(0.125, locale: posix) == "0.13")
        // trailing zeros trimmed
        #expect(WeightMath.displayNumber(62.50, locale: posix) == "62.5")
        #expect(WeightMath.displayNumber(60.00, locale: posix) == "60")
        // rounding may carry into the integer part
        #expect(WeightMath.displayNumber(59.999, locale: posix) == "60")
    }

    @Test func conversionDisplay_isPlain() throws {
        // 60 kg shown in lb = 132.28 lb. Used to be "≈132.28 lb"; D52
        // dropped the mark at the user's request.
        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        let label = WeightMath.displayLabel(for: weight, in: .lb, locale: posix)
        #expect(label == "132.28 lb")
        #expect(!label.contains("≈"))
    }

    @Test func sameUnitDisplay_isNotMarked() throws {
        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        #expect(WeightMath.displayLabel(for: weight, in: .kg, locale: posix) == "60 kg")

        let lb = try #require(StoredWeight(value: 132.5, unit: .lb))
        #expect(WeightMath.displayLabel(for: lb, in: .lb, locale: posix) == "132.5 lb")
    }

    @Test func display_usesLocaleDecimalSeparator() throws {
        let german = Locale(identifier: "de_DE")
        #expect(WeightMath.displayNumber(62.5, locale: german) == "62,5")

        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        #expect(WeightMath.displayLabel(for: weight, in: .lb, locale: german) == "132,28 lb")
    }

    @Test func storage_isLocaleIndependent() throws {
        // Storage serialization always uses "." regardless of user locale,
        // and keeps full precision (no display rounding).
        #expect(WeightMath.storageNumber(62.5) == "62.5")
        #expect(WeightMath.storageNumber(60) == "60.0")
        #expect(WeightMath.storageNumber(61.234) == "61.234")
        let parsed = Double(WeightMath.storageNumber(27.215_542_2))
        #expect(parsed == 27.215_542_2)
    }

    // MARK: Round-trip honesty

    @Test func roundTripHonesty_displayRoundingNeverMutatesStorage() throws {
        // 60 kg → display in lb → storage is still exactly 60 kg.
        let weight = try #require(StoredWeight(value: 60, unit: .kg))
        let displayed = WeightMath.displayLabel(for: weight, in: .lb, locale: posix)
        #expect(displayed == "132.28 lb")
        #expect(weight.value == 60)
        #expect(weight.unit == .kg)
        #expect(weight.normalizedKg == 60)

        // And a full user round trip: re-enter the rounded lb figure and the
        // normalized value honestly differs from 60 kg — no fake exactness.
        let reentered = try #require(StoredWeight(value: 132.28, unit: .lb))
        #expect(reentered.normalizedKg != 60)
        #expect(abs(reentered.normalizedKg - 60) < 0.01)
    }
}
