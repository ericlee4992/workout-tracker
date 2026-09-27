import SwiftUI

// Numbers: big and heavy; labels: small. Grouped numbers per look:
// A: ONE scoreboard panel divided by hairlines. B: separate solid stat tiles (radius 20).
// C: one ticket per pair (radius 16, soft rule, vertical rule between halves).

// MARK: - Section header

struct SectionHeader: View {
    /// `.section`: a section inside a page (20 pt class). `.page`: the top-level section of a
    /// tab page, e.g. Home "Templates" (B steps up to Title 2).
    enum Level { case section, page }
    var title: String
    var level: Level = .section
    var trailing: String?
    var trailingAction: (() -> Void)?
    @Environment(\.look) private var look

    init(_ title: String, level: Level = .section, trailing: String? = nil, trailingAction: (() -> Void)? = nil) {
        self.title = title
        self.level = level
        self.trailing = trailing
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(level == .page ? look.font.pageSectionTitle : look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let trailing {
                if let trailingAction {
                    Button(trailing, action: trailingAction)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.actionText)
                        .frame(minHeight: 44)
                } else {
                    Text(trailing).font(look.font.caption).foregroundStyle(look.textTertiary)
                }
            }
        }
    }
}

// MARK: - Stat figure

/// Big number + small unit, with a small caption label (and glyph) above it.
struct StatFigure: View {
    var value: String
    var unit: String?
    var label: String?
    var symbol: String?
    /// Value colour (heart rate figures use the heart colour in A/B).
    var tint: Color?
    /// Glyph colour (C colours only the heart glyph).
    var symbolTint: Color?
    var countsUp = false
    var numberFont: Font?

    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab

    init(value: String, unit: String? = nil, label: String? = nil, symbol: String? = nil, tint: Color? = nil,
         symbolTint: Color? = nil, countsUp: Bool = false, numberFont: Font? = nil) {
        self.value = value
        self.unit = unit
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.symbolTint = symbolTint
        self.countsUp = countsUp
        self.numberFont = numberFont
    }

    var body: some View {
        let secondary = onSlab ? look.onSlabSecondary : look.textSecondary
        VStack(alignment: .leading, spacing: look.id == .floodlight ? 6 : 4) {
            if label != nil || symbol != nil {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(symbolTint ?? secondary)
                    }
                    if let label {
                        Text(label).font(.system(.footnote, weight: look.id == .floodlight ? .regular : .semibold))
                            .foregroundStyle(secondary)
                            .lineLimit(1)
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                number
                    .font(numberFont ?? look.font.bigNumber)
                    .foregroundStyle(tint ?? (onSlab ? look.onSlab : look.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([label, value, unit].compactMap { $0 }.joined(separator: " "))
    }

    @ViewBuilder private var number: some View {
        if countsUp, let parsed = CountUpFormat.parse(value) {
            CountUpText(parsed.value, format: parsed.format)
        } else {
            Text(value)
        }
    }
}

/// Parses display strings back into a count-up ("52:10" → seconds, "18,450" → number). Numbers
/// are read in the locale that formatted them (Codex review 04: a German "1.880" is 1880, not
/// 1.88) and counted back up in the same grouped, ≤ 2-decimal form.
enum CountUpFormat {
    static func parse(_ string: String, locale: Locale = .current) -> (value: Double, format: (Double) -> String)? {
        let parts = string.split(separator: ":")
        if parts.count >= 2, parts.allSatisfy({ Int($0) != nil }) {
            let seconds = parts.reduce(0) { $0 * 60 + Int($1)! }
            return (Double(seconds), { LookFormat.elapsed(Int($0.rounded())) })
        }
        let reader = NumberFormatter()
        reader.locale = locale
        reader.numberStyle = .decimal
        if let number = reader.number(from: string)?.doubleValue {
            // A whole figure counts in whole steps; a fractional one keeps its decimals.
            let whole = number == number.rounded()
            return (number, { whole ? LookFormat.grouped($0) : LookFormat.groupedDecimal($0) })
        }
        return nil
    }
}

// MARK: - Paired stat tiles

/// The finish tiles in the user's order, paired: Workout time | Total volume,
/// Active | Total calories, Avg. | Max heart rate. A missing fact leaves its half out.
struct StatPairGrid: View {
    var tiles: [FinishTile]
    var countsUp = true
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private var rows: [[FinishTile]] {
        let groups = Dictionary(grouping: tiles) { Self.pairIndex($0.kind) }
        return groups.keys.sorted().map { groups[$0]! }
    }

    static func pairIndex(_ kind: FinishTileKind) -> Int {
        switch kind {
        case .workoutTime, .totalVolume: 0
        case .activeCalories, .totalCalories: 1
        case .averageHeartRate, .maxHeartRate: 2
        }
    }

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        switch look.id {
        case .floodlight:
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { LookDivider() }
                    pairRow(row, stacked: stacked, divider: true)
                }
            }
            .lookSurface(.stat)
        case .paper, .carbon:
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    pairRow(row, stacked: stacked, divider: true)
                        .lookSurface(.stat)
                }
            }
        }
    }

    @ViewBuilder
    private func pairRow(_ row: [FinishTile], stacked: Bool, divider: Bool) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ForEach(Array(row.enumerated()), id: \.element.id) { index, tile in
                if index > 0 && divider { LookDivider(vertical: !stacked) }
                cell(tile).frame(maxWidth: .infinity, alignment: .leading)
            }
            if row.count == 1 && !stacked {
                LookDivider(vertical: true)
                Color.clear.frame(maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cell(_ tile: FinishTile) -> some View {
        let isHeart = tile.kind == .averageHeartRate || tile.kind == .maxHeartRate
        let valueTint: Color? = isHeart && !look.id.isPaperClub ? look.heartRate : nil
        let symbolTint: Color? = isHeart ? look.heartRate : (look.id.isPaperClub ? look.textPrimary : nil)
        return StatFigure(value: tile.value, unit: tile.unit.isEmpty ? nil : tile.unit, label: tile.label,
                          symbol: tile.kind.symbol, tint: valueTint, symbolTint: symbolTint, countsUp: countsUp)
            .padding(.horizontal, 16)
            .padding(.top, look.id == .floodlight ? 16 : 13)
            .padding(.bottom, look.id == .floodlight ? 16 : 12)
    }
}
