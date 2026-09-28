import SwiftData
import SwiftUI

/// An exercise's own page (Floodlight ticket 08, E02 — new: the app reached every per-exercise
/// action through a long-press menu). Identity (equipment glyph, body area with its family mark,
/// tags), the user's numbers (workouts, last trained, sets), then the bold element: the best set
/// of the most-trained variation with its 1RM, change and mini chart (tap → the progress chart on
/// that variation) and the other variations; the rep-count records; setup (load type, presets,
/// rename for custom exercises); the machines that serve it; the last three workouts that
/// trained it. Opened from the Exercises tab and from a machine page's exercise rows.
/// Everything shown is history in snapshot terms (D23), read from finished workouts.
struct ExerciseDetailView: View {
    var exerciseID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var matches: [Exercise]
    @Query private var allPreferences: [AppPreferences]
    @Query private var machines: [MachineInstance]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var finished: [Workout]
    @State private var titleInBar = false
    @State private var charting: ChartRequest?
    @State private var showingPresets = false
    @State private var showingLoadType = false
    @State private var renaming = false
    @State private var renameText = ""

    init(exerciseID: UUID) {
        self.exerciseID = exerciseID
        _matches = Query(filter: #Predicate<Exercise> { $0.id == exerciseID })
    }

    /// The progress chart, opened on one variation.
    private struct ChartRequest: Identifiable {
        var key: ProgressVariationKey
        var id: ProgressVariationKey { key }
    }

    private var displayUnit: WeightUnit {
        UnitPrecedence.defaultUnit(machineUnit: nil, gymUnit: nil,
                                   appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
    }

    var body: some View {
        if let exercise = matches.first(where: { !$0.isDeleted }) {
            content(exercise)
        } else {
            Color.clear.lookScreenBackground()
        }
    }

    // MARK: Data

    /// One read of this exercise's history per render.
    private struct Readout {
        var stat: ExerciseStat
        var inputs: [RecordSetInput]
        var variations: [(key: ProgressVariationKey, days: Int)]
        var labels: [ProgressVariationKey: String]
        var sessions: [ExerciseOverview.Session]
        var machineUses: [ExerciseOverview.MachineUse]
    }

    private func readout(_ exercise: Exercise) -> Readout {
        _ = finished.count
        let sets = (try? ExerciseOverview.loggedSets(in: modelContext))?[exerciseID] ?? []
        let inputs = sets.map(\.input)
        let variations = ProgressSeriesMath.rankedVariations(in: inputs)
        let finishedEntries = (try? SetBadgeMath.finishedEntries(in: modelContext)) ?? []
        let mine = finishedEntries.filter { $0.snapshotExerciseID == exerciseID }
        let labels = ProgressSeriesMath.labels(for: variations.map {
            (key: $0.key, words: ExerciseOverview.variationWords(for: $0.key, entries: mine))
        })
        return Readout(
            stat: ExerciseOverview.stat(of: sets, currentLoadType: exercise.loadType),
            inputs: inputs, variations: variations, labels: labels,
            sessions: ExerciseOverview.recentSessions(exerciseID: exerciseID, finishedEntries: finishedEntries),
            machineUses: ExerciseOverview.machineUses(exerciseID: exerciseID, currentLoadType: exercise.loadType,
                                                      sets: sets, machines: machines))
    }

    private func content(_ exercise: Exercise) -> some View {
        let data = readout(exercise)
        return ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                hero(exercise)
                if data.stat.workouts > 0 {
                    GymStatStrip(stats: stats(data.stat))
                }
                progress(exercise, data: data)
                if let main = data.variations.first {
                    records(ProgressSeriesMath.scoped(data.inputs, to: main.key), loadType: main.key.loadType)
                }
                setup(exercise)
                machinesSection(data.machineUses, loadType: exercise.loadType)
                history(data.sessions)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 40)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("exerciseDetail")
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 110 : 64)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .lookScreenBackground()
        .exercisesInlineTitle(exercise.name, visible: titleInBar)
        .sheet(item: $charting) { request in
            NavigationStack {
                ExerciseProgressView(exerciseID: exercise.id, exerciseName: exercise.name, initialVariation: request.key)
            }
        }
        .sheet(isPresented: $showingPresets) { ExercisePresetsSheet(exercise: exercise) }
        .sheet(isPresented: $showingLoadType) { EditExerciseLoadTypeSheet(exercise: exercise) }
        .alert("Rename Exercise", isPresented: $renaming) {
            TextField("Name", text: $renameText)
            Button("Save") { rename(exercise) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Hero

    private func hero(_ exercise: Exercise) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            // At AX sizes the tile would take a row of its own; the tags carry it.
            if !ax {
                ExercisesGlyph(exercise.equipmentTypeTags.first, style: .title2)
                    .foregroundStyle(look.textPrimary)
                    .frame(width: 60, height: 60)
                    .background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    ExercisesFamilyMark(family: MuscleFamily(muscleGroup: exercise.muscleGroup))
                    Text(exercise.muscleGroup ?? "Uncategorized")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                Text(exercise.name)
                    .font(look.font.title)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(exercise.shownEquipmentTags) { ExercisesTag($0.label) }
                    ExercisesTag(exercise.loadType.badge, symbol: exercise.loadType.rankSymbol)
                    if !exercise.isSeeded { ExercisesTag("Custom") }
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
    }

    private func stats(_ stat: ExerciseStat) -> [GymStat] {
        var items = [GymStat.count(stat.workouts, "Workout", "Workouts")]
        if let last = stat.lastTrained {
            items.append(GymStat(value: ExerciseDates.relative(last, now: .now), label: "Last trained", isWord: true))
        }
        items.append(GymStat.count(stat.workingSets, "Set", "Sets"))
        return items
    }

    // MARK: Progress (the bold element)

    @ViewBuilder
    private func progress(_ exercise: Exercise, data: Readout) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Progress")
            if let main = data.variations.first {
                VStack(spacing: 0) {
                    mainProgress(main.key, data: data)
                    ForEach(Array(data.variations.dropFirst().enumerated()), id: \.element.key) { index, variation in
                        LookDivider().padding(.leading, 16)
                        variationRow(variation, data: data)
                            .accessibilityIdentifier("exerciseVariation.\(index + 1)")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
                .lookSurface(.tile)
            } else {
                EmptyStateView(symbol: "chart.xyaxis.line", title: "No sets logged yet")
                    .lookSurface(.panel)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("exerciseProgressEmpty")
            }
        }
    }

    private func mainProgress(_ key: ProgressVariationKey, data: Readout) -> some View {
        let scoped = ProgressSeriesMath.scoped(data.inputs, to: key)
        let series = ProgressSeriesMath.series(for: data.inputs, variation: key)
        let recordDays = ProgressSeriesMath.recordDays(series)
        let best = ExerciseOverview.best(scoped, loadType: key.loadType).flatMap(SetValue.init)
        // Marked only when the newest session set it (never a first time or a tie).
        let marked = series.points.count > 1 && series.points.last.map { recordDays.contains($0.date) } == true
        let oneRepMax = key.loadType == .weighted ? RecordsMath.bestE1RM(among: scoped)?.e1RMKg : nil
        let change = ProgressSeriesMath.change(series)
        let label = data.labels[key] ?? key.loadType.badge
        return Button { charting = ChartRequest(key: key) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                }
                if let best {
                    ExercisesBestValue(value: best, loadType: key.loadType, userUnit: displayUnit, style: .hero, marked: marked)
                }
                if oneRepMax != nil || change != nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 26) { figures(oneRepMax: oneRepMax, change: change) }
                        VStack(alignment: .leading, spacing: 12) { figures(oneRepMax: oneRepMax, change: change) }
                    }
                }
                if series.points.filter({ $0.bestKg != nil }).count >= 2 {
                    MachineBestChart(series: series, recordDays: recordDays, height: 150)
                        // Set labels and axis dates collide above xLarge; the figures above carry it.
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                        .padding(.top, 4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(ExercisesRowPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the progress chart")
        .accessibilityIdentifier("exerciseProgressPanel")
    }

    @ViewBuilder
    private func figures(oneRepMax: Double?, change: Double?) -> some View {
        if let oneRepMax {
            figure(value: LookFormat.grouped(WeightMath.convert(oneRepMax, from: .kg, to: displayUnit)),
                   unit: displayUnit.rawValue, label: "1RM")
        }
        if let change {
            figure(value: LookFormat.percent(change * 100), unit: nil, label: "Since first session")
        }
    }

    private func figure(value: String, unit: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(look.font.smallNumber).foregroundStyle(look.textPrimary)
                if let unit {
                    Text(unit).font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
            }
            Text(label).font(look.font.caption).foregroundStyle(look.textSecondary)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private func variationRow(_ variation: (key: ProgressVariationKey, days: Int), data: Readout) -> some View {
        let scoped = ProgressSeriesMath.scoped(data.inputs, to: variation.key)
        let best = ExerciseOverview.best(scoped, loadType: variation.key.loadType).flatMap(SetValue.init)
        // "Chest Press 2 · Narrow grip" reads as equipment, then what varies: the equipment is the
        // row title, the preset / other gym joins the day count underneath.
        let label = data.labels[variation.key] ?? variation.key.loadType.badge
        let parts = label.components(separatedBy: " · ")
        let detail = ([parts.dropFirst().joined(separator: " · ")].filter { !$0.isEmpty }
                      + ["\(variation.days) day\(variation.days == 1 ? "" : "s")"]).joined(separator: " · ")
        let ax = typeSize.isAccessibilitySize
        return Button { charting = ChartRequest(key: variation.key) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(parts.first ?? label)
                        .font(look.exercisesRowTitle)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if ax, let best {
                        ExercisesBestValue(value: best, loadType: variation.key.loadType, userUnit: displayUnit)
                    }
                }
                Spacer(minLength: 8)
                if !ax, let best {
                    ExercisesBestValue(value: best, loadType: variation.key.loadType, userUnit: displayUnit)
                }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        }
        .buttonStyle(ExercisesRowPressStyle())
        .accessibilityElement(children: .combine)
    }

    // MARK: Rep records

    /// The rep-count records of the main variation, by load type: Weighted the heaviest, Assisted
    /// the least assistance ("−70"), BW + added the most added ("+15", or "BW" for a plain set),
    /// Bodyweight one tile with the most reps.
    @ViewBuilder
    private func records(_ scoped: [RecordSetInput], loadType: LoadType) -> some View {
        let title = loadType.recordsTitle
        let bests = RecordsMath.repCountBests(among: scoped, loadType: loadType).sorted { $0.key < $1.key }
        let most = loadType == .bodyweight ? RecordsMath.mostRepsRecord(among: scoped) : nil
        if !bests.isEmpty || most != nil {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader(title.title, trailing: title.caption)
                if let most {
                    recordTile(caption: "Most reps", figure: "\(most.reps)", unit: most.reps == 1 ? "rep" : "reps",
                               date: nil, spoken: "Most reps, \(most.reps)")
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 180, alignment: .leading)
                } else {
                    let columns = [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 84), spacing: 10)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(bests, id: \.key) { reps, best in
                            let value = SetValue(weight: best.weightValue, unit: best.weightUnit ?? displayUnit, reps: reps)
                            recordTile(caption: "\(reps) rep\(reps == 1 ? "" : "s")",
                                       figure: ExerciseValueText.figure(value, loadType: loadType),
                                       unit: ExerciseValueText.figureHasUnit(value, loadType: loadType) ? value.unit.rawValue : nil,
                                       date: best.completedAt,
                                       spoken: "\(reps) rep\(reps == 1 ? "" : "s"), \(ExerciseValueText.spoken(value, loadType: loadType))")
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("exerciseRecords")
        }
    }

    private func recordTile(caption: String, figure: String, unit: String?, date: Date?, spoken: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(figure)
                    .font(look.font.statNumber)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
            }
            if let date {
                Text(LookFormat.shortDate(date))
                    .font(look.font.caption)
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.stat)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.map { "\(spoken), \(LookFormat.shortDate($0))" } ?? spoken)
    }

    // MARK: Setup

    private func setup(_ exercise: Exercise) -> some View {
        let presets = (exercise.presets ?? []).sorted { ($0.order, $0.name) < ($1.order, $1.name) }
        let presetLine = presets.isEmpty ? "No presets yet" : presets.map(\.name).joined(separator: " · ")
        return LookList(separatorInset: 54) {
            // At AX sizes the type is the subtitle: as a trailing value it squeezed to "Weight-ed".
            let ax = typeSize.isAccessibilitySize
            LookRow("Load type", subtitle: ax ? exercise.loadType.badge : nil, symbol: exercise.loadType.pickerSymbol,
                    action: { showingLoadType = true }) {
                if !ax {
                    Text(exercise.loadType.badge)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
            }
            .accessibilityIdentifier("exerciseSetupLoadType")
            LookRow("Presets", subtitle: presetLine, symbol: "slider.horizontal.3",
                    value: presets.isEmpty ? nil : "\(presets.count)",
                    action: { showingPresets = true })
                .accessibilityIdentifier("exerciseSetupPresets")
            if !exercise.isSeeded {
                LookRow("Rename…", symbol: "pencil", showsChevron: false, action: {
                    renameText = exercise.name
                    renaming = true
                })
                .accessibilityIdentifier("exerciseRename")
            }
        }
    }

    // MARK: Machines

    @ViewBuilder
    private func machinesSection(_ uses: [ExerciseOverview.MachineUse], loadType: LoadType) -> some View {
        let byID = Dictionary(machines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if !uses.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Machines")
                LookList(separatorInset: 14) {
                    ForEach(uses) { use in
                        if let machine = byID[use.machineID] {
                            NavigationLink { MachineDetailView(machine: machine) } label: {
                                machineRow(use, loadType: loadType)
                            }
                            .buttonStyle(ExercisesRowPressStyle())
                            .accessibilityIdentifier("exerciseMachine.\(use.label)")
                        }
                    }
                }
            }
        }
    }

    private func machineRow(_ use: ExerciseOverview.MachineUse, loadType: LoadType) -> some View {
        let ax = typeSize.isAccessibilitySize
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(use.label)
                    .font(look.exercisesRowTitle)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let gym = use.gymName {
                    Text(gym).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                if ax { machineUse(use, loadType: loadType, alignment: .leading) }
            }
            Spacer(minLength: 8)
            if !ax { machineUse(use, loadType: loadType, alignment: .trailing) }
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func machineUse(_ use: ExerciseOverview.MachineUse, loadType: LoadType, alignment: HorizontalAlignment) -> some View {
        if use.workouts > 0 {
            VStack(alignment: alignment, spacing: 3) {
                if let best = use.best.flatMap(SetValue.init) {
                    ExercisesBestValue(value: best, loadType: loadType, userUnit: displayUnit)
                }
                Text("\(use.workouts) workout\(use.workouts == 1 ? "" : "s")")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textTertiary)
            }
        }
    }

    // MARK: History

    @ViewBuilder
    private func history(_ sessions: [ExerciseOverview.Session]) -> some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("History")
                LookList {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        NavigationLink { WorkoutDetailView(workout: session.workout) } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(ExercisesRowPressStyle())
                        .accessibilityIdentifier("exerciseSession.\(index)")
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: ExerciseOverview.Session) -> some View {
        let date = session.workout.startedAt
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(verbatim: "\(Calendar.current.component(.day, from: date))")
                    .font(look.font.smallNumber)
                    .foregroundStyle(look.textPrimary)
                Text(ExerciseDates.weekdayShort(date))
                    .font(look.font.caption)
                    .foregroundStyle(look.textSecondary)
            }
            .frame(minWidth: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.workout.historyTitle)
                    .font(look.exercisesRowTitle)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                if !session.equipment.isEmpty {
                    Text(session.equipment)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                WrapLayout(spacing: 10, lineSpacing: 4) {
                    ForEach(session.sets) { set in
                        if let reps = set.reps {
                            ExercisesSetText(value: SetValue(weight: set.weightValue, unit: set.weightUnit, reps: reps),
                                             type: set.type, loadType: session.loadType, userUnit: displayUnit,
                                             isNewBest: session.newBestSetIDs.contains(set.id))
                        }
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textTertiary)
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func rename(_ exercise: Exercise) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !exercise.isSeeded else { return }
        do {
            try EquipmentLifecycle(context: modelContext).rename(exercise, to: trimmed)
        } catch {
            assertionFailure("Failed to rename exercise: \(error)")
        }
    }
}
