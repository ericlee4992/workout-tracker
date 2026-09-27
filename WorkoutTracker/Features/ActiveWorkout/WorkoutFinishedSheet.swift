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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.look) private var look
    @State private var namingTemplate = false
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
        savedWorkout.map { WorkoutSession.orderedEntries(of: $0).filter { !($0.sets ?? []).filter { $0.completedAt != nil }.isEmpty }.count } ?? 0
    }

    private var setCount: Int {
        savedWorkout?.completedSets.count ?? 0
    }

    /// The families, new bests, exercise rows and template comparison (Floodlight redesign).
    /// Built once per saved workout, not per render: it reads each scope's whole history.
    @State private var receipt: FinishReceipt?

    private func buildReceipt() {
        receipt = savedWorkout.flatMap { try? FinishReceipt.build(for: $0, in: modelContext) }
    }

    var body: some View {
        let receipt = receipt
        NavigationStack {
            List {
                FinishHeader(
                    saved: savedWorkout != nil,
                    title: savedWorkout?.historyTitle,
                    gymName: savedWorkout?.historyGymName,
                    countLine: countLine,
                    summaryLine: summaryLine,
                    ringRuns: receipt?.ringRuns ?? [],
                    families: receipt?.familySets ?? [])
                    .finishRow(top: 8, bottom: 10)

                if savedWorkout != nil {
                    actions.finishRow(top: 10, bottom: 8)
                }

                if let summary {
                    statsSection(summary).finishRow(top: 18, bottom: 8)
                    if let receipt, !receipt.bests.isEmpty {
                        bestsSection(receipt.bests).finishRow(top: 18, bottom: 8)
                    }
                    if let comparison = receipt?.comparison {
                        comparisonSection(comparison).finishRow(top: 18, bottom: 8)
                    }
                    // Milestone 9, ticket 05: the graph, when a series exists, with time in zones
                    // under it in the same plate (ticket 05 of the redesign).
                    if summary.hasHeartRateSeries || summary.zoneSeconds.contains(where: { $0 > 0 }) {
                        HeartRateSummarySection(summary: summary)
                            .finishRow(top: 18, bottom: 8)
                    }
                    if let workout = savedWorkout, !workout.recordedCardio.isEmpty {
                        Section {
                            ForEach(workout.recordedCardio) { CardioSummaryCard(segment: $0) }
                                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        } header: {
                            SectionHeader("Cardio").textCase(nil)
                        }
                    }
                    if let receipt, !receipt.exercises.isEmpty {
                        exercisesSection(receipt.exercises).finishRow(top: 18, bottom: 24)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .background(look.groundSheet.ignoresSafeArea())
            .environment(\.lookOnSheet, true)
            // The summary made this sheet tall; a medium detent hid the
            // actions and the exercises below the fold.
            .presentationDetents([.large])
            .onAppear(perform: buildReceipt)
            .onChange(of: savedWorkout?.id) { _, _ in buildReceipt() }
            .navigationTitle(savedWorkout == nil ? "Nothing logged" : "Nice work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(savedWorkout == nil ? "Nothing logged" : "Nice work")
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { done() }
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .accessibilityIdentifier("finishedDone")
                }
            }
            // Ticket 13: the naming flow is `SaveAsTemplateFlow`, shared with
            // History's workout detail.
            .saveAsTemplateFlow(workout: savedWorkout, isPresented: $namingTemplate) {
                savedTemplateName = $0
            }
        }
    }

    // MARK: Actions

    /// View in History is the one filled command; Save as Template the quiet peer, replaced in
    /// place by the confirmation once saved (C2).
    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton("View in History", symbol: "clock.arrow.circlepath") { viewInHistory() }
                .accessibilityIdentifier("viewFinishedWorkout")
            if let savedTemplateName {
                FinishSavedTemplateLine(name: savedTemplateName)
            } else if canSaveAsTemplate {
                Button {
                    namingTemplate = true
                } label: {
                    Label("Save as Template", systemImage: "square.on.square")
                }
                .buttonStyle(.lookSecondary)
                .accessibilityIdentifier("saveAsTemplate")
            }
        }
    }

    /// "5 exercises · 22 sets" (the lifting counts), cardio named when there was some.
    private var countLine: String? {
        guard let saved = savedWorkout else { return nil }
        var parts: [String] = []
        if setCount > 0 {
            parts.append(HistoryRendering.pluralized(entryCount, "exercise", "exercises"))
            parts.append(HistoryRendering.pluralized(setCount, "set", "sets"))
        }
        if !saved.recordedCardio.isEmpty {
            parts.append(HistoryRendering.pluralized(saved.recordedCardio.count, "cardio activity", "cardio activities"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var summaryLine: String {
        guard let saved = savedWorkout else {
            return "No sets were completed, so this workout wasn't saved."
        }
        var parts = [
            HistoryRendering.pluralized(entryCount, "exercise", "exercises"),
            HistoryRendering.pluralized(setCount, "set", "sets"),
        ]
        if !saved.recordedCardio.isEmpty {
            if setCount == 0 { parts = [] }
            parts.append(HistoryRendering.pluralized(saved.recordedCardio.count, "cardio activity", "cardio activities"))
        }
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

    /// Workout details: the paired tiles in the user's order (ticket 17) — time / volume,
    /// active / total calories, average / max heart rate. Every tile is OMITTED, not zeroed,
    /// when its fact is missing (D44); one column at accessibility sizes.
    private func statsSection(_ summary: WorkoutSummary) -> some View {
        let tiles = FinishTile.summaryTiles(summary, unit: displayUnit) { kind in
            switch kind {
            case .workoutTime: "summaryTime"
            case .totalVolume: "summaryVolume"
            case .activeCalories: "summaryCalories"
            case .totalCalories: "summaryTotalCalories"
            case .averageHeartRate: "summaryAvgHR"
            case .maxHeartRate: "summaryMaxHR"
            }
        }
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Workout details")
            FinishTileGrid(tiles: tiles)
        }
    }

    // MARK: New bests

    private func bestsSection(_ bests: [FinishReceipt.Best]) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("New bests")
            VStack(spacing: 0) {
                ForEach(Array(bests.enumerated()), id: \.element.id) { index, best in
                    if index > 0 { LookDivider().padding(.leading, 16) }
                    FinishBestRow(best: best)
                }
            }
            .lookSurface(.panel)
        }
        .sensoryFeedback(.success, trigger: bests.count)
    }

    // MARK: Last run

    /// The template's last run beside this one: total volume, two bars and the change.
    private func comparisonSection(_ comparison: FinishReceipt.Comparison) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Last \(comparison.templateName)")
            ComparisonBars(
                lastLabel: LookFormat.shortDate(comparison.lastDate),
                last: WeightMath.convert(comparison.lastVolumeKg, from: .kg, to: displayUnit),
                today: WeightMath.convert(comparison.volumeKg, from: .kg, to: displayUnit),
                unit: displayUnit.label)
        }
    }

    /// The half Apple's summary cannot show: what was actually lifted.
    private func exercisesSection(_ rows: [FinishReceipt.ExerciseRow]) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(savedWorkout?.recordedCardio.isEmpty == false ? "Lifting" : "Exercises")
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { LookDivider().padding(.leading, 16) }
                    FinishExerciseRow(row: row)
                        // Combined: an identifier on a multi-Text container is not queryable,
                        // and propagates over its children's.
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("summaryExercise")
                }
            }
            .lookSurface(.panel)
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
