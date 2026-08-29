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
    /// The SNAPSHOT load type being charted, not the exercise's current one:
    /// history keeps what it was logged under (D23/D47).
    let loadType: LoadType
    /// D36: records are per-preset, so a chart must be too. Pooling narrow- and
    /// wide-grip bests would let one variation set a record the other can never
    /// beat. nil charts only sets logged with no preset.
    var presetID: UUID?

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
            switch series.confidence {
            case .empty:
                ContentUnavailableView(
                    "No sets logged yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Log \(exerciseName) in a workout and its progress appears here."))
                    .accessibilityIdentifier("progressEmpty")
            case .single:
                Section {
                    singlePoint
                } header: {
                    Text("One session")
                } footer: {
                    // Refusing to draw a line is the honest render.
                    Text("One session is a point, not a trend. Log this exercise again and a chart appears.")
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
                    Text(footer(days: days))
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

    /// The metric being viewed, in the honest form for it.
    private func calloutValue(_ point: ProgressPoint) -> String {
        switch metric {
        case .bestSet:
            // As entered, with no ≈: this is the number the user typed.
            return asEntered(point)
        case .volume:
            let value = inDisplayUnit(point.volumeKg)
            // Volume IS derived — a sum, then converted — so it keeps its ≈.
            return displayUnit == .kg
                ? "\(WeightMath.displayNumber(value)) kg"
                : "≈\(WeightMath.displayNumber(value)) \(displayUnit.rawValue)"
        case .e1rm:
            guard let kg = point.e1rmKg else { return "—" }
            let value = inDisplayUnit(kg)
            // An estimate of a conversion. Never presented as measured.
            return "≈\(WeightMath.displayNumber(value)) \(displayUnit.rawValue == "kg" ? "kg" : displayUnit.rawValue)"
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

    private var unitSuffix: String {
        // `≈` when converted, per D9/D25: every plotted point is then a derived
        // number rather than one the user typed.
        displayUnit == .kg ? " (kg)" : " (≈\(displayUnit.rawValue))"
    }

    private var yLabel: String {
        switch metric {
        case .bestSet:
            loadType == .bodyweight ? "Reps" : series.loadAxisLabel + unitSuffix
        case .volume: "Volume" + unitSuffix
        case .e1rm: "Estimated 1RM" + unitSuffix
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
            loadType == .bodyweight ? point.bestKg : point.bestKg.map(inDisplayUnit)
        case .volume: inDisplayUnit(point.volumeKg)
        case .e1rm: point.e1rmKg.map(inDisplayUnit)
        }
    }

    /// Volume and e1RM are weighted-only concepts (D20, `RecordsMath`). Offering
    /// them for an assisted movement would draw a flat zero line and invite the
    /// user to read meaning into it.
    private var availableMetrics: [Metric] {
        loadType == .weighted ? Metric.allCases : [.bestSet]
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
        if loadType == .bodyweight {
            return point.bestReps.map { "\($0) reps" } ?? "—"
        }
        guard let value = point.bestValue, let unit = point.bestUnit else { return "—" }
        let reps = point.bestReps.map { " × \($0)" } ?? ""
        return "\(Format.weight(value)) \(unit.rawValue)\(reps)"
    }

    private func footer(days: Int) -> String {
        // Says the unit it is ACTUALLY plotted in. This read "Plotted in kg"
        // even after the axis started converting (2026-08-26), which is
        // precisely the kind of stale caption D9/D25 exist to prevent —
        // spotted in the first screenshot of a real series.
        let base = displayUnit == .kg
            ? "Plotted in kg. Sessions logged in other units are converted so they share one axis; the values you entered are unchanged."
            : "Converted to \(displayUnit.rawValue) (≈) so sessions logged in different units share one axis. Tap the chart to see what you actually entered."
        // A short series is still a short series. Say so rather than letting
        // three points imply a trajectory.
        return days < 4
            ? base + " Only \(days) days logged so far — read the shape with caution."
            : base
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    // MARK: Data

    /// Built from frozen snapshots (D23), never the live exercise row, so the
    /// chart shows what was actually logged.
    private var series: ProgressSeries {
        let descriptor = FetchDescriptor<SetRecord>()
        let sets = (try? modelContext.fetch(descriptor)) ?? []
        let inputs = sets.compactMap { set -> RecordSetInput? in
            // Snapshot load type, and only entries matching the type being
            // charted. codex-review 2 (critical): the view passed the LIVE
            // exercise's load type while the sets carried their frozen ones, so
            // a correction relabelled old history. Also excludes sets in a
            // workout that has not finished — an in-progress session is not
            // history yet.
            guard !set.isDeleted, let entry = set.entry, !entry.isDeleted,
                  entry.snapshotExerciseID == exerciseID,
                  entry.snapshotLoadType == loadType,
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
        return ProgressSeriesMath.series(for: inputs, loadType: loadType, presetID: presetID)
    }
}
