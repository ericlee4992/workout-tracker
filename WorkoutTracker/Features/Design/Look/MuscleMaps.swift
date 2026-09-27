import SwiftUI

// Muscle maps: the user's two-layer assets (white silhouettes, template rendering),
// tinted per look. Lit = grey body + vivid family muscle; unlit = a visible grey body
// (A/B) or a faint body with no muscle inside a dashed sticker (C). Summaries only —
// never beside an exercise row.

struct MuscleMap: View {
    var family: MuscleFamily
    var lit: Bool = true
    var size: CGFloat = 48
    /// Light up after this delay on first appearance (Home / Finish entry motion).
    var appearDelay: Double?

    @State private var shownLit: Bool?
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(family: MuscleFamily, lit: Bool = true, size: CGFloat = 48, appearDelay: Double? = nil) {
        self.family = family
        self.lit = lit
        self.size = size
        self.appearDelay = appearDelay
    }

    var body: some View {
        let on = shownLit ?? (appearDelay == nil || reduceMotion ? lit : false)
        ZStack {
            Image(family.bodyAsset)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(on ? look.mapBody : look.mapBodyUnlit)
            Image(family.muscleAsset)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(on ? look.family(family) : look.mapMuscleUnlit)
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .easeOut(duration: appearDelay == nil ? 0.2 : look.motion.mapLightDuration), value: on)
        .onAppear {
            guard let appearDelay, !reduceMotion, lit, shownLit == nil else { return }
            shownLit = false
            DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay) { shownLit = true }
        }
        .onChange(of: lit) { _, newValue in shownLit = newValue }
        .accessibilityElement()
        .accessibilityLabel(family.label)
    }
}

/// C's washed sticker: a small tile tinted with the family colour holding its map.
/// Unlit: dashed outline, faint body, no muscle. A/B: the bare map.
struct FamilySticker: View {
    var family: MuscleFamily
    var lit: Bool = true
    var size: CGFloat = 30
    @Environment(\.look) private var look

    var body: some View {
        if look.id.isPaperClub {
            let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            MuscleMap(family: family, lit: lit, size: size * 0.86)
                .frame(width: size, height: size)
                .background(lit ? look.familyTint(family) : .clear, in: shape)
                .overlay {
                    if lit {
                        shape.strokeBorder(look.hairline, lineWidth: 1.5)
                    } else {
                        shape.strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                    }
                }
        } else {
            MuscleMap(family: family, lit: lit, size: size)
        }
    }
}

/// The families of a template / workout, head to toe, all lit.
struct FamilyStrip: View {
    var families: [MuscleFamily]
    var size: CGFloat = 30
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(MuscleFamily.ordered(families)) { family in
                FamilySticker(family: family, lit: true, size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MuscleFamily.ordered(families).map(\.label).joined(separator: ", "))
    }
}

/// C's template-tile band: one washed segment per family with its map, divided by soft rules.
/// A/B fall back to a leading FamilyStrip.
struct FamilyBand: View {
    var families: [MuscleFamily]
    var height: CGFloat = 76
    @Environment(\.look) private var look

    var body: some View {
        let ordered = MuscleFamily.ordered(families)
        if look.id.isPaperClub {
            GeometryReader { geo in
                let count = CGFloat(max(ordered.count, 1))
                let segment = (geo.size.width - 1.5 * (count - 1)) / count
                let mapSize = max(16, min(height * 0.84, segment * 0.94, 64))
                HStack(spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.element) { index, family in
                        if index > 0 { Rectangle().fill(look.hairline).frame(width: 1.5) }
                        MuscleMap(family: family, lit: true, size: mapSize)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(look.familyTint(family))
                    }
                }
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ordered.map(\.label).joined(separator: ", "))
        } else {
            FamilyStrip(families: ordered, size: 30)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One family's tally: its map, "N sets", and its name. Lit = trained.
///
/// `.column` (default at standard sizes): map over count over name.
/// `.row` (B and C at accessibility sizes, via `FamilyTallyGroup`): a 44 pt map (C: its washed
/// tile), the family name, and the count trailing — B SPEC §8 / C SPEC §9.
struct FamilyTally: View {
    enum Style { case automatic, column, row }
    var family: MuscleFamily
    var sets: Int
    var lit: Bool?
    var size: CGFloat?
    var showsName = true
    var appearDelay: Double?
    var style: Style = .automatic
    /// Finish (B): an untrained family shows its dim map and name but no "0 sets".
    var hidesZeroCount = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(family: MuscleFamily, sets: Int, lit: Bool? = nil, size: CGFloat? = nil, showsName: Bool = true,
         appearDelay: Double? = nil, style: Style = .automatic, hidesZeroCount: Bool = false) {
        self.family = family
        self.sets = sets
        self.lit = lit
        self.size = size
        self.showsName = showsName
        self.appearDelay = appearDelay
        self.style = style
        self.hidesZeroCount = hidesZeroCount
    }

    private var showsCount: Bool { !(hidesZeroCount && sets == 0) }

    private var isLit: Bool { lit ?? (sets > 0) }
    private var setsWord: String { sets == 1 ? "set" : "sets" }

    /// A keeps its one row of maps at every size (A SPEC §9); B and C become rows at AX sizes.
    private var resolvedStyle: Style {
        switch style {
        case .automatic: typeSize.isAccessibilitySize && look.id != .floodlight ? .row : .column
        default: style
        }
    }

    var body: some View {
        Group {
            if resolvedStyle == .row {
                row
            } else {
                switch look.id {
                case .floodlight: floodlight
                case .paper, .carbon: paperClub
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(family.label), \(sets) \(setsWord)")
    }

    /// Accessibility sizes put the number over "sets" (two lines) instead of truncating.
    private var countLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 3))
    }

    private var floodlight: some View {
        VStack(spacing: 4) {
            MuscleMap(family: family, lit: isLit, size: size ?? 56, appearDelay: appearDelay)
            if showsCount { countLayout {
                Text("\(sets)")
                    .font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
                    .foregroundStyle(isLit ? look.textPrimary : look.textTertiary)
                Text(setsWord).font(look.font.caption).foregroundStyle(look.textSecondary)
            }
            .lineLimit(1)
            .fixedSize() }
            if showsName {
                Text(family.label).font(look.font.caption).foregroundStyle(isLit ? look.textSecondary : look.textTertiary)
                    .fixedSize()
            }
        }
    }

    private var paperClub: some View {
        VStack(spacing: 4) {
            MuscleMap(family: family, lit: isLit, size: size ?? 66, appearDelay: appearDelay)
                .frame(maxWidth: .infinity, minHeight: 90)
                .modifier(PaperTallyTile(family: family, lit: isLit, radius: 16))
                .padding(.bottom, 6)
            if showsName {
                Text(family.label).font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
            }
            if showsCount {
                Text("\(sets) working \(setsWord)")
                    .font(look.font.caption)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The accessibility-size row: map · name · count trailing.
    private var row: some View {
        HStack(spacing: 12) {
            if look.id.isPaperClub {
                MuscleMap(family: family, lit: isLit, size: 38, appearDelay: appearDelay)
                    .frame(width: 44, height: 44)
                    .modifier(PaperTallyTile(family: family, lit: isLit, radius: 12))
            } else {
                MuscleMap(family: family, lit: isLit, size: 44, appearDelay: appearDelay)
            }
            if look.id.isPaperClub {
                VStack(alignment: .leading, spacing: 2) {
                    Text(family.label).font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                    if showsCount {
                        Text("\(sets) working \(setsWord)").font(look.font.caption).foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            } else {
                Text(family.label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(isLit ? look.textPrimary : look.textTertiary)
                Spacer(minLength: 8)
                if showsCount { HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sets)")
                        .font(look.font.smallNumber)
                        .foregroundStyle(isLit ? look.textPrimary : look.textTertiary)
                    Text(setsWord).font(.system(.caption, weight: .bold)).foregroundStyle(look.textSecondary)
                } }
            }
        }
        .frame(minHeight: 44)
    }
}

/// C's washed tile behind a tally map (dashed and empty when the family is untrained).
private struct PaperTallyTile: ViewModifier {
    var family: MuscleFamily
    var lit: Bool
    var radius: CGFloat
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(lit ? look.familyTint(family) : .clear, in: shape)
            .overlay {
                if lit {
                    shape.strokeBorder(look.hairline, lineWidth: 1.5)
                } else {
                    shape.strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
    }
}

/// A set of family tallies laid out per look and size — use this rather than an HStack of
/// FamilyTally. Standard sizes: equal columns. Accessibility sizes: B and C become a list of
/// rows (map · name · count); A keeps one row of maps, wrapping 3 + 2 if it cannot fit.
struct FamilyTallyGroup: View {
    var counts: [FamilyCount]
    var mapSize: CGFloat?
    var showsNames = true
    /// First map lights after this delay; the rest follow `stagger` apart (nil: no entry motion).
    var appearDelay: Double?
    var stagger: Double = 0.08
    var spacing: CGFloat = 6
    var hidesZeroCounts = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(counts: [FamilyCount], mapSize: CGFloat? = nil, showsNames: Bool = true,
         appearDelay: Double? = nil, stagger: Double = 0.08, spacing: CGFloat = 6, hidesZeroCounts: Bool = false) {
        self.counts = counts
        self.mapSize = mapSize
        self.showsNames = showsNames
        self.appearDelay = appearDelay
        self.stagger = stagger
        self.spacing = spacing
        self.hidesZeroCounts = hidesZeroCounts
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize && look.id != .floodlight {
                VStack(spacing: look.id.isPaperClub ? 8 : 4) {
                    ForEach(Array(counts.enumerated()), id: \.element.id) { index, count in
                        tally(count, index, style: .row)
                    }
                }
            } else {
                if look.id == .floodlight && typeSize.isAccessibilitySize && showsNames {
                    threePlusTwo
                } else if look.id != .floodlight {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(counts.enumerated()), id: \.element.id) { index, count in
                            tally(count, index, style: .column).frame(maxWidth: .infinity)
                        }
                    }
                } else { ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(counts.enumerated()), id: \.element.id) { index, count in
                            tally(count, index, style: .column).frame(maxWidth: .infinity)
                        }
                    }
                    // Too wide for one row (A at the largest sizes): 3 + 2.
                    Grid(horizontalSpacing: spacing, verticalSpacing: 12) {
                        ForEach(Array(stride(from: 0, to: counts.count, by: 3)), id: \.self) { start in
                            GridRow(alignment: .top) {
                                ForEach(start..<min(start + 3, counts.count), id: \.self) { i in
                                    tally(counts[i], i, style: .column).frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                } }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(counts.map { "\($0.family.label) \($0.sets)" }.joined(separator: ", "))
    }

    private var threePlusTwo: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: 12) {
            ForEach(Array(stride(from: 0, to: counts.count, by: 3)), id: \.self) { start in
                GridRow(alignment: .top) {
                    ForEach(start..<min(start + 3, counts.count), id: \.self) { i in
                        tally(counts[i], i, style: .column).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func tally(_ count: FamilyCount, _ index: Int, style: FamilyTally.Style) -> some View {
        FamilyTally(family: count.family, sets: count.sets, size: mapSize, showsName: showsNames,
                    appearDelay: appearDelay.map { $0 + Double(index) * stagger }, style: style,
                    hidesZeroCount: hidesZeroCounts)
    }
}
