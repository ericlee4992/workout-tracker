import SwiftUI
import UIKit

// PROTOTYPE — Gyms area views the Look layer doesn't have yet (area-prefixed so the integrator
// can promote them): equipment-category glyphs, the gym monogram, the stat strip, group
// headers, the "make one" row, tags, the best value and last-used marks, a swipe-to-delete row
// that yields to vertical scrolling, a sheet header that re-flows at AX sizes, the machine's
// best-set chart, the grouping menu, capture paging and small layout helpers.

// MARK: - Equipment-category glyphs (24-unit grid, drawn like WeightStackGlyph)

/// A weight plate seen face-on: rim, hub, grip slot. Plate-loaded machines.
struct GymsPlateGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.midX - 12 * s, oy = rect.midY - 12 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        p.addEllipse(in: CGRect(origin: pt(2.2, 2.2), size: CGSize(width: 19.6 * s, height: 19.6 * s)))
        p.addEllipse(in: CGRect(origin: pt(9.3, 9.3), size: CGSize(width: 5.4 * s, height: 5.4 * s)))
        p.addRoundedRect(in: CGRect(origin: pt(8.6, 4.9), size: CGSize(width: 6.8 * s, height: 2.2 * s)),
                         cornerSize: CGSize(width: 1.1 * s, height: 1.1 * s))
        return p
    }
}

/// A pulley on a bracket with its cable and stirrup handle. Cable & functional stations.
struct GymsPulleyGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.midX - 12 * s, oy = rect.midY - 12 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        p.move(to: pt(7.5, 1.6)); p.addLine(to: pt(16.5, 1.6))
        p.move(to: pt(12, 1.6)); p.addLine(to: pt(12, 3))
        p.addEllipse(in: CGRect(origin: pt(8, 3), size: CGSize(width: 8 * s, height: 8 * s)))
        p.addEllipse(in: CGRect(origin: pt(11.1, 6.1), size: CGSize(width: 1.8 * s, height: 1.8 * s)))
        p.move(to: pt(16, 7)); p.addLine(to: pt(16, 15.2))
        p.move(to: pt(16, 15.2)); p.addLine(to: pt(11.6, 21.6)); p.addLine(to: pt(20.4, 21.6)); p.closeSubpath()
        return p
    }
}

/// Two uprights holding a loaded bar. Rack, Smith & bench.
struct GymsRackGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.midX - 12 * s, oy = rect.midY - 12 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        for x in [6.5, 17.5] as [CGFloat] {
            p.move(to: pt(x, 1.8)); p.addLine(to: pt(x, 22))
            p.move(to: pt(x - 2.6, 22)); p.addLine(to: pt(x + 2.6, 22))
        }
        p.move(to: pt(1.2, 9)); p.addLine(to: pt(22.8, 9))
        p.addRoundedRect(in: CGRect(origin: pt(2.4, 5.6), size: CGSize(width: 2 * s, height: 6.8 * s)),
                         cornerSize: CGSize(width: 0.8 * s, height: 0.8 * s))
        p.addRoundedRect(in: CGRect(origin: pt(19.6, 5.6), size: CGSize(width: 2 * s, height: 6.8 * s)),
                         cornerSize: CGSize(width: 0.8 * s, height: 0.8 * s))
        return p
    }
}

/// A pull-up / dip tower. Bodyweight stations.
struct GymsStationGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.midX - 12 * s, oy = rect.midY - 12 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        p.move(to: pt(2, 3.5)); p.addLine(to: pt(22, 3.5))
        for x in [7, 17] as [CGFloat] {
            p.move(to: pt(x, 3.5)); p.addLine(to: pt(x, 22))
        }
        p.move(to: pt(7, 13)); p.addLine(to: pt(2.6, 13))
        p.move(to: pt(17, 13)); p.addLine(to: pt(21.4, 13))
        p.move(to: pt(4.5, 22)); p.addLine(to: pt(19.5, 22))
        return p
    }
}

/// The glyph for an equipment category. No category (no model, or a type not picked yet) is
/// an empty dashed ring: it claims nothing about the machine.
struct GymsEquipmentGlyph: View {
    var category: EquipmentCategory?
    var side: CGFloat

    var body: some View {
        let line = StrokeStyle(lineWidth: max(1.4, side * 0.085), lineCap: .round, lineJoin: .round)
        Group {
            switch category {
            case .plateLoaded: GymsPlateGlyph().stroke(style: line)
            case .cable: GymsPulleyGlyph().stroke(style: line)
            case .rackOrSmith: GymsRackGlyph().stroke(style: line)
            case .bodyweight: GymsStationGlyph().stroke(style: line)
            case .selectorized: WeightStackGlyph().stroke(style: line)
            case .none:
                Circle().stroke(style: StrokeStyle(lineWidth: max(1.2, side * 0.07), dash: [side * 0.14, side * 0.12]))
                    .padding(side * 0.14)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// The equipment glyph in the look's icon cell: A a raised square cell, B a white-8 % disc,
/// C an outlined disc (the row it leads is pressable). No category: an empty dashed cell.
struct GymsEquipmentDisc: View {
    var category: EquipmentCategory?
    var size: CGFloat = 40
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * min(scale, 1.5)
        if category == nil {
            let dashed = StrokeStyle(lineWidth: look.id.isPaperClub ? 1.5 : 1.3, dash: [4, 3.5])
            Group {
                if look.id == .floodlight {
                    RoundedRectangle(cornerRadius: side * 0.26, style: .continuous).strokeBorder(look.dash, style: dashed)
                } else {
                    Circle().strokeBorder(look.id.isPaperClub ? look.textSecondary : look.dash, style: dashed)
                }
            }
            .frame(width: side, height: side)
            .accessibilityHidden(true)
        } else {
            let glyph = GymsEquipmentGlyph(category: category, side: side * 0.56)
                .foregroundStyle(look.textPrimary)
                .frame(width: side, height: side)
            switch look.id {
            case .floodlight:
                glyph.background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: side * 0.26, style: .continuous))
            case .anatomy:
                glyph.background(look.controlFill, in: Circle())
            case .paper, .carbon:
                glyph.overlay { Circle().strokeBorder(look.outline, lineWidth: 1.5) }
            }
        }
    }
}

// MARK: - Gym monogram (per-gym identity without inventing data)

struct GymsMonogram: View {
    var name: String
    var size: CGFloat = 48
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).filter { $0.first?.isLetter == true || $0.first?.isNumber == true }
        let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    var body: some View {
        let side = size * min(scale, 1.6)
        let text = Text(Self.initials(name))
            .font(font(side))
            .foregroundStyle(look.textPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(width: side, height: side)
        Group {
            switch look.id {
            case .floodlight:
                text.background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
            case .anatomy:
                text.background(look.controlFill, in: Circle())
            case .paper, .carbon:
                text.background(look.ground, in: Circle())
                    .overlay { Circle().strokeBorder(look.outline, lineWidth: side > 56 ? 2 : 1.5) }
            }
        }
        .accessibilityHidden(true)
    }

    private func font(_ side: CGFloat) -> Font {
        switch look.id {
        case .floodlight: Font.system(size: side * 0.36, weight: .black).width(.expanded)
        case .anatomy: .system(size: side * 0.38, weight: .heavy, design: .rounded)
        case .paper, .carbon: .system(size: side * 0.42, weight: .black, design: .serif)
        }
    }
}

// MARK: - Stat strip (big numbers, small labels)

struct GymsStat: Identifiable, Hashable {
    var id: String { label }
    var value: String
    var label: String
    /// Counts ("18 visits") count up when they appear.
    var number: Int?
    /// Dates ("Sep 23", "Yesterday") are words: set a size down, on the numbers' baseline.
    var isWord = false

    static func count(_ n: Int, _ label: String) -> GymsStat { GymsStat(value: Format.grouped(n), label: label, number: n) }
}

/// Three facts in a row. A: one scoreboard divided by hairlines. B: separate solid tiles.
/// C: one ticket with rules. `embedded` drops the surface (inside a gym card). Word values
/// sit in the numbers' line box, so every label shares one baseline.
/// AX sizes: one row per fact, number leading, label trailing.
struct GymsStatStrip: View {
    var stats: [GymsStat]
    var embedded = false
    /// Keeps the column rhythm of sibling strips when a fact is missing (a gym never visited
    /// has no last visit): the empty columns stay blank.
    var columns: Int? = nil
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 { LookDivider() }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        value(stat)
                        Spacer(minLength: 8)
                        label(stat).multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, embedded ? 0 : 16)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stat.label) \(stat.value)")
                }
            }
            .modifier(GymsStripSurface(embedded: embedded))
        } else if look.id == .anatomy && !embedded {
            HStack(spacing: 10) {
                ForEach(stats) { stat in
                    cell(stat)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lookSurface(.stat)
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 && look.id != .anatomy { LookDivider(vertical: true) }
                    cell(stat)
                        .padding(.leading, index == 0 && embedded ? 0 : 14)
                        .padding(.trailing, 8)
                        .padding(.vertical, embedded ? 0 : 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(0..<max(0, (columns ?? 0) - stats.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .modifier(GymsStripSurface(embedded: embedded))
        }
    }

    private func cell(_ stat: GymsStat) -> some View {
        VStack(alignment: .leading, spacing: look.id == .floodlight ? 3 : 2) {
            value(stat)
            label(stat)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.label) \(stat.value)")
    }

    /// The value on the number's baseline, in the number's line box (a hidden "0" sets it).
    private func value(_ stat: GymsStat) -> some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .lastTextBaseline)) {
            Text("0").font(look.font.statNumber).hidden()
            Group {
                if let number = stat.number {
                    GymsRollingCount(value: number)
                } else {
                    Text(stat.value)
                }
            }
            .font(stat.isWord ? wordFont : look.font.statNumber)
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }

    private var wordFont: Font {
        switch look.id {
        case .floodlight: Font.system(.title3, weight: .heavy).width(.expanded)
        case .anatomy: .system(.title3, design: .rounded, weight: .heavy)
        case .paper, .carbon: Font.system(.title3, weight: .heavy).width(.expanded)
        }
    }

    private func label(_ stat: GymsStat) -> some View {
        Text(look.id.isPaperClub ? stat.label.lowercased() : stat.label)
            .font(.system(.caption, weight: look.id == .floodlight ? .regular : .semibold))
            .foregroundStyle(look.textSecondary)
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
    }
}

/// A count that rolls up to its value on appear (digits roll, the text is always a whole,
/// final-able number: an interpolated count can be caught mid-way in a still frame).
/// Reduce Motion: the value, still.
struct GymsRollingCount: View {
    var value: Int
    @State private var shown: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = shown ?? (reduceMotion ? value : 0)
        Text(Format.grouped(current))
            .contentTransition(.numericText(value: Double(current)))
            .onAppear {
                guard shown == nil else { return }
                if reduceMotion { shown = value; return }
                shown = 0
                withAnimation(.snappy(duration: 0.6).delay(0.15)) { shown = value }
            }
            .onChange(of: value) { _, new in
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.4)) { shown = new }
            }
            .accessibilityLabel(Format.grouped(value))
    }
}

private struct GymsStripSurface: ViewModifier {
    var embedded: Bool
    func body(content: Content) -> some View {
        if embedded { content } else { content.lookSurface(.stat) }
    }
}

// MARK: - Group header (family swatch + name + count)

/// A group title with a small family-colour swatch (maps stay in summaries). Groups without a
/// family (Core, Full Body, Uncategorized, manufacturers) get the same-size empty swatch, so
/// every title starts at one inset.
struct GymsGroupHeader: View {
    var title: String
    var family: MuscleFamily?
    var showsSwatch = true
    var count: Int?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var swatch: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if showsSwatch { swatchView }
            Text(title)
                .font(look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let count {
                Text("\(count)")
                    .font(look.id == .anatomy ? .system(.subheadline, design: .rounded, weight: .heavy)
                          : Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit())
                    .foregroundStyle(look.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var swatchView: some View {
        let shape = look.id == .anatomy ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: swatch * 0.3, style: .continuous))
        if let family {
            shape.fill(look.family(family))
                .frame(width: swatch, height: swatch)
                .accessibilityHidden(true)
        } else {
            shape.stroke(look.textTertiary, lineWidth: 1.5)
                .frame(width: swatch - 1.5, height: swatch - 1.5)
                .frame(width: swatch, height: swatch)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - "Make one" row (dashed)

/// A full-width dashed "make one" row: Add Gym…, Add Machine…, New Model….
struct GymsMakeRow: View {
    var title: String
    var symbol: String = "plus"
    /// What it will make ("Belt Squat" from a search with no match).
    var detail: String? = nil
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                switch look.id {
                case .floodlight:
                    Image(systemName: symbol).font(.system(.body, weight: .semibold))
                        .frame(width: disc)
                case .anatomy, .paper, .carbon:
                    IconDisc(symbol: symbol, size: disc, context: .make)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(look.id == .anatomy ? look.font.button : .system(.body, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .overlay {
                if look.id.isPaperClub {
                    RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous)
                        .strokeBorder(look.outline, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                } else {
                    RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous)
                        .strokeBorder(look.dash, style: StrokeStyle(lineWidth: look.stroke.dashed, dash: [5, 4]))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
    }
}

// MARK: - The screen's one filled command, as the Start capsule

/// The screen's one filled command in the capsule the user chose for Start (an ink disc holding
/// the glyph). A and B use the Start capsule itself; C's primary already carries its disc.
struct GymsPrimaryCapsule: View {
    var title: String
    var symbol: String
    var action: () -> Void

    @Environment(\.look) private var look

    var body: some View {
        if look.id.isPaperClub {
            PrimaryButton(title, symbol: symbol, action: action)
        } else {
            StartCapsule(title: title, symbol: symbol, action: action)
                .frame(maxWidth: .infinity)
        }
    }
}

/// A compact dashed "make one" pill (44 pt): the catalog's pinned New Model… · Scan Machine.
struct GymsMakePill: View {
    var title: String
    var symbol: String
    /// Only the glyph, in a pill as wide as it is tall (the title is its VoiceOver label).
    var iconOnly = false
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(.subheadline, weight: .bold))
                if !iconOnly {
                    Text(title)
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, iconOnly ? 0 : 14)
            .frame(width: iconOnly ? height * 1.35 : nil)
            .frame(maxWidth: iconOnly ? nil : .infinity, minHeight: height)
            .overlay {
                if look.id.isPaperClub {
                    Capsule().strokeBorder(look.outline, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                } else {
                    Capsule().strokeBorder(look.dash, style: StrokeStyle(lineWidth: max(1.5, look.stroke.dashed), dash: [5, 4]))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(title)
    }
}

// MARK: - Quiet compact pill (Restore)

/// A quiet 44 pt pill for a row's own action. C outlines it in ink: it is pressable.
struct GymsQuietPillStyle: ButtonStyle {
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let label = configuration.label
            .font(look.id == .anatomy ? .system(.subheadline, design: .rounded, weight: .bold)
                  : .system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 18)
            .frame(minHeight: height)
        Group {
            switch look.id {
            case .floodlight:
                label.background(look.surfaceRaised, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            case .anatomy:
                label.background(look.controlFill, in: Capsule())
            case .paper, .carbon:
                label.background(pressed ? look.pressedFill : look.surface, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.outline, lineWidth: 1.5) }
            }
        }
        .contentShape(Capsule())
        .pressFeedback(pressed, look.id.isPaperClub ? .none : .scale)
    }
}

// MARK: - Small information tag (unit override, "Custom", category, "Assisted")

/// Information, never a control: A a raised chip, B a white-8 % capsule, C a hairline rule in
/// secondary ink (C keeps its solid ink outline for things you can press).
struct GymsTag: View {
    var text: String
    var category: EquipmentCategory??
    var symbol: String?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .caption) private var glyph: CGFloat = 13

    init(_ text: String, category: EquipmentCategory?? = nil, symbol: String? = nil) {
        self.text = text
        self.category = category
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 5) {
            if let category {
                GymsEquipmentGlyph(category: category, side: glyph)
            } else if let symbol {
                Image(systemName: symbol).font(.system(.caption2, weight: .bold))
            }
            Text(text)
                .font(.system(.caption, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(look.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            switch look.id {
            case .floodlight: RoundedRectangle(cornerRadius: 6).fill(look.surfaceRaised)
            case .anatomy: Capsule().fill(look.controlFill)
            case .paper, .carbon: RoundedRectangle(cornerRadius: 6).strokeBorder(look.hairline, lineWidth: 1)
            }
        }
        .fixedSize()
    }
}

// MARK: - The best value (A burst, B star, C highlighter) and the last-used mark

/// A best set in the look's "best" vocabulary. `prominent` = the hero figure.
struct GymsBestValue: View {
    var text: String
    var font: Font
    var prominent = true
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swiped = false

    var body: some View {
        HStack(alignment: .center, spacing: prominent ? 8 : 5) {
            switch look.id {
            case .floodlight:
                Image(systemName: "burst.fill")
                    .font(.system(prominent ? .title3 : .caption, weight: .bold))
                    .foregroundStyle(look.positive)
                Text(text).font(font).foregroundStyle(look.textPrimary)
            case .anatomy:
                Image(systemName: "star.fill")
                    .font(.system(prominent ? .footnote : .caption2, weight: .bold))
                    .imageScale(prominent ? .medium : .small)
                    .foregroundStyle(look.positive)
                    .frame(width: prominent ? 28 : 18, height: prominent ? 28 : 18)
                    .background(look.positive.opacity(0.13), in: Circle())
                Text(text).font(font).foregroundStyle(look.textPrimary)
            case .paper, .carbon:
                Text(text).font(font)
                    .foregroundStyle(swiped ? look.onPositive : look.textPrimary)
                    .padding(.horizontal, prominent ? 6 : 4)
                    .padding(.vertical, 1)
                    .background {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(look.positive)
                            .scaleEffect(x: swiped ? 1 : 0.001, y: 1, anchor: .leading)
                    }
                    .onAppear {
                        guard !swiped else { return }
                        if reduceMotion { swiped = true } else {
                            withAnimation(.easeOut(duration: 0.4).delay(0.25)) { swiped = true }
                        }
                    }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// "Last used": the History glyph before the look's last-done word (A "Sep 21", B "Mon",
/// C "3 days ago"), so a date beside a best never reads as the day the best was set.
struct GymsLastUsed: View {
    var date: Date
    var now: Date
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.arrow.circlepath").imageScale(.small)
            Text(GymsDate.label(date, now: now))
        }
        .font(.system(look.id == .anatomy ? .footnote : .caption, weight: .semibold))
        .foregroundStyle(look.textSecondary)
        .lineLimit(1)
    }
}

// MARK: - Swipe to delete (with each look's delete tile)

/// A row that swipes left to reveal the look's delete tile. The pan only begins for a clearly
/// horizontal drag (leftward when closed), and the list's vertical scroll waits for it to
/// decline, so scrolling never catches a row and a swipe never scrolls. Tapping the open row
/// closes it; tapping the tile asks `onDelete` (which confirms). One row open at a time via
/// `openID`. VoiceOver gets a "Delete" action.
struct GymsSwipeRow<Content: View>: View {
    var id: String
    @Binding var openID: String?
    var accessibilityDeleteName: String = "Delete"
    var onDelete: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragX: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 86

    private var isOpen: Bool { openID == id }
    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86) }

    var body: some View {
        let base: CGFloat = isOpen ? -tileWidth : 0
        let raw = base + dragX
        let offset = raw < -tileWidth ? -tileWidth + (raw + tileWidth) * 0.3 : min(0, raw)
        content
            .overlay {
                if isOpen {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { withAnimation(spring) { openID = nil } }
                        .accessibilityHidden(true)
                }
            }
            .offset(x: offset)
            .background(alignment: .trailing) {
                GymsDeleteTile(action: onDelete)
                    .frame(width: max(0, -offset))
                    .opacity(offset < -4 ? 1 : 0)
            }
            .clipped()
            .gesture(GymsHorizontalPan(isOpen: isOpen, onBegan: {
                if openID != nil && openID != id { withAnimation(spring) { openID = nil } }
            }, onChanged: { translation in
                dragX = translation
            }, onEnded: { translation, velocity in
                let end = base + translation + velocity * 0.18
                withAnimation(spring) {
                    openID = end < -tileWidth * 0.5 ? id : (isOpen ? nil : openID)
                    dragX = 0
                }
            }))
            .accessibilityAction(named: accessibilityDeleteName) { onDelete() }
    }
}

/// A UIKit pan that begins only for a horizontal drag and makes the enclosing scroll view's
/// pan wait for it to decline (UITableView's swipe behaviour; a SwiftUI DragGesture inside a
/// ScrollView either blocks the scroll or scrolls while swiping).
struct GymsHorizontalPan: UIGestureRecognizerRepresentable {
    var isOpen: Bool
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.isOpen = isOpen
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began:
            onBegan()
            onChanged(translation)
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed:
            onEnded(0, 0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isOpen = false

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            guard abs(v.x) > abs(v.y) * 1.2 else { return false }
            // Closed rows open leftward only, so the back-swipe from the edge still works.
            return isOpen || v.x < 0
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView && other is UIPanGestureRecognizer
        }
    }
}

/// A: the danger tile with ink glyph and word. B: a raised tile with a pearl trash (no hue).
/// C: the destructive double rule with the trash in a solid disc (red means heart).
struct GymsDeleteTile: View {
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                let showsWord = geo.size.width > 64
                ZStack {
                    switch look.id {
                    case .floodlight:
                        look.destructive
                        stack(showsWord, glyph: look.onAction, word: look.onAction)
                    case .anatomy:
                        look.surfaceRaised
                        stack(showsWord, glyph: look.textPrimary, word: look.textPrimary)
                    case .paper, .carbon:
                        look.surface
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(look.outline, lineWidth: 2)
                            .padding(5)
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(look.outline, lineWidth: 1.2)
                            .padding(9)
                        VStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(look.surface)
                                .frame(width: 26, height: 26)
                                .background(look.textPrimary, in: Circle())
                            if showsWord {
                                Text("Delete").font(.system(.caption, weight: .bold)).foregroundStyle(look.textPrimary)
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
    }

    private func stack(_ showsWord: Bool, glyph: Color, word: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "trash").font(.system(.body, weight: .semibold)).foregroundStyle(glyph)
            if showsWord {
                Text("Delete").font(.system(.caption, weight: .semibold)).foregroundStyle(word)
            }
        }
    }
}

// MARK: - Sheet header (Cancel · title · commit) that re-flows at AX sizes

/// Cancel on glass, the title centred, the filled commit. At AX sizes the title leaves the bar
/// and becomes the first content line under the buttons (it would run into Cancel). The
/// disabled commit stays a visible capsule in every look.
struct GymsSheetHeader: View {
    var title: String
    var cancel: () -> Void
    var commitTitle: String?
    var commitEnabled = true
    var commit: () -> Void = {}
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        let titleText = Text(title)
            .foregroundStyle(look.textPrimary)
            .accessibilityAddTraits(.isHeader)
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    buttons
                    titleText.font(look.font.title2).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ZStack {
                    titleText.font(look.font.navTitle).lineLimit(1).padding(.horizontal, 104)
                    buttons
                }
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var buttons: some View {
        HStack {
            GlassCapsuleButton("Cancel", action: cancel)
            Spacer(minLength: 12)
            if let commitTitle {
                Button(action: commit) {
                    Text(commitTitle)
                        .font(look.font.button)
                        .foregroundStyle(commitEnabled ? look.onAction : look.textTertiary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 18)
                        .frame(minHeight: height)
                        .background { commitFill }
                        .contentShape(Capsule())
                }
                .buttonStyle(.lookPressable)
                .disabled(!commitEnabled)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityShowsLargeContentViewer { Text(commitTitle) }
            }
        }
    }

    @ViewBuilder private var commitFill: some View {
        if commitEnabled {
            Capsule().fill(look.action)
                .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.outline, lineWidth: 2) } }
        } else if look.id.isPaperClub {
            // C: surfaceRaised is the sheet itself, so the capsule is drawn as a faint outline.
            Capsule().strokeBorder(look.outline.opacity(0.28), lineWidth: 2)
        } else {
            Capsule().fill(look.surfaceRaised)
        }
    }
}

// MARK: - Best-set chart on one machine

/// The best set per session on this machine, sessions evenly spaced, drawn by hand so every
/// mark sits exactly on its point: new bests (strictly better than every earlier set here)
/// carry the look's best mark and their set ("100 × 10"), so a rep gain at the same weight
/// reads as the best it is and a repeat never does. A label that would overlap its neighbour
/// drops below the line. Two guide lines: where it started and the best. First and last dates sit
/// under their points. The line draws itself in on appear (Reduce Motion: drawn).
struct GymsBestChart: View {
    var points: [ProgressPoint]
    var loadType: LoadType
    var unit: WeightUnit
    var height: CGFloat = 150
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    private struct Item: Identifiable {
        var id: Int
        var date: Date
        var value: Double
        var set: SetValue
        var isRecord: Bool
    }

    private var items: [Item] {
        let values: [(ProgressPoint, Double)] = points.compactMap { p in
            if loadType == .bodyweight { return (p, Double(p.best.reps)) }
            guard let v = p.bestKg.map({ unit.fromKg($0) }) ?? p.best.weight else { return nil }
            return (p, v)
        }
        return values.enumerated().map { i, pair in
            Item(id: i, date: pair.0.date, value: pair.1, set: pair.0.best, isRecord: pair.0.isRecord)
        }
    }

    /// Labels go above their point unless that would overlap an earlier label; then below.
    /// Widths are estimated from the caption2 figures (about 7 pt a character, plus padding and a clear gap).
    private func placeBelow(_ items: [Item], at pos: (Item) -> CGPoint) -> Set<Int> {
        var placed: [CGRect] = []
        var below: Set<Int> = []
        for item in items where item.isRecord {
            let p = pos(item)
            let width = CGFloat(Format.setShort(item.set, loadType: loadType).count) * 7 + 22
            let above = CGRect(x: p.x - width / 2, y: p.y - 26, width: width, height: 18)
            if placed.contains(where: { $0.intersects(above) }) {
                below.insert(item.id)
                placed.append(above.offsetBy(dx: 0, dy: 34))
            } else {
                placed.append(above)
            }
        }
        return below
    }

    private let labelRoom: CGFloat = 24
    private let axisRoom: CGFloat = 22
    private let trailingRoom: CGFloat = 34

    var body: some View {
        let items = items
        GeometryReader { geo in
            let plot = CGRect(x: 10, y: labelRoom, width: max(1, geo.size.width - 10 - trailingRoom),
                              height: max(1, geo.size.height - labelRoom * 2 - axisRoom))
            let values = items.map(\.value)
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 1)
            let pos: (Item) -> CGPoint = { item in
                let x = items.count > 1 ? plot.minX + plot.width * CGFloat(item.id) / CGFloat(items.count - 1) : plot.midX
                let y = plot.maxY - plot.height * CGFloat((item.value - lo) / span)
                return CGPoint(x: x, y: y)
            }
            let below = placeBelow(items, at: pos)
            ZStack(alignment: .topLeading) {
                // Guides: the start and the best.
                ForEach(Array(Set([lo, hi])).sorted(), id: \.self) { v in
                    let y = plot.maxY - plot.height * CGFloat((v - lo) / span)
                    Path { p in p.move(to: CGPoint(x: plot.minX - 6, y: y)); p.addLine(to: CGPoint(x: plot.maxX + 6, y: y)) }
                        .stroke(look.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    Text(Format.number(v))
                        .font(.system(.caption2, weight: .semibold).monospacedDigit())
                        .foregroundStyle(look.textTertiary)
                        .fixedSize()
                        .position(x: plot.maxX + trailingRoom / 2 + 6, y: y)
                }
                Path { p in
                    for (i, item) in items.enumerated() {
                        if i == 0 { p.move(to: pos(item)) } else { p.addLine(to: pos(item)) }
                    }
                }
                .trim(from: 0, to: drawn)
                .stroke(lineColor, style: StrokeStyle(lineWidth: look.id.isPaperClub ? 2.5 : 2, lineCap: .round, lineJoin: .round))
                ForEach(items) { item in
                    let p = pos(item)
                    marker(item)
                        .position(p)
                        .opacity(drawn >= CGFloat(item.id) / CGFloat(max(items.count - 1, 1)) - 0.001 ? 1 : 0)
                    if item.isRecord {
                        label(item)
                            .fixedSize()
                            .position(x: min(max(p.x, plot.minX + 26), plot.maxX + 8),
                                      y: below.contains(item.id) ? p.y + 17 : p.y - 17)
                            .opacity(drawn >= 1 ? 1 : 0)
                    }
                }
                if let first = items.first {
                    dateLabel(first.date).position(x: max(pos(first).x, 24), y: geo.size.height - axisRoom / 2)
                }
                if items.count > 1, let last = items.last {
                    dateLabel(last.date).position(x: min(pos(last).x, geo.size.width - 24), y: geo.size.height - axisRoom / 2)
                }
            }
        }
        .frame(height: height)
        .onAppear {
            guard drawn == 0 else { return }
            if reduceMotion { drawn = 1 } else { withAnimation(.easeOut(duration: 0.8).delay(0.2)) { drawn = 1 } }
        }
    }

    private var lineColor: Color { look.id == .floodlight ? look.done : look.textPrimary }

    private func dateLabel(_ date: Date) -> some View {
        Text(Format.shortDate(date))
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(look.textTertiary)
            .fixedSize()
    }

    @ViewBuilder private func label(_ item: Item) -> some View {
        let text = Text(Format.setShort(item.set, loadType: loadType))
        switch look.id {
        case .floodlight:
            text.font(Font.system(.caption2, weight: .heavy).width(.expanded)).foregroundStyle(look.textPrimary)
        case .anatomy:
            text.font(.system(.caption2, design: .rounded, weight: .heavy)).foregroundStyle(look.textPrimary)
        case .paper, .carbon:
            text.font(Font.system(.caption2, weight: .heavy).width(.expanded))
                .foregroundStyle(look.onPositive)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(look.positive, in: RoundedRectangle(cornerRadius: 3))
        }
    }

    @ViewBuilder private func marker(_ item: Item) -> some View {
        if item.isRecord {
            switch look.id {
            case .floodlight:
                Image(systemName: "burst.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(look.positive)
                    .background(Circle().fill(look.surface).frame(width: 10, height: 10))
            case .anatomy:
                Image(systemName: "star.fill").font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(look.onDone)
                    .frame(width: 16, height: 16).background(look.done, in: Circle())
            case .paper, .carbon:
                Circle().fill(look.positive).frame(width: 13, height: 13)
                    .overlay { Circle().strokeBorder(look.onPositive, lineWidth: 1.5) }
            }
        } else {
            Circle().fill(look.surface).frame(width: 8, height: 8)
                .overlay { Circle().strokeBorder(lineColor, lineWidth: 2) }
        }
    }
}

// MARK: - Grouping menu (compact: one control instead of a row of pills)

/// The current grouping with an up-down chevron; the menu lists the choices with a check.
struct GymsGroupingMenu: View {
    var titles: [String]
    @Binding var selection: Int
    var accessibilityName: String
    @Environment(\.look) private var look

    var body: some View {
        Menu {
            Picker(accessibilityName, selection: $selection) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Text(title).tag(index)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(titles.indices.contains(selection) ? titles[selection] : "")
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(.caption, weight: .bold))
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background {
                switch look.id {
                case .floodlight: Capsule().fill(look.surfaceRaised)
                case .anatomy: Capsule().fill(look.controlFill)
                case .paper, .carbon: Capsule().fill(look.surface).overlay { Capsule().strokeBorder(look.outline, lineWidth: 1.5) }
                }
            }
            .padding(.vertical, 2)
            .contentShape(Capsule())
        }
        .menuOrder(.fixed)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(titles.indices.contains(selection) ? titles[selection] : "")
    }
}

/// "App (lb) | kg | lb": segmented pills, stacked rows at AX.
struct GymsUnitChoice: View {
    var options: [String]
    @Binding var selection: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Chip(option, symbol: selection == index ? "checkmark" : nil, isSelected: selection == index) { selection = index }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            SegmentedPills(options, selection: $selection)
        }
    }
}

/// A simple wrapping row (chips, tags).
struct GymsFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// List rows highlight with the pressed fill (no scale, so lists don't wobble).
struct GymsRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? look.pressedFill : .clear)
    }
}

// MARK: - Inline nav title, capture paging, sheet type override

extension View {
    /// The pushed screen's inline title in the look's nav face, faded in when `visible`.
    func gymsInlineTitle(_ title: String, visible: Bool) -> some View {
        modifier(GymsInlineTitle(title: title, visible: visible))
    }

    /// Capture variants "p2" / "p3" scroll the page to its 2nd / 3rd viewport on appear.
    func gymsCapturePaging(_ variant: String?, position: Binding<ScrollPosition>) -> some View {
        modifier(GymsCapturePaging(page: GymsCapturePaging.page(variant), position: position))
    }

    /// Reports whether the scroll view has moved past `threshold` (for the inline title).
    func gymsScrolledPast(_ threshold: CGFloat, into flag: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > threshold
        } action: { _, past in
            if flag.wrappedValue != past { withAnimation(.easeOut(duration: 0.18)) { flag.wrappedValue = past } }
        }
    }

    /// Applies the prototype's Dynamic Type override (`-axl YES`, Z04/Z05) inside a Gyms sheet.
    /// The shell applies it to the tabs and covers; sheets over the tabs do not inherit it.
    func gymsSheetTypeOverride(_ size: DynamicTypeSize?) -> some View {
        modifier(GymsSheetTypeOverride(size: size))
    }
}

private struct GymsInlineTitle: ViewModifier {
    var title: String
    var visible: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .opacity(visible ? 1 : 0)
                        .accessibilityHidden(!visible)
                }
            }
    }
}

struct GymsCapturePaging: ViewModifier {
    var page: Int
    @Binding var position: ScrollPosition
    @State private var metrics = Metrics()
    @State private var applied = false

    struct Metrics: Equatable {
        var viewport: CGFloat = 0
        var content: CGFloat = 0
        var insetTop: CGFloat = 0
        var insetBottom: CGFloat = 0
    }

    static func page(_ variant: String?) -> Int {
        switch variant {
        case "p2": 1
        case "p3": 2
        default: 0
        }
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Metrics.self) { geo in
                Metrics(viewport: geo.containerSize.height, content: geo.contentSize.height,
                        insetTop: geo.contentInsets.top, insetBottom: geo.contentInsets.bottom)
            } action: { _, new in
                metrics = new
            }
            .task {
                guard page > 0, !applied else { return }
                // Wait for the scroll view's geometry to be measured and settle (a push or
                // sheet may still be animating), then scroll once.
                var last = Metrics()
                for _ in 0..<40 {
                    try? await Task.sleep(for: .milliseconds(120))
                    if metrics.viewport > 0, metrics.content > 0, metrics == last { break }
                    last = metrics
                }
                try? await Task.sleep(for: .milliseconds(150))
                applied = true
                // p3 always reaches the end; on a page longer than three viewports p2 sits
                // halfway, so the three captures together still cover the whole screen.
                let visible = metrics.viewport - metrics.insetTop - metrics.insetBottom
                let step = max(200, visible - 60)
                let maxOffset = max(0, metrics.content - metrics.viewport + metrics.insetBottom)
                let target: CGFloat
                if page >= 2 {
                    target = maxOffset
                } else if maxOffset > 2 * step {
                    target = maxOffset / 2
                } else {
                    target = min(step - metrics.insetTop, maxOffset)
                }
                position.scrollTo(y: target)
            }
    }
}

private struct GymsSheetTypeOverride: ViewModifier {
    var size: DynamicTypeSize?
    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}
