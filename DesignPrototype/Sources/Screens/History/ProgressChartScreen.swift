import SwiftUI
import Charts

// H06 Progress: one exercise, one variation (never pooled, D36). A metric switch (Best set /
// Volume / 1RM — weighted only), the chart with new-best markers and a y-axis that does not
// start at zero, the selected day as the big number, the change since the first session for
// the metric on screen, the rep-count records, and the sessions (tap to open one).

struct ProgressChartScreen: View {
    let exerciseID: UUID
    let variationID: String?
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chosenVariation: String?
    @State private var metric: ProgressMetric = .bestSet
    @State private var selectedDate: Date?
    @State private var ticks = 0

    init(exerciseID: UUID, variationID: String?) {
        self.exerciseID = exerciseID
        self.variationID = variationID
    }

    var body: some View {
        let variations = store.progressVariations(exerciseID: exerciseID)
        let variation = variations.first { $0.id == (chosenVariation ?? variationID) } ?? variations.first
        let series = variation.map { Derived.progressSeries(exerciseID: exerciseID, variation: $0, history: store.workouts) }
        let name = store.exercise(exerciseID)?.name ?? "Progress"
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(name)
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let variation { variationPicker(variations, current: variation) }
                }
                if let series, let variation {
                    switch series.confidence {
                    case .empty:
                        EmptyStateView(symbol: "chart.xyaxis.line", title: "No sets logged yet")
                    case .single, .series:
                        if variation.loadType == .weighted && series.points.count > 1 {
                            SegmentedPills(ProgressMetric.allCases.map(\.label), selection: Binding(
                                get: { ProgressMetric.allCases.firstIndex(of: metric) ?? 0 },
                                set: { metric = ProgressMetric.allCases[$0]; ticks += 1 }))
                        }
                        chartPanel(series, variation: variation)
                        records(variation, series: series).id("records")
                        sessions(series, variation: variation).id("sessions")
                    }
                } else {
                    EmptyStateView(symbol: "chart.xyaxis.line", title: "No sets logged yet")
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 8)
            .padding(.bottom, 48)
            Color.clear.frame(height: 1).id(HistoryAnchor.bottom)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .historyInlineTitle(name, after: 60)
        .historyCaptureVariant(.h06, matches: store.screenTarget.exerciseID == exerciseID, anchor: { variant in
            variant == "p2" ? "records" : nil
        }, onVariant: { variant in
            switch variant {
            case "volume": metric = .volume
            case "1rm": metric = .oneRepMax
            // Thin data: the 2-day variation, and the 1-day one (a point, no line).
            case "thin": chosenVariation = variations.first { $0.trainingDays == 2 }?.id
            case "single": chosenVariation = variations.first { $0.trainingDays == 1 }?.id
            default: break
            }
        })
        .sensoryFeedback(.selection, trigger: ticks)
    }

    /// The chart's unit: the variation's own unit when every session was logged in it (a kg
    /// machine at Gangnam charts in kg, matching its "45 kg × 8"), else the app unit.
    private var unit: WeightUnit {
        let variations = store.progressVariations(exerciseID: exerciseID)
        guard let variation = variations.first(where: { $0.id == (chosenVariation ?? variationID) }) ?? variations.first
        else { return store.displayUnit }
        let points = Derived.progressSeries(exerciseID: exerciseID, variation: variation, history: store.workouts).points
        let units = Set(points.map(\.best.unit))
        return units.count == 1 ? units.first ?? store.displayUnit : store.displayUnit
    }

    // MARK: Variation

    @ViewBuilder
    private func variationPicker(_ variations: [ProgressVariation], current: ProgressVariation) -> some View {
        let label = HStack(spacing: 8) {
            LookIcon(current.machineID != nil ? LookIcon.machine : (current.freeWeightTag?.symbol ?? "circle.dashed"),
                     style: .footnote)
            Text("\(current.label) · \(Format.count(current.trainingDays, "day"))")
                .font(.system(.subheadline, weight: .semibold))
                .multilineTextAlignment(.leading)
            if variations.count > 1 {
                Image(systemName: "chevron.up.chevron.down").font(.system(.caption, weight: .bold))
            }
        }
        .foregroundStyle(look.textPrimary)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        if variations.count > 1 {
            Menu {
                Picker("Variation", selection: Binding(
                    get: { current.id },
                    set: { chosenVariation = $0; selectedDate = nil; metric = .bestSet; ticks += 1 })) {
                    ForEach(variations) { v in
                        Text("\(v.label) · \(Format.count(v.trainingDays, "day"))").tag(v.id)
                    }
                }
            } label: {
                label.lookSurface(.raised, radius: 22)
            }
            .accessibilityLabel("Variation, \(current.label)")
        } else {
            label.padding(.horizontal, -14)
                .foregroundStyle(look.textSecondary)
        }
    }

    // MARK: Chart

    private func points(_ series: ProgressSeries, loadType: LoadType) -> [HistoryProgressPoint] {
        let unit = self.unit
        var bestSoFar: Double?
        return series.points.compactMap { p -> HistoryProgressPoint? in
            let value: Double?
            switch metric {
            case .bestSet: value = loadType == .bodyweight ? Double(p.best.reps) : (p.bestKg.map { unit.fromKg($0) } ?? p.best.weight)
            case .volume: value = unit.fromKg(p.volumeKg)
            case .oneRepMax: value = p.oneRepMaxKg.map { unit.fromKg($0) }
            }
            guard let value else { return nil }
            let record: Bool
            if metric == .bestSet {
                record = p.isRecord
            } else {
                record = bestSoFar.map { value > $0 + 1e-6 } ?? false
                bestSoFar = max(bestSoFar ?? value, value)
            }
            return HistoryProgressPoint(date: p.date, value: value, isRecord: record, point: p)
        }
    }

    private func chartPanel(_ series: ProgressSeries, variation: ProgressVariation) -> some View {
        let items = points(series, loadType: variation.loadType)
        let selected = items.first { $0.date == selectedDate } ?? items.last
        let change = store.progressChange(series, metric: metric)
        let unit = self.unit
        return VStack(alignment: .leading, spacing: 16) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                if let selected { heroValue(selected, loadType: variation.loadType) }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
                if series.points.count > 1, let change {
                    HistoryChangeFigure(percent: change, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
                } else if series.points.count == 1 {
                    Text("One session").font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
            }
            HistoryProgressChart(points: items, selectedDate: selected?.date,
                                 unit: metric == .bestSet && variation.loadType == .bodyweight ? "reps" : unit.label) { date in
                if selectedDate != date {
                    selectedDate = date
                    ticks += 1
                }
            }
            .id(metric)
            .transition(.opacity)
        }
        .padding(16)
        .lookSurface(.panel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: metric)
    }

    private func heroValue(_ point: HistoryProgressPoint, loadType: LoadType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                switch metric {
                case .bestSet:
                    if loadType.takesWeight, let w = point.point.best.weight {
                        Text(Format.weight(w)).font(look.font.heroNumber)
                        Text(point.point.best.unit.label).font(.system(.title3, weight: .semibold)).foregroundStyle(look.textSecondary)
                        Text("× \(point.point.best.reps)").font(look.font.bigNumber)
                    } else {
                        Text("\(point.point.best.reps)").font(look.font.heroNumber)
                        Text("reps").font(.system(.title3, weight: .semibold)).foregroundStyle(look.textSecondary)
                    }
                case .volume, .oneRepMax:
                    Text(Format.grouped(point.value)).font(look.font.heroNumber)
                    Text(unit.label).font(.system(.title3, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
            }
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText())
            HStack(spacing: 8) {
                Text(metric == .oneRepMax ? "1RM · \(Format.day(point.date))" : Format.day(point.date))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                if point.isRecord && metric == .bestSet { NewBestBadge(kind: .newBest) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Records (1–12 reps)

    /// Rows always fill: up to four across in one row, otherwise a sideways row of tiles (a
    /// half-empty second row read as messy). Large text: one tile per row.
    @ViewBuilder
    private func records(_ variation: ProgressVariation, series: ProgressSeries) -> some View {
        let bests = store.historyRepBests(exerciseID: exerciseID, variation: variation)
        if !bests.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader(recordsTitle(variation.loadType))
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        ForEach(bests, id: \.reps) { recordCell($0, loadType: variation.loadType, series: series) }
                    }
                } else if bests.count <= 4 {
                    HStack(spacing: 10) {
                        ForEach(bests, id: \.reps) { recordCell($0, loadType: variation.loadType, series: series) }
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(bests, id: \.reps) {
                                recordCell($0, loadType: variation.loadType, series: series).frame(width: 92)
                            }
                        }
                        .padding(.horizontal, look.space.margin)
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, -look.space.margin)
                }
            }
        }
    }

    private func recordsTitle(_ loadType: LoadType) -> String {
        switch loadType {
        case .weighted: "Weight records"
        case .assisted: "Least-assistance records · lower is better"
        case .bodyweightPlus: "Added-weight records"
        case .bodyweight: "Bodyweight record"
        }
    }

    private func recordCell(_ best: RepBest, loadType: LoadType, series: ProgressSeries) -> some View {
        let day = Calendar.app.startOfDay(for: best.date)
        let isSelected = selectedDate == day
        return Button {
            guard series.points.contains(where: { $0.date == day }) else { return }
            metric = .bestSet
            selectedDate = day
            ticks += 1
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.reps(best.reps))
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(best.value.weight.map { Format.weight($0) } ?? "\(best.reps)")
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.textPrimary)
                    Text(best.value.unit.label).font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Text(Format.shortDate(best.date)).font(look.font.caption2).foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.tile, radius: look.radius.stat)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: look.radius.stat, style: .continuous)
                        .strokeBorder(look.id.isPaperClub ? look.actionText : look.textPrimary, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("\(Format.reps(best.reps)), \(Format.set(best.value, loadType: loadType)), \(Format.shortDate(best.date))")
    }

    // MARK: Sessions

    private func sessions(_ series: ProgressSeries, variation: ProgressVariation) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Sessions", trailing: Format.count(series.points.count, "day"))
            HistoryListPanel {
                ForEach(series.points.reversed()) { point in
                    Button { router.push(.workoutDetail(workoutID: point.workoutID)) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Format.day(point.date))
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(look.textSecondary)
                                Text(Format.set(point.best, loadType: variation.loadType))
                                    .font(look.historyRowNumber)
                                    .foregroundStyle(look.textPrimary)
                            }
                            Spacer(minLength: 8)
                            if point.isRecord { NewBestBadge(kind: .newBest) }
                            Image(systemName: "chevron.right")
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(look.textTertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .background(point.date == selectedDate ? look.pressedFill : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HistoryRowPressStyle())
                }
            }
        }
    }
}

// MARK: - Chart

struct HistoryProgressPoint: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var value: Double
    var isRecord: Bool
    var point: ProgressPoint
}

/// Points joined by a line (one point: no line), per-look new-best markers, a y-axis padded
/// around the data (never from zero), and a selection rule the thumb drags.
struct HistoryProgressChart: View {
    var points: [HistoryProgressPoint]
    var selectedDate: Date?
    var unit: String
    var onSelect: (Date) -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var reveal: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var domain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.18, max(2, hi * 0.03))
        return (lo - pad)...(hi + pad)
    }

    private var tickDates: [Date] {
        guard let first = points.first?.date, let last = points.last?.date else { return [] }
        if points.count < 2 { return [first] }
        if typeSize.isAccessibilitySize || points.count < 4 { return [first, last] }
        // The session nearest the middle of the time span, only when it sits clear of both ends
        // (dates are uneven, so the middle INDEX can crowd the last label).
        let span = last.timeIntervalSince(first)
        let middle = first.addingTimeInterval(span / 2)
        guard let mid = points.map(\.date).min(by: { abs($0.timeIntervalSince(middle)) < abs($1.timeIntervalSince(middle)) }),
              mid.timeIntervalSince(first) > span * 0.3, last.timeIntervalSince(mid) > span * 0.3 else { return [first, last] }
        return [first, mid, last]
    }

    private var lineColor: Color { look.id == .floodlight ? look.done : look.textPrimary }
    private var selectionColor: Color { look.id.isPaperClub ? look.actionText : look.textPrimary }

    var body: some View {
        Chart {
            if points.count > 1 {
                ForEach(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value(unit, p.value))
                        .foregroundStyle(lineColor)
                        .lineStyle(StrokeStyle(lineWidth: look.id.isPaperClub ? 2.5 : 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
            }
            if let selectedDate {
                RuleMark(x: .value("Date", selectedDate))
                    .foregroundStyle(selectionColor.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            ForEach(points) { p in
                PointMark(x: .value("Date", p.date), y: .value(unit, p.value))
                    .symbol { marker(p, selected: p.date == selectedDate) }
            }
        }
        .chartYScale(domain: domain)
        // The last session's marker (often a new best) clears the trailing y labels.
        .chartXScale(range: .plotDimension(startPadding: 14, endPadding: 30))
        .chartXAxis {
            // Ticks on real sessions: the first, the last (the selected default) and one between.
            AxisMarks(values: tickDates) { value in
                AxisTick(length: 4).foregroundStyle(look.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true,
                               anchor: value.index == value.count - 1 && value.count > 1 ? .topTrailing
                                   : (value.index == 0 && value.count > 1 ? .topLeading : .top))
                    .foregroundStyle(look.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(look.hairline)
                AxisValueLabel(horizontalSpacing: 8).foregroundStyle(look.textTertiary)
            }
        }
        .chartGesture { proxy in
            DragGesture(minimumDistance: 0).onChanged { value in
                guard let date: Date = proxy.value(atX: value.location.x) else { return }
                if let nearest = points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                    onSelect(nearest.date)
                }
            }
        }
        // Axis labels stay readable but capped, so dates never collide at accessibility sizes
        // (the selected value above the chart carries the number in full size).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(height: typeSize.isAccessibilitySize ? 270 : 220)
        .opacity(reveal)
        .scaleEffect(x: 1, y: reduceMotion ? 1 : 0.9 + 0.1 * reveal, anchor: .bottom)
        .onAppear {
            guard reveal == 0 else { return }
            if reduceMotion { reveal = 1 } else { withAnimation(.easeOut(duration: 0.45)) { reveal = 1 } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress, \(points.count) days")
        .accessibilityValue(points.first { $0.date == selectedDate }.map { "\(Format.shortDate($0.date)), \(Format.number(($0.value * 10).rounded() / 10)) \(unit)" } ?? "")
        .accessibilityAdjustableAction { direction in
            guard let index = points.firstIndex(where: { $0.date == selectedDate }) ?? (points.isEmpty ? nil : points.count - 1) else { return }
            switch direction {
            case .increment: if index + 1 < points.count { onSelect(points[index + 1].date) }
            case .decrement: if index > 0 { onSelect(points[index - 1].date) }
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private func marker(_ point: HistoryProgressPoint, selected: Bool) -> some View {
        let scale: CGFloat = selected ? 1.5 : 1
        if point.isRecord {
            switch look.id {
            case .floodlight:
                Image(systemName: "burst.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(look.positive)
                    .background(Circle().fill(look.surface).frame(width: 10, height: 10))
                    .scaleEffect(scale)
            case .anatomy:
                Image(systemName: "star.fill").font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(look.onDone)
                    .frame(width: 17, height: 17).background(look.done, in: Circle())
                    .scaleEffect(scale)
            case .paper, .carbon:
                Circle().fill(look.positive).frame(width: 14, height: 14)
                    .overlay { Circle().strokeBorder(look.onPositive, lineWidth: 1.5) }
                    .overlay { if selected { Circle().strokeBorder(look.actionText, lineWidth: 2).padding(-4) } }
                    .scaleEffect(selected ? 1.2 : 1)
            }
        } else if selected {
            Circle().fill(selectionColor).frame(width: 12, height: 12)
                .overlay { Circle().strokeBorder(look.surface, lineWidth: 2) }
        } else {
            Circle().fill(look.surface).frame(width: 8, height: 8)
                .overlay { Circle().strokeBorder(lineColor, lineWidth: 2) }
        }
    }
}

/// The change since the first session for the metric on screen: A a floodlight plate with an
/// arrow, B the arrow and a big number, C the signed figure.
struct HistoryChangeFigure: View {
    var percent: Double
    var alignment: HorizontalAlignment = .trailing
    @Environment(\.look) private var look

    var body: some View {
        let up = percent >= 0
        let rounded = Int(abs(percent).rounded())
        VStack(alignment: alignment, spacing: 4) {
            switch look.id {
            case .floodlight:
                HStack(spacing: 3) {
                    Image(systemName: up ? "arrow.up" : "arrow.down").font(.system(.footnote, weight: .heavy))
                    Text("\(rounded)%").font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
                }
                .foregroundStyle(up ? look.onDone : look.textPrimary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(up ? look.done : look.surfaceRaised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            case .anatomy:
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Image(systemName: up ? "arrow.up" : "arrow.down").font(.system(.title3, design: .rounded, weight: .heavy))
                    Text("\(rounded)%").font(look.font.statNumber)
                }
                .foregroundStyle(up ? look.textPrimary : look.textSecondary)
            case .paper, .carbon:
                Text(Format.percent(percent)).font(look.font.statNumber).foregroundStyle(look.textPrimary)
            }
            Text("Since first session").font(look.font.caption).foregroundStyle(look.textSecondary)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(up ? "Up" : "Down") \(rounded) percent since first session")
    }
}
