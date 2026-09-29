import SwiftUI

// Shared pieces of the cardio area (Floodlight ticket 12, plain Floodlight): the activity glyphs,
// the ring, the figures table, the recording dot and blink, the GPS bars, the tray's buttons and
// the plain-number formatting (D52).

extension CardioActivity {
    var symbol: String {
        switch self {
        case .indoorWalk, .outdoorWalk: "figure.walk"
        case .indoorRun, .outdoorRun: "figure.run"
        case .indoorCycle: "figure.indoor.cycle"
        case .outdoorCycle: "figure.outdoor.cycle"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .stairStepper: "figure.stair.stepper"
        }
    }
}

// MARK: - Formatting (plain numbers, D52)

enum CardioFormat {
    static let distanceSymbol = "point.bottomleft.forward.to.point.topright.scurvepath"

    /// Two decimals, so a live figure never jumps width: "1.47"; a recorded zero is "0.00" (it is a
    /// value, distinct from a cleared entry); only no distance at all is "—".
    static func distance(_ meters: Double?, _ unit: CardioDistanceUnit) -> String {
        guard let meters, meters.isFinite, meters >= 0 else { return "—" }
        return String(format: "%.2f", meters / unit.metersPerUnit)
    }
    /// "18.4" units per hour, or "—".
    static func speed(meters: Double?, seconds: Double, unit: CardioDistanceUnit) -> String {
        guard let meters, meters.isFinite, meters > 0, seconds > 0 else { return "—" }
        return String(format: "%.1f", meters / seconds * 3_600 / unit.metersPerUnit)
    }
    static func speed(metersPerSecond: Double?, unit: CardioDistanceUnit) -> String {
        guard let speed = metersPerSecond, speed.isFinite, speed > 0 else { return "—" }
        return String(format: "%.1f", speed * 3_600 / unit.metersPerUnit)
    }
    static func pace(meters: Double?, seconds: Double, unit: CardioDistanceUnit) -> String {
        CardioMath.paceText(CardioMath.pace(seconds: seconds, meters: meters, unit: unit))
    }
    static func paceUnit(_ unit: CardioDistanceUnit) -> String { "/\(unit.rawValue)" }
    static func speedUnit(_ unit: CardioDistanceUnit) -> String { "\(unit.rawValue)/h" }
    /// What a distance ring counts toward: "of 2 mi" (decision 3, 2026-09-28).
    static func splitTarget(_ next: Int, _ unit: CardioDistanceUnit) -> String { "of \(next) \(unit.rawValue)" }
    /// A typed distance as `CardioSession.enterDistance` reads it (a comma is a decimal separator);
    /// nil for blank. The text is never rewritten: what the user typed or stored is what is checked.
    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
    /// The big field's edit rule: an edit that would make the entry longer than `limit` is refused
    /// WHOLE (the previous text stays) — never cut to a prefix, which could turn "1.23e-06" into
    /// 1.23 or an invalid "1.23456x" into a valid number. Shortening is always accepted, so a longer
    /// stored value loads and can be edited down.
    static func acceptEdit(from old: String, to new: String, limit: Int) -> String {
        new.count > limit && new.count > old.count ? old : new
    }
    /// Whether a non-blank entry would be refused (`CardioSessionError.invalidDistance`).
    static func isInvalidEntry(_ text: String, unit: CardioDistanceUnit) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let value = parse(text) else { return true }
        return !value.isFinite || value < 0 || !(value * unit.metersPerUnit).isFinite
    }
}

extension Look {
    /// The ring's number: the look's figure face at a Dynamic-Type-scaled size (pass a size that
    /// derives from a `@ScaledMetric`).
    func cardioHeroFont(size: CGFloat) -> Font {
        Font.system(size: size, weight: .heavy).width(.expanded).monospacedDigit()
    }
    /// Small label over a figure.
    var cardioLabelFont: Font { .footnote }
    var cardioUnitFont: Font { .system(.subheadline, weight: .semibold) }
    var cardioCaptionFont: Font { .system(.subheadline, weight: .semibold) }
}

extension EnvironmentValues {
    /// True in UI-test stores (captures): the pulse, blink, flicker and rolling digits rest in their
    /// final state, so a screenshot never catches a mid-blink or mid-roll frame.
    @Entry var cardioStill: Bool = WorkoutTrackerStore.isUITestReset
}

// MARK: - Recording dot, blink

/// The recording pulse: a solid dot that sends out a small ripple every 1.4 s. Reduce Motion or
/// a still capture: a steady dot.
struct CardioPulseDot: View {
    var color: Color
    var size: CGFloat = 9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still

    var body: some View {
        let animate = !reduceMotion && !still
        TimelineView(.animation(minimumInterval: nil, paused: !animate)) { context in
            let phase = animate ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4 : 0
            ZStack {
                if animate {
                    Circle().stroke(color, lineWidth: max(1.2, size * 0.16))
                        .scaleEffect(1 + 0.9 * phase).opacity(0.7 * (1 - phase))
                }
                Circle().fill(color)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A stopped watch: the pause glyph over the frozen time blinks (never the time, which stays
/// legible). Reduce Motion / still: steady.
struct CardioBlink: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still

    func body(content: Content) -> some View {
        if reduceMotion || still {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let wave = 0.5 + 0.5 * cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.6)
                content.opacity(0.3 + 0.7 * wave)
            }
        }
    }
}

// MARK: - GPS bars

/// Three signal bars lighting in turn while GPS searches (Reduce Motion / still: one lit).
struct CardioSignalBars: View {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still
    @ScaledMetric(relativeTo: .caption) private var unit: CGFloat = 3.5

    var body: some View {
        let searching = !reduceMotion && !still
        TimelineView(.animation(minimumInterval: 0.25, paused: !searching)) { context in
            let tick = searching ? Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 4 : 1
            HStack(alignment: .bottom, spacing: unit * 0.55) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < tick ? look.textPrimary : look.ringTrack)
                        .frame(width: unit, height: unit * (1.4 + CGFloat(i) * 0.9))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Activity disc

/// The activity figure in a raised disc: the picker tiles, the live header and the segment cards,
/// so an activity always wears the same badge.
struct CardioActivityDisc: View {
    var symbol: String
    var size: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .frame(width: size, height: size)
            .background(look.surfaceRaised, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - The ring

enum CardioRingPhase: Equatable { case recording, paused, stalled, still }

/// Cardio's one bold element (plain Floodlight): one segment per minute / tenth of a unit / five
/// seconds. Recorded segments light; the current one fills in violet and flickers while recording.
/// Paused: the lit segments go hollow. Stalled (GPS lost on a distance ring): the head stops at a
/// slashed pin and the unrecorded track thins. Met: fully lit with a check at 12 o'clock.
struct CardioRing<Center: View>: View {
    var progress: Double
    var ticks: Int
    var phase: CardioRingPhase
    var size: CGFloat
    var lineWidth: CGFloat
    /// The ground the ring sits on (the pin and badge are cut out of it).
    var notch: Color
    @ViewBuilder var center: Center

    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still

    private var p: Double { max(0, min(1, progress)) }
    private var met: Bool { progress >= 1 && (phase == .recording || phase == .still) }
    private var radius: CGFloat { (size - lineWidth) / 2 }

    var body: some View {
        ZStack {
            if ticks > 0 { segmented } else { plain }
            if phase == .stalled { stalledHead }
            if met && size >= 120 && phase == .recording { metBadge }
            center
        }
        .frame(width: size, height: size)
    }

    private var geometry: (n: Int, step: Double, gap: Double) {
        let n = max(2, ticks)
        return (n, 1.0 / Double(n), n > 30 ? 0.26 : 0.16)
    }

    private var segmented: some View {
        let (n, step, gap) = geometry
        let exact = p * Double(n)
        let lit = min(n, Int(exact.rounded(.down)))
        let partial = exact - Double(lit)
        let solid = StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
        let hollow = max(1.5, lineWidth * 0.12)
        func start(_ i: Int) -> Double { Double(i) * step + step * gap / 2 }
        func end(_ i: Int) -> Double { Double(i + 1) * step - step * gap / 2 }
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let arc = RingArc(start: start(i), end: end(i))
                if i < lit {
                    if phase == .paused {
                        arc.stroke(style: solid).stroke(look.textSecondary, lineWidth: hollow)
                    } else {
                        arc.stroke(look.done, style: solid)
                    }
                } else if phase == .stalled {
                    arc.stroke(look.ringTrack, style: StrokeStyle(lineWidth: max(2, lineWidth * 0.28), lineCap: .butt))
                } else {
                    arc.stroke(look.ringTrack, style: solid)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: lit)
            if lit < n, partial > 0.001, phase != .stalled {
                let arc = RingArc(start: start(lit), end: start(lit) + (end(lit) - start(lit)) * partial)
                if phase == .paused {
                    arc.stroke(style: solid).stroke(look.textSecondary, lineWidth: hollow)
                } else {
                    flicker { arc.stroke(phase == .recording ? look.live : look.done, style: solid) }
                }
            }
        }
        .padding(lineWidth / 2)
    }

    @ViewBuilder private func flicker<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        let view = content()
        if phase == .recording && !reduceMotion && !still {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                view.opacity(0.55 + 0.45 * (0.5 + 0.5 * cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.4)))
            }
        } else {
            view
        }
    }

    private var plain: some View {
        ZStack {
            Circle().stroke(look.ringTrack, lineWidth: lineWidth)
            if p > 0 {
                RingArc(start: 0, end: p)
                    .stroke(p >= 1 ? look.done : (phase == .paused ? look.textTertiary : look.done),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: p >= 1 ? .butt : .round))
            }
        }
        .padding(lineWidth / 2)
    }

    private func point(at fraction: Double) -> CGSize {
        let angle = fraction * 2 * Double.pi - Double.pi / 2
        return CGSize(width: radius * CGFloat(cos(angle)), height: radius * CGFloat(sin(angle)))
    }

    /// Where the recorded arc ends (inside the current segment).
    private var headFraction: Double {
        guard ticks > 0 else { return p }
        let (n, step, gap) = geometry
        let exact = p * Double(n)
        let lit = exact.rounded(.down)
        return lit * step + step * gap / 2 + (step - step * gap) * (exact - lit)
    }

    private var stalledHead: some View {
        let side = max(28, lineWidth * 2.3)
        return Image(systemName: "location.slash.fill")
            .font(.system(size: side * 0.46, weight: .bold))
            .foregroundStyle(look.textPrimary)
            .frame(width: side, height: side)
            .background(notch, in: Circle())
            .overlay { Circle().strokeBorder(look.textSecondary, lineWidth: 2) }
            .offset(point(at: headFraction))
            .accessibilityHidden(true)
    }

    private var metBadge: some View {
        let side = max(30, lineWidth * 2.5)
        return Image(systemName: "checkmark")
            .font(.system(size: side * 0.44, weight: .heavy))
            .foregroundStyle(look.onDone)
            .frame(width: side, height: side)
            .background(look.done, in: Circle())
            .overlay { Circle().strokeBorder(notch, lineWidth: 3) }
            .offset(point(at: 0))
            .transition(reduceMotion ? .opacity : .scale(scale: 1.6).combined(with: .opacity))
            .accessibilityHidden(true)
    }
}

// MARK: - Figures table

struct CardioStat: Identifiable {
    var id: String { identifier ?? label }
    var label: String
    var symbol: String
    var value: String
    var unit: String?
    var tint: Color? = nil
    var symbolTint: Color? = nil
    var dimmed = false
    /// A glyph after the label: "pencil" (editable), "location.slash" (GPS lost).
    var accessory: String? = nil
    var action: (() -> Void)? = nil
    /// The UI tests' handle (`cardioDistanceMetric`, `cardioSummaryEditDistance`, …).
    var identifier: String? = nil
    /// With an action: the figure stays its own element (`identifier`, tappable) and a separate
    /// pencil button carries this handle — the live Distance figure (`cardioEditDistance`).
    var editIdentifier: String? = nil
    /// Spoken after the figure (where a distance came from; never shown — September 19).
    var spokenSuffix: String? = nil
}

/// Paired figures in one hairline table: one panel split by hairlines. At accessibility sizes the
/// pairs stay (labels wrap to two lines, numerals may shrink to 0.7×) so the table keeps its shape.
struct CardioStatGrid: View {
    enum Style { case panel, inset }
    var stats: [CardioStat]
    var style: Style = .panel
    var numberFont: Font?
    var dense = false
    /// The numbers stop growing at xxxLarge (the live table, under the ring's centre).
    var capsNumbers = false
    @Environment(\.look) private var look

    private var rows: [[CardioStat]] {
        stride(from: 0, to: stats.count, by: 2).map { Array(stats[$0..<min($0 + 2, stats.count)]) }
    }

    var body: some View {
        let table = VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { LookDivider() }
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { i, stat in
                        if i > 0 { LookDivider(vertical: true) }
                        CardioStatCell(stat: stat, numberFont: numberFont ?? look.font.bigNumber, dense: dense,
                                       capsNumbers: capsNumbers)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    if row.count == 1 {
                        LookDivider(vertical: true)
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        if style == .panel { table.lookSurface(.stat) } else { table }
    }
}

/// Small label (with its glyph) over a big number and a small unit.
struct CardioStatCell: View {
    var stat: CardioStat
    var numberFont: Font
    var dense = false
    var capsNumbers = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardioStill) private var still

    var body: some View {
        if let action = stat.action, let editIdentifier = stat.editIdentifier {
            content
                .onTapGesture(perform: action)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Edit distance", action)
                .accessibilityIdentifier(stat.identifier ?? "")
                .overlay(alignment: .topTrailing) {
                    Button(action: action) {
                        Image(systemName: "pencil")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(look.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.lookPressable)
                    .accessibilityLabel("Edit distance")
                    .accessibilityIdentifier(editIdentifier)
                }
        } else if let action = stat.action {
            Button(action: action) { content }
                .buttonStyle(.lookPressable)
                .accessibilityHint("Edits the distance")
                .accessibilityIdentifier(stat.identifier ?? "")
        } else {
            content.accessibilityIdentifier(stat.identifier ?? "")
        }
    }

    private var noReading: Bool { stat.value == "—" }

    private var content: some View {
        let ax = typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                // At accessibility sizes the glyph goes: the label keeps whole words in a half-width cell.
                if !ax {
                    Image(systemName: stat.symbol)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(stat.symbolTint ?? look.textSecondary)
                }
                Text(stat.label)
                    .font(look.cardioLabelFont)
                    .foregroundStyle(look.textSecondary)
                    .lineLimit(ax ? 2 : 1)
                    .minimumScaleFactor(ax ? 1 : 0.8)
                    .fixedSize(horizontal: false, vertical: ax)
                if let accessory = stat.accessory, stat.editIdentifier == nil {
                    Image(systemName: accessory)
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(stat.action != nil ? look.textPrimary : look.textSecondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(stat.value)
                    .font(numberFont)
                    .dynamicTypeSize(...(capsNumbers ? DynamicTypeSize.xxxLarge : DynamicTypeSize.accessibility5))
                    .foregroundStyle(noReading ? look.textTertiary : (stat.dimmed ? look.textSecondary : (stat.tint ?? look.textPrimary)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(reduceMotion || still ? nil : .snappy(duration: 0.3), value: stat.value)
                if let unit = stat.unit, !noReading {
                    Text(unit).font(look.cardioUnitFont).foregroundStyle(look.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.horizontal, ax ? 12 : 16)
        .padding(.top, dense ? 10 : 13)
        .padding(.bottom, dense ? 9 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([stat.label, noReading ? "no reading" : stat.value, noReading ? nil : stat.unit]
            .compactMap { $0 }.joined(separator: " ") + (stat.spokenSuffix ?? ""))
    }
}

// MARK: - Tray

/// The tray's buttons: full-width capsules, 54 pt (capped at 60 at accessibility sizes, so the
/// tray never covers the figures). `prominent` is the state's one filled command.
struct CardioTrayButtonStyle: ButtonStyle {
    var prominent: Bool
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 54
    @Environment(\.look) private var look
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(look.font.button)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: min(height, 60))
        Group {
            if prominent {
                label.foregroundStyle(look.onAction).background(look.action, in: Capsule())
            } else {
                label.foregroundStyle(look.textPrimary)
                    .background(look.pillFill, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            }
        }
        .contentShape(Capsule())
        .opacity(isEnabled ? 1 : 0.4)
        .pressFeedback(configuration.isPressed)
    }
}

/// The pinned tray's slab: the rest bar's glass bar.
struct CardioTrayBackground: View {
    @Environment(\.look) private var look

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous)
        shape.fill(look.slab)
            .background(.ultraThinMaterial, in: shape)
            .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1) }
            .shadow(color: look.floatShadow(0.5), radius: 14, x: 0, y: 6)
    }
}
