import SwiftData
import SwiftUI

/// C2 (ticket 17) — the receipt for a finished workout. Finishing used to
/// drop you on the Workout tab with no confirmation and no way back to what
/// you just logged. This says what was saved, offers the workout itself, and
/// carries the save-as-template option that used to block Finish (B2).
///
/// A2: `workout` is nil when the workout was empty and got discarded instead
/// of finished. The same receipt then says *that* — silently vanishing and
/// confirming a save are both lies about what happened.
///
/// Light and skippable: Done is always one tap away.
struct WorkoutFinishedSheet: View {
    @Environment(\.modelContext) private var modelContext
    /// The saved workout, or nil when nothing was logged (A2).
    var workout: Workout?
    /// Dismisses the sheet and shows the workout in History.
    var viewInHistory: () -> Void
    var done: () -> Void

    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var templateFailure: String?
    @State private var savedTemplateName: String?

    /// The workout only when it really reached history — a deleted or
    /// missing one is the discarded case, whatever the caller passed.
    private var savedWorkout: Workout? {
        guard let workout, !workout.isDeleted, workout.finishedAt != nil else {
            return nil
        }
        return workout
    }

    private var entryCount: Int {
        savedWorkout.map { WorkoutSession.orderedEntries(of: $0).count } ?? 0
    }

    private var setCount: Int {
        savedWorkout?.completedSets.count ?? 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            savedWorkout == nil ? "Nothing to save" : "Workout saved",
                            systemImage: savedWorkout == nil
                                ? "tray" : "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(savedWorkout == nil ? Color.secondary : Color.green)
                        Text(summaryLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("finishedSummary")
                    }
                    .padding(.vertical, 4)
                }

                if savedWorkout != nil {
                    Section {
                        Button("View in History", systemImage: "clock.arrow.circlepath") {
                            viewInHistory()
                        }
                        .accessibilityIdentifier("viewFinishedWorkout")

                        if let savedTemplateName {
                            Label("Saved as template “\(savedTemplateName)”", systemImage: "checkmark")
                                .foregroundStyle(.secondary)
                        } else if canSaveAsTemplate {
                            Button("Save as Template", systemImage: "square.on.square") {
                                templateName = defaultTemplateName
                                namingTemplate = true
                            }
                            .accessibilityIdentifier("saveAsTemplate")
                        }
                    } footer: {
                        if savedTemplateName == nil, canSaveAsTemplate {
                            Text("Completed sets become target set and rep slots. Weights and rest times are not saved.")
                        }
                    }
                }

                if let summary {
                    statsSection(summary)
                    exercisesSection(summary)
                }
            }
            // The summary made this sheet tall; a medium detent hid the
            // actions and the exercises below the fold.
            .presentationDetents([.large])
            .navigationTitle(savedWorkout == nil ? "Nothing logged" : "Nice work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { done() }
                        .font(.headline)
                        .accessibilityIdentifier("finishedDone")
                }
            }
            .alert("Save as Template", isPresented: $namingTemplate) {
                TextField("Template name", text: $templateName)
                Button("Save") { saveTemplate() }
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Completed sets become target set and rep slots. Weights and rest times are not saved.")
            }
            .alert(
                "Couldn't Save Template",
                isPresented: Binding(
                    get: { templateFailure != nil },
                    set: { if !$0 { templateFailure = nil } })
            ) {
                Button("OK", role: .cancel) { templateFailure = nil }
            } message: {
                Text(templateFailure ?? "")
            }
        }
    }

    private var summaryLine: String {
        guard let saved = savedWorkout else {
            return "No sets were completed, so this workout wasn't saved."
        }
        var parts = [
            HistoryRendering.pluralized(entryCount, "exercise", "exercises"),
            HistoryRendering.pluralized(setCount, "set", "sets"),
        ]
        // The snapshot name (D23), like the rest of history — the receipt
        // describes what was logged, not what the gym is called now.
        if let gymName = saved.historyGymName {
            parts.append(gymName)
        }
        return parts.joined(separator: " · ")
    }

    /// A workout can only become a template once something has been
    /// completed — `saveAsTemplate` captures completed sets only and throws
    /// `noExercises` otherwise.
    private var canSaveAsTemplate: Bool {
        savedWorkout.map(WorkoutTemplateService.canSaveAsTemplate) ?? false
    }

    private var defaultTemplateName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = savedWorkout?.startedAt ?? .now
        return "Workout \(formatter.string(from: date))"
    }

    /// D44: the numbers for the workout just finished. Built from the
    /// workout's own persisted fields, so this screen and History can never
    /// disagree.
    private var summary: WorkoutSummary? {
        savedWorkout.map { WorkoutSummaryBuilder.summary(for: $0) }
    }

    /// The app's default weight unit (D2/T7 precedence, app level).
    private var displayUnit: WeightUnit {
        let rows = (try? modelContext.fetch(FetchDescriptor<AppPreferences>())) ?? []
        return UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil,
            appPreference: AppPreferences.canonical(of: rows)?.unitPreference)
    }

    private func volumeLabel(_ kg: Double) -> String {
        let unit = displayUnit
        guard unit != .kg else { return "\(WeightMath.displayNumber(kg)) kg" }
        let converted = WeightMath.convert(kg, from: .kg, to: unit)
        return "≈\(WeightMath.displayNumber(converted)) \(unit.rawValue)"
    }

    @ViewBuilder
    private func statsSection(_ summary: WorkoutSummary) -> some View {
        Section("Workout details") {
            statRow("Workout time", Format.duration(seconds: Int(summary.duration)))
            if summary.totalVolumeKg > 0 {
                // Shown in the app's own unit, not always kg. Reported
                // 2026-08-26: a user logging in lb saw their volume in kg,
                // which is a number they cannot sanity-check against anything
                // they typed.
                //
                // Marked `≈` when converted, per D9/D25 — volume is a derived
                // number and, unlike a single set, the conversion is applied to
                // a sum, so it is approximate twice over.
                statRow("Total volume", volumeLabel(summary.totalVolumeKg))
            }
            // Every heart-rate row is OMITTED, not zeroed, when no sensor ran
            // (D44). A workout logged without one says nothing about the heart
            // rather than claiming 0 BPM.
            if let calories = summary.activeEnergyKilocalories {
                statRow("Active calories", "\(Int(calories.rounded())) CAL")
                    .accessibilityIdentifier("summaryCalories")
            }
            if let average = summary.averageHeartRate {
                statRow("Avg. heart rate", "\(average) BPM")
                    .accessibilityIdentifier("summaryAvgHR")
            }
            if let maximum = summary.maxHeartRate {
                statRow("Max heart rate", "\(maximum) BPM")
            }
            if summary.zoneSeconds.contains(where: { $0 > 0 }) {
                zoneRow(summary.zoneSeconds)
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private var summaryZonesEstimated: Bool {
        summary?.zonesFromEstimatedMax == true
    }

    private func zoneRow(_ seconds: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Time in zones")
                    .font(.subheadline)
                if summaryZonesEstimated {
                    // D45, on the permanent record rather than only live.
                    Text("(estimated)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(HeartRateZone.allCases, id: \.self) { zone in
                let value = zone.rawValue < seconds.count ? seconds[zone.rawValue] : 0
                if value > 0 {
                    HStack {
                        Text(zone.label).font(.caption)
                        Spacer()
                        Text(Format.duration(seconds: value))
                            .font(.caption).monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// The half Apple's summary cannot show: what was actually lifted.
    @ViewBuilder
    private func exercisesSection(_ summary: WorkoutSummary) -> some View {
        if !summary.exercises.isEmpty {
            Section("Exercises") {
                ForEach(summary.exercises) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.name)
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 6) {
                            if let equipment = line.equipment {
                                Text(equipment)
                            }
                            if let preset = line.preset {
                                Text("· \(preset)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(HistoryRendering.pluralized(line.setCount, "set", "sets"))
                            if let best = line.bestSet {
                                Text("· best \(best)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    // Combined for the same reason the heart-rate bar's rows
                    // are: an identifier on a multi-Text container is not
                    // queryable, and propagates over its children's.
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("summaryExercise")
                }
            }
        }
    }

    private func saveTemplate() {
        guard let saved = savedWorkout else { return }
        do {
            let template = try WorkoutTemplateService(context: modelContext)
                .saveAsTemplate(saved, name: templateName)
            savedTemplateName = template.name
        } catch {
            templateFailure = Self.templateFailureMessage(error)
        }
    }

    private static func templateFailureMessage(_ error: Error) -> String {
        switch error as? WorkoutTemplateError {
        case .emptyName:
            return "Give the template a name and try again."
        case .noExercises:
            return "This workout has no completed sets, so there is nothing to save as a template."
        case nil:
            return "The template could not be saved: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let context = container.mainContext
    let gym = Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg)
    context.insert(gym)
    let workout = Workout(
        startedAt: .now.addingTimeInterval(-2_700), finishedAt: .now,
        snapshotGymName: gym.name, gym: gym)
    context.insert(workout)
    return WorkoutFinishedSheet(workout: workout, viewInHistory: {}, done: {})
        .modelContainer(container)
}
