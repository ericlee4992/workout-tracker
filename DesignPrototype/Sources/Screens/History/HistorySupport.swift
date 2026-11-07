import SwiftUI
import UIKit

// History area helpers: grouping, formatting, fonts and small behaviours the Store and Look
// do not provide. Everything is History-prefixed (see native-contract.md). Candidates for the
// integrator to promote: `Store.historyMonthSections()`, `Store.historyDaySignals`,
// `HistoryFormat`, `HistorySwipeRow`, `HistoryCaptureVariant`, `Store.historyHRSlots`.

// MARK: - Fonts (per-look faces, all Dynamic Type text styles)

extension Look {
    /// Workout row titles: A expanded heavy, B rounded bold, C New York heavy (Headline class).
    var historyRowTitle: Font {
        switch id {
        case .floodlight: Font.system(.headline, weight: .heavy).width(.expanded)
        case .anatomy: .system(.headline, design: .rounded, weight: .bold)
        case .paper, .carbon: .system(.headline, design: .serif, weight: .heavy)
        }
    }

    /// The day number in a row's date column.
    var historyDayNumber: Font {
        switch id {
        case .anatomy: .system(.title3, design: .rounded, weight: .heavy).monospacedDigit()
        default: Font.system(.title3, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }

    /// A figure that sits in a row (volume, distance): Headline class, the look's number face.
    var historyRowNumber: Font {
        switch id {
        case .anatomy: .system(.headline, design: .rounded, weight: .heavy).monospacedDigit()
        default: Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }

    /// Small labels under figures ("lb", "Workouts").
    var historyFigureLabel: Font {
        .system(.footnote, design: id == .anatomy ? .rounded : .default, weight: id == .floodlight ? .regular : .semibold)
    }

    /// The surface colour a card sits on (for knock-out strokes).
    func historyCardFill(onSheet: Bool) -> Color { onSheet ? surfaceSheet : surface }

    /// The colour a finished route is drawn in: A floodlight (lit), B heart rate (cardio is
    /// B's red screen), C ink.
    var historyRouteColor: Color {
        switch id {
        case .floodlight: done
        case .anatomy: heartRate
        case .paper, .carbon: textPrimary
        }
    }
}

// MARK: - Formatting

enum HistoryFormat {
    private static func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Format.locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
    private static let weekdayShortF = formatter("EEE")
    private static let dayF = formatter("d")
    private static let monthShortF = formatter("MMM")
    private static let editedF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Format.locale
        f.timeZone = Calendar.app.timeZone
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// "Mon"
    static func weekdayShort(_ date: Date) -> String { weekdayShortF.string(from: date) }
    /// "21"
    static func dayNumber(_ date: Date) -> String { dayF.string(from: date) }
    /// "SEP" (C's stamp)
    static func monthShort(_ date: Date) -> String { monthShortF.string(from: date) }
    /// "Monday, Sep 21"
    static func dayTitle(_ date: Date) -> String { "\(Format.weekday(date)), \(Format.shortDate(date))" }
    /// "10:30 AM – 11:37 AM"
    static func timeRange(_ start: Date, _ end: Date) -> String { "\(Format.time(start)) – \(Format.time(end))" }
    /// The existing mark: "Edited Sep 20, 2026 at 8:40 AM".
    static func edited(_ date: Date) -> String { "Edited \(editedF.string(from: date))" }

    /// "This week", "Last week", "Sep 7 – 13", "Aug 31 – Sep 6".
    static func weekTitle(start: Date, now: Date) -> String {
        let cal = Calendar.app
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        if start == thisWeek { return "This week" }
        if let last = cal.date(byAdding: .day, value: -7, to: thisWeek), start == last { return "Last week" }
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        if cal.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(Format.shortDate(start)) – \(dayNumber(end))"
        }
        return "\(Format.shortDate(start)) – \(Format.shortDate(end))"
    }

    /// "9 workouts", "1 workout"
    static func workouts(_ n: Int) -> String { Format.count(n, "workout") }

    /// "7.9" (the number of `Format.hours`, for a big figure with a small "h").
    static func hoursNumber(_ hours: Double) -> String {
        Format.hours(hours).replacingOccurrences(of: " h", with: "")
    }

    /// Pace "8:59" or speed "18.4" for a segment, with its unit suffix.
    static func paceOrSpeed(_ segment: CardioSegment) -> (value: String, unit: String, label: String)? {
        if segment.activity.usesSpeed {
            guard let speed = segment.speedPerHour else { return nil }
            return (Format.number((speed * 10).rounded() / 10), "\(segment.unit.label)/h", "Average speed")
        }
        guard let pace = segment.paceSecondsPerUnit else { return nil }
        return (Format.pace(pace), "/\(segment.unit.label)", "Average pace")
    }

    /// Where a distance came from, for VoiceOver only (", entered distance" / ", GPS").
    static func distanceSource(_ segment: CardioSegment) -> String {
        if segment.manualDistance != nil { return ", entered distance" }
        return segment.activity.isOutdoor ? ", GPS" : ""
    }

    /// The whole workout's distance (all segments), in the first segment's unit.
    static func distance(_ workout: Workout) -> (meters: Double, unit: DistanceUnit)? {
        let segments = workout.cardio.filter { $0.distanceMeters != nil }
        guard let first = segments.first else { return nil }
        return (segments.reduce(0) { $0 + ($1.distanceMeters ?? 0) }, first.unit)
    }
}

// MARK: - Grouping (month → week → workouts)

struct HistoryWeekSection: Identifiable, Hashable {
    var id: Date { start }
    var start: Date
    var title: String
    /// Newest first.
    var workouts: [Workout]
    var minutes: Int { workouts.reduce(0) { $0 + $1.durationSeconds } / 60 }
}

struct HistoryMonthSection: Identifiable, Hashable {
    var id: Date { month }
    var month: Date
    var weeks: [HistoryWeekSection]
}

/// What happened on one calendar day, for the heat strip and the calendar cells.
struct HistoryDaySignal: Hashable {
    /// Working sets per family that day, head to toe.
    var families: [FamilyCount]
    var hasCardio: Bool
    var hasLifting: Bool
}

extension Store {
    /// History newest first, grouped by month (of a week's newest workout) and week (Mon–Sun).
    func historyMonthSections() -> [HistoryMonthSection] {
        let cal = Calendar.app
        var order: [Date] = []
        var byWeek: [Date: [Workout]] = [:]
        for workout in history {
            let start = cal.dateInterval(of: .weekOfYear, for: workout.startedAt)?.start ?? workout.startedAt
            if byWeek[start] == nil { order.append(start) }
            byWeek[start, default: []].append(workout)
        }
        var months: [HistoryMonthSection] = []
        for start in order {
            guard let workouts = byWeek[start], let newest = workouts.first else { continue }
            let month = cal.dateInterval(of: .month, for: newest.startedAt)?.start ?? newest.startedAt
            let week = HistoryWeekSection(start: start, title: HistoryFormat.weekTitle(start: start, now: now),
                                          workouts: workouts)
            if months.last?.month == month {
                months[months.count - 1].weeks.append(week)
            } else {
                months.append(HistoryMonthSection(month: month, weeks: [week]))
            }
        }
        return months
    }

    /// Day → families trained (working sets) and cardio, for every day that has a workout.
    var historyDaySignals: [Date: HistoryDaySignal] {
        let cal = Calendar.app
        var result: [Date: HistoryDaySignal] = [:]
        for workout in workouts {
            let day = cal.startOfDay(for: workout.startedAt)
            var signal = result[day] ?? HistoryDaySignal(families: [], hasCardio: false, hasLifting: false)
            var counts = Dictionary(uniqueKeysWithValues: signal.families.map { ($0.family, $0.sets) })
            for entry in workout.entries {
                if let family = exercise(entry.exerciseID)?.family { counts[family, default: 0] += entry.countedSets.count }
            }
            signal.families = MuscleFamily.allCases.compactMap { f in counts[f].map { FamilyCount(family: f, sets: $0) } }
            signal.hasCardio = signal.hasCardio || workout.hasCardio
            signal.hasLifting = signal.hasLifting || workout.hasLifting
            result[day] = signal
        }
        return result
    }

    /// The finished workout's WORKING sets in order with their family, for the hero ring.
    /// Warmups stay out, so a finished ring is always fully lit (the Finish ring's rule).
    func historyRingSets(_ workout: Workout) -> [MuscleFamily?] {
        workout.entries.flatMap { entry in
            let family = exercise(entry.exerciseID)?.family
            return entry.countedSets.map { _ in family }
        }
    }

    /// Heart-rate bars for a workout's detail. Lifting sessions get one floating range bar
    /// per minute from a lightly smoothed series (Apple Fitness's strength chart), so efforts
    /// and rests read as a shape instead of a comb of full-height spikes; the minute where the
    /// recorded maximum happened still reaches it. Cardio-only sessions keep the Store's bars.
    func historyHRSlots(_ workout: Workout) -> [HRSlot] {
        guard workout.hasLifting, let summary = workout.heartRate, let series = summary.series else {
            return hrSlots(workoutID: workout.id)
        }
        return HistoryHeartRate.minuteSlots(series, durationSeconds: workout.durationSeconds, peak: summary.maximum)
    }

    /// Rep bests (1–12) for one exercise variation, with the heaviest (or least-assisted) set per rep count.
    func historyRepBests(exerciseID: UUID, variation: ProgressVariation) -> [RepBest] {
        let dated: [(value: SetValue, date: Date)] = workouts.flatMap { w in
            w.entries.filter { $0.exerciseID == exerciseID && Derived.variationID(for: $0) == variation.id }
                .flatMap { entry in
                    entry.sets.filter { Records.isEligible(type: $0.type, value: $0.value, loadType: variation.loadType) }
                        .compactMap { set in set.value.map { (value: $0, date: w.startedAt) } }
                }
        }
        return Records.repBests(dated, loadType: variation.loadType)
    }
}

// MARK: - Heart rate per minute

enum HistoryHeartRate {
    /// One bar per minute. The bar is centred on the minute's average and spans a damped share
    /// of its swing (3–7 bpm each side), so a minute that holds both a set and its rest reads
    /// as a short floating range, and a 5-minute blend draws the work / rest wave (the Max
    /// tile keeps the recorded peak; the chart shows the shape).
    static func minuteSlots(_ series: HeartRateSeries, durationSeconds: Int, peak: Int?) -> [HRSlot] {
        let mean = series.mean
        let interval = max(1, series.intervalSeconds)
        let count = durationSeconds > 0
            ? min(mean.count, Int((Double(durationSeconds) / Double(interval)).rounded(.up))) : mean.count
        guard count > 0 else { return [] }
        let perSlot = max(1, 60 / interval)
        let slotCount = Int((Double(count) / Double(perSlot)).rounded(.up))
        // Minute averages and swings (the blend below joins them into a shape).
        var centres = [Double?](repeating: nil, count: slotCount)
        var swings = [Double](repeating: 0, count: slotCount)
        for slot in 0..<slotCount {
            let first = slot * perSlot, last = min(count, first + perSlot)
            let values = mean[first..<last].filter { $0 > 0 }.map(Double.init)
            guard let lo = values.min(), let hi = values.max() else { continue }   // a gap stays a gap
            centres[slot] = values.reduce(0, +) / Double(values.count)
            swings[slot] = hi - lo
        }
        var slots: [HRSlot] = []
        let weights: [Double] = [1, 2, 3, 2, 1]
        for slot in 0..<slotCount {
            guard centres[slot] != nil else { continue }
            // A 5-minute triangular blend: sets and rests read as a wave, not a zigzag comb.
            var sum = 0.0, weight = 0.0
            for (k, w) in weights.enumerated() {
                let i = slot + k - 2
                guard i >= 0, i < slotCount, let c = centres[i] else { continue }
                sum += c * w; weight += w
            }
            let blended = sum / weight
            let half = min(7, max(3, swings[slot] * 0.15))
            var low = Int((blended - half).rounded()), high = Int((blended + half).rounded())
            let first = slot * perSlot, last = min(count, first + perSlot)
            if let peak { high = min(high, peak); low = min(low, high - 1) }
            let end = durationSeconds > 0 ? min(last * interval, durationSeconds) : last * interval
            slots.append(HRSlot(index: slot, startSeconds: first * interval, endSeconds: end, low: low, high: high))
        }
        return slots
    }
}

// MARK: - Unit badge

extension Workout {
    /// The row/hero unit badge, only when it tells something: "kg + lb" when the workout mixes
    /// units (was "Mixed", which read as lifting + cardio), or the one entered unit when it is
    /// not the app's.
    func historyUnitBadge(appUnit: WeightUnit) -> String? {
        let units = Set(allSets.filter { $0.weight != nil }.map(\.unit))
        if units.count > 1 { return "kg + lb" }
        guard let only = units.first, only != appUnit else { return nil }
        return only.label
    }
}

// MARK: - Display unit (History detail: As entered / Show in kg / Show in lb, display only)

enum HistoryUnitMode: String, CaseIterable, Identifiable, Hashable {
    case asEntered, kg, lb
    var id: String { rawValue }
    var title: String {
        switch self {
        case .asEntered: "As entered"
        case .kg: "Show in kg"
        case .lb: "Show in lb"
        }
    }
    var unit: WeightUnit? {
        switch self {
        case .asEntered: nil
        case .kg: .kg
        case .lb: .lb
        }
    }

    /// The value to show: as entered, or converted plainly (D52). Converting drops the bar.
    func display(_ value: SetValue) -> SetValue {
        guard let target = unit, target != value.unit, let w = value.weight else { return value }
        let converted = (target.fromKg(value.unit.toKg(w)) * 10).rounded() / 10   // one decimal: 61.2 kg
        return SetValue(weight: converted, unit: target, reps: value.reps, bar: nil)
    }
}

// MARK: - Dynamic Type override inside sheets

/// The shell's AX capture override (`router.dynamicTypeOverride`) does not reach sheet content,
/// so History's sheets apply it themselves. No effect when the override is nil.
struct HistorySheetTypeOverride: ViewModifier {
    @Environment(Router.self) private var router
    func body(content: Content) -> some View {
        if let size = router.dynamicTypeOverride { content.dynamicTypeSize(size) } else { content }
    }
}

extension View {
    func historySheetTypeOverride() -> some View { modifier(HistorySheetTypeOverride()) }
}

// MARK: - Capture variants (-variant p2 / p3 / p4 / end, and demo states)

/// Reads the launch variant once, when the screen is the one the capture opened: hands it to
/// the screen (demo states such as "swipe" or "delete") and scrolls to the NAMED section the
/// screen maps it to, so every look and text size shows the same section side by side.
struct HistoryCaptureVariant: ViewModifier {
    var screen: ScreenID
    var matches: Bool = true
    /// A screen pushed by another capture (H01 "mixed" opens a workout) takes its variant
    /// from `HistoryCaptureHandoff` under this key.
    var handoffKey: UUID? = nil
    var anchor: (String) -> AnyHashable?
    var onVariant: (String) -> Void
    @Environment(Router.self) private var router
    @Environment(Store.self) private var store
    @State private var applied = false

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.onAppear {
                guard !applied else { return }
                let variant: String
                if let key = handoffKey, let handoff = HistoryCaptureHandoff.pending, handoff.key == key {
                    HistoryCaptureHandoff.pending = nil
                    variant = handoff.variant
                } else {
                    guard matches, store.currentScreen == screen, let v = router.variant else { return }
                    router.variant = nil
                    variant = v
                }
                applied = true
                onVariant(variant)
                let id: AnyHashable? = variant == "end" ? HistoryAnchor.bottom : anchor(variant)
                guard let id else { return }
                // Twice: a lazy list only knows its true height once the first jump has laid
                // out the rows it passed, so the second jump lands exactly.
                for delay in [0.35, 0.9] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        proxy.scrollTo(id, anchor: variant == "end" ? .bottom : .top)
                    }
                }
            }
        }
    }
}

/// A variant handed from one History screen to the one it pushes (captures only).
@MainActor
enum HistoryCaptureHandoff {
    static var pending: (key: UUID, variant: String)?
}

enum HistoryAnchor {
    /// A zero-height marker at the end of each long page ("end" variant).
    static let bottom = "history-bottom"
}

extension View {
    func historyCaptureVariant(_ screen: ScreenID, matches: Bool = true, handoffKey: UUID? = nil,
                               anchor: @escaping (String) -> AnyHashable? = { _ in nil },
                               onVariant: @escaping (String) -> Void = { _ in }) -> some View {
        modifier(HistoryCaptureVariant(screen: screen, matches: matches, handoffKey: handoffKey,
                                       anchor: anchor, onVariant: onVariant))
    }

    /// Shows an inline nav title once the page's own title has scrolled away.
    func historyInlineTitle(_ title: String, after threshold: CGFloat = 110) -> some View {
        modifier(HistoryInlineTitle(title: title, threshold: threshold, trailing: EmptyView(), hasTrailing: false))
    }

    /// The same, with trailing toolbar items in the SAME toolbar (two `.toolbar` modifiers on
    /// one screen made the first render take seconds).
    func historyInlineTitle<Trailing: View>(_ title: String, after threshold: CGFloat = 110,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(HistoryInlineTitle(title: title, threshold: threshold, trailing: trailing(), hasTrailing: true))
    }
}

private struct HistoryInlineTitle<Trailing: View>: ViewModifier {
    var title: String
    var threshold: CGFloat
    var trailing: Trailing
    var hasTrailing: Bool
    @State private var shows = false
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > threshold } action: { _, value in
                withAnimation(.easeInOut(duration: 0.2)) { shows = value }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .opacity(shows ? 1 : 0)
                        .accessibilityHidden(!shows)
                }
                if hasTrailing {
                    ToolbarItem(placement: .topBarTrailing) { trailing }
                }
            }
    }
}

// MARK: - Horizontal swipe (a pan that only starts sideways, so the page still scrolls)

struct HistoryHorizontalPan: UIGestureRecognizerRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed: onChanged(translation)
        case .ended, .cancelled, .failed: onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y) * 1.3
        }
        /// The page's scroll waits for this pan to fail (it fails at once on a vertical drag).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView && other is UIPanGestureRecognizer
        }
    }
}

/// A row with a trailing swipe-to-delete tile (the kept gesture). The tile is the look's
/// destructive treatment: A danger fill, B a raised tile with a pearl trash (no hue),
/// C the double rule with a trash disc. Tapping it (or a full swipe) calls `onDelete`,
/// which always confirms.
struct HistorySwipeRow<Content: View>: View {
    var title: String = "Delete"
    var startsOpen = false
    var onDelete: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    @State private var isOpen = false
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var reveal: CGFloat = 92

    init(title: String = "Delete", startsOpen: Bool = false, onDelete: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.startsOpen = startsOpen
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                tile
                    .frame(width: max(reveal, -offset))
                    .transition(.identity)
            }
            content
                .background(look.historyCardFill(onSheet: onSheet))
                .offset(x: offset)
                .overlay {
                    if isOpen {
                        Color.clear.contentShape(Rectangle()).onTapGesture { close() }
                    }
                }
                .gesture(HistoryHorizontalPan(onChanged: changed, onEnded: ended))
        }
        .clipped()
        .accessibilityAction(named: Text(title)) { onDelete() }
        .onChange(of: startsOpen, initial: true) { _, open in
            guard open, !isOpen else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animate { offset = -reveal; isOpen = true } }
        }
    }

    private var tile: some View {
        Button {
            close()
            onDelete()
        } label: {
            VStack(spacing: 3) {
                switch look.id {
                case .paper, .carbon:
                    // A short set row is ~50 pt tall: the disc stays small enough for its word.
                    Image(systemName: "trash")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(look.surface)
                        .frame(width: 22, height: 22)
                        .background(look.textPrimary, in: Circle())
                default:
                    Image(systemName: "trash").font(.system(.body, weight: .semibold))
                }
                Text(title).font(.system(.caption, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(tileForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tileBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tileForeground: Color {
        switch look.id {
        case .floodlight: look.onAction
        case .anatomy: look.textPrimary
        case .paper, .carbon: look.textPrimary
        }
    }

    @ViewBuilder private var tileBackground: some View {
        switch look.id {
        case .floodlight:
            look.destructive
        case .anatomy:
            look.surfaceRaised
        case .paper, .carbon:
            ZStack {
                look.pressedFill
                Rectangle().strokeBorder(look.outline, lineWidth: 2)
                Rectangle().inset(by: 4.5).strokeBorder(look.outline, lineWidth: 1.5)
            }
        }
    }

    private func changed(_ translation: CGFloat) {
        let base: CGFloat = isOpen ? -reveal : 0
        offset = min(0, base + translation)
    }

    private func ended(_ translation: CGFloat, _ velocity: CGFloat) {
        let base: CGFloat = isOpen ? -reveal : 0
        let final = base + translation
        if final < -reveal * 2.6 {
            close()
            onDelete()
        } else if final < -reveal * 0.5 || velocity < -600 {
            animate { offset = -reveal; isOpen = true }
        } else {
            close()
        }
    }

    private func close() { animate { offset = 0; isOpen = false } }

    private func animate(_ change: () -> Void) {
        if reduceMotion { change() } else { withAnimation(.spring(response: 0.3, dampingFraction: 0.86), change) }
    }
}

// MARK: - Square (a mark that always contains its content)

/// Sizes to a square no smaller than `minSide` and no smaller than its content, centred — so a
/// circle drawn behind it (C's punch) grows with large text instead of the number overlapping it.
struct HistorySquare: Layout {
    var minSide: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        let side = max(minSide, size.width, size.height)
        return CGSize(width: side, height: side)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}
