import SwiftUI

// Pieces of the finish receipt (Floodlight redesign; the prototype's Screens/Finish).

extension View {
    /// A bare list row on the receipt: no separator, no background, the 20 pt margin.
    func finishRow(top: CGFloat, bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Status header

/// The kept receipt top: the status ring and "Workout saved" + the summary. The ring is one
/// segment per completed set in its family's colour, in workout order (it agrees with the set
/// count), and its key — each family's map with the number of segments it lit — sits under the
/// text. "Nothing to save": an empty ring and the reason (A2). AX sizes: the ring above the text.
struct FinishHeader: View {
    var saved: Bool
    var title: String?
    var gymName: String?
    var countLine: String?
    var summaryLine: String
    /// The ring (every completed set, in workout order) and its key (mapped families' totals).
    var ringRuns: [RingRun]
    var families: [FamilyCount]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var keySize: CGFloat = 36

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        layout {
            ring
            VStack(alignment: .leading, spacing: 4) {
                Text(saved ? "Workout saved" : "Nothing to save")
                    .font(look.font.title)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if saved {
                    let place = [title, gymName].compactMap { $0 }.joined(separator: " · ")
                    if !place.isEmpty {
                        Text(place).font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                // The kept summary line (its identifier and words are tested).
                Text(saved ? (countLine ?? summaryLine) : summaryLine)
                    .font(saved ? look.font.caption : look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(summaryLine)
                    .accessibilityIdentifier("finishedSummary")
                if saved && !families.isEmpty { key.padding(.top, 8) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var ring: some View {
        if saved && ringRuns.contains(where: { $0.sets > 0 }) {
            FinishStatusRing(segments: ringRuns, size: 112)
        } else {
            ZStack {
                Circle().stroke(look.ringTrack, lineWidth: 10).padding(5)
                Image(systemName: saved ? "checkmark" : "tray")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(saved ? look.textPrimary : look.textTertiary)
            }
            .frame(width: 112, height: 112)
            .accessibilityHidden(true)
        }
    }

    /// Each family's map with its set count in the family colour, in ring order. Wraps.
    private var key: some View {
        let size = min(keySize, 46)
        return TemplateFlowLayout(spacing: 12, lineSpacing: 6) {
            ForEach(families) { count in
                HStack(alignment: .center, spacing: 3) {
                    MuscleMap(family: count.family, lit: true, size: size)
                    Text("\(count.sets)")
                        .font(Font.system(.headline, weight: .semibold).monospacedDigit())
                        .foregroundStyle(look.family(count.family))
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(count.family.label), \(HistoryRendering.pluralized(count.sets, "set", "sets"))")
            }
        }
    }
}

// MARK: - Stat tiles

extension FinishTile {
    /// Workout details for a summary, in the user's order (ticket 17) — time / volume, active /
    /// total calories, average / max heart rate — each OMITTED, not zeroed, when its fact is
    /// missing (D44). Volume in `unit`, plain (D52), grouped with its precision (≤ 2 decimals,
    /// D25: 7.5, not 8). Shared by the receipt and History's detail; `identifier` names each tile.
    static func summaryTiles(_ summary: WorkoutSummary, unit: WeightUnit,
                             identifier: (FinishTileKind) -> String) -> [(tile: FinishTile, id: String)] {
        var tiles: [FinishTile] = [
            FinishTile(kind: .workoutTime, value: Format.duration(seconds: Int(summary.workoutTime)), unit: ""),
        ]
        if summary.totalVolumeKg > 0 {
            let volume = WeightMath.convert(summary.totalVolumeKg, from: .kg, to: unit)
            tiles.append(FinishTile(kind: .totalVolume, value: LookFormat.groupedDecimal(volume), unit: unit.label))
        }
        if let calories = summary.activeEnergyKilocalories {
            tiles.append(FinishTile(kind: .activeCalories, value: "\(Int(calories.rounded()))", unit: "cal"))
        }
        // Total = active + basal, only when the system gave both (D9/D25).
        if let total = summary.totalEnergyKilocalories {
            tiles.append(FinishTile(kind: .totalCalories, value: "\(Int(total.rounded()))", unit: "cal"))
        }
        if let average = summary.averageHeartRate {
            tiles.append(FinishTile(kind: .averageHeartRate, value: "\(average)", unit: "bpm"))
        }
        if let maximum = summary.maxHeartRate {
            tiles.append(FinishTile(kind: .maxHeartRate, value: "\(maximum)", unit: "bpm"))
        }
        return tiles.map { ($0, identifier($0.kind)) }
    }
}


/// The paired tiles as one scoreboard panel split by hairlines; one column at AX sizes. Each
/// tile carries its identifier (`summaryTime` …).
struct FinishTileGrid: View {
    var tiles: [(tile: FinishTile, id: String)]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private var rows: [[(tile: FinishTile, id: String)]] {
        let groups = Dictionary(grouping: tiles) { StatPairGrid.pairIndex($0.tile.kind) }
        return groups.keys.sorted().map { groups[$0]! }
    }

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { LookDivider() }
                let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
                layout {
                    ForEach(Array(row.enumerated()), id: \.element.id) { i, item in
                        if i > 0 { LookDivider(vertical: !stacked) }
                        cell(item.tile).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier(item.id)
                    }
                    if row.count == 1 && !stacked {
                        LookDivider(vertical: true)
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .lookSurface(.stat)
    }

    private func cell(_ tile: FinishTile) -> some View {
        let isHeart = tile.kind == .averageHeartRate || tile.kind == .maxHeartRate
        return StatFigure(value: tile.value, unit: tile.unit.isEmpty ? nil : tile.unit, label: tile.label,
                          symbol: tile.kind.symbol, tint: isHeart ? look.heartRate : nil,
                          symbolTint: isHeart ? look.heartRate : nil, countsUp: true)
            .padding(16)
    }
}

// MARK: - New bests

/// One new best: the burst stamp, the exercise and its equipment, the value big and the best it
/// beat struck through beneath it.
struct FinishBestRow: View {
    var best: FinishReceipt.Best
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        HStack(alignment: ax ? .top : .center, spacing: 14) {
            Image(systemName: "burst.fill")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(look.positive)
                .frame(width: 40, height: 40)
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(look.positive, lineWidth: 2) }
                .rotation3DEffect(.degrees(landed || reduceMotion ? 0 : 90), axis: (x: 1, y: 0, z: 0))
            VStack(alignment: .leading, spacing: 2) {
                Text(best.exerciseName)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let equipment = best.equipment {
                    Text(equipment).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                if ax { values(alignment: .leading).padding(.top, 6) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !ax { values(alignment: .trailing) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .onAppear {
            guard !reduceMotion else { landed = true; return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.15)) { landed = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("finishNewBest")
    }

    private func values(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            FinishSetValueText(value: best.value, loadType: best.loadType, big: true, alignment: alignment)
            if let previous = best.previous {
                Text(LookFormat.set(previous, loadType: best.loadType))
                    .font(.system(.footnote, weight: .semibold))
                    .strikethrough()
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(look.textSecondary)
            }
        }
    }

    private var spoken: String {
        // The scope is part of the record (two machines are two records), so it is spoken too.
        var parts = ["New best", best.exerciseName]
        if let equipment = best.equipment { parts.append(equipment) }
        parts.append(LookFormat.set(best.value, loadType: best.loadType))
        if let previous = best.previous { parts.append("previous best \(LookFormat.set(previous, loadType: best.loadType))") }
        return parts.joined(separator: ", ")
    }
}

/// "110 lb × 8": the numbers heavy, the unit and × small; reps only for bodyweight. A bar-mode
/// set says which bar on its own line beneath ("(45 lb bar)", D39), so the load line stays one
/// line at any size and the annotation wraps instead of pushing past the panel.
struct FinishSetValueText: View {
    var value: SetValue
    var loadType: LoadType
    var big = false
    var alignment: HorizontalAlignment = .trailing
    @Environment(\.look) private var look

    var body: some View {
        let numberFont = big ? Font.system(.title3, weight: .semibold).monospacedDigit()
                             : Font.system(.subheadline, weight: .semibold).monospacedDigit()
        VStack(alignment: alignment, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if loadType.takesWeight, let weight = value.weight {
                    Text(LookFormat.weight(weight)).font(numberFont)
                    Text(value.unit.label).font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
                    Text("×").font(.system(.subheadline, weight: .bold)).foregroundStyle(look.textSecondary)
                    Text("\(value.reps)").font(numberFont)
                } else {
                    Text("\(value.reps)").font(numberFont)
                    Text(value.reps == 1 ? "rep" : "reps").font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
            }
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .fixedSize()
            if loadType.takesWeight, value.weight != nil, let bar = value.bar {
                Text("(\(LookFormat.weight(bar, value.unit)) bar)")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Exercises

/// One exercise: its name, the snapshot equipment and set count, and its best set, with the
/// New best / First time mark.
struct FinishExerciseRow: View {
    var row: FinishReceipt.ExerciseRow
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.detail).font(look.font.footnote).foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                if let best = row.best {
                    FinishSetValueText(value: best, loadType: row.loadType,
                                       alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
                }
                if let badge = row.badge { NewBestBadge(kind: badge) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

// MARK: - Saved as template

/// "Saved as template “Push Day copy”" in the Save as Template slot: a check that stamps in
/// once. Reduce Motion: it simply appears.
struct FinishSavedTemplateLine: View {
    let name: String
    @State private var stamped = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(.footnote, weight: .heavy))
                .foregroundStyle(look.onDone)
                .frame(width: 26, height: 26)
                .background(look.done, in: Circle())
                .scaleEffect(stamped || reduceMotion ? 1 : 1.6)
                .rotationEffect(.degrees(stamped || reduceMotion ? 0 : look.motion.stampRotation))
                .opacity(stamped || reduceMotion ? 1 : 0)
            Text("Saved as template “\(name)”")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .onAppear {
            guard !reduceMotion else { stamped = true; return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55).delay(0.15)) { stamped = true }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Soft redesign S3: the receipt leads with what was won (Direction A)

/// The first new best, big — the exercise, the new figure, what it beat — then any others as the compact rows
/// (the prototype's `ProposedBestsHero`). Spoken and identified as each best's row was (`finishNewBest`).
struct FinishBestsHero: View {
    var bests: [FinishReceipt.Best]
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = bests.first { lead(first) }
            ForEach(bests.dropFirst()) { best in
                LookDivider().padding(.vertical, 4)
                FinishBestRow(best: best).padding(.horizontal, -16)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .sensoryFeedback(.success, trigger: bests.count)
        .onAppear {
            if reduceMotion { shown = true } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.35)) { shown = true }
            }
        }
    }

    private func lead(_ best: FinishReceipt.Best) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "burst.fill")
                Text(bests.count == 1 ? "New best" : "\(bests.count) new bests")
            }
            .font(.system(.subheadline, weight: .bold))
            .foregroundStyle(look.textPrimary)
            Text(best.exerciseName)
                .font(look.font.cardTitle)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(LookFormat.set(best.value, loadType: best.loadType))
                .font(look.font.heroNumber)
                .foregroundStyle(look.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .scaleEffect(shown ? 1 : 0.82, anchor: .leading)
                .opacity(shown ? 1 : 0)
            let was = [best.previous.map { "was \(LookFormat.set($0, loadType: best.loadType))" }, best.equipment]
                .compactMap { $0 }
            if !was.isEmpty {
                Text(was.joined(separator: " · "))
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(best))
        .accessibilityIdentifier("finishNewBest")
    }

    private func spoken(_ best: FinishReceipt.Best) -> String {
        var parts = ["New best", best.exerciseName]
        if let equipment = best.equipment { parts.append(equipment) }
        parts.append(LookFormat.set(best.value, loadType: best.loadType))
        if let previous = best.previous { parts.append("previous best \(LookFormat.set(previous, loadType: best.loadType))") }
        return parts.joined(separator: ", ")
    }
}

/// The summary as a short receipt: one row per fact, label leading, figures trailing, hairlines between (no
/// tiles) — Time · Exercises and sets · Volume · Calories active / total · Heart rate avg / max (the prototype's
/// `ProposedSummaryList`). The figures come from the same `FinishTile`s, so absent facts are omitted exactly as
/// the tiles were (D44/D52); each figure keeps its tile's identifier and is spoken with its tile's label.
struct FinishReceiptList: View {
    /// `FinishTile.summaryTiles`: each figure with its identifier.
    var tiles: [(tile: FinishTile, id: String)]
    var exerciseCount: Int
    var setCount: Int
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Part: Identifiable {
        var id: String
        var figure: String
        var unit: String
        var spoken: String
    }

    private struct Row: Identifiable {
        var id: String
        var label: String
        var symbol: String
        var parts: [Part]
        var tint = false
    }

    private func part(_ kind: FinishTileKind, unit: String? = nil) -> Part? {
        guard let (tile, id) = tiles.first(where: { $0.tile.kind == kind }) else { return nil }
        return Part(id: id, figure: tile.value, unit: unit ?? tile.unit,
                    spoken: "\(tile.label) \(tile.value) \(tile.unit)")
    }

    private var rows: [Row] {
        var rows: [Row] = []
        if let time = part(.workoutTime) {
            rows.append(Row(id: "time", label: "Time", symbol: "stopwatch", parts: [time]))
        }
        if setCount > 0 {
            let exercises = exerciseCount == 1 ? "exercise" : "exercises"
            let sets = setCount == 1 ? "set" : "sets"
            rows.append(Row(id: "work", label: "Exercises", symbol: "list.bullet", parts: [
                Part(id: "summaryExerciseCount", figure: "\(exerciseCount)", unit: exercises,
                     spoken: "\(exerciseCount) \(exercises)"),
                Part(id: "summarySetCount", figure: "\(setCount)", unit: sets, spoken: "\(setCount) \(sets)"),
            ]))
        }
        if let volume = part(.totalVolume) {
            rows.append(Row(id: "volume", label: "Volume", symbol: "scalemass", parts: [volume]))
        }
        let calories = [part(.activeCalories, unit: "active"), part(.totalCalories, unit: "total cal")].compactMap { $0 }
        if !calories.isEmpty {
            rows.append(Row(id: "cal", label: "Calories", symbol: "flame", parts: calories))
        }
        let heart = [part(.averageHeartRate, unit: "avg"), part(.maxHeartRate, unit: "max bpm")].compactMap { $0 }
        if !heart.isEmpty {
            rows.append(Row(id: "hr", label: "Heart rate", symbol: "heart.fill", parts: heart, tint: true))
        }
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { LookDivider().padding(.leading, 16) }
                line(row)
            }
        }
        .lookSurface(.panel)
        .accessibilityIdentifier("finishReceipt")
    }

    private func line(_ row: Row) -> some View {
        let stack = typeSize.isAccessibilitySize
        let layout = stack ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                           : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Label(row.label, systemImage: row.symbol)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(row.tint ? look.heartRate : look.textSecondary)
                .labelStyle(.titleAndIcon)
                .accessibilityHidden(true)
            if !stack { Spacer(minLength: 8) }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(Array(row.parts.enumerated()), id: \.element.id) { index, part in
                    if index > 0 {
                        Text("  ·  ").font(.footnote).foregroundStyle(look.textTertiary).accessibilityHidden(true)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(part.figure).font(look.font.smallNumber).foregroundStyle(look.textPrimary).monospacedDigit()
                        if !part.unit.isEmpty {
                            Text(" \(part.unit)").font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(part.spoken)
                    .accessibilityIdentifier(part.id)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
