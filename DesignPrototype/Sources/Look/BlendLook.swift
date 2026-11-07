import SwiftUI

// DIRECTION C "Blend" (2026-11-07) — from two independent proposals (Fable 5.1 "Floodlight, daylight",
// ChatGPT Astra "Open Floodlight"; work-record/ui-evolution/proposals/). Our identity kept: SF Pro
// Expanded titles and figures, ink / cool-white grounds, Mono action, muscle figures, the set table.
// Borrowed from the reference, in our materials: air (cards lifted on a soft shadow, light mode
// only — dark keeps graphite + hairline), figure-over-goal, the day at the top, a "+" a thumb away.
// Refused: the warm page wash, plain type, smooth icon rings.

extension Look {
    static let blendLight: Look = {
        var look = Look.finalLight.withAccent(.mono, live: false)
        look.origin = .blend
        look.ground = Color(hex: 0xF3F3F5)
        look.groundSheet = Color(hex: 0xF3F3F5)
        look.hairline = Color.black.opacity(0.06)
        look.ringTrack = Color(hex: 0xE2E2E8)
        look.radius = LookRadii(panel: 20, tile: 20, stat: 18, row: 12, field: 10, bar: 24, badge: 6, marker: 8, sheet: 38)
        look.space = LookSpacing(section: 28, group: 12, header: 12, panelPadding: 16, grid: 12)
        return look
    }()

    static let blendDark: Look = {
        var look = Look.finalDark.withAccent(.mono, live: false)
        look.origin = .blend
        look.ground = Color(hex: 0x0B0B0D)
        look.groundSheet = Color(hex: 0x0B0B0D)
        look.surface = Color(hex: 0x161619)
        look.surfaceSheet = Color(hex: 0x161619)
        look.surfaceRaised = Color(hex: 0x1F1F23)
        look.field = Color(hex: 0x1F1F23)
        look.hairline = Color.white.opacity(0.08)
        look.ringTrack = Color(hex: 0x2A2A30)
        look.radius = LookRadii(panel: 20, tile: 20, stat: 18, row: 12, field: 10, bar: 24, badge: 6, marker: 8, sheet: 38)
        look.space = LookSpacing(section: 28, group: 12, header: 12, panelPadding: 16, grid: 12)
        return look
    }()
}

/// The Blend variants the prototype pill switches between (the user: "show me both").
@MainActor @Observable
final class BlendOptions {
    static let shared = BlendOptions()
    enum Tabs: String { case food, library }
    enum Add: String { case circle, bar }
    enum Macros: String { case dials, bars }
    var tabs: Tabs = Tabs(rawValue: UserDefaults.standard.string(forKey: "blendTabs") ?? "") ?? .food
    var add: Add = Add(rawValue: UserDefaults.standard.string(forKey: "blendAdd") ?? "") ?? .circle
    var macros: Macros = Macros(rawValue: UserDefaults.standard.string(forKey: "blendMacros") ?? "") ?? .dials
    private init() {}
}

/// Nutrition's quiet family (Fable's earthy hues): never on the same row as the muscle hues.
enum BlendMacro: CaseIterable, Identifiable {
    case protein, carbs, fat
    var id: Self { self }
    var letter: String { switch self { case .protein: "P"; case .carbs: "C"; case .fat: "F" } }
    var name: String { switch self { case .protein: "Protein"; case .carbs: "Carbs"; case .fat: "Fat" } }
    func color(dark: Bool) -> Color {
        switch (self, dark) {
        case (.protein, false): Color(hex: 0xC2183D)
        case (.protein, true): Color(hex: 0xFF5F7E)
        case (.carbs, false): Color(hex: 0xA9742F)
        case (.carbs, true): Color(hex: 0xD9A55A)
        case (.fat, false): Color(hex: 0x566BA8)
        case (.fat, true): Color(hex: 0x8EA0E0)
        }
    }
    var soft: SoftMacro { switch self { case .protein: .protein; case .carbs: .carbs; case .fat: .fat } }
}
