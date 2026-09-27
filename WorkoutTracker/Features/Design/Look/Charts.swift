import SwiftUI
import Charts

// Charts in the Apple Fitness spirit: thin floating range bars, four labels, no gridlines.
// Zones: A and C sit the time-in-zones bar + legend directly under the graph;
// B lists each zone as a row with its own bar. C's graph lives on the ink slab.

// MARK: - Heart-rate plate

/// The container for the heart-rate graph and zones. A: panel; B: card; C: the ink slab
/// (an instrument), with its title inside.
struct HeartRatePlate<Content: View>: View {
    var title: String? = "Heart rate"
    @ViewBuilder var content: Content
    @Environment(\.look) private var look

    var body: some View {
        switch look.id {
        case .floodlight:
            VStack(alignment: .leading, spacing: look.space.header) {
                if let title { SectionHeader(title) }
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lookSurface(.panel)
            }
        case .paper, .carbon:
            VStack(alignment: .leading, spacing: 14) {
                if let title {
                    Text(title).font(look.font.title3).foregroundStyle(look.onSlab)
                }
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(look.slab, in: RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
                    .strokeBorder(look.slabEdge, lineWidth: 1.5)
            }
            .environment(\.lookOnSlab, true)
        }
    }
}

// MARK: - HR range chart

/// Thin floating range bars (low…high per slot), each split where it crosses a zone
/// boundary and coloured by that zone. Labels: max / min at trailing, start / end below.
struct HeartRateRangeChart: View {
    var slots: [HRSlot]
    /// Lower bound in bpm of each zone, index 0 (Warm-up = 0) … 5.
    var zoneBounds: [Int]
    var startLabel: String
    var endLabel: String
    var height: CGFloat = 150

    @State private var reveal: Double = 0
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption2) private var labelColumn: CGFloat = 30

    init(slots: [HRSlot], zoneBounds: [Int], startLabel: String, endLabel: String, height: CGFloat = 150) {
        self.slots = slots
        self.zoneBounds = zoneBounds
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.height = height
    }

    /// Convenience: bounds from a max heart rate (55/65/75/85/95 %).
    init(slots: [HRSlot], maxHeartRate: Int, startLabel: String, endLabel: String, height: CGFloat = 150) {
        self.init(slots: slots, zoneBounds: HeartRateZone.allCases.map { Int((Double(maxHeartRate) * $0.lowerFraction).rounded()) },
                  startLabel: startLabel, endLabel: endLabel, height: height)
    }

    private var range: ClosedRange<Int>? {
        guard let lo = slots.map(\.low).min(), let hi = slots.map(\.high).max() else { return nil }
        return lo...max(hi, lo + 1)
    }

    var body: some View {
        let labelColor = onSlab ? look.onSlabSecondary : look.textTertiary
        let labelFont = Font.system(.caption2, weight: .semibold).monospacedDigit()
        // AX sizes: the plot grows 1.25× and B keeps only the first time label (B SPEC §8).
        let plotHeight = typeSize.isAccessibilitySize ? height * 1.25 : height
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                bars
                    .frame(height: plotHeight)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * (look.id.isPaperClub ? reveal : 1))
                        }
                    }
                VStack(alignment: .trailing) {
                    Text(range.map { "\($0.upperBound)" } ?? "").fixedSize()
                    Spacer(minLength: 0)
                    Text(range.map { "\($0.lowerBound)" } ?? "").fixedSize()
                }
                .font(labelFont)
                .foregroundStyle(labelColor)
                .frame(minWidth: labelColumn, alignment: .trailing)
                .frame(height: plotHeight)
            }
            HStack {
                Text(startLabel)
                Spacer()
                Text(endLabel)
            }
            .font(labelFont)
            .foregroundStyle(labelColor)
            .lineLimit(1)
            .padding(.trailing, labelColumn + 8)
        }
        .onAppear {
            guard reveal == 0 else { return }
            if reduceMotion || !look.id.isPaperClub { reveal = 1; return }
            withAnimation(.easeInOut(duration: 1).delay(0.3)) { reveal = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate from \(range?.lowerBound ?? 0) to \(range?.upperBound ?? 0) beats per minute")
    }

    private var barWidth: CGFloat {
        switch look.id {
        case .floodlight: 2.4
        case .paper, .carbon: 3
        }
    }

    private var bars: some View {
        Canvas { context, size in
            guard let range, !slots.isEmpty else { return }
            let lo = Double(range.lowerBound) - 2, hi = Double(range.upperBound) + 2
            let span = max(1, hi - lo)
            let count = (slots.map(\.index).max() ?? 0) + 1
            let step = size.width / CGFloat(count)
            let width = min(barWidth, step * 0.7)
            func y(_ bpm: Double) -> CGFloat { size.height * CGFloat(1 - (bpm - lo) / span) }
            for slot in slots {
                let x = (CGFloat(slot.index) + 0.5) * step - width / 2
                let top = y(Double(slot.high)), bottom = y(Double(slot.low))
                let barRect = CGRect(x: x, y: top, width: width, height: max(width, bottom - top))
                let capsule = Path(roundedRect: barRect, cornerRadius: width / 2)
                context.drawLayer { layer in
                    layer.clip(to: capsule)
                    for zone in HeartRateZone.allCases {
                        let lower = Double(zone.rawValue < zoneBounds.count ? zoneBounds[zone.rawValue] : 0)
                        let upper = zone.rawValue + 1 < zoneBounds.count ? Double(zoneBounds[zone.rawValue + 1]) : 1000
                        let segTop = max(barRect.minY, y(upper)), segBottom = min(barRect.maxY, y(lower))
                        guard segBottom > segTop else { continue }
                        layer.fill(Path(CGRect(x: x, y: segTop, width: width, height: segBottom - segTop)),
                                   with: .color(look.zone(zone)))
                    }
                }
            }
        }
    }
}

// MARK: - Zones

private func zoneTime(_ seconds: Int) -> String { LookFormat.duration(seconds) }

/// One stacked bar: each zone's share of the time, in the zone ramp.
struct ZoneBar: View {
    var seconds: [Int]
    var height: CGFloat = 10
    @Environment(\.look) private var look

    var body: some View {
        let entries = HeartRateZone.allCases.compactMap { zone -> (HeartRateZone, Int)? in
            let s = zone.rawValue < seconds.count ? seconds[zone.rawValue] : 0
            return s > 0 ? (zone, s) : nil
        }
        let total = max(1, entries.reduce(0) { $0 + $1.1 })
        GeometryReader { geo in
            let gaps = CGFloat(max(0, entries.count - 1)) * 2
            HStack(spacing: 2) {
                ForEach(entries, id: \.0) { zone, s in
                    RoundedRectangle(cornerRadius: look.id.isPaperClub ? 2 : 3, style: .continuous)
                        .fill(look.zone(zone))
                        .frame(width: max(2, (geo.size.width - gaps) * CGFloat(s) / CGFloat(total)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The zone legend, laid out per look (A: a row of columns; B: rows with bars; C: a 2-column grid).
struct ZoneLegend: View {
    var seconds: [Int]
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.dynamicTypeSize) private var typeSize

    private var entries: [(zone: HeartRateZone, seconds: Int)] {
        HeartRateZone.allCases.compactMap { zone in
            let s = zone.rawValue < seconds.count ? seconds[zone.rawValue] : 0
            return s > 0 ? (zone, s) : nil
        }
    }

    var body: some View {
        switch look.id {
        case .floodlight: columns
        case .paper, .carbon: grid
        }
    }

    private var primary: Color { onSlab ? look.onSlab : look.textPrimary }
    private var secondary: Color { onSlab ? look.onSlabSecondary : look.textSecondary }

    @ViewBuilder private var columns: some View {
        let items = entries
        if typeSize.isAccessibilitySize {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { i in
                    GridRow {
                        column(items[i])
                        if i + 1 < items.count { column(items[i + 1]) }
                    }
                }
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                ForEach(items, id: \.zone) { item in column(item).frame(maxWidth: .infinity, alignment: .leading) }
            }
        }
    }

    private func column(_ item: (zone: HeartRateZone, seconds: Int)) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5).fill(look.zone(item.zone)).frame(width: 7, height: 7)
                Text(item.zone.label).font(.system(.caption2, weight: .medium)).foregroundStyle(secondary).lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(zoneTime(item.seconds))
                .font(Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit())
                .foregroundStyle(primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var grid: some View {
        let items = entries
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        return Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { i in
                GridRow {
                    ForEach(i..<min(i + columns, items.count), id: \.self) { j in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2).fill(look.zone(items[j].zone)).frame(width: 9, height: 9)
                            Text(items[j].zone.label).font(.system(.footnote, weight: .semibold)).foregroundStyle(primary)
                            Spacer(minLength: 6)
                            Text(zoneTime(items[j].seconds))
                                .font(.system(.footnote, weight: .bold).monospacedDigit())
                                .foregroundStyle(primary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

/// "Time in zones" directly under the graph, with no tap.
struct ZoneBreakdown: View {
    var seconds: [Int]
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LookDivider().padding(.bottom, 4)
            Text("Time in zones")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(onSlab ? look.onSlab : look.textPrimary)
            ZoneBar(seconds: seconds, height: look.id.isPaperClub ? 12 : 10)
            ZoneLegend(seconds: seconds)
        }
    }
}

// MARK: - Comparison

/// Last time vs today, as two zero-based bars and the change.
struct ComparisonBars: View {
    var title: String = "Total volume"
    /// B: "vs Push Day, Sep 17"; C: "Push Day" (shown as "Total volume · Push Day").
    var context: String?
    var lastLabel: String
    var last: Double
    var todayLabel: String = "Today"
    var today: Double
    var unit: String
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 46

    init(title: String = "Total volume", context: String? = nil, lastLabel: String, last: Double,
         todayLabel: String = "Today", today: Double, unit: String) {
        self.title = title
        self.context = context
        self.lastLabel = lastLabel
        self.last = last
        self.todayLabel = todayLabel
        self.today = today
        self.unit = unit
    }

    private var change: Double? { last > 0 ? (today - last) / last * 100 : nil }
    private var arrow: String { (change ?? 0) >= 0 ? "arrow.up" : "arrow.down" }
    private var percent: String { "\(Int(abs(change ?? 0).rounded()))%" }

    var body: some View {
        Group {
            switch look.id {
            case .floodlight: floodlight
            case .paper, .carbon: paperClub
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(todayLabel) \(LookFormat.grouped(today)) \(unit), \(lastLabel) \(LookFormat.grouped(last)) \(unit), \((change ?? 0) >= 0 ? "up" : "down") \(percent)")
    }

    private var floodlight: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(look.font.footnote).foregroundStyle(look.textSecondary)
                Spacer()
                if change != nil {
                    HStack(spacing: 3) {
                        Image(systemName: arrow).font(.system(.caption2, weight: .heavy))
                        Text(percent).font(.system(.caption, weight: .bold).monospacedDigit())
                    }
                    .foregroundStyle(look.onDone)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(look.done, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            barRow(label: lastLabel, value: last, color: look.comparisonLast, emphasized: false, thickness: 8)
            barRow(label: todayLabel, value: today, color: look.done, emphasized: true, thickness: 8)
        }
        .padding(16)
        .lookSurface(.panel)
    }

    private var paperClub: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.map { "\(title) · \($0)" } ?? title)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                Spacer()
                if let change {
                    Text(LookFormat.percent(change)).font(look.font.smallNumber).foregroundStyle(look.textPrimary)
                }
            }
            barRow(label: lastLabel, value: last, color: look.comparisonLast, emphasized: false, thickness: 18)
            barRow(label: todayLabel, value: today, color: look.textPrimary, emphasized: true, thickness: 18)
        }
        .padding(16)
        .lookSurface(.panel)
    }

    /// Label · bar · value on one line; at AX sizes the label and value sit above a
    /// full-width bar (every SPEC's AX rule), so "Today" / "Sep 17" never truncate.
    @ViewBuilder
    private func barRow(label: String, value: Double, color: Color, emphasized: Bool, thickness: CGFloat) -> some View {
        let maxValue = max(last, today, 1)
        let labelText = Text(label)
            .font(.system(.caption, weight: emphasized ? .bold : .medium))
            .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
        let bar = GeometryReader { geo in
            RoundedRectangle(cornerRadius: look.id.isPaperClub ? 4 : thickness / 2, style: .continuous)
                .fill(color)
                .frame(width: geo.size.width * CGFloat(value / maxValue), height: thickness)
                .frame(maxHeight: .infinity)
        }
        .frame(height: thickness)
        let figure = HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(LookFormat.grouped(value))
                .font(look.id == .floodlight ? Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit()
                      : .system(.subheadline, weight: .bold).monospacedDigit())
                .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
            Text(unit).font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
        }
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) { labelText; Spacer(minLength: 8); figure }
                bar
            }
        } else {
            HStack(spacing: 12) {
                labelText.lineLimit(1).frame(width: labelWidth, alignment: .leading)
                bar
                figure.frame(minWidth: 86, alignment: .trailing)
            }
        }
    }
}

// MARK: - Progress line

struct ProgressChartPoint: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var value: Double
    var isRecord: Bool
}

/// Exercise progress: points joined by a line, new-best markers, a y-axis NOT from zero.
struct ProgressLineChart: View {
    var points: [ProgressChartPoint]
    var unit: String = "lb"
    var height: CGFloat = 180
    @Environment(\.look) private var look

    private var domain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max(2, (hi - lo) * 0.15)
        return (lo - pad)...(hi + pad)
    }

    private var lineColor: Color { look.id == .floodlight ? look.done : look.textPrimary }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value(unit, point.value))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: look.id.isPaperClub ? 2.5 : 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", point.date), y: .value(unit, point.value))
                    .symbol { marker(point) }
            }
        }
        .chartYScale(domain: domain)
        .chartXScale(range: .plotDimension(startPadding: 8, endPadding: 12))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(look.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(horizontalSpacing: 10).foregroundStyle(look.textTertiary)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Progress, \(points.count) days")
    }

    @ViewBuilder private func marker(_ point: ProgressChartPoint) -> some View {
        if point.isRecord {
            switch look.id {
            case .floodlight:
                Image(systemName: "burst.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(look.positive)
                    .background(Circle().fill(look.surface).frame(width: 10, height: 10))
            case .paper, .carbon:
                Circle().fill(look.positive).frame(width: 13, height: 13)
                    .overlay { Circle().strokeBorder(look.onPositive, lineWidth: 1.5) }
            }
        } else {
            Circle().fill(look.id.isPaperClub ? look.surface : look.ground).frame(width: 8, height: 8)
                .overlay { Circle().strokeBorder(lineColor, lineWidth: 2) }
        }
    }
}
