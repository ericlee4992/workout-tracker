import SwiftUI

// Workout detail sections: exercises (supersets share one card, lettered A/B), set lines,
// cardio segments and splits. History shows frozen snapshot names only (D23).

// MARK: - Exercises

/// A capture demo on one set row: its Delete tile revealed, or its delete dialog open.
struct HistorySetDemo: Equatable {
    enum Action { case swipe, delete }
    var setID: UUID
    var action: Action
}

struct HistoryExercisesSection: View {
    var workout: Workout
    var unitMode: HistoryUnitMode
    var demo: HistorySetDemo? = nil
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        let letters = store.supersetLabels(ofWorkout: workout.id)
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Exercises", trailing: Format.count(workout.entries.count, "exercise"))
            VStack(spacing: look.space.group) {
                ForEach(groups(letters), id: \.first!.id) { group in
                    VStack(spacing: 0) {
                        ForEach(Array(group.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { LookDivider().padding(.vertical, 2) }
                            HistoryEntryBlock(workout: workout, entry: entry, letter: letters[entry.id], unitMode: unitMode,
                                              demo: demo)
                                .id("entry-\(workout.entries.firstIndex(where: { $0.id == entry.id }) ?? 0)")
                        }
                    }
                    .background(look.surface)
                    .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
                    .lookSurface(.panel)
                }
            }
        }
    }

    /// Adjacent entries of one superset share a card.
    private func groups(_ letters: [UUID: String]) -> [[WorkoutEntry]] {
        var result: [[WorkoutEntry]] = []
        for entry in workout.entries {
            if let last = result.last?.last, letters[entry.id] != nil, letters[last.id] != nil,
               last.supersetGroup != nil, last.supersetGroup == entry.supersetGroup {
                result[result.count - 1].append(entry)
            } else {
                result.append([entry])
            }
        }
        return result
    }
}

/// One exercise: name (with its superset letter), the progress-chart button and the options
/// menu (Add Set, load type, Remove Exercise…), the snapshot equipment line, then its sets.
struct HistoryEntryBlock: View {
    var workout: Workout
    var entry: WorkoutEntry
    var letter: String?
    var unitMode: HistoryUnitMode
    var demo: HistorySetDemo? = nil
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var pendingSetDelete: LoggedSet?
    @State private var confirmRemove = false
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            equipment
            VStack(spacing: 0) {
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                    if index > 0 { LookDivider().padding(.leading, 50) }
                    HistorySwipeRow(startsOpen: demo == HistorySetDemo(setID: set.id, action: .swipe),
                                    onDelete: { pendingSetDelete = set }) {
                        HistorySetLine(logged: set, marker: marker(index), loadType: entry.loadType,
                                       outcome: store.bestOutcome(setID: set.id), unitMode: unitMode) {
                            router.present(.editSet(workoutID: workout.id, entryID: entry.id, setID: set.id))
                        }
                    }
                }
            }
            .padding(.horizontal, -8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .onChange(of: demo, initial: true) { _, demo in
            guard let demo, demo.action == .delete, let set = entry.sets.first(where: { $0.id == demo.setID }) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { pendingSetDelete = set }
        }
        .confirmationDialog("Delete this set?", isPresented: Binding(
            get: { pendingSetDelete != nil }, set: { if !$0 { pendingSetDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingSetDelete) { set in
            Button("Delete Set", role: .destructive) { deleteSet(set) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(HistoryDeleteCopy.set(exerciseName: entry.exerciseName, isOnlySet: entry.sets.count == 1))
        }
        .confirmationDialog("Remove this exercise?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove Exercise", role: .destructive) {
                withAnimation(.snappy) { store.removeEntry(entry.id, workoutID: workout.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(entry.exerciseName) and its \(Format.count(entry.sets.count, "set")) will be permanently removed from this workout. Records are recalculated without them.")
        }
    }

    // MARK: Header

    private var header: some View {
        // Actions sit on the title's FIRST line (a two-line name never pushes them down).
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let letter {
                HistorySupersetLetter(letter: letter)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + titleCentreToBaseline }
            }
            Text(entry.exerciseName)
                .font(look.font.cardTitle)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: look.id.isPaperClub ? 10 : 12) {
                CardIconButton("chart.line.uptrend.xyaxis", accessibilityLabel: "Progress chart") {
                    router.push(.progress(exerciseID: entry.exerciseID, variationID: store.progressVariationID(for: entry)))
                }
                optionsMenu
            }
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + titleCentreToBaseline }
        }
    }

    /// From the centre of the title's first line to its baseline (≈ 0.3 of the line height).
    @ScaledMetric(relativeTo: .title3) private var titleCentreToBaseline: CGFloat = 7

    private var optionsMenu: some View {
        Menu {
            Button {
                if let setID = store.addLoggedSet(workoutID: workout.id, entryID: entry.id) {
                    HistoryNewSetRegistry.ids.insert(setID)
                    router.present(.editSet(workoutID: workout.id, entryID: entry.id, setID: setID))
                }
            } label: { Label("Add Set", systemImage: "plus") }
            Picker(selection: Binding(get: { entry.loadType },
                                      set: { store.retypeEntry(entry.id, to: $0, workoutID: workout.id) })) {
                ForEach(LoadType.allCases) { Text($0.badge).tag($0) }
            } label: {
                Label("Load type", systemImage: "scalemass")
            }
            .pickerStyle(.menu)
            Divider()
            Button(role: .destructive) { confirmRemove = true } label: {
                Label("Remove Exercise", systemImage: "trash")
            }
        } label: {
            HistoryIconFace(symbol: "ellipsis")
        }
        .accessibilityLabel("Options")
    }

    // MARK: Equipment

    private var equipment: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if entry.machineID == nil && entry.freeWeightTag == .barbell {
                        HistoryBarbellGlyph()
                    } else {
                        LookIcon(entry.machineID != nil || entry.freeWeightTag == .machine ? LookIcon.machine
                                 : (entry.freeWeightTag?.symbol ?? "circle.dashed"), style: .footnote)
                    }
                }
                .foregroundStyle(look.textSecondary)
                .frame(width: glyphColumn)
                Text(entry.equipmentLabel)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if entry.loadType != .weighted { HistoryTextBadge(entry.loadType.badge) }
            }
            if let line = entry.reclassifiedLine {
                Text(line)
                    .font(look.font.caption)
                    .foregroundStyle(look.textTertiary)
                    .padding(.leading, glyphColumn + 8)
            }
        }
    }

    /// W / F / D, or the working number (warmups are not counted, as in the live table).
    private func marker(_ index: Int) -> Int {
        entry.sets[...index].filter { $0.type == .working }.count
    }

    private func deleteSet(_ set: LoggedSet) {
        let wasLast = entry.sets.count == 1
        withAnimation(.snappy) {
            store.deleteLoggedSet(set.id, workoutID: workout.id)
            if wasLast { store.removeEntry(entry.id, workoutID: workout.id) }
        }
    }
}

/// A logged set: marker · value (number big, unit small) · bar breakdown · new-best mark ·
/// a pencil (tap to edit). Swipe left to delete.
struct HistorySetLine: View {
    var logged: LoggedSet
    var marker: Int
    var loadType: LoadType
    var outcome: BestOutcome
    var unitMode: HistoryUnitMode
    var action: () -> Void
    @State private var flash = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                SetMarker(kind: logged.type, number: marker, done: true)
                VStack(alignment: .leading, spacing: 2) {
                    value
                    if let breakdown { Text(breakdown).font(look.font.caption).foregroundStyle(look.textSecondary) }
                    if typeSize.isAccessibilitySize, let badge { NewBestBadge(kind: badge) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize, let badge { NewBestBadge(kind: badge) }
                // A faint hint that the row edits (the whole row is the target).
                Image(systemName: "pencil")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(look.textTertiary.opacity(0.55))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(look.textPrimary.opacity(flash ? 0.12 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(HistoryRowPressStyle())
        .animation(reduceMotion ? nil : .snappy, value: logged)
        // A saved edit answers on the row itself: the new numbers roll in and the row glows once.
        .onChange(of: logged) { _, _ in
            guard !reduceMotion else { return }
            flash = true
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) { flash = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint("Edits the set")
    }

    private var badge: SetBadge? {
        switch outcome {
        case .newBest: .newBest
        case .firstTime: .firstTime
        case .none: nil
        }
    }

    private var shown: SetValue? { logged.value.map { unitMode.display($0) } }

    /// The plate maths, only when there are plates ("45 lb bar = 45 lb" says nothing).
    private var breakdown: String? {
        guard let shown, shown.bar != nil, let perSide = shown.perSide, perSide > 0 else { return nil }
        return Format.barBreakdown(shown)
    }

    @ViewBuilder private var value: some View {
        if let shown {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if loadType.takesWeight, let w = shown.weight {
                    Text(Format.weight(w)).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText(value: w))
                    Text(shown.unit.label).font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
                    Text("×").font(look.font.subhead).foregroundStyle(look.textSecondary).padding(.horizontal, 1)
                    Text("\(shown.reps)").font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText(value: Double(shown.reps)))
                } else {
                    Text("\(shown.reps)").font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                    Text(shown.reps == 1 ? "rep" : "reps").font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
            }
        } else {
            Text("—").font(look.font.fieldNumber).foregroundStyle(look.textTertiary)
        }
    }

    private var spoken: String {
        var parts = [logged.type == .working ? "Set \(marker)" : logged.type.displayName]
        if let shown { parts.append(Format.set(shown, loadType: loadType)) }
        if let breakdown { parts.append(breakdown) }
        if let badge { parts.append(badge == .newBest ? "New best" : "First time") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Cardio

/// A recorded cardio segment: activity, its figures (time, distance, pace or speed, heart
/// rate, calories) and the distance row that opens the distance editor.
struct HistoryCardioCard: View {
    var segment: CardioSegment
    var showsFigures = true
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                IconDisc(symbol: segment.activity.symbol, size: 40, context: .make)
                VStack(alignment: .leading, spacing: 1) {
                    Text(segment.activity.name).font(look.historyRowTitle).foregroundStyle(look.textPrimary)
                    Text(Format.time(segment.startedAt)).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            if showsFigures {
                figures.padding(.horizontal, 16).padding(.bottom, 16)
            }
            LookDivider()
            distanceRow
        }
        .background(look.surface)
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
    }

    /// Paired like the tiles: time | pace (or speed), heart rate | calories. Distance lives in
    /// the editable row below, so it is not shown twice. One column at accessibility sizes.
    private var figures: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        var items: [(String, String?, String, String?, Color?)] = [
            (Format.elapsed(segment.activeSeconds), nil, "Time", "timer", nil)]
        if let pace = HistoryFormat.paceOrSpeed(segment) { items.append((pace.value, pace.unit, pace.label, nil, nil)) }
        if let hr = segment.averageHeartRate {
            items.append(("\(hr)", "bpm", "Avg. heart rate", "heart.fill", look.id.isPaperClub ? nil : look.heartRate))
        }
        if let cal = segment.activeCalories { items.append(("\(cal)", "cal", "Active calories", "flame.fill", nil)) }
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(start..<start + columns, id: \.self) { i in
                        if i < items.count {
                            let item = items[i]
                            StatFigure(value: item.0, unit: item.1, label: item.2, symbol: item.3, tint: item.4,
                                       symbolTint: item.3 == "heart.fill" ? look.heartRate : nil,
                                       numberFont: look.font.statNumber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }

    /// "Distance" with its value and where it came from; opens the distance editor (C05).
    private var distanceRow: some View {
        Button { router.present(.cardioDistance(segmentID: segment.id)) } label: {
            HStack(spacing: 10) {
                Text(segment.distanceMeters == nil ? "Enter distance" : "Distance")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                if let meters = segment.distanceMeters {
                    Text(Format.distanceLabel(meters: meters, segment.unit))
                        .font(.system(.subheadline, weight: .bold).monospacedDigit())
                        .foregroundStyle(look.textPrimary)
                }
                Image(systemName: "pencil").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(HistoryRowPressStyle())
        // Where the distance came from is spoken only (no source captions on screen).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(segment.distanceMeters.map {
            "Distance, \(Format.distanceLabel(meters: $0, segment.unit))" + HistoryFormat.distanceSource(segment)
        } ?? "Enter distance")
        .accessibilityAddTraits(.isButton)
    }
}

/// Per-unit splits of a cardio segment: a bar per mile (longer = faster), the fastest lit.
struct HistorySplitsSection: View {
    var segment: CardioSegment
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var labelColumn: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var valueColumn: CGFloat = 76

    var body: some View {
        let splits = Derived.splits(segment)
        if splits.count > 1 {
            let paces = splits.map { Double($0.seconds) / max(0.01, $0.distance) }
            // Only a full split can be the fastest (a 0.1 mi tail is not a lit record).
            let fullPaces = splits.filter { $0.distance >= 0.95 }.map { paces[$0.index] }
            let fastest = (fullPaces.isEmpty ? paces : fullPaces).min() ?? 1
            let slowest = paces.max() ?? 1
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Splits", trailing: "/\(segment.unit.label)")
                VStack(spacing: 10) {
                    ForEach(splits) { split in
                        let pace = paces[split.index]
                        let isFastest = pace == fastest && (split.distance >= 0.95 || fullPaces.isEmpty)
                        HStack(spacing: 12) {
                            Text(split.distance < 0.95 ? Format.number((split.distance * 10).rounded() / 10) : "\(split.index + 1)")
                                .font(look.historyRowNumber)
                                .foregroundStyle(look.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(width: labelColumn, alignment: .leading)
                            GeometryReader { geo in
                                // Longer = faster; the slowest split still shows 45 %.
                                let span = max(1, slowest - fastest)
                                let fraction = min(1, 0.45 + 0.55 * (slowest - pace) / span)
                                RoundedRectangle(cornerRadius: look.id.isPaperClub ? 3 : 5, style: .continuous)
                                    .fill(isFastest ? fastestColor : look.comparisonLast)
                                    .frame(width: geo.size.width * fraction, height: 12)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(height: 20)
                            Text(Format.pace(pace))
                                .font(look.historyRowNumber)
                                .foregroundStyle(isFastest ? look.textPrimary : look.textSecondary)
                                .frame(width: valueColumn, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Split \(split.index + 1), \(Format.pace(pace)) per \(segment.unit.label)")
                    }
                }
                .padding(16)
                .lookSurface(.panel)
            }
        }
    }

    private var fastestColor: Color {
        switch look.id {
        case .floodlight: look.done
        case .anatomy: look.heartRate
        case .paper, .carbon: look.textPrimary
        }
    }
}
