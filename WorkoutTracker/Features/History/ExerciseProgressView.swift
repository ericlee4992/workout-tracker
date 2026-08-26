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
        }
        .chartYAxisLabel(yLabel)
        // Assisted improves DOWNWARD. Inverting the axis would hide that; the
        // label says it instead, so the shape of the line stays honest.
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
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
        let base = "Plotted in kg so sessions logged in different units share one axis; the values you entered are unchanged."
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
