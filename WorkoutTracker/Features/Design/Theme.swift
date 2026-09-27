import SwiftUI

/// TRANSITIONAL (Floodlight redesign): the pre-redesign token names, now drawn from the
/// Floodlight palette and following Settings → Appearance (light / dark), so a screen not yet
/// rebuilt on `Look` stays legible in both schemes. Screens move to `@Environment(\.look)`;
/// this enum is removed once none reads it.
enum Theme {
    static let accent = Color.accentColor
    static let onAccent = dynamic(dark: 0x060708, light: 0xFFFFFF)
    static let background = dynamic(dark: 0x060708, light: 0xF2F3F5)
    static let card = dynamic(dark: 0x181A1E, light: 0xFFFFFF)
    static let elevated = dynamic(dark: 0x22252A, light: 0xEBEDF0)
    static let fill = dynamic(dark: 0x2A2D33, light: 0xE3E6EA)
    static let hairline = dynamic(dark: 0xFFFFFF, darkAlpha: 0.10, light: 0x0B0C0E, lightAlpha: 0.10)
    static let text = dynamic(dark: 0xF4F6F8, light: 0x0B0C0E)
    static let secondary = dynamic(dark: 0xA4A9B1, light: 0x555A63)
    static let tertiary = dynamic(dark: 0x7F858E, light: 0x62676F)
    static let danger = dynamic(dark: 0xFF5E3A, light: 0xBF3510)
    static let warmup = dynamic(dark: 0xA4A9B1, light: 0x555A63)
    static let drop = dynamic(dark: 0xF4F6F8, light: 0x0B0C0E)
    static let unitKg = dynamic(dark: 0xA4A9B1, light: 0x555A63)
    static let unitLb = dynamic(dark: 0xA4A9B1, light: 0x555A63)
    static let unitMixed = dynamic(dark: 0xA4A9B1, light: 0x555A63)
    /// The neutral body of a muscle-map icon (ticket 12) — the muscle wears the family colour.
    static let muscleBody = dynamic(dark: 0x535862, light: 0xC9CDD4)

    private static func dynamic(dark: UInt32, darkAlpha: CGFloat = 1, light: UInt32, lightAlpha: CGFloat = 1) -> Color {
        func ui(_ hex: UInt32, _ alpha: CGFloat) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                    blue: CGFloat(hex & 255) / 255, alpha: alpha)
        }
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .light ? ui(light, lightAlpha) : ui(dark, darkAlpha)
        })
    }

    enum Radius {
        static let card: CGFloat = 24
        static let inner: CGFloat = 16
        static let field: CGFloat = 10
    }
    enum Space {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let inset: CGFloat = 16
        static let large: CGFloat = 24
    }
    static let hero = Font.system(.largeTitle, design: .rounded, weight: .black)
    static let stat = Font.system(.title2, design: .rounded, weight: .bold)
    static let cardTitle = Font.headline.weight(.bold)
    static let label = Font.caption2.weight(.semibold)
}

extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                  green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255, opacity: 1)
    }
}
