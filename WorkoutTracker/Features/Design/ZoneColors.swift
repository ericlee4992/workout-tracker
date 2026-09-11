import SwiftUI

/// One colour per heart-rate zone, shared by the live bar, the finish
/// sheet's zone bar and History (D54). Warm-up is deliberately quiet.
extension HeartRateZone {
    var color: Color {
        switch self {
        case .warm: Theme.tertiary
        case .one: Color(rgb: 0x8ABCE5)
        case .two: Color(rgb: 0x80CABE)
        case .three: Color(rgb: 0xA5CF9A)
        case .four: Theme.accent
        case .five: Theme.danger
        }
    }
}
