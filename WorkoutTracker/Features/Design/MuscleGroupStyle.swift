import SwiftUI

/// A fixed colour and a muscle-map image per muscle FAMILY (D54; UI redesign
/// tickets 11–12). The user rejected SF Symbols for this ("inaccurate and
/// mild") and chose, from two designed sets, Codex's body maps: a neutral body
/// with the family's muscle highlighted — pecs, lats + traps, deltoids, the
/// bicep, the quads. Each map is two template images in `Assets.xcassets/
/// MuscleMaps/` (`<family>-body`, `<family>-muscle`), tinted here: the body in
/// `Theme.muscleBody`, the muscle in the family colour. The mapping from the
/// seeded vocabulary lives in `Domain/MuscleFamily.swift`, unit-tested.
struct MuscleGroupStyle {
    var color: Color
    /// The asset name stem under the `MuscleMaps` namespace.
    var map: String

    static let styles: [MuscleFamily: MuscleGroupStyle] = [
        .chest: .init(color: Color(rgb: 0xFF70B6), map: "chest"),
        .back: .init(color: Color(rgb: 0x4EB9FF), map: "back"),
        .shoulders: .init(color: Color(rgb: 0x4DE0D4), map: "shoulders"),
        .arms: .init(color: Color(rgb: 0xB891FF), map: "arms"),
        .legs: .init(color: Color(rgb: 0x84D65A), map: "legs"),
    ]

    static func resolve(_ family: MuscleFamily) -> MuscleGroupStyle {
        styles[family] ?? styles[.chest]!
    }

    var bodyImage: String { "MuscleMaps/\(map)-body" }
    var muscleImage: String { "MuscleMaps/\(map)-muscle" }
}

struct MuscleIcon: View {
    var family: MuscleFamily
    /// The tile grows with Dynamic Type (`@ScaledMetric`) — at AccessibilityL
    /// a fixed 40 pt tile was smaller than its glyph (UI redesign ticket 08).
    /// `size` picks the base: 40 for a row, 24 for a strip inside a tile
    /// (ticket 10). The map fills 86 % of the tile (the proportion the user
    /// chose from on the comparison board, ticket 12).
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 40
    private let small: Bool

    init(family: MuscleFamily, size: CGFloat = 40) {
        self.family = family
        self.small = size < 32
        _side = ScaledMetric(wrappedValue: size, relativeTo: .title3)
    }

    var body: some View {
        let style = MuscleGroupStyle.resolve(family)
        let map = side * 0.86
        ZStack {
            Image(style.bodyImage)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Theme.muscleBody)
            Image(style.muscleImage)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(style.color)
        }
        .frame(width: map, height: map)
        .frame(width: side, height: side)
        .background(style.color.opacity(0.16),
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
