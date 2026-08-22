import Foundation

// Barbell bar weight (D39–D40, 2026-08-22) — the first half of milestone 6's
// plate calculator: which bar you are on, and what you hung on it. Pure logic:
// no UI, no SwiftData.
//
// THE INVARIANT THIS FILE EXISTS TO PROTECT: a set's stored `weightValue` is
// always the TOTAL lifted, bar included. Bar mode changes what the user types
// (plates per side) and what the row displays — never what is stored. Every
// write of a bar-mode weight goes through `total(barWeight:platesPerSide:)`.
//
// What breaks if that is violated: `RecordsMath`, volume (D21), e1RM (D20) and
// the export's `weight`/`weightKg` all read `weightValue`. A stored weight that
// sometimes excluded the bar would drop every barbell PR by the weight of a bar
// with no error anywhere — the history would simply become wrong.

/// A bar the user can pick, with its own unit. A 20 kg bar and a 45 lb bar are
/// **separate presets**, not conversions of each other (D40): 20 kg is 44.09 lb,
/// and the 45 lb bar sold in US gyms is a different object. Listing both and
/// letting the user pick the one in their hands is the honest version — and it
/// means picking a bar never converts anything, so nothing is ever marked ≈.
struct BarPreset: Identifiable, Equatable, Hashable {
    /// Stable identifier. Not persisted today (only the bar's *weight* is —
    /// see `SetRecord.barWeightValue`), but stable anyway so a picker
    /// selection, a test, or a later preference can name a bar without
    /// depending on its display name.
    let id: String
    let name: String
    let value: Double
    let unit: WeightUnit
    /// False for bars whose weight is not standardised across makers. D4's
    /// rule — a plausible-but-invented number is worse than an absent one — so
    /// these ship with their weight shown as typical and the picker says to
    /// check the one in the rack.
    let isStandard: Bool

    init(
        id: String, name: String, value: Double, unit: WeightUnit,
        isStandard: Bool = true
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.isStandard = isStandard
    }

    /// `45 lb`, `20 kg` — the weight as entered, never converted (D25).
    func weightLabel(locale: Locale = .current) -> String {
        "\(WeightMath.displayNumber(value, locale: locale)) \(unit.rawValue)"
    }
}

enum BarbellMath {

    /// The shipped bars. IWF-standard bars (20/15/10 kg and the 45/35/15 lb
    /// bars US gyms stock) carry exact weights; EZ curl and trap bars vary by
    /// maker and are flagged `isStandard: false`. Anything else is entered as a
    /// custom weight — the app never guesses at a number the user can read off
    /// the bar in front of them (D4).
    static let presets: [BarPreset] = [
        BarPreset(id: "olympic-20kg", name: "Olympic barbell", value: 20, unit: .kg),
        BarPreset(id: "womens-15kg", name: "Women's Olympic barbell", value: 15, unit: .kg),
        BarPreset(id: "technique-10kg", name: "Technique bar", value: 10, unit: .kg),
        BarPreset(
            id: "ezcurl-10kg", name: "EZ curl bar", value: 10, unit: .kg,
            isStandard: false),
        BarPreset(
            id: "trap-25kg", name: "Trap / hex bar", value: 25, unit: .kg,
            isStandard: false),
        BarPreset(id: "olympic-45lb", name: "Olympic barbell", value: 45, unit: .lb),
        BarPreset(id: "womens-35lb", name: "Women's Olympic barbell", value: 35, unit: .lb),
        BarPreset(id: "technique-15lb", name: "Technique bar", value: 15, unit: .lb),
        BarPreset(
            id: "ezcurl-25lb", name: "EZ curl bar", value: 25, unit: .lb,
            isStandard: false),
        BarPreset(
            id: "trap-55lb", name: "Trap / hex bar", value: 55, unit: .lb,
            isStandard: false),
    ]

    static func presets(in unit: WeightUnit) -> [BarPreset] {
        presets.filter { $0.unit == unit }
    }

    /// A bar weight is storable iff it is finite and strictly positive. Zero is
    /// **not** a bar: "no bar" is `nil`, which means the weight field is the
    /// total, and a zero-weight bar would render as bar mode while adding
    /// nothing — two ways to say the same thing, one of which lies about the
    /// equipment.
    static func isValidBarWeight(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }

    /// What the set weighs: the bar plus a plate stack on each end.
    ///
    /// `platesPerSide == 0` is legal and meaningful — an empty bar is a real
    /// working set, and A1 (loggability) accepts it for exactly that reason.
    static func total(barWeight: Double, platesPerSide: Double) -> Double {
        barWeight + 2 * platesPerSide
    }

    /// The plates the user must have hung to reach `total` on this bar —
    /// the inverse of `total(barWeight:platesPerSide:)`, used to seed the input
    /// field from a stored (total) weight.
    ///
    /// nil when the total is below the bar: a negative plate stack is not a
    /// thing. Returning one would put `-5` in the field, and committing that
    /// text would log a lighter set than the user performed. The caller's honest
    /// move is to leave the field empty and let the user say what they lifted.
    static func platesPerSide(total: Double, barWeight: Double) -> Double? {
        guard total.isFinite, barWeight.isFinite, total >= barWeight else { return nil }
        return (total - barWeight) / 2
    }

    // MARK: - Display

    /// The running total under a bar-mode row: `= 135 lb`. Always the row's own
    /// unit, so nothing here is ever a converted value (D25).
    static func totalLabel(
        barWeight: Double, platesPerSide: Double, unit: WeightUnit,
        locale: Locale = .current
    ) -> String {
        let total = total(barWeight: barWeight, platesPerSide: platesPerSide)
        return "= \(WeightMath.displayNumber(total, locale: locale)) \(unit.rawValue)"
    }

    /// How a logged bar-mode set reads in history: `45 + 45 × 2 = 135 lb`. The
    /// arithmetic is shown rather than asserted, because the whole point of the
    /// feature is that the user did not do it themselves.
    static func breakdownLabel(
        barWeight: Double, total: Double, unit: WeightUnit,
        locale: Locale = .current
    ) -> String? {
        guard let perSide = platesPerSide(total: total, barWeight: barWeight) else {
            return nil
        }
        let bar = WeightMath.displayNumber(barWeight, locale: locale)
        let sum = WeightMath.displayNumber(total, locale: locale)
        guard perSide > 0 else {
            // An empty bar has no plates to show, and "45 + 0 × 2" reads as a
            // mistake rather than as a light set.
            return "\(bar) \(unit.rawValue) bar = \(sum) \(unit.rawValue)"
        }
        let plates = WeightMath.displayNumber(perSide, locale: locale)
        return "\(bar) + \(plates) × 2 = \(sum) \(unit.rawValue)"
    }
}
