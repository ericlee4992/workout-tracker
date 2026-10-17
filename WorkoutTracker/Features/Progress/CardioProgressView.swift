import SwiftData
import SwiftUI

// Public beta ticket 16 (D63): a cardio activity's progress, opened from its Progress panel — the cardio counterpart of
// `ExerciseProgressView`: the metric pills (Distance · Pace or Speed · Time; no heart-rate view), the chart panel, the
// bests and every session (tap one to open its workout). Presented as a sheet, like the exercise chart.

struct CardioProgressView: View {
    let activity: CardioActivity
    @State private var metric: ProgressPinMetric
    @State private var titleInBar = false
    @State private var ticks = 0
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt)
    private var workouts: [Workout]
    @Query private var preferences: [AppPreferences]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss

    init(activity: CardioActivity, metric: ProgressPinMetric) {
        self.activity = activity
        _metric = State(initialValue: metric.isCardio ? metric : .distance)
    }

    /// The app's distance unit (D52: a plain conversion; sessions logged in km and mi share one axis).
    private var unit: CardioDistanceUnit {
        AppUnitSystem.resolve(preference: AppPreferences.canonical(of: preferences)?.unitPreference).distanceUnit
    }

    var body: some View {
        let sessions = CardioProgressMath.sessions(in: workouts, activity: activity)
        let reading = ProgressReading.cardio(sessions, metric: metric, activity: activity, unit: unit)
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.name)
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 8) {
                        LookIcon(activity.symbol, style: .footnote)
                        Text(HistoryRendering.pluralized(sessions.count, "session", "sessions"))
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(look.textSecondary)
                }
                SegmentedPills(ProgressPinMetric.cardio.map { $0.title(for: activity) }, selection: Binding(
                    get: { ProgressPinMetric.cardio.firstIndex(of: metric) ?? 0 },
                    set: { metric = ProgressPinMetric.cardio[$0]; ticks += 1 }))
                    .accessibilityLabel("Metric")
                    .accessibilityIdentifier("cardioProgressMetric")
                chartPanel(reading)
                bests(sessions)
                sessionList(sessions)
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
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(look.groundSheet, for: .navigationBar)
        .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(activity.name)
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .opacity(titleInBar ? 1 : 0)
                    .accessibilityHidden(!titleInBar)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .tint(look.textPrimary)
                    .accessibilityIdentifier("closeCardioProgress")
            }
        }
        .navigationDestination(for: ProgressSessionLink.self) { WorkoutDetailView(workout: $0.workout) }
        .sensoryFeedback(.selection, trigger: ticks)
    }

    @ViewBuilder private func chartPanel(_ reading: ProgressReading) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch reading.state {
            case .empty:
                Text("Nothing to chart here").font(look.font.subhead).foregroundStyle(look.textSecondary)
            case .single:
                ProgressReadingValue(reading: reading, numberFont: look.font.heroNumber)
                Text("One session").font(look.font.footnote).foregroundStyle(look.textSecondary)
            case .series:
                ProgressReadingHeader(reading: reading, numberFont: look.font.heroNumber)
                ProgressPanelChart(reading: reading, height: 160)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardioProgressPanel")
    }

    // MARK: Bests

    @ViewBuilder private func bests(_ sessions: [CardioProgressSession]) -> some View {
        let top = CardioProgressMath.bests(sessions, activity: activity, unit: unit)
        let rows: [(title: String, point: CardioProgressPoint, value: String, symbol: String)] = [
            top.longest.map { ("Longest distance", $0, "\(String(format: "%.1f", $0.value)) \(unit.rawValue)", CardioFormat.distanceSymbol) },
            top.fastest.map { point in
                activity.usesSpeed
                    ? ("Fastest average", point, "\(String(format: "%.1f", point.value)) \(CardioFormat.speedUnit(unit))", "speedometer")
                    : ("Fastest pace", point, "\(CardioMath.paceText(point.value)) \(CardioProgressMath.paceLabel(activity, unit: unit))", "speedometer")
            },
            top.longestTime.map { ("Longest session", $0, "\(Int($0.value.rounded())) min", "timer") },
        ].compactMap { $0 }
        if !rows.isEmpty {
            LookList(header: "Bests") {
                ForEach(rows, id: \.title) { row in
                    LookRow(row.title, subtitle: LookFormat.shortDate(row.point.date), symbol: row.symbol, showsChevron: false) {
                        Text(row.value).font(look.font.fieldNumber).foregroundStyle(look.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: Sessions

    @ViewBuilder private func sessionList(_ sessions: [CardioProgressSession]) -> some View {
        let byID = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if !sessions.isEmpty {
            LookList(header: "Sessions") {
                ForEach(sessions.reversed()) { session in
                    if let workout = byID[session.workoutID] {
                        NavigationLink(value: ProgressSessionLink(workout: workout)) {
                            LookRow(HistoryFormat.shortDayTitle(session.date), subtitle: line(session)) { EmptyView() }
                        }
                        .buttonStyle(HistoryRowPressStyle())
                        .accessibilityIdentifier("cardioProgressSession")
                    }
                }
            }
        }
    }

    /// "5.2 km · 30 min · 5:43 /km · 152 bpm": what the session logged, in the app's unit.
    private func line(_ session: CardioProgressSession) -> String {
        var parts: [String] = []
        if let km = CardioProgressMath.value(session, metric: .distance, activity: activity, unit: unit) {
            parts.append("\(String(format: "%.1f", km)) \(unit.rawValue)")
        }
        parts.append("\(Int((session.seconds / 60).rounded())) min")
        if let rate = CardioProgressMath.value(session, metric: .pace, activity: activity, unit: unit) {
            parts.append(activity.usesSpeed
                ? "\(String(format: "%.1f", rate)) \(CardioFormat.speedUnit(unit))"
                : "\(CardioMath.paceText(rate)) \(CardioProgressMath.paceLabel(activity, unit: unit))")
        }
        if let bpm = session.heartRate { parts.append("\(bpm) bpm") }
        return parts.joined(separator: " · ")
    }
}
