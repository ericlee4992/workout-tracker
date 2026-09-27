import SwiftUI
import UIKit

// Floodlight redesign ticket 06 — the Gyms area's pieces, ported from the prototype
// (`Screens/Gyms/GymsComponents.swift`) in the ★ look: equipment-type glyphs, the gym monogram,
// the stat strip, the eight-week visit rhythm, the Current badge, tags, the best value and
// last-used marks, the dashed "make one" row, group headers, the grouping menu, the unit choice
// and the best-set chart on one machine.

// MARK: - Equipment-type glyphs (24-unit grid, drawn like WeightStackGlyph)

/// A weight plate seen face-on: rim, hub, grip slot. Plate-loaded machines.
struct PlateGlyph: Shape {
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
struct PulleyGlyph: Shape {
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
struct RackGlyph: Shape {
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
struct StationGlyph: Shape {
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

/// The glyph for an equipment type. No type (no model, or a model without one) is an empty dashed
/// ring: it claims nothing about the machine.
struct EquipmentGlyph: View {
    var category: EquipmentCategory?
    var side: CGFloat

    var body: some View {
        let line = StrokeStyle(lineWidth: max(1.4, side * 0.085), lineCap: .round, lineJoin: .round)
        Group {
            switch category {
            case .plateLoaded: PlateGlyph().stroke(style: line)
            case .cable: PulleyGlyph().stroke(style: line)
            case .rackOrSmith: RackGlyph().stroke(style: line)
            case .bodyweight: StationGlyph().stroke(style: line)
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

/// The equipment glyph in a raised square cell; no type: an empty dashed cell.
struct EquipmentTile: View {
    var category: EquipmentCategory?
    var size: CGFloat = 40
    var dimmed = false
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * min(scale, 1.5)
        let shape = RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
        Group {
            if category == nil {
                shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.3, dash: [4, 3.5]))
            } else {
                EquipmentGlyph(category: category, side: side * 0.56)
                    .foregroundStyle(look.textPrimary)
                    .frame(width: side, height: side)
                    .background(look.surfaceRaised, in: shape)
            }
        }
        .frame(width: side, height: side)
        .opacity(dimmed ? 0.72 : 1)
        .accessibilityHidden(true)
    }
}

// MARK: - Gym monogram (per-gym identity without inventing data)

struct GymMonogram: View {
    var name: String
    var size: CGFloat = 48
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" })
            .filter { $0.first?.isLetter == true || $0.first?.isNumber == true }
        let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    var body: some View {
        let side = size * min(scale, 1.6)
        Text(Self.initials(name))
            .font(Font.system(size: side * 0.36, weight: .black).width(.expanded))
            .foregroundStyle(look.textPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(width: side, height: side)
            .background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Stat strip (big numbers, small labels)

struct GymStat: Identifiable, Hashable {
    var id: String { label }
    var value: String
    var label: String
    /// Counts roll up when they appear.
    var number: Int?
    /// Dates ("Sep 23", "Yesterday") are words: a size down, on the numbers' baseline.
    var isWord = false

    static func count(_ n: Int, _ singular: String, _ plural: String) -> GymStat {
        GymStat(value: LookFormat.grouped(n), label: n == 1 ? singular : plural, number: n)
    }

    static func day(_ date: Date, _ label: String) -> GymStat {
        GymStat(value: GymOverviewMath.relativeDay(date, now: .now), label: label, isWord: true)
    }
}

/// Three facts in a row, divided by hairlines (one scoreboard). `embedded` drops the surface
/// (inside a gym card). AX sizes: one row per fact, number leading, label trailing.
struct GymStatStrip: View {
    var stats: [GymStat]
    var embedded = false
    /// Keeps sibling cards' column rhythm when a fact is missing (never visited: no last visit).
    var columns: Int?
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
            .modifier(StripSurface(embedded: embedded))
        } else {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 { LookDivider(vertical: true) }
                    VStack(alignment: .leading, spacing: 3) {
                        value(stat)
                        label(stat)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stat.label) \(stat.value)")
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
            .modifier(StripSurface(embedded: embedded))
        }
    }

    /// The value on the number's baseline, in the number's line box (a hidden "0" sets it).
    private func value(_ stat: GymStat) -> some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .lastTextBaseline)) {
            Text(verbatim: "0").font(look.font.statNumber).hidden()
            Group {
                if let number = stat.number {
                    RollingCount(value: number)
                } else {
                    Text(stat.value)
                }
            }
            .font(stat.isWord ? Font.system(.title3, weight: .heavy).width(.expanded) : look.font.statNumber)
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }

    private func label(_ stat: GymStat) -> some View {
        Text(stat.label)
            .font(.caption)
            .foregroundStyle(look.textSecondary)
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
    }
}

private struct StripSurface: ViewModifier {
    var embedded: Bool
    func body(content: Content) -> some View {
        if embedded { content } else { content.lookSurface(.stat) }
    }
}

/// A count that rolls up to its value on appear (whole numbers only, so a still frame never
/// catches a fraction). Reduce Motion: the value, still.
struct RollingCount: View {
    var value: Int
    @State private var shown: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = shown ?? (reduceMotion ? value : 0)
        Text(LookFormat.grouped(current))
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
            .accessibilityLabel(LookFormat.grouped(value))
    }
}

// MARK: - Visit rhythm (visits per week, last 8 weeks)

/// Eight weeks of visits at a gym, oldest to this week: lit cells carrying the count; this week
/// unvisited is the dashed "today" mark.
struct GymVisitRhythm: View {
    var counts: [Int]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var cellHeight: CGFloat = 22

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            Text("Last 8 weeks")
                .font(.caption)
                .foregroundStyle(look.textSecondary)
                .fixedSize()
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                    cell(count, isThisWeek: index == counts.count - 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: cellHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visits per week, last 8 weeks: \(counts.map(String.init).joined(separator: ", "))")
    }

    @ViewBuilder
    private func cell(_ count: Int, isThisWeek: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        if count > 0 {
            Text(verbatim: "\(count)")
                .font(Font.system(.caption2, weight: .heavy).width(.expanded).monospacedDigit())
                .foregroundStyle(look.onDone)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(look.done, in: shape)
        } else if isThisWeek {
            shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
        } else {
            shape.fill(look.ringTrack)
        }
    }
}

/// The gym Home is set to: a state (not a control), the selection lozenge.
struct GymCurrentBadge: View {
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: look.gymSymbol).font(.system(.caption2, weight: .bold))
            Text("Current").font(.system(.caption, weight: .bold))
        }
        .foregroundStyle(look.selection)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(look.selectionFill, in: Capsule())
        .fixedSize()
    }
}

// MARK: - Tags, best value, last used

/// Information, never a control: a raised chip (unit override, "Custom", type, "Assisted").
struct GymTag: View {
    var text: String
    var category: EquipmentCategory??
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .caption) private var glyph: CGFloat = 13

    init(_ text: String, category: EquipmentCategory?? = nil) {
        self.text = text
        self.category = category
    }

    var body: some View {
        HStack(spacing: 5) {
            if let category { EquipmentGlyph(category: category, side: glyph) }
            Text(text)
                .font(.system(.caption, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(look.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(look.surfaceRaised))
        .fixedSize()
    }
}

/// A best set: the new-best burst before the figure. `prominent` = the hero figure.
struct GymBestValue: View {
    var text: String
    var font: Font
    var prominent = true
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .center, spacing: prominent ? 8 : 5) {
            Image(systemName: "burst.fill")
                .font(.system(prominent ? .title3 : .caption, weight: .bold))
                .foregroundStyle(look.positive)
                .accessibilityHidden(true)
            Text(text).font(font).foregroundStyle(look.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// "Last used": the history glyph before the day, so a date beside a best never reads as the day
/// the best was set.
struct GymLastUsed: View {
    var date: Date
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.arrow.circlepath").imageScale(.small)
            Text(GymOverviewMath.relativeDay(date, now: .now))
        }
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(look.textSecondary)
        .lineLimit(1)
    }
}

// MARK: - "Make one" row and pill (dashed)

/// A full-width dashed "make one" row: Add Gym…, Add Machine…, New Model….
struct MakeRow: View {
    var title: String
    var symbol: String = "plus"
    /// What it will make ("Belt Squat" from a search with no match).
    var detail: String?
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var glyph: CGFloat = 36

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(.body, weight: .semibold))
                    .frame(width: glyph)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, weight: .semibold))
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
            .dashedOutline(look.dash, radius: look.radius.tile, lineWidth: look.stroke.dashed)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
    }
}

/// A quiet 44 pt pill for a row's own action (Restore).
struct QuietPillStyle: ButtonStyle {
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 18)
            .frame(minHeight: height)
            .background(look.surfaceRaised, in: Capsule())
            .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            .contentShape(Capsule())
            .pressFeedback(configuration.isPressed, .scale)
    }
}

// MARK: - Group header and grouping menu

/// A group title with a small family-colour swatch; groups without a family get the same-size
/// empty swatch so every title starts at one inset.
struct GymGroupHeader: View {
    var title: String
    var family: MuscleFamily?
    var showsSwatch = true
    var count: Int?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var swatch: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if showsSwatch {
                let shape = RoundedRectangle(cornerRadius: swatch * 0.3, style: .continuous)
                if let family {
                    shape.fill(look.family(family)).frame(width: swatch, height: swatch)
                } else {
                    shape.stroke(look.textTertiary, lineWidth: 1.5)
                        .frame(width: swatch - 1.5, height: swatch - 1.5)
                        .frame(width: swatch, height: swatch)
                }
            }
            Text(title)
                .font(look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let count {
                Text(verbatim: "\(count)")
                    .font(Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit())
                    .foregroundStyle(look.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The current choice with an up-down chevron (a collapsed picker: never the primary style).
/// Each option carries its own identifier so UI tests can pick it.
struct GroupingMenu<Option: Hashable>: View {
    var options: [Option]
    var title: (Option) -> String
    var identifier: (Option) -> String
    @Binding var selection: Option
    var accessibilityName: String
    @Environment(\.look) private var look

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
                .accessibilityIdentifier(identifier(option))
            }
        } label: {
            HStack(spacing: 6) {
                Text(title(selection))
                    .font(.system(.subheadline, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(.caption, weight: .bold))
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(Capsule().fill(look.surfaceRaised))
            .padding(.vertical, 2)
            .contentShape(Capsule())
        }
        .menuOrder(.fixed)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(title(selection))
    }
}

/// "App (lb) | kg | lb": segmented pills (each a button carrying its own identifier); stacked
/// checkable chips at AX sizes.
struct UnitChoice: View {
    var options: [String]
    @Binding var selection: Int
    var identifiers: [String] = []
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Chip(option, symbol: selection == index ? "checkmark" : nil, isSelected: selection == index) {
                        selection = index
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(identifiers.indices.contains(index) ? identifiers[index] : option)
                }
            }
        } else {
            SegmentedPills(options, selection: $selection)
        }
    }
}

extension WeightUnit? {
    /// The unit choice's index: 0 = inherit (App / Gym), 1 = kg, 2 = lb.
    var unitChoiceIndex: Int {
        switch self {
        case .none: 0
        case .some(.kg): 1
        case .some(.lb): 2
        }
    }

    static func fromUnitChoice(_ index: Int) -> WeightUnit? {
        switch index {
        case 1: .kg
        case 2: .lb
        default: nil
        }
    }
}

// MARK: - Best-set chart on one machine

/// The best set per day of one record scope on a machine, days evenly spaced, drawn by hand so
/// every mark sits on its point: new bests (`ProgressSeriesMath.recordDays`, beating every earlier
/// day by the records' rank) carry the burst and their set ("100 × 10"); a label that would
/// overlap its neighbour drops below the line. Two guides: where it started and the best. The
/// line draws itself in (Reduce Motion: drawn).
struct MachineBestChart: View {
    var series: ProgressSeries
    var recordDays: Set<Date>
    var height: CGFloat = 168
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
        series.points.compactMap { point -> (ProgressPoint, Double, SetValue)? in
            guard let value = point.bestKg, let reps = point.bestReps else { return nil }
            let set = SetValue(weight: point.bestValue, unit: point.bestUnit ?? .kg, reps: reps)
            return (point, value, set)
        }
        .enumerated()
        .map { index, item in
            Item(id: index, date: item.0.date, value: item.1, set: item.2, isRecord: recordDays.contains(item.0.date))
        }
    }

    private func placeBelow(_ items: [Item], at pos: (Item) -> CGPoint) -> Set<Int> {
        var placed: [CGRect] = []
        var below: Set<Int> = []
        for item in items where item.isRecord {
            let p = pos(item)
            let width = CGFloat(LookFormat.setShort(item.set, loadType: series.loadType).count) * 7 + 22
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
    private let trailingRoom: CGFloat = 12

    var body: some View {
        let items = items
        GeometryReader { geo in
            let plot = CGRect(x: 10, y: labelRoom, width: max(1, geo.size.width - 10 - trailingRoom),
                              height: max(1, geo.size.height - labelRoom * 2 - axisRoom))
            let values = items.map(\.value)
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 0.001)
            let pos: (Item) -> CGPoint = { item in
                let x = items.count > 1 ? plot.minX + plot.width * CGFloat(item.id) / CGFloat(items.count - 1) : plot.midX
                let y = hi == lo ? plot.midY : plot.maxY - plot.height * CGFloat((item.value - lo) / span)
                return CGPoint(x: x, y: y)
            }
            let below = placeBelow(items, at: pos)
            ZStack(alignment: .topLeading) {
                ForEach(Array(Set([lo, hi])).sorted(), id: \.self) { v in
                    let y = hi == lo ? plot.midY : plot.maxY - plot.height * CGFloat((v - lo) / span)
                    Path { p in p.move(to: CGPoint(x: plot.minX - 6, y: y)); p.addLine(to: CGPoint(x: plot.maxX + 6, y: y)) }
                        .stroke(look.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                Path { p in
                    for (i, item) in items.enumerated() {
                        if i == 0 { p.move(to: pos(item)) } else { p.addLine(to: pos(item)) }
                    }
                }
                .trim(from: 0, to: drawn)
                .stroke(look.done, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ForEach(items) { item in
                    let p = pos(item)
                    marker(item)
                        .position(p)
                        .opacity(drawn >= CGFloat(item.id) / CGFloat(max(items.count - 1, 1)) - 0.001 ? 1 : 0)
                    if item.isRecord {
                        Text(LookFormat.setShort(item.set, loadType: series.loadType))
                            .font(Font.system(.caption2, weight: .heavy).width(.expanded))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize()
                            .position(x: min(max(p.x, plot.minX + 26), plot.maxX - 20),
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

    private func dateLabel(_ date: Date) -> some View {
        Text(LookFormat.shortDate(date))
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(look.textTertiary)
            .fixedSize()
    }

    @ViewBuilder private func marker(_ item: Item) -> some View {
        if item.isRecord {
            Image(systemName: "burst.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(look.positive)
                .background(Circle().fill(look.surface).frame(width: 10, height: 10))
        } else {
            Circle().fill(look.surface).frame(width: 8, height: 8)
                .overlay { Circle().strokeBorder(look.done, lineWidth: 2) }
        }
    }
}

// MARK: - Screen chrome

extension View {
    /// A pushed Gyms page's bar: the title fades into the bar once the page scrolls past its hero
    /// (as History does); the bar's ground appears with it.
    func gymsInlineTitle(_ title: String, visible: Bool) -> some View {
        modifier(GymsInlineTitle(title: title, visible: visible))
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
            .toolbarBackground(look.ground, for: .navigationBar)
            .toolbarBackgroundVisibility(visible ? .visible : .hidden, for: .navigationBar)
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
