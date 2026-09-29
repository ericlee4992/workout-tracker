import MapKit
import SwiftUI

// Finished cardio (Floodlight ticket 12): the receipt's and History's cardio card, the cardio-only
// History hero, the route picture and the splits. Routes appear only after Finish (never live).

/// One finished segment: the disc, name and start time; the route (outdoor) as a picture; the
/// figures on one grid — Distance · Time · Average pace (or speed), then Avg. heart rate · Active
/// calories; Splits when there are two or more. Distance is tappable (pencil) and opens Distance —
/// on the receipt too (the user's decision 4, 2026-09-28).
struct CardioSummaryCard: View {
    var segment: CardioSegment
    var showsRoute = true
    @Environment(\.look) private var look
    @State private var editingDistance = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                CardioActivityDisc(symbol: segment.activity.symbol, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.activity.name)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(segment.startedAt.formatted(date: .omitted, time: .shortened))
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cardioSummary.\(segment.activityRawValue)")
            if showsRoute && segment.route.count > 1 {
                CardioRouteMap(points: segment.route).frame(height: 190)
            }
            CardioFigures(segment: segment, editDistance: { editingDistance = true })
            let splits = CardioReadout.splits(segment)
            if splits.count > 1 {
                LookDivider()
                CardioSplitsView(splits: splits, unit: segment.unit, usesSpeed: segment.activity.usesSpeed)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $editingDistance) { CardioDistanceSheet(segment: segment) }
    }
}

/// The finished figures: one three-column grid at the default size (every figure starts on a
/// column edge), one figure per row at accessibility sizes.
private struct CardioFigures: View {
    var segment: CardioSegment
    var editDistance: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Figure: Identifiable {
        var id: String
        var value: String
        var unit: String?
        var label: String
        var symbol: String
        var tint: Color? = nil
        var edits = false
    }

    private var seconds: Double { segment.activeDuration(at: segment.endedAt ?? segment.lastCheckpointAt) }

    private var primary: [Figure] {
        let unit = segment.unit
        var list = [
            Figure(id: "distance", value: CardioFormat.distance(segment.distanceMeters, unit), unit: unit.rawValue,
                   label: segment.manualDistanceValue != nil ? "Entered distance" : "Distance",
                   symbol: CardioFormat.distanceSymbol, edits: true),
            Figure(id: "time", value: Format.elapsed(seconds: Int(seconds)), label: "Time", symbol: "timer")]
        if segment.distanceMeters != nil {
            if segment.activity.usesSpeed {
                list.append(Figure(id: "rate", value: CardioFormat.speed(meters: segment.distanceMeters, seconds: seconds, unit: unit),
                                   unit: CardioFormat.speedUnit(unit), label: "Average speed", symbol: "speedometer"))
            } else {
                list.append(Figure(id: "rate", value: CardioFormat.pace(meters: segment.distanceMeters, seconds: seconds, unit: unit),
                                   unit: CardioFormat.paceUnit(unit), label: "Average pace", symbol: "gauge.with.needle"))
            }
        }
        return list
    }

    private var secondary: [Figure] {
        var list: [Figure] = []
        if let bpm = segment.averageHeartRate {
            list.append(Figure(id: "hr", value: "\(bpm)", unit: "bpm", label: "Avg. heart rate", symbol: "heart.fill",
                               tint: look.heartRate))
        }
        if let calories = segment.activeEnergyKilocalories {
            list.append(Figure(id: "cal", value: "\(Int(calories.rounded()))", unit: "cal", label: "Active calories",
                               symbol: "flame.fill"))
        }
        return list
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(primary + secondary) { figure($0) }
            }
        } else {
            let primary = primary, secondary = secondary
            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow {
                    ForEach(primary) { figure($0).frame(maxWidth: .infinity, alignment: .leading) }
                    ForEach(primary.count..<3, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                }
                if !secondary.isEmpty {
                    GridRow {
                        figure(secondary[0]).frame(maxWidth: .infinity, alignment: .leading).gridCellColumns(2)
                        if secondary.count > 1 {
                            figure(secondary[1]).frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func figure(_ f: Figure) -> some View {
        let face = VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(f.value)
                    .font(look.font.statNumber)
                    .foregroundStyle(f.value == "—" ? look.textTertiary : (f.tint ?? look.textPrimary))
                if let unit = f.unit, f.value != "—" {
                    Text(unit).font(look.cardioUnitFont).foregroundStyle(look.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Image(systemName: f.symbol).font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(f.id == "hr" ? look.heartRate : look.textSecondary)
                Text(f.label).font(.caption).foregroundStyle(look.textSecondary).lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                if f.edits {
                    Image(systemName: "pencil").font(.system(.caption, weight: .bold)).foregroundStyle(look.textPrimary)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(f.value == "—" ? "\(f.label), none" : "\(f.label), \(f.value) \(f.unit ?? "")")
        if f.edits {
            Button(action: editDistance) { face.frame(minHeight: 44, alignment: .topLeading) }
                .buttonStyle(.lookPressable)
                .accessibilityHint("Edits the distance")
                .accessibilityIdentifier("cardioSummaryEditDistance")
        } else {
            face
        }
    }
}

// MARK: - Cardio-only History hero (H04)

/// A cardio-only workout's hero, under the title block: the route (the bold element when there is
/// one) with a marker per mile / km, then the distance as the hero figure (tap to edit), Time and
/// pace or speed beside it. Where the distance came from is not shown (September 19).
struct CardioHistoryHero: View {
    var segment: CardioSegment
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingDistance = false
    @ScaledMetric(relativeTo: .title) private var mapHeight: CGFloat = 250

    private var seconds: Double { segment.activeDuration(at: segment.endedAt ?? segment.lastCheckpointAt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if segment.route.count > 1 {
                CardioRouteMap(points: segment.route, markerMeters: segment.unit.metersPerUnit,
                               totalMeters: segment.distanceMeters)
                    .frame(height: min(mapHeight, 320))
            } else {
                HStack(spacing: 12) {
                    CardioActivityDisc(symbol: segment.activity.symbol, size: 44)
                    Text(segment.activity.name).font(look.font.cardTitle).foregroundStyle(look.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: 12))
            layout {
                distanceButton.frame(maxWidth: .infinity, alignment: .leading)
                figure(Format.elapsed(seconds: Int(seconds)), nil, "Time")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if segment.distanceMeters != nil {
                    if segment.activity.usesSpeed {
                        figure(CardioFormat.speed(meters: segment.distanceMeters, seconds: seconds, unit: segment.unit),
                               CardioFormat.speedUnit(segment.unit), "Average speed")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        figure(CardioFormat.pace(meters: segment.distanceMeters, seconds: seconds, unit: segment.unit),
                               CardioFormat.paceUnit(segment.unit), "Average pace")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardioSummary.\(segment.activityRawValue)")
        .sheet(isPresented: $editingDistance) { CardioDistanceSheet(segment: segment) }
    }

    private var distanceButton: some View {
        Button { editingDistance = true } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let meters = segment.distanceMeters {
                    figure(CardioFormat.distance(meters, segment.unit), segment.unit.rawValue,
                           segment.manualDistanceValue != nil ? "Entered distance" : "Distance", hero: true)
                } else {
                    figure("—", nil, "Enter distance", hero: true)
                }
                Image(systemName: "pencil")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(segment.distanceMeters.map {
            "\(segment.manualDistanceValue != nil ? "Entered distance" : "Distance"), \(CardioFormat.distance($0, segment.unit)) \(segment.unit.rawValue)"
        } ?? "Enter distance")
        .accessibilityHint("Edits the distance")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("cardioSummaryEditDistance")
    }

    private func figure(_ value: String, _ unit: String?, _ label: String, hero: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(hero ? look.font.heroNumber : look.font.bigNumber)
                    .foregroundStyle(value == "—" ? look.textTertiary : look.textPrimary)
                if let unit, value != "—" {
                    Text(unit).font(.system(.subheadline, weight: .bold)).foregroundStyle(look.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value) \(unit ?? "")")
    }
}

/// History's Splits section for a cardio-only workout (two or more splits).
struct CardioSplitsSection: View {
    var segment: CardioSegment
    @Environment(\.look) private var look

    var body: some View {
        let splits = CardioReadout.splits(segment)
        if splits.count > 1 {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Splits", trailing: segment.activity.usesSpeed ? CardioFormat.speedUnit(segment.unit)
                              : CardioFormat.paceUnit(segment.unit))
                CardioSplitsView(splits: splits, unit: segment.unit, usesSpeed: segment.activity.usesSpeed, titled: false)
                    .padding(16)
                    .lookSurface(.panel)
            }
            .accessibilityIdentifier("cardioSplits")
        }
    }
}

// MARK: - Splits

/// One bar per split on a shared scale: the bar grows with speed, so the fastest split is the
/// longest (a part-unit tail's bar is its pace, not its distance). The fastest whole split is lit.
struct CardioSplitsView: View {
    var splits: [CardioSplit]
    var unit: CardioDistanceUnit
    var usesSpeed: Bool
    var titled = true
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var indexColumn: CGFloat = 34

    var body: some View {
        let paces = splits.compactMap(\.secondsPerUnit)
        let fastest = paces.min() ?? 1
        let whole = splits.filter { !$0.isPartial }
        let fastestWhole = whole.compactMap(\.secondsPerUnit).min()
        let lit = whole.count > 1 && fastestWhole == fastest ? fastest : nil
        VStack(alignment: .leading, spacing: 10) {
            if titled {
                Text("Splits")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(splits) { split in
                let pace = split.secondsPerUnit ?? 0
                // Length ∝ speed, stretched 3× around the fastest so a few seconds show.
                let share = pace > 0 ? max(0.35, 1 - 3 * (pace - fastest) / fastest) : 0
                let isLit = !split.isPartial && lit != nil && pace == lit
                let tail = String(format: "%.2f", split.distance)
                HStack(spacing: 10) {
                    Text(split.isPartial ? tail : "\(split.index + 1)")
                        .font(.system(.footnote, weight: .semibold).monospacedDigit())
                        .foregroundStyle(look.textSecondary)
                        .frame(width: indexColumn, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isLit ? look.textPrimary : look.comparisonLast)
                            .frame(width: geo.size.width * share, height: 8)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 14)
                    Text(usesSpeed
                         ? "\(String(format: "%.1f", pace > 0 ? 3_600 / pace : 0)) \(CardioFormat.speedUnit(unit))"
                         : "\(CardioMath.paceText(pace)) \(CardioFormat.paceUnit(unit))")
                        .font(.system(.footnote, weight: .heavy).width(.expanded).monospacedDigit())
                        .foregroundStyle(isLit ? look.textPrimary : look.textSecondary)
                        .fixedSize()
                        .frame(minWidth: 70, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(split.isPartial
                    ? "Last \(tail) \(unit.rawValue), \(CardioMath.paceText(pace)) per \(unit.rawValue)"
                    : "Split \(split.index + 1), \(CardioMath.paceText(pace)) per \(unit.rawValue)\(isLit ? ", fastest" : "")")
            }
        }
    }
}

// MARK: - Route picture

/// A picture of the route, not a live map: a flat, muted MapKit snapshot taken to grey and re-tinted
/// with the look's neutral, so no water blue or park green competes with the figures. The route is
/// drawn per GPS portion (never joined across a pause or outage) in the text colour over a casing;
/// start is a dot, finish a ring (a loop: the dot inside the ring). While the tiles load, or when
/// they cannot, the same well shows a faint grid under the route. Optional markers per mile / km.
struct CardioRouteMap: View {
    var points: [CardioRoutePoint]
    var markerMeters: Double? = nil
    var totalMeters: Double? = nil
    @Environment(\.look) private var look
    @State private var tiles: UIImage?

    var body: some View {
        let radius = max(10, look.radius.row)
        GeometryReader { geo in
            let size = geo.size
            let rect = Self.mapRect(for: points, aspect: size.width / max(1, size.height))
            ZStack {
                look.surfaceRaised
                CardioMapGrid()
                if let tiles {
                    Image(uiImage: tiles)
                        .resizable()
                        .grayscale(1)
                        .overlay(Rectangle().fill(look.surfaceRaised).blendMode(.color))
                        .overlay(look.ground.opacity(look.isDark ? 0.3 : 0.2))
                        .compositingGroup()
                        .transition(.opacity)
                }
                routeLayer(size: size, rect: rect)
            }
            .task(id: "\(points.count)-\(Int(size.width))x\(Int(size.height))-\(look.isDark)") {
                guard size.width > 1 else { return }
                let key = CardioRouteSnapshots.key(points, size: size, dark: look.isDark)
                if let cached = CardioRouteSnapshots.cache[key] { tiles = cached; return }
                tiles = nil
                if let image = await CardioRouteSnapshots.render(rect: rect, size: size, dark: look.isDark) {
                    CardioRouteSnapshots.cache[key] = image
                    withAnimation(.easeOut(duration: 0.3)) { tiles = image }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(look.hairline, lineWidth: 1)
        }
        .accessibilityElement()
        .accessibilityLabel("Recorded cardio route")
        .accessibilityIdentifier("cardioRoute")
    }

    private var sorted: [CardioRoutePoint] { points.sorted { $0.date < $1.date } }

    @ViewBuilder private func routeLayer(size: CGSize, rect: MKMapRect) -> some View {
        let route = sorted
        let line = look.textPrimary
        let casing = look.isDark ? Color.black.opacity(0.62) : Color.white.opacity(0.92)
        let first = route.first.map { Self.point($0, in: size, rect: rect) }
        let last = route.last.map { Self.point($0, in: size, rect: rect) }
        let loop = first.flatMap { a in last.map { b in hypot(a.x - b.x, a.y - b.y) < 10 } } ?? false
        let path = Self.path(route, in: size, rect: rect)
        ZStack {
            path.stroke(casing, style: StrokeStyle(lineWidth: 8.5, lineCap: .round, lineJoin: .round))
            path.stroke(line, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
            ForEach(Array(markers(route, size: size, rect: rect).enumerated()), id: \.offset) { index, point in
                Text("\(index + 1)")
                    .font(.system(.caption2, weight: .heavy).monospacedDigit())
                    .foregroundStyle(look.ground)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(line, in: Circle())
                    .overlay { Circle().strokeBorder(casing, lineWidth: 2) }
                    .position(point)
                    .accessibilityHidden(true)
            }
            if let last {
                Circle().fill(casing).frame(width: 19, height: 19)
                    .overlay { Circle().strokeBorder(line, lineWidth: 3.5) }
                    .overlay { if loop { Circle().fill(line).frame(width: 7, height: 7) } }
                    .position(last)
            }
            if let first, !loop {
                Circle().fill(line).frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(casing, lineWidth: 2.5) }
                    .position(first)
            }
        }
    }

    /// Where each whole mile / km falls along the drawn route (scaled to the recorded distance).
    private func markers(_ route: [CardioRoutePoint], size: CGSize, rect: MKMapRect) -> [CGPoint] {
        guard let step = markerMeters, step > 0, route.count > 1 else { return [] }
        var cumulative: [Double] = [0]
        for i in 1..<route.count {
            cumulative.append(cumulative[i - 1] + (route[i].portion == route[i - 1].portion
                ? CardioMath.meters(between: route[i - 1], and: route[i]) : 0))
        }
        guard let routeMeters = cumulative.last, routeMeters > 0 else { return [] }
        let total = totalMeters ?? routeMeters
        let scale = total / routeMeters
        var result: [CGPoint] = []
        var target = step
        while target < total - step * 0.05 {
            if let i = cumulative.firstIndex(where: { $0 * scale >= target }), i > 0 {
                let a = route[i - 1], b = route[i]
                let span = (cumulative[i] - cumulative[i - 1]) * scale
                let t = span > 0 ? (target - cumulative[i - 1] * scale) / span : 0
                let pa = Self.point(a, in: size, rect: rect), pb = Self.point(b, in: size, rect: rect)
                result.append(CGPoint(x: pa.x + (pb.x - pa.x) * t, y: pa.y + (pb.y - pa.y) * t))
            }
            target += step
        }
        return result
    }

    /// The route's bounds padded by 30 % and fitted to the view's aspect, so the snapshot and the
    /// drawn route share one projection.
    static func mapRect(for route: [CardioRoutePoint], aspect: CGFloat) -> MKMapRect {
        let points = route.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        guard let first = points.first else { return .world }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points { minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y) }
        var width = max(maxX - minX, 200) * 1.3, height = max(maxY - minY, 200) * 1.3
        let target = Double(max(0.1, aspect))
        if width / height < target { width = height * target } else { height = width / target }
        return MKMapRect(x: (minX + maxX) / 2 - width / 2, y: (minY + maxY) / 2 - height / 2, width: width, height: height)
    }

    static func point(_ p: CardioRoutePoint, in size: CGSize, rect: MKMapRect) -> CGPoint {
        let m = MKMapPoint(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude))
        return CGPoint(x: (m.x - rect.minX) / rect.width * size.width, y: (m.y - rect.minY) / rect.height * size.height)
    }

    /// One subpath per GPS portion.
    static func path(_ route: [CardioRoutePoint], in size: CGSize, rect: MKMapRect) -> Path {
        var path = Path()
        var previous: UUID?
        for p in route {
            let point = point(p, in: size, rect: rect)
            if p.portion != previous { path.move(to: point) } else { path.addLine(to: point) }
            previous = p.portion
        }
        return path
    }
}

/// The well under the route while the tiles load, or when they cannot: a faint square grid.
private struct CardioMapGrid: View {
    @Environment(\.look) private var look

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            var path = Path()
            var x = size.width.truncatingRemainder(dividingBy: spacing) / 2
            while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y = size.height.truncatingRemainder(dividingBy: spacing) / 2
            while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            context.stroke(path, with: .color(look.hairline), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Snapshot rendering and a small in-memory cache (a reopened receipt shows its tiles at once).
@MainActor
enum CardioRouteSnapshots {
    static var cache: [String: UIImage] = [:]

    static func key(_ route: [CardioRoutePoint], size: CGSize, dark: Bool) -> String {
        let anchor = route.first.map { "\($0.latitude),\($0.longitude)" } ?? "none"
        return "\(anchor)-\(route.count)-\(Int(size.width))x\(Int(size.height))-\(dark)"
    }

    static func render(rect: MKMapRect, size: CGSize, dark: Bool) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = size
        options.traitCollection = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration
        return try? await MKMapSnapshotter(options: options).start().image
    }
}
