import SwiftUI

// PROTOTYPE — E02 Exercise Detail, a NEW destination (the real app hid every per-exercise
// action behind a long-press menu). Identity (equipment glyph, body area with its family
// colour mark, tags), the user's numbers (workouts, last trained, sets), then the bold element:
// the best set with its mini progress chart (tap → the full chart, H06) and the other
// variations, the rep-count records, setup (load type, presets, rename for custom exercises),
// the machines that serve it, and the last three workouts that trained it.

struct ExerciseDetailScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var titleVisible = false
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var page = 0
    @State private var renameShown = false
    @State private var renameText = ""
    /// The mini chart draws in left to right once (Reduce Motion: shown complete).
    @State private var chartReveal: Double = 0
    /// Capture variants show another exercise in the same pushed screen ("assisted",
    /// "bodyweight", "bwplus", "untrained", "custom"); nil = the pushed exercise.
    @State private var variantID: UUID?

    private var exerciseID: UUID { variantID ?? pushedID }
    private let pushedID: UUID

    init(exerciseID: UUID) {
        self.pushedID = exerciseID
    }

    var body: some View {
        if let exercise = store.exercise(exerciseID) {
            content(exercise)
        } else {
            Color.clear.lookScreenBackground()
        }
    }

    private func content(_ exercise: Exercise) -> some View {
        let stat = store.exercisesStat(exerciseID)
        let variations = store.progressVariations(exerciseID: exerciseID)
        let main = variations.first
        let layer = main.flatMap { layerFor($0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                hero(exercise)
                if stat.workouts > 0 {
                    ExercisesStatStrip(stats: statItems(stat))
                }
                progress(exercise, variations: variations, layer: layer)
                if let layer, !layer.repBests.isEmpty || layer.mostReps != nil {
                    records(layer, loadType: main?.loadType ?? exercise.loadType)
                }
                setup(exercise)
                machines(exercise)
                history(exercise)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scroll)
        .exercisesPaging(page, position: $scroll)
        .exercisesScrolledPast(64, into: $titleVisible)
        .lookScreenBackground()
        .exercisesInlineTitle(exercise.name, visible: titleVisible)
        .alert("Rename Exercise", isPresented: $renameShown) {
            TextField("Name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { store.renameExercise(exerciseID, to: trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            // Frozen-clock captures show the chart complete instead of mid-draw.
            if store.freezeClock { chartReveal = 1 }
            if let variant = ExercisesVariant.consume(.e02, store: store, router: router) {
                page = ExercisesVariant.page(variant)
                applyVariant(variant)
            }
        }
    }

    private func layerFor(_ variation: ProgressVariation) -> PerformanceLayer? {
        store.previousPerformance(exerciseID: exerciseID, machineID: variation.machineID, tag: variation.freeWeightTag,
                                  presetID: variation.presetID, gymID: nil)?.layers.first
    }

    /// Other exercises for captures: an assisted one (least-assistance records), a bodyweight
    /// one (Hanging Knee Raise re-typed to Bodyweight, as the history load-type menu would, so the
    /// "Bodyweight record" shows), a BW + added one, one never trained, and the user-made one
    /// (its Rename… row).
    private func applyVariant(_ variant: String) {
        func named(_ name: String) -> UUID? { store.exercises.first { $0.name == name }?.id }
        if ExercisesVariant.has(variant, "assisted") { variantID = named("Assisted Pull-Up") }
        if ExercisesVariant.has(variant, "bwplus") { variantID = named("Dip") }
        if ExercisesVariant.has(variant, "custom") { variantID = named("Landmine Press") }
        if ExercisesVariant.has(variant, "untrained") {
            let trained = Set(store.workouts.flatMap { $0.entries.map(\.exerciseID) })
            variantID = store.exercises.filter { $0.isSeeded && !trained.contains($0.id) && $0.muscleGroup != nil }
                .sorted { $0.name < $1.name }.first { $0.name == "Nordic Hamstring Curl" }?.id
                ?? store.exercises.first { !trained.contains($0.id) }?.id
        }
        if ExercisesVariant.has(variant, "bodyweight"), let id = named("Hanging Knee Raise") {
            store.setLoadType(.bodyweight, exerciseID: id)
            for workout in store.workouts {
                for entry in workout.entries where entry.exerciseID == id {
                    store.retypeEntry(entry.id, to: .bodyweight, workoutID: workout.id)
                }
            }
            variantID = id
        }
    }

    // MARK: Hero

    private func hero(_ exercise: Exercise) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            // At accessibility sizes the disc would take a row of its own; the tags carry it.
            if !typeSize.isAccessibilitySize {
                ExercisesEquipmentDisc(tag: exercise.exercisesGlyphTag, size: 60)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    ExercisesFamilyMark(family: exercise.family)
                    Text(exercise.muscleGroup?.label ?? "Uncategorized")
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                Text(exercise.name)
                    .font(look.font.title)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                ExercisesFlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(exercise.exercisesShownTags) { tag in ExercisesTag(tag.label) }
                    ExercisesTag(exercise.loadType.badge, symbol: exercise.loadType.exercisesRankSymbol)
                    if !exercise.isSeeded { ExercisesTag("Custom") }
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
    }

    private func statItems(_ stat: ExercisesCatalogStat) -> [ExercisesStat] {
        var items = [ExercisesStat(value: Format.grouped(stat.workouts), label: stat.workouts == 1 ? "Workout" : "Workouts")]
        if let last = stat.lastTrained {
            items.append(ExercisesStat(value: ExercisesDates.relative(last, now: store.now), label: "Last trained", isWord: true))
        }
        items.append(ExercisesStat(value: Format.grouped(stat.workingSets), label: stat.workingSets == 1 ? "Set" : "Sets"))
        return items
    }

    // MARK: Progress (the bold element)

    @ViewBuilder
    private func progress(_ exercise: Exercise, variations: [ProgressVariation], layer: PerformanceLayer?) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Progress")
            if let main = variations.first, let series = store.progressSeries(exerciseID: exerciseID, variationID: main.id) {
                VStack(spacing: 0) {
                    Button { router.push(.progress(exerciseID: exerciseID, variationID: main.id)) } label: {
                        mainProgress(exercise, variation: main, series: series, layer: layer)
                    }
                    .buttonStyle(ExercisesRowPressStyle())
                    ForEach(variations.dropFirst()) { variation in
                        LookDivider().padding(.leading, 16)
                        variationRow(exercise, variation)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
                .lookSurface(.tile)
            } else {
                EmptyStateView(symbol: "chart.xyaxis.line", title: "No sets logged yet")
                    .lookSurface(.panel)
            }
        }
    }

    private func mainProgress(_ exercise: Exercise, variation: ProgressVariation, series: ProgressSeries,
                              layer: PerformanceLayer?) -> some View {
        let unit = store.displayUnit
        let change = store.progressChange(series, metric: .bestSet)
        let points = chartPoints(series, loadType: variation.loadType, unit: unit)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(variation.label)
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            if let best = layer?.best {
                // Marked only when the newest session set it (never a first time or a tie).
                ExercisesBestValue(value: best, loadType: variation.loadType, rowUnit: unit, style: .hero,
                                   marked: series.points.count > 1 && series.points.last?.isRecord == true)
            }
            if layer?.oneRepMaxKg != nil || change != nil {
                figures(series: series, layer: layer, unit: unit)
            }
            if points.count > 1 {
                ProgressLineChart(points: points, unit: unit.label, height: 128)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * chartReveal)
                        }
                    }
                    .appearProgress($chartReveal, delay: 0.15, duration: 0.9)
                    .padding(.top, 4)
                    .allowsHitTesting(false)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the progress chart")
    }

    private func figures(series: ProgressSeries, layer: PerformanceLayer?, unit: WeightUnit) -> some View {
        let change = store.progressChange(series, metric: .bestSet)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 26) { figureItems(series: series, layer: layer, unit: unit, change: change) }
            VStack(alignment: .leading, spacing: 12) { figureItems(series: series, layer: layer, unit: unit, change: change) }
        }
    }

    @ViewBuilder
    private func figureItems(series: ProgressSeries, layer: PerformanceLayer?, unit: WeightUnit, change: Double?) -> some View {
        if let kg = layer?.oneRepMaxKg {
            figure(value: Format.grouped(unit.fromKg(kg)), unit: unit.label, label: "1RM")
        }
        if let change {
            figure(value: Format.percent(change), unit: nil, label: "Since first session")
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

    private func chartPoints(_ series: ProgressSeries, loadType: LoadType, unit: WeightUnit) -> [ProgressChartPoint] {
        if loadType == .bodyweight {
            return series.points.map { ProgressChartPoint(date: $0.date, value: Double($0.best.reps), isRecord: $0.isRecord) }
        }
        return ProgressChartPoint.bestSet(series.points, in: unit)
    }

    private func variationRow(_ exercise: Exercise, _ variation: ProgressVariation) -> some View {
        let best = layerFor(variation)?.best
        // "Chest Press 2 · Narrow grip" reads as equipment, then what varies: the equipment
        // is the row title, the preset / other gym joins the day count underneath.
        let parts = variation.label.components(separatedBy: " · ")
        let detail = ([parts.dropFirst().joined(separator: " · ")].filter { !$0.isEmpty }
                      + [Format.count(variation.trainingDays, "day")]).joined(separator: " · ")
        return Button { router.push(.progress(exerciseID: exerciseID, variationID: variation.id)) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(parts.first ?? variation.label)
                        .font(look.exercisesRowTitle)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if typeSize.isAccessibilitySize, let best {
                        ExercisesBestValue(value: best, loadType: variation.loadType, rowUnit: store.displayUnit, style: .row,
                                           marked: false)
                    }
                }
                Spacer(minLength: 8)
                if !typeSize.isAccessibilitySize, let best {
                    ExercisesBestValue(value: best, loadType: variation.loadType, rowUnit: store.displayUnit, style: .row,
                                           marked: false)
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
    }

    // MARK: Rep records

    /// The rep-count records of the main variation, by load type: Weighted the heaviest,
    /// Assisted the least assistance ("−70"), BW + added the most added ("+15", or "BW" for a
    /// plain set), Bodyweight one tile with the most reps (the kept "Bodyweight record" title).
    private func records(_ layer: PerformanceLayer, loadType: LoadType) -> some View {
        let columns = [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 84), spacing: 10)]
        return VStack(alignment: .leading, spacing: look.space.header) {
            // "Least-assistance records · lower is better": the direction rides as the trailing
            // caption so the title stays on one line.
            let parts = loadType.exercisesRecordsTitle.components(separatedBy: " · ")
            SectionHeader(parts[0], trailing: parts.count > 1 ? parts[1] : nil)
            if loadType == .bodyweight, let most = layer.mostReps {
                recordTile(caption: "Most reps", figure: "\(most)", unit: most == 1 ? "rep" : "reps", date: nil,
                           spoken: "Most reps, \(most)")
                    .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 180, alignment: .leading)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(layer.repBests) { best in
                        recordTile(caption: Format.reps(best.reps),
                                   figure: ExercisesValue.figure(best.value, loadType: loadType),
                                   unit: ExercisesValue.figureHasUnit(best.value, loadType: loadType) ? best.value.unit.label : nil,
                                   date: best.date,
                                   spoken: "\(Format.reps(best.reps)), \(ExercisesValue.spoken(best.value, loadType: loadType))")
                    }
                }
            }
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
                Text(Format.shortDate(date))
                    .font(look.font.caption)
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.stat)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.map { "\(spoken), \(Format.shortDate($0))" } ?? spoken)
    }

    // MARK: Setup

    private func setup(_ exercise: Exercise) -> some View {
        let presetLine = exercise.presets.isEmpty ? "No presets yet"
            : exercise.presets.map(\.name).joined(separator: " · ")
        return LookList(separatorInset: 54) {
            LookRow("Load type", symbol: exercise.loadType.exercisesSymbol,
                    action: { router.present(.loadType(exerciseID: exerciseID)) }) {
                Text(exercise.loadType.badge)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
            }
            LookRow("Presets", subtitle: presetLine, symbol: "slider.horizontal.3",
                    value: exercise.presets.isEmpty ? nil : "\(exercise.presets.count)",
                    action: { router.present(.presets(exerciseID: exerciseID)) })
            if !exercise.isSeeded {
                LookRow("Rename…", symbol: "pencil", showsChevron: false, action: {
                    renameText = exercise.name
                    renameShown = true
                })
            }
        }
    }

    // MARK: Machines

    @ViewBuilder
    private func machines(_ exercise: Exercise) -> some View {
        let uses = store.exercisesMachines(exerciseID)
        if !uses.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Machines")
                LookList(separatorInset: 14) {
                    ForEach(uses) { use in machineRow(use, loadType: exercise.loadType) }
                }
            }
        }
    }

    private func machineRow(_ use: ExercisesMachineUse, loadType: LoadType) -> some View {
        let ax = typeSize.isAccessibilitySize
        return Button { router.push(.machineDetail(machineID: use.machine.id)) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(use.machine.label)
                        .font(look.exercisesRowTitle)
                        .foregroundStyle(look.textPrimary)
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
        }
        .buttonStyle(ExercisesRowPressStyle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func machineUse(_ use: ExercisesMachineUse, loadType: LoadType, alignment: HorizontalAlignment) -> some View {
        if use.workouts > 0 {
            VStack(alignment: alignment, spacing: 3) {
                if let best = use.best {
                    ExercisesBestValue(value: best, loadType: loadType, rowUnit: store.displayUnit, style: .row, marked: false)
                }
                Text(Format.count(use.workouts, "workout"))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textTertiary)
            }
        }
    }

    // MARK: History

    @ViewBuilder
    private func history(_ exercise: Exercise) -> some View {
        let sessions = store.exercisesRecentSessions(exerciseID)
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("History")
                LookList {
                    ForEach(sessions) { session in sessionRow(session) }
                }
            }
        }
    }

    private func sessionRow(_ session: ExercisesSession) -> some View {
        Button { router.push(.workoutDetail(workoutID: session.workoutID)) } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Text("\(Calendar.app.component(.day, from: session.date))")
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.textPrimary)
                    Text(ExercisesDates.weekdayShort(session.date))
                        .font(look.font.caption)
                        .foregroundStyle(look.textSecondary)
                }
                .frame(minWidth: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(look.exercisesRowTitle)
                        .foregroundStyle(look.textPrimary)
                    if !session.equipment.isEmpty {
                        Text(session.equipment)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ExercisesFlowLayout(spacing: 10, lineSpacing: 4) {
                        ForEach(session.sets) { set in setText(set, session: session) }
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
        }
        .buttonStyle(ExercisesRowPressStyle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func setText(_ set: LoggedSet, session: ExercisesSession) -> some View {
        if let value = set.value {
            ExercisesSetText(value: value, type: set.type, loadType: session.loadType, rowUnit: store.displayUnit,
                             isNewBest: session.newBestSetIDs.contains(set.id))
        }
    }
}

// MARK: - Equipment disc

/// The exercise's equipment glyph in the look's disc (A a raised square, B a round fill,
/// C an outlined circle).
struct ExercisesEquipmentDisc: View {
    var tag: EquipmentTag?
    var size: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        ExercisesGlyph(tag, style: .title2)
            .foregroundStyle(look.textPrimary)
            .frame(width: size, height: size)
            .background {
                switch look.id {
                case .floodlight: RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous).fill(look.surfaceRaised)
                case .anatomy: Circle().fill(look.controlFill)
                case .paper, .carbon: Circle().fill(look.surface).overlay { Circle().strokeBorder(look.outline, lineWidth: 2) }
                }
            }
            .accessibilityHidden(true)
    }
}
