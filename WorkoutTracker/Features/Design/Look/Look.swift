import SwiftUI

// The visual system every screen is written against. Tokens are named BY MEANING, never by
// hue; components read `@Environment(\.look)` and switch on `look.id` only where the design
// defines a different structural treatment.
//
// The user's chosen look ("Soft", D67, 2026-11-07; it replaces D59's Floodlight look):
// • Everywhere: SF Pro only (bold titles, semibold figures), a light ground with a faint warm
//   wash at the top, white cards lifted on a wide faint shadow (dark: graphite cards with a
//   hairline on black), the Mono action (black in light, white in dark), flat buttons. Dark
//   (`Look.softDark`) or light (`Look.softLight`, FinalLook.swift), picked by Settings →
//   Appearance (System / Light / Dark).
// • The live lifting workout keeps Paper Club's STRUCTURE (round set markers, dashed draft
//   fields, stamp check circles, outlined icon buttons, the inverse rest slab) drawn in Soft's
//   palette and type with a flat Mono action (`Look.live(dark:)`). Its structural id is
//   `.carbon` in dark and `.paper` in light; nothing else in the app uses those ids.
// • The structural id elsewhere is still called `.floodlight`: it names the layout family the
//   components were built in (segmented rings, the Start capsules…), which Soft keeps.
//
// Source: the approved prototype, tag design/soft-approved-2026-11-07 (DesignPrototype/Sources/
// Look/SoftLook.swift), work-record/soft-redesign/issues/01-soft-look.md.

// MARK: - Look identity

/// The structural family a `Look` is drawn in (`look.id`). `.floodlight` everywhere (the layout
/// family Soft keeps); `.paper` (light) or `.carbon` (dark) inside the live lifting workout.
enum LookStyle: String, CaseIterable, Hashable {
    case floodlight, paper, carbon

    /// The Paper Club structure (the live lifting workout), either scheme.
    var isPaperClub: Bool { self == .paper || self == .carbon }
}

/// Settings → Appearance. Stored per device in `UserDefaults` (`AppearanceSetting.key`), not in
/// the synced SwiftData store: it is a display preference and must be readable before the model
/// container opens (the window's colour scheme is set at launch).
enum Appearance: String, CaseIterable, Identifiable, Hashable {
    case system, light, dark

    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    /// nil = follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppearanceSetting {
    static let key = "appearance"
    /// The stored value; an unknown or missing value is System.
    static func resolve(_ raw: String?) -> Appearance {
        raw.flatMap(Appearance.init(rawValue:)) ?? .system
    }
}

// MARK: - Fonts by role

/// Every role is built from a Dynamic Type text style, so all of it scales.
struct LookFonts {
    // Text styles by role
    var largeTitle: Font
    var title: Font
    var title2: Font
    var title3: Font
    var headline: Font
    var body: Font
    var callout: Font
    var subhead: Font
    var footnote: Font
    var caption: Font
    var caption2: Font
    // Numerals (monospaced digits)
    /// 34 pt class: big hero figures.
    var heroNumber: Font
    /// 28 pt class: finish tiles, rest time.
    var bigNumber: Font
    /// 22 pt class: vitals, week footer.
    var statNumber: Font
    /// 20 pt class: family set counts, day minutes, set markers.
    var smallNumber: Font
    /// 17 pt class: set field values, best sets in lists.
    var fieldNumber: Font
    /// The live clock WITH seconds (medium-large, never a hero).
    var timer: Font
    // Controls and chrome
    var button: Font
    var tabLabel: Font
    var navTitle: Font
    /// Section titles inside a page ("This week", "Workout details", "Heart rate").
    var sectionTitle: Font
    /// The top-level section of a tab page (Home "Templates").
    var pageSectionTitle: Font
    /// Exercise card titles.
    var cardTitle: Font
    /// Template tile names.
    var tileTitle: Font
    /// SET · PREVIOUS · WEIGHT · REPS (apply `look.columnTracking`).
    var columnHeader: Font
    var badge: Font
}

private enum Face { case text }

private func face(_ style: Font.TextStyle, _ kind: Face, _ weight: Font.Weight, mono: Bool = false) -> Font {
    var font: Font
    switch kind {
    case .text: font = .system(style, design: .default, weight: weight)
    }
    return mono ? font.monospacedDigit() : font
}

extension LookFonts {
    /// Soft (D67): SF Pro only — bold titles, semibold figures, no Expanded or Black.
    static let soft = LookFonts(
        largeTitle: face(.largeTitle, .text, .bold),
        title: face(.title, .text, .bold),
        title2: face(.title2, .text, .bold),
        title3: face(.title3, .text, .semibold),
        headline: face(.headline, .text, .semibold),
        body: face(.body, .text, .regular),
        callout: face(.callout, .text, .regular),
        subhead: face(.subheadline, .text, .regular),
        footnote: face(.footnote, .text, .regular),
        caption: face(.caption, .text, .regular),
        caption2: face(.caption2, .text, .regular),
        heroNumber: face(.largeTitle, .text, .semibold, mono: true),
        bigNumber: face(.title, .text, .semibold, mono: true),
        statNumber: face(.title2, .text, .semibold, mono: true),
        smallNumber: face(.title3, .text, .semibold, mono: true),
        fieldNumber: face(.headline, .text, .semibold, mono: true),
        timer: face(.title, .text, .semibold, mono: true),
        button: face(.headline, .text, .semibold),
        tabLabel: face(.caption2, .text, .semibold),
        navTitle: face(.headline, .text, .semibold),
        sectionTitle: face(.title3, .text, .semibold),
        pageSectionTitle: face(.title2, .text, .bold),
        cardTitle: face(.title3, .text, .semibold),
        tileTitle: face(.headline, .text, .semibold),
        columnHeader: face(.caption2, .text, .medium),
        badge: face(.caption, .text, .semibold))
}

// MARK: - Geometry, strokes, motion

struct LookRadii {
    /// Panels / content cards / week card.
    var panel: CGFloat
    /// Template tiles and make tiles.
    var tile: CGFloat
    /// Stat tiles / tickets / vitals strip.
    var stat: CGFloat
    /// Inner rows: equipment row, Add Set slot.
    var row: CGFloat
    /// Editable fields and wells.
    var field: CGFloat
    /// Floating bars (rest bar).
    var bar: CGFloat
    /// New-best mark / sticker.
    var badge: CGFloat
    /// Set marker box (Floodlight square-ish; the live workout's circles use half their size).
    var marker: CGFloat
    /// Sheet top corners.
    var sheet: CGFloat
}

struct LookSpacing {
    /// Side margin: 20 pt on every screen.
    var margin: CGFloat = 20
    /// Between sections.
    var section: CGFloat
    /// Inside a group / grid gaps.
    var group: CGFloat
    /// Section header to its content.
    var header: CGFloat
    /// Inside panels.
    var panelPadding: CGFloat
    /// Grid gap between tiles.
    var grid: CGFloat
}

struct LookStrokes {
    /// Hairline separators and information edges.
    var hairline: CGFloat
    /// The outline that means "you can press this" (live workout only; 0 elsewhere).
    var pressable: CGFloat
    /// Outline around the one primary command (live workout only).
    var primary: CGFloat
    /// Dashed edges ("make one", Add Set, drafts).
    var dashed: CGFloat
}

struct LookMotion {
    /// Scale while a pressable is held (1 = no scale).
    var pressScale: CGFloat
    /// Live workout: the primary physically sinks into its hard shadow by this much.
    var pressSink: CGFloat
    /// Opacity used for press feedback under Reduce Motion.
    var reducedPressOpacity: Double
    /// Floodlight: segmented rings; live workout: arcs.
    var segmentedRings: Bool
    /// Stamp entry: scale and rotation the check drops in from.
    var stampScale: CGFloat
    var stampRotation: Double
    /// How long a muscle map takes to light on entry.
    var mapLightDuration: Double
}

// MARK: - The look

struct Look {
    /// The structural family (what components switch on).
    var id: LookStyle
    /// The scheme this token set is drawn for.
    var colorScheme: ColorScheme = .dark

    // Grounds and surfaces
    /// Screen ground.
    var ground: Color
    /// Sheet ground (the elevated base of modals).
    var groundSheet: Color
    /// Panels, cards, tiles (content surfaces) on the ground.
    var surface: Color
    /// Content surfaces on a sheet.
    var surfaceSheet: Color
    /// Raised inner surfaces: cells, the machine row, the secondary button.
    var surfaceRaised: Color
    /// Editable fields (draft weight / reps).
    var field: Color
    /// Fill of a pressable while pressed / tinted chrome.
    var pressedFill: Color
    /// Separators and information edges.
    var hairline: Color
    /// A top inner highlight on cards (clear in this design).
    var innerHighlight: Color
    /// The dashed edge of an open draft field / make tile.
    var dash: Color
    /// Outline that marks pressable things (live workout; clear elsewhere).
    var outline: Color

    // Text tiers
    var textPrimary: Color
    var textSecondary: Color
    var textTertiary: Color

    // Meanings
    /// The one action / "now" (fill of the primary command).
    var action: Color
    /// Labels and glyphs on `action`.
    var onAction: Color
    /// The action meaning as text, rings and marks.
    var actionText: Color
    /// A live instrument (rest ring, live progress).
    var live: Color
    /// Selection as a state (selected tab, chip, segment) — glyph/label colour.
    var selection: Color
    /// Selection fill (the lozenge behind a selected tab / segment).
    var selectionFill: Color
    /// Done / lit / inked (completed set, trained day, stamp).
    var done: Color
    var onDone: Color
    /// A new best (PR).
    var positive: Color
    var onPositive: Color
    var heartRate: Color
    /// Destructive controls.
    var destructive: Color
    // Set kinds
    var warmup: Color
    var drop: Color
    var failure: Color
    /// Background of the "W" marker when it is a filled disc / outline colour.
    var warmupMarker: Color
    // Instruments (the live rest slab; Floodlight's glass bars)
    var slab: Color
    var slabEdge: Color
    var onSlab: Color
    var onSlabSecondary: Color
    // Rings and charts
    var ringTrack: Color
    /// "Last time" bar in comparisons.
    var comparisonLast: Color
    /// The live workout's hard offset shadow under the primary (clear in Soft: flat buttons).
    var shadowInk: Color
    /// Floating chrome tint (tab bar, toolbar buttons, rest bar).
    var glassTint: Color
    var glassEdge: Color
    /// Unit suffixes ("lb", "kg") — plain.
    var unitKg: Color
    var unitLb: Color
    /// HR zone ramp, index 0 (Warm-up) … 5.
    var zoneRamp: [Color]
    // Muscle families
    var familyColors: [MuscleFamily: Color]
    /// Washes behind maps — the family colour at low strength.
    var familyTints: [MuscleFamily: Color]
    var mapBody: Color
    var mapBodyUnlit: Color
    var mapMuscleUnlit: Color

    var font: LookFonts
    var radius: LookRadii
    var space: LookSpacing
    var stroke: LookStrokes
    var motion: LookMotion
    /// Tracking for the uppercase column header (+6 %).
    var columnTracking: CGFloat = 0.66

    // Control fills (kept here so components never hard-code a hex)
    /// Round icon buttons / discs / stepper tracks inside content.
    var controlFill: Color
    /// The gym chip in the live header.
    var chipFill: Color
    /// Selected chip / segment fill.
    var segmentFill: Color
    /// The quiet rest-bar pill (+15s): fill and edge.
    var pillFill: Color
    var pillEdge: Color
    /// Week-strip dots for untrained days: past and future.
    var dayDotPast: Color
    var dayDotFuture: Color

    // Soft (D67)
    /// The live colour on the live workout's ink rest slab (`Look.live(dark:)` sets it: the Mono
    /// action is ink in light and would vanish there).
    var liveOnSlabOverride: Color? = nil
    /// Content cards (panel, card, stat, tile) sit on a wide faint shadow without an outline in
    /// light, and on a hairline in dark.
    var liftedCards = false
    /// A faint warm wash at the top of every screen ground (light only; nil = none).
    var groundWash: Color? = nil

    var liveOnSlab: Color { liveOnSlabOverride ?? live }

    func family(_ family: MuscleFamily) -> Color { familyColors[family] ?? textSecondary }
    func familyTint(_ family: MuscleFamily) -> Color { familyTints[family] ?? surfaceRaised }
    func zone(_ zone: HeartRateZone) -> Color { zoneRamp[zone.rawValue] }
    func unit(_ unit: WeightUnit) -> Color { unit == .kg ? unitKg : unitLb }
    var isDark: Bool { colorScheme == .dark }

    /// The app's token set for a resolved colour scheme.
    static func app(_ scheme: ColorScheme) -> Look {
        scheme == .light ? .softLight : .softDark
    }
}

// MARK: - Soft (dark)

extension Look {
    /// Soft, dark (D67): black ground, graphite cards with a hairline, the Mono action in flood.
    /// Text on surface #1C1C1E / raised #2C2C2E: primary #F5F5F7 15.63 · secondary #A1A1A8 6.63 /
    /// 5.43 · tertiary #949499 5.64 / 4.62 (the prototype's #98989F / #7C7C82 deepened to pass
    /// 4.5:1 on raised cells). onAction #000000 on #F5F5F7 19.29.
    static let softDark: Look = {
        let flood = Color(hex: 0xF5F5F7)
        let dim = Color(hex: 0xA1A1A8)
        let ink = Color(hex: 0x000000)
        return Look(
            id: .floodlight,
            ground: .black,
            groundSheet: Color(hex: 0x0E0E10),
            surface: Color(hex: 0x1C1C1E),
            surfaceSheet: Color(hex: 0x1C1C1E),
            surfaceRaised: Color(hex: 0x2C2C2E),
            field: Color(hex: 0x2C2C2E),
            pressedFill: Color(hex: 0x2A2D33),
            hairline: .white.opacity(0.08),
            innerHighlight: .clear,
            dash: .white.opacity(0.28),
            outline: .clear,
            textPrimary: flood,
            textSecondary: dim,
            textTertiary: Color(hex: 0x949499),
            action: flood,
            onAction: ink,
            actionText: flood,
            live: flood,
            selection: flood,
            selectionFill: .white.opacity(0.11),
            done: flood,
            onDone: ink,
            positive: flood,
            onPositive: ink,
            heartRate: Color(hex: 0xFF4F86),
            destructive: Color(hex: 0xFF5E3A),
            warmup: dim,
            drop: flood,
            failure: flood,
            warmupMarker: dim.opacity(0.62),
            slab: Color(hex: 0x16181C).opacity(0.86),
            slabEdge: .white.opacity(0.12),
            onSlab: flood,
            onSlabSecondary: dim,
            ringTrack: Color(hex: 0x2C2C2E),
            comparisonLast: Color(hex: 0x686D76),
            shadowInk: .clear,
            glassTint: Color(hex: 0x22252B).opacity(0.62),
            glassEdge: .white.opacity(0.12),
            unitKg: dim,
            unitLb: dim,
            zoneRamp: [0x7F858E, 0x9A5270, 0xC2577F, 0xE65C8E, 0xFF77A5, 0xFFB0CA].map { Color(hex: $0) },
            familyColors: [.chest: Color(hex: 0xFFA03C), .back: Color(hex: 0x3D9EFF), .shoulders: Color(hex: 0x4DE0D4),
                           .arms: Color(hex: 0xFFE15C), .legs: Color(hex: 0x84D65A)],
            familyTints: [.chest: Color(hex: 0xFFA03C).opacity(0.16), .back: Color(hex: 0x3D9EFF).opacity(0.16),
                          .shoulders: Color(hex: 0x4DE0D4).opacity(0.16), .arms: Color(hex: 0xFFE15C).opacity(0.16),
                          .legs: Color(hex: 0x84D65A).opacity(0.16)],
            mapBody: Color(hex: 0x535862),
            mapBodyUnlit: Color(hex: 0x464A52),
            mapMuscleUnlit: Color(hex: 0x737983),
            font: .soft,
            radius: LookRadii(panel: 24, tile: 22, stat: 20, row: 14, field: 12, bar: 28, badge: 8, marker: 10, sheet: 38),
            space: LookSpacing(section: 26, group: 12, header: 14, panelPadding: 18, grid: 12),
            stroke: LookStrokes(hairline: 1, pressable: 0, primary: 0, dashed: 1.5),
            motion: LookMotion(pressScale: 0.97, pressSink: 0, reducedPressOpacity: 0.7, segmentedRings: true,
                               stampScale: 1.55, stampRotation: -14, mapLightDuration: 0.2),
            controlFill: Color(hex: 0x22252A),
            chipFill: Color(hex: 0x0F1012),
            segmentFill: .white.opacity(0.14),
            pillFill: Color(hex: 0x222427),
            pillEdge: .white.opacity(0.12),
            dayDotPast: Color(hex: 0x34373D),
            dayDotFuture: Color(hex: 0x22252A),
            liftedCards: true)
    }()
}

// MARK: - Paper Club structure (the base of the live workout only)

extension Look {
    /// The Paper Club structure the live workout is drawn in: its radii, strokes, spacing and
    /// motion. `Look.live(dark:)` replaces every colour and the type with Soft's.
    static func paperClubStructure(dark: Bool) -> Look {
        var look = Look.softDark
        look.id = dark ? .carbon : .paper
        look.colorScheme = dark ? .dark : .light
        look.radius = LookRadii(panel: 18, tile: 18, stat: 16, row: 12, field: 10, bar: 24, badge: 6, marker: 17, sheet: 36)
        look.space = LookSpacing(section: 30, group: 12, header: 12, panelPadding: 14, grid: 12)
        look.stroke = LookStrokes(hairline: 1.5, pressable: 2, primary: 2.5, dashed: 2)
        look.motion = LookMotion(pressScale: 1, pressSink: 4, reducedPressOpacity: 0.8, segmentedRings: false,
                                 stampScale: 1.7, stampRotation: -16, mapLightDuration: 0.32)
        return look
    }
}

// MARK: - Per-look symbols and labels

extension Look {
    /// The gym pin: a location pin, never a thumbtack.
    var gymSymbol: String { "mappin.and.ellipse" }

    /// The exercise card's previous-performance button.
    var previousPerformanceSymbol: String { id == .floodlight ? "chart.bar.xaxis" : "chart.line.uptrend.xyaxis" }

    /// Rest-bar next-set line: Floodlight keeps the unit ("Next · Set 3 · 110 lb × 8"); the live
    /// workout drops it when it matches the row ("Next · Set 3 · 110 × 8").
    /// `value == nil` gives "Next · Set 3".
    func nextSetLabel(number: Int, value: SetValue?, rowUnit: WeightUnit, loadType: LoadType = .weighted) -> String {
        guard let value else { return "Next · Set \(number)" }
        return "Next · Set \(number) · \(previousLabel(value, rowUnit: rowUnit, loadType: loadType))"
    }

    /// Rest-bar line when the next set belongs to another exercise: "Next · Incline Chest Press".
    func nextExerciseLabel(_ exercise: String) -> String { "Next · \(exercise)" }

    /// A template's last-done date: "Sep 23".
    func lastDoneLabel(_ date: Date, now: Date) -> String {
        LookFormat.shortDate(date)
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var look: Look = .softDark
    /// true inside a sheet: content surfaces use `surfaceSheet`.
    @Entry var lookOnSheet: Bool = false
    /// true inside an instrument slab (the live rest bar): text uses `onSlab`.
    @Entry var lookOnSlab: Bool = false
}

extension View {
    /// Injects a look and pins its colour scheme (sub-presentations that re-apply the look).
    func look(_ look: Look) -> some View {
        environment(\.look, look).preferredColorScheme(look.colorScheme)
    }

    /// Injects the app look for a presentation layer (window root, sheets, covers): the scheme
    /// follows Settings → Appearance (System leaves it to the device), and the light / dark
    /// token set follows the scheme that results.
    func lookLayer() -> some View {
        modifier(LookLayerModifier())
    }
}

extension View {
    /// A sheet presented from inside the live workout's Paper look (a card's Bar or Rest sheet):
    /// back to plain Floodlight in the same scheme, like every other sheet over the cover.
    func floodlightSheet(from look: Look) -> some View {
        environment(\.look, Look.app(look.isDark ? .dark : .light))
    }
}

private struct LookLayerModifier: ViewModifier {
    @AppStorage(AppearanceSetting.key) private var appearanceRaw = Appearance.system.rawValue
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let appearance = AppearanceSetting.resolve(appearanceRaw)
        content
            .environment(\.look, Look.app(appearance.colorScheme ?? systemScheme))
            .preferredColorScheme(appearance.colorScheme)
    }
}

// MARK: - Colour helper

extension Color {
    /// `Color(hex: 0xF5F5F7)`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
