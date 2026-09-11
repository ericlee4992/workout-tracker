import SwiftUI

/// A fixed colour and SF Symbol per muscle FAMILY (D54; UI redesign
/// ticket 11). Before ticket 11 this was a table of the 14 seeded groups and
/// every exercise row wore one; the user wanted the row icons gone ("they
/// don't match") and a template to show icons "only for muscle group (either
/// chest, back, arm, shoulder or leg)". The mapping from the seeded
/// vocabulary lives in `Domain/MuscleFamily.swift`, unit-tested.
struct MuscleGroupStyle {
    var color: Color
    var symbol: String

    static let styles: [MuscleFamily: MuscleGroupStyle] = [
        .chest: .init(color: Color(rgb: 0xF4939C), symbol: "figure.strengthtraining.traditional"),
        .back: .init(color: Color(rgb: 0x8ABCE5), symbol: "figure.rower"),
        .shoulders: .init(color: Color(rgb: 0xE6CF88), symbol: "figure.arms.open"),
        .arms: .init(color: Color(rgb: 0xC1A9EB), symbol: "dumbbell.fill"),
        .legs: .init(color: Color(rgb: 0xA5CF9A), symbol: "figure.strengthtraining.functional"),
    ]
    static let fallback = MuscleGroupStyle(color: Theme.tertiary, symbol: "dumbbell.fill")

    static func resolve(_ family: MuscleFamily?) -> MuscleGroupStyle {
        family.flatMap { styles[$0] } ?? fallback
    }
}

struct MuscleIcon: View {
    var family: MuscleFamily?
    /// The tile grows with the glyph (the font scales with Dynamic Type) —
    /// at AccessibilityL a fixed 40 pt tile was smaller than its symbol
    /// (UI redesign ticket 08). `size` picks the base: 40 for a row, 24 for
    /// a strip inside a tile (ticket 10).
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 40
    /// The base picks the glyph's text style; the scaled side never does
    /// (codex-review-10: a 24 pt tile crossed a threshold at AXL and its
    /// glyph jumped to Title 3, out of its background).
    private let small: Bool

    init(family: MuscleFamily?, size: CGFloat = 40) {
        self.family = family
        self.small = size < 32
        _side = ScaledMetric(wrappedValue: size, relativeTo: .title3)
    }

    var body: some View {
        let style = MuscleGroupStyle.resolve(family)
        Image(systemName: style.symbol)
            .font(small ? .caption.weight(.semibold) : .title3.weight(.semibold))
            .foregroundStyle(style.color)
            .frame(width: side, height: side)
            .background(style.color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: small ? 8 : 14))
            .accessibilityHidden(true)
    }
}

/// The families a set of exercises trains, as a strip of icons — the
/// template tile (24 pt) and the template detail (40 pt). Decoration to
/// VoiceOver except for one label naming the families, so the strip says
/// what it shows without a visible word.
struct MuscleFamilyStrip: View {
    var families: [MuscleFamily]
    var size: CGFloat = 40

    var body: some View {
        WrapLayout {
            ForEach(families, id: \.self) { family in
                MuscleIcon(family: family, size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(families.map(\.rawValue).joined(separator: ", "))
    }
}
