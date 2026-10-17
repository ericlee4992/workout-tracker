import Charts
import SwiftUI

// Public beta ticket 16 — DESIGN PROTOTYPE of the Progress tab, on hard-coded sample data. Three layouts to choose
// from (UI-first: the user picks before anything reads the store or saves a pin). `PROTO_PROGRESS_LAYOUT`
// (featured | cards | grid | empty) picks the opening layout; the Layout menu switches it on screen.
// Replaced by the real tab once the user has chosen; nothing here is persisted.

struct ProgressTabPrototype: View {
    enum Layout: String, CaseIterable, Identifiable {
        case featured, cards, grid, empty
        var id: String { rawValue }
        var title: String {
            switch self {
            case .featured: "A · Featured + list"
            case .cards: "B · Chart cards"
            case .grid: "C · Grid"
            case .empty: "Empty"
            }
        }
    }

    @State private var layout: Layout = Layout(rawValue: ProcessInfo.processInfo.environment["PROTO_PROGRESS_LAYOUT"] ?? "") ?? .featured
    @State private var featuredID = ProtoPin.samples[0].id
    @State private var adding = false
    @State private var titleInBar = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Progress")
                    switch layout {
                    case .featured: featured
                    case .cards: cards
                    case .grid: grid
                    case .empty:
                        EmptyStateView(symbol: "chart.xyaxis.line", title: "No charts yet",
                                       message: "Pin an exercise or a cardio activity to follow it here.",
                                       actionTitle: "Add Chart") { adding = true }
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 2)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .lookScreenBackground()
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 70 : 46)
            } action: { _, past in
                withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(look.ground, for: .navigationBar)
            .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Progress").font(look.font.navTitle).foregroundStyle(look.textPrimary)
                        .opacity(titleInBar ? 1 : 0).accessibilityHidden(!titleInBar)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Layout", selection: $layout) {
                            ForEach(Layout.allCases) { Text($0.title).tag($0) }
                        }
                    } label: {
                        Label("Layout", systemImage: "square.grid.2x2")
                    }
                    .tint(look.textPrimary)
                    .accessibilityIdentifier("protoLayout")
                }
                if layout != .empty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add Chart", systemImage: "plus") { adding = true }
                            .tint(look.textPrimary)
                            .accessibilityIdentifier("progressAddChart")
                    }
                }
            }
            .sheet(isPresented: $adding) { AddChartPrototype() }
        }
    }

    // MARK: A — one featured chart, the rest as a list

    private var featured: some View {
        let pin = ProtoPin.samples.first { $0.id == featuredID } ?? ProtoPin.samples[0]
        return VStack(alignment: .leading, spacing: look.space.section) {
            VStack(alignment: .leading, spacing: 14) {
                PinHeading(pin: pin, titleFont: look.font.title2)
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                layout {
                    PinValue(pin: pin, numberFont: look.font.heroNumber)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
                    if let change = pin.change {
                        ProgressChangeBadge(fraction: change, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
                    }
                }
                PinChart(pin: pin, height: 150, axes: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.panel)
            .id(pin.id)
            .transition(.opacity)

            LookList(header: "Pinned") {
                ForEach(ProtoPin.samples) { other in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { featuredID = other.id }
                    } label: {
                        PinRow(pin: other, isSelected: other.id == pin.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: B — a chart card per pin

    private var cards: some View {
        VStack(spacing: look.space.group) {
            ForEach(ProtoPin.samples) { pin in
                VStack(alignment: .leading, spacing: 12) {
                    PinHeading(pin: pin, titleFont: look.font.cardTitle)
                    HStack(alignment: .firstTextBaseline) {
                        PinValue(pin: pin, numberFont: look.font.statNumber)
                        Spacer(minLength: 4)
                        if let change = pin.change { ChangeText(fraction: change) }
                    }
                    PinChart(pin: pin, height: 84, axes: false)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lookSurface(.panel)
            }
        }
    }

    // MARK: C — a two-column grid of tiles

    private var grid: some View {
        let columns = typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: look.space.grid), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: look.space.grid) {
            ForEach(ProtoPin.samples) { pin in
                VStack(alignment: .leading, spacing: 8) {
                    Text(pin.title)
                        .font(look.font.headline)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(2, reservesSpace: !typeSize.isAccessibilitySize)
                    Text(pin.variation)
                        .font(look.font.caption)
                        .foregroundStyle(look.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    Spacer(minLength: 0)
                    PinValue(pin: pin, numberFont: look.font.statNumber, compact: true)
                    PinChart(pin: pin, height: 44, axes: false)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? nil : 190, alignment: .topLeading)
                .lookSurface(.tile)
            }
        }
    }
}

// MARK: - Pieces

private struct PinHeading: View {
    let pin: ProtoPin
    let titleFont: Font
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pin.title).font(titleFont).foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                LookIcon(pin.glyph, style: .footnote)
                Text("\(pin.variation) · \(pin.metric)")
                    .font(look.font.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(look.textSecondary)
        }
    }
}

private struct PinValue: View {
    let pin: ProtoPin
    let numberFont: Font
    var compact = false
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(pin.value).font(numberFont).foregroundStyle(look.textPrimary)
                Text(pin.unit).font(look.font.headline).foregroundStyle(look.textSecondary)
            }
            if !compact {
                Text(pin.dateCaption).font(look.font.caption).foregroundStyle(look.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ChangeText: View {
    let fraction: Double
    @Environment(\.look) private var look

    var body: some View {
        let up = fraction >= 0
        HStack(spacing: 3) {
            Image(systemName: up ? "arrow.up" : "arrow.down").font(.system(.caption, weight: .heavy))
            Text("\(Int((abs(fraction) * 100).rounded()))%").font(look.font.headline.monospacedDigit())
        }
        .foregroundStyle(up ? look.done : look.textSecondary)
    }
}

private struct PinRow: View {
    let pin: ProtoPin
    let isSelected: Bool
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var spark: CGFloat = 64

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            HStack(spacing: 12) {
                LookIcon(pin.glyph, style: .body)
                    .foregroundStyle(isSelected ? look.action : look.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.title).font(look.font.body.weight(.semibold)).foregroundStyle(look.textPrimary)
                    Text(pin.variation).font(look.font.footnote).foregroundStyle(look.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 12) {
                PinChart(pin: pin, height: 28, axes: false).frame(width: spark)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(pin.value).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                    Text(pin.unit).font(look.font.caption2).foregroundStyle(look.textSecondary)
                }
                .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isSelected ? look.surfaceRaised : .clear)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PinChart: View {
    let pin: ProtoPin
    let height: CGFloat
    let axes: Bool
    @Environment(\.look) private var look

    var body: some View {
        let points = pin.points
        let values = points.map(\.value)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.18, max(0.5, hi * 0.03))
        Chart(points) { p in
            LineMark(x: .value("Date", p.date), y: .value(pin.unit, p.value))
                .foregroundStyle(look.done)
                .lineStyle(StrokeStyle(lineWidth: axes ? 2 : 1.75, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            if axes || p.date == points.last?.date {
                PointMark(x: .value("Date", p.date), y: .value(pin.unit, p.value))
                    .symbolSize(axes ? 28 : 18)
                    .foregroundStyle(look.done)
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis {
            if axes {
                AxisMarks(values: [points.first!.date, points.last!.date]) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(look.textTertiary)
                }
            }
        }
        .chartYAxis {
            if axes {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(horizontalSpacing: 10).foregroundStyle(look.textTertiary)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(!axes)
    }
}

// MARK: - Add Chart (prototype)

private struct AddChartPrototype: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var kind = 0
    @State private var search = ""

    private let lifts: [(String, String, String)] = [
        ("Bench Press", "Barbell · 2 machines", "dumbbell.fill"),
        ("Chest Press", "3 machines", LookIcon.machine),
        ("Lat Pulldown", "2 machines", LookIcon.machine),
        ("Leg Press", "1 machine", LookIcon.machine),
        ("Romanian Deadlift", "Barbell", "dumbbell.fill"),
        ("Shoulder Press", "Dumbbell · 1 machine", "dumbbell.fill"),
    ]
    private let cardio: [(String, String, String)] = [
        ("Outdoor Run", "12 sessions", "figure.run"),
        ("Indoor Run", "4 sessions", "figure.run.treadmill"),
        ("Rowing", "6 sessions", "figure.rower"),
        ("Indoor Cycle", "3 sessions", "figure.indoor.cycle"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    SegmentedPills(["Lifting", "Cardio"], selection: $kind)
                    LookList(header: kind == 0 ? "Exercises you've logged" : "Activities you've recorded") {
                        ForEach(kind == 0 ? lifts : cardio, id: \.0) { item in
                            NavigationLink {
                                ChooseVariationPrototype(title: item.0, isCardio: kind == 1, close: { dismiss() })
                            } label: {
                                LookRow(item.0, subtitle: item.1, symbol: item.2) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 12)
            }
            .searchable(text: $search, prompt: kind == 0 ? "Exercises" : "Activities")
            .lookSheetGround()
            .navigationTitle("Add Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct ChooseVariationPrototype: View {
    let title: String
    let isCardio: Bool
    let close: () -> Void
    @Environment(\.look) private var look
    @State private var variation = 0
    @State private var metric = 0

    private let variations: [(String, String, String)] = [
        ("Most used", "Now Hammer Strength · Iron Temple", "sparkles"),
        ("Hammer Strength", "Iron Temple · 14 days", LookIcon.machine),
        ("Life Fitness", "Iron Temple · 6 days", LookIcon.machine),
        ("Technogym", "Hotel gym · 2 days", LookIcon.machine),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                Text(title).font(look.font.title).foregroundStyle(look.textPrimary)
                if !isCardio {
                    LookList(header: "Machine") {
                        ForEach(Array(variations.enumerated()), id: \.offset) { index, item in
                            LookRow(item.0, subtitle: item.1, symbol: item.2, showsChevron: false,
                                    action: { variation = index }) {
                                if variation == index {
                                    Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(look.action)
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Show").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                        .padding(.leading, 4)
                    SegmentedPills(isCardio ? ["Distance", "Pace", "Time", "Heart"] : ["Best set", "Volume", "1RM"],
                                   selection: $metric)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 12)
        }
        .lookSheetGround()
        .navigationTitle("Add Chart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Add", action: close).fontWeight(.semibold) }
        }
    }
}

// MARK: - Sample data

struct ProtoPin: Identifiable {
    struct Point: Identifiable { var id: Date { date }; let date: Date; let value: Double }
    let id = UUID()
    let title: String
    let variation: String
    let glyph: String
    let metric: String
    let value: String
    let unit: String
    let dateCaption: String
    let change: Double?
    let points: [Point]

    private static func series(_ values: [Double], every days: Int) -> [Point] {
        let end = Calendar.current.startOfDay(for: .now)
        return values.enumerated().map { index, value in
            Point(date: Calendar.current.date(byAdding: .day, value: -(values.count - 1 - index) * days, to: end)!, value: value)
        }
    }

    static let samples: [ProtoPin] = [
        ProtoPin(title: "Bench Press", variation: "Barbell", glyph: "dumbbell.fill", metric: "Best set",
                 value: "185", unit: "lb × 5", dateCaption: "Oct 14 · New best", change: 0.16,
                 points: series([160, 160, 165, 165, 170, 170, 175, 180, 180, 185], every: 5)),
        ProtoPin(title: "Chest Press", variation: "Most used · Hammer Strength", glyph: LookIcon.machine, metric: "Best set",
                 value: "140", unit: "lb × 8", dateCaption: "Oct 12", change: 0.17,
                 points: series([120, 120, 125, 130, 130, 135, 135, 140], every: 6)),
        ProtoPin(title: "Leg Press", variation: "Life Fitness · Iron Temple", glyph: LookIcon.machine, metric: "Best set",
                 value: "360", unit: "lb × 10", dateCaption: "Oct 14", change: 0.20,
                 points: series([300, 310, 320, 320, 340, 340, 350, 360], every: 6)),
        ProtoPin(title: "Outdoor Run", variation: "GPS", glyph: "figure.run", metric: "Distance",
                 value: "5.2", unit: "km", dateCaption: "Oct 15", change: 0.30,
                 points: series([4.0, 4.2, 3.8, 4.5, 4.8, 4.6, 5.0, 5.2], every: 4)),
        ProtoPin(title: "Rowing", variation: "Estimated distance", glyph: "figure.rower", metric: "Distance",
                 value: "≈ 2.4", unit: "km", dateCaption: "Oct 11", change: 0.09,
                 points: series([2.2, 2.0, 2.3, 2.2, 2.4], every: 7)),
    ]
}
