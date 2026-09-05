import Charts
import SwiftData
import SwiftUI

// Milestone 8, ticket 01 — progress charts (the milestone-4 feature, brought
// forward). Swift Charts, no third-party dependencies (SPEC).
//
// The maths lives in `Domain/ProgressSeries.swift` so it can be proven without
// rendering anything; this file is presentation only. What it must not do is
// draw a picture more confident than the data behind it — an assisted series
// plotted as "decline", or a slope between two dots, is the same false
// precision D9/D25 mark with `≈`, and harder to disbelieve because it looks
// like maths.

struct ExerciseProgressView: View {
    @Environment(\.modelContext) private var modelContext

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
    /// Raw x position from `chartXSelection`; resolved to the nearest point.
    @State private var selectedDate: Date?

    enum Metric: String, CaseIterable, Identifiable {
        case bestSet = "Best set"
        case volume = "Volume"
        case e1rm = "Est. 1RM"
        var id: String { rawValue }
    }

    var body: some View {
        List {
            // Above the state switch on purpose: the picker must exist in the
            // empty and single-session states too. codex-review 01 (high):
            // History could open the chart on a session whose variation has
            // one day, or only warmups, and the picker — rendered only under a
            // drawn series — vanished, stranding the user in a false empty
            // state with the rest of their history unreachable.
            if availableVariations.count > 1 {
                Section {
                    variationPicker
                }
            }
            switch series.confidence {
            case .empty:
                ContentUnavailableView(
                    availableVariations.count > 1 ? "Nothing to chart here" : "No sets logged yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text(emptyDescription))
                    .accessibilityIdentifier("progressEmpty")
            case .single:
                Section {
                    singlePoint
                } header: {
                    Text("One session")
                }
            case .series(let days):
                Section {
                    Picker("Metric", selection: $metric) {
                        ForEach(availableMetrics) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    chart
                        .frame(height: 240)
                        .accessibilityIdentifier("progressChart")
                    selectionRow
                } footer: {
                    // The one caveat that survives the copy cull (ticket 06,
                    // codex-review 06): two or three days are a drawn line but
                    // not much of a trend, and the count exists to say so.
                    if days < 4 {
                        Text("Only \(days) days logged — read the shape with caution.")
                    }
                }

                if let change = ProgressSeriesMath.change(series) {
                    Section("Change") {
                        LabeledContent("Since first session") {
                            Text(change >= 0 ? "+\(percent(change))" : percent(change))
                                .foregroundStyle(change >= 0 ? .green : .secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Chart

    @ViewBuilder
    private var chart: some View {
        Chart(series.points) { point in
            if let value = plotted(point) {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(yLabel, value))
                    .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(yLabel, value))
            }
            // The selected day is marked IN the chart, but its numbers are
            // shown in a row beneath it rather than as a floating callout: an
            // annotation overlaps the very line it describes on a phone-width
            // chart, and a normal view is also something a test can see.
            if let selected, selected.date == point.date, let value = plotted(point) {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                PointMark(
                    x: .value("Date", selected.date),
                    y: .value(yLabel, value))
                    .symbolSize(140)
            }
        }
        .chartYAxisLabel(yLabel)
        // Assisted improves DOWNWARD. Inverting the axis would hide that; the
        // label says it instead, so the shape of the line stays honest.
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        // An EXPLICIT overlay gesture rather than `.chartXSelection`.
        //
        // `chartXSelection` never fired here: this chart lives in a `List` row,
        // and the list's own scroll gesture wins. A `DragGesture` with
        // `minimumDistance: 0` claims taps and drags on the plot area itself,
        // which composes predictably inside a scrolling container.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                select(at: value.location, proxy: proxy, geometry: geometry)
                            }
                    )
            }
        }
    }

    /// Maps a touch to the day under it. Reads the x position through the
    /// chart proxy, so it stays correct whatever the axis does.
    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geometry[plotFrame].origin
        let x = location.x - origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        selectedDate = date
    }

    /// The point nearest the selected x position, or nil when nothing is
    /// selected. `chartXSelection` reports a raw date between data points, so
    /// the nearest day is what the user actually meant.
    private var selected: ProgressPoint? {
        guard let selectedDate else { return nil }
        return series.points.min {
            abs($0.date.timeIntervalSince(selectedDate))
                < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    /// WHAT THE TOOLTIP IS FOR, and why it is not just the plotted number: the
    /// chart plots canonical kg converted into the display unit (D25), so the
    /// value on the axis is a DERIVED number. The as-entered figure — the one
    /// the user actually typed — only exists here. Ticket 01 asked for
    /// as-entered tooltips; the single-session state had them and a drawn
    /// series did not.
    /// Offered only when this exercise has history under more than one
    /// variation. D36 forbids pooling them, so the alternative to a picker is
    /// history the user simply cannot reach.
    private var variationPicker: some View {
        let labels = variationLabels
        return Picker("Variation", selection: variationBinding) {
            ForEach(availableVariations, id: \.key) { item in
                Text(item.days == 0
                    ? "\(labels[item.key] ?? "") · nothing eligible"
                    : "\(labels[item.key] ?? "") · \(item.days) day\(item.days == 1 ? "" : "s")")
                    .tag(item.key)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("chartVariationPicker")
    }

    /// Distinct labels for every listed variation — the Domain owns the rule
    /// (`ProgressSeriesMath.labels`); this only supplies the snapshot words.
    private var variationLabels: [ProgressVariationKey: String] {
        ProgressSeriesMath.labels(for: availableVariations.map { (key: $0.key, words: words(for: $0.key)) })
    }

    /// Names the variation that is empty when others are not, so the state
    /// reads as "nothing HERE" rather than "nothing at all".
    private var emptyDescription: String {
        availableVariations.count > 1
            ? "No eligible sets under \(variationName(resolvedVariation)). Warmups do not count. Pick another variation above."
            : "Log \(exerciseName) in a workout and its progress appears here."
    }

    private var variationBinding: Binding<ProgressVariationKey> {
        Binding(
            get: { resolvedVariation },
            set: { variation = $0 })
    }

    @ViewBuilder
    private var selectionRow: some View {
        // Falls back to the LAST session when nothing is selected, so the row
        // is never an empty gap and the most recent numbers are always one
        // glance away.
        if let point = selected ?? series.points.last {
            LabeledContent(point.date.formatted(date: .abbreviated, time: .omitted)) {
                Text(calloutValue(point))
                    .monospacedDigit()
            }
            .accessibilityIdentifier("chartSelection")
            .accessibilityLabel(
                "\(point.date.formatted(date: .abbreviated, time: .omitted)), \(calloutValue(point))")
        }
    }

    /// The metric being viewed. Best set is the number the user typed;
    /// volume and 1RM are in the display unit, plain (D52 — the point still
    /// records which units its contributors were entered in).
    private func calloutValue(_ point: ProgressPoint) -> String {
        switch metric {
        case .bestSet:
            return asEntered(point)
        case .volume:
            return "\(WeightMath.displayNumber(inDisplayUnit(point.volumeKg))) \(displayUnit.rawValue)"
        case .e1rm:
            guard let kg = point.e1rmKg else { return "—" }
            return "\(WeightMath.displayNumber(inDisplayUnit(kg))) \(displayUnit.rawValue)"
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

    /// The axis unit, plain. It used to carry ≈ when any contributor to the
    /// metric was entered in the other unit (codex-review 06b); D52 dropped
    /// the mark, and `ProgressPoint` keeps the per-contributor units so it
    /// could come back without guessing.
    private var unitSuffix: String {
        " (\(displayUnit.rawValue))"
    }

    private var yLabel: String {
        switch metric {
        case .bestSet:
            resolvedVariation.loadType == .bodyweight ? "Reps" : series.loadAxisLabel + unitSuffix
        case .volume: "Volume" + unitSuffix
        case .e1rm: "1RM" + unitSuffix
        }
    }

    /// Converts a canonical-kg value into the display unit. Reps are not a
    /// weight and are never converted.
    private func inDisplayUnit(_ kg: Double) -> Double {
        WeightMath.convert(kg, from: .kg, to: displayUnit)
    }

    private func plotted(_ point: ProgressPoint) -> Double? {
        switch metric {
        case .bestSet:
            // Bodyweight plots REPS, which have no unit to convert.
            resolvedVariation.loadType == .bodyweight ? point.bestKg : point.bestKg.map(inDisplayUnit)
        case .volume: inDisplayUnit(point.volumeKg)
        case .e1rm: point.e1rmKg.map(inDisplayUnit)
        }
    }

    /// Volume and e1RM are weighted-only concepts (D20, `RecordsMath`). Offering
    /// them for an assisted movement would draw a flat zero line and invite the
    /// user to read meaning into it.
    private var availableMetrics: [Metric] {
        resolvedVariation.loadType == .weighted ? Metric.allCases : [.bestSet]
    }

    @ViewBuilder
    private var singlePoint: some View {
        if let point = series.points.first {
            LabeledContent(point.date.formatted(date: .abbreviated, time: .omitted)) {
                Text(asEntered(point))
                    .monospacedDigit()
            }
            .accessibilityIdentifier("progressSinglePoint")
        }
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

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    // MARK: Data

    /// Built from frozen snapshots (D23), never the live exercise row, so the
    /// chart shows what was actually logged.
    private var series: ProgressSeries {
        ProgressSeriesMath.series(for: history, variation: resolvedVariation)
    }

    /// Every finished set logged against this exercise, in SNAPSHOT terms
    /// (D23), across all variations. Scoping happens in `series`.
    private var history: [RecordSetInput] {
        let sets = (try? modelContext.fetch(FetchDescriptor<SetRecord>())) ?? []
        return sets.compactMap { set -> RecordSetInput? in
            // Snapshot values only, and finished workouts only — an
            // in-progress session is not history yet.
            guard !set.isDeleted, let entry = set.entry, !entry.isDeleted,
                  entry.snapshotExerciseID == exerciseID,
                  let workout = entry.workout, !workout.isDeleted,
                  workout.finishedAt != nil
            else { return nil }
            return RecordSetInput(
                loadType: entry.snapshotLoadType,
                exerciseID: entry.snapshotExerciseID,
                gymID: entry.snapshotGymID,
                machineID: entry.snapshotMachineID,
                modelID: entry.snapshotModelID,
                freeWeightTag: entry.snapshotFreeWeightTag,
                presetID: entry.snapshotPresetID,
                setType: set.type, reps: set.reps,
                weightValue: set.weightValue, weightUnit: set.weightUnit,
                normalizedKg: set.normalizedKg, completedAt: set.completedAt)
        }
    }

    /// The variation on screen, defaulting to the one with the most history.
    private var resolvedVariation: ProgressVariationKey {
        variation
            ?? ProgressSeriesMath.defaultVariation(in: history)
            ?? ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil)
    }

    /// The variations this exercise actually has history for, in the Domain's
    /// order — the picker lists what the user has trained, not every preset
    /// that happens to exist.
    private var availableVariations: [(key: ProgressVariationKey, days: Int)] {
        let ranked = ProgressSeriesMath.rankedVariations(in: history)
        // The variation on screen must be IN the list even when it has nothing
        // eligible to chart (a warmup-only session opened from History): a
        // Picker whose selection matches no row shows its title instead, and
        // the user cannot see what they are looking at, let alone leave it.
        let current = resolvedVariation
        guard !ranked.contains(where: { $0.key == current }) else { return ranked }
        return ranked + [(key: current, days: 0)]
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

    /// The label the empty state uses for the variation on screen.
    private func variationName(_ key: ProgressVariationKey) -> String {
        variationLabels[key] ?? exerciseName
    }
}
