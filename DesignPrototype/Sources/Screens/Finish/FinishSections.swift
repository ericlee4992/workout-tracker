import SwiftUI

// PROTOTYPE — the receipt's sections below the actions: new bests, last-time comparison,
// families trained, heart rate with zones directly below, and the exercises with best sets.
// Each look's treatment follows its SPEC; the data is the same everywhere. Every section's
// entry motion waits for `revealed` — the moment the user reaches it — so nothing plays
// off-screen.

// MARK: - New bests

/// A: one panel; each row leads with the outlined burst stamp (40 pt), which flips in.
/// B: one card; each row leads with a pearl star medal that shines once (a pearl halo).
/// C: one card per best; the value sits on the yellow highlighter, swiped in left to right.
/// Every row shows the previous best struck through beside the new value. Rows land one by
/// one (160 ms apart, a light haptic each) once the section is revealed.
struct FinishNewBestsSection: View {
    let bests: [FinishBestRowData]
    let revealed: Bool

    @State private var landed: Int
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(bests: [FinishBestRowData], revealed: Bool, instant: Bool) {
        self.bests = bests
        self.revealed = revealed
        _landed = State(initialValue: instant && revealed ? bests.count : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("New bests")
            switch look.id {
            case .floodlight, .anatomy:
                VStack(spacing: 0) {
                    ForEach(Array(bests.enumerated()), id: \.element.id) { index, best in
                        if index > 0 { LookDivider().padding(.leading, 16) }
                        FinishBestRow(best: best, isLanded: index < landed).finishAnchor()
                    }
                }
                .lookSurface(.panel)
            case .paper, .carbon:
                VStack(spacing: 12) {
                    ForEach(Array(bests.enumerated()), id: \.element.id) { index, best in
                        FinishBestRow(best: best, isLanded: index < landed)
                            .lookSurface(.panel)
                            .finishAnchor()
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: landed) { old, new in new > old }
        .task(id: revealed) {
            guard revealed else { landed = 0; return }
            guard landed < bests.count else { return }
            if reduceMotion { landed = bests.count; return }
            for index in bests.indices {
                landed = index + 1
                try? await Task.sleep(for: .milliseconds(160))
                if Task.isCancelled { return }
            }
        }
    }
}

private struct FinishBestRow: View {
    let best: FinishBestRowData
    let isLanded: Bool

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        HStack(alignment: ax ? .top : .center, spacing: 14) {
            if !look.id.isPaperClub { mark }
            VStack(alignment: .leading, spacing: 2) {
                Text(best.name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let equipment = best.equipment {
                    Text(equipment)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ax { valueBlock(alignment: .leading).padding(.top, 6) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !ax { valueBlock(alignment: .trailing) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, look.id.isPaperClub ? 14 : 12)
        .frame(minHeight: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = ["New best", best.name, Format.set(best.value, loadType: best.loadType)]
        if let previous = best.previous { parts.append("previous best \(Format.set(previous, loadType: best.loadType))") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private func valueBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            if look.id.isPaperClub {
                FinishHighlighter(isOn: isLanded) { color in
                    FinishSetValueText(value: best.value, loadType: best.loadType, size: .hero, color: color)
                }
            } else {
                FinishSetValueText(value: best.value, loadType: best.loadType, size: .hero)
            }
            if let previous = best.previous {
                FinishPreviousBestText(value: previous, loadType: best.loadType)
                    .opacity(isLanded ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.25), value: isLanded)
            }
        }
    }

    /// A's outlined burst stamp / B's pearl star medal.
    @ViewBuilder private var mark: some View {
        switch look.id {
        case .floodlight:
            FinishBurstStamp(isLanded: isLanded)
        default:
            FinishStarMedal(isLanded: isLanded)
        }
    }
}

/// A: a 40 pt flood outline with `burst.fill`, flipping in like a scoreboard card.
private struct FinishBurstStamp: View {
    let isLanded: Bool
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(look.positive, lineWidth: 1.5)
            .overlay {
                Image(systemName: "burst.fill")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(look.positive)
            }
            .frame(width: side, height: side)
            .rotation3DEffect(.degrees(isLanded || reduceMotion ? 0 : 90), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .opacity(isLanded || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.62), value: isLanded)
            .accessibilityHidden(true)
    }
}

/// B: a pearl star on a pearl 12 % disc; on landing a pearl halo shines outward once.
private struct FinishStarMedal: View {
    let isLanded: Bool
    @State private var halo = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(.subheadline, weight: .heavy))
            .foregroundStyle(look.textPrimary)
            .frame(width: side, height: side)
            .background(look.positive.opacity(0.12), in: Circle())
            .background {
                Circle()
                    .stroke(look.positive.opacity(halo ? 0 : 0.55), lineWidth: 2)
                    .scaleEffect(halo ? 1.9 : 1)
            }
            .scaleEffect(isLanded || reduceMotion ? 1 : 0.4)
            .opacity(isLanded || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.58), value: isLanded)
            .onChange(of: isLanded) { _, landed in
                guard landed, !reduceMotion else { return }
                halo = false
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) { halo = true }
            }
            .onAppear { if isLanded || reduceMotion { halo = true } }
            .accessibilityHidden(true)
    }
}

/// C: the yellow highlighter swiped across a value left to right (0.4 s). The value is drawn
/// twice — in its own colours, and in ink on the highlighter — and the swipe reveals the inked
/// copy, so the text changes colour exactly where the pen passes (never ink on the dark sheet).
/// Reduce Motion: already drawn.
struct FinishHighlighter<Content: View>: View {
    let isOn: Bool
    var delay: Double = 0
    /// The value, drawn with a colour override (nil = its own colours).
    @ViewBuilder let content: (Color?) -> Content
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = isOn || reduceMotion
        ZStack {
            content(nil)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
            content(look.onPositive)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(look.positive, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .mask(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .frame(width: shown ? geo.size.width : 0)
                            .animation(reduceMotion || !shown ? nil : .easeOut(duration: 0.4).delay(delay), value: shown)
                    }
                }
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Comparison with the last run of the template

/// A: "Last Push Day" header over the panel. B: no header; "vs Push Day, Sep 17" inside.
/// C: "Last time" header; "Total volume · Push Day" inside. Hidden without a baseline.
struct FinishComparisonSection: View {
    let comparison: TemplateComparison
    let unit: WeightUnit
    @Environment(\.look) private var look

    var body: some View {
        let date = Format.shortDate(comparison.lastDate)
        VStack(alignment: .leading, spacing: look.space.header) {
            switch look.id {
            case .floodlight: SectionHeader("Last \(comparison.templateName)")
            case .anatomy: EmptyView()
            case .paper, .carbon: SectionHeader("Last time")
            }
            ComparisonBars(
                context: look.id == .anatomy ? "vs \(comparison.templateName), \(date)"
                    : (look.id.isPaperClub ? comparison.templateName : nil),
                lastLabel: date,
                last: unit.fromKg(comparison.lastVolumeKg),
                today: unit.fromKg(comparison.volumeKg),
                unit: unit.label)
        }
    }
}

// MARK: - Families trained

/// B: the "Working sets" card — all five maps, the trained ones light (with their counts)
/// when the card is revealed. C: "Muscle groups" — one tile per trained family that lands
/// when revealed. (A carries its families as the ring's key in the header.)
struct FinishFamiliesSection: View {
    let data: FinishData
    let revealed: Bool
    /// Draw lit at once (Reduce Motion, frozen captures).
    let instant: Bool

    @Environment(\.look) private var look

    /// B's maps stay unlit until the card is revealed: FamilyTallyGroup lights a map once,
    /// `appearDelay` after it appears, so the group is re-created on reveal with a short
    /// delay (and held unlit before it).
    private static let holdUnlit: Double = 86_400

    var body: some View {
        switch look.id {
        case .floodlight:
            EmptyView()
        case .anatomy:
            VStack(alignment: .leading, spacing: 14) {
                Text("Working sets")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                FamilyTallyGroup(counts: data.familyTotals, mapSize: 58,
                                 appearDelay: instant ? nil : (revealed ? 0.05 : Self.holdUnlit),
                                 stagger: 0.09, spacing: 4, hidesZeroCounts: true)
                    .id(instant || revealed)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.card)
        case .paper, .carbon:
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Muscle groups")
                FinishFamilyTiles(counts: data.trainedFamilies, revealed: instant || revealed)
            }
        }
    }
}

/// C's Muscle groups: one tile per trained family — a solid family-colour band over a wash
/// of the family colour holding its map — then the name and "N working sets". The tiles land
/// (dropping in, 0.32 s, 0.1 s apart) and their maps light as they land. AX: one column of
/// rows (tile · name · count). Reduce Motion: landed.
struct FinishFamilyTiles: View {
    let counts: [FamilyCount]
    let revealed: Bool

    @State private var landed: Int
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(counts: [FamilyCount], revealed: Bool) {
        self.counts = counts
        self.revealed = revealed
        _landed = State(initialValue: revealed ? counts.count : 0)
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    ForEach(Array(counts.enumerated()), id: \.element.id) { index, count in
                        HStack(spacing: 14) {
                            tile(count, lit: index < landed, mapSize: 46).frame(width: 64, height: 64)
                            VStack(alignment: .leading, spacing: 2) {
                                name(count)
                                sets(count)
                            }
                            Spacer(minLength: 0)
                        }
                        .modifier(FinishLanding(landed: index < landed))
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                // At most three tiles a row, so "Shoulders" and "N working sets" never break
                // (a whole-body day's five families sit as 3 + 2).
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                         count: min(3, max(1, counts.count))),
                          alignment: .leading, spacing: 16) {
                    ForEach(Array(counts.enumerated()), id: \.element.id) { index, count in
                        VStack(spacing: 4) {
                            tile(count, lit: index < landed, mapSize: 62)
                                .frame(maxWidth: .infinity)
                                .frame(height: 96)
                                .padding(.bottom, 6)
                            name(count)
                            sets(count).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .modifier(FinishLanding(landed: index < landed))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .task(id: revealed) {
            guard revealed else { landed = 0; return }
            guard landed < counts.count else { return }
            if reduceMotion { landed = counts.count; return }
            for index in counts.indices {
                landed = index + 1
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
            }
        }
    }

    private func tile(_ count: FamilyCount, lit: Bool, mapSize: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let colour = look.family(count.family)
        return MuscleMap(family: count.family, lit: lit, size: mapSize)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack(alignment: .top) {
                    // Paper keeps its pale tint; Carbon washes with the family colour itself
                    // (its muted tints read as maroon and brown on the carbon sheet).
                    look.id == .carbon ? colour.opacity(0.22) : look.familyTint(count.family)
                    colour.frame(height: 7)
                }
            }
            .clipShape(shape)
            .overlay { shape.strokeBorder(look.hairline, lineWidth: 1.5) }
    }

    private func name(_ count: FamilyCount) -> some View {
        Text(count.family.label)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sets(_ count: FamilyCount) -> some View {
        Text("\(count.sets) working \(count.sets == 1 ? "set" : "sets")")
            .font(look.font.caption)
            .foregroundStyle(look.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A tile dropping onto the page: from above, slightly large and clear, to rest.
private struct FinishLanding: ViewModifier {
    let landed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: landed || reduceMotion ? 0 : -16)
            .scaleEffect(landed || reduceMotion ? 1 : 1.07)
            .opacity(landed || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.7), value: landed)
    }
}

// MARK: - Heart rate

/// The range chart with time in zones directly below it (no tap). A panel (A), a card (B)
/// or C's ink slab. Axis labels: elapsed time (A, C) or clock times (B).
struct FinishHeartRateSection: View {
    let summary: FinishSummary
    let slots: [HRSlot]
    /// Time in zones from the same trace as the bars (FinishData.zoneSeconds).
    let zoneSeconds: [Int]
    let maxHeartRate: Int?
    let revealed: Bool

    @Environment(\.look) private var look

    var body: some View {
        HeartRatePlate {
            if !slots.isEmpty { chart.finishAnchor() }
            if !Derived.zoneTimes(zoneSeconds).isEmpty {
                ZoneBreakdown(seconds: zoneSeconds).finishAnchor()
            }
        }
    }

    @ViewBuilder private var chart: some View {
        let start = look.id == .anatomy ? Format.time(summary.date) : "0:00"
        let end = look.id == .anatomy
            ? Format.time(summary.date.addingTimeInterval(TimeInterval(summary.durationSeconds)))
            : Format.elapsed(summary.durationSeconds)
        // No max heart rate: no zones, so every bar takes the plain heart-rate step.
        let bounds = maxHeartRate.map { max in
            HeartRateZone.allCases.map { Int((Double(max) * $0.lowerFraction).rounded()) }
        } ?? [0, 0, 0, 0, 1000, 1000]
        FinishHeartRateChart(slots: slots, zoneBounds: bounds, startLabel: start, endLabel: end, revealed: revealed)
    }
}

// MARK: - Exercises

/// "Exercises" ("Lifting" when cardio is also on the receipt): name, "equipment · N sets",
/// and the best set trailing. A marks a new best with a burst, B with a star, C with the
/// highlighter; each lands (staggered) when the list is revealed. A first-ever exercise
/// carries the "First time" badge (never a new best). A adds the "best" column caption.
/// AX: the best drops under the name.
struct FinishExercisesSection: View {
    let rows: [FinishExerciseRowData]
    let title: String
    let revealed: Bool

    @Environment(\.look) private var look

    var body: some View {
        let bestOrder = rows.filter(\.isNewBest).map(\.id)
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(title, trailing: look.id == .floodlight ? "best" : nil)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { LookDivider().padding(.leading, 16) }
                    FinishExerciseRow(row: row, marked: revealed,
                                      delay: Double(bestOrder.firstIndex(of: row.id) ?? 0) * 0.14)
                        .finishAnchor()
                }
            }
            .lookSurface(.panel)
        }
    }
}

private struct FinishExerciseRow: View {
    let row: FinishExerciseRowData
    let marked: Bool
    let delay: Double

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(.body, weight: look.id == .floodlight || look.id == .anatomy ? .semibold : .medium))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.detail)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if row.isFirstTime {
                    NewBestBadge(kind: .firstTime).padding(.top, 4)
                }
                if ax, row.best != nil { best.padding(.top, 4) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !ax, row.best != nil { best }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [row.name, row.detail]
        if let value = row.best {
            parts.append("best \(Format.set(value, loadType: row.loadType))")
            if row.isNewBest { parts.append("new best") }
        }
        if row.isFirstTime { parts.append("first time") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private var best: some View {
        if let value = row.best {
            switch look.id {
            case .floodlight, .anatomy:
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if row.isNewBest {
                        Image(systemName: look.id == .floodlight ? "burst.fill" : "star.fill")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(look.positive)
                            .scaleEffect(marked || reduceMotion ? 1 : 0.2)
                            .opacity(marked || reduceMotion ? 1 : 0)
                            .animation(reduceMotion || !marked ? nil : .spring(response: 0.34, dampingFraction: 0.5).delay(delay),
                                       value: marked)
                    }
                    FinishSetValueText(value: value, loadType: row.loadType, size: .row)
                }
            case .paper, .carbon:
                if row.isNewBest {
                    FinishHighlighter(isOn: marked, delay: delay) { color in
                        FinishSetValueText(value: value, loadType: row.loadType, size: .row, color: color)
                    }
                } else {
                    FinishSetValueText(value: value, loadType: row.loadType, size: .row)
                        .padding(.horizontal, 7)
                }
            }
        }
    }
}
