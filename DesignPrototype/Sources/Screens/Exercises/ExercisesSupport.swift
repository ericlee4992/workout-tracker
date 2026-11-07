import SwiftUI

// PROTOTYPE — Exercises area support: readouts derived from history (nothing new is stored),
// capture helpers (variants, p2 / p3 paging), and small look helpers. Everything here is
// area-prefixed so it cannot collide with other areas. Integrator: the Store readouts and
// the paging modifier are candidates to promote (Gyms / LiveSheets carry near-copies).

// MARK: - Catalog readouts

/// One exercise's relationship with the user, for the catalog row and the detail stats.
struct ExercisesCatalogStat: Hashable {
    var lastTrained: Date?
    var workouts = 0
    /// Completed non-warmup sets.
    var workingSets = 0
    /// Best eligible set across every equipment (the "Any equipment" layer), as entered.
    var best: SetValue?
    /// The new-best rule, one for every look: the best was set in the most recent workout that
    /// trained the exercise AND an earlier workout already had an eligible set it beat. A tie keeps
    /// the earlier set (so it is never marked), and a first-ever set is "first time", not a best.
    var lastWasNewBest = false
}

/// One past workout's sets for an exercise (the detail's History rows).
struct ExercisesSession: Identifiable, Hashable {
    var id: UUID { workoutID }
    var workoutID: UUID
    var date: Date
    var title: String
    var gymName: String?
    var equipment: String
    var sets: [LoggedSet]
    var loadType: LoadType
    var newBestSetIDs: Set<UUID>
}

/// A machine that serves (or served) the exercise, with its use for this exercise.
struct ExercisesMachineUse: Identifiable, Hashable {
    var id: UUID { machine.id }
    var machine: Machine
    var gymName: String?
    var workouts: Int
    var best: SetValue?
    var lastUsed: Date?
}

extension Store {
    /// Per-exercise stats in one pass over history (oldest first, so a tie keeps the earlier best).
    func exercisesCatalogStats() -> [UUID: ExercisesCatalogStat] {
        var stats: [UUID: ExercisesCatalogStat] = [:]
        // Best so far, the workout that set it, and whether an earlier workout had an eligible set.
        var bests: [UUID: (value: SetValue, workoutID: UUID)] = [:]
        var eligibleWorkouts: [UUID: Set<UUID>] = [:]
        var latest: [UUID: UUID] = [:]
        let byID = exerciseByID
        for workout in history.reversed() {
            var seen = Set<UUID>()
            for entry in workout.entries {
                let id = entry.exerciseID
                var stat = stats[id] ?? ExercisesCatalogStat()
                if seen.insert(id).inserted {
                    stat.workouts += 1
                    stat.lastTrained = workout.startedAt
                    latest[id] = workout.id
                }
                stat.workingSets += entry.countedSets.count
                let loadType = byID[id]?.loadType ?? entry.loadType
                // Sets logged under another load type rank differently (D23): they never mix in.
                if entry.loadType == loadType {
                    for set in entry.sets where Records.isEligible(type: set.type, value: set.value, loadType: loadType) {
                        guard let value = set.value else { continue }
                        eligibleWorkouts[id, default: []].insert(workout.id)
                        if let current = bests[id] {
                            if Records.outranks(value, current.value, loadType: loadType) { bests[id] = (value, workout.id) }
                        } else {
                            bests[id] = (value, workout.id)
                        }
                    }
                }
                stats[id] = stat
            }
        }
        for (id, best) in bests {
            stats[id]?.best = best.value
            let earlier = (eligibleWorkouts[id] ?? []).subtracting([best.workoutID])
            stats[id]?.lastWasNewBest = best.workoutID == latest[id] && !earlier.isEmpty
        }
        return stats
    }

    func exercisesStat(_ exerciseID: UUID) -> ExercisesCatalogStat {
        exercisesCatalogStats()[exerciseID] ?? ExercisesCatalogStat()
    }

    /// The newest workouts that trained an exercise, entries of one workout merged.
    func exercisesRecentSessions(_ exerciseID: UUID, limit: Int = 3) -> [ExercisesSession] {
        history.compactMap { workout -> ExercisesSession? in
            let entries = workout.entries.filter { $0.exerciseID == exerciseID }
            guard let first = entries.first else { return nil }
            let sets = entries.flatMap(\.sets)
            let equipment = [first.machineLabel ?? first.freeWeightTag?.label, first.presetName]
                .compactMap { $0 }.joined(separator: " · ")
            return ExercisesSession(
                workoutID: workout.id, date: workout.startedAt, title: workout.title, gymName: workout.gymName,
                equipment: equipment, sets: sets, loadType: first.loadType,
                newBestSetIDs: Set(sets.filter { bestOutcome(setID: $0.id).isNewBest }.map(\.id)))
        }
        .prefix(limit)
        .map { $0 }
    }

    /// Workouts per preset (a preset used twice in one workout counts once).
    func exercisesPresetUsage(_ exerciseID: UUID) -> [UUID: Int] {
        var usage: [UUID: Int] = [:]
        for workout in workouts {
            let presets = Set(workout.entries.filter { $0.exerciseID == exerciseID }.compactMap(\.presetID))
            for id in presets { usage[id, default: 0] += 1 }
        }
        return usage
    }

    /// Each preset's best eligible set on any equipment (sets logged under the exercise's
    /// current load type only, so a re-typed exercise never mixes rankings).
    func exercisesPresetBests(_ exerciseID: UUID) -> [UUID: SetValue] {
        let loadType = exercise(exerciseID)?.loadType ?? .weighted
        var values: [UUID: [SetValue]] = [:]
        for workout in history.reversed() {
            for entry in workout.entries where entry.exerciseID == exerciseID && entry.loadType == loadType {
                guard let presetID = entry.presetID else { continue }
                values[presetID, default: []] += entry.sets
                    .filter { Records.isEligible(type: $0.type, value: $0.value, loadType: loadType) }
                    .compactMap(\.value)
            }
        }
        return values.compactMapValues { Records.best($0, loadType: loadType) }
    }

    /// Active machines at every gym that serve the exercise, plus active machines it was
    /// logged on; most used first.
    func exercisesMachines(_ exerciseID: UUID) -> [ExercisesMachineUse] {
        let loadType = exercise(exerciseID)?.loadType ?? .weighted
        var used: [UUID: (workouts: Int, values: [SetValue], last: Date?)] = [:]
        for workout in history.reversed() {
            var seen = Set<UUID>()
            for entry in workout.entries where entry.exerciseID == exerciseID {
                guard let machineID = entry.machineID else { continue }
                var item = used[machineID] ?? (0, [], nil)
                if seen.insert(machineID).inserted {
                    item.workouts += 1
                    item.last = workout.startedAt
                }
                if entry.loadType == loadType {
                    item.values += entry.sets
                        .filter { Records.isEligible(type: $0.type, value: $0.value, loadType: loadType) }
                        .compactMap(\.value)
                }
                used[machineID] = item
            }
        }
        let serving = machines.filter { !$0.isDeleted && exerciseIDs(of: $0).contains(exerciseID) }.map(\.id)
        let ids = Array(Set(serving).union(used.keys.filter { machine($0)?.isDeleted == false }))
        return ids.compactMap { id -> ExercisesMachineUse? in
            guard let machine = machine(id) else { return nil }
            let item = used[id]
            return ExercisesMachineUse(machine: machine, gymName: gym(machine.gymID)?.name, workouts: item?.workouts ?? 0,
                                       best: item.flatMap { Records.best($0.values, loadType: loadType) },
                                       lastUsed: item?.last)
        }
        .sorted {
            if $0.workouts != $1.workouts { return $0.workouts > $1.workouts }
            if $0.gymName != $1.gymName { return ($0.gymName ?? "") < ($1.gymName ?? "") }
            return $0.machine.label.localizedCompare($1.machine.label) == .orderedAscending
        }
    }

    /// Sets already logged for an exercise (they keep the load type they were logged under).
    func exercisesLoggedSetCount(_ exerciseID: UUID) -> Int {
        workouts.reduce(0) { sum, workout in
            sum + workout.entries.filter { $0.exerciseID == exerciseID }.reduce(0) { $0 + $1.sets.count }
        }
    }

    /// Another exercise already has this name (case-insensitive).
    func exercisesNameTaken(_ name: String, except id: UUID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return exercises.contains { $0.id != id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }
}

// MARK: - Dates

enum ExercisesDates {
    private static let weekdayF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Format.locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    /// "Thu"
    static func weekdayShort(_ date: Date) -> String { weekdayF.string(from: date) }

    /// One date rule for every look (so the looks compare like for like): "Today", "Yesterday",
    /// the weekday within the last 6 days ("Mon"), otherwise "Sep 19".
    static func relative(_ date: Date, now: Date) -> String {
        let cal = Calendar.app
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return weekdayShort(date)
        default: return Format.shortDate(date)
        }
    }
}

// MARK: - Set values by load type

/// One formatter for every best, record and history value in the Exercises area, in every
/// look. It follows the load type (a plain "70 × 8" on an assisted exercise would read as 70 lb
/// lifted) and one unit rule: the unit shows only when it differs from the gym's unit.
/// Weighted "105 × 8" · BW + added "+15 × 8", or "BW × 12" for a plain set · Assisted
/// "−70 × 8" (less is better; 0 = unassisted, "BW × 8") · Bodyweight "BW × 12".
enum ExercisesValue {
    static func label(_ value: SetValue, loadType: LoadType, rowUnit: WeightUnit, alwaysUnit: Bool = false) -> String {
        let reps = value.reps
        let weight = value.weight ?? 0
        let unit = (alwaysUnit || value.unit != rowUnit) ? " \(value.unit.label)" : ""
        switch loadType {
        case .weighted:
            guard value.weight != nil else { return Format.reps(reps) }
            return "\(Format.weight(weight))\(unit) × \(reps)"
        case .bodyweight:
            return "BW × \(reps)"
        case .bodyweightPlus:
            return weight > 0 ? "+\(Format.weight(weight))\(unit) × \(reps)" : "BW × \(reps)"
        case .assisted:
            return weight > 0 ? "−\(Format.weight(weight))\(unit) × \(reps)" : "BW × \(reps)"
        }
    }

    /// The load alone, for a record tile's figure: "105", "+15", "−70", "BW".
    static func figure(_ value: SetValue, loadType: LoadType) -> String {
        let weight = value.weight ?? 0
        switch loadType {
        case .weighted: return Format.weight(weight)
        case .bodyweight: return "BW"
        case .bodyweightPlus: return weight > 0 ? "+\(Format.weight(weight))" : "BW"
        case .assisted: return weight > 0 ? "−\(Format.weight(weight))" : "BW"
        }
    }

    /// Whether the figure carries a unit (a "BW" figure does not).
    static func figureHasUnit(_ value: SetValue, loadType: LoadType) -> Bool {
        switch loadType {
        case .weighted: return value.weight != nil
        case .bodyweight: return false
        case .bodyweightPlus, .assisted: return (value.weight ?? 0) > 0
        }
    }

    /// VoiceOver: "105 pounds, 8 reps", "15 pounds added, 8 reps", "70 pounds assistance, 8 reps",
    /// "Bodyweight, 12 reps".
    static func spoken(_ value: SetValue, loadType: LoadType) -> String {
        let reps = Format.reps(value.reps)
        let weight = value.weight ?? 0
        let amount = "\(Format.weight(weight)) \(value.unit == .lb ? "pounds" : "kilograms")"
        switch loadType {
        case .weighted: return value.weight == nil ? reps : "\(amount), \(reps)"
        case .bodyweight: return "Bodyweight, \(reps)"
        case .bodyweightPlus: return weight > 0 ? "\(amount) added, \(reps)" : "Bodyweight, \(reps)"
        case .assisted: return weight > 0 ? "\(amount) assistance, \(reps)" : "Bodyweight, \(reps)"
        }
    }
}

// MARK: - Equipment

extension Exercise {
    /// The equipment words for a row: tags in catalog order. "Bodyweight" is left out when the
    /// load badge already says it (so "Dip" reads "BW + added", not "Bodyweight · BW + added").
    var exercisesEquipmentLine: String {
        exercisesShownTags.map(\.label).joined(separator: " · ")
    }

    /// The equipment tags worth showing beside the load badge (see above).
    var exercisesShownTags: [EquipmentTag] {
        tags.filter { !($0 == .bodyweight && loadType != .weighted) }
    }

    /// The leading glyph: the first tag's equipment (machines draw the weight stack).
    var exercisesGlyphTag: EquipmentTag? { tags.first }
}

extension LoadType {
    /// The load type's picker glyph.
    var exercisesSymbol: String {
        switch self {
        case .weighted: "scalemass"
        case .bodyweight: "figure.strengthtraining.functional"
        case .bodyweightPlus: "plus.circle"
        case .assisted: "arrow.down.circle"
        }
    }

    /// Which way records rank (assisted is the one that points down).
    var exercisesRankSymbol: String { higherIsBetter ? "arrow.up" : "arrow.down" }

    /// One consequence line for the selected type, one line at the default size (the real Load
    /// Type sheet's copy, trimmed: Bodyweight, BW + added and Assisted are PROPOSED shortenings).
    var exercisesExplanation: String {
        switch self {
        case .weighted: "More weight is harder. Records rank the heaviest set."
        case .bodyweight: "Your body is the load. Log reps alone."
        case .bodyweightPlus: "Your body plus any weight you add."
        case .assisted: "Less assistance is harder. Records rank the least."
        }
    }

    /// The rep-record table's title (the real Previous Performance copy).
    var exercisesRecordsTitle: String {
        switch self {
        case .weighted: "Weight records"
        case .assisted: "Least-assistance records · lower is better"
        case .bodyweightPlus: "Added-weight records"
        case .bodyweight: "Bodyweight record"
        }
    }
}

// MARK: - Grouping and filters (E01)

enum ExercisesGrouping: String, CaseIterable, Identifiable {
    case bodyArea, lastTrained, alphabetical

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bodyArea: "Body area"
        case .lastTrained: "Last trained"
        case .alphabetical: "A–Z"
        }
    }
    var symbol: String {
        switch self {
        case .bodyArea: "figure.arms.open"
        case .lastTrained: "clock.arrow.circlepath"
        case .alphabetical: "textformat.abc"
        }
    }
}

/// A list section: a title, the family its colour mark shows (nil = a neutral mark), and rows.
struct ExercisesSection: Identifiable {
    var id: String
    var title: String
    var family: MuscleFamily?
    /// false: no mark at all (A–Z letters).
    var showsMark = true
    var exercises: [Exercise]
}

// MARK: - Capture variants

/// View-level capture variants ("p2", "p3", "empty", "rename"…), read once for the screen
/// that owns them, then cleared so an ordinary presentation opens in its default state.
enum ExercisesVariant {
    static func consume(_ screen: ScreenID, store: Store, router: Router) -> String? {
        guard store.currentScreen == screen, let variant = router.variant else { return nil }
        router.variant = nil
        return variant
    }

    /// 0 = first viewport, 1 = p2, 2 = p3.
    static func page(_ variant: String?) -> Int {
        guard let variant else { return 0 }
        if variant.contains("p3") { return 2 }
        if variant.contains("p2") { return 1 }
        return 0
    }

    static func has(_ variant: String?, _ flag: String) -> Bool {
        variant?.localizedCaseInsensitiveContains(flag) ?? false
    }
}

/// A name handed from the catalog's "no match" state to the New Exercise sheet (the sheet's
/// initializer is fixed, so the prefill travels here).
enum ExercisesDraft {
    static var pendingName: String?
}

// MARK: - Paging (p2 / p3)

/// Scrolls a long page to its 2nd / 3rd viewport once it has laid out (capture variants).
/// p3 always reaches the end; on a page longer than three viewports p2 sits halfway.
struct ExercisesPaging: ViewModifier {
    var page: Int
    @Binding var position: ScrollPosition
    @State private var metrics = Metrics()

    struct Metrics: Equatable {
        var viewport: CGFloat = 0
        var content: CGFloat = 0
        var insetTop: CGFloat = 0
        var insetBottom: CGFloat = 0
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Metrics.self) { geo in
                Metrics(viewport: geo.containerSize.height, content: geo.contentSize.height,
                        insetTop: geo.contentInsets.top, insetBottom: geo.contentInsets.bottom)
            } action: { _, new in
                metrics = new
            }
            .task(id: page) {
                guard page > 0 else { return }
                var last = Metrics()
                for _ in 0..<40 {
                    try? await Task.sleep(for: .milliseconds(120))
                    if metrics.viewport > 0, metrics.content > 0, metrics == last { break }
                    last = metrics
                }
                try? await Task.sleep(for: .milliseconds(150))
                let visible = metrics.viewport - metrics.insetTop - metrics.insetBottom
                let step = max(200, visible - 60)
                let maxOffset = max(0, metrics.content - metrics.viewport + metrics.insetBottom)
                let target: CGFloat
                if page >= 2 {
                    target = maxOffset
                } else if maxOffset > 2 * step {
                    target = maxOffset / 2
                } else {
                    target = min(step - metrics.insetTop, maxOffset)
                }
                position.scrollTo(y: target)
            }
    }
}

extension View {
    func exercisesPaging(_ page: Int, position: Binding<ScrollPosition>) -> some View {
        modifier(ExercisesPaging(page: page, position: position))
    }

    /// A pushed screen's inline title in the look's nav face, faded in once the hero title
    /// has scrolled away.
    func exercisesInlineTitle(_ title: String, visible: Bool) -> some View {
        modifier(ExercisesInlineTitle(title: title, visible: visible))
    }

    /// Reports whether the scroll view has moved past `threshold`.
    func exercisesScrolledPast(_ threshold: CGFloat, into flag: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > threshold
        } action: { _, past in
            if flag.wrappedValue != past { withAnimation(.easeOut(duration: 0.18)) { flag.wrappedValue = past } }
        }
    }

    /// A sheet's root: the sheet ground, the look's corner radius, the drag indicator, and the
    /// prototype's Dynamic Type override (a sheet is its own presentation). `fitted` is the
    /// measured height of the sheet's content: the sheet opens at exactly that height (drag up
    /// for the full height) so a small choice keeps its parent in view with no empty tail. At
    /// accessibility sizes, or when the content is taller than the screen, it opens full height.
    func exercisesSheetPresentation(_ look: Look, fitted: CGFloat? = nil) -> some View {
        modifier(ExercisesSheetChrome(look: look, fitted: fitted))
    }

    /// Reports a view's height (for a fitted sheet).
    func exercisesMeasureHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { new in
            if abs(height.wrappedValue - new) > 0.5 { height.wrappedValue = new }
        }
    }

    /// Reports a scroll view's content height (for a fitted sheet).
    func exercisesMeasureContent(_ height: Binding<CGFloat>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, new in
            if abs(height.wrappedValue - new) > 0.5 { height.wrappedValue = new }
        }
    }
}

private struct ExercisesSheetChrome: ViewModifier {
    var look: Look
    var fitted: CGFloat?
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var expanded = false

    func body(content: Content) -> some View {
        let ax = (router.dynamicTypeOverride ?? typeSize).isAccessibilitySize
        // Rounded to whole points so a sub-point re-measure never re-seats the sheet.
        let height = fitted.map { ($0 + 12).rounded(.up) }
        let short: PresentationDetent? = (!ax && (height ?? 0) > 120 && (height ?? 0) < 780) ? .height(height!) : nil
        content
            .lookSheetGround()
            .modifier(ExercisesTypeOverride())
            .presentationBackground(look.groundSheet)
            .presentationCornerRadius(look.radius.sheet)
            .presentationDragIndicator(.visible)
            .presentationDetents(short.map { [$0, .large] } ?? [.large],
                                 selection: Binding(get: { expanded || short == nil ? .large : short! },
                                                    set: { expanded = ($0 == .large) }))
    }
}

private struct ExercisesInlineTitle: ViewModifier {
    var title: String
    var visible: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .opacity(visible ? 1 : 0)
                        .accessibilityHidden(!visible)
                }
            }
    }
}

/// Applies `router.dynamicTypeOverride` inside a sheet.
struct ExercisesTypeOverride: ViewModifier {
    @Environment(Router.self) private var router
    func body(content: Content) -> some View {
        if let size = router.dynamicTypeOverride { content.dynamicTypeSize(size) } else { content }
    }
}

// MARK: - Look helpers (fonts built from text styles, per look)

extension Look {
    /// A list row's title.
    var exercisesRowTitle: Font {
        switch id {
        case .floodlight: .system(.body, weight: .semibold)
        case .anatomy: .system(.body, design: .rounded, weight: .semibold)
        case .paper, .carbon: .system(.body, weight: .medium)
        }
    }

    /// A number inside a row ("105 × 8").
    var exercisesRowValue: Font {
        switch id {
        case .anatomy: .system(.subheadline, design: .rounded, weight: .heavy).monospacedDigit()
        case .floodlight, .paper, .carbon: Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }

    /// A word shown as a stat ("Sep 17", "Wed").
    var exercisesStatWord: Font {
        switch id {
        case .anatomy: .system(.title3, design: .rounded, weight: .heavy)
        case .floodlight, .paper, .carbon: Font.system(.title3, weight: .heavy).width(.expanded)
        }
    }

    /// Glyph colour in rows (C draws glyphs in ink).
    var exercisesGlyphTint: Color { id.isPaperClub ? textPrimary : textSecondary }
}

// MARK: - Equipment glyphs (the same drawings the live pickers use)

/// An equipment glyph: the machine weight stack, a barbell, a cable, a Smith machine or an SF Symbol.
struct ExercisesGlyph: View {
    var tag: EquipmentTag?
    var style: Font.TextStyle = .body
    @ScaledMetric private var side: CGFloat

    init(_ tag: EquipmentTag?, style: Font.TextStyle = .body) {
        self.tag = tag
        self.style = style
        _side = ScaledMetric(wrappedValue: style == .title2 ? 26 : (style == .title3 ? 22 : 19), relativeTo: style)
    }

    var body: some View {
        switch tag {
        case .machine: LookIcon(LookIcon.machine, style: style)
        case .barbell: shape(ExercisesBarbellShape())
        case .cable: shape(ExercisesCableShape())
        case .smith: shape(ExercisesSmithShape())
        case .dumbbell: Image(systemName: "dumbbell").font(.system(style, weight: .semibold))
        case .bodyweight: Image(systemName: "figure.strengthtraining.functional").font(.system(style, weight: .semibold))
        case nil: Image(systemName: "questionmark.square.dashed").font(.system(style, weight: .semibold))
        }
    }

    private func shape<S: Shape>(_ s: S) -> some View {
        s.stroke(style: StrokeStyle(lineWidth: max(1.4, side * 0.085), lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

private struct ExercisesGrid {
    let s: CGFloat, ox: CGFloat, oy: CGFloat
    init(_ rect: CGRect) {
        s = min(rect.width, rect.height) / 24
        ox = rect.midX - 12 * s
        oy = rect.midY - 12 * s
    }
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(origin: pt(x, y), size: CGSize(width: w * s, height: h * s))
    }
}

struct ExercisesBarbellShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = ExercisesGrid(rect)
        var p = Path()
        p.move(to: g.pt(1, 12)); p.addLine(to: g.pt(23, 12))
        p.addRoundedRect(in: g.rect(4, 5.5, 3, 13), cornerSize: CGSize(width: g.s, height: g.s))
        p.addRoundedRect(in: g.rect(17, 5.5, 3, 13), cornerSize: CGSize(width: g.s, height: g.s))
        p.addRoundedRect(in: g.rect(7.5, 8, 2, 8), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        p.addRoundedRect(in: g.rect(14.5, 8, 2, 8), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        return p
    }
}

struct ExercisesCableShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = ExercisesGrid(rect)
        var p = Path()
        p.move(to: g.pt(12, 0.8)); p.addLine(to: g.pt(12, 2.5))
        p.addEllipse(in: g.rect(7.5, 2.5, 9, 9))
        p.addEllipse(in: g.rect(11, 6, 2, 2))
        p.move(to: g.pt(16.5, 7)); p.addLine(to: g.pt(16.5, 16.5))
        p.move(to: g.pt(16.5, 16.5)); p.addLine(to: g.pt(12.5, 20))
        p.move(to: g.pt(16.5, 16.5)); p.addLine(to: g.pt(20.5, 20))
        p.move(to: g.pt(10, 20.5)); p.addLine(to: g.pt(23, 20.5))
        return p
    }
}

struct ExercisesSmithShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = ExercisesGrid(rect)
        var p = Path()
        p.move(to: g.pt(5, 2)); p.addLine(to: g.pt(5, 22))
        p.move(to: g.pt(19, 2)); p.addLine(to: g.pt(19, 22))
        p.move(to: g.pt(2, 22)); p.addLine(to: g.pt(22, 22))
        p.move(to: g.pt(1.5, 10)); p.addLine(to: g.pt(22.5, 10))
        p.addRoundedRect(in: g.rect(7, 6.5, 2.4, 7), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        p.addRoundedRect(in: g.rect(14.6, 6.5, 2.4, 7), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        return p
    }
}

// MARK: - Flow layout (chips)

/// Lays chips out left to right, wrapping to new lines.
struct ExercisesFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(width: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let used = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += min(size.width, bounds.width) + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let w = min(size.width, width)
            let needed = current.indices.isEmpty ? w : current.width + spacing + w
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? w : current.width + spacing + w
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
