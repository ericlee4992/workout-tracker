import Charts
import SwiftUI

// EXPLORATION (2026-11-07) — Soft "Progress": body weight against a goal, its trend, calories
// this week against the goal, and strength (each lift's best set and change; taps open the
// existing exercise page).

struct SoftProgressScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var nutrition = SoftNutrition.shared
    @State private var range = "90D"
    @State private var showLogWeight = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Progress").font(.system(.largeTitle, weight: .bold)).foregroundStyle(look.textPrimary)
                    .padding(.top, 6)
                weightCard
                trendCard
                caloriesCard
                strengthCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogWeight) { SoftLogWeightSheet().presentationDetents([.medium]) }
        .proposalScreen("progress")
    }

    private var current: Double { nutrition.weights.last ?? 0 }

    private var weightCard: some View {
        let done = (nutrition.startWeight - current) / (nutrition.startWeight - nutrition.goalWeight)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body weight").font(.system(.subheadline, weight: .medium)).foregroundStyle(look.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(current.formatted(.number.precision(.fractionLength(1)))).font(.system(size: 40, weight: .semibold))
                        Text("lb").font(.system(.title3, weight: .medium)).foregroundStyle(look.textSecondary)
                    }
                    .foregroundStyle(look.textPrimary)
                    .monospacedDigit()
                }
                Spacer()
                SoftPillButton(title: "Log weight", trailingSymbol: "arrow.right") { showLogWeight = true }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(look.ringTrack)
                    Capsule().fill(look.textPrimary).frame(width: geo.size.width * max(0.02, min(done, 1)))
                }
            }
            .frame(height: 8)
            HStack {
                Text("Start ").foregroundStyle(look.textSecondary) + Text("\(Int(nutrition.startWeight)) lb").bold()
                Spacer()
                Text("Goal ").foregroundStyle(look.textSecondary) + Text("\(Int(nutrition.goalWeight)) lb").bold()
            }
            .font(.system(.subheadline))
            .foregroundStyle(look.textPrimary)
            Text("At this pace you reach your goal around ").foregroundStyle(look.textSecondary)
                + Text("Jan 30").bold().foregroundStyle(look.textPrimary)
        }
        .font(.system(.subheadline))
        .padding(20)
        .lookSurface(.panel)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weight trend").font(.system(.title3, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer()
                Label("\(Int(((nutrition.startWeight - current) / (nutrition.startWeight - nutrition.goalWeight) * 100).rounded()))% of goal", systemImage: "flag")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(look.surfaceRaised, in: Capsule())
            }
            Chart {
                ForEach(Array(nutrition.weights.enumerated()), id: \.offset) { i, w in
                    LineMark(x: .value("Week", i), y: .value("lb", w))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(look.textPrimary)
                    PointMark(x: .value("Week", i), y: .value("lb", w))
                        .symbolSize(18)
                        .foregroundStyle(look.textPrimary)
                }
                RuleMark(y: .value("Goal", nutrition.goalWeight))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(look.textTertiary)
            }
            .chartYScale(domain: 168...182)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [170, 175, 180]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(look.hairline)
                    AxisValueLabel().foregroundStyle(look.textSecondary)
                }
            }
            .frame(height: 180)
            SoftSegmented(options: ["90D", "6M", "1Y", "All"], selection: $range)
        }
        .padding(20)
        .lookSurface(.panel)
    }

    private var caloriesCard: some View {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        let logged = nutrition.week.compactMap { $0 }
        let average = logged.isEmpty ? 0 : logged.reduce(0, +) / logged.count
        return VStack(alignment: .leading, spacing: 16) {
            Text("Calories this week").font(.system(.title3, weight: .semibold)).foregroundStyle(look.textPrimary)
            HStack(spacing: 28) {
                stat("Daily average", average.formatted(), "cal")
                stat("Goal", nutrition.calorieGoal.formatted(), "cal")
            }
            Chart {
                ForEach(0..<7, id: \.self) { i in
                    let value = i == 5 ? nutrition.eaten : (nutrition.week[i] ?? 0)
                    BarMark(x: .value("Day", "\(i)"), y: .value("cal", value), width: .ratio(0.34))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .foregroundStyle(i == 5 ? look.textPrimary : look.textPrimary.opacity(0.28))
                }
                RuleMark(y: .value("Goal", nutrition.calorieGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(look.textTertiary)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self), let i = Int(s) { Text(days[i]).foregroundStyle(look.textSecondary) }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
        }
        .padding(20)
        .lookSurface(.panel)
    }

    private var strengthCard: some View {
        let lifts: [(String, String, String)] = [
            ("Seated Chest Press", "110 lb × 8", "+11%"),
            ("Leg Press", "320 lb × 10", "+8%"),
            ("Lat Pulldown", "140 lb × 8", "+5%"),
        ]
        return VStack(alignment: .leading, spacing: 4) {
            Text("Strength").font(.system(.title3, weight: .semibold)).foregroundStyle(look.textPrimary)
                .padding(.bottom, 8)
            ForEach(Array(lifts.enumerated()), id: \.offset) { i, lift in
                if i > 0 { LookDivider() }
                Button { router.push(.exerciseDetail(exerciseID: SampleData.exerciseID(lift.0))) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lift.0).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                            Text("Best set").font(.system(.footnote)).foregroundStyle(look.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(lift.1).font(.system(.body, weight: .semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
                            Text("\(lift.2) since first").font(.system(.footnote)).foregroundStyle(look.textSecondary)
                        }
                        Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textTertiary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .lookSurface(.panel)
    }

    private func stat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(.footnote, weight: .medium)).foregroundStyle(look.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(.title2, weight: .semibold)).monospacedDigit()
                Text(unit).font(.system(.footnote)).foregroundStyle(look.textSecondary)
            }
            .foregroundStyle(look.textPrimary)
        }
    }
}

/// The pill segmented control: a white thumb on a light track.
struct SoftSegmented: View {
    var options: [String]
    @Binding var selection: String
    @Environment(\.look) private var look
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button { withAnimation(.snappy) { selection = option } } label: {
                    Text(option)
                        .font(.system(.subheadline, weight: on ? .semibold : .medium))
                        .foregroundStyle(on ? look.textPrimary : look.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if on {
                                Capsule().fill(look.isDark ? look.surfaceRaised.opacity(1.6) : .white)
                                    .shadow(color: .black.opacity(look.isDark ? 0 : 0.06), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(look.isDark ? look.surfaceRaised : Color(hex: 0xEFEFF3), in: Capsule())
    }
}
