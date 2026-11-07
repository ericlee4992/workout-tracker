import SwiftUI

// Soft Light and the live-workout look (D67, the user's decision 2026-11-07; it replaces D59's
// Floodlight look). Settings → Appearance (System / Light / Dark) picks `Look.softLight` (below)
// or `Look.softDark` (Look.swift).
//
// • The live lifting workout swaps in `Look.live(dark:)`: the Paper Club STRUCTURE (id `.carbon`
//   in dark, `.paper` in light — round set markers, pencil→ink draft fields in dashed boxes,
//   round check circles with the stamp + ripple, the circular outlined icon buttons, the
//   bordered equipment row, dashed Add Set, the inverse rest slab with 48 pt +15s / Skip, the
//   Add block at the end; Cancel in the toolbar since live-workout-fixes 02) drawn with Soft's
//   palette and SF Pro type, its Mono action FLAT (no hard offset shadow). The yellow highlighter
//   "New best" sticker is the one borrowed accent. Cardio focus and every sheet over the cover
//   stay plain Soft. Its layout is unchanged (skin only, soft-redesign S1).
//
// SOFT LIGHT — tokens (sRGB) and measured WCAG contrast
// Grounds: ground #F5F5F7 with a warm wash (#F7E7DA @ 75 %, radial from the top trailing corner)
// · groundSheet #F5F5F7 · surface / surfaceSheet #FFFFFF (white cards on a black 6 % shadow,
// radius 18, y 6; no outline) · surfaceRaised / field / controlFill #F1F1F4 · pressedFill #EAEAEE
// · hairline ink @ 7 % · dash ink @ 28 % · ringTrack #ECECF1.
// Text on ground #F5F5F7 / surface #FFFFFF / raised #F1F1F4:
//   textPrimary          #111114  17.31  18.85  16.6
//   textSecondary        #5C5C62   6.10   6.6    5.89  (the prototype's #6C6C72, deepened)
//   textTertiary         #6C6C72   4.79   5.22   4.63  (the prototype's #8A8A90 was 3.43)
//   action / actionText  #111114  (Mono: ink) — onAction #FFFFFF on it 18.85
//   heartRate            #C41D58   5.16   5.73   4.89
//   destructive          #BF3510   5.17   5.63   4.80
//   family colours: Floodlight Light's deepened set (each ≥ 4.8 on raised), unchanged.
// The live workout's rest slab stays ink #0B0C0E with flood #F4F6F8 (18.06); its live ring and
// Skip pill are flood (`liveOnSlabOverride`, set in `live(dark:)`), because the Mono action is ink.
// Surfaces that are always dark (the scan camera) use `darkCounterpart` (Soft dark).

extension Look {
    /// Soft, light (tokens and contrast in the header above).
    static let softLight: Look = {
        let ink = Color(hex: 0x111114)
        let dim = Color(hex: 0x5C5C62)
        let families: [MuscleFamily: Color] = [
            .chest: Color(hex: 0xA84C00), .back: Color(hex: 0x1D63CC), .shoulders: Color(hex: 0x06736B),
            .arms: Color(hex: 0x786800), .legs: Color(hex: 0x367318)]
        var look = Look.softDark
        look.colorScheme = .light
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
        look.textSecondary = dim
        look.textTertiary = Color(hex: 0x6C6C72)
        look.action = ink
        look.onAction = .white
        look.actionText = ink
        look.live = ink
        look.selection = ink
        look.selectionFill = ink.opacity(0.06)
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
        look.slab = Color.white.opacity(0.86)
        look.slabEdge = ink.opacity(0.10)
        look.onSlab = ink
        look.onSlabSecondary = dim
        look.ringTrack = Color(hex: 0xECECF1)
        look.comparisonLast = Color(hex: 0x9BA0A8)
        look.glassTint = Color.white.opacity(0.7)
        look.glassEdge = ink.opacity(0.10)
        look.unitKg = dim
        look.unitLb = dim
        look.zoneRamp = [0x62676F, 0x8E4E6C, 0xA63D69, 0xBF1F5C, 0xA0124B, 0x7A0A39].map { Color(hex: $0) }
        look.familyColors = families
        look.familyTints = families.mapValues { $0.opacity(0.10) }
        look.mapBody = Color(hex: 0xC9CDD4)
        look.mapBodyUnlit = Color(hex: 0xD9DCE1)
        look.mapMuscleUnlit = Color(hex: 0xB3B8C0)
        look.controlFill = Color(hex: 0xF1F1F4)
        look.chipFill = Color(hex: 0xF1F1F4)
        look.segmentFill = .white
        look.pillFill = .white
        look.pillEdge = ink.opacity(0.12)
        look.groundWash = Color(hex: 0xF7E7DA).opacity(0.75)
        look.dayDotPast = Color(hex: 0xD3D6DB)
        look.dayDotFuture = Color(hex: 0xE6E8EC)
        return look
    }()

    static let liveDark = live(dark: true)
    static let liveLight = live(dark: false)

    /// The live lifting workout: Paper Club structure with Soft's palette, the flat Mono action
    /// and SF Pro type (the approved prototype's `LiveWorkoutScreen.liveLook` for Soft).
    static func live(dark: Bool) -> Look {
        let skin: Look = dark ? .softDark : .softLight
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
        // Soft keeps Paper's outlines but quiet: hairline 8 %, dashes 30 %, pressable edges 18 %.
        look.hairline = skin.textPrimary.opacity(0.08)
        look.dash = skin.textPrimary.opacity(0.30)
        look.outline = skin.textPrimary.opacity(0.18)

        look.textPrimary = skin.textPrimary
        look.textSecondary = skin.textSecondary
        look.textTertiary = skin.textSecondary

        // The Mono action (ink in light, flood in dark); on the ink rest slab the live ring is
        // flood in both schemes.
        look.action = skin.action
        look.onAction = skin.onAction
        look.actionText = skin.actionText
        look.live = skin.action
        look.liveOnSlabOverride = Color(hex: 0xF4F6F8)
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
        // Flat (the user: "make it plain 2d"): no hard offset under the primary.
        look.shadowInk = .clear
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

        // Soft's type and corner radii; Soft cards lift in light as everywhere else.
        look.font = .soft
        look.radius = skin.radius
        look.liftedCards = skin.liftedCards
        look.groundWash = skin.groundWash
        return look
    }
}

extension Look {
    /// The same look's dark finish, for surfaces that are always dark (the scan camera).
    var darkCounterpart: Look { isDark ? self : .softDark }

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
