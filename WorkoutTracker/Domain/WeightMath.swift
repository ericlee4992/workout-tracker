import Foundation

// Ticket 03 — unit conversion domain core (D25). Pure logic: no UI, no
// SwiftData. Storage keeps full precision as entered; all rounding is
// display-only; converted display values are shown plain (D52 — they carried
// a ≈ prefix until 2026-09-04).

// MARK: - Conversion, validation, formatting

enum WeightMath {

    /// Exact by international definition (D25): 1 lb = 0.45359237 kg.
    static let kilogramsPerPound = 0.45359237

    /// A weight input is storable iff it is finite and non-negative.
    /// Zero is legal (bodyweight sets).
    static func isValidInput(_ value: Double) -> Bool {
        value.isFinite && value >= 0
    }

    /// Canonical kg value for `(value, unit)`. kg passes through untouched so
    /// `normalizedKg == value` exactly for kg entries.
    static func normalizedKg(value: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: value
        case .lb: value * kilogramsPerPound
        }
    }

    /// Full-precision conversion between units. Identity when units match.
    static func convert(
        _ value: Double, from source: WeightUnit, to target: WeightUnit
    ) -> Double {
        guard source != target else { return value }
        switch target {
        case .kg: return value * kilogramsPerPound
        case .lb: return value / kilogramsPerPound
        }
    }

    // MARK: Display formatting (D25)

    /// Display-time number formatting: at most 2 decimals, half-up rounding,
    /// trailing zeros trimmed (`60`, `62.5`, `61.23`), decimal separator from
    /// `locale`. Never used for storage.
    static func displayNumber(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: value as NSNumber) ?? "\(value)"
    }

    /// Label for a stored weight shown in `displayUnit`: the as-entered value
    /// in its own unit (`60 kg`), or the converted number plain (`132.28 lb`).
    /// D52 dropped the ≈ prefix a converted value used to carry; the stored
    /// `(value, unit)` is untouched either way (D25).
    static func displayLabel(
        for weight: StoredWeight, in displayUnit: WeightUnit,
        locale: Locale = .current
    ) -> String {
        let converted = convert(weight.value, from: weight.unit, to: displayUnit)
        let number = displayNumber(converted, locale: locale)
        return "\(number) \(displayUnit.rawValue)"
    }

    /// Label for a canonical-kg figure (a volume, a 1RM — derived numbers
    /// that have no as-entered unit of their own) rendered in `displayUnit`,
    /// plain (D52). One place for the conversion + rounding + suffix, so a
    /// display-policy change is one edit rather than one per screen
    /// (codex-review 02 of the finish graph).
    static func displayLabel(
        kilograms: Double, in displayUnit: WeightUnit, locale: Locale = .current
    ) -> String {
        let converted = convert(kilograms, from: .kg, to: displayUnit)
        return "\(displayNumber(converted, locale: locale)) \(displayUnit.rawValue)"
    }

    /// Locale-independent, full-precision serialization (export/debug). Always
    /// uses `.` as the decimal separator and round-trips through `Double(_:)`.
    static func storageNumber(_ value: Double) -> String {
        // Swift's Double description is locale-independent and shortest
        // round-trip (`Double(storageNumber(x)) == x`).
        "\(value)"
    }
}

// MARK: - Stored weight with atomic recompute

/// A validated `(value, unit)` pair plus its derived `normalizedKg`.
/// Construction is the only door: every edit goes through a helper that
/// recomputes `normalizedKg` in the same step, so the three can never drift
/// (D25). `value`/`unit` always remain exactly as entered.
struct StoredWeight: Equatable {
    let value: Double
    let unit: WeightUnit
    let normalizedKg: Double

    /// Fails for NaN, infinite, or negative input.
    init?(value: Double, unit: WeightUnit) {
        guard WeightMath.isValidInput(value) else { return nil }
        self.value = value
        self.unit = unit
        self.normalizedKg = WeightMath.normalizedKg(value: value, unit: unit)
    }

    /// Value edit: same unit, recomputed `normalizedKg`. Fails on invalid input.
    func editingValue(_ newValue: Double) -> StoredWeight? {
        StoredWeight(value: newValue, unit: unit)
    }

    /// Unit edit: reinterprets the same as-entered value in `newUnit` (never a
    /// silent conversion — D25), recomputing `normalizedKg`.
    func settingUnit(_ newUnit: WeightUnit) -> StoredWeight {
        // `value` was validated at construction, so this cannot fail.
        StoredWeight(value: value, unit: newUnit)!
    }

    /// Convenience for the kg/lb unit toggle.
    func togglingUnit() -> StoredWeight {
        settingUnit(unit.toggled)
    }
}
