import Charts
import SwiftData
import SwiftUI

// Public beta ticket 16 — DESIGN PROTOTYPE of the Progress tab, on hard-coded sample data (UI-first: nothing here reads
// history or saves a pin). Round 2, the user's direction: A's chart panel for EVERY pin, one under another, lifting and
// cardio mixed, and keep adding. Long-press a panel to change what it shows, move it or remove it; + or "Add Chart"
// appends one. A lifting panel opens the existing exercise chart (on the design sample's exercise when one has that
// name); a cardio panel opens the cardio progress screen designed here. `PROTO_PROGRESS_LAYOUT=empty` starts empty.

struct ProgressTabPrototype: View {
    @State private var pins: [ProtoPin] = ProcessInfo.processInfo.environment["PROTO_PROGRESS_LAYOUT"] == "empty"
        ? [] : ProtoPin.initial
    @State private var adding = false
    @State private var titleInBar = false
    /// Captures only: `PROTO_PROGRESS_OPEN=<pin title>[:<metric>]` opens that pin; `PROTO_PROGRESS_SCROLL=bottom`.
    @State private var path: [UUID] = []
    @Query private var exercises: [Exercise]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.group) {
                    LookNavTitle("Progress")
                        .padding(.bottom, look.space.section - look.space.group)
                    if pins.isEmpty {
                        EmptyStateView(symbol: "chart.xyaxis.line", title: "No charts yet",
                                       message: "Pin an exercise or a cardio activity to follow it here.",
                                       actionTitle: "Add Chart") { adding = true }
                            .padding(.top, 40)
                    } else {
                        ForEach($pins) { $pin in
                            NavigationLink(value: pin.id) {
                                PinPanel(pin: pin)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { menu(for: $pin) }
                            .accessibilityIdentifier("progressPanel")
                        }
                        Button("Add Chart", systemImage: "plus") { adding = true }
                            .buttonStyle(.lookSecondary)
                            .padding(.top, 8)
                            .accessibilityIdentifier("progressAddChartBottom")
                            .id("bottom")
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 2)
                .padding(.bottom, 48)
                .animation(.snappy(duration: 0.3), value: pins.map(\.id))
            }
            .onAppear {
                let env = ProcessInfo.processInfo.environment
                if env["PROTO_PROGRESS_SCROLL"] == "bottom" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                if let open = env["PROTO_PROGRESS_OPEN"] {
                    let parts = open.split(separator: ":").map(String.init)
                    if let index = pins.firstIndex(where: { $0.title == parts[0] }) {
                        if parts.count > 1 { pins[index].metric = parts[1] }
                        path = [pins[index].id]
                    }
                }
            }
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
                if !pins.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add Chart", systemImage: "plus") { adding = true }
                            .tint(look.textPrimary)
                            .accessibilityIdentifier("progressAddChart")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let pin = pins.first(where: { $0.id == id }) { destination(pin) }
            }
            .sheet(isPresented: $adding) {
                AddChartPrototype { title, metric in
                    pins.append(ProtoPin.make(title: title, metric: metric))
                }
            }
        }
    }

    @ViewBuilder private func destination(_ pin: ProtoPin) -> some View {
        if pin.isCardio {
            CardioProgressPrototype(pin: pin)
        } else if let exercise = exercises.first(where: { $0.name == pin.title }) {
            ExerciseProgressView(exerciseID: exercise.id, exerciseName: exercise.name)
        } else {
            EmptyStateView(symbol: "chart.xyaxis.line", title: pin.title,
                           message: "Opens this exercise's chart (the one Exercises and History open).")
                .lookSheetGround()
        }
    }

    @ViewBuilder private func menu(for pin: Binding<ProtoPin>) -> some View {
        Picker("Show", selection: pin.metric) {
            ForEach(pin.wrappedValue.metrics, id: \.self) { Text($0).tag($0) }
        }
        let index = pins.firstIndex { $0.id == pin.wrappedValue.id } ?? 0
        if index > 0 {
            Button("Move Up", systemImage: "arrow.up") { pins.swapAt(index, index - 1) }
        }
        if index < pins.count - 1 {
            Button("Move Down", systemImage: "arrow.down") { pins.swapAt(index, index + 1) }
        }
        Button("Remove from Progress", systemImage: "pin.slash", role: .destructive) {
            pins.removeAll { $0.id == pin.wrappedValue.id }
        }
    }
}

// MARK: - The panel (A's design, one per pin)

private struct PinPanel: View {
    let pin: ProtoPin
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let reading = pin.reading
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pin.title).font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        LookIcon(pin.glyph, style: .footnote)
                        Text("\(pin.variation) · \(pin.metric)")
                            .font(look.font.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.textTertiary)
                    .padding(.top, 6)
            }
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                ReadingValue(reading: reading, numberFont: look.font.bigNumber)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
                if let change = reading.change {
                    ChangeBadge(change: change, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
                }
            }
            ReadingChart(reading: reading, height: 108, axes: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .contentShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
    }
}

private struct ReadingValue: View {
    let reading: ProtoReading
    let numberFont: Font
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(reading.value).font(numberFont).foregroundStyle(look.textPrimary)
                Text(reading.unit).font(look.font.headline).foregroundStyle(look.textSecondary)
            }
            Text(reading.caption).font(look.font.caption).foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// ProgressChangeBadge's look with the text given: pace improves DOWNWARD and heart rate has no better direction, so
/// the badge says what changed ("0:21 faster") instead of signing a percentage.
private struct ChangeBadge: View {
    let change: ProtoReading.Change
    var alignment: HorizontalAlignment = .trailing
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: change.better ? "arrow.up" : "arrow.down").font(.system(.footnote, weight: .heavy))
                Text(change.text).font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
            }
            .foregroundStyle(change.better ? look.onDone : look.textPrimary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(change.better ? look.done : look.surfaceRaised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("Since first session").font(look.font.caption).foregroundStyle(look.textSecondary)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

private struct ReadingChart: View {
    let reading: ProtoReading
    let height: CGFloat
    let axes: Bool
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Pace: faster is lower, plotted negated so every chart on the tab reads "up is better".
        let sign: Double = reading.lowerIsBetter ? -1 : 1
        let points = reading.points.map { ProtoReading.Point(date: $0.date, value: $0.value * sign, isBest: $0.isBest) }
        let values = points.map(\.value)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.18, max(0.5, hi * 0.03))
        let color = reading.isHeartRate ? look.heartRate : look.done
        Chart(points) { p in
            LineMark(x: .value("Date", p.date), y: .value(reading.unit, p.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", p.date), y: .value(reading.unit, p.value))
                .symbolSize(p.isBest ? 60 : 26)
                .foregroundStyle(color)
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXScale(range: .plotDimension(startPadding: 6, endPadding: 10))
        .chartXAxis {
            if axes {
                AxisMarks(values: [points.first!.date, points.last!.date]) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), anchor: value.index == 0 ? .topLeading : .topTrailing)
                        .foregroundStyle(look.textTertiary)
                }
            }
        }
        .chartYAxis {
            if axes {
                // AX sizes: two labels, or the scaled numbers touch (as HeartRateRangeChart, the plot grows 1.25×).
                AxisMarks(position: .trailing, values: .automatic(desiredCount: typeSize.isAccessibilitySize ? 2 : 3)) { value in
                    AxisValueLabel(horizontalSpacing: 10) {
                        if let v = value.as(Double.self) { Text(reading.axisLabel(v * sign)) }
                    }
                    .foregroundStyle(look.textTertiary)
                }
            }
        }
        .frame(height: typeSize.isAccessibilitySize ? height * 1.25 : height)
    }
}

// MARK: - Cardio progress (the screen a cardio panel opens)

struct CardioProgressPrototype: View {
    @State var pin: ProtoPin
    @State private var titleInBar = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let reading = pin.reading
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pin.title).font(look.font.title).foregroundStyle(look.textPrimary)
                    HStack(spacing: 8) {
                        LookIcon(pin.glyph, style: .footnote)
                        Text(pin.variation).font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(look.textSecondary)
                }
                SegmentedPills(pin.metrics, selection: Binding(
                    get: { pin.metrics.firstIndex(of: pin.metric) ?? 0 },
                    set: { pin.metric = pin.metrics[$0] }))
                VStack(alignment: .leading, spacing: 16) {
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                    layout {
                        ReadingValue(reading: reading, numberFont: look.font.heroNumber)
                        if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
                        if let change = reading.change {
                            ChangeBadge(change: change, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
                        }
                    }
                    ReadingChart(reading: reading, height: 160, axes: true)
                }
                .padding(16)
                .lookSurface(.panel)
                .id(pin.metric)
                .transition(.opacity)
                .animation(.snappy(duration: 0.3), value: pin.metric)

                LookList(header: "Bests") {
                    ForEach(pin.cardioBests, id: \.0) { best in
                        LookRow(best.0, subtitle: best.2, symbol: best.3, showsChevron: false) {
                            Text(best.1).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                        }
                    }
                }
                LookList(header: "Sessions") {
                    ForEach(pin.sessions.reversed()) { session in
                        LookRow(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                                subtitle: pin.sessionLine(session), symbol: nil) { EmptyView() }
                    }
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .lookSheetGround()
        .navigationTitle(pin.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add Chart (prototype)

private struct AddChartPrototype: View {
    let onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var kind = 0
    @State private var search = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    SegmentedPills(["Lifting", "Cardio"], selection: $kind)
                    LookList(header: kind == 0 ? "Exercises you've logged" : "Activities you've recorded") {
                        ForEach(kind == 0 ? ProtoPin.liftChoices : ProtoPin.cardioChoices, id: \.0) { item in
                            NavigationLink {
                                ChooseVariationPrototype(title: item.0, isCardio: kind == 1) { metric in
                                    onAdd(item.0, metric)
                                    dismiss()
                                }
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
    let add: (String) -> Void
    @Environment(\.look) private var look
    @State private var variation = 0
    @State private var metric = 0

    private let variations: [(String, String, String)] = [
        ("Most used", "Now Hammer Strength · Iron Temple", "sparkles"),
        ("Hammer Strength", "Iron Temple · 14 days", LookIcon.machine),
        ("Life Fitness", "Iron Temple · 6 days", LookIcon.machine),
        ("Technogym", "Hotel gym · 2 days", LookIcon.machine),
    ]

    private var metrics: [String] {
        isCardio ? ProtoPin.cardioMetrics(usesSpeed: title.contains("Cycle")) : ProtoPin.liftMetrics
    }

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
                    SegmentedPills(metrics, selection: $metric)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 12)
        }
        .lookSheetGround()
        .navigationTitle("Add Chart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { add(metrics[metric]) }.fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Sample data

struct ProtoSession: Identifiable {
    var id: Date { date }
    let date: Date
    let km: Double
    let minutes: Double
    let heartRate: Int?
}

struct ProtoReading {
    struct Point: Identifiable { var id: Date { date }; let date: Date; let value: Double; let isBest: Bool }
    struct Change { let text: String; let better: Bool }
    var value: String
    var unit: String
    var caption: String
    var change: Change?
    var points: [Point]
    var lowerIsBetter = false
    var isHeartRate = false
    var axisLabel: (Double) -> String = { String(Int($0.rounded())) }
}

struct ProtoPin: Identifiable {
    let id = UUID()
    let title: String
    let variation: String
    let glyph: String
    let isCardio: Bool
    var estimated = false
    var usesSpeed = false
    var metric: String
    /// Lifting: (date, best-set weight in lb, reps).
    var lifts: [(Date, Double, Int)] = []
    var sessions: [ProtoSession] = []

    static let liftMetrics = ["Best set", "Volume", "1RM"]
    // No Heart view (the user, 2026-10-17: "I don't think it's necessary").
    static func cardioMetrics(usesSpeed: Bool) -> [String] { ["Distance", usesSpeed ? "Speed" : "Pace", "Time"] }
    var metrics: [String] { isCardio ? Self.cardioMetrics(usesSpeed: usesSpeed) : Self.liftMetrics }

    // MARK: Readings

    var reading: ProtoReading { isCardio ? cardioReading : liftReading }

    private var liftReading: ProtoReading {
        let values: [(Date, Double)] = lifts.map { date, weight, reps in
            switch metric {
            case "Volume": (date, weight * Double(reps) * 3)
            case "1RM": (date, (weight * (1 + Double(reps) / 30)).rounded())
            default: (date, weight)
            }
        }
        let best = values.map(\.1).max() ?? 0
        let last = lifts.last!
        let shown = values.last!.1
        let isBest = shown >= best
        let first = values.first!.1
        let fraction = first > 0 ? shown / first - 1 : 0
        let rounded = Int((abs(fraction) * 100).rounded())
        let (value, unit): (String, String) = switch metric {
        case "Volume": (shown.formatted(.number.grouping(.automatic)), "lb")
        case "1RM": ("≈ \(Int(shown))", "lb")
        default: ("\(Int(last.1))", "lb × \(last.2)")
        }
        return ProtoReading(
            value: value, unit: unit,
            caption: last.0.formatted(.dateTime.month(.abbreviated).day()) + (isBest ? " · New best" : ""),
            change: ProtoReading.Change(text: "\(rounded)%", better: fraction >= 0),
            points: values.map { ProtoReading.Point(date: $0.0, value: $0.1, isBest: $0.1 >= best) })
    }

    private var cardioReading: ProtoReading {
        let last = sessions.last!, first = sessions.first!
        let date = last.date.formatted(.dateTime.month(.abbreviated).day())
        let approx = estimated ? "≈ " : ""
        switch metric {
        case "Pace":
            let pace = { (s: ProtoSession) in s.minutes * 60 / s.km }
            let best = sessions.map(pace).min() ?? 0
            let delta = pace(first) - pace(last)
            return ProtoReading(
                value: approx + Self.clock(pace(last)), unit: "/km",
                caption: date + (pace(last) <= best ? " · Fastest" : ""),
                change: ProtoReading.Change(text: "\(Self.clock(abs(delta))) \(delta >= 0 ? "faster" : "slower")", better: delta >= 0),
                points: sessions.map { ProtoReading.Point(date: $0.date, value: pace($0), isBest: pace($0) <= best) },
                lowerIsBetter: true, axisLabel: { Self.clock($0) })
        case "Speed":
            let speed = { (s: ProtoSession) in s.km / (s.minutes / 60) }
            let best = sessions.map(speed).max() ?? 0
            let fraction = speed(last) / speed(first) - 1
            return ProtoReading(
                value: approx + speed(last).formatted(.number.precision(.fractionLength(1))), unit: "km/h",
                caption: date + (speed(last) >= best ? " · Fastest" : ""),
                change: ProtoReading.Change(text: "\(Int((abs(fraction) * 100).rounded()))%", better: fraction >= 0),
                points: sessions.map { ProtoReading.Point(date: $0.date, value: speed($0), isBest: speed($0) >= best) },
                axisLabel: { String(format: "%.0f", $0) })
        case "Time":
            let best = sessions.map(\.minutes).max() ?? 0
            let fraction = last.minutes / first.minutes - 1
            return ProtoReading(
                value: "\(Int(last.minutes.rounded()))", unit: "min",
                caption: date + (last.minutes >= best ? " · Longest" : ""),
                change: ProtoReading.Change(text: "\(Int((abs(fraction) * 100).rounded()))%", better: fraction >= 0),
                points: sessions.map { ProtoReading.Point(date: $0.date, value: $0.minutes, isBest: $0.minutes >= best) })
        case "Heart":
            let withHR = sessions.filter { $0.heartRate != nil }
            return ProtoReading(
                value: "\(withHR.last?.heartRate ?? 0)", unit: "bpm avg",
                caption: (withHR.last?.date ?? last.date).formatted(.dateTime.month(.abbreviated).day())
                    + " · \(withHR.count) of \(sessions.count) sessions",
                change: nil,
                points: withHR.map { ProtoReading.Point(date: $0.date, value: Double($0.heartRate!), isBest: false) },
                isHeartRate: true)
        default:
            let best = sessions.map(\.km).max() ?? 0
            let fraction = last.km / first.km - 1
            return ProtoReading(
                value: approx + last.km.formatted(.number.precision(.fractionLength(1))), unit: "km",
                caption: date + (last.km >= best ? " · Longest" : ""),
                change: ProtoReading.Change(text: "\(Int((abs(fraction) * 100).rounded()))%", better: fraction >= 0),
                points: sessions.map { ProtoReading.Point(date: $0.date, value: $0.km, isBest: $0.km >= best) },
                axisLabel: { $0.formatted(.number.precision(.fractionLength(0...1))) })
        }
    }

    var cardioBests: [(String, String, String, String)] {
        guard let longest = sessions.max(by: { $0.km < $1.km }),
              let fastest = sessions.min(by: { $0.minutes / $0.km < $1.minutes / $1.km }),
              let longestTime = sessions.max(by: { $0.minutes < $1.minutes }) else { return [] }
        let day = { (s: ProtoSession) in s.date.formatted(.dateTime.month(.abbreviated).day()) }
        let approx = estimated ? "≈ " : ""
        let speedOrPace = usesSpeed
            ? ("Fastest average", approx + (fastest.km / (fastest.minutes / 60)).formatted(.number.precision(.fractionLength(1))) + " km/h")
            : ("Fastest pace", approx + Self.clock(fastest.minutes * 60 / fastest.km) + " /km")
        return [
            ("Longest distance", approx + longest.km.formatted(.number.precision(.fractionLength(1))) + " km", day(longest), "point.topleft.down.to.point.bottomright.curvepath"),
            (speedOrPace.0, speedOrPace.1, day(fastest), "speedometer"),
            ("Longest session", "\(Int(longestTime.minutes.rounded())) min", day(longestTime), "timer"),
        ]
    }

    func sessionLine(_ s: ProtoSession) -> String {
        let approx = estimated ? "≈ " : ""
        let distance = approx + s.km.formatted(.number.precision(.fractionLength(1))) + " km"
        let rate = usesSpeed
            ? (s.km / (s.minutes / 60)).formatted(.number.precision(.fractionLength(1))) + " km/h"
            : Self.clock(s.minutes * 60 / s.km) + " /km"
        let heart = s.heartRate.map { " · \($0) bpm" } ?? ""
        return "\(distance) · \(Int(s.minutes.rounded())) min · \(rate)\(heart)"
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    // MARK: Samples

    private static func days(_ count: Int, every step: Int) -> [Date] {
        let end = Calendar.current.startOfDay(for: .now)
        return (0..<count).map { Calendar.current.date(byAdding: .day, value: -(count - 1 - $0) * step - 2, to: end)! }
    }

    private static func lift(_ title: String, _ variation: String, _ glyph: String, weights: [Double], reps: [Int], every: Int) -> ProtoPin {
        let dates = days(weights.count, every: every)
        return ProtoPin(title: title, variation: variation, glyph: glyph, isCardio: false, metric: "Best set",
                        lifts: weights.indices.map { (dates[$0], weights[$0], reps[$0 % reps.count]) })
    }

    private static func cardio(_ title: String, _ variation: String, _ glyph: String, estimated: Bool = false,
                               usesSpeed: Bool = false, km: [Double], minutes: [Double], hr: [Int?], every: Int) -> ProtoPin {
        let dates = days(km.count, every: every)
        return ProtoPin(title: title, variation: variation, glyph: glyph, isCardio: true, estimated: estimated,
                        usesSpeed: usesSpeed, metric: "Distance",
                        sessions: km.indices.map { ProtoSession(date: dates[$0], km: km[$0], minutes: minutes[$0], heartRate: hr[$0 % hr.count]) })
    }

    static let pool: [String: ProtoPin] = [
        "Bench Press": lift("Bench Press", "Barbell", "dumbbell.fill",
                            weights: [160, 160, 165, 165, 170, 170, 175, 180, 180, 185], reps: [5], every: 5),
        "Chest Press": lift("Chest Press", "Most used · Hammer Strength", LookIcon.machine,
                            weights: [120, 120, 125, 130, 130, 135, 135, 140], reps: [8], every: 6),
        "Leg Press": lift("Leg Press", "Life Fitness · Iron Temple", LookIcon.machine,
                          weights: [300, 310, 320, 320, 340, 340, 350, 360], reps: [10], every: 6),
        "Lat Pulldown": lift("Lat Pulldown", "Most used · Life Fitness", LookIcon.machine,
                             weights: [110, 115, 115, 120, 125, 125, 130], reps: [10, 8], every: 7),
        "Romanian Deadlift": lift("Romanian Deadlift", "Barbell", "dumbbell.fill",
                                  weights: [135, 145, 155, 155, 165, 175], reps: [8], every: 8),
        "Shoulder Press": lift("Shoulder Press", "Dumbbell", "dumbbell.fill",
                               weights: [40, 45, 45, 50, 50, 55], reps: [10, 8], every: 7),
        "Outdoor Run": cardio("Outdoor Run", "GPS", "figure.run",
                              km: [4.0, 4.2, 3.8, 4.5, 4.8, 4.6, 5.0, 5.2], minutes: [25.5, 26, 22.8, 27, 28.1, 26.4, 28.8, 29.7],
                              hr: [148, 151, nil, 150, 153, 149, 152, 152], every: 4),
        "Indoor Run": cardio("Indoor Run", "Indoor", "figure.run.treadmill", estimated: true,
                             km: [3.0, 3.2, 3.5, 3.4], minutes: [20, 21, 22.5, 21.5], hr: [145, 147, 150, 146], every: 9),
        "Rowing": cardio("Rowing", "Indoor", "figure.rower", estimated: true,
                         km: [2.2, 2.0, 2.3, 2.2, 2.4], minutes: [12, 11, 12.2, 11.5, 12.4], hr: [138, nil, 141, 140, 142], every: 7),
        "Indoor Cycle": cardio("Indoor Cycle", "Indoor", "figure.indoor.cycle", estimated: true, usesSpeed: true,
                               km: [10.5, 11.2, 12.0], minutes: [30, 30, 32], hr: [132, 135, 137], every: 10),
    ]

    static let initial: [ProtoPin] = ["Bench Press", "Outdoor Run", "Leg Press", "Rowing"].compactMap { pool[$0] }

    static func make(title: String, metric: String) -> ProtoPin {
        var pin = pool[title] ?? pool["Bench Press"]!
        pin = ProtoPin(title: pin.title, variation: pin.variation, glyph: pin.glyph, isCardio: pin.isCardio,
                       estimated: pin.estimated, usesSpeed: pin.usesSpeed, metric: metric, lifts: pin.lifts, sessions: pin.sessions)
        return pin
    }

    static let liftChoices: [(String, String, String)] = [
        ("Bench Press", "Barbell · 2 machines", "dumbbell.fill"),
        ("Chest Press", "3 machines", LookIcon.machine),
        ("Lat Pulldown", "2 machines", LookIcon.machine),
        ("Leg Press", "1 machine", LookIcon.machine),
        ("Romanian Deadlift", "Barbell", "dumbbell.fill"),
        ("Shoulder Press", "Dumbbell · 1 machine", "dumbbell.fill"),
    ]
    static let cardioChoices: [(String, String, String)] = [
        ("Outdoor Run", "8 sessions", "figure.run"),
        ("Indoor Run", "4 sessions", "figure.run.treadmill"),
        ("Rowing", "5 sessions", "figure.rower"),
        ("Indoor Cycle", "3 sessions", "figure.indoor.cycle"),
    ]
}
