import SwiftUI

struct MuscleGroupStyle {
    var color: Color
    var symbol: String

    static let styles: [String: MuscleGroupStyle] = [
        "Chest": .init(color: Color(rgb: 0xF4939C), symbol: "figure.strengthtraining.traditional"),
        "Shoulders": .init(color: Color(rgb: 0xE6CF88), symbol: "figure.boxing"),
        "Triceps": .init(color: Color(rgb: 0xC1A9EB), symbol: "dumbbell.fill"),
        "Back": .init(color: Color(rgb: 0x8ABCE5), symbol: "figure.rower"),
        "Biceps": .init(color: Color(rgb: 0xA5B0F1), symbol: "dumbbell.fill"),
        "Forearms": .init(color: Color(rgb: 0xA5B7C9), symbol: "hand.raised.fill"),
        "Core": .init(color: Color(rgb: 0x80CABE), symbol: "figure.core.training"),
        "Quads": .init(color: Color(rgb: 0xA5CF9A), symbol: "figure.strengthtraining.functional"),
        "Hamstrings": .init(color: Color(rgb: 0xC8D595), symbol: "figure.flexibility"),
        "Glutes": .init(color: Color(rgb: 0xDDA7CB), symbol: "figure.cooldown"),
        "Calves": .init(color: Color(rgb: 0x9BCFBA), symbol: "figure.walk"),
        "Hips": .init(color: Color(rgb: 0xD4B395), symbol: "figure.pilates"),
        "Neck": .init(color: Color(rgb: 0xB3ADC6), symbol: "person.bust.fill"),
        "Full Body": .init(color: Color(rgb: 0xF6F3EC), symbol: "figure.highintensity.intervaltraining"),
    ]
    static let fallback = MuscleGroupStyle(color: Theme.tertiary, symbol: "dumbbell.fill")

    static func resolve(_ group: String?) -> MuscleGroupStyle {
        group.flatMap { styles[$0] } ?? fallback
    }
}

struct MuscleIcon: View {
    var group: String?
    /// The tile grows with the glyph (the font scales with Dynamic Type) —
    /// at AccessibilityL a fixed 40 pt tile was smaller than its symbol
    /// (UI redesign ticket 08). `size` picks the base: 40 for a row, 24 for
    /// a strip inside a tile (ticket 10).
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 40
    /// The base picks the glyph's text style; the scaled side never does
    /// (codex-review-10: a 24 pt tile crossed a threshold at AXL and its
    /// glyph jumped to Title 3, out of its background).
    private let small: Bool

    init(group: String?, size: CGFloat = 40) {
        self.group = group
        self.small = size < 32
        _side = ScaledMetric(wrappedValue: size, relativeTo: .title3)
    }

    var body: some View {
        let style = MuscleGroupStyle.resolve(group)
        Image(systemName: style.symbol)
            .font(small ? .caption.weight(.semibold) : .title3.weight(.semibold))
            .foregroundStyle(style.color)
            .frame(width: side, height: side)
            .background(style.color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: small ? 8 : 14))
            .accessibilityHidden(true)
    }
}
