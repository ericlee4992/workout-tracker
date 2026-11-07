import SwiftUI

// EXPLORATION (2026-11-07) — "Soft": the user liked the feel of a calorie/macro tracker's design
// (light airy ground, white rounded cards on soft shadows, plain SF type, black pill buttons,
// rings with small icons, a floating + beside the tab bar). Built on Floodlight's structure with
// its own tokens; the action is monochrome (Direction A's Mono). Muscle families keep their hues.

extension Look {
    static let softLight: Look = {
        let ink = Color(hex: 0x111114)
        let grey = Color(hex: 0x6C6C72)
        var look = Look.finalLight
        look.origin = .soft
        look.ground = Color(hex: 0xF5F5F7)
        look.groundSheet = Color(hex: 0xF5F5F7)
        look.surface = .white
        look.surfaceSheet = .white
        look.surfaceRaised = Color(hex: 0xF1F1F4)
        look.field = Color(hex: 0xF1F1F4)
        look.pressedFill = Color(hex: 0xEAEAEE)
        look.hairline = ink.opacity(0.07)
        look.dash = ink.opacity(0.28)
        look.textPrimary = ink
        look.textSecondary = grey
        look.textTertiary = Color(hex: 0x8A8A90)
        look.action = ink
        look.onAction = .white
        look.actionText = ink
        look.live = ink
        look.liveOnSlabOverride = Color(hex: 0xF4F6F8)
        look.selection = ink
        look.selectionFill = ink.opacity(0.06)
        look.done = ink
        look.onDone = .white
        look.positive = ink
        look.onPositive = .white
        look.ringTrack = Color(hex: 0xECECF1)
        look.slab = Color.white.opacity(0.86)
        look.glassTint = Color.white.opacity(0.7)
        look.controlFill = Color(hex: 0xF1F1F4)
        look.chipFill = Color(hex: 0xF1F1F4)
        look.segmentFill = .white
        look.pillFill = .white
        look.pillEdge = ink.opacity(0.12)
        look.font = .soft
        look.radius = LookRadii(panel: 24, tile: 22, stat: 20, row: 14, field: 12, bar: 28, badge: 8, marker: 10, sheet: 38)
        look.space = LookSpacing(section: 26, group: 12, header: 14, panelPadding: 18, grid: 12)
        return look
    }()

    static let softDark: Look = {
        let flood = Color(hex: 0xF5F5F7)
        var look = Look.finalDark
        look.origin = .soft
        look.ground = .black
        look.groundSheet = Color(hex: 0x0E0E10)
        look.surface = Color(hex: 0x1C1C1E)
        look.surfaceSheet = Color(hex: 0x1C1C1E)
        look.surfaceRaised = Color(hex: 0x2C2C2E)
        look.field = Color(hex: 0x2C2C2E)
        look.hairline = .white.opacity(0.08)
        look.textPrimary = flood
        look.textSecondary = Color(hex: 0x98989F)
        look.textTertiary = Color(hex: 0x7C7C82)
        look.action = flood
        look.onAction = .black
        look.actionText = flood
        look.live = flood
        look.liveOnSlabOverride = flood
        look.selection = flood
        look.done = flood
        look.onDone = .black
        look.ringTrack = Color(hex: 0x2C2C2E)
        look.font = .soft
        look.radius = LookRadii(panel: 24, tile: 22, stat: 20, row: 14, field: 12, bar: 28, badge: 8, marker: 10, sheet: 38)
        look.space = LookSpacing(section: 26, group: 12, header: 14, panelPadding: 18, grid: 12)
        return look
    }()
}
