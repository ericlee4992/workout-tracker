import SwiftUI

/// The three macros' names, glyphs and quiet hues (D67: macro hues are for nutrition only — the small icons and their
/// rings, never text). The hues are the approved prototype's (`SoftMacro`, tag `design/soft-approved-2026-11-07`).
enum MacroKind: CaseIterable, Identifiable {
    case protein, carbs, fat
    var id: Self { self }

    var name: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }

    var symbol: String {
        switch self {
        case .protein: "fish.fill"
        case .carbs: "leaf.fill"
        case .fat: "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .protein: Color(hex: 0xD9665B)
        case .carbs: Color(hex: 0xC9944A)
        case .fat: Color(hex: 0x5B7FC9)
        }
    }

    func grams(of macros: Macros) -> Double {
        switch self {
        case .protein: macros.proteinGrams
        case .carbs: macros.carbsGrams
        case .fat: macros.fatGrams
        }
    }
}

/// A macro's glyph in its hue on a soft disc of the same hue.
struct MacroGlyph: View {
    var macro: MacroKind
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(macro.color.opacity(0.14))
            Image(systemName: macro.symbol)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(macro.color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
