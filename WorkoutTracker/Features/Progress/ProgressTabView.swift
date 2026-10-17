import SwiftData
import SwiftUI

// Public beta ticket 16 (D63): the Progress tab — every pinned chart, one panel under another, lifting and cardio in
// the user's own order. Long-press a panel to change what it shows, move it or remove it; + and "Add Chart" append. A
// lifting panel opens `ExerciseProgressView` on its variation; a cardio panel opens `CardioProgressView`.

struct ProgressTabView: View {
    /// The pins, as `ProgressPinStore` saves them (an app setting, not workout data — D63).
    @AppStorage(ProgressPinStore.key) private var pinsData = Data()
    @State private var history: [UUID: [ExerciseHistory.Item]] = [:]
    @State private var adding = false
    @State private var opened: ProgressPin?
    @State private var titleInBar = false
    @Query private var exercises: [Exercise]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt)
    private var workouts: [Workout]
    @Query private var preferences: [AppPreferences]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private var pins: [ProgressPin] { ProgressPinStore.decode(pinsData) }

    private func save(_ pins: [ProgressPin]) {
        withAnimation(.snappy(duration: 0.3)) { pinsData = ProgressPinStore.encode(pins) }
    }

    /// A pin whose exercise no longer exists, or whose activity this build does not know, disappears quietly (D63).
    private var shown: [ProgressPin] {
        let ids = Set(exercises.map(\.id))
        return pins.filter { pin in
            switch pin.subject {
            case .lift(let id, _): ids.contains(id)
            case .cardio: pin.activity != nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.group) {
                    LookNavTitle("Progress")
                        .padding(.bottom, look.space.section - look.space.group)
                    let visible = shown
                    if visible.isEmpty {
                        EmptyStateView(symbol: "chart.xyaxis.line", title: "No charts yet",
                                       message: "Pin an exercise or a cardio activity to follow it here.",
                                       actionTitle: "Add Chart") { adding = true }
                            .padding(.top, 40)
                            .accessibilityIdentifier("progressEmptyState")
                    } else {
                        ForEach(visible) { pin in
                            Button { opened = pin } label: { panel(pin) }
                                .buttonStyle(.lookPressable)
                                .contextMenu { menu(for: pin, in: visible) }
                                .accessibilityIdentifier("progressPanel")
                        }
                        Button("Add Chart", systemImage: "plus") { adding = true }
                            .buttonStyle(.lookSecondary)
                            .padding(.top, 8)
                            .accessibilityIdentifier("progressAddChartBottom")
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 2)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .lookScreenBackground()
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 70 : 46)
            } action: { _, past in
                withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(look.ground, for: .navigationBar)
            .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Progress")
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .opacity(titleInBar ? 1 : 0)
                        .accessibilityHidden(!titleInBar)
                }
                if !shown.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add Chart", systemImage: "plus") { adding = true }
                            .tint(look.textPrimary)
                            .accessibilityIdentifier("progressAddChart")
                    }
                }
            }
            .sheet(isPresented: $adding, onDismiss: refresh) {
                AddChartSheet { pin in save(pins + [pin]) }
            }
            .sheet(item: $opened, onDismiss: refresh) { pin in
                NavigationStack { destination(pin) }
            }
        }
        // Read on every visit to the tab and after a sheet closes (a workout edited from a chart): a fetch of every
        // set per render would run on each scroll-title change.
        .onAppear(perform: refresh)
        .onChange(of: workouts.count) { _, _ in refresh() }
    }

    private func refresh() { history = ExerciseHistory.all(in: modelContext) }

    // MARK: Panels

    private var displayUnit: WeightUnit { LiftProgressValues.displayUnit(in: modelContext) }

    private var distanceUnit: CardioDistanceUnit {
        AppUnitSystem.resolve(preference: AppPreferences.canonical(of: preferences)?.unitPreference).distanceUnit
    }

    @ViewBuilder private func panel(_ pin: ProgressPin) -> some View {
        switch pin.subject {
        case let .lift(exerciseID, variation):
            let items = history[exerciseID] ?? []
            let inputs = items.map(\.input)
            let name = exercises.first { $0.id == exerciseID }?.name ?? ""
            if let key = variation.resolve(in: inputs) {
                let metric = liftMetric(pin.shownMetric(loadType: key.loadType))
                let series = ProgressSeriesMath.series(for: inputs, variation: key)
                let values = LiftProgressValues(metric: metric, loadType: key.loadType, displayUnit: displayUnit)
                ProgressPanel(
                    title: name,
                    subtitle: "\(liftLabel(key, inputs: inputs, mostUsed: variation == .mostUsed)) · \(pin.shownMetric(loadType: key.loadType).title())",
                    glyph: glyph(key.equipment),
                    reading: .lift(series: series, recordDays: ProgressSeriesMath.recordDays(series), values: values))
            } else {
                ProgressPanel(title: name, subtitle: pin.metric.title(), glyph: "circle.dashed",
                              reading: ProgressReading(value: "—", unit: "", caption: "", points: []))
            }
        case .cardio:
            if let activity = pin.activity {
                let sessions = CardioProgressMath.sessions(in: workouts, activity: activity)
                let metric = pin.shownMetric(loadType: nil)
                ProgressPanel(
                    title: activity.name,
                    subtitle: "\(HistoryRendering.pluralized(sessions.count, "session", "sessions")) · \(metric.title(for: activity))",
                    glyph: activity.symbol,
                    reading: .cardio(sessions, metric: metric, activity: activity, unit: distanceUnit))
            }
        }
    }

    /// "Most used · Chest Press 2", "Barbell": the variation's label as the exercise chart names it.
    private func liftLabel(_ key: ProgressVariationKey, inputs: [RecordSetInput], mostUsed: Bool) -> String {
        let ranked = ProgressSeriesMath.rankedVariations(in: inputs)
        let entries = (try? modelContext.fetch(FetchDescriptor<ExerciseEntry>())) ?? []
        var rows = ranked.map { (key: $0.key, words: ExerciseOverview.variationWords(for: $0.key, entries: entries)) }
        if !rows.contains(where: { $0.key == key }) {
            rows.append((key: key, words: ExerciseOverview.variationWords(for: key, entries: entries)))
        }
        let label = ProgressSeriesMath.labels(for: rows)[key] ?? ""
        return mostUsed ? "Most used · \(label)" : label
    }

    private func liftMetric(_ metric: ProgressPinMetric) -> ExerciseProgressView.Metric {
        switch metric {
        case .volume: .volume
        case .e1rm: .e1rm
        default: .bestSet
        }
    }

    private func glyph(_ equipment: ProgressEquipment) -> String {
        switch equipment {
        case .machine: LookIcon.machine
        case .freeWeight(let tag): tag.historySymbol
        case .unrecorded: "circle.dashed"
        }
    }

    // MARK: Open

    @ViewBuilder private func destination(_ pin: ProgressPin) -> some View {
        switch pin.subject {
        case let .lift(exerciseID, variation):
            let inputs = (history[exerciseID] ?? []).map(\.input)
            ExerciseProgressView(exerciseID: exerciseID,
                                 exerciseName: exercises.first { $0.id == exerciseID }?.name ?? "",
                                 initialVariation: variation.resolve(in: inputs))
        case .cardio:
            if let activity = pin.activity {
                CardioProgressView(activity: activity, metric: pin.shownMetric(loadType: nil))
            }
        }
    }

    // MARK: Long-press

    @ViewBuilder private func menu(for pin: ProgressPin, in visible: [ProgressPin]) -> some View {
        let options = metricOptions(pin)
        if options.count > 1 {
            // Inline under a "Show" heading: one tap to change what the panel draws.
            Section("Show") {
            Picker("Show", selection: Binding(
                get: { pin.shownMetric(loadType: loadType(pin)) },
                set: { metric in save(pins.map { $0.id == pin.id ? ProgressPin(id: $0.id, subject: $0.subject, metric: metric) : $0 }) }
            )) {
                ForEach(options, id: \.self) { Text($0.title(for: pin.activity)).tag($0) }
            }
            .pickerStyle(.inline)
            }
        }
        // Moves are within what is shown; a hidden pin (its exercise deleted) keeps its place in the stored list.
        if let index = visible.firstIndex(where: { $0.id == pin.id }) {
            if index > 0 {
                Button("Move Up", systemImage: "arrow.up") { swap(pin, with: visible[index - 1]) }
            }
            if index < visible.count - 1 {
                Button("Move Down", systemImage: "arrow.down") { swap(pin, with: visible[index + 1]) }
            }
        }
        Button("Remove from Progress", systemImage: "pin.slash", role: .destructive) {
            save(pins.filter { $0.id != pin.id })
        }
    }

    private func swap(_ a: ProgressPin, with b: ProgressPin) {
        var all = pins
        guard let i = all.firstIndex(where: { $0.id == a.id }), let j = all.firstIndex(where: { $0.id == b.id }) else { return }
        all.swapAt(i, j)
        save(all)
    }

    private func loadType(_ pin: ProgressPin) -> LoadType? {
        guard case let .lift(exerciseID, variation) = pin.subject else { return nil }
        return variation.resolve(in: (history[exerciseID] ?? []).map(\.input))?.loadType
    }

    private func metricOptions(_ pin: ProgressPin) -> [ProgressPinMetric] {
        switch pin.subject {
        case .lift: ProgressPinMetric.lifting(for: loadType(pin) ?? .weighted)
        case .cardio: ProgressPinMetric.cardio
        }
    }
}
