import Charts
import SwiftUI

// PROPOSAL (Soft, round 2, 2026-11-07) — Progress keeps the shipped app's model (pinned charts,
// "Add Chart") but anything can be pinned now: exercises, body weight, weight trend, calories,
// protein, macros, workouts per week, training volume, cardio distance. In Soft's materials.

enum SoftChartKind: Hashable, Identifiable {
    case exercise(String), bodyWeight, weightTrend, calories, protein, macros, workoutsPerWeek, volume, cardioDistance

    var id: String {
        switch self {
        case .exercise(let name): "exercise.\(name)"
        default: "\(self)"
        }
    }

    enum Category: String, CaseIterable { case training = "Training", body = "Body", nutrition = "Nutrition" }

    var category: Category {
        switch self {
        case .exercise, .workoutsPerWeek, .volume, .cardioDistance: .training
        case .bodyWeight, .weightTrend: .body
        case .calories, .protein, .macros: .nutrition
        }
    }

    var title: String {
        switch self {
        case .exercise(let name): name
        case .bodyWeight: "Body weight"
        case .weightTrend: "Weight trend"
        case .calories: "Calories"
        case .protein: "Protein"
        case .macros: "Macros"
        case .workoutsPerWeek: "Workouts per week"
        case .volume: "Training volume"
        case .cardioDistance: "Running distance"
        }
    }

    var detail: String {
        switch self {
        case .exercise(let name): name == "Seated Chest Press" ? "Best set · Chest Press 2" : "Best set"
        case .bodyWeight: "Each weigh-in"
        case .weightTrend: "7-day average"
        case .calories: "Eaten per day vs goal"
        case .protein: "Grams per day vs goal"
        case .macros: "Protein · carbs · fat per day"
        case .workoutsPerWeek: "Last 8 weeks"
        case .volume: "Working sets × weight, per week"
        case .cardioDistance: "Outdoor and indoor runs"
        }
    }

    var symbol: String {
        switch self {
        case .exercise: "dumbbell"
        case .bodyWeight, .weightTrend: "scalemass"
        case .calories: "flame"
        case .protein, .macros: "fork.knife"
        case .workoutsPerWeek: "calendar"
        case .volume: "square.stack.3d.up"
        case .cardioDistance: "figure.run"
        }
    }

    var isBars: Bool {
        switch self {
        case .calories, .protein, .workoutsPerWeek, .volume, .macros: true
        default: false
        }
    }

    /// (value, unit, change) for the card's headline.
    var headline: (String, String, String) {
        switch self {
        case .exercise(let name):
            switch name {
            case "Leg Press": ("320 × 10", "lb", "+8% since first session")
            case "Lat Pulldown": ("140 × 8", "lb", "+5% since first session")
            default: ("110 × 8", "lb", "+11% since first session")
            }
        case .bodyWeight: ("172.4", "lb", "−7.6 lb in 12 weeks")
        case .weightTrend: ("172.9", "lb", "−0.6 lb a week")
        case .calories: ("2,211", "cal", "daily average, 5 of 7 days logged")
        case .protein: ("118", "g", "daily average · goal 149 g")
        case .macros: ("31 / 47 / 22", "%", "protein / carbs / fat, this week")
        case .workoutsPerWeek: ("4", "this week", "3.6 on average")
        case .volume: ("41,200", "lb", "+6% vs last week")
        case .cardioDistance: ("3.2", "mi", "longest run, Nov 4")
        }
    }

    var series: [Double] {
        switch self {
        case .exercise(let name): name == "Leg Press" ? [280, 290, 290, 300, 310, 320] : [90, 95, 95, 100, 105, 110]
        case .bodyWeight: SoftNutrition.shared.weights
        case .weightTrend: [179.9, 179.4, 178.9, 178.3, 177.8, 177.0, 176.3, 175.6, 175.0, 174.4, 173.8, 173.3, 172.9]
        case .calories: [2_140, 2_310, 1_980, 2_205, 2_420, Double(SoftNutrition.shared.eaten), 0]
        case .protein: [126, 141, 98, 133, 112, Double(SoftNutrition.shared.eaten(.protein)), 0]
        case .macros: [2_140, 2_310, 1_980, 2_205, 2_420, Double(SoftNutrition.shared.eaten), 0]
        case .workoutsPerWeek: [3, 4, 3, 5, 4, 3, 4, 4]
        case .volume: [32_100, 35_400, 33_800, 38_900, 36_200, 39_000, 38_800, 41_200]
        case .cardioDistance: [2.1, 2.4, 2.2, 2.8, 2.6, 3.0, 3.2]
        }
    }

    var goal: Double? {
        switch self {
        case .calories, .macros: Double(SoftNutrition.shared.calorieGoal)
        case .protein: 149
        case .bodyWeight, .weightTrend: 170
        default: nil
        }
    }

    static let all: [SoftChartKind] = [
        .exercise("Seated Chest Press"), .exercise("Leg Press"), .exercise("Lat Pulldown"),
        .workoutsPerWeek, .volume, .cardioDistance, .bodyWeight, .weightTrend, .calories, .protein, .macros,
    ]
}

@MainActor @Observable
final class SoftBoard {
    static let shared = SoftBoard()
    var pinned: [SoftChartKind] = [.bodyWeight, .exercise("Seated Chest Press"), .calories, .protein]
    func toggle(_ kind: SoftChartKind) {
        withAnimation(.snappy) {
            if let i = pinned.firstIndex(of: kind) { pinned.remove(at: i) } else { pinned.append(kind) }
        }
    }
    func moveUp(_ kind: SoftChartKind) {
        guard let i = pinned.firstIndex(of: kind), i > 0 else { return }
        withAnimation(.snappy) { pinned.swapAt(i, i - 1) }
    }
    private init() {}
}

struct SoftProgressBoard: View {
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var board = SoftBoard.shared
    @State private var adding = UserDefaults.standard.bool(forKey: "softAddChart")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Progress").font(.system(.largeTitle, weight: .bold)).foregroundStyle(look.textPrimary)
                    Spacer()
                    Button { adding = true } label: {
                        Image(systemName: "plus").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(look.surface, in: Circle())
                            .shadow(color: .black.opacity(look.isDark ? 0 : 0.06), radius: 8, y: 2)
                    }
                    .accessibilityLabel("Add Chart")
                }
                .padding(.top, 6)
                ForEach(board.pinned) { kind in
                    SoftChartCard(kind: kind) {
                        if case .exercise(let name) = kind { router.push(.exerciseDetail(exerciseID: SampleData.exerciseID(name))) }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                Button { adding = true } label: {
                    Label("Add Chart", systemImage: "plus")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay { Capsule().strokeBorder(look.textPrimary.opacity(0.14), lineWidth: 1) }
                        .contentShape(Capsule())
                }
                .buttonStyle(.lookPressable)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) { SoftAddChartSheet().presentationDetents([.large]).environment(\.look, look) }
        .proposalScreen("progress")
    }
}

struct SoftChartCard: View {
    let kind: SoftChartKind
    var open: () -> Void
    @Environment(\.look) private var look
    @State private var board = SoftBoard.shared

    var body: some View {
        let (value, unit, change) = kind.headline
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title).font(.system(.headline)).foregroundStyle(look.textPrimary)
                    Text(kind.detail).font(.system(.footnote)).foregroundStyle(look.textSecondary)
                }
                Spacer()
                Menu {
                    Button("Move Up", systemImage: "arrow.up") { board.moveUp(kind) }
                    Button("Remove Chart", systemImage: "minus.circle", role: .destructive) { board.toggle(kind) }
                } label: {
                    Image(systemName: "ellipsis").font(.system(.body, weight: .semibold)).foregroundStyle(look.textSecondary)
                        .frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .accessibilityLabel("\(kind.title) options")
            }
            Button(action: open) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(value).font(.system(size: 30, weight: .semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
                        Text(unit).font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textSecondary)
                    }
                    Text(change).font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
                    chart.frame(height: 110)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .lookSurface(.panel)
    }

    @ViewBuilder private var chart: some View {
        let series = kind.series
        if kind == .macros {
            Chart {
                ForEach(0..<7, id: \.self) { i in
                    let total = series[i]
                    if total > 0 {
                        BarMark(x: .value("Day", "\(i)"), y: .value("cal", total * 0.31)).foregroundStyle(SoftMacro.protein.color)
                        BarMark(x: .value("Day", "\(i)"), y: .value("cal", total * 0.47)).foregroundStyle(SoftMacro.carbs.color)
                        BarMark(x: .value("Day", "\(i)"), y: .value("cal", total * 0.22)).foregroundStyle(SoftMacro.fat.color)
                    }
                }
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
        } else if kind.isBars {
            Chart {
                ForEach(Array(series.enumerated()), id: \.offset) { i, v in
                    if v > 0 {
                        BarMark(x: .value("i", "\(i)"), y: .value("v", v), width: .ratio(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .foregroundStyle(i == series.lastIndex(where: { $0 > 0 }) ? look.textPrimary : look.textPrimary.opacity(0.22))
                    }
                }
                if let goal = kind.goal {
                    RuleMark(y: .value("Goal", goal)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(look.textTertiary)
                }
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
        } else {
            let lo = (series.min() ?? 0), hi = (series.max() ?? 1)
            let pad = max(1, (hi - lo) * 0.2)
            Chart {
                ForEach(Array(series.enumerated()), id: \.offset) { i, v in
                    LineMark(x: .value("i", i), y: .value("v", v)).interpolationMethod(.catmullRom).foregroundStyle(look.textPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    if i == series.count - 1 {
                        PointMark(x: .value("i", i), y: .value("v", v)).symbolSize(50).foregroundStyle(look.textPrimary)
                    }
                }
                if let goal = kind.goal, goal >= lo - pad * 3 {
                    RuleMark(y: .value("Goal", goal)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(look.textTertiary)
                }
            }
            .chartYScale(domain: min(lo - pad, kind.goal ?? lo) ... hi + pad)
            .chartXAxis(.hidden).chartYAxis(.hidden)
        }
    }
}

struct SoftAddChartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var board = SoftBoard.shared
    @State private var category = "Training"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add Chart").font(.system(.title2, weight: .bold)).foregroundStyle(look.textPrimary)
                Spacer()
                Button("Done") { dismiss() }.font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
            }
            .padding(.top, 22)
            SoftSegmented(options: SoftChartKind.Category.allCases.map(\.rawValue), selection: $category)
            ScrollView {
                VStack(spacing: 0) {
                    let kinds = SoftChartKind.all.filter { $0.category.rawValue == category }
                    ForEach(Array(kinds.enumerated()), id: \.element.id) { i, kind in
                        if i > 0 { LookDivider().padding(.leading, 56) }
                        let on = board.pinned.contains(kind)
                        Button { board.toggle(kind) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: kind.symbol).font(.system(.body, weight: .semibold)).frame(width: 26)
                                    .foregroundStyle(look.textPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                                    Text(kind.detail).font(.system(.footnote)).foregroundStyle(look.textSecondary)
                                }
                                Spacer()
                                Image(systemName: on ? "checkmark" : "plus").font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(on ? look.onAction : look.textPrimary)
                                    .frame(width: 34, height: 34)
                                    .background { if on { Circle().fill(look.action) } else { Circle().strokeBorder(look.textPrimary.opacity(0.2)) } }
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .padding(.horizontal, 16).frame(minHeight: 64).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(on ? "On Progress" : "")
                    }
                }
                .lookSurface(.panel)
            }
        }
        .padding(.horizontal, 20)
        .background(look.ground.ignoresSafeArea())
    }
}
