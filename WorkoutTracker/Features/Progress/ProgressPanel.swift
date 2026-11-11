import Charts
import SwiftUI

// Public beta ticket 16 (D63): one pinned chart on the Progress tab — its title, equipment or session count · metric,
// the latest value, the change since the first session and a short chart. The numbers come from the same code as the
// full charts (`ProgressSeriesMath` + `LiftProgressValues`; `CardioProgressMath`); this file only lays them out.

/// What a panel (and the cardio screen's chart panel) shows, already formatted.
struct ProgressReading {
    struct Point: Identifiable, Equatable {
        /// The point's own key when it has one (a weigh-in's entry id — two can share a time, codex-review-n10-b);
        /// otherwise its date, unique in a series of sessions, days or weeks.
        var id: String { key ?? String(date.timeIntervalSinceReferenceDate) }
        let date: Date
        let value: Double
        let isBest: Bool
        /// N10, the macros chart: protein, carbs and fat calories, stacked (they add up to `value`).
        var parts: [Double]? = nil
        var key: String? = nil
    }
    /// N10: a line (the default), daily bars, or daily bars stacked protein · carbs · fat.
    enum Style: Equatable { case line, bars, macros }
    enum Change: Equatable {
        /// Oriented so positive is better — `ProgressChangeBadge`.
        case fraction(Double)
        /// Pace: the badge says what changed ("0:40 faster"), since a faster pace is a SMALLER number.
        case words(String, better: Bool)
    }
    enum State: Equatable { case empty, single, series }

    var value: String
    var unit: String
    var caption: String
    /// The lifting chart's NEW BEST mark beside the caption (best set only).
    var newBest = false
    var change: Change?
    var points: [Point]
    /// Pace: drawn negated so faster is UP and every chart on the tab reads "up is better" (D63). Assisted lifting is
    /// NOT inverted (the exercise chart's rule: the label says it instead).
    var lowerIsBetter = false
    var axisLabel: (Double) -> String = { LookFormat.number($0) }
    /// Under a lone point on a panel: a lift's or an activity's single point IS one session. A weekly training chart
    /// sets nil — its one point is a week that may hold several workouts (codex-review-s4 #1).
    var singleNote: String? = "One session"
    var style: Style = .line
    /// N10: the dashed goal line (calories, protein).
    var goal: Double? = nil
    /// N10: the days the bars stand on, so a day without food is an empty slot, not a squeezed axis.
    var xDomain: ClosedRange<Date>? = nil

    var state: State {
        switch points.count {
        case 0: .empty
        case 1: .single
        default: .series
        }
    }
}

extension ProgressReading {
    /// A lifting variation's reading for one metric.
    static func lift(series: ProgressSeries, recordDays: Set<Date>, values: LiftProgressValues) -> ProgressReading {
        let points = series.points.compactMap { point in
            values.plotted(point).map {
                Point(date: point.date, value: $0, isBest: values.metric == .bestSet && recordDays.contains(point.date))
            }
        }
        guard let latest = series.points.last(where: { values.plotted($0) != nil }) else {
            return ProgressReading(value: "—", unit: "", caption: "", points: [])
        }
        let value: String, unit: String
        switch values.metric {
        case .bestSet:
            if values.loadType != .bodyweight, let typed = latest.bestValue, let typedUnit = latest.bestUnit {
                value = LookFormat.number(typed)
                unit = "\(typedUnit.rawValue) × \(latest.bestReps ?? 0)"
            } else {
                value = "\(latest.bestReps ?? 0)"
                unit = "reps"
            }
        case .volume, .e1rm:
            value = values.plotted(latest).map(LookFormat.groupedDecimal) ?? "—"
            unit = values.displayUnit.rawValue
        }
        let day = HistoryFormat.shortDayTitle(latest.date)
        return ProgressReading(
            value: value, unit: unit,
            caption: values.metric == .e1rm ? "1RM · \(day)" : day,
            newBest: values.metric == .bestSet && recordDays.contains(latest.date),
            change: points.count > 1 ? values.change(series).map(Change.fraction) : nil,
            points: points)
    }

    /// A cardio activity's reading for one metric (no heart-rate view, D63).
    static func cardio(_ sessions: [CardioProgressSession], metric: ProgressPinMetric, activity: CardioActivity,
                       unit: CardioDistanceUnit) -> ProgressReading {
        let series = CardioProgressMath.points(sessions, metric: metric, activity: activity, unit: unit)
        let points = series.map { Point(date: $0.date, value: $0.value, isBest: $0.isBest) }
        guard let latest = series.last else { return ProgressReading(value: "—", unit: "", caption: "", points: []) }
        let speed = metric == .pace && activity.usesSpeed
        let value: String, unitText: String
        var axis: (Double) -> String = { LookFormat.number($0) }
        switch metric {
        case .pace where speed:
            value = String(format: "%.1f", latest.value)
            unitText = CardioFormat.speedUnit(unit)
            axis = { String(format: "%.0f", $0) }
        case .pace:
            value = CardioMath.paceText(latest.value)
            unitText = CardioProgressMath.paceLabel(activity, unit: unit)
            axis = { CardioMath.paceText($0) }
        case .time:
            value = "\(Int(latest.value.rounded()))"
            unitText = "min"
        default:
            value = String(format: "%.1f", latest.value)
            unitText = unit.rawValue
            axis = { $0.formatted(.number.precision(.fractionLength(0...1))) }
        }
        let best = CardioProgressMath.latestIsBest(series, metric: metric, activity: activity)
        let bestWord = metric == .pace ? "Fastest" : "Longest"
        var change: Change?
        switch CardioProgressMath.change(series, metric: metric, activity: activity) {
        case .fraction(let f): change = .fraction(f)
        case .paceSeconds(let s): change = .words("\(CardioMath.paceText(abs(s))) \(s >= 0 ? "faster" : "slower")", better: s >= 0)
        case nil: change = nil
        }
        return ProgressReading(
            value: value, unit: unitText,
            caption: HistoryFormat.shortDayTitle(latest.date) + (best ? " · \(bestWord)" : ""),
            change: change, points: points,
            lowerIsBetter: CardioProgressMath.lowerIsBetter(metric, activity: activity),
            axisLabel: axis)
    }
}

extension ProgressReading {
    /// Soft redesign S4: a training-wide weekly reading. The figure is this week so far; the caption gives last week
    /// for comparison (no change badge: a week in progress against a full one would mislead).
    static func training(_ points: [TrainingWeekPoint], metric: TrainingMetric, weightUnit: WeightUnit,
                         distanceUnit: CardioDistanceUnit) -> ProgressReading {
        func shown(_ raw: Double) -> Double {
            switch metric {
            case .workoutsPerWeek: raw
            case .trainingVolume: WeightMath.convert(raw, from: .kg, to: weightUnit)
            case .runningDistance: raw / distanceUnit.metersPerUnit
            }
        }
        func text(_ value: Double) -> String {
            switch metric {
            case .workoutsPerWeek: "\(Int(value.rounded()))"
            case .trainingVolume: LookFormat.grouped(value)
            case .runningDistance: String(format: "%.1f", value)
            }
        }
        let unit: String = switch metric {
        case .workoutsPerWeek: ""
        case .trainingVolume: weightUnit.rawValue
        case .runningDistance: distanceUnit.rawValue
        }
        guard let latest = points.last else { return ProgressReading(value: "—", unit: "", caption: "", points: []) }
        var caption = "This week"
        if points.count > 1 {
            let last = text(shown(points[points.count - 2].value))
            caption += " · last week \(last)\(unit.isEmpty ? "" : " \(unit)")"
        }
        return ProgressReading(
            value: text(shown(latest.value)), unit: unit, caption: caption, change: nil,
            points: points.map { Point(date: $0.weekStart, value: shown($0.value), isBest: false) },
            axisLabel: { $0.formatted(.number.precision(.fractionLength(0...1))) }, singleNote: nil)
    }
}

// MARK: - The panel

struct ProgressPanel: View {
    let title: String
    let subtitle: String
    let glyph: String
    let reading: ProgressReading
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var menuSize: CGFloat = ProgressPanel.menuSide

    /// Soft redesign S4: the Progress tab lays the panel's "…" options menu over its top-right corner (the approved
    /// prototype's chart card); the panel keeps that square free. The whole card still opens the chart. Side before
    /// Dynamic Type scaling.
    static let menuSide: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        LookIcon(glyph, style: .footnote)
                        Text(subtitle).font(look.font.footnote).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 8)
                Color.clear.frame(width: menuSize, height: menuSize).accessibilityHidden(true)
            }
            switch reading.state {
            case .empty:
                // The string the exercise chart always had for a variation with nothing to draw.
                Text("Nothing to chart here").font(look.font.subhead).foregroundStyle(look.textSecondary)
            case .single:
                ProgressReadingValue(reading: reading, numberFont: look.font.bigNumber)
                if let note = reading.singleNote {
                    Text(note).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
            case .series:
                ProgressReadingHeader(reading: reading, numberFont: look.font.bigNumber)
                ProgressPanelChart(reading: reading, height: 108)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .contentShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
    }
}

/// Soft redesign S4: a panel's visible "…" — the same Move / Remove (and Show) actions as its long-press menu, laid
/// over the corner `ProgressPanel` keeps free.
struct ProgressPanelMenu<Items: View>: View {
    let title: String
    @ViewBuilder let items: () -> Items
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = ProgressPanel.menuSide

    var body: some View {
        Menu(content: items) {
            Image(systemName: "ellipsis")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .frame(width: side, height: side)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("\(title) options")
        .accessibilityIdentifier("progressPanelOptions")
        .padding(16)
    }
}

/// The value and the change badge: side by side, stacked at accessibility sizes.
struct ProgressReadingHeader: View {
    let reading: ProgressReading
    let numberFont: Font
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            ProgressReadingValue(reading: reading, numberFont: numberFont)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
            switch reading.change {
            case .fraction(let f):
                ProgressChangeBadge(fraction: f, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
            case .words(let text, let better):
                ProgressWordsBadge(text: text, better: better, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
            case nil:
                EmptyView()
            }
        }
    }
}

struct ProgressReadingValue: View {
    let reading: ProgressReading
    let numberFont: Font
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(reading.value).font(numberFont).foregroundStyle(look.textPrimary)
                Text(reading.unit).font(look.font.headline).foregroundStyle(look.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(spacing: 8) {
                Text(reading.caption).font(look.font.caption).foregroundStyle(look.textSecondary)
                if reading.newBest { NewBestBadge(kind: .newBest) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// `ProgressChangeBadge`'s look with words instead of a signed percentage (pace improves downward).
struct ProgressWordsBadge: View {
    let text: String
    let better: Bool
    var alignment: HorizontalAlignment = .trailing
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: better ? "arrow.up" : "arrow.down").font(.system(.footnote, weight: .heavy))
                Text(text).font(Font.system(.headline, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(better ? look.onDone : look.textPrimary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(better ? look.done : look.surfaceRaised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("Since first session").font(look.font.caption).foregroundStyle(look.textSecondary)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text) since first session")
    }
}

/// A short, non-interactive chart: a monotone line through the sessions, new bests marked, first and last dates, the
/// y-axis padded around the data (never from zero). The full charts behind a panel are the interactive ones.
struct ProgressPanelChart: View {
    let reading: ProgressReading
    let height: CGFloat
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder var body: some View {
        if reading.style == .line { line } else { bars }
    }

    /// N10 (the approved prototype): daily bars — the latest day in full, earlier days lighter — or stacked macros,
    /// against a dashed goal; from zero (amounts, not a trend).
    private var bars: some View {
        let top = max(reading.points.map(\.value).max() ?? 0, reading.goal ?? 0) * 1.12
        let latest = reading.points.last?.date
        return Chart {
            ForEach(reading.points) { p in
                if reading.style == .macros, let parts = p.parts {
                    ForEach(Array(zip(MacroKind.allCases, parts)), id: \.0) { kind, part in
                        BarMark(x: .value("Day", p.date, unit: .day), y: .value("Calories", part), width: .ratio(0.6))
                            .foregroundStyle(kind.color)
                    }
                } else {
                    BarMark(x: .value("Day", p.date, unit: .day), y: .value("Value", p.value), width: .ratio(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(p.date == latest ? look.textPrimary : look.textPrimary.opacity(0.28))
                }
            }
            if let goal = reading.goal {
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(look.textTertiary)
            }
        }
        .chartYScale(domain: 0...max(top, 1))
        .modifier(BarDomain(domain: reading.xDomain))
        .chartXAxis {
            if let first = reading.xDomain?.lowerBound ?? reading.points.first?.date,
               let last = reading.xDomain?.upperBound ?? reading.points.last?.date {
                AxisMarks(values: [first, last]) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(),
                                   anchor: value.index == 0 ? .topLeading : .topTrailing)
                        .foregroundStyle(look.textTertiary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: typeSize.isAccessibilitySize ? 2 : 3)) { value in
                AxisValueLabel(horizontalSpacing: 10) {
                    if let v = value.as(Double.self) { Text(reading.axisLabel(v)) }
                }
                .foregroundStyle(look.textTertiary)
            }
        }
        .frame(height: typeSize.isAccessibilitySize ? height * 1.25 : height)
        .accessibilityHidden(true)
    }

    private var line: some View {
        let sign: Double = reading.lowerIsBetter ? -1 : 1
        let points = reading.points.map {
            ProgressReading.Point(date: $0.date, value: $0.value * sign, isBest: $0.isBest, key: $0.key)
        }
        let values = points.map(\.value)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.18, max(0.5, abs(hi) * 0.03))
        return Chart(points) { p in
            LineMark(x: .value("Date", p.date), y: .value("Value", p.value))
                .foregroundStyle(look.done)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                .symbolSize(p.date == points.last?.date ? 60 : 26)
                .foregroundStyle(look.done)
            if p.isBest {
                PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                    .symbol {
                        Image(systemName: "burst.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(look.positive)
                            .background(Circle().fill(look.surface).frame(width: 8, height: 8))
                    }
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXScale(range: .plotDimension(startPadding: 6, endPadding: 10))
        .chartXAxis {
            if let first = points.first?.date, let last = points.last?.date {
                AxisMarks(values: [first, last]) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(),
                                   anchor: value.index == 0 ? .topLeading : .topTrailing)
                        .foregroundStyle(look.textTertiary)
                }
            }
        }
        .chartYAxis {
            // AX sizes: two labels, or the scaled numbers touch (and the plot grows 1.25×, as HeartRateRangeChart).
            AxisMarks(position: .trailing, values: .automatic(desiredCount: typeSize.isAccessibilitySize ? 2 : 3)) { value in
                AxisValueLabel(horizontalSpacing: 10) {
                    if let v = value.as(Double.self) { Text(reading.axisLabel(v * sign)) }
                }
                .foregroundStyle(look.textTertiary)
            }
        }
        .frame(height: typeSize.isAccessibilitySize ? height * 1.25 : height)
        .accessibilityHidden(true)
    }
}

/// The bars' days: the whole span when the reading names one (a day without food stays an empty slot).
private struct BarDomain: ViewModifier {
    let domain: ClosedRange<Date>?
    @ViewBuilder func body(content: Content) -> some View {
        if let domain {
            // The last day's bar stands on its start: the domain runs to the end of that day (a calendar day, so a
            // daylight-saving change does not clip it).
            let end = Calendar.current.date(byAdding: .day, value: 1, to: domain.upperBound) ?? domain.upperBound
            content.chartXScale(domain: domain.lowerBound...end)
        } else {
            content
        }
    }
}
