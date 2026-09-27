import SwiftUI

// Floodlight Light and the live-workout look (the user's decision, 2026-09-26): keep Floodlight
// everywhere, bring in Paper Club's live WORKOUT structure re-skinned in Floodlight's language,
// and add a light theme (Settings → Appearance: System / Light / Dark).
//
// • `Look.floodlight` (Look.swift) is the dark set; `Look.floodlightLight` (below) the light one.
// • The live lifting workout swaps in `Look.live(dark:)`: the Paper Club STRUCTURE (id `.carbon`
//   in dark, `.paper` in light — round set markers, pencil→ink draft fields in dashed boxes,
//   round check circles with the stamp + ripple, the circular outlined icon buttons, the
//   bordered equipment row, dashed Add Set, the inverse rest slab with 48 pt +15s / Skip, the
//   Add block and "Discard Workout…" at the end) drawn with Floodlight's palette, its violet
//   Ultra action and its SF Pro Expanded type. The yellow highlighter "New best" sticker is the
//   one borrowed accent. Cardio focus and every sheet over the cover stay plain Floodlight.
//
// FLOODLIGHT LIGHT — tokens (sRGB) and measured WCAG contrast
// Grounds: ground #F2F3F5 (cool near-white) · groundSheet #F2F3F5 · surface / surfaceSheet
// #FFFFFF (white panels) with hairline ink @ 10 % · surfaceRaised / field / controlFill #EBEDF0 ·
// pressedFill #E3E6EA · dash ink @ 34 % · ringTrack #DCDFE4 · comparisonLast #9BA0A8 (a bar).
// Text on ground #F2F3F5 / surface #FFFFFF / raised #EBEDF0:
//   textPrimary          #0B0C0E  17.62  19.57  16.68
//   textSecondary        #555A63   6.24   6.93   5.91
//   textTertiary         #62676F   5.13   5.69   4.85
//   action / actionText  #7A2EE0   5.74   6.37   5.43   (Ultra, deepened for light)
//   heartRate            #C41D58   5.16   5.73   4.89
//   destructive          #BF3510   5.07   5.63   4.80
//   warmup               #555A63   6.24   6.93   5.91
//   family.chest         #A84C00   5.11   5.68   4.84
//   family.back          #1D63CC   5.10   5.66   4.83
//   family.shoulders     #06736B   5.15   5.72   4.88
//   family.arms          #786800   5.01   5.56   4.74
//   family.legs          #367318   5.22   5.80   4.94
//   zone0 … zone5        #62676F 5.13 · #8E4E6C 5.47 · #A63D69 5.42 · #BF1F5C 5.30 ·
//                        #A0124B 7.05 · #7A0A39 9.80 (on ground; ≥ 4.85 on raised)
// Pairs:
//   onAction #FFFFFF on action #7A2EE0            6.37
//   onDone #FFFFFF on done #0B0C0E               19.57
//   onPositive #16140F on highlighter #FFE14A    14.13
//   warm-up digit #FFFFFF on W disc #6A6F78       5.05
//   rest slab: #F4F6F8 on #0B0C0E                18.06
//   rest slab: #A4A9B1 on #0B0C0E                 8.28
//   rest ring Ultra #B25CFF on the ink slab       5.47  (live stays bright Ultra on the slab)
//   textSecondary on pressed #E3E6EA              5.54
// Muscle maps: body layer #C9CDD4 (lit views) / #D9DCE1 (unlit), unlit muscle #B3B8C0; lit
// muscles take the deepened family colours above, so a lit group reads at a glance on white.
// Dark-live extras: onDone #181A1E on done #F4F6F8 16.08; W digit #181A1E on #8E949D 5.70;
// "Discard Workout…" #FF5E3A on #181A1E 5.74 (light: #BF3510 on #FFFFFF 5.63).
// Non-text on the ink slab (≥ 3:1): +15s edge #6E737C 4.11; the heart-rate rest glyph
// #C41D58 3.41 (light only — its bpm figures are #F4F6F8).
// Surfaces that are always dark (the scan camera) use `darkCounterpart` (Floodlight dark).

extension Look {
    /// "Floodlight Light" (tokens and contrast in the header above).
    static let floodlightLight: Look = {
        let ink = Color(hex: 0x0B0C0E)
        let dim = Color(hex: 0x555A63)
        let violet = Color(hex: 0x7A2EE0)
        let families: [MuscleFamily: Color] = [
            .chest: Color(hex: 0xA84C00), .back: Color(hex: 0x1D63CC), .shoulders: Color(hex: 0x06736B),
            .arms: Color(hex: 0x786800), .legs: Color(hex: 0x367318)]
        var look = Look.floodlight
        look.colorScheme = .light
        look.ground = Color(hex: 0xF2F3F5)
        look.groundSheet = Color(hex: 0xF2F3F5)
        look.surface = .white
        look.surfaceSheet = .white
        look.surfaceRaised = Color(hex: 0xEBEDF0)
        look.field = Color(hex: 0xEBEDF0)
        look.pressedFill = Color(hex: 0xE3E6EA)
        look.hairline = ink.opacity(0.10)
        look.dash = ink.opacity(0.34)
        look.textPrimary = ink
        look.textSecondary = dim
        look.textTertiary = Color(hex: 0x62676F)
        look.action = violet
        look.onAction = .white
        look.actionText = violet
        look.live = violet
        look.selection = ink
        look.selectionFill = ink.opacity(0.07)
        look.done = ink
        look.onDone = .white
        look.positive = ink
        look.onPositive = .white
        look.heartRate = Color(hex: 0xC41D58)
        look.destructive = Color(hex: 0xBF3510)
        look.warmup = dim
        look.drop = ink
        look.failure = ink
        look.warmupMarker = Color(hex: 0x6A6F78)
        look.slab = Color.white.opacity(0.80)
        look.slabEdge = ink.opacity(0.10)
        look.onSlab = ink
        look.onSlabSecondary = dim
        look.ringTrack = Color(hex: 0xDCDFE4)
        look.comparisonLast = Color(hex: 0x9BA0A8)
        look.glassTint = Color.white.opacity(0.66)
        look.glassEdge = ink.opacity(0.10)
        look.unitKg = dim
        look.unitLb = dim
        look.zoneRamp = [0x62676F, 0x8E4E6C, 0xA63D69, 0xBF1F5C, 0xA0124B, 0x7A0A39].map { Color(hex: $0) }
        look.familyColors = families
        look.familyTints = families.mapValues { $0.opacity(0.10) }
        look.mapBody = Color(hex: 0xC9CDD4)
        look.mapBodyUnlit = Color(hex: 0xD9DCE1)
        look.mapMuscleUnlit = Color(hex: 0xB3B8C0)
        look.controlFill = Color(hex: 0xEBEDF0)
        look.chipFill = Color(hex: 0xE6E8EC)
        look.segmentFill = ink.opacity(0.09)
        look.pillFill = Color(hex: 0xE6E8EC)
        look.pillEdge = ink.opacity(0.10)
        look.dayDotPast = Color(hex: 0xD3D6DB)
        look.dayDotFuture = Color(hex: 0xE6E8EC)
        return look
    }()

    static let liveDark = live(dark: true)
    static let liveLight = live(dark: false)

    /// The live lifting workout: Paper Club structure with Floodlight's palette, Ultra action
    /// and Expanded type.
    static func live(dark: Bool) -> Look {
        let skin: Look = dark ? .floodlight : .floodlightLight
        var look = Look.paperClubStructure(dark: dark)
        look.colorScheme = skin.colorScheme

        // Grounds: the card is the sheet on the page; wells (fields, the equipment row) are
        // holes back through to the ground, as in Paper.
        look.ground = skin.ground
        look.groundSheet = skin.ground
        look.surface = skin.surface
        look.surfaceSheet = skin.surface
        look.surfaceRaised = skin.ground
        look.field = skin.ground
        look.pressedFill = skin.pressedFill
        look.innerHighlight = .clear
        look.hairline = skin.textPrimary.opacity(dark ? 0.16 : 0.16)
        look.dash = skin.textPrimary.opacity(dark ? 0.40 : 0.42)
        // Paper's "you can press this" outline, in Floodlight's ink / flood (softened a touch
        // in dark so the flood outlines do not glare against the black ground).
        look.outline = dark ? skin.textPrimary.opacity(0.82) : skin.textPrimary

        look.textPrimary = skin.textPrimary
        look.textSecondary = skin.textSecondary
        look.textTertiary = skin.textSecondary

        // Ultra replaces cobalt as the action; the live instrument stays bright Ultra (it
        // drains on the ink slab in both schemes).
        look.action = skin.action
        look.onAction = skin.onAction
        look.actionText = skin.actionText
        look.live = Color(hex: 0xB25CFF)
        look.selection = skin.actionText
        look.selectionFill = skin.pressedFill
        look.segmentFill = skin.action

        look.done = skin.textPrimary
        look.onDone = skin.surface
        // The one borrowed accent: Paper's yellow highlighter for a new best.
        look.positive = Color(hex: 0xFFE14A)
        look.onPositive = Color(hex: 0x16140F)

        look.heartRate = skin.heartRate
        look.destructive = skin.destructive
        look.warmup = skin.textSecondary
        look.drop = skin.textPrimary
        look.failure = skin.textPrimary
        look.warmupMarker = dark ? Color(hex: 0x8E949D) : Color(hex: 0x6A6F78)

        // The inverse rest slab: ink in light (as Paper), pure black edged in flood in dark.
        look.slab = dark ? .black : Color(hex: 0x0B0C0E)
        look.slabEdge = dark ? Color(hex: 0xF4F6F8).opacity(0.22) : Color(hex: 0x0B0C0E)
        look.onSlab = Color(hex: 0xF4F6F8)
        look.onSlabSecondary = Color(hex: 0xA4A9B1)

        look.ringTrack = skin.ringTrack
        look.comparisonLast = skin.comparisonLast
        // The primary's hard offset: ink in light, a deep Ultra shade in dark.
        look.shadowInk = dark ? Color(hex: 0x4A2470) : Color(hex: 0x0B0C0E)
        look.glassTint = skin.glassTint
        look.glassEdge = skin.glassEdge
        look.unitKg = skin.unitKg
        look.unitLb = skin.unitLb
        look.zoneRamp = skin.zoneRamp
        look.familyColors = skin.familyColors
        look.familyTints = skin.familyTints
        look.mapBody = skin.mapBody
        look.mapBodyUnlit = skin.mapBodyUnlit
        look.mapMuscleUnlit = skin.mapMuscleUnlit

        look.controlFill = skin.surface
        look.chipFill = skin.surface
        look.pillFill = .clear
        look.pillEdge = Color(hex: 0x6E737C)
        look.dayDotPast = skin.dayDotPast
        look.dayDotFuture = skin.dayDotFuture

        // Floodlight's type: Expanded Black / Heavy titles and numerals, never New York.
        look.font = .floodlight
        look.font.fieldNumber = Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit()
        return look
    }
}

extension Look {
    /// The same look's dark finish, for surfaces that are always dark (the scan camera).
    var darkCounterpart: Look { isDark ? self : .floodlight }

    /// A wash of the look's ink over its surfaces: white in the dark finishes (unchanged from
    /// the studies' `Color.white.opacity`), the text ink in light ones.
    func wash(_ opacity: Double) -> Color {
        isDark ? Color.white.opacity(opacity) : textPrimary.opacity(opacity)
    }

    /// Drop shadows under floating chrome: the dark studies' heavy black, lighter in light.
    func floatShadow(_ opacity: Double) -> Color {
        Color.black.opacity(isDark ? opacity : opacity * 0.28)
    }
}
