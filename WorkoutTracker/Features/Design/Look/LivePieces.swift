import SwiftUI

// Live workout pieces. They take plain values and closures (never the Store), so any
// screen can drive them. The header line keeps the user's skeleton:
// gym chip · clock WITH seconds (medium-large, not a hero) · small "N/M sets" ring.

// MARK: - Gym chip + header line

/// The live header's gym chip: a 36 pt capsule with a 44 pt hit area.
struct GymChip: View {
    var name: String
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36

    init(_ name: String, action: @escaping () -> Void = {}) {
        self.name = name
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: look.gymSymbol)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                Text(name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .frame(minHeight: height)
            .background(look.chipFill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(look.id.isPaperClub ? look.outline : look.hairline,
                                       lineWidth: look.id.isPaperClub ? 1.5 : 1)
            }
            // 44 pt hit area without taking layout space.
            .padding(.vertical, hitOutset)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .padding(.vertical, -hitOutset)
    }

    private var hitOutset: CGFloat { max(0, (44 - height) / 2) }
}

struct LiveHeaderLine: View {
    var gym: String?
    /// Elapsed seconds; shown as "18:42" / "1:02:03".
    var elapsed: Int
    var done: Int
    var total: Int
    var onGym: () -> Void = {}
    @Environment(\.look) private var look

    init(gym: String?, elapsed: Int, done: Int, total: Int, onGym: @escaping () -> Void = {}) {
        self.gym = gym
        self.elapsed = elapsed
        self.done = done
        self.total = total
        self.onGym = onGym
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                if let gym { GymChip(gym, action: onGym).fixedSize() }
                clock.fixedSize()
                Spacer(minLength: 4)
                SetsRingLabel(done: done, total: total).fixedSize()
            }
            // Two lines. A: gym chip, then clock + ring (A SPEC §9); B/C: clock + ring, then chip.
            VStack(alignment: .leading, spacing: 8) {
                if look.id == .floodlight, let gym { GymChip(gym, action: onGym) }
                HStack {
                    clock
                    Spacer(minLength: 8)
                    SetsRingLabel(done: done, total: total)
                }
                if look.id != .floodlight, let gym { GymChip(gym, action: onGym) }
            }
        }
    }

    private var clock: some View {
        Text(LookFormat.elapsed(elapsed))
            .font(look.font.timer)
            .foregroundStyle(look.textPrimary)
            .contentTransition(.numericText(countsDown: false))
            .lineLimit(1)
            .accessibilityLabel(LookFormat.spokenElapsed(elapsed))
    }
}

// MARK: - Vitals strip

/// Heart rate · Active calories · Total volume in one strip. Missing facts are absent, never 0.
struct VitalsStrip: View {
    var hr: Int?
    var zone: HeartRateZone?
    /// The feed is stale: the heart stops and greys out.
    var isStale = false
    var activeCal: Int?
    /// Volume so far, in `unit`.
    var volume: Double
    var unit: WeightUnit = .lb
    var onHeartRate: () -> Void = {}

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(hr: Int?, zone: HeartRateZone?, isStale: Bool = false, activeCal: Int?,
         volume: Double, unit: WeightUnit = .lb, onHeartRate: @escaping () -> Void = {}) {
        self.hr = hr
        self.zone = zone
        self.isStale = isStale
        self.activeCal = activeCal
        self.volume = volume
        self.unit = unit
        self.onHeartRate = onHeartRate
    }

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            if let hr {
                Button(action: onHeartRate) { heartCell(hr) }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LookDivider(vertical: !stacked)
            }
            if let activeCal {
                cell(value: { Text("\(activeCal)") }, unit: "cal", label: "Active calories")
                LookDivider(vertical: !stacked)
            }
            cell(value: {
                // A and B count the volume up; C also bumps it (1.25×).
                CountUpText(volume, countsFromZero: false) { LookFormat.grouped($0) }
                    .celebrate(look.id.isPaperClub ? volume : 0)
            }, unit: unit.label, label: "Total volume")
        }
        .fixedSize(horizontal: false, vertical: true)
        .lookSurface(.stat, radius: 16)
    }

    private func heartCell(_ hr: Int) -> some View {
        let valueColor: Color = isStale ? look.textTertiary : (look.id.isPaperClub ? look.textPrimary : look.heartRate)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                BeatingHeart(bpm: hr, isFresh: !isStale, font: .system(.footnote, weight: .bold))
                Text("\(hr)").font(vitalsFont).foregroundStyle(valueColor)
                    .contentTransition(.numericText(value: Double(hr)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("bpm").font(unitFont).foregroundStyle(look.textSecondary)
            }
            HStack(spacing: 6) {
                ZoneMeter(zone: isStale ? nil : zone)
                zoneText(zone?.label ?? "Set up zones")
            }
        }
        .padding(.horizontal, look.id.isPaperClub ? 12 : 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate \(hr) beats per minute\(zone.map { ", \($0.label)" } ?? "")\(isStale ? ", not current" : "")")
    }

    private func zoneText(_ text: String) -> some View {
        Text(text)
            .font(look.id.isPaperClub ? .system(.caption, weight: .bold) : .system(.footnote, weight: .regular))
            .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
            .lineLimit(1)
    }

    /// The wide Expanded face fits the three cells at Title 3.
    private var vitalsFont: Font { look.font.smallNumber }

    private var unitFont: Font {
        .system(.footnote, weight: .medium)
    }

    private func cell<V: View>(@ViewBuilder value: () -> V, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                value().font(vitalsFont).foregroundStyle(look.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text(unit).font(unitFont).foregroundStyle(look.textSecondary)
            }
            Text(label)
                .font(look.id.isPaperClub ? .system(.caption, weight: .semibold) : .system(.footnote, weight: .regular))
                .foregroundStyle(look.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, look.id.isPaperClub ? 12 : 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Five small steps; the steps up to the current zone light in the zone ramp (C: heart colour).
struct ZoneMeter: View {
    var zone: HeartRateZone?
    @Environment(\.look) private var look

    var body: some View {
        let level = zone?.rawValue ?? 0
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...5, id: \.self) { step in
                let lit = step <= level
                switch look.id {
                case .floodlight:
                    Capsule().fill(lit ? look.zoneRamp[step] : look.ringTrack).frame(width: 8, height: 4)
                case .paper, .carbon:
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(lit ? look.heartRate : look.textSecondary.opacity(0.25))
                        .frame(width: 5, height: 10)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - New best

/// A: outlined plate with a starburst (never a white fill — white means done).
/// B: a pearl pill with a star. C: a yellow highlighter sticker rotated −3°.
struct NewBestBadge: View {
    var kind: SetBadge = .newBest
    @Environment(\.look) private var look

    var body: some View {
        Group {
            switch look.id {
            case .floodlight:
                HStack(spacing: 4) {
                    if kind == .newBest { Image(systemName: "burst.fill").font(.system(.caption, weight: .bold)) }
                    Text(kind == .newBest ? "NEW BEST" : "FIRST TIME")
                        .font(look.font.badge)
                        .tracking(0.5)
                }
                .foregroundStyle(look.positive)
                .padding(.leading, 5).padding(.trailing, 7)
                .frame(minHeight: 20)
                .overlay {
                    RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous)
                        .strokeBorder(look.positive, style: StrokeStyle(lineWidth: 1.5, dash: kind == .newBest ? [] : [3, 2]))
                }
            case .paper, .carbon:
                Text(kind == .newBest ? "New best" : "First time")
                    .font(look.font.badge)
                    .foregroundStyle(look.onPositive)
                    .padding(.horizontal, 6).padding(.top, 1).padding(.bottom, 2)
                    .background(kind == .newBest ? look.positive : Color.white,
                                in: RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous)
                            .strokeBorder(look.onPositive, lineWidth: 1.5)
                    }
                    .rotationEffect(.degrees(-3))
            }
        }
        .fixedSize()
        .accessibilityLabel(kind == .newBest ? "New best" : "First time")
    }
}

// MARK: - Set row

extension Look {
    /// PREVIOUS column text. A keeps the unit next to the weight ("105 lb × 8");
    /// B and C drop it when it matches the row's unit ("105 × 8").
    func previousLabel(_ value: SetValue, rowUnit: WeightUnit, loadType: LoadType = .weighted) -> String {
        if id == .floodlight || value.unit != rowUnit { return LookFormat.set(value, loadType: loadType) }
        return LookFormat.setShort(value, loadType: loadType)
    }
}

/// Column geometry shared by SetRowView and SetColumnHeader so they always align.
/// Widths grow with Dynamic Type up to 1.25× (beyond that the row switches to two lines).
struct SetGridMetrics {
    var marker: CGFloat
    var markerSide: CGFloat
    var weight: CGFloat
    var reps: CGFloat
    var spacing: CGFloat

    static func make(_ look: Look, scale: CGFloat) -> SetGridMetrics {
        let k = min(max(scale, 0.85), 1.25)
        switch look.id {
        case .floodlight: return SetGridMetrics(marker: 34 * k, markerSide: 34 * k, weight: 76 * k, reps: 50 * k, spacing: 6)
        case .paper, .carbon: return SetGridMetrics(marker: 40 * k, markerSide: 34 * k, weight: 92 * k, reps: 56 * k, spacing: 8)
        }
    }
}

/// One set row in any state: warmup / working / failure / drop; done, prefilled draft,
/// typed, empty; next-up. The completion effect is each look's signature:
/// A stamp (+ double strobe on a new best), B pop + ripple + row flash, C stamp + ripple + unbox.
///
/// Prefer the typed initializer (`last:` + `loadType:`): it formats PREVIOUS per look
/// (A "105 lb × 8", B/C "105 × 8"). The string initializer is for pre-formatted special cases.
struct SetRowView: View {
    var kind: SetType
    /// Working-set number shown in the marker (ignored for W / F / D).
    var number: Int
    var previous: String?
    var weight: String?
    var unit: WeightUnit
    var reps: String?
    var state: LiveSetState
    /// The next set to do.
    var isNextUp = false
    /// Rest is running (A: Ultra stays on the rest bar, not on the next check).
    var isResting = false
    var badge: SetBadge?
    var weightColumnTitle = "WEIGHT"
    var onCheck: () -> Void = {}
    var onWeight: () -> Void = {}
    var onReps: () -> Void = {}
    var onUnit: () -> Void = {}

    @State private var stamp = 0
    @State private var strobe = 0
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var gridScale: CGFloat = 1

    /// Pre-formatted values (PREVIOUS, weight and reps exactly as given).
    init(kind: SetType, number: Int, previous: String?, weight: String?, unit: WeightUnit, reps: String?,
         state: LiveSetState, isNextUp: Bool = false, isResting: Bool = false, badge: SetBadge? = nil,
         weightColumnTitle: String = "WEIGHT",
         onCheck: @escaping () -> Void = {}, onWeight: @escaping () -> Void = {},
         onReps: @escaping () -> Void = {}, onUnit: @escaping () -> Void = {}) {
        self.kind = kind
        self.number = number
        self.previous = previous
        self.weight = weight
        self.unit = unit
        self.reps = reps
        self.state = state
        self.isNextUp = isNextUp
        self.isResting = isResting
        self.badge = badge
        self.weightColumnTitle = weightColumnTitle
        self.onCheck = onCheck
        self.onWeight = onWeight
        self.onReps = onReps
        self.onUnit = onUnit
    }

    /// Typed values: `last` is last time's set (formatted per look with `look.previousLabel`),
    /// `weight` / `reps` are the row's field values (nil = empty field).
    init(kind: SetType, number: Int, last: SetValue?, loadType: LoadType = .weighted, weight: Double?,
         unit: WeightUnit, reps: Int?, state: LiveSetState, isNextUp: Bool = false, isResting: Bool = false,
         badge: SetBadge? = nil, weightColumnTitle: String = "WEIGHT",
         onCheck: @escaping () -> Void = {}, onWeight: @escaping () -> Void = {},
         onReps: @escaping () -> Void = {}, onUnit: @escaping () -> Void = {}) {
        self.init(kind: kind, number: number, previous: nil, weight: weight.map { LookFormat.weight($0) }, unit: unit,
                  reps: reps.map { "\($0)" }, state: state, isNextUp: isNextUp, isResting: isResting, badge: badge,
                  weightColumnTitle: weightColumnTitle, onCheck: onCheck, onWeight: onWeight, onReps: onReps,
                  onUnit: onUnit)
        self.last = last
        self.loadType = loadType
    }

    private var last: SetValue?
    private var loadType: LoadType = .weighted

    private var previousText: String? {
        if let last { return look.previousLabel(last, rowUnit: unit, loadType: loadType) }
        return previous
    }

    private var done: Bool { state == .completed }
    private var metrics: SetGridMetrics { .make(look, scale: gridScale) }

    var body: some View {
        rowContent
            .background { rowFlash }
            .onChange(of: done) { _, isDone in didChangeDone(isDone) }
            .onChange(of: badge) { _, newBadge in didChangeBadge(newBadge) }
            .sensoryFeedback(.impact(weight: .medium), trigger: stamp)
            .sensoryFeedback(.success, trigger: badge, condition: Self.isNewBestArrival)
    }

    @ViewBuilder private var rowContent: some View {
        if typeSize.isAccessibilitySize { twoLine } else { oneLine }
    }

    private func didChangeDone(_ isDone: Bool) {
        guard isDone else { return }
        stamp += 1
        if badge == SetBadge.newBest { strobe += 1 }
    }

    private func didChangeBadge(_ newBadge: SetBadge?) {
        let isBest: Bool = newBadge == SetBadge.newBest
        if isBest && look.id == LookStyle.floodlight { strobe += 1 }
    }

    private static func isNewBestArrival(_ old: SetBadge?, _ new: SetBadge?) -> Bool {
        old == nil && new == SetBadge.newBest
    }

    private var oneLine: some View {
        let m = metrics
        return HStack(spacing: m.spacing) {
            SetMarker(kind: kind, number: number, done: done, isNextUp: isNextUp, side: m.markerSide)
                .frame(width: m.marker)
            previousColumn.frame(maxWidth: .infinity, alignment: .leading)
            field(weight, unit: unit.label, spoken: "Weight", action: onWeight, unitAction: onUnit).frame(width: m.weight)
            field(reps, unit: nil, spoken: "Reps", action: onReps, unitAction: nil).frame(width: m.reps)
            checkButton
        }
        .frame(minHeight: 48)
    }

    private var twoLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SetMarker(kind: kind, number: number, done: done, isNextUp: isNextUp)
                previousColumn
                Spacer(minLength: 4)
                checkButton
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weightColumnTitle).font(look.font.columnHeader).tracking(look.columnTracking).foregroundStyle(look.textSecondary)
                    field(weight, unit: unit.label, spoken: "Weight", action: onWeight, unitAction: onUnit)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("REPS").font(look.font.columnHeader).tracking(look.columnTracking).foregroundStyle(look.textSecondary)
                    field(reps, unit: nil, spoken: "Reps", action: onReps, unitAction: nil)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private var previousColumn: some View {
        let text = Text(previousText ?? "—")
            .font(look.id.isPaperClub ? .system(.subheadline) : look.font.footnote)
            .monospacedDigit()
            .foregroundStyle(look.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        VStack(alignment: .leading, spacing: 3) {
            text
            if let badge { NewBestBadge(kind: badge).transition(badgeTransition) }
        }
    }

    private var badgeTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 1.5).combined(with: .opacity)
    }

    // MARK: Fields

    private var fieldStyle: SetFieldBackground.Style {
        switch state {
        case .completed: .done
        case .prefilled: .draft
        case .typed: .typed
        case .empty: .empty
        }
    }

    /// A 40 pt field box with a 44 pt hit area. Tapping the box edits; tapping the unit suffix
    /// toggles the unit (its own button, full row height, reaching into the column gap).
    private func field(_ value: String?, unit: String?, spoken: String, action: @escaping () -> Void,
                       unitAction: (() -> Void)?) -> some View {
        let dim = kind == .warmup && done && look.id == .floodlight
        let valueFont = look.id == .floodlight ? Font.system(.title3, weight: .heavy).width(.expanded).monospacedDigit() : look.font.fieldNumber
        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value ?? "—")
                .font(valueFont)
                .foregroundStyle(value == nil ? look.textSecondary : (dim ? look.textSecondary : look.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let unit, value != nil {
                UnitSuffixButton(unit: unit, color: look.unit(self.unit), enabled: !done && unitAction != nil) {
                    unitAction?()
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background { fieldBackground.padding(.vertical, 2) }
        .contentShape(Rectangle())
        .onTapGesture { if !done { action() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityValue([value, value == nil ? nil : unit].compactMap { $0 }.joined(separator: " "))
        .accessibilityAddTraits(done ? [] : .isButton)
        .accessibilityAction { if !done { action() } }
        .accessibilityActions {
            if let unitAction, unit != nil, !done { Button("Switch unit", action: unitAction) }
        }
    }

    private var fieldBackground: some View {
        SetFieldBackground(style: fieldStyle, stamp: stamp)
    }

    // MARK: Check

    private var checkButton: some View {
        Button(action: onCheck) {
            SetCheck(done: done, warmup: kind == .warmup, isNextUp: isNextUp, isResting: isResting, stamp: stamp)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(done ? "Completed" : "Complete set")
    }

    // MARK: Row flash

    @ViewBuilder private var rowFlash: some View {
        if !reduceMotion && !look.id.isPaperClub {
            let color = look.id == .floodlight ? look.done : look.textPrimary
            RoundedRectangle(cornerRadius: look.radius.row, style: .continuous)
                .fill(color)
                .padding(.horizontal, -6)
                .keyframeAnimator(initialValue: 0.0, trigger: strobe) { view, opacity in
                    view.opacity(opacity)
                } keyframes: { _ in
                    KeyframeTrack {
                        if look.id == .floodlight {
                            // Double strobe for a new best (900 ms).
                            LinearKeyframe(0.34, duration: 0.16)
                            LinearKeyframe(0, duration: 0.16)
                            LinearKeyframe(0.22, duration: 0.16)
                            LinearKeyframe(0, duration: 0.42)
                        } else {
                            MoveKeyframe(0.12)
                            LinearKeyframe(0, duration: 1.0)
                        }
                    }
                }
        }
    }
}

/// A set field's box: Floodlight a filled well; the live workout's pencil→ink box — dashed while
/// a draft (empty or carried forward), a soft rule once typed, and dissolving ("unboxing") as
/// the values stand inked when the set completes. `stamp` increments on completion.
struct SetFieldBackground: View {
    enum Style { case done, draft, typed, empty }
    var style: Style
    var stamp: Int
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
        switch (look.id, style) {
        case (.floodlight, .done):
            shape.fill(look.wash(0.045))
        case (.floodlight, _):
            shape.fill(look.field).overlay { shape.strokeBorder(look.textPrimary.opacity(0.45), lineWidth: 1) }
        case (_, .done):
            shape.fill(look.field).opacity(0).overlay { unboxing(shape) }
        case (_, .typed):
            shape.fill(look.field).overlay { shape.strokeBorder(look.hairline, lineWidth: 1.5) }
        case (_, _):
            shape.fill(look.field).overlay { shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
        }
    }

    @ViewBuilder private func unboxing(_ shape: RoundedRectangle) -> some View {
        if reduceMotion {
            Color.clear
        } else {
            shape.fill(look.field)
                .overlay { shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
                .keyframeAnimator(initialValue: 0.0, trigger: stamp) { view, opacity in
                    view.opacity(opacity)
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(1.0)
                        LinearKeyframe(0.0, duration: 0.45)
                    }
                }
        }
    }
}

/// The weight field's unit suffix ("lb"): its own button so a tap toggles the unit without
/// editing. The hit area is the full field height and reaches right into the column gap;
/// it takes no extra layout space.
private struct UnitSuffixButton: View {
    var unit: String
    var color: Color
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(unit)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(color)
                .padding(.leading, 4).padding(.trailing, 16).padding(.vertical, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, -4).padding(.trailing, -16).padding(.vertical, -16)
        .allowsHitTesting(enabled)
    }
}

/// The set marker column. `side` fixes the box (SetRowView passes its column size);
/// nil scales with Dynamic Type (two-line rows, standalone use).
struct SetMarker: View {
    var kind: SetType
    var number: Int
    var done: Bool
    var isNextUp = false
    var side: CGFloat?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    init(kind: SetType, number: Int, done: Bool, isNextUp: Bool = false, side: CGFloat? = nil) {
        self.kind = kind
        self.number = number
        self.done = done
        self.isNextUp = isNextUp
        self.side = side
    }

    private var label: String { kind.marker ?? "\(number)" }
    private var box: CGFloat { side ?? 34 * scale }

    var body: some View {
        switch look.id {
        case .floodlight: floodlight
        case .paper, .carbon: paperClub
        }
    }

    private var numberFont: Font { Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit() }

    private var floodlight: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.marker, style: .continuous)
        return Text(label)
            .font(kind == .warmup ? Font.system(.footnote, weight: .heavy).width(.expanded) : numberFont)
            .foregroundStyle(kind == .warmup ? look.textSecondary : (done ? look.onDone : look.textPrimary))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: box, height: box)
            .background {
                if done && kind != .warmup { shape.fill(look.done) }
            }
            .overlay {
                if kind == .warmup {
                    shape.strokeBorder(look.warmupMarker, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                } else if !done {
                    shape.strokeBorder(look.textPrimary.opacity(0.42), lineWidth: 1.5)
                }
            }
            .animation(.easeOut(duration: 0.25), value: done)
    }

    @ViewBuilder private var paperClub: some View {
        let size = box
        let fg: Color = done || kind == .warmup ? look.onDone : (isNextUp ? look.actionText : look.textSecondary)
        let text = Text(label).font(numberFont).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.6)
        switch kind {
        case .failure:
            text.frame(width: size, height: size)
                .background { if done { Octagon().fill(look.done) } }
                .overlay { if !done { Octagon().stroke(isNextUp ? look.actionText : look.textSecondary, lineWidth: isNextUp ? 2 : 1.5) } }
        case .drop:
            text.padding(.bottom, 4).frame(width: size, height: size)
                .background { if done { DropTag().fill(look.done) } }
                .overlay { if !done { DropTag().stroke(isNextUp ? look.actionText : look.textSecondary, lineWidth: isNextUp ? 2 : 1.5) } }
        case .warmup:
            text.frame(width: size, height: size).background(look.warmupMarker, in: Circle())
        case .working:
            text.frame(width: size, height: size)
                .background {
                    if done { Circle().fill(look.done) } else if isNextUp { Circle().fill(look.surface) }
                }
                .overlay {
                    if !done {
                        Circle().strokeBorder(isNextUp ? look.actionText : look.textSecondary, lineWidth: isNextUp ? 2 : 1.5)
                    }
                }
        }
    }
}

/// C failure marker: an octagon.
struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let c = min(rect.width, rect.height) * 0.29
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.closeSubpath()
        return p
    }
}

/// C drop marker: a downward tag.
struct DropTag: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width * 0.18
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.66))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.66))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// The check control with the look's set-complete effect. `stamp` increments on completion.
struct SetCheck: View {
    var done: Bool
    var warmup: Bool
    var isNextUp: Bool
    var isResting: Bool
    var stamp: Int
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ripple
            face.modifier(StampIn(trigger: stamp, look: look, enabled: !reduceMotion))
        }
    }

    @ViewBuilder private var face: some View {
        switch look.id {
        case .floodlight:
            let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
            let now = isNextUp && !isResting
            if done {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(look.onDone)
                    .frame(width: 34, height: 34)
                    .background(warmup ? look.textSecondary : look.done, in: shape)
            } else {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(now ? look.action : look.textPrimary.opacity(0.62))
                    .frame(width: 34, height: 34)
                    .overlay { shape.strokeBorder(now ? look.action : look.textPrimary.opacity(0.42), lineWidth: 2) }
                    .animation(.easeInOut(duration: 0.3), value: now)
            }
        case .paper, .carbon:
            if done {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(look.onDone)
                    .frame(width: 34, height: 34)
                    .background(look.done, in: Circle())
            } else if isNextUp {
                Circle().fill(look.surface)
                    .overlay { Circle().strokeBorder(look.actionText, lineWidth: 2.5) }
                    .frame(width: 34, height: 34)
            } else {
                Circle().strokeBorder(look.textSecondary, lineWidth: 2).frame(width: 34, height: 34)
            }
        }
    }

    /// The live workout: an ink ripple. Floodlight stamps without one.
    @ViewBuilder private var ripple: some View {
        if !reduceMotion && look.id != .floodlight {
            Circle()
                .strokeBorder(look.textPrimary, lineWidth: 3)
                .frame(width: 34, height: 34)
                .keyframeAnimator(initialValue: RippleValue(), trigger: stamp) { view, value in
                    view.scaleEffect(value.scale).opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(0.8)
                        CubicKeyframe(1.9, duration: 0.55)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0.8)
                        LinearKeyframe(0, duration: 0.55)
                    }
                }
        }
    }
}

private struct RippleValue {
    var scale: CGFloat = 1
    var opacity: Double = 0
}

/// The stamp: Floodlight drops in from 1.55× at −14°, the live workout from 1.7× at −16°.
private struct StampIn: ViewModifier {
    var trigger: Int
    var look: Look
    var enabled: Bool

    struct Value {
        var scale: CGFloat = 1
        var rotation: Double = 0
    }

    private var from: CGFloat { look.motion.stampScale }
    private var overshoot: CGFloat { 0.9 }
    private var first: Double { look.id == .floodlight ? 0.19 : 0.21 }
    private var settle: Double { 0.17 }

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: Value(), trigger: trigger) { view, value in
                view.scaleEffect(value.scale).rotationEffect(.degrees(value.rotation))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(from)
                    CubicKeyframe(overshoot, duration: first)
                    CubicKeyframe(1, duration: settle)
                }
                KeyframeTrack(\.rotation) {
                    MoveKeyframe(look.motion.stampRotation)
                    CubicKeyframe(look.motion.stampRotation == 0 ? 0 : 2.5, duration: first)
                    CubicKeyframe(0, duration: settle)
                }
            }
        } else {
            content
        }
    }
}

/// SET · PREVIOUS · WEIGHT · REPS header aligned to SetRowView's columns (hidden at AX sizes).
struct SetColumnHeader: View {
    var weightTitle = "WEIGHT"
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var gridScale: CGFloat = 1

    init(weightTitle: String = "WEIGHT") {
        self.weightTitle = weightTitle
    }

    var body: some View {
        if !typeSize.isAccessibilitySize {
            let m = SetGridMetrics.make(look, scale: gridScale)
            HStack(spacing: m.spacing) {
                header("SET").frame(width: m.marker)
                header("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
                header(weightTitle).frame(width: m.weight)
                header("REPS").frame(width: m.reps)
                Color.clear.frame(width: 44, height: 1)
            }
            .accessibilityHidden(true)
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(look.font.columnHeader)
            .tracking(look.columnTracking)
            .foregroundStyle(look.id.isPaperClub ? look.textSecondary : look.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Rest bar

/// The pinned rest bar: draining ring with hourglass, "Rest" over the time, the next set, +15s, Skip.
/// A: glass bar, Ultra ring and Skip, a floodlight beat in the final 10 s.
/// B: Liquid Glass bar (tinted graphite), pearl ring and Skip. C: an inverse ink slab,
/// light-cobalt ring, 48 pt buttons. Build `next` with `look.nextSetLabel(…)` /
/// `look.nextExerciseLabel(…)` so the unit rule stays per look.
/// AX sizes: two rows (ring + time, then equal +15s / Skip). A moves the Next line to
/// VoiceOver only; B and C keep it, wrapping.
struct RestBar: View {
    var remaining: Int
    var total: Int
    var next: String?
    var onAdd15: () -> Void = {}
    var onSkip: () -> Void = {}
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(remaining: Int, total: Int, next: String?, onAdd15: @escaping () -> Void = {}, onSkip: @escaping () -> Void = {}) {
        self.remaining = remaining
        self.total = total
        self.next = next
        self.onAdd15 = onAdd15
        self.onSkip = onSkip
    }

    /// Rises 24–28 pt with a fade; Reduce Motion: appears in place.
    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .offset(y: 26).combined(with: .opacity)
    }

    private var progress: Double { total > 0 ? Double(remaining) / Double(total) : 0 }
    private var isFinal: Bool { remaining <= 10 && remaining > 0 }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) { ring; timeBlock(showNext: look.id != .floodlight) }
                    HStack(spacing: 10) { add15.frame(maxWidth: .infinity); skip.frame(maxWidth: .infinity) }
                }
                .padding(14)
            } else {
                HStack(spacing: 10) {
                    ring
                    timeBlock(showNext: true)
                    Spacer(minLength: 0)
                    add15
                    skip
                }
                .padding(.leading, 12).padding(.trailing, look.id.isPaperClub ? 14 : 12)
                .frame(minHeight: look.id.isPaperClub ? 96 : 84)
            }
        }
        .environment(\.lookOnSlab, look.id.isPaperClub)
        .background { barBackground }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rest, \(LookFormat.duration(remaining)) left" + (next.map { ". \($0)" } ?? ""))
    }

    private var ring: some View {
        RestRing(progress: progress, isFinal: isFinal, size: look.id.isPaperClub ? 58 : 56)
    }

    private func timeBlock(showNext: Bool) -> some View {
        let secondary = look.id.isPaperClub ? look.onSlabSecondary : look.textSecondary
        return VStack(alignment: .leading, spacing: 0) {
            Text("Rest")
                .font(look.id.isPaperClub ? .system(.caption, weight: .semibold) : .system(.footnote, weight: .regular))
                .foregroundStyle(secondary)
            Text(LookFormat.duration(remaining))
                .font(look.font.bigNumber)
                .foregroundStyle(look.id.isPaperClub ? look.onSlab : look.textPrimary)
                .contentTransition(.numericText(countsDown: true))
                .lineLimit(1)
            if showNext, let next {
                Text(next)
                    .font(look.id.isPaperClub ? .system(.caption, weight: .semibold) : look.font.footnote)
                    .foregroundStyle(secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    .truncationMode(.tail)
            }
        }
        .layoutPriority(1)
    }

    private var add15: some View {
        Button("+15s", action: onAdd15).buttonStyle(PillButtonStyle())
    }
    private var skip: some View {
        Button("Skip", action: onSkip).buttonStyle(PillButtonStyle(prominent: true))
    }

    @ViewBuilder private var barBackground: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous)
        switch look.id {
        case .floodlight:
            shape.fill(look.slab)
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1) }
                .shadow(color: look.floatShadow(0.6), radius: 20, x: 0, y: 16)
        case .paper, .carbon:
            shape.fill(look.slab)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1.5) }
        }
    }
}

// MARK: - Exercise card header

/// An exercise card's title line: the name (wraps, never truncates), an optional caption
/// (B's "Target: 3 sets · 10, 8, 8 reps"), and the previous-performance and options buttons.
/// The buttons are centred on the title block and take only their visual size, so the
/// equipment row follows at the mockups' rhythm. AX sizes: A and C keep the buttons beside
/// the first line (top-aligned); B drops them to their own trailing line.
struct ExerciseCardHeader: View {
    var title: String
    var subtitle: String?
    var onPrevious: () -> Void = {}
    var onOptions: () -> Void = {}
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: String, subtitle: String? = nil, onPrevious: @escaping () -> Void = {},
         onOptions: @escaping () -> Void = {}) {
        self.title = title
        self.subtitle = subtitle
        self.onPrevious = onPrevious
        self.onOptions = onOptions
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: 10) {
                titleBlock.frame(maxWidth: .infinity, alignment: .leading)
                buttons.padding(.top, 4)
            }
        } else {
            HStack(alignment: .center, spacing: 10) {
                titleBlock.frame(maxWidth: .infinity, alignment: .leading)
                buttons
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(look.font.cardTitle)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: look.id.isPaperClub ? 10 : 12) {
            CardIconButton(look.previousPerformanceSymbol, accessibilityLabel: "Previous performance", action: onPrevious)
            CardIconButton("ellipsis", accessibilityLabel: "Options", action: onOptions)
        }
    }
}

// MARK: - Equipment row

/// The machine / equipment row inside an exercise card. `symbol` defaults to the machine
/// (weight-stack) glyph; pass an SF Symbol such as "dumbbell" for free-weight equipment.
struct EquipmentRow: View {
    var title: String
    var subtitle: String?
    var symbol: String = LookIcon.machine
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    init(title: String, subtitle: String? = nil, symbol: String = LookIcon.machine, action: @escaping () -> Void = {}) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LookIcon(symbol, style: .body)
                    .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                    .frame(width: glyphColumn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(look.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(look.id.isPaperClub ? look.font.caption : look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
            }
            .padding(.horizontal, look.id.isPaperClub ? 12 : 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: look.id.isPaperClub ? 54 : 52, alignment: .leading)
            .lookSurface(.raised)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }

    private var titleFont: Font {
        switch look.id {
        case .floodlight: .system(.body, weight: .semibold)
        case .paper, .carbon: .system(.subheadline, weight: .bold)
        }
    }
}

/// "+ Add Set": a deliberate dashed row (rows are never auto-added).
struct AddSetRow: View {
    var action: () -> Void = {}
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(.subheadline, weight: .semibold))
                Text("Add Set").font(.system(.subheadline, weight: .semibold))
            }
            .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.wash(look.isDark ? 0.17 : 0.24),
                           radius: look.radius.row, lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [5, 4])
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }
}
