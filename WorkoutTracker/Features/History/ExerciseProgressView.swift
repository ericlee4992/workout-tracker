import Charts
import SwiftData
import SwiftUI

// Milestone 8, ticket 01 — progress charts (the milestone-4 feature, brought
// forward). Swift Charts, no third-party dependencies (SPEC). Floodlight redesign ticket 05:
// the title and a variation capsule, metric pills, one panel with the selected day as the big
// number, the change since the first session and the chart (new-best bursts, a y-axis padded
// around the data), then the rep-count records and the sessions (tap one to open it).
//
// The maths lives in `Domain/ProgressSeries.swift` so it can be proven without
// rendering anything; this file is presentation only. What it must not do is
// draw a picture more confident than the data behind it — an assisted series
// plotted as "decline", or a slope between two dots, is the same false
// precision D9/D25 mark with `≈`, and harder to disbelieve because it looks
// like maths.

struct ExerciseProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let exerciseID: UUID
    let exerciseName: String

    /// Which variation is on screen. Resolved from HISTORY, never from the live
    /// exercise: the caller used to pass `exercise.loadType`, so a D47
    /// correction made old history vanish from its own chart.
    @State private var variation: ProgressVariationKey?

    /// - Parameter initialVariation: the variation to open on, when the caller
    ///   is looking at one — History opens the chart on the variation THAT
    ///   session used (its snapshot type, tag and preset), not on whichever the
    ///   user has trained most. nil defers to history.
    init(exerciseID: UUID, exerciseName: String, initialVariation: ProgressVariationKey? = nil) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        _variation = State(initialValue: initialVariation)
    }

    @State private var metric: Metric = .bestSet
    /// The day the thumb picked; nil shows the most recent.
    @State private var selectedDate: Date?
    @State private var ticks = 0
    @State private var titleInBar = false
    @Environment(\.dismiss) private var dismiss

    enum Metric: String, CaseIterable, Identifiable {
        case bestSet = "Best set"
        case volume = "Volume"
        case e1rm = "1RM"
        var id: String { rawValue }
    }

    var body: some View {
        let data = ProgressData(history: history, variation: resolvedVariation)
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(exerciseName)
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    variationControl(data)
                }
                switch data.series.confidence {
                case .empty:
                    // The strings are the ones this screen always had.
                    EmptyStateView(
                        symbol: "chart.xyaxis.line",
                        title: availableVariations(data).count > 1 ? "Nothing to chart here" : "No sets logged yet",
                        message: emptyDescription(data))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("progressEmpty")
                case .single:
                    singlePanel(data)
                    records(data)
                    sessions(data)
                case .series(let days):
                    if availableMetrics.count > 1 {
                        SegmentedPills(availableMetrics.map(\.rawValue), selection: Binding(
                            get: { availableMetrics.firstIndex(of: metric) ?? 0 },
                            set: { metric = availableMetrics[$0]; ticks += 1 }))
                            .accessibilityLabel("Metric")
                    }
                    chartPanel(data, days: days)
                    records(data)
                    sessions(data)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .lookSheetGround()
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 90 : 50)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(look.groundSheet, for: .navigationBar)
        .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            // The large title above says it; the bar takes it once scrolled.
            ToolbarItem(placement: .principal) {
                Text(exerciseName)
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .opacity(titleInBar ? 1 : 0)
                    .accessibilityHidden(!titleInBar)
            }
            // A sheet that only shows closes (both callers present it as a sheet).
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .tint(look.textPrimary)
                    .accessibilityIdentifier("closeProgress")
            }
        }
        .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        .sensoryFeedback(.selection, trigger: ticks)
        // Resolved once: the default reads the whole history, and every part of the screen
        // asks for the variation.
        .onAppear {
            if variation == nil { variation = ProgressSeriesMath.defaultVariation(in: data.history.map(\.input)) }
        }
    }

    // MARK: Variation

    /// Offered as a menu only when this exercise has history under more than one variation.
    /// D36 forbids pooling them, so the alternative to a picker is history the user simply
    /// cannot reach. Always shown above the state switch: the empty and single states need it
    /// too (codex-review 01, high — a warmup-only variation opened from History was a dead end).
    @ViewBuilder
    private func variationControl(_ data: ProgressData) -> some View {
        let options = availableVariations(data)
        let labels = variationLabels(options)
        let current = options.first { $0.key == resolvedVariation }
        let text = current.map { label(for: $0, labels: labels) } ?? exerciseName
        let face = HStack(spacing: 8) {
            LookIcon(glyph(resolvedVariation.equipment), style: .footnote)
            Text(text)
                .font(.system(.subheadline, weight: .semibold))
                .multilineTextAlignment(.leading)
            if options.count > 1 {
                Image(systemName: "chevron.up.chevron.down").font(.system(.caption, weight: .bold))
            }
        }
        .foregroundStyle(look.textPrimary)
        if options.count > 1 {
            Menu {
                Picker("Variation", selection: Binding(
                    get: { resolvedVariation },
                    set: { variation = $0; selectedDate = nil; metric = .bestSet; ticks += 1 })
                ) {
                    ForEach(options, id: \.key) { item in
                        Text(label(for: item, labels: labels)).tag(item.key)
                    }
                }
            } label: {
                face.padding(.horizontal, 14).frame(minHeight: 44).lookSurface(.raised, radius: 22)
            }
            .accessibilityLabel(text)
            .accessibilityIdentifier("chartVariationPicker")
        } else {
            face.foregroundStyle(look.textSecondary)
        }
    }

    private func label(for item: (key: ProgressVariationKey, days: Int), labels: [ProgressVariationKey: String]) -> String {
        item.days == 0
            ? "\(labels[item.key] ?? "") · nothing eligible"
            : "\(labels[item.key] ?? "") · \(item.days) day\(item.days == 1 ? "" : "s")"
    }

    private func glyph(_ equipment: ProgressEquipment) -> String {
        switch equipment {
        case .machine: LookIcon.machine
        case .freeWeight(let tag): tag.historySymbol
        case .unrecorded: "circle.dashed"
        }
    }

    // MARK: Panels

    /// One session: its number, and no line — a slope needs two points.
    private func singlePanel(_ data: ProgressData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let point = data.series.points.first {
                heroValue(point, data: data)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(point.date.formatted(date: .abbreviated, time: .omitted)), \(asEntered(point))")
                    .accessibilityIdentifier("progressSinglePoint")
            }
            Text("One session").font(look.font.footnote).foregroundStyle(look.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    private func chartPanel(_ data: ProgressData, days: Int) -> some View {
        let points = plottedPoints(data)
        let selected = selectedPoint(data) ?? data.series.points.last
        return VStack(alignment: .leading, spacing: 16) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                if let selected {
                    heroValue(selected, data: data)
                        // The number the user actually typed lives here (D25: the chart plots
                        // converted values), and a normal view is something a test can see.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(selected.date.formatted(date: .abbreviated, time: .omitted)), \(calloutValue(selected, data: data))")
                        .accessibilityIdentifier("chartSelection")
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
                if let change = change(data) {
                    ProgressChangeBadge(fraction: change, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
                }
            }
            ProgressChart(points: points, selectedDate: selected?.date, yLabel: yLabel(data)) { date in
                if selectedDate != date {
                    selectedDate = date
                    ticks += 1
                }
            }
            .id(metric)
            .transition(.opacity)
            .accessibilityIdentifier("progressChart")
            // The one caveat that survives the copy cull (ticket 06, codex-review 06): two or
            // three days are a drawn line but not much of a trend.
            if days < 4 {
                Text("Only \(days) days logged — read the shape with caution.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
        }
        .padding(16)
        .lookSurface(.panel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: metric)
    }

    /// The selected day as the big number, its date under it with a NEW BEST mark.
    private func heroValue(_ point: ProgressPoint, data: ProgressData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                switch metric {
                case .bestSet:
                    if resolvedVariation.loadType != .bodyweight, let value = point.bestValue, let unit = point.bestUnit {
                        Text(LookFormat.number(value)).font(look.font.heroNumber)
                        Text(unit.rawValue).font(.system(.title3, weight: .semibold)).foregroundStyle(look.textSecondary)
                        Text("× \(point.bestReps ?? 0)").font(look.font.bigNumber)
                    } else {
                        Text("\(point.bestReps ?? 0)").font(look.font.heroNumber)
                        Text("reps").font(.system(.title3, weight: .semibold)).foregroundStyle(look.textSecondary)
                    }
                case .volume, .e1rm:
                    let kg = metric == .volume ? point.volumeKg : (point.e1rmKg ?? 0)
                    Text(LookFormat.groupedDecimal(WeightMath.convert(kg, from: .kg, to: displayUnit).rounded()))
                        .font(look.font.heroNumber)
                    Text(displayUnit.rawValue).font(.system(.title3, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
            }
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(spacing: 8) {
                Text(metric == .e1rm ? "1RM · \(HistoryFormat.shortDayTitle(point.date))" : HistoryFormat.shortDayTitle(point.date))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                if metric == .bestSet && data.recordDays.contains(point.date) { NewBestBadge(kind: .newBest) }
            }
        }
    }

    // MARK: Records

    /// Best set per rep count (1–12) in this variation — or, for plain bodyweight, the most
    /// reps. Tapping one selects its day on the chart.
    @ViewBuilder
    private func records(_ data: ProgressData) -> some View {
        let bests = repBests(data)
        if !bests.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader(recordsTitle)
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 10) { ForEach(bests, id: \.reps) { recordCell($0, data: data) } }
                } else if bests.count <= 4 {
                    HStack(spacing: 10) { ForEach(bests, id: \.reps) { recordCell($0, data: data) } }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(bests, id: \.reps) { recordCell($0, data: data).frame(width: 96) }
                        }
                        .padding(.horizontal, look.space.margin)
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, -look.space.margin)
                }
            }
        }
    }

    private var recordsTitle: String {
        switch resolvedVariation.loadType {
        case .weighted: "Weight records"
        case .assisted: "Least-assistance records · lower is better"
        case .bodyweightPlus: "Added-weight records"
        case .bodyweight: "Bodyweight record"
        }
    }

    private func repBests(_ data: ProgressData) -> [RecordAchievement] {
        if resolvedVariation.loadType == .bodyweight {
            return RecordsMath.mostRepsRecord(among: data.scoped).map { [$0] } ?? []
        }
        return RecordsMath.repCountBests(among: data.scoped, loadType: resolvedVariation.loadType)
            .values.sorted { $0.reps < $1.reps }
    }

    private func recordCell(_ best: RecordAchievement, data: ProgressData) -> some View {
        let day = Calendar.current.startOfDay(for: best.completedAt)
        let value = best.weightValue.map { "\(LookFormat.number($0)) \(best.weightUnit?.rawValue ?? "")" }
        return Button {
            guard data.series.points.contains(where: { $0.date == day }) else { return }
            metric = .bestSet
            selectedDate = day
            ticks += 1
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(LookFormat.reps(best.reps))
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(best.weightValue.map { LookFormat.number($0) } ?? "\(best.reps)")
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.textPrimary)
                    Text(best.weightUnit?.rawValue ?? "reps")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Text(LookFormat.shortDate(best.completedAt)).font(look.font.caption2).foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.tile, radius: look.radius.stat)
            .overlay {
                if selectedDate == day {
                    RoundedRectangle(cornerRadius: look.radius.stat, style: .continuous)
                        .strokeBorder(look.textPrimary, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("\(LookFormat.reps(best.reps)), \(value ?? LookFormat.reps(best.reps)), \(LookFormat.shortDate(best.completedAt))")
    }

    // MARK: Sessions

    /// Every day of this variation, newest first; each opens its workout.
    private func sessions(_ data: ProgressData) -> some View {
        let points = Array(data.series.points.reversed())
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Sessions", trailing: HistoryRendering.pluralized(points.count, "day", "days"))
            VStack(spacing: 0) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    if index > 0 { LookDivider().padding(.leading, 16) }
                    sessionRow(point, data: data)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
            .lookSurface(.panel)
        }
    }

    @ViewBuilder
    private func sessionRow(_ point: ProgressPoint, data: ProgressData) -> some View {
        let row = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HistoryFormat.shortDayTitle(point.date))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                Text(asEntered(point))
                    .font(look.historyRowNumber)
                    .foregroundStyle(look.textPrimary)
            }
            Spacer(minLength: 8)
            if data.recordDays.contains(point.date) { NewBestBadge(kind: .newBest) }
            if data.workouts[point.date] != nil {
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(point.date == selectedDate ? look.pressedFill : .clear)
        .contentShape(Rectangle())
        if let workout = data.workouts[point.date] {
            NavigationLink(value: workout) { row }
                .buttonStyle(HistoryRowPressStyle())
                .accessibilityIdentifier("progressSession")
        } else {
            row
        }
    }

    // MARK: Chart values

    private func plottedPoints(_ data: ProgressData) -> [ProgressChart.Point] {
        data.series.points.compactMap { point in
            plotted(point).map {
                ProgressChart.Point(date: point.date, value: $0,
                                    isRecord: metric == .bestSet && data.recordDays.contains(point.date))
            }
        }
    }

    /// The point nearest the selected day, or nil when nothing is selected.
    private func selectedPoint(_ data: ProgressData) -> ProgressPoint? {
        guard let selectedDate else { return nil }
        return data.series.points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    /// Since the first session, for the metric on screen. Best set: the Domain's rule (assisted
    /// improves downward). Volume and 1RM are weighted only, where more is better.
    private func change(_ data: ProgressData) -> Double? {
        switch metric {
        case .bestSet: return ProgressSeriesMath.change(data.series)
        case .volume:
            return ProgressSeriesMath.change(first: data.series.points.first?.volumeKg, last: data.series.points.last?.volumeKg)
        case .e1rm:
            return ProgressSeriesMath.change(first: data.series.points.first?.e1rmKg, last: data.series.points.last?.e1rmKg)
        }
    }

    /// The metric being viewed. Best set is the number the user typed;
    /// volume and 1RM are in the display unit, plain (D52 — the point still
    /// records which units its contributors were entered in).
    private func calloutValue(_ point: ProgressPoint, data: ProgressData) -> String {
        switch metric {
        case .bestSet:
            return asEntered(point)
        case .volume:
            return WeightMath.displayLabel(kilograms: point.volumeKg, in: displayUnit)
        case .e1rm:
            guard let kg = point.e1rmKg else { return "—" }
            return WeightMath.displayLabel(kilograms: kg, in: displayUnit)
        }
    }

    /// The app's default weight unit (D2/T7 precedence, app level).
    ///
    /// Reported 2026-08-26: a chart of lb-logged sets plotted in kg. The series
    /// is computed in canonical kg so mixed-unit sessions share one axis (D25),
    /// but the AXIS should read in the unit the user thinks in.
    private var displayUnit: WeightUnit {
        let rows = (try? modelContext.fetch(FetchDescriptor<AppPreferences>())) ?? []
        return UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil,
            appPreference: AppPreferences.canonical(of: rows)?.unitPreference)
    }

    /// What the axis measures, in the display unit, plain (D52). Assisted improves DOWNWARD:
    /// inverting the axis would hide that; the label says it instead.
    private func yLabel(_ data: ProgressData) -> String {
        let suffix = " (\(displayUnit.rawValue))"
        switch metric {
        case .bestSet:
            return resolvedVariation.loadType == .bodyweight ? "Reps" : data.series.loadAxisLabel + suffix
        case .volume: return "Volume" + suffix
        case .e1rm: return "1RM" + suffix
        }
    }

    private func plotted(_ point: ProgressPoint) -> Double? {
        let convert = { WeightMath.convert($0, from: .kg, to: displayUnit) }
        switch metric {
        case .bestSet:
            // Bodyweight plots REPS, which have no unit to convert.
            return resolvedVariation.loadType == .bodyweight ? point.bestKg : point.bestKg.map(convert)
        case .volume: return convert(point.volumeKg)
        case .e1rm: return point.e1rmKg.map(convert)
        }
    }

    /// Volume and e1RM are weighted-only concepts (D20, `RecordsMath`). Offering
    /// them for an assisted movement would draw a flat zero line and invite the
    /// user to read meaning into it.
    private var availableMetrics: [Metric] {
        resolvedVariation.loadType == .weighted ? Metric.allCases : [.bestSet]
    }

    /// D9/D25: show the number the user typed. The chart plots canonical kg so
    /// mixed-unit sessions share an axis, but the text says what was entered.
    private func asEntered(_ point: ProgressPoint) -> String {
        // Plain bodyweight has no load to show — reps ARE the achievement.
        if resolvedVariation.loadType == .bodyweight {
            return point.bestReps.map { "\($0) reps" } ?? "—"
        }
        guard let value = point.bestValue, let unit = point.bestUnit else { return "—" }
        let reps = point.bestReps.map { " × \($0)" } ?? ""
        return "\(Format.weight(value)) \(unit.rawValue)\(reps)"
    }

    /// Names the variation that is empty when others are not, so the state
    /// reads as "nothing HERE" rather than "nothing at all".
    private func emptyDescription(_ data: ProgressData) -> String {
        let options = availableVariations(data)
        return options.count > 1
            ? "No eligible sets under \(variationLabels(options)[resolvedVariation] ?? exerciseName). Warmups do not count. Pick another variation above."
            : "Log \(exerciseName) in a workout and its progress appears here."
    }

    // MARK: Data

    /// One read of this exercise's history per render: the series, the variation's sets and
    /// each day's workout.
    private struct ProgressData {
        var history: [(input: RecordSetInput, workout: Workout)]
        var series: ProgressSeries
        var scoped: [RecordSetInput]
        var recordDays: Set<Date>
        /// The workout each charted day came from (the latest that day), for Sessions.
        var workouts: [Date: Workout]

        init(history: [(input: RecordSetInput, workout: Workout)], variation: ProgressVariationKey) {
            self.history = history
            let inputs = history.map(\.input)
            series = ProgressSeriesMath.series(for: inputs, variation: variation)
            scoped = ProgressSeriesMath.scoped(inputs, to: variation)
            recordDays = ProgressSeriesMath.recordDays(series)
            var byDay: [Date: Workout] = [:]
            for item in history where ProgressSeriesMath.scoped([item.input], to: variation).count == 1
                && RecordsMath.isEligible(item.input) {
                let day = Calendar.current.startOfDay(for: item.input.completedAt ?? .distantPast)
                if let current = byDay[day], current.startedAt >= item.workout.startedAt { continue }
                byDay[day] = item.workout
            }
            workouts = byDay
        }
    }

    /// Every finished set logged against this exercise, in SNAPSHOT terms
    /// (D23), across all variations, with its workout. Scoping happens in the series.
    private var history: [(input: RecordSetInput, workout: Workout)] {
        let sets = (try? modelContext.fetch(FetchDescriptor<SetRecord>())) ?? []
        return sets.compactMap { set -> (input: RecordSetInput, workout: Workout)? in
            // Snapshot values only, and finished workouts only — an
            // in-progress session is not history yet.
            guard !set.isDeleted, let entry = set.entry, !entry.isDeleted,
                  entry.snapshotExerciseID == exerciseID,
                  let workout = entry.workout, !workout.isDeleted,
                  workout.finishedAt != nil
            else { return nil }
            return (RecordSetInput(
                loadType: entry.snapshotLoadType,
                exerciseID: entry.snapshotExerciseID,
                gymID: entry.snapshotGymID,
                machineID: entry.snapshotMachineID,
                modelID: entry.snapshotModelID,
                freeWeightTag: entry.snapshotFreeWeightTag,
                presetID: entry.snapshotPresetID,
                setType: set.type, reps: set.reps,
                weightValue: set.weightValue, weightUnit: set.weightUnit,
                normalizedKg: set.normalizedKg, completedAt: set.completedAt), workout)
        }
    }

    /// The variation on screen, defaulting to the one with the most history.
    private var resolvedVariation: ProgressVariationKey {
        variation
            ?? ProgressSeriesMath.defaultVariation(in: history.map(\.input))
            ?? ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil)
    }

    /// The variations this exercise actually has history for, in the Domain's
    /// order — the picker lists what the user has trained, not every preset
    /// that happens to exist.
    private func availableVariations(_ data: ProgressData) -> [(key: ProgressVariationKey, days: Int)] {
        let ranked = ProgressSeriesMath.rankedVariations(in: data.history.map(\.input))
        // The variation on screen must be IN the list even when it has nothing
        // eligible to chart (a warmup-only session opened from History): a
        // Picker whose selection matches no row shows its title instead, and
        // the user cannot see what they are looking at, let alone leave it.
        let current = resolvedVariation
        guard !ranked.contains(where: { $0.key == current }) else { return ranked }
        return ranked + [(key: current, days: 0)]
    }

    /// Distinct labels for every listed variation — the Domain owns the rule
    /// (`ProgressSeriesMath.labels`); this only supplies the snapshot words.
    private func variationLabels(_ options: [(key: ProgressVariationKey, days: Int)]) -> [ProgressVariationKey: String] {
        ProgressSeriesMath.labels(for: options.map { (key: $0.key, words: words(for: $0.key)) })
    }

    /// The snapshot words for a variation — as logged, not as today's rows say
    /// (D23). Naming policy lives in `ProgressSeriesMath.labels`.
    private func words(for key: ProgressVariationKey) -> ProgressVariationWords {
        let entries = (try? modelContext.fetch(FetchDescriptor<ExerciseEntry>())) ?? []
        var equipmentName: String?
        var gymName: String?
        switch key.equipment {
        case .freeWeight(let tag):
            equipmentName = tag.label
        case .machine(let machineID):
            let entry = entries.first { $0.snapshotMachineID == machineID }
            equipmentName = entry?.snapshotMachineLabel ?? "Machine"
            gymName = entry?.snapshotGymName
        case .unrecorded:
            break
        }
        let presetName = key.presetID.map { id in
            entries.first { $0.snapshotPresetID == id }?.snapshotPresetName ?? "Variation"
        }
        return ProgressVariationWords(
            loadType: key.loadType, equipment: key.equipment,
            equipmentName: equipmentName, gymName: gymName, presetName: presetName)
    }
}

// MARK: - Chart

/// Points joined by a monotone line (it never crosses the observations, where Catmull-Rom could
/// invent a hump — codex-review-06), new-best bursts, a y-axis padded around the data (never
/// from zero), and a selection rule the thumb drags.
struct ProgressChart: View {
    struct Point: Identifiable, Hashable {
        var id: Date { date }
        var date: Date
        var value: Double
        var isRecord: Bool
    }

    var points: [Point]
    var selectedDate: Date?
    var yLabel: String
    var onSelect: (Date) -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0

    private var domain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.18, max(2, hi * 0.03))
        return (lo - pad)...(hi + pad)
    }

    /// Ticks on real sessions: the first, the last and one near the middle when it clears both.
    private var tickDates: [Date] {
        guard let first = points.first?.date, let last = points.last?.date else { return [] }
        if points.count < 2 { return [first] }
        if typeSize.isAccessibilitySize || points.count < 4 { return [first, last] }
        let span = last.timeIntervalSince(first)
        let middle = first.addingTimeInterval(span / 2)
        guard let mid = points.map(\.date).min(by: { abs($0.timeIntervalSince(middle)) < abs($1.timeIntervalSince(middle)) }),
              mid.timeIntervalSince(first) > span * 0.3, last.timeIntervalSince(mid) > span * 0.3 else { return [first, last] }
        return [first, mid, last]
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value(yLabel, p.value))
                    .foregroundStyle(look.done)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let selectedDate {
                RuleMark(x: .value("Date", selectedDate))
                    .foregroundStyle(look.textPrimary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            ForEach(points) { p in
                PointMark(x: .value("Date", p.date), y: .value(yLabel, p.value))
                    .symbol { marker(p, selected: p.date == selectedDate) }
            }
        }
        .chartYScale(domain: domain)
        .chartYAxisLabel(yLabel)
        // The last marker (often a new best) clears the trailing y labels.
        .chartXScale(range: .plotDimension(startPadding: 14, endPadding: 30))
        .chartXAxis {
            AxisMarks(values: tickDates) { value in
                AxisTick(length: 4).foregroundStyle(look.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true,
                               anchor: value.index == value.count - 1 && value.count > 1 ? .topTrailing
                                   : (value.index == 0 && value.count > 1 ? .topLeading : .top))
                    .foregroundStyle(look.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(look.hairline)
                AxisValueLabel(horizontalSpacing: 8).foregroundStyle(look.textTertiary)
            }
        }
        // A tap picks a day; a short press then a drag scrubs. A bare drag stays the page's
        // scroll (a zero-distance drag here would trap every swipe that starts on the chart).
        .chartGesture { proxy in
            LongPressGesture(minimumDuration: 0.15)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    if case .second(true, let drag?) = value { select(atX: drag.location.x, proxy: proxy) }
                }
                .exclusively(before: SpatialTapGesture().onEnded { select(atX: $0.location.x, proxy: proxy) })
        }
        // Axis labels readable but capped, so dates never collide at accessibility sizes (the
        // selected value above the chart carries the number in full size).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(height: typeSize.isAccessibilitySize ? 270 : 220)
        .opacity(reduceMotion ? 1 : reveal)
        .onAppear {
            guard reveal == 0 else { return }
            if reduceMotion { reveal = 1 } else { withAnimation(.easeOut(duration: 0.45)) { reveal = 1 } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress, \(points.count) days")
        .accessibilityAdjustableAction { direction in
            guard let index = points.firstIndex(where: { $0.date == selectedDate }) ?? (points.isEmpty ? nil : points.count - 1)
            else { return }
            switch direction {
            case .increment: if index + 1 < points.count { onSelect(points[index + 1].date) }
            case .decrement: if index > 0 { onSelect(points[index - 1].date) }
            @unknown default: break
            }
        }
    }

    private func select(atX x: CGFloat, proxy: ChartProxy) {
        guard let date: Date = proxy.value(atX: x),
              let nearest = points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
        else { return }
        onSelect(nearest.date)
    }

    @ViewBuilder
    private func marker(_ point: Point, selected: Bool) -> some View {
        if point.isRecord {
            Image(systemName: "burst.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(look.positive)
                .background(Circle().fill(look.surface).frame(width: 10, height: 10))
                .scaleEffect(selected ? 1.5 : 1)
        } else if selected {
            Circle().fill(look.textPrimary).frame(width: 12, height: 12)
                .overlay { Circle().strokeBorder(look.surface, lineWidth: 2) }
        } else {
            Circle().fill(look.surface).frame(width: 8, height: 8)
                .overlay { Circle().strokeBorder(look.done, lineWidth: 2) }
        }
    }
}

/// The change since the first session: a lit plate with an arrow when up, a quiet one when down.
struct ProgressChangeBadge: View {
    var fraction: Double
    var alignment: HorizontalAlignment = .trailing
    @Environment(\.look) private var look

    var body: some View {
        let up = fraction >= 0
        let rounded = Int((abs(fraction) * 100).rounded())
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: up ? "arrow.up" : "arrow.down").font(.system(.footnote, weight: .heavy))
                Text("\(rounded)%").font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
            }
            .foregroundStyle(up ? look.onDone : look.textPrimary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(up ? look.done : look.surfaceRaised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("Since first session").font(look.font.caption).foregroundStyle(look.textSecondary)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(up ? "Up" : "Down") \(rounded) percent since first session")
    }
}
