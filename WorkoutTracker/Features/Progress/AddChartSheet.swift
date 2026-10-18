import SwiftData
import SwiftUI

// Public beta ticket 16 (D63): Add Chart — Lifting or Cardio, then one of the exercises or activities the user has
// actually logged, then (lifting) the machine or weight kind or "Most used", and what to show. Staged: Cancel or Add.

struct AddChartSheet: View {
    let onAdd: (ProgressPin) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Query private var exercises: [Exercise]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var workouts: [Workout]
    @State private var kind = 0
    @State private var search = ""
    @State private var history: [UUID: [ExerciseHistory.Item]] = [:]
    /// Read once when the sheet opens: rows and the variation page never fetch while typing (codex-review-16 #2).
    @State private var entries: [ExerciseEntry] = []
    @State private var summaries: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    SegmentedPills(["Lifting", "Cardio"], selection: $kind)
                        .accessibilityIdentifier("addChartKind")
                    if kind == 0 { liftingList } else { cardioList }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 12)
            }
            .searchable(text: $search, prompt: kind == 0 ? "Exercises" : "Activities")
            .lookSheetGround()
            .navigationTitle("Add Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("addChartCancel")
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        history = ExerciseHistory.all(in: modelContext)
        entries = (try? modelContext.fetch(FetchDescriptor<ExerciseEntry>())) ?? []
        var out: [UUID: String] = [:]
        for exercise in exercises {
            if let items = history[exercise.id], let line = summary(items, name: exercise.name) { out[exercise.id] = line }
        }
        summaries = out
    }

    private func matches(_ name: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty || name.localizedCaseInsensitiveContains(query)
    }

    // MARK: Lifting

    /// Exercises with eligible history, most recently trained first.
    private var logged: [(exercise: Exercise, items: [ExerciseHistory.Item], last: Date)] {
        exercises.compactMap { exercise in
            guard let items = history[exercise.id],
                  let last = items.filter({ RecordsMath.isEligible($0.input) }).compactMap(\.input.completedAt).max()
            else { return nil }
            return (exercise, items, last)
        }
        .filter { matches($0.exercise.name) }
        .sorted { ($0.last, $1.exercise.name) > ($1.last, $0.exercise.name) }
    }

    @ViewBuilder private var liftingList: some View {
        let rows = logged
        if rows.isEmpty {
            EmptyStateView(symbol: "chart.xyaxis.line", title: search.isEmpty ? "No sets logged yet" : "No matches")
        } else {
            LookList(header: "Exercises you've logged") {
                ForEach(rows, id: \.exercise.id) { row in
                    NavigationLink {
                        ChooseLiftChart(exercise: row.exercise, items: row.items, entries: entries) { pin in onAdd(pin); dismiss() }
                    } label: {
                        LookRow(row.exercise.name, subtitle: summaries[row.exercise.id],
                                symbol: glyph(row.items)) { EmptyView() }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addChartExercise")
                }
            }
        }
    }

    /// "Barbell", "Barbell · Chest Press 2", or "Barbell + 2 more": the variations the exercise was logged under; nil
    /// when the only one is a machine labelled with the exercise's own name.
    private func summary(_ items: [ExerciseHistory.Item], name: String) -> String? {
        let ranked = ProgressSeriesMath.rankedVariations(in: items.map(\.input))
        let labels = ProgressSeriesMath.labels(for: ranked.map {
            (key: $0.key, words: ExerciseOverview.variationWords(for: $0.key, entries: entries))
        })
        let names = ranked.compactMap { labels[$0.key] }
        if names == [name] { return nil }
        return names.count <= 2 ? names.joined(separator: " · ") : "\(names[0]) + \(names.count - 1) more"
    }

    private func glyph(_ items: [ExerciseHistory.Item]) -> String {
        switch ProgressSeriesMath.defaultVariation(in: items.map(\.input))?.equipment {
        case .machine: LookIcon.machine
        case .freeWeight(let tag): tag.historySymbol
        default: "circle.dashed"
        }
    }

    // MARK: Cardio

    @ViewBuilder private var cardioList: some View {
        let rows = CardioProgressMath.activities(in: workouts).filter { matches($0.activity.name) }
        if rows.isEmpty {
            EmptyStateView(symbol: "chart.xyaxis.line", title: search.isEmpty ? "No cardio recorded yet" : "No matches")
        } else {
            LookList(header: "Activities you've recorded") {
                ForEach(rows, id: \.activity) { row in
                    NavigationLink {
                        ChooseCardioChart(activity: row.activity) { pin in onAdd(pin); dismiss() }
                    } label: {
                        LookRow(row.activity.name, subtitle: HistoryRendering.pluralized(row.sessions, "session", "sessions"),
                                symbol: row.activity.symbol) { EmptyView() }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addChartActivity")
                }
            }
        }
    }
}

// MARK: - Step 2: lifting

private struct ChooseLiftChart: View {
    let exercise: Exercise
    let items: [ExerciseHistory.Item]
    let entries: [ExerciseEntry]
    let add: (ProgressPin) -> Void
    @Environment(\.look) private var look
    /// nil = Most used.
    @State private var choice: ProgressVariationKey?
    @State private var metric = 0

    /// Worked out once when the page opens, from the entries the sheet read.
    @State private var ranked: [(key: ProgressVariationKey, days: Int)] = []
    @State private var labels: [ProgressVariationKey: String] = [:]

    private var resolved: ProgressVariationKey? { choice ?? ranked.first?.key }
    private var metrics: [ProgressPinMetric] { ProgressPinMetric.lifting(for: resolved?.loadType ?? .weighted) }

    var body: some View {
        let options = ranked
        let names = labels
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                Text(exercise.name).font(look.font.title).foregroundStyle(look.textPrimary)
                if options.count > 1 {
                    let allMachines = options.allSatisfy { if case .machine = $0.key.equipment { true } else { false } }
                    LookList(header: allMachines ? "Machine" : "Equipment") {
                        LookRow("Most used", subtitle: options.first.flatMap { names[$0.key] }.map { "Now \($0)" },
                                symbol: "sparkles", showsChevron: false, action: { select(nil) }) {
                            check(choice == nil)
                        }
                        .accessibilityIdentifier("addChartMostUsed")
                        ForEach(options, id: \.key) { option in
                            LookRow(names[option.key] ?? exercise.name,
                                    subtitle: HistoryRendering.pluralized(option.days, "day", "days"),
                                    symbol: glyph(option.key.equipment), showsChevron: false,
                                    action: { select(option.key) }) {
                                check(choice == option.key)
                            }
                            .accessibilityIdentifier("addChartVariation")
                        }
                    }
                }
                if metrics.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Show").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                            .padding(.leading, 4)
                            .accessibilityAddTraits(.isHeader)
                        SegmentedPills(metrics.map { $0.title() }, selection: $metric)
                            .accessibilityIdentifier("addChartMetric")
                    }
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 12)
        }
        .lookSheetGround()
        .navigationTitle("Add Chart")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard ranked.isEmpty else { return }
            ranked = ProgressSeriesMath.rankedVariations(in: items.map(\.input))
            labels = ProgressSeriesMath.labels(for: ranked.map {
                (key: $0.key, words: ExerciseOverview.variationWords(for: $0.key, entries: entries))
            })
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let shown = metrics.indices.contains(metric) ? metrics[metric] : .bestSet
                    add(ProgressPin(subject: .lift(exerciseID: exercise.id, variation: choice.map(PinnedLiftVariation.init) ?? .mostUsed),
                                    metric: shown))
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("addChartAdd")
            }
        }
    }

    private func select(_ key: ProgressVariationKey?) {
        choice = key
        // A non-weighted variation has only Best set (D20).
        if !metrics.indices.contains(metric) { metric = 0 }
    }

    @ViewBuilder private func check(_ on: Bool) -> some View {
        if on {
            Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(look.action)
                .accessibilityLabel("Selected")
        }
    }

    private func glyph(_ equipment: ProgressEquipment) -> String {
        switch equipment {
        case .machine: LookIcon.machine
        case .freeWeight(let tag): tag.historySymbol
        case .unrecorded: "circle.dashed"
        }
    }
}

// MARK: - Step 2: cardio

private struct ChooseCardioChart: View {
    let activity: CardioActivity
    let add: (ProgressPin) -> Void
    @Environment(\.look) private var look
    @State private var metric = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                Text(activity.name).font(look.font.title).foregroundStyle(look.textPrimary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Show").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                        .padding(.leading, 4)
                        .accessibilityAddTraits(.isHeader)
                    SegmentedPills(ProgressPinMetric.cardio.map { $0.title(for: activity) }, selection: $metric)
                        .accessibilityIdentifier("addChartMetric")
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 12)
        }
        .lookSheetGround()
        .navigationTitle("Add Chart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    add(ProgressPin(subject: .cardio(activity: activity.rawValue), metric: ProgressPinMetric.cardio[metric]))
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("addChartAdd")
            }
        }
    }
}
