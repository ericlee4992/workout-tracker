import SwiftUI

/// Ink, graphite and amber. Semantic type scales with the user's text size.
enum Theme {
    static let accent = Color.accentColor
    static let onAccent = Color("OnAccent")
    static let background = Color("SurfaceBackground")
    static let card = Color("SurfaceCard")
    static let elevated = Color("SurfaceElevated")
    static let fill = Color("SurfaceFill")
    static let hairline = Color("Hairline")
    static let text = Color("TextPrimary")
    static let secondary = Color("TextSecondary")
    static let tertiary = Color("TextTertiary")
    static let danger = Color("Danger")
    static let warmup = Color("Warmup")
    static let drop = Color("Drop")
    static let unitKg = Color("UnitKg")
    static let unitLb = Color("UnitLb")
    static let unitMixed = Color("UnitMixed")

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
