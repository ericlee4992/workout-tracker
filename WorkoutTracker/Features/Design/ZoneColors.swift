import SwiftUI

/// One colour per heart-rate zone, shared by the live bar, the finish
/// sheet's zone bar and History (D54). Warm-up is deliberately quiet.
/// TRANSITIONAL (Floodlight redesign): the light Appearance takes the Floodlight Light zone ramp
/// (≥ 4.85:1 on white), so zone captions on screens not yet rebuilt stay readable; dark keeps the
/// pre-redesign hues. Rebuilt screens use `look.zone(_:)`.
extension HeartRateZone {
    var color: Color {
        switch self {
        case .warm: Theme.tertiary
        case .one: Self.dynamic(dark: 0x8ABCE5, light: 0x8E4E6C)
        case .two: Self.dynamic(dark: 0x80CABE, light: 0xA63D69)
        case .three: Self.dynamic(dark: 0xA5CF9A, light: 0xBF1F5C)
        case .four: Theme.accent
        case .five: Theme.danger
        }
    }

    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                    blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
        return Color(UIColor { $0.userInterfaceStyle == .light ? ui(light) : ui(dark) })
    }
}
