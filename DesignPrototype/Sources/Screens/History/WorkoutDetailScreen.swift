import SwiftUI

// H03 strength detail / H04 cardio detail. A hero (A lit set ring · B family arcs · C date
// stamp; cardio: the route), Save as Template… as a visible secondary, the tiles in the Finish
// order, the last same-template comparison, heart rate with zones below, then the exercises
// with their snapshot equipment and editable set lines, cardio, Add Exercise…, notes and a
// visible Delete Workout… (confirmed, naming what is destroyed).

struct WorkoutDetailScreen: View {
    let workoutID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @State private var unitMode: HistoryUnitMode = .asEntered
    @State private var showsUnits = false
    @State private var renaming = false
    @State private var nameDraft = ""
    @State private var editingNotes = false
    @State private var notesDraft = ""
    @State private var confirmDelete = false
    @State private var pickingExercise = false
    /// Capture demo on one set row (swipe revealed, or its delete dialog).
    @State private var setDemo: HistorySetDemo?

    init(workoutID: UUID) {
        self.workoutID = workoutID
    }

    var body: some View {
        Group {
            if let workout = store.workout(workoutID) {
                content(workout)
                    .historyInlineTitle(workout.title, after: workout.hasLifting || !workout.cardio.contains(where: \.hasRoute) ? 150 : 90) {
                        // Units are about weights: no control on a cardio-only workout.
                        if workout.hasLifting { unitsControl }
                    }
            } else {
                Color.clear
            }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert("Workout Name", isPresented: $renaming) {
            TextField(store.workout(workoutID).map { derivedTitle($0) } ?? "", text: $nameDraft)
            Button("Save") { store.renameHistoryWorkout(workoutID, to: nameDraft) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Notes", isPresented: $editingNotes) {
            TextField("Notes", text: $notesDraft, axis: .vertical)
            Button("Save") { store.setNotes(notesDraft, workoutID: workoutID) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $pickingExercise) {
            HistoryExercisePickerSheet { exerciseID in addExercise(exerciseID) }
                .environment(store)
                .environment(router)
                .look(look)
        }
    }

    private func derivedTitle(_ workout: Workout) -> String {
        var copy = workout
        copy.name = nil
        return copy.title
    }

    // MARK: Page

    private func content(_ workout: Workout) -> some View {
        let summary = store.finishSummary(workoutID: workout.id)
        let routeSegment = workout.cardio.first(where: \.hasRoute)
        let cardioOnly = !workout.hasLifting && workout.hasCardio
        return ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                VStack(alignment: .leading, spacing: 18) {
                    if cardioOnly {
                        HistoryCardioHero(workout: workout, onRename: rename)
                    } else {
                        HistoryStrengthHero(workout: workout, onRename: rename)
                    }
                    if store.canSaveAsTemplate(workoutID: workout.id) {
                        Button { router.present(.saveAsTemplate(workoutID: workout.id)) } label: {
                            Label("Save as Template…", systemImage: "square.on.square")
                        }
                        .buttonStyle(.lookSecondary)
                    }
                }
                if let summary {
                    tiles(summary, cardioOnly: cardioOnly)
                    if cardioOnly, let segment = routeSegment ?? workout.cardio.first {
                        HistorySplitsSection(segment: segment).id("splits")
                    }
                    comparison(summary, workout: workout)
                    heartRate(summary, workout: workout).id("hr")
                }
                if workout.hasLifting {
                    // Add Exercise… sits right under the exercises it adds to.
                    VStack(alignment: .leading, spacing: look.space.group) {
                        HistoryExercisesSection(workout: workout, unitMode: unitMode, demo: setDemo)
                        HistoryMakeRow(title: "Add Exercise…") { pickingExercise = true }
                    }
                    .id("exercises")
                }
                // Cardio-only: the hero already carries the segment (distance is its tap
                // target), so no second card repeats it.
                if workout.hasCardio && !cardioOnly {
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Cardio")
                        ForEach(workout.cardio) { segment in
                            HistoryCardioCard(segment: segment)
                        }
                    }
                    .id("cardio")
                }
                if !workout.hasLifting {
                    HistoryMakeRow(title: "Add Exercise…") { pickingExercise = true }
                }
                notes(workout).id("notes")
                DestructiveRowButton("Delete Workout…") { confirmDelete = true }
                    .padding(.top, 4)
                    // Anchored on the button, so the dialog rises from what was tapped.
                    .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete Workout", role: .destructive) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { store.deleteWorkout(workoutID) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        if let workout = store.workout(workoutID) { Text(HistoryDeleteCopy.workout(workout, store: store)) }
                    }
                Color.clear.frame(height: 1).id(HistoryAnchor.bottom)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .historyCaptureVariant(store.currentScreen == .h04 ? .h04 : .h03,
                               matches: store.screenTarget.workoutID == workoutID,
                               handoffKey: workoutID,
                               anchor: { anchor($0, workout: workout) },
                               onVariant: { applyDemo($0, workout: workout) })
    }

    // MARK: Capture variants

    /// Named sections, so p2 / p3 / p4 show the same content in every look and size.
    private func anchor(_ variant: String, workout: Workout) -> AnyHashable? {
        let cardioOnly = !workout.hasLifting && workout.hasCardio
        switch variant {
        case "p2": return cardioOnly ? "splits" : "hr"
        case "p3": return cardioOnly ? "hr" : "exercises"
        case "p4": return workout.entries.count > 3 ? "entry-3" : "notes"
        case "swipeSet", "deleteSet", "kg": return "entry-0"
        case "deleteWorkout": return HistoryAnchor.bottom
        case "deleteOnly": return "entry-3"
        case "notes": return "notes"
        case "mixed":
            // The first exercise logged in a unit other than the app's.
            let unit = store.displayUnit
            return workout.entries.firstIndex { $0.sets.contains { $0.weight != nil && $0.unit != unit } }
                .map { "entry-\($0)" } ?? "exercises"
        default: return nil
        }
    }

    private func applyDemo(_ variant: String, workout: Workout) {
        let bench = workout.entries.first
        switch variant {
        case "swipeSet":
            if let bench, bench.sets.count > 2 { setDemo = HistorySetDemo(setID: bench.sets[2].id, action: .swipe) }
        case "deleteSet":
            if let bench, bench.sets.count > 2 { setDemo = HistorySetDemo(setID: bench.sets[2].id, action: .delete) }
        case "deleteOnly":
            // The exercise's only set: its dialog says the exercise goes too.
            guard workout.entries.count > 3 else { return }
            let entry = workout.entries[3]
            for set in entry.sets.dropFirst() { store.deleteLoggedSet(set.id, workoutID: workoutID) }
            if let first = entry.sets.first { setDemo = HistorySetDemo(setID: first.id, action: .delete) }
        case "deleteWorkout":
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { confirmDelete = true }
        case "units":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showsUnits = true }
        case "kg": unitMode = .kg
        case "rename":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { rename() }
        case "notes":
            if workout.notes.isEmpty { store.setNotes("Bench moved fast today. Shoulder press felt heavy on the last set.", workoutID: workoutID) }
        case "picker":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { pickingExercise = true }
        default: break
        }
    }

    private func rename() {
        nameDraft = store.workout(workoutID)?.name ?? ""
        renaming = true
    }

    // MARK: Sections

    @ViewBuilder
    private func tiles(_ summary: FinishSummary, cardioOnly: Bool) -> some View {
        // Cardio-only: time is already a hero figure, so the tiles start at calories.
        let tiles = cardioOnly ? summary.tiles.filter { $0.kind != .workoutTime } : summary.tiles
        if !tiles.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                if !look.id.isPaperClub { SectionHeader("Workout details") }
                StatPairGrid(tiles: tiles, countsUp: false)
            }
        }
    }

    @ViewBuilder
    private func comparison(_ summary: FinishSummary, workout: Workout) -> some View {
        if let comparison = summary.comparison, comparison.lastVolumeKg > 0, summary.volumeKg > 0 {
            let unit = store.displayUnit
            VStack(alignment: .leading, spacing: look.space.header) {
                switch look.id {
                case .floodlight: SectionHeader("Last \(comparison.templateName)")
                case .anatomy: EmptyView()
                case .paper, .carbon: SectionHeader("Last time")
                }
                ComparisonBars(
                    context: look.id == .anatomy ? "vs \(comparison.templateName), \(Format.shortDate(comparison.lastDate))"
                        : (look.id.isPaperClub ? comparison.templateName : nil),
                    lastLabel: Format.shortDate(comparison.lastDate),
                    last: unit.fromKg(comparison.lastVolumeKg),
                    todayLabel: Format.shortDate(workout.startedAt),
                    today: unit.fromKg(comparison.volumeKg),
                    unit: unit.label)
            }
        }
    }

    @ViewBuilder
    private func heartRate(_ summary: FinishSummary, workout: Workout) -> some View {
        let slots = store.historyHRSlots(workout)
        if !slots.isEmpty {
            HeartRatePlate {
                HeartRateRangeChart(
                    slots: slots, maxHeartRate: store.maxHeartRate ?? 185,
                    startLabel: look.id == .anatomy ? Format.time(workout.startedAt) : "0:00",
                    endLabel: look.id == .anatomy ? Format.time(workout.finishedAt) : Format.elapsed(workout.durationSeconds))
                if !summary.zoneSeconds.isEmpty { ZoneBreakdown(seconds: summary.zoneSeconds) }
            }
        }
    }

    /// Notes: the note (tap to edit), or a dashed Add Note… when there is none yet.
    @ViewBuilder
    private func notes(_ workout: Workout) -> some View {
        if workout.notes.isEmpty {
            HistoryMakeRow(title: "Add Note…", symbol: "square.and.pencil") {
                notesDraft = ""
                editingNotes = true
            }
        } else {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Notes")
                Button {
                    notesDraft = workout.notes
                    editingNotes = true
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(workout.notes)
                            .font(look.font.body)
                            .foregroundStyle(look.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textTertiary)
                    }
                    .padding(16)
                    .lookSurface(.tile)
                }
                .buttonStyle(.lookPressable)
                .accessibilityHint("Edits the note")
            }
        }
    }

    /// A labelled capsule naming the current mode ("As entered", "kg", "lb"); the choices
    /// open in a small popover.
    private var unitsControl: some View {
        Button { showsUnits = true } label: {
            HStack(spacing: 4) {
                Text(unitMode.unit?.label ?? "As entered")
                Image(systemName: "chevron.down").font(.system(.caption2, weight: .bold))
            }
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 6)
            .fixedSize()
        }
        .accessibilityLabel("Units, \(unitMode.title)")
        .popover(isPresented: $showsUnits, arrowEdge: .top) {
            HistoryUnitsPopover(mode: $unitMode) { showsUnits = false }
                .look(look)
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: Add Exercise… (then its first set opens in the set sheet)

    private func addExercise(_ exerciseID: UUID) {
        store.addExerciseToWorkout(workoutID: workoutID, exerciseID: exerciseID)
        guard let entry = store.workout(workoutID)?.entries.last,
              let setID = store.addLoggedSet(workoutID: workoutID, entryID: entry.id) else { return }
        HistoryNewSetRegistry.ids.insert(setID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            router.present(.editSet(workoutID: workoutID, entryID: entry.id, setID: setID))
        }
    }
}

/// The units choices: As entered, Show in kg, Show in lb (display only; nothing is rewritten).
struct HistoryUnitsPopover: View {
    @Binding var mode: HistoryUnitMode
    var done: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(HistoryUnitMode.allCases.enumerated()), id: \.element) { index, option in
                if index > 0 { LookDivider() }
                Button {
                    mode = option
                    done()
                } label: {
                    HStack(spacing: 12) {
                        Text(option.title)
                            .font(.system(.body, weight: option == mode ? .semibold : .regular))
                            .foregroundStyle(look.textPrimary)
                        Spacer(minLength: 16)
                        if option == mode {
                            Image(systemName: "checkmark").font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(look.actionText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minWidth: 220, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HistoryRowPressStyle())
                .accessibilityAddTraits(option == mode ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .background(look.surfaceSheet)
    }
}

// MARK: - Heroes

/// Strength (and mixed) hero: the ring/stamp beside the date, title (tap to rename), time and
/// gym, the families trained and the new-best count; the Edited mark under it.
struct HistoryStrengthHero: View {
    var workout: Workout
    var onRename: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let prCount = store.newBestCount(workoutID: workout.id)
        let families = store.families(ofWorkout: workout.id)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
        VStack(alignment: .leading, spacing: 14) {
            layout {
                HistoryHeroRing(sets: store.historyRingSets(workout), size: look.id.isPaperClub ? 112 : 112)
                VStack(alignment: .leading, spacing: 5) {
                    Text(HistoryFormat.dayTitle(workout.startedAt))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    HistoryTitleButton(title: workout.title, action: onRename)
                    Text(meta)
                        .font(look.font.subhead)
                        .monospacedDigit()
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !families.isEmpty || prCount > 0 || unitBadge != nil {
                HistoryFlowLayout(spacing: 10, lineSpacing: 8) {
                    if !families.isEmpty {
                        FamilyStrip(families: families, size: look.id.isPaperClub ? 32 : 30, spacing: look.id.isPaperClub ? 4 : 2)
                    }
                    if prCount > 0 { HistoryPRMark(count: prCount) }
                    if let unitBadge { HistoryTextBadge(unitBadge) }
                }
            }
            if let edited = workout.editedAt {
                HistoryEditedLine(date: edited)
            }
        }
    }

    private var meta: String {
        var parts = [HistoryFormat.timeRange(workout.startedAt, workout.finishedAt)]
        if let gym = workout.gymName { parts.append(gym) }
        return parts.joined(separator: " · ")
    }

    private var unitBadge: String? { workout.historyUnitBadge(appUnit: store.displayUnit) }
}

/// Cardio-only hero: the route is the bold element (after Finish only), with the three
/// figures — distance big, time and pace — under it. No route: the activity disc.
struct HistoryCardioHero: View {
    var workout: Workout
    var onRename: () -> Void
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title) private var mapHeight: CGFloat = 250

    var body: some View {
        let segment = workout.cardio.first(where: \.hasRoute) ?? workout.cardio.first
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                if segment?.hasRoute != true, let segment {
                    IconDisc(symbol: segment.activity.symbol, size: 58, context: .make)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(HistoryFormat.dayTitle(workout.startedAt))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    HistoryTitleButton(title: workout.title, action: onRename)
                    Text(meta)
                        .font(look.font.subhead)
                        .monospacedDigit()
                        .foregroundStyle(look.textSecondary)
                }
            }
            if let segment, segment.hasRoute {
                HistoryRouteMap(route: segment.route, markers: markers(segment), lineWidth: 4.5, inset: 30)
                    .frame(height: min(mapHeight, 320))
                    .frame(maxWidth: .infinity)
                    .lookSurface(.panel)
            }
            if let segment { figures(segment) }
            if let edited = workout.editedAt { HistoryEditedLine(date: edited) }
        }
    }

    private var meta: String {
        var parts = [HistoryFormat.timeRange(workout.startedAt, workout.finishedAt)]
        if let gym = workout.gymName { parts.append(gym) }
        return parts.joined(separator: " · ")
    }

    /// The distance is the hero's one editable figure: tap it (pencil beside) for the distance
    /// sheet. Where it came from is spoken, not shown.
    private func distanceButton(_ segment: CardioSegment) -> some View {
        Button { router.present(.cardioDistance(segmentID: segment.id)) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let meters = segment.distanceMeters {
                    HistoryFigure(value: Format.distance(meters: meters, segment.unit), unit: segment.unit.label,
                                  label: "Distance", font: look.font.heroNumber)
                } else {
                    HistoryFigure(value: "—", unit: nil, label: "Enter distance", font: look.font.heroNumber)
                }
                Image(systemName: "pencil")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(segment.distanceMeters.map {
            "Distance, \(Format.distanceLabel(meters: $0, segment.unit))" + HistoryFormat.distanceSource(segment)
        } ?? "Enter distance")
        .accessibilityHint("Edits the distance")
        .accessibilityAddTraits(.isButton)
    }

    private func markers(_ segment: CardioSegment) -> [(meters: Double, label: String)] {
        guard let total = segment.distanceMeters else { return [] }
        let unit = segment.unit.metersPerUnit
        return stride(from: unit, to: total - unit * 0.05, by: unit).enumerated().map { ($1, "\($0 + 1)") }
    }

    /// Distance leads (the hero size), time and pace follow; every number sits over its small
    /// label and the labels share one baseline. Stacked into rows at accessibility sizes.
    @ViewBuilder
    private func figures(_ segment: CardioSegment) -> some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: 12))
        layout {
            distanceButton(segment)
                .frame(maxWidth: .infinity, alignment: .leading)
            HistoryFigure(value: Format.elapsed(segment.activeSeconds), unit: nil, label: "Time", font: look.font.bigNumber)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let pace = HistoryFormat.paceOrSpeed(segment) {
                HistoryFigure(value: pace.value, unit: pace.unit, label: pace.label, font: look.font.bigNumber)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// A big number with a small unit over a small label (the month card's pattern).
struct HistoryFigure: View {
    var value: String
    var unit: String?
    var label: String
    var font: Font
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(font).foregroundStyle(look.textPrimary)
                if let unit {
                    Text(unit).font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                        .foregroundStyle(look.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(label).font(look.historyFigureLabel).foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value) \(unit ?? "")")
    }
}

/// The workout title as a button that renames it (a small pencil says so).
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
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(title)
        .accessibilityHint("Renames the workout")
        .accessibilityAddTraits(.isHeader)
    }
}

/// "Edited Sep 20, 2026 at 8:40 AM" (the existing mark, D47).
struct HistoryEditedLine: View {
    var date: Date
    @Environment(\.look) private var look

    var body: some View {
        Label {
            Text(HistoryFormat.edited(date))
        } icon: {
            Image(systemName: "pencil.circle")
        }
        .font(look.font.footnote)
        .foregroundStyle(look.textSecondary)
        .labelStyle(HistoryTightLabelStyle())
    }
}

struct HistoryTightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
    }
}
