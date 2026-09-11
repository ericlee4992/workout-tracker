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
                // D54: the receipt opens on a status ring — full and amber for
                // a saved workout, empty and quiet for a discarded one — beside
                // the same two lines it always said.
                Section {
                    HStack(spacing: Theme.Space.inset) {
                        ZStack {
                            ProgressRing(progress: savedWorkout == nil ? 0 : 1,
                                         tint: savedWorkout == nil ? Theme.tertiary : Theme.accent,
                                         lineWidth: 7)
                            Image(systemName: savedWorkout == nil ? "tray" : "checkmark")
                                .font(.title.weight(.bold))
                                .foregroundStyle(savedWorkout == nil ? Theme.tertiary : Theme.accent)
                        }
                        .frame(width: 84, height: 84)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(savedWorkout == nil ? "Nothing to save" : "Workout saved")
                                .font(Theme.stat)
                                .foregroundStyle(savedWorkout == nil ? Theme.secondary : Theme.text)
                            Text(summaryLine)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                                .accessibilityIdentifier("finishedSummary")
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Space.inset)
                    .card()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                if savedWorkout != nil {
                    Section {
                        VStack(spacing: Theme.Space.small) {
                            Button {
                                viewInHistory()
                            } label: {
                                Label("View in History", systemImage: "clock.arrow.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.primary)
                            .accessibilityIdentifier("viewFinishedWorkout")

                            if let savedTemplateName {
                                Label("Saved as template “\(savedTemplateName)”", systemImage: "checkmark")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            } else if canSaveAsTemplate {
                                Button {
                                    templateName = defaultTemplateName
                                    namingTemplate = true
                                } label: {
                                    Label("Save as Template", systemImage: "square.on.square")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.secondary)
                                .accessibilityIdentifier("saveAsTemplate")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }

                if let summary {
                    statsSection(summary)
                    // Milestone 9, ticket 05: the graph, when a series exists.
                    if summary.hasHeartRateSeries, let interval = summary.heartRateSeriesIntervalSeconds {
                        HeartRateSummarySection(
                            series: summary.heartRateSeries,
                            low: summary.heartRateSeriesLow,
                            high: summary.heartRateSeriesHigh,
                            intervalSeconds: interval,
                            durationSeconds: Int(summary.duration.rounded(.up)),
                            startedAt: summary.date,
                            averageBpm: summary.averageHeartRate,
                            maxBpm: summary.maxHeartRate)
                    }
                    exercisesSection(summary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
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
                Text("Saves exercises, sets and target reps — not weights or rest times.")
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
        WeightMath.displayLabel(kilograms: kg, in: displayUnit)
    }

    @ViewBuilder
    private func statsSection(_ summary: WorkoutSummary) -> some View {
        Section("Workout details") {
            // Milestone 9, ticket 05: the headline figures as a block of
            // tiles, the way the user's reference (Apple Fitness) lays them
            // out — now every figure is a tile (D54). Every tile is still
            // OMITTED, not zeroed, when its fact is missing (D44) — a block
            // with a hole is honest; a block with a 0 is not.
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Space.small) {
                tile("Workout time", Format.duration(seconds: Int(summary.duration)), symbol: "timer",
                     tint: Theme.accent, id: "summaryTime")
                if let calories = summary.activeEnergyKilocalories {
                    tile("Active calories", "\(Int(calories.rounded()))", unit: "CAL", symbol: "flame.fill",
                         tint: Self.calorieTint, id: "summaryCalories")
                }
                // Total = active + basal, only when the system gave both (D9/D25).
                if let total = summary.totalEnergyKilocalories {
                    tile("Total calories", "\(Int(total.rounded()))", unit: "CAL", symbol: "flame",
                         tint: Self.calorieTint, id: "summaryTotalCalories")
                }
                if let average = summary.averageHeartRate {
                    tile("Avg. heart rate", "\(average)", unit: "BPM", symbol: "heart.fill",
                         tint: Theme.danger, id: "summaryAvgHR")
                }
                if let maximum = summary.maxHeartRate {
                    tile("Max heart rate", "\(maximum)", unit: "BPM", symbol: "arrow.up.heart.fill",
                         tint: Theme.danger, id: "summaryMaxHR")
                }
                if summary.totalVolumeKg > 0 {
                    // Shown in the app's own unit, not always kg. Reported
                    // 2026-08-26: a user logging in lb saw their volume in kg,
                    // which is a number they cannot sanity-check against
                    // anything they typed. Plain, no ≈ (D52).
                    tile("Total volume", volumeLabel(summary.totalVolumeKg), symbol: "scalemass.fill",
                         tint: Theme.text, id: "summaryVolume")
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)

            if summary.zoneSeconds.contains(where: { $0 > 0 }) {
                zoneCard(summary.zoneSeconds)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
            }
        }
    }

    private static let calorieTint = Color(rgb: 0xF4939C)

    /// A stat tile whose unit rides in the value ("7 CAL") and whose
    /// accessibility label keeps the shape the tests and VoiceOver knew:
    /// "title, value unit".
    private func tile(_ title: String, _ value: String, unit: String? = nil, symbol: String, tint: Color, id: String) -> some View {
        StatTile(
            value: unit.map { "\(value) \($0)" } ?? value,
            label: title,
            symbol: symbol,
            tint: tint,
            identifier: id,
            accessibilityText: "\(title), \(value) \(unit ?? "")")
    }

    /// Time in zones as one stacked bar — each zone's share of the workout in
    /// its colour — with the durations beneath. The record still knows whether
    /// these came from 220−age (`zonesFromEstimatedMax`); the screen no longer
    /// says so (D52).
    private func zoneCard(_ seconds: [Int]) -> some View {
        let present = HeartRateZone.allCases.filter { zone in
            zone.rawValue < seconds.count && seconds[zone.rawValue] > 0
        }
        return VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text("Time in zones")
                .font(Theme.cardTitle)
            GeometryReader { geometry in
                let widths = ZoneBarLayout.widths(
                    values: present.map { seconds[$0.rawValue] }, width: geometry.size.width, gap: 2)
                HStack(spacing: 2) {
                    ForEach(Array(present.enumerated()), id: \.element) { index, zone in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zone.color)
                            .frame(width: widths[index])
                    }
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)
            VStack(spacing: 6) {
                ForEach(present, id: \.self) { zone in
                    HStack(spacing: 8) {
                        Circle().fill(zone.color).frame(width: 8, height: 8)
                        Text(zone.label).font(.caption)
                        Spacer()
                        Text(Format.duration(seconds: seconds[zone.rawValue]))
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    }
                }
            }
        }
        .padding(Theme.Space.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// The half Apple's summary cannot show: what was actually lifted.
    @ViewBuilder
    private func exercisesSection(_ summary: WorkoutSummary) -> some View {
        if !summary.exercises.isEmpty {
            Section("Exercises") {
                ForEach(summary.exercises) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.name)
                            .font(Theme.cardTitle)
                        HStack(spacing: 6) {
                            if let equipment = line.equipment {
                                Text(equipment)
                            }
                            if let preset = line.preset {
                                Text("· \(preset)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                        HStack(spacing: 6) {
                            Text(HistoryRendering.pluralized(line.setCount, "set", "sets"))
                            if let best = line.bestSet {
                                Text("· best \(best)")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(Theme.Space.inset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                    // Combined for the same reason the heart-rate bar's rows
                    // are: an identifier on a multi-Text container is not
                    // queryable, and propagates over its children's.
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("summaryExercise")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
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
