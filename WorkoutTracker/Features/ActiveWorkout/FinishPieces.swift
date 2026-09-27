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
        if saved && !families.isEmpty {
            FinishStatusRing(segments: families, size: 112)
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
                        .font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
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
    }

    private func values(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            FinishSetValueText(value: best.value, loadType: best.loadType, big: true)
            if let previous = best.previous {
                Text(LookFormat.set(previous, loadType: best.loadType))
                    .font(.system(.footnote, weight: .semibold))
                    .strikethrough()
                    .foregroundStyle(look.textSecondary)
            }
        }
    }

    private var spoken: String {
        var parts = ["New best", best.exerciseName, LookFormat.set(best.value, loadType: best.loadType)]
        if let previous = best.previous { parts.append("previous best \(LookFormat.set(previous, loadType: best.loadType))") }
        return parts.joined(separator: ", ")
    }
}

/// "110 lb × 8": the numbers heavy, the unit and × small; reps only for bodyweight.
struct FinishSetValueText: View {
    var value: SetValue
    var loadType: LoadType
    var big = false
    @Environment(\.look) private var look

    var body: some View {
        let numberFont = big ? Font.system(.title3, weight: .heavy).width(.expanded).monospacedDigit()
                             : Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit()
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
                if let best = row.best { FinishSetValueText(value: best, loadType: row.loadType) }
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
