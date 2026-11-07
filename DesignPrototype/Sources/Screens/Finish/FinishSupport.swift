import SwiftUI

// PROTOTYPE — Finish area support: the receipt's derived rows (from the frozen workout
// snapshot, never live catalog names), the per-look set-value text, the paired tiles with
// their count-up, the fallback rings and the capture variants. Everything is area-prefixed so
// the integrator can promote what survives into Model/ or Look/.

// MARK: - Receipt data

/// One exercise on the receipt: snapshot name, short equipment line, best counted set.
struct FinishExerciseRowData: Identifiable, Hashable {
    let id: UUID
    let name: String
    /// The frozen equipment snapshot and the set count: "Chest Press 2 · 5 sets".
    let detail: String
    let best: SetValue?
    let loadType: LoadType
    let isNewBest: Bool
    /// The first eligible set ever in this scope: "First time", never a new best.
    let isFirstTime: Bool
}

/// One new best: the set that beat the previous best on the same equipment and preset.
struct FinishBestRowData: Identifiable, Hashable {
    let id: UUID
    let name: String
    /// "Chest Press 2" (the machine / free-weight tag snapshot, plus the preset).
    let equipment: String?
    let value: SetValue
    let previous: SetValue?
    let loadType: LoadType
}

/// Everything the receipt draws, derived once per summary.
struct FinishData {
    let summary: FinishSummary
    let workout: Workout?
    /// Every set per family in workout order (A's ring: one segment per set, warmups included,
    /// so the ring agrees with "22 sets").
    let allSetsByFamily: [FamilyCount]
    /// Working sets (warmups excluded) per family in workout order (B's family arcs).
    let workingSetsByFamily: [FamilyCount]
    /// Working sets for all five families, head to toe (B's card, C's tiles).
    let familyTotals: [FamilyCount]
    let exercises: [FinishExerciseRowData]
    let bests: [FinishBestRowData]
    let cardio: [CardioSegment]
    /// One-minute heart-rate range bars (see FinishHeartRateFixture); empty without heart rate.
    let hrSlots: [HRSlot]
    /// Seconds per zone for Time in zones, from the same trace as the bars (so the rows and
    /// the bars agree and add up to the workout); empty without zones.
    let zoneSeconds: [Int]
    /// The workout logged at least one lifting entry (cardio-only sessions have no families).
    let hasLifting: Bool

    var trainedFamilies: [FamilyCount] { familyTotals.filter { $0.sets > 0 } }
    var zoneTimes: [ZoneTime] { Derived.zoneTimes(zoneSeconds) }
    /// Active seconds of cardio, for A's and B's cardio arc around the ring.
    var cardioSeconds: Int { cardio.reduce(0) { $0 + $1.activeSeconds } }
}

extension Store {
    /// The receipt rows for a summary. Family mapping is live (`exercise.muscleGroup`), the
    /// documented D23 exception the SPECs accept; every name shown is the frozen snapshot.
    func finishData(for summary: FinishSummary) -> FinishData {
        let workout = workout(summary.workoutID)
        let entries = workout?.entries ?? []
        var allOrder: [MuscleFamily] = [], all: [MuscleFamily: Int] = [:]
        var workingOrder: [MuscleFamily] = [], working: [MuscleFamily: Int] = [:]
        for entry in entries {
            guard let family = exercise(entry.exerciseID)?.family else { continue }
            if !entry.sets.isEmpty {
                if all[family] == nil { allOrder.append(family) }
                all[family, default: 0] += entry.sets.count
            }
            let counted = entry.countedSets.count
            if counted > 0 {
                if working[family] == nil { workingOrder.append(family) }
                working[family, default: 0] += counted
            }
        }
        let bestEntryIDs = Set(summary.exercises.filter(\.hasNewBest).map(\.entryID))
        let rows = entries.map { entry in
            let isNewBest = bestEntryIDs.contains(entry.id)
            let firstTime = !isNewBest && entry.countedSets.contains { bestOutcome(setID: $0.id) == .firstTime }
            return FinishExerciseRowData(
                id: entry.id, name: entry.exerciseName,
                detail: [Self.finishEquipment(entry), Format.count(entry.sets.count, "set")]
                    .compactMap { $0 }.joined(separator: " · "),
                best: entry.bestCounted, loadType: entry.loadType, isNewBest: isNewBest, isFirstTime: firstTime)
        }
        let bests: [FinishBestRowData] = summary.newBests.map { line in
            let entry = entries.first { $0.sets.contains { $0.id == line.setID } }
            return FinishBestRowData(
                id: line.setID, name: line.exerciseName,
                equipment: entry.flatMap(Self.finishEquipment),
                value: line.value, previous: line.previous, loadType: entry?.loadType ?? .weighted)
        }
        let heartRate = summary.hrSlots.isEmpty && summary.zoneSeconds.isEmpty ? nil
            : workout.flatMap { FinishHeartRateFixture.build(for: $0, maxHeartRate: maxHeartRate) }
        let zoneSeconds = summary.zoneSeconds.isEmpty ? []
            : (heartRate.map(\.zoneSeconds).flatMap { $0.isEmpty ? nil : $0 } ?? summary.zoneSeconds)
        return FinishData(
            summary: summary, workout: workout,
            allSetsByFamily: allOrder.map { FamilyCount(family: $0, sets: all[$0] ?? 0) },
            workingSetsByFamily: workingOrder.map { FamilyCount(family: $0, sets: working[$0] ?? 0) },
            familyTotals: MuscleFamily.allCases.map { FamilyCount(family: $0, sets: working[$0] ?? 0) },
            exercises: rows, bests: bests, cardio: summary.cardio.map(FinishRouteFixture.displaySegment),
            hrSlots: summary.hrSlots.isEmpty ? [] : (heartRate?.slots ?? summary.hrSlots),
            zoneSeconds: zoneSeconds,
            hasLifting: !entries.isEmpty)
    }

    /// The frozen equipment snapshot under an exercise, the same on every row: "Chest Press
    /// 2", "Chest Press 2 · Narrow grip", "Dumbbell". nil only when nothing was captured.
    static func finishEquipment(_ entry: WorkoutEntry) -> String? {
        let parts = [entry.machineLabel ?? entry.freeWeightTag?.label, entry.presetName].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Average / max heart rate over a cardio segment (the segment's own figures, else the
    /// workout's 15 s series; nil = no data).
    func finishSegmentHeartRate(_ segment: CardioSegment, in workout: Workout?) -> (average: Int, max: Int)? {
        if let avg = segment.averageHeartRate { return (avg, segment.maxHeartRate ?? avg) }
        guard let workout, let series = workout.heartRate?.series else { return nil }
        let start = Int(segment.startedAt.timeIntervalSince(workout.startedAt)) / series.intervalSeconds
        let end = start + segment.activeSeconds / series.intervalSeconds
        let slice = series.mean.indices.filter { $0 >= start && $0 < end }.map { series.mean[$0] }.filter { $0 > 0 }
        guard !slice.isEmpty else { return nil }
        return (slice.reduce(0, +) / slice.count, slice.max() ?? 0)
    }
}

// MARK: - Summary lines

/// "5 exercises · 22 sets · Iron Temple" that wraps only between its parts: each part keeps
/// its words together (unless one part alone is wider than the line), and the "·" before a
/// part that starts a new line is dropped — no line starts or ends with "·".
struct FinishFlowLine: View {
    let parts: [String]

    var body: some View {
        FinishFlowLayout(spacing: 0, lineSpacing: 2, separators: true) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Text(" · ").accessibilityHidden(true).layoutValue(key: FinishFlowSeparator.self, value: true)
                }
                Text(part)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(parts.joined(separator: ", "))
    }
}

/// Marks a separator subview of `FinishFlowLayout`.
nonisolated struct FinishFlowSeparator: LayoutValueKey {
    static let defaultValue = false
}

/// Lays subviews out left to right and wraps to a new line when the next one does not fit.
/// With `separators`, a separator subview is kept only between two items on the same line.
struct FinishFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var separators: Bool

    private struct Placement { var index: Int; var origin: CGPoint; var size: CGSize; var hidden: Bool }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (placements: [Placement], size: CGSize) {
        var placements: [Placement] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        var pendingSeparator: (Int, CGSize)?
        for index in subviews.indices {
            let subview = subviews[index]
            if separators && subview[FinishFlowSeparator.self] {
                pendingSeparator = (index, subview.sizeThatFits(.unspecified))
                continue
            }
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width { size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            let separatorWidth = pendingSeparator.map { $0.1.width } ?? 0
            let gap = x > 0 ? spacing : 0
            if x > 0 && x + gap + separatorWidth + size.width > width + 0.5 {
                // Wrap: the separator goes with the break.
                if let (i, s) = pendingSeparator { placements.append(Placement(index: i, origin: .zero, size: s, hidden: true)) }
                y += lineHeight + lineSpacing
                x = 0; lineHeight = 0
            } else if let (i, s) = pendingSeparator, x > 0 {
                placements.append(Placement(index: i, origin: CGPoint(x: x, y: y), size: s, hidden: false))
                x += s.width
                lineHeight = max(lineHeight, s.height)
            }
            pendingSeparator = nil
            let start = x > 0 ? x + (separators ? 0 : spacing) : 0
            placements.append(Placement(index: index, origin: CGPoint(x: start, y: y), size: size, hidden: false))
            x = start + size.width
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x)
        }
        return (placements, CGSize(width: widest, height: y + lineHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for p in arrange(subviews, width: bounds.width).placements {
            if p.hidden {
                subviews[p.index].place(at: CGPoint(x: bounds.minX - 10_000, y: bounds.minY), proposal: ProposedViewSize(p.size))
            } else {
                subviews[p.index].place(at: CGPoint(x: bounds.minX + p.origin.x, y: bounds.minY + p.origin.y),
                                        proposal: ProposedViewSize(p.size))
            }
        }
    }
}

// MARK: - Sections and their reveals

/// The receipt's sections below the fold. Each one plays its entry motion when the user
/// actually meets it (scrolled 40 % into view), not when the sheet opens.
enum FinishRevealSection: Hashable, CaseIterable {
    case bests, families, cardio, heartRate, exercises
}

/// Reports where receipt sections and the cards inside them start in the scroll content, so
/// the "pN" capture variants open each page on a section title — or, inside a section taller
/// than the screen, on a card boundary (never mid-card). Each mark reports through
/// `onGeometryChange` (it follows every later layout change, which a preference measured once
/// in a GeometryReader did not) and withdraws when its view goes away.
enum FinishSectionTop {
    static let space = "finishContent"

    struct Mark: Equatable, Comparable {
        var y: CGFloat
        var isSection: Bool
        static func < (a: Mark, b: Mark) -> Bool { a.y < b.y }
    }
}

extension EnvironmentValues {
    /// Where receipt marks report (id, mark; nil = gone). Unset outside the receipt.
    @Entry var finishMarkReport: ((UUID, FinishSectionTop.Mark?) -> Void)?
}

extension View {
    /// A section title starts here.
    func finishSectionTop() -> some View { modifier(FinishMarkModifier(isSection: true)) }
    /// A card (or a block inside a tall card) starts here.
    func finishAnchor() -> some View { modifier(FinishMarkModifier(isSection: false)) }
}

private struct FinishMarkModifier: ViewModifier {
    let isSection: Bool
    @State private var id = UUID()
    @Environment(\.finishMarkReport) private var report

    func body(content: Content) -> some View {
        if let report {
            content
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(FinishSectionTop.space)).minY } action: { y in
                    report(id, FinishSectionTop.Mark(y: y, isSection: isSection))
                }
                .onDisappear { report(id, nil) }
        } else {
            content
        }
    }
}

// MARK: - Capture variants

/// View-level variants of F01/F02 (`-variant a+b`, joined with "+"): extra receipt states
/// for review. Store-free except `saved` and `long`, which act through Store methods.
struct FinishVariant {
    var page: Int?
    /// Save as Template already done: the confirmation line replaces the button.
    var saved = false
    /// Save as Template tapped: T04 open over the receipt.
    var saveSheet = false
    /// No heart-rate source: no avg/max tiles, no graph; no basal, so no total calories.
    var noHeartRate = false
    /// No earlier run of this template: no comparison.
    var firstRun = false
    /// A freeform workout (no template): no comparison, derived title.
    var freeform = false
    /// Another history workout's receipt (cardio only, indoor run, first times, assisted).
    var workoutKey: String?
    /// The route map without tiles (offline).
    var offline = false
    /// More than 24 sets (A's continuous-arc ring).
    var longSession = false
    /// Force Reduce Motion inside the receipt (for review frames).
    var reduceMotion = false

    init(_ raw: String?) {
        for token in (raw ?? "").split(whereSeparator: { $0 == "+" || $0 == "," }).map(String.init) {
            switch token {
            case "saved": saved = true
            case "saveSheet": saveSheet = true
            case "noHR": noHeartRate = true
            case "firstRun": firstRun = true
            case "freeform": freeform = true
            case "cardioOnly": workoutKey = "2026-08-29"
            case "indoor": workoutKey = "2026-09-21-run"
            case "firsts": workoutKey = "2026-08-31"
            case "assisted": workoutKey = "2026-09-21"
            case "offline": offline = true
            case "long": longSession = true
            case "rm": reduceMotion = true
            default:
                if token.hasPrefix("p"), let n = Int(token.dropFirst()), n >= 2 { page = n }
            }
        }
    }

    /// Applies the summary-level changes to the receipt the reset produced.
    @MainActor func apply(to summary: FinishSummary, store: Store) -> FinishSummary {
        var result = summary
        if let key = workoutKey, let other = store.finishSummary(workoutID: SampleData.workoutID(key)) {
            result = other
        }
        if longSession, let id = result.workoutID, let workout = store.workout(id) {
            // Three more logged sets (History editing), so the ring passes 24 segments.
            for entry in workout.entries.prefix(3) { _ = store.addLoggedSet(workoutID: id, entryID: entry.id) }
            result = store.finishSummary(workoutID: id) ?? result
        }
        if noHeartRate {
            result.tiles.removeAll { [.averageHeartRate, .maxHeartRate, .totalCalories].contains($0.kind) }
            result.averageHeartRate = nil
            result.maxHeartRate = nil
            result.zoneSeconds = []
            result.hrSlots = []
        }
        if firstRun || freeform { result.comparison = nil }
        if freeform, let id = result.workoutID, var workout = store.workout(id) {
            workout.templateID = nil
            workout.templateName = nil
            result.title = workout.title
        }
        return result
    }
}

// MARK: - Set value text

/// "110 lb × 8" with big numbers and a small unit, per look: the weight and the reps both in
/// the number face (A Expanded Heavy, B Rounded Heavy, C Expanded Heavy — New bests and
/// Exercises alike), the unit small —
/// a new best that is a rep gain ("80 × 8" → "80 × 10") shows its gain at full size.
/// Bodyweight sets (and BW + added logged at 0) read "12 reps".
struct FinishSetValueText: View {
    enum Size { case hero, row }
    var value: SetValue
    var loadType: LoadType
    var size: Size = .row
    /// Text colour override (C's highlighter uses ink).
    var color: Color?

    @Environment(\.look) private var look

    private var showsWeight: Bool {
        guard loadType.takesWeight, let weight = value.weight else { return false }
        return !(loadType == .bodyweightPlus && weight == 0)
    }

    var body: some View {
        let primary = color ?? look.textPrimary
        let secondary = color?.opacity(0.78) ?? look.textSecondary
        Group {
            if showsWeight, let weight = value.weight {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Format.weight(weight)).font(numberFont).foregroundStyle(primary)
                    Text(value.unit.label).font(smallFont).foregroundStyle(secondary)
                    Text("× \(value.reps)").font(numberFont).foregroundStyle(primary)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(value.reps)").font(numberFont).foregroundStyle(primary)
                    Text(value.reps == 1 ? "rep" : "reps").font(smallFont).foregroundStyle(secondary)
                }
            }
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsWeight ? Format.set(value, loadType: loadType) : Format.reps(value.reps))
    }

    private var numberFont: Font {
        switch (look.id, size) {
        // A's hero stays at Headline so a long name ("Machine Shoulder Press") keeps one line.
        case (.floodlight, _): Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit()
        case (.anatomy, .hero): Font.system(.title3, design: .rounded, weight: .heavy).monospacedDigit()
        case (.anatomy, .row): Font.system(.headline, design: .rounded, weight: .heavy).monospacedDigit()
        case (_, .hero): Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit()
        case (_, .row): Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }

    private var smallFont: Font {
        switch look.id {
        case .anatomy: .system(.caption, design: .rounded, weight: .bold)
        case .floodlight: .system(.caption, weight: .semibold)
        case .paper, .carbon: .system(.caption, weight: .bold)
        }
    }
}

/// The previous best, struck through: the replaced record reads at a glance with no words.
struct FinishPreviousBestText: View {
    var value: SetValue
    var loadType: LoadType
    @Environment(\.look) private var look

    var body: some View {
        Text(look.id == .floodlight ? Format.set(value, loadType: loadType) : Format.setShort(value, loadType: loadType))
            .font(.system(.caption, weight: .semibold).monospacedDigit())
            .strikethrough(true, color: look.textTertiary)
            .foregroundStyle(look.textTertiary)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("Previous best \(Format.set(value, loadType: loadType))")
    }
}

// MARK: - Paired tiles

/// The finish tiles in the user's order, paired (Workout time | Total volume, Active | Total
/// calories, Avg. | Max heart rate), laid out like `StatPairGrid` per look. Only running
/// totals count up (time, volume, calories); the heart-rate figures are an average and a
/// peak, which never pass through lower values, so they fade in at their final values.
struct FinishStatGrid: View {
    var tiles: [FinishTile]
    /// false = the final state at once (Reduce Motion, frozen captures, the placeholder).
    var animated = true

    @State private var heartShown = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rows: [[FinishTile]] {
        let groups = Dictionary(grouping: tiles) { StatPairGrid.pairIndex($0.kind) }
        return groups.keys.sorted().map { groups[$0]! }
    }

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        Group {
            switch look.id {
            case .floodlight:
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { LookDivider() }
                        pairRow(row, stacked: stacked)
                    }
                }
                .lookSurface(.stat)
            case .anatomy:
                VStack(spacing: 10) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        let layout = stacked ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                        layout {
                            ForEach(row) { tile in
                                cell(tile)
                                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                                    .lookSurface(.stat)
                            }
                            if row.count == 1 && !stacked { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                }
            case .paper, .carbon:
                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        pairRow(row, stacked: stacked).lookSurface(.stat)
                    }
                }
            }
        }
        .onAppear {
            guard animated, !reduceMotion else { heartShown = true; return }
            withAnimation(.easeOut(duration: 0.4).delay(0.55)) { heartShown = true }
        }
    }

    @ViewBuilder
    private func pairRow(_ row: [FinishTile], stacked: Bool) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ForEach(Array(row.enumerated()), id: \.element.id) { index, tile in
                if index > 0 { LookDivider(vertical: !stacked) }
                cell(tile).frame(maxWidth: .infinity, alignment: .leading)
            }
            if row.count == 1 && !stacked {
                // The missing half stays an empty cell (missing is not zero).
                LookDivider(vertical: true)
                Color.clear.frame(maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cell(_ tile: FinishTile) -> some View {
        let isHeart = tile.kind == .averageHeartRate || tile.kind == .maxHeartRate
        let valueTint: Color? = isHeart && !look.id.isPaperClub ? look.heartRate : nil
        let symbolTint: Color? = isHeart ? look.heartRate : (look.id.isPaperClub ? look.textPrimary : nil)
        return StatFigure(value: tile.value, unit: tile.unit.isEmpty ? nil : tile.unit, label: tile.label,
                          symbol: look.tileSymbol(tile.kind), tint: valueTint, symbolTint: symbolTint,
                          countsUp: animated && !isHeart)
            .opacity(isHeart && !heartShown ? 0 : 1)
            .padding(.horizontal, 16)
            .padding(.top, look.id == .floodlight ? 16 : 13)
            .padding(.bottom, look.id == .floodlight ? 16 : 12)
            .finishAnchor()
    }
}

// MARK: - Rings without families

/// A and B for a session with no lifting families (cardio only): the ring shows time in
/// zones as arcs in the zone ramp (B SPEC §6 "the cardio finish ring is segmented by time in
/// zones"), or a single done ring without heart rate, then the check lands.
/// C always uses its rubber stamp.
struct FinishZoneRing: View {
    var zoneSeconds: [Int]
    var size: CGFloat
    @State private var drawn = false
    @State private var checkIn = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = size * (look.id == .floodlight ? 0.1 : 0.094)
        let entries = HeartRateZone.allCases.compactMap { zone -> (HeartRateZone, Int)? in
            let s = zone.rawValue < zoneSeconds.count ? zoneSeconds[zone.rawValue] : 0
            return s > 0 ? (zone, s) : nil
        }
        let total = Double(max(1, entries.reduce(0) { $0 + $1.1 }))
        ZStack {
            Circle().stroke(look.ringTrack, lineWidth: width)
            if entries.isEmpty {
                RingArc(start: 0, end: drawn ? 1 : 0)
                    .stroke(look.done, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: drawn)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.0) { index, item in
                    let start = entries[..<index].reduce(0.0) { $0 + Double($1.1) } / total
                    let end = start + Double(item.1) / total
                    RingArc(start: start + 0.006, end: drawn ? max(start + 0.006, end - 0.006) : start + 0.006)
                        .stroke(look.zone(item.0), style: StrokeStyle(lineWidth: width, lineCap: .butt))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(Double(index) * 0.15), value: drawn)
                }
            }
            CheckShape()
                .stroke(look.textPrimary, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round, lineJoin: .round))
                .scaleEffect(checkIn ? 1 : look.motion.stampScale)
                .opacity(checkIn ? 1 : 0)
        }
        .padding(width / 2)
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion { drawn = true; checkIn = true; return }
            drawn = true
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.8)) { checkIn = true }
        }
        .sensoryFeedback(.success, trigger: checkIn) { _, new in new }
        .accessibilityElement()
        .accessibilityLabel("Workout saved")
    }
}

/// "Nothing to save": an empty ring holding a tray, per look (A/B a plain, unsegmented track —
/// segments would promise sets that do not exist; C an unstamped dashed stamp outline).
/// Nothing celebrates, nothing animates.
struct FinishEmptyRing: View {
    var size: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        ZStack {
            FinishRingRest(size: size, segments: 0)
            Image(systemName: "tray")
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The ring's resting state, drawn before (and under) the reveal so the slot never reads as
/// a hole: A's unlit segments (a plain track above 24 sets), B's track, C's dashed unstamped
/// outline.
struct FinishRingRest: View {
    var size: CGFloat
    /// A: how many segments the ring will light (0 = a plain track).
    var segments: Int
    @Environment(\.look) private var look

    var body: some View {
        switch look.id {
        case .floodlight:
            let width = size * 0.1
            Group {
                if segments > 0 && segments <= 24 {
                    ZStack {
                        ForEach(0..<segments, id: \.self) { index in
                            let step = 1.0 / Double(segments)
                            RingArc(start: Double(index) * step + step * 0.14, end: Double(index + 1) * step - step * 0.14)
                                .stroke(look.ringTrack, style: StrokeStyle(lineWidth: width))
                        }
                    }
                } else {
                    Circle().stroke(look.ringTrack, lineWidth: width)
                }
            }
            .padding(width / 2)
            .frame(width: size, height: size)
        case .anatomy:
            Circle().stroke(look.ringTrack, lineWidth: size * 0.094)
                .padding(size * 0.047 + size * 0.04)
                .frame(width: size, height: size)
        case .paper, .carbon:
            Circle()
                .strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: size * 0.03, dash: [6, 5]))
                .padding(size * 0.02)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Type size inside the sheet

/// Applies `router.dynamicTypeOverride` inside the sheet (a presented sheet does not inherit
/// the shell's trait-based `-axl` override).
struct FinishTypeSizeOverride: ViewModifier {
    var size: DynamicTypeSize?
    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}

/// Forces Reduce Motion inside the receipt for the `rm` review variant.
struct FinishReduceMotionOverride: ViewModifier {
    var on: Bool
    func body(content: Content) -> some View {
        if on { content.environment(\._accessibilityReduceMotion, true) } else { content }
    }
}
