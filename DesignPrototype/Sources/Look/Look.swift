import SwiftUI
import Observation

// The visual system every screen is written against. Four looks share one set of
// tokens BY MEANING (never by hue name); components read `@Environment(\.look)`
// and switch on `look.id` only where a direction SPEC defines a different
// treatment. Hex values are copied from directions/{A,B,C}/SPEC.md.

// MARK: - Look identity

/// The switcher's choices. `final` (the user's pick: Floodlight everywhere, with Paper Club's
/// live-workout structure re-skinned in Floodlight, light or dark) comes first, so it is the
/// launch default. Components never switch on this: they switch on `look.id` (`LookStyle`),
/// the structural family a `Look` value is drawn in.
enum LookID: String, CaseIterable, Identifiable, Hashable {
    case final, floodlight, anatomy, paper, carbon, soft

    var id: String { rawValue }

    /// Switcher / gallery name.
    var displayName: String {
        switch self {
        case .final: "★ Floodlight + Paper workout"
        case .floodlight: "A · Floodlight"
        case .anatomy: "B · Anatomy"
        case .paper: "C · Paper"
        case .carbon: "C · Carbon"
        case .soft: "Soft"
        }
    }

    /// Compact label for tight chrome.
    var shortLabel: String {
        switch self {
        case .final: "★"
        case .floodlight: "A"
        case .anatomy: "B"
        case .paper: "C"
        case .carbon: "C·dk"
        case .soft: "S"
        }
    }

    /// Only the final look follows the Appearance setting; the four studies keep their finish.
    var followsAppearance: Bool { self == .final || self == .soft }

    /// The fixed scheme of a study look (`final` resolves through `LookModel.appearance`).
    var fixedColorScheme: ColorScheme? {
        switch self {
        case .final, .soft: nil
        case .paper: .light
        default: .dark
        }
    }

    /// Parses `-look final|floodlight|anatomy|paper|carbon` (also `star`, `a`, `b`, `c`, `paperClub`, `carbonCopy`).
    init?(argument: String) {
        switch argument.lowercased() {
        case "final", "star", "★": self = .final
        case "floodlight", "a": self = .floodlight
        case "anatomy", "b": self = .anatomy
        case "paper", "c", "paperclub": self = .paper
        case "carbon", "carboncopy", "c-dark", "cdark": self = .carbon
        case "soft", "s": self = .soft
        default: return nil
        }
    }

    var next: LookID {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
    var previous: LookID {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + all.count - 1) % all.count]
    }
}

/// The structural family a `Look` is drawn in (`look.id`). Components switch on this for the
/// signature treatments each direction SPEC defines. The final look reports `.floodlight`
/// everywhere, and `.paper` / `.carbon` inside the live lifting workout (FinalLook.swift).
enum LookStyle: String, CaseIterable, Hashable {
    case floodlight, anatomy, paper, carbon

    /// Both Paper Club finishes share layouts and treatments.
    var isPaperClub: Bool { self == .paper || self == .carbon }
}

/// The Appearance setting (Settings → Appearance). Drives the final look's light / dark token
/// set and the app's `preferredColorScheme`; the study looks ignore it.
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
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    init?(argument: String) { self.init(rawValue: argument.lowercased()) }
}

// MARK: - Fonts by role

/// Every role is built from a Dynamic Type text style, so all of it scales.
/// Width (`.expanded`), design (`.rounded` / `.serif`) and weight follow each SPEC's type table.
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
    /// 34 pt class: B's comparison "6%", big hero figures.
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
    /// The top-level section of a tab page (Home "Templates"): B steps up to Title 2 (22).
    var pageSectionTitle: Font
    /// Exercise card titles.
    var cardTitle: Font
    /// Template tile names.
    var tileTitle: Font
    /// SET · PREVIOUS · WEIGHT · REPS (apply `look.columnTracking`).
    var columnHeader: Font
    var badge: Font
}

private enum Face { case text, expanded, rounded, serif }

private func face(_ style: Font.TextStyle, _ kind: Face, _ weight: Font.Weight, mono: Bool = false) -> Font {
    var font: Font
    switch kind {
    case .text: font = .system(style, design: .default, weight: weight)
    case .expanded: font = Font.system(style, design: .default, weight: weight).width(.expanded)
    case .rounded: font = .system(style, design: .rounded, weight: weight)
    case .serif: font = .system(style, design: .serif, weight: weight)
    }
    return mono ? font.monospacedDigit() : font
}

extension LookFonts {
    /// SF Pro text roles shared by every look (body, callout, captions…).
    fileprivate static func textRoles(
        largeTitle: Font, title: Font, title2: Font, title3: Font,
        numbers: Face, numberWeight: Font.Weight, fieldNumber: Font,
        button: Font, navTitle: Font, sectionTitle: Font, pageSectionTitle: Font? = nil,
        cardTitle: Font, tileTitle: Font, columnHeader: Font, badge: Font
    ) -> LookFonts {
        LookFonts(
            largeTitle: largeTitle, title: title, title2: title2, title3: title3,
            headline: face(.headline, .text, .semibold),
            body: face(.body, .text, .regular),
            callout: face(.callout, .text, .regular),
            subhead: face(.subheadline, .text, .regular),
            footnote: face(.footnote, .text, .regular),
            caption: face(.caption, .text, .regular),
            caption2: face(.caption2, .text, .regular),
            heroNumber: face(.largeTitle, numbers, numberWeight, mono: true),
            bigNumber: face(.title, numbers, numberWeight, mono: true),
            statNumber: face(.title2, numbers, numberWeight, mono: true),
            smallNumber: face(.title3, numbers, numberWeight, mono: true),
            fieldNumber: fieldNumber,
            timer: face(.title, numbers, numberWeight, mono: true),
            button: button,
            tabLabel: face(.caption2, .text, .semibold),
            navTitle: navTitle, sectionTitle: sectionTitle, pageSectionTitle: pageSectionTitle ?? sectionTitle,
            cardTitle: cardTitle, tileTitle: tileTitle,
            columnHeader: columnHeader, badge: badge)
    }

    /// A · Floodlight: SF Pro Expanded Black titles, Expanded Heavy numerals; buttons stay standard width (§3).
    static let floodlight = textRoles(
        largeTitle: face(.largeTitle, .expanded, .black),
        title: face(.title, .expanded, .black),
        title2: face(.title2, .expanded, .heavy),
        title3: face(.title3, .expanded, .heavy),
        numbers: .expanded, numberWeight: .heavy,
        fieldNumber: face(.headline, .expanded, .heavy, mono: true),
        button: face(.headline, .text, .bold),
        navTitle: face(.headline, .expanded, .heavy),
        sectionTitle: face(.title3, .expanded, .heavy),
        cardTitle: face(.title3, .expanded, .heavy),
        tileTitle: face(.headline, .expanded, .heavy),
        columnHeader: face(.caption2, .text, .semibold),
        badge: face(.caption, .text, .bold))

    /// B · Anatomy: SF Pro Rounded, heavy numerals, no Black (§2).
    static let anatomy = textRoles(
        largeTitle: face(.largeTitle, .rounded, .bold),
        title: face(.title, .rounded, .heavy),
        title2: face(.title2, .rounded, .bold),
        title3: face(.title3, .rounded, .bold),
        numbers: .rounded, numberWeight: .heavy,
        fieldNumber: face(.headline, .rounded, .bold, mono: true),
        button: face(.headline, .rounded, .bold),
        navTitle: face(.headline, .rounded, .heavy),
        sectionTitle: face(.title3, .rounded, .bold),
        pageSectionTitle: face(.title2, .rounded, .bold),
        cardTitle: face(.title3, .rounded, .bold),
        tileTitle: face(.headline, .rounded, .bold),
        columnHeader: face(.caption, .text, .semibold),
        badge: face(.caption, .rounded, .heavy))

    /// C · Paper Club (both finishes): New York for names, SF Expanded for numbers, SF Pro for the rest (§3).
    static let paperClub = textRoles(
        largeTitle: face(.largeTitle, .serif, .black),
        title: face(.title, .serif, .black),
        title2: face(.title2, .serif, .heavy),
        title3: face(.title3, .serif, .heavy),
        numbers: .expanded, numberWeight: .heavy,
        fieldNumber: face(.headline, .text, .bold, mono: true),
        button: face(.headline, .text, .bold),
        navTitle: face(.headline, .serif, .heavy),
        sectionTitle: face(.title2, .serif, .heavy),
        cardTitle: face(.title3, .serif, .heavy),
        tileTitle: face(.title3, .serif, .heavy),
        columnHeader: face(.caption2, .text, .bold),
        badge: face(.caption2, .text, .heavy))
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
    /// Set marker box (A square-ish; B/C circles use half their size).
    var marker: CGFloat
    /// Sheet top corners.
    var sheet: CGFloat
}

struct LookSpacing {
    /// Side margin: 20 pt on every screen in every look.
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
    /// The outline that means "you can press this" (C only; 0 elsewhere).
    var pressable: CGFloat
    /// Outline around the one primary command (C only).
    var primary: CGFloat
    /// Dashed edges ("make one", Add Set, drafts).
    var dashed: CGFloat
}

struct LookMotion {
    /// Scale while a pressable is held (1 = no scale).
    var pressScale: CGFloat
    /// C: the primary physically sinks into its hard shadow by this much.
    var pressSink: CGFloat
    /// Opacity used for press feedback under Reduce Motion.
    var reducedPressOpacity: Double
    /// A: segment rings; B/C: arcs.
    var segmentedRings: Bool
    /// Stamp entry: scale and rotation the check drops in from.
    var stampScale: CGFloat
    var stampRotation: Double
    /// How long a muscle map takes to light on entry (A 200 ms, B 0.7 s, C 0.32 s).
    var mapLightDuration: Double
}

// MARK: - The look

struct Look {
    /// The structural family (what components switch on).
    var id: LookStyle
    /// The switcher choice this value was built for (`.final` for the user's look).
    var origin: LookID = .floodlight
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
    /// Fill of a pressable while pressed (C) / tinted chrome.
    var pressedFill: Color
    /// Separators and information edges.
    var hairline: Color
    /// A top inner highlight on cards (B only; clear elsewhere).
    var innerHighlight: Color
    /// The dashed edge of an open draft field / make tile.
    var dash: Color
    /// Outline that marks pressable things (C: ink / bone; clear elsewhere).
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
    /// The action meaning as text, rings and marks (C Carbon: lighter cobalt).
    var actionText: Color
    /// A live instrument (rest ring, live progress).
    var live: Color
    /// PROPOSAL: the live colour on the ink rest slab, when the accent itself is dark.
    var liveOnSlabOverride: Color? = nil
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
    /// Destructive controls (B / C have no hue: they use the text colour + a mark).
    var destructive: Color
    // Set kinds
    var warmup: Color
    var drop: Color
    var failure: Color
    /// Background of the "W" marker when it is a filled disc (C) / outline colour (A).
    var warmupMarker: Color
    // Instruments (C slabs; A/B glass bars)
    var slab: Color
    var slabEdge: Color
    var onSlab: Color
    var onSlabSecondary: Color
    // Rings and charts
    var ringTrack: Color
    /// "Last time" bar in comparisons.
    var comparisonLast: Color
    /// The C hard offset shadow under the primary (clear elsewhere).
    var shadowInk: Color
    /// Floating chrome tint (tab bar, toolbar buttons, rest bar).
    var glassTint: Color
    var glassEdge: Color
    /// Unit suffixes ("lb", "kg") — plain in every look.
    var unitKg: Color
    var unitLb: Color
    /// HR zone ramp, index 0 (Warm-up) … 5.
    var zoneRamp: [Color]
    // Muscle families
    var familyColors: [MuscleFamily: Color]
    /// Tile washes behind maps (C) — family colour at low strength elsewhere.
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
    /// Round icon buttons / discs / stepper tracks inside content (A cell, B white 8 % "fill-2", C sheet).
    var controlFill: Color
    /// The gym chip in the live header.
    var chipFill: Color
    /// Selected chip / segment fill (A white 14 %, B white 12 %, C cobalt).
    var segmentFill: Color
    /// The quiet rest-bar pill (+15s): fill and edge.
    var pillFill: Color
    var pillEdge: Color
    /// Week-strip dots for untrained days (B): past and future.
    var dayDotPast: Color
    var dayDotFuture: Color

    func family(_ family: MuscleFamily) -> Color { familyColors[family] ?? textSecondary }
    func familyTint(_ family: MuscleFamily) -> Color { familyTints[family] ?? surfaceRaised }
    func zone(_ zone: HeartRateZone) -> Color { zoneRamp[zone.rawValue] }
    func unit(_ unit: WeightUnit) -> Color { unit == .kg ? unitKg : unitLb }
    var isDark: Bool { colorScheme == .dark }

    /// The token set for a switcher choice. `scheme` only matters for `.final` (light or dark
    /// Floodlight); the study looks have one fixed finish each.
    static func `for`(_ id: LookID, scheme: ColorScheme = .dark) -> Look {
        switch id {
        case .final: scheme == .light ? .finalLight : .finalDark
        case .soft: scheme == .light ? .softLight : .softDark
        case .floodlight: .floodlight
        case .anatomy: .anatomy
        case .paper: .paper
        case .carbon: .carbon
        }
    }
}

// MARK: - A · Floodlight

extension Look {
    static let floodlight: Look = {
        let flood = Color(hex: 0xF4F6F8)
        let dim = Color(hex: 0xA4A9B1)
        let ink = Color(hex: 0x060708)
        let ultra = Color(hex: 0xB25CFF)
        return Look(
            id: .floodlight,
            ground: Color(hex: 0x060708),
            groundSheet: Color(hex: 0x0B0C0E),
            surface: Color(hex: 0x181A1E),
            surfaceSheet: Color(hex: 0x181A1E),
            surfaceRaised: Color(hex: 0x22252A),
            field: Color(hex: 0x22252A),
            pressedFill: Color(hex: 0x2A2D33),
            hairline: .white.opacity(0.10),
            innerHighlight: .clear,
            dash: .white.opacity(0.28),
            outline: .clear,
            textPrimary: flood,
            textSecondary: dim,
            textTertiary: Color(hex: 0x7F858E),
            action: ultra,
            onAction: ink,
            actionText: ultra,
            live: ultra,
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
            ringTrack: Color(hex: 0x34373D),
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
            font: .floodlight,
            radius: LookRadii(panel: 16, tile: 16, stat: 16, row: 10, field: 8, bar: 22, badge: 6, marker: 8, sheet: 38),
            space: LookSpacing(section: 28, group: 12, header: 12, panelPadding: 16, grid: 12),
            stroke: LookStrokes(hairline: 1, pressable: 0, primary: 0, dashed: 1.5),
            motion: LookMotion(pressScale: 0.97, pressSink: 0, reducedPressOpacity: 0.7, segmentedRings: true,
                               stampScale: 1.55, stampRotation: -14, mapLightDuration: 0.2),
            controlFill: Color(hex: 0x22252A),
            chipFill: Color(hex: 0x0F1012),
            segmentFill: .white.opacity(0.14),
            pillFill: Color(hex: 0x222427),
            pillEdge: .white.opacity(0.12),
            dayDotPast: Color(hex: 0x34373D),
            dayDotFuture: Color(hex: 0x22252A))
    }()
}

// MARK: - B · Anatomy

extension Look {
    static let anatomy: Look = {
        let pearl = Color(hex: 0xF3F1EC)
        let ink = Color(hex: 0x0A0B0F)
        var look = Look(
            id: .anatomy,
            ground: ink,
            groundSheet: Color(hex: 0x101115),
            surface: Color(hex: 0x191A1E),
            surfaceSheet: Color(hex: 0x1F2024),
            surfaceRaised: Color(hex: 0x28292D),
            field: Color(hex: 0x292A2E),
            pressedFill: Color(hex: 0x2E2F33),
            hairline: .white.opacity(0.07),
            innerHighlight: .white.opacity(0.05),
            dash: pearl.opacity(0.20),
            outline: .clear,
            textPrimary: pearl,
            textSecondary: Color(hex: 0xA7ACB6),
            textTertiary: Color(hex: 0x8A8F99),
            action: pearl,
            onAction: ink,
            actionText: pearl,
            live: pearl,
            selection: pearl,
            selectionFill: .white.opacity(0.12),
            done: pearl,
            onDone: ink,
            positive: pearl,
            onPositive: ink,
            heartRate: Color(hex: 0xFF5262),
            destructive: pearl,
            warmup: Color(hex: 0xF2D06B),
            drop: Color(hex: 0xB5E2FF),
            failure: Color(hex: 0xFF8A2B),
            warmupMarker: Color(hex: 0xF2D06B),
            slab: Color(hex: 0x24252A).opacity(0.80),
            slabEdge: .white.opacity(0.08),
            onSlab: pearl,
            onSlabSecondary: Color(hex: 0xA7ACB6),
            ringTrack: .white.opacity(0.08),
            comparisonLast: Color(hex: 0x5C6069),
            shadowInk: .clear,
            glassTint: .white.opacity(0.0625),
            glassEdge: .white.opacity(0.08),
            unitKg: Color(hex: 0xA7ACB6),
            unitLb: Color(hex: 0xA7ACB6),
            zoneRamp: [0x77737D, 0xB54450, 0xDC4B5A, 0xFF5262, 0xFF7D7B, 0xFFAFA6].map { Color(hex: $0) },
            familyColors: [.chest: Color(hex: 0xEA43CE), .back: Color(hex: 0x2C76F5), .shoulders: Color(hex: 0x2BDCC8),
                           .arms: Color(hex: 0xB194FF), .legs: Color(hex: 0xB3EE77)],
            familyTints: [.chest: Color(hex: 0xEA43CE).opacity(0.14), .back: Color(hex: 0x2C76F5).opacity(0.14),
                          .shoulders: Color(hex: 0x2BDCC8).opacity(0.14), .arms: Color(hex: 0xB194FF).opacity(0.14),
                          .legs: Color(hex: 0xB3EE77).opacity(0.14)],
            mapBody: Color(hex: 0x4C515C),
            mapBodyUnlit: Color(hex: 0x30333A),
            mapMuscleUnlit: Color(hex: 0x3F434C),
            font: .anatomy,
            radius: LookRadii(panel: 24, tile: 24, stat: 20, row: 14, field: 12, bar: 28, badge: 11, marker: 16, sheet: 38),
            space: LookSpacing(section: 30, group: 12, header: 12, panelPadding: 16, grid: 12),
            stroke: LookStrokes(hairline: 1, pressable: 0, primary: 0, dashed: 1.5),
            motion: LookMotion(pressScale: 0.97, pressSink: 0, reducedPressOpacity: 0.8, segmentedRings: false,
                               stampScale: 0.55, stampRotation: 0, mapLightDuration: 0.7),
            controlFill: .white.opacity(0.08),
            chipFill: Color(hex: 0x191A1E),
            segmentFill: .white.opacity(0.12),
            pillFill: .white.opacity(0.08),
            pillEdge: .white.opacity(0.08),
            dayDotPast: Color(hex: 0x3A3D45),
            dayDotFuture: Color(hex: 0x26282E))
        look.origin = .anatomy
        return look
    }()
}

// MARK: - C · Paper Club (two finishes, one token table each)

extension Look {
    /// Shared C structure; only the token values differ between Paper and Carbon copy.
    private static func paperClub(
        id: LookStyle, ground: UInt32, sheet: UInt32, text: Color, text2: Color, rule: Color, dash: Color,
        actionText: UInt32, shadow: UInt32, heart: UInt32, wu: UInt32, slab: Color, slabEdge: Color,
        onSlab: Color, pressed: UInt32, glass: Color, glassEdge: Color, tints: [MuscleFamily: UInt32],
        mapBody: UInt32, mapBodyUnlit: Color, lastBar: UInt32
    ) -> Look {
        let cobalt = Color(hex: 0x2743F2)
        return Look(
            id: id,
            ground: Color(hex: ground),
            groundSheet: Color(hex: ground),
            surface: Color(hex: sheet),
            surfaceSheet: Color(hex: sheet),
            surfaceRaised: Color(hex: ground),
            field: Color(hex: ground),
            pressedFill: Color(hex: pressed),
            hairline: rule,
            innerHighlight: .clear,
            dash: dash,
            outline: text,
            textPrimary: text,
            textSecondary: text2,
            textTertiary: text2,
            action: cobalt,
            onAction: .white,
            actionText: Color(hex: actionText),
            live: Color(hex: 0x4C8DFF),
            selection: Color(hex: actionText),
            selectionFill: Color(hex: pressed),
            done: text,
            onDone: Color(hex: sheet),
            positive: Color(hex: 0xFFE14A),
            onPositive: Color(hex: 0x16140F),
            heartRate: Color(hex: heart),
            destructive: text,
            warmup: Color(hex: wu),
            drop: text,
            failure: text,
            warmupMarker: Color(hex: wu),
            slab: slab,
            slabEdge: slabEdge,
            onSlab: onSlab,
            onSlabSecondary: Color(hex: 0xBEBAB2),
            ringTrack: rule,
            comparisonLast: Color(hex: lastBar),
            shadowInk: Color(hex: shadow),
            glassTint: glass,
            glassEdge: glassEdge,
            unitKg: text2,
            unitLb: text2,
            zoneRamp: [0x6F6A62, 0x9A4E58, 0xCC3C3C, 0xF4502C, 0xFF8A4F, 0xFFC4A6].map { Color(hex: $0) },
            familyColors: [.chest: Color(hex: 0xFF6AA8), .back: Color(hex: 0x0FA0BD), .shoulders: Color(hex: 0xFFA83F),
                           .arms: Color(hex: 0xC49BFF), .legs: Color(hex: 0x9BE05C)],
            familyTints: tints.mapValues { Color(hex: $0) },
            mapBody: Color(hex: mapBody),
            mapBodyUnlit: mapBodyUnlit,
            mapMuscleUnlit: .clear,
            font: .paperClub,
            radius: LookRadii(panel: 18, tile: 18, stat: 16, row: 12, field: 10, bar: 24, badge: 6, marker: 17, sheet: 36),
            space: LookSpacing(section: 30, group: 12, header: 12, panelPadding: 14, grid: 12),
            stroke: LookStrokes(hairline: 1.5, pressable: 2, primary: 2.5, dashed: 2),
            motion: LookMotion(pressScale: 1, pressSink: 4, reducedPressOpacity: 0.8, segmentedRings: false,
                               stampScale: 1.7, stampRotation: -16, mapLightDuration: 0.32),
            controlFill: Color(hex: sheet),
            chipFill: Color(hex: sheet),
            segmentFill: cobalt,
            pillFill: .clear,
            pillEdge: Color(hex: 0xA6A39C),
            dayDotPast: text2,
            dayDotFuture: text2.opacity(0.5))
    }

    static let paper: Look = {
        let ink = Color(hex: 0x16140F)
        var look = paperClub(
            id: .paper, ground: 0xF2ECDF, sheet: 0xFFFBF2, text: ink, text2: Color(hex: 0x575046),
            rule: ink.opacity(0.22), dash: ink.opacity(0.45), actionText: 0x2743F2, shadow: 0x16140F,
            heart: 0xE0261E, wu: 0x6E665A, slab: ink, slabEdge: ink, onSlab: Color(hex: 0xFFFBF2),
            pressed: 0xE8E1D2, glass: Color(hex: 0xFFFBF2).opacity(0.72), glassEdge: ink.opacity(0.14),
            tints: [.chest: 0xFFE4E6, .back: 0xD9ECEA, .shoulders: 0xFFEED5, .arms: 0xF6ECF4, .legs: 0xEFF7DA],
            mapBody: 0x7D766B, mapBodyUnlit: ink.opacity(0.20), lastBar: 0x9C968B)
        look.origin = .paper
        look.colorScheme = .light
        return look
    }()

    static let carbon: Look = {
        let bone = Color(hex: 0xEDE6D6)
        var look = paperClub(
            id: .carbon, ground: 0x15130F, sheet: 0x211E18, text: bone, text2: Color(hex: 0xB5AE9F),
            rule: bone.opacity(0.16), dash: bone.opacity(0.42), actionText: 0x4C8DFF, shadow: 0x756D60,
            heart: 0xFF453A, wu: 0x948C7E, slab: .black, slabEdge: bone.opacity(0.24), onSlab: bone,
            pressed: 0x2E2A23, glass: Color(hex: 0x2C2821).opacity(0.72), glassEdge: bone.opacity(0.14),
            tints: [.chest: 0x522F38, .back: 0x1D3B3C, .shoulders: 0x523C21, .arms: 0x453A4B, .legs: 0x3C4927],
            mapBody: 0x7C7569, mapBodyUnlit: bone.opacity(0.16), lastBar: 0x6E685E)
        look.origin = .carbon
        return look
    }()
}

// MARK: - Per-look symbols and labels

extension Look {
    /// The gym pin (every look: a location pin, never a thumbtack).
    var gymSymbol: String { "mappin.and.ellipse" }

    /// The exercise card's previous-performance button (A bars, B/C a trend line).
    var previousPerformanceSymbol: String { id == .floodlight ? "chart.bar.xaxis" : "chart.line.uptrend.xyaxis" }

    /// Finish / history tile glyphs. The SPECs draw outline `scalemass` (the model's
    /// `FinishTileKind.symbol` says `scalemass.fill`), so the look layer overrides it.
    func tileSymbol(_ kind: FinishTileKind) -> String {
        switch kind {
        case .totalVolume: "scalemass"
        default: kind.symbol
        }
    }

    /// Rest-bar next-set line: A keeps the unit ("Next · Set 3 · 110 lb × 8"),
    /// B and C drop it when it matches the row ("Next · Set 3 · 110 × 8").
    /// `value == nil` gives "Next · Set 3".
    func nextSetLabel(number: Int, value: SetValue?, rowUnit: WeightUnit, loadType: LoadType = .weighted) -> String {
        guard let value else { return "Next · Set \(number)" }
        return "Next · Set \(number) · \(previousLabel(value, rowUnit: rowUnit, loadType: loadType))"
    }

    /// Rest-bar line when the next set belongs to another exercise: "Next · Incline Chest Press".
    func nextExerciseLabel(_ exercise: String) -> String { "Next · \(exercise)" }

    /// A template's last-done date, per look (the date is data; the wording is the look's):
    /// A "Sep 23"; B "Wed" within this week, else "Sep 17"; C "Yesterday", "3 days ago".
    func lastDoneLabel(_ date: Date, now: Date) -> String {
        let cal = Calendar.app
        switch id {
        case .floodlight:
            return Format.shortDate(date)
        case .anatomy:
            if let week = cal.dateInterval(of: .weekOfYear, for: now), week.contains(date) {
                return LookDates.weekdayShort.string(from: date)
            }
            return Format.shortDate(date)
        case .paper, .carbon:
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
            switch days {
            case ...0: return "Today"
            case 1: return "Yesterday"
            case 2...60: return "\(days) days ago"
            default: return Format.shortDate(date)
            }
        }
    }
}

private enum LookDates {
    static let weekdayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Calendar.app.locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var look: Look = .floodlight
    /// true inside a sheet: content surfaces use `surfaceSheet` (B's lighter sheet card).
    @Entry var lookOnSheet: Bool = false
    /// true inside an instrument slab (C rest bar / heart-rate plate): text uses `onSlab`.
    @Entry var lookOnSlab: Bool = false
}

/// The prototype's current look (the switcher mutates `id`) and the Appearance setting.
@Observable
final class LookModel {
    var id: LookID
    /// PROPOSAL (2026-11): the accent that replaces violet (switchable in the prototype pill).
    var accent: ProposalAccent = ProposalAccent(rawValue: UserDefaults.standard.string(forKey: "accent") ?? "") ?? .mono
    /// Settings → Appearance. Persisted; a `-appearance light|dark|system` launch argument wins.
    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    static let appearanceKey = "prototype.appearance"

    init(id: LookID = .final, appearance: Appearance? = nil) {
        self.id = id
        let defaults = UserDefaults.standard
        self.appearance = appearance
            ?? defaults.string(forKey: "appearance").flatMap(Appearance.init(argument:))
            ?? defaults.string(forKey: Self.appearanceKey).flatMap(Appearance.init(argument:))
            ?? .system
    }

    /// The scheme the app asks for: a study look's fixed finish, or the Appearance setting
    /// (`nil` = follow the system) for the final look.
    var preferredColorScheme: ColorScheme? {
        id.followsAppearance ? appearance.colorScheme : id.fixedColorScheme
    }

    /// The token set, given the scheme the system resolves to when Appearance is System.
    func look(system: ColorScheme) -> Look {
        let base = Look.for(id, scheme: preferredColorScheme ?? system)
        return id == .final ? base.withAccent(accent, live: false) : base
    }

    /// The sun / moon quick toggle: flips the final look between explicit Light and Dark.
    func toggleLightDark(system: ColorScheme) {
        let current = appearance.colorScheme ?? system
        appearance = current == .dark ? .light : .dark
    }
}

extension View {
    /// Injects a look and pins its colour scheme (sub-presentations that re-apply the look).
    func look(_ look: Look) -> some View {
        environment(\.look, look).preferredColorScheme(look.colorScheme)
    }

    /// Injects the model's current look for a presentation layer: the scheme follows the
    /// Appearance setting (System leaves it to the device), and the final look's light / dark
    /// token set follows the scheme that results.
    func lookLayer(_ model: LookModel) -> some View {
        modifier(LookLayerModifier(model: model))
    }
}

private struct LookLayerModifier: ViewModifier {
    let model: LookModel
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        content
            .environment(\.look, model.look(system: systemScheme))
            .preferredColorScheme(model.preferredColorScheme)
    }
}

// MARK: - Colour helper

extension Color {
    /// `Color(hex: 0xB25CFF)`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// `Color(hex: "#B25CFF")` or `"B25CFF"`; invalid strings are magenta so they show.
    init(hex string: String) {
        let cleaned = string.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        self.init(hex: UInt32(cleaned, radix: 16) ?? 0xFF00FF)
    }
}

// MARK: - Soft (2026-11 exploration)

extension LookFonts {
    /// Soft: SF Pro only — bold titles, semibold figures, no Expanded or Black.
    static let soft = textRoles(
        largeTitle: face(.largeTitle, .text, .bold),
        title: face(.title, .text, .bold),
        title2: face(.title2, .text, .bold),
        title3: face(.title3, .text, .semibold),
        numbers: .text, numberWeight: .semibold,
        fieldNumber: face(.headline, .text, .semibold, mono: true),
        button: face(.headline, .text, .semibold),
        navTitle: face(.headline, .text, .semibold),
        sectionTitle: face(.title3, .text, .semibold),
        pageSectionTitle: face(.title2, .text, .bold),
        cardTitle: face(.title3, .text, .semibold),
        tileTitle: face(.headline, .text, .semibold),
        columnHeader: face(.caption2, .text, .medium),
        badge: face(.caption, .text, .semibold))
}
