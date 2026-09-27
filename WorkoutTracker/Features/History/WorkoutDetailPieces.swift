import SwiftUI

// Floodlight redesign ticket 05 — the workout detail's pieces: the hero (ring + date, title,
// time and gym, marks, Edited), an exercise's header, a logged set's line and the dashed
// "make one" row. History shows frozen snapshot names only (D23).

// MARK: - Hero ring

/// The detail hero: one segment per WORKING set in its family colour, in workout order, with the
/// count in the middle (warmups stay out, so a finished ring is always fully lit). Family-less
/// sets (Core, Full Body, unclassified) are lit in ink, never left grey.
struct HistoryHeroRing: View {
    /// Working sets in workout order, with their family.
    var sets: [MuscleFamily?]
    var size: CGFloat = 112
    @State private var drawn = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Int { sets.count }
    private var label: String { total == 1 ? "working set" : "working sets" }

    var body: some View {
        let width = size * 0.085
        ZStack {
            if total > 0 && total <= 40 {
                ForEach(0..<total, id: \.self) { index in
                    let step = 1.0 / Double(total)
                    RingArc(start: Double(index) * step + step * 0.13, end: Double(index + 1) * step - step * 0.13)
                        .stroke(drawn || reduceMotion ? color(sets[index]) : look.ringTrack, style: StrokeStyle(lineWidth: width))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.16).delay(Double(index) * 0.024), value: drawn)
                }
            } else if total > 40 {
                runs(width: width)
            } else {
                Circle().stroke(look.ringTrack, lineWidth: width)
            }
            VStack(spacing: 0) {
                Text("\(total)")
                    .font(look.font.bigNumber)
                    .foregroundStyle(look.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: size * 0.66)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .padding(width / 2)
        .frame(width: size, height: size)
        .onAppear { if !drawn { drawn = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total) \(label)")
    }

    private func color(_ family: MuscleFamily?) -> Color {
        family.map { look.family($0) } ?? look.textPrimary
    }

    /// More than 40 sets: consecutive runs of one family.
    private func runs(width: CGFloat) -> some View {
        var groups: [(family: MuscleFamily?, count: Int)] = []
        for family in sets {
            if let last = groups.last, last.family == family {
                groups[groups.count - 1].count += 1
            } else {
                groups.append((family, 1))
            }
        }
        let fractions = groups.map { Double($0.count) / Double(max(1, total)) }
        let starts = fractions.indices.map { i in fractions[..<i].reduce(0, +) }
        return ZStack {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                RingArc(start: starts[index] + 0.002, end: max(starts[index] + 0.003, starts[index] + fractions[index] - 0.002))
                    .stroke(color(group.family), style: StrokeStyle(lineWidth: width))
            }
        }
    }
}

// MARK: - Hero

/// The ring beside the date, the title (tap to rename), time range and gym; the families, the
/// new-best count and the unit badge; the Edited line. AX sizes: the ring above the text.
struct HistoryDetailHero: View {
    var workout: Workout
    var ringSets: [MuscleFamily?]
    var families: [MuscleFamily]
    var newBests: Int
    var unitBadge: String?
    var onRename: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private var hasLifting: Bool { !ringSets.isEmpty }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
        VStack(alignment: .leading, spacing: 14) {
            layout {
                if hasLifting { HistoryHeroRing(sets: ringSets) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(HistoryFormat.dayTitle(workout.startedAt))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .accessibilityIdentifier("historyWorkoutDate")
                    HistoryTitleButton(title: workout.historyTitle, action: onRename)
                    Text(meta)
                        .font(look.font.subhead)
                        .monospacedDigit()
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !families.isEmpty || newBests > 0 || unitBadge != nil {
                WrapLayout(spacing: 10, lineSpacing: 8) {
                    if !families.isEmpty {
                        FamilyStrip(families: families, size: 30, spacing: 2)
                            .accessibilityIdentifier("historyHeroFamilies")
                    }
                    if newBests > 0 { HistoryPRMark(count: newBests) }
                    if let unitBadge { HistoryTextBadge(unitBadge) }
                }
            }
            if let edited = workout.historyEditedAt {
                // The existing mark (D47): "Edited Sep 20, 2026 at 8:40 AM".
                Label("Edited \(edited.formatted(date: .abbreviated, time: .shortened))", systemImage: "pencil.circle")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .accessibilityIdentifier("historyEditedMark")
            }
        }
    }

    /// "10:30 AM – 11:37 AM · Iron Temple"
    private var meta: String {
        var parts = [HistoryFormat.timeRange(workout.startedAt, workout.finishedAt)]
        if let gym = workout.historyGymName { parts.append(gym) }
        return parts.joined(separator: " · ")
    }
}

/// The workout title as the button that renames it (a small pencil says so).
struct HistoryTitleButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(look.font.title)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "pencil")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(title)
        .accessibilityHint("Renames the workout")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("historyWorkoutName")
    }
}

// MARK: - Exercise header

/// One exercise: its superset letter, name, the progress-chart button and the "…" menu on the
/// title's first line; the snapshot equipment with its glyph and a load-type badge when not
/// weighted; the D51 "Reclassified from…" line.
struct HistoryEntryHeader<Menu: View>: View {
    var entry: ExerciseEntry
    var letter: String?
    var onChart: () -> Void
    @ViewBuilder var menu: Menu
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 22
    @ScaledMetric(relativeTo: .title3) private var titleCentreToBaseline: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let letter {
                    HistorySupersetLetter(letter: letter)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + titleCentreToBaseline }
                }
                Text(entry.snapshotExerciseName)
                    .font(look.font.cardTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 4) {
                    CardIconButton("chart.line.uptrend.xyaxis", accessibilityLabel: "Progress chart", action: onChart)
                        .accessibilityIdentifier("historyEntryChart")
                    menu
                }
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + titleCentreToBaseline }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if entry.snapshotMachineID == nil && entry.snapshotFreeWeightTag == .barbell {
                        HistoryBarbellGlyph()
                    } else {
                        LookIcon(entry.snapshotMachineLabel != nil ? LookIcon.machine
                                 : (entry.snapshotFreeWeightTag?.historySymbol ?? "circle.dashed"),
                                 style: .footnote)
                    }
                }
                .foregroundStyle(look.textSecondary)
                .frame(width: glyphColumn)
                Text(entry.snapshotEquipmentLabel)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if entry.snapshotLoadType != .weighted { HistoryTextBadge(entry.snapshotLoadType.badge) }
            }
            // D51: a reclassified row says what it was, on the row.
            if let from = entry.reclassifiedFromExerciseName, let when = entry.reclassifiedAt {
                Text("Reclassified from \(from) · \(when.formatted(date: .abbreviated, time: .omitted))")
                    .font(look.font.caption)
                    .foregroundStyle(look.textSecondary)
                    .padding(.leading, glyphColumn + 8)
                    .accessibilityIdentifier("historyReclassifiedMark")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

extension EquipmentTag {
    /// The glyph beside History's equipment line (the barbell has its own drawn glyph).
    var historySymbol: String {
        switch self {
        case .machine, .smith: LookIcon.machine
        case .barbell, .dumbbell: "dumbbell"
        case .cable: "cable.connector"
        case .bodyweight: "figure.stand"
        }
    }
}

/// Superset letter ("A", "B") beside an exercise name.
struct HistorySupersetLetter: View {
    var letter: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Text(letter)
            .font(.system(.footnote, weight: .heavy))
            .foregroundStyle(look.textPrimary)
            .frame(width: side, height: side)
            .overlay { shape.strokeBorder(look.textPrimary.opacity(0.42), lineWidth: 1.5) }
            .accessibilityLabel("Superset \(letter)")
    }
}

/// The face of a card icon button, for use as a Menu label (the exercise's "…" menu).
struct HistoryIconFace: View {
    var symbol: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var visual: CGFloat = 32

    var body: some View {
        let outset = max(0, (44 - visual) / 2)
        Image(systemName: symbol)
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(look.textSecondary)
            .frame(width: visual, height: visual)
            .padding(outset)
            .contentShape(Rectangle())
            .padding(-outset)
    }
}

// MARK: - Set line

/// A logged set: marker · value (number big, unit small) · bar breakdown · new-best mark · a
/// faint pencil. The whole row edits; swiping deletes (the caller's list row).
struct HistorySetLine: View {
    /// Named `record`: a bare `set` in a computed property reads as a setter.
    var record: SetRecord
    /// The working-set number (warmups are not counted, as in the live table).
    var number: Int
    var loadType: LoadType
    var badge: SetBadge?
    /// The convert toggle's unit (D9/D52: display only); nil = as entered.
    var displayUnit: WeightUnit?
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SetMarker(kind: record.type, number: number, done: true)
            VStack(alignment: .leading, spacing: 2) {
                value
                if let breakdown {
                    Text(breakdown).font(look.font.caption).foregroundStyle(look.textSecondary)
                }
                if typeSize.isAccessibilitySize, let badge { NewBestBadge(kind: badge) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize, let badge { NewBestBadge(kind: badge) }
            Image(systemName: "pencil")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(look.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint("Edits the set")
    }

    /// The weight under the toggle: as entered, or converted plain (WeightMath, D25/D52).
    private var shown: (value: Double, unit: WeightUnit)? {
        guard let value = record.weightValue, let stored = StoredWeight(value: value, unit: record.weightUnit) else { return nil }
        let unit = displayUnit ?? stored.unit
        return (WeightMath.convert(value, from: stored.unit, to: unit), unit)
    }

    /// D39: how a bar-mode set was loaded — "45 + 45 × 2 = 135 lb". Shown as entered only: a
    /// converted sum of two converted parts reads as arithmetic the app is claiming.
    private var breakdown: String? {
        guard displayUnit == nil || displayUnit == record.weightUnit,
              let bar = record.barWeightValue, let total = record.weightValue else { return nil }
        return BarbellMath.breakdownLabel(barWeight: bar, total: total, unit: record.weightUnit)
    }

    private var repsText: String { record.reps.map(String.init) ?? "—" }

    @ViewBuilder private var value: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if loadType.takesWeight {
                if let shown {
                    Text(LookFormat.number(shown.value)).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                    Text(shown.unit.rawValue).font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
                } else {
                    Text("—").font(look.font.fieldNumber).foregroundStyle(look.textTertiary)
                }
                Text("×").font(look.font.subhead).foregroundStyle(look.textSecondary).padding(.horizontal, 1)
                Text(repsText).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
            } else {
                Text(repsText).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                Text(record.reps == 1 ? "rep" : "reps").font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
            }
        }
        .monospacedDigit()
    }

    /// "Set 2, 135 lb × 10, 45 + 45 × 2 = 135 lb, New best" — the old line's words, in order.
    private var spoken: String {
        var parts = [record.type == .working ? "Set \(number)" : record.type.displayName]
        if loadType.takesWeight {
            let weight = record.weightValue
                .flatMap { StoredWeight(value: $0, unit: record.weightUnit) }
                .map { WeightMath.displayLabel(for: $0, in: displayUnit ?? $0.unit) } ?? "—"
            parts.append("\(weight) × \(repsText)")
        } else {
            parts.append("\(repsText) \(record.reps == 1 ? "rep" : "reps")")
        }
        if let breakdown { parts.append(breakdown) }
        if let badge { parts.append(badge == .newBest ? "New best" : "First time") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Make row

/// A dashed "make one" row (Add Exercise…, Add Note…).
struct HistoryMakeRow: View {
    var title: String
    var symbol: String = "plus"
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 52

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(.body, weight: .semibold))
                Text(title).font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(look.textPrimary)
            .frame(maxWidth: .infinity, minHeight: height)
            .dashedOutline(look.dash, radius: look.radius.panel, lineWidth: 1.5, dash: [6, 4])
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }
}

// MARK: - Barbell glyph

/// A barbell (bar, collars and plates), so "Barbell" does not borrow the Workout tab's figure.
struct HistoryBarbellGlyph: View {
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 20

    var body: some View {
        HistoryBarbellShape()
            .frame(width: width, height: width * 0.6)
            .accessibilityHidden(true)
    }
}

struct HistoryBarbellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height, mid = rect.midY
        let barH = max(1.4, h * 0.14)
        path.addRoundedRect(in: CGRect(x: rect.minX, y: mid - barH / 2, width: w, height: barH),
                            cornerSize: CGSize(width: barH / 2, height: barH / 2))
        func plate(_ x: CGFloat, _ pw: CGFloat, _ ph: CGFloat) {
            path.addRoundedRect(in: CGRect(x: rect.minX + x, y: mid - ph / 2, width: pw, height: ph),
                                cornerSize: CGSize(width: pw * 0.35, height: pw * 0.35))
        }
        // Outer small plate, inner big plate, then the collar — mirrored.
        for (x, pw, ph) in [(w * 0.07, w * 0.09, h * 0.62), (w * 0.17, w * 0.12, h), (w * 0.3, w * 0.05, h * 0.36)] {
            plate(x, pw, ph)
            plate(w - x - pw, pw, ph)
        }
        return path
    }
}
