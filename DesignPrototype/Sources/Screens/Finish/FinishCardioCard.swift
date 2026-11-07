import SwiftUI
import MapKit

// PROTOTYPE — one finished cardio segment on the receipt (routes are allowed after Finish,
// never live). Header (activity), the route map for outdoor segments, the stats as big numbers
// with small labels on one three-column grid (Distance · Time · Average pace, then Avg. heart
// rate across two columns · Active calories under the pace), and per-unit splits as bars. The
// edit-distance row stays in History (the audit's "buried edit in the celebratory sheet").

struct FinishCardioCard: View {
    let segment: CardioSegment
    let heartRate: (average: Int, max: Int)?
    /// Draw the route line in (pen trace) once the user reaches this card.
    let traceShown: Bool
    /// The route over the plain well, no map tiles (offline / tiles unavailable).
    var offline = false
    /// Wait for the sheet to land before asking MapKit (off for frozen captures).
    var waitsForSheet = true

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header.finishAnchor()
            if segment.hasRoute {
                FinishRouteMap(route: segment.route, traceShown: traceShown, offline: offline, waitsForSheet: waitsForSheet)
                    .finishAnchor()
            }
            stats.finishAnchor()
            let splits = Derived.splits(segment)
            if splits.count > 1 {
                LookDivider()
                FinishSplitsView(splits: splits, unit: segment.unit, usesSpeed: segment.activity.usesSpeed)
                    .finishAnchor()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    private var header: some View {
        HStack(spacing: 12) {
            activityDisc
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.activity.name)
                    .font(look.font.cardTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Format.time(segment.startedAt))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// The activity glyph in an information-level disc (it is not a button): A a raised disc,
    /// B the control fill, C a plain ground-coloured disc with no outline (C's solid outline
    /// means "you can press this").
    @ViewBuilder private var activityDisc: some View {
        switch look.id {
        case .floodlight:
            IconDisc(symbol: segment.activity.symbol, size: 40, context: .onSurface)
                .background(Circle().fill(look.surfaceRaised))
        case .anatomy:
            IconDisc(symbol: segment.activity.symbol, size: 40, context: .onSurface)
        case .paper, .carbon:
            Image(systemName: segment.activity.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: 40, height: 40)
                .background(look.surfaceRaised, in: Circle())
                .accessibilityHidden(true)
        }
    }

    // MARK: Stats

    private struct Stat: Identifiable {
        let id: String
        let value: String
        let unit: String?
        let label: String
        let symbol: String
        var isHeart = false
    }

    private var primaryStats: [Stat] {
        var stats: [Stat] = []
        if let meters = segment.distanceMeters, meters > 0 {
            stats.append(Stat(id: "distance", value: Format.distance(meters: meters, segment.unit), unit: segment.unit.label,
                              label: "Distance", symbol: "point.topleft.down.to.point.bottomright.curvepath"))
        }
        stats.append(Stat(id: "time", value: Format.elapsed(segment.activeSeconds), unit: nil, label: "Time", symbol: "timer"))
        if segment.activity.usesSpeed, let speed = segment.speedPerHour {
            stats.append(Stat(id: "speed", value: Format.number((speed * 10).rounded() / 10), unit: "\(segment.unit.label)/h",
                              label: "Average speed", symbol: "speedometer"))
        } else if let pace = segment.paceSecondsPerUnit {
            stats.append(Stat(id: "pace", value: Format.pace(pace), unit: "/\(segment.unit.label)",
                              label: "Average pace", symbol: "gauge.with.needle"))
        }
        return stats
    }

    private var secondaryStats: [Stat] {
        var stats: [Stat] = []
        if let hr = heartRate {
            stats.append(Stat(id: "hr", value: "\(hr.average)", unit: "bpm", label: "Avg. heart rate", symbol: "heart.fill", isHeart: true))
        }
        if let cal = segment.activeCalories {
            stats.append(Stat(id: "cal", value: "\(cal)", unit: "cal", label: "Active calories", symbol: "flame.fill"))
        }
        return stats
    }

    /// One three-column grid: Distance · Time · Average pace, then Avg. heart rate across the
    /// first two columns and Active calories in the third, under the pace (so every figure
    /// starts on a column edge and "Avg. heart rate" never truncates). AX: one figure per row.
    @ViewBuilder private var stats: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(primaryStats + secondaryStats) { figure($0) }
            }
        } else {
            let primary = primaryStats, secondary = secondaryStats
            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow {
                    ForEach(primary) { figure($0).frame(maxWidth: .infinity, alignment: .leading) }
                    ForEach(primary.count..<3, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                }
                if !secondary.isEmpty {
                    GridRow {
                        if secondary.count == 2 {
                            figure(secondary[0]).frame(maxWidth: .infinity, alignment: .leading).gridCellColumns(2)
                            figure(secondary[1]).frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            figure(secondary[0]).frame(maxWidth: .infinity, alignment: .leading).gridCellColumns(2)
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
    }

    private func figure(_ stat: Stat) -> some View {
        StatFigure(value: stat.value, unit: stat.unit, label: stat.label, symbol: stat.symbol,
                   tint: stat.isHeart && !look.id.isPaperClub ? look.heartRate : nil,
                   symbolTint: stat.isHeart ? look.heartRate : nil, numberFont: look.font.statNumber)
    }
}

// MARK: - Route map

/// A picture of the route, not a live map: a flat, muted MapKit snapshot (no points of
/// interest) rendered off the main thread, then taken fully grey and re-tinted with the look's
/// own neutral (A and B cool grey, Paper warm paper, Carbon warm carbon), so no water blue or
/// park green competes with the family and heart-rate colours — the route is the only strong
/// mark. The route is drawn per GPS portion (never joined across a pause or outage) in the
/// look's text colour over a casing. Start and finish: a dot and a ring; a loop's meet in one
/// marker. The route traces in (about 1 s) when the user reaches it; Reduce Motion: drawn.
/// Loading and offline share one designed well: the trace on a faint grid in the look's
/// hairline colour, with its start and finish marks; the tiles fade in over it when they come.
struct FinishRouteMap: View {
    let route: [RoutePoint]
    let traceShown: Bool
    var offline = false
    var waitsForSheet = true

    @State private var progress: CGFloat
    @State private var tiles: UIImage?
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let height: CGFloat = 190

    init(route: [RoutePoint], traceShown: Bool, offline: Bool = false, waitsForSheet: Bool = true) {
        self.route = route
        self.traceShown = traceShown
        self.offline = offline
        self.waitsForSheet = waitsForSheet
        _progress = State(initialValue: traceShown ? 1 : 0)
    }

    var body: some View {
        let radius = max(10, look.radius.row)
        GeometryReader { geo in
            let size = geo.size
            let rect = Self.mapRect(for: route, aspect: size.width / max(1, size.height))
            let key = FinishRouteSnapshots.key(route: route, size: size, dark: look.isDark)
            ZStack {
                look.surfaceRaised
                FinishMapGrid()
                if let tiles, !offline {
                    Image(uiImage: tiles)
                        .resizable()
                        .grayscale(1)
                        .overlay(Rectangle().fill(look.surfaceRaised).blendMode(BlendMode.color))
                        .overlay(look.ground.opacity(look.isDark ? 0.3 : 0.2))
                        .compositingGroup()
                        .transition(.opacity)
                }
                routeLayer(size: size, rect: rect)
            }
            .task(id: key) {
                guard size.width > 1, !offline else { return }
                if let cached = FinishRouteSnapshots.cache[key] { tiles = cached; return }
                tiles = nil
                // Let the sheet land before MapKit starts working.
                if waitsForSheet { try? await Task.sleep(for: .milliseconds(450)) }
                guard !Task.isCancelled else { return }
                if let image = await FinishRouteSnapshots.render(rect: rect, size: size, dark: look.isDark) {
                    FinishRouteSnapshots.cache[key] = image
                    withAnimation(.easeOut(duration: 0.3)) { tiles = image }
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(look.hairline, lineWidth: look.stroke.hairline)
        }
        .onAppear { if reduceMotion { progress = 1 } }
        .onChange(of: traceShown) { _, shown in
            guard shown else { progress = 0; return }
            if reduceMotion { progress = 1; return }
            withAnimation(.easeInOut(duration: 1.1)) { progress = 1 }
        }
        .accessibilityElement()
        .accessibilityLabel("Route map")
    }

    @ViewBuilder private func routeLayer(size: CGSize, rect: MKMapRect) -> some View {
        let line = look.textPrimary
        let casing = look.isDark ? Color.black.opacity(0.62) : Color.white.opacity(0.92)
        let path = Self.path(route, in: size, rect: rect)
        let first = route.first.map { Self.point($0, in: size, rect: rect) }
        let last = route.last.map { Self.point($0, in: size, rect: rect) }
        let loop = first.flatMap { a in last.map { b in hypot(a.x - b.x, a.y - b.y) < 10 } } ?? false
        ZStack {
            path.trim(from: 0, to: progress)
                .stroke(casing, style: StrokeStyle(lineWidth: 8.5, lineCap: .round, lineJoin: .round))
            path.trim(from: 0, to: progress)
                .stroke(line, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
            if let last {
                // Finish: a ring that lands when the trace arrives (a loop: the start dot sits in it).
                Circle().fill(casing).frame(width: 19, height: 19)
                    .overlay { Circle().strokeBorder(line, lineWidth: 3.5) }
                    .overlay { if loop { Circle().fill(line).frame(width: 7, height: 7) } }
                    .position(last)
                    .scaleEffect(progress >= 1 ? 1 : 0.2, anchor: UnitPoint(x: last.x / max(1, size.width), y: last.y / max(1, size.height)))
                    .opacity(progress >= 1 ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6).delay(1.0), value: progress)
            }
            if let first, !(loop && progress >= 1) {
                // Start: a dot (it moves into the finish ring when the loop closes).
                Circle().fill(line).frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(casing, lineWidth: 2.5) }
                    .position(first)
            }
        }
    }

    // MARK: Projection (Web Mercator, identical to the snapshot's for an aspect-matched rect)

    /// The route's bounds padded by 28 % and widened or heightened to the view's aspect, so
    /// the snapshot and the drawn route share one linear projection.
    static func mapRect(for route: [RoutePoint], aspect: CGFloat) -> MKMapRect {
        let points = route.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        guard let first = points.first else { return .world }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        var width = max(maxX - minX, 200), height = max(maxY - minY, 200)
        width *= 1.3; height *= 1.3
        let target = Double(max(0.1, aspect))
        if width / height < target { width = height * target } else { height = width / target }
        let midX = (minX + maxX) / 2, midY = (minY + maxY) / 2
        return MKMapRect(x: midX - width / 2, y: midY - height / 2, width: width, height: height)
    }

    static func point(_ p: RoutePoint, in size: CGSize, rect: MKMapRect) -> CGPoint {
        let m = MKMapPoint(CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude))
        return CGPoint(x: (m.x - rect.minX) / rect.width * size.width, y: (m.y - rect.minY) / rect.height * size.height)
    }

    /// One subpath per GPS portion.
    static func path(_ route: [RoutePoint], in size: CGSize, rect: MKMapRect) -> Path {
        var path = Path()
        var previousPortion: Int?
        for p in route {
            let point = point(p, in: size, rect: rect)
            if p.portion != previousPortion { path.move(to: point) } else { path.addLine(to: point) }
            previousPortion = p.portion
        }
        return path
    }
}

/// The well under the route while the tiles load, or when they cannot: a faint square grid in
/// the look's hairline colour (a map without its pictures), so the trace never floats on grey.
private struct FinishMapGrid: View {
    @Environment(\.look) private var look

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            var path = Path()
            var x = (size.width.truncatingRemainder(dividingBy: spacing)) / 2
            while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y = (size.height.truncatingRemainder(dividingBy: spacing)) / 2
            while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            context.stroke(path, with: .color(look.hairline), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Snapshot rendering and a small in-memory cache (a receipt reopened, or a look switched
/// back, shows its tiles at once).
@MainActor
enum FinishRouteSnapshots {
    static var cache: [String: UIImage] = [:]

    static func key(route: [RoutePoint], size: CGSize, dark: Bool) -> String {
        let anchor = route.first.map { "\($0.latitude),\($0.longitude)" } ?? "none"
        return "\(anchor)-\(route.count)-\(Int(size.width))x\(Int(size.height))-\(dark)"
    }

    static func render(rect: MKMapRect, size: CGSize, dark: Bool) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = size
        options.scale = 3
        options.traitCollection = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration
        return try? await MKMapSnapshotter(options: options).start().image
    }
}

// MARK: - Splits

/// One bar per split, every row on one shared scale: the bar grows with speed, so the fastest
/// split is the longest — including the part-unit last row (its bar is its pace, not its
/// distance). Lengths are honest: a 4 % faster mile is a visibly, not wildly, longer bar. The
/// fastest whole split is lit (text colour) when it is also the longest bar; otherwise none.
struct FinishSplitsView: View {
    let splits: [CardioSplit]
    let unit: DistanceUnit
    let usesSpeed: Bool

    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var indexColumn: CGFloat = 34

    private func pace(_ split: CardioSplit) -> Double {
        split.distance > 0 ? Double(split.seconds) / split.distance : 0
    }

    private func isPartial(_ split: CardioSplit) -> Bool { split.distance < 0.995 }

    var body: some View {
        let paces = splits.map(pace).filter { $0 > 0 }
        let fastest = paces.min() ?? 1
        let fastestWhole = splits.filter { !isPartial($0) }.map(pace).filter { $0 > 0 }.min()
        let lit = splits.filter { !isPartial($0) }.count > 1 && fastestWhole == fastest ? fastest : nil
        VStack(alignment: .leading, spacing: 10) {
            Text("Splits")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(splits) { split in
                let p = pace(split)
                let partial = isPartial(split)
                // Length ∝ speed, stretched 3× around the fastest so a few seconds show.
                let share = p > 0 ? max(0.35, 1 - 3 * (p - fastest) / fastest) : 0
                let isLit = !partial && lit != nil && p == lit
                HStack(spacing: 10) {
                    Text(partial ? Format.number((split.distance * 100).rounded() / 100) : "\(split.index + 1)")
                        .font(.system(.footnote, weight: .semibold).monospacedDigit())
                        .foregroundStyle(look.textSecondary)
                        .frame(width: indexColumn, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: look.id.isPaperClub ? 3 : 4, style: .continuous)
                            .fill(isLit ? look.textPrimary : look.comparisonLast)
                            .frame(width: geo.size.width * share, height: 8)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 14)
                    Text(usesSpeed
                         ? "\(Format.number(((split.distance / Double(max(1, split.seconds)) * 3600) * 10).rounded() / 10)) \(unit.label)/h"
                         : "\(Format.pace(p)) /\(unit.label)")
                        .font(look.id == .anatomy ? Font.system(.footnote, design: .rounded, weight: .heavy).monospacedDigit()
                              : Font.system(.footnote, weight: .heavy).width(.expanded).monospacedDigit())
                        .foregroundStyle(isLit ? look.textPrimary : look.textSecondary)
                        .frame(minWidth: 70, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(partial
                    ? "Last \(Format.number((split.distance * 100).rounded() / 100)) \(unit.label), \(Format.pace(p)) per \(unit.label)"
                    : "Split \(split.index + 1), \(Format.pace(p)) per \(unit.label)\(isLit ? ", fastest" : "")")
            }
        }
    }
}
