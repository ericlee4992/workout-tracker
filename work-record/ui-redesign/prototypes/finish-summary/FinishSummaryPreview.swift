// DESIGN PROTOTYPE ONLY. No persistence or product dependencies.
// Same fixed illustrative workout in all three directions; actions are visual placeholders.
import SwiftUI
import Charts

private enum Ink {
    static let background = Color(hex: 0x0B0D10)
    static let card = Color(hex: 0x171B21)
    static let fill = Color(hex: 0x2B323C)
    static let text = Color(hex: 0xF6F3EC)
    static let secondary = Color(hex: 0xB5B9C2)
    static let amber = Color(hex: 0xFFB45E)
    static let red = Color(hex: 0xFF6B76)
    static let stat = Font.system(.title2, design: .rounded, weight: .bold)
    static let hero = Font.system(.largeTitle, design: .rounded, weight: .black)
}
private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255)/255,
                  green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1)
    }
}
private extension View {
    func inkCard() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.07)))
    }
}

struct FinishSummaryPreview: View {
    var direction: String = "A"
    var anchor: String = "top"
    @Environment(\.dynamicTypeSize) private var type
    private let exercises = [
        ["Seated Chest Press", "Chest Press · Life Fitness Insignia Series", "4 sets · best 130 lb × 10"],
        ["Lat Pulldown", "Hammer Strength", "3 sets · best 100 lb × 10"],
        ["Lateral Raise", "Dumbbell", "3 sets · best 20 lb × 12"]
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        confirmation.id("top")
                        if direction == "A" {
                            section("Workout details") { balancedStats }.id("stats")
                            section("Heart rate") { graph }.id("graph")
                            zones.id("zones")
                            exerciseList.id("exercises")
                        } else if direction == "B" {
                            liftingHero
                            exerciseList.id("exercises")
                            section("Workout details") { healthStats }.id("stats")
                            section("Heart rate") { graph }.id("graph")
                            zones.id("zones")
                        } else {
                            section("Heart rate") { graph }.id("graph")
                            zones.id("zones")
                            section("Workout details") { balancedStats }.id("stats")
                            exerciseList.id("exercises")
                        }
                        actions.id("actions")
                    }
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 24)
                }
                .task {
                    try? await Task.sleep(for: .milliseconds(600))
                    scroll.scrollTo(anchor, anchor: .top)
                }
            }
            .background(Ink.background)
            .navigationTitle("Nice work").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") {}.font(.headline) } }
        }
        .tint(Ink.text).foregroundStyle(Ink.text).preferredColorScheme(.dark)
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Workout saved", systemImage: "checkmark.circle.fill")
                .font(.headline).symbolRenderingMode(.hierarchical)
                .foregroundStyle(Ink.text)
            Text("3 exercises · 10 sets · Iron Temple")
                .font(.subheadline).foregroundStyle(Ink.secondary)
        }
    }
    private func section<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name).font(.headline).foregroundStyle(Ink.secondary)
            content()
        }
    }
    private func metric(_ title: String, _ value: String, tint: Color = Ink.text, hero: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(hero ? Ink.hero : Ink.stat).monospacedDigit().foregroundStyle(tint)
            Text(title).font(.caption).foregroundStyle(Ink.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func pair<L: View, R: View>(@ViewBuilder left: () -> L, @ViewBuilder right: () -> R) -> some View {
        Group {
            if type.isAccessibilitySize { VStack(alignment: .leading, spacing: 16) { left(); right() } }
            else { HStack(alignment: .top, spacing: 16) { left(); right() } }
        }
    }
    private var balancedStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            pair { metric("Workout time", "48:12", hero: direction == "A") }
                right: { metric("Total volume", "9,740 lb") }
            Divider()
            pair { metric("Active calories", "312 CAL") }
                right: { metric("Total calories", "380 CAL") }
            pair { metric("Avg. heart rate", "126 BPM", tint: Ink.red) }
                right: { metric("Max heart rate", "159 BPM", tint: Ink.red) }
        }.inkCard()
    }
    private var liftingHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            metric("Total volume", "9,740 lb", hero: true)
            Divider()
            metric("Workout time", "48:12")
        }.inkCard()
    }
    private var healthStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            pair { metric("Active calories", "312 CAL") } right: { metric("Total calories", "380 CAL") }
            pair { metric("Avg. heart rate", "126 BPM", tint: Ink.red) }
                right: { metric("Max heart rate", "159 BPM", tint: Ink.red) }
        }.inkCard()
    }
    private var graph: some View {
        VStack(alignment: .leading, spacing: 10) {
            if direction == "C" { metric("Avg. heart rate", "126 BPM", tint: Ink.red, hero: true) }
            Chart {
                ForEach(0..<96, id: \.self) { i in
                    // Illustrative intervals, not computed session data. Floating low/high bars.
                    let center = 124.0 + 20 * sin(Double(i) * 0.31) + 5 * cos(Double(i) * 0.79)
                    RectangleMark(xStart: .value("From", Double(i) + 0.30),
                                  xEnd: .value("To", Double(i) + 0.70),
                                  yStart: .value("Low", i == 0 ? 89 : center - 8),
                                  yEnd: .value("High", i == 63 ? 159 : center + 9))
                    .foregroundStyle(LinearGradient(colors: [Ink.amber, Ink.red], startPoint: .bottom, endPoint: .top))
                    .cornerRadius(1)
                }
            }
            .chartXScale(domain: 0...96).chartYScale(domain: 80...168)
            .chartXAxis {
                AxisMarks(values: [0,32,64]) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.07))
                    AxisValueLabel(anchor: .topLeading) {
                        if let x = value.as(Int.self), !type.isAccessibilitySize || x == 0 {
                            Text(x == 0 ? "18:00" : x == 32 ? "18:16" : "18:32")
                                .font(.caption2).foregroundStyle(Ink.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [89,159]) { _ in
                    AxisValueLabel().foregroundStyle(Ink.secondary)
                }
            }
            .frame(height: direction == "C" ? 180 : 150)
            Text("126 BPM AVG").font(.caption.weight(.semibold)).foregroundStyle(Ink.red)
        }.inkCard()
    }
    private let zoneNames = ["Warm-up", "Zone 1", "Zone 2", "Zone 3", "Zone 4"]
    private let zoneTimes = ["2:00", "5:12", "16:00", "19:00", "6:00"]
    private let zoneFractions: [CGFloat] = [120,312,960,1140,360]
    private let zoneColors: [Color] = [Color(hex:0x7F8793), Color(hex:0x8ABCE5), Color(hex:0x80CABE), Color(hex:0xA5CF9A), Ink.amber]
    private var zones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time in zones").font(.headline)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: 3).fill(zoneColors[i])
                            .frame(width: (geo.size.width - 8) * zoneFractions[i] / 2892)
                    }
                }
            }.frame(height: 12)
            ForEach(0..<5) { i in
                HStack {
                    Circle().fill(zoneColors[i]).frame(width: 8, height: 8)
                    Text(zoneNames[i]).foregroundStyle(Ink.secondary)
                    Spacer()
                    Text(zoneTimes[i]).fontWeight(.semibold).monospacedDigit()
                }.font(.caption)
            }
        }.inkCard()
    }
    private var exerciseList: some View {
        section("Exercises") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<exercises.count, id: \.self) { i in
                    if i > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercises[i][0]).font(.headline)
                        Text(exercises[i][1]).font(.caption).foregroundStyle(Ink.secondary)
                        Text(exercises[i][2]).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.inkCard()
        }
    }
    private var actions: some View {
        VStack(spacing: 8) {
            Button {} label: {
                Label("View in History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 4)
            }
            Button {} label: {
                Label("Save as Template", systemImage: "square.on.square")
                    .frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 4)
            }
        }.font(.headline).buttonStyle(.bordered).tint(Ink.secondary)
    }
}

@main
struct PreviewApp: App {
    @State private var shown = true
    var body: some Scene {
        WindowGroup {
            Ink.background.ignoresSafeArea().sheet(isPresented: $shown) {
                FinishSummaryPreview(direction: UserDefaults.standard.string(forKey: "direction") ?? "A",
                                     anchor: UserDefaults.standard.string(forKey: "anchor") ?? "top")
                    .presentationDetents([.large]).interactiveDismissDisabled()
            }.preferredColorScheme(.dark)
        }
    }
}

#if DEBUG
#Preview("A · Balanced") { FinishSummaryPreview(direction: "A") }
#Preview("B · Lifting") { FinishSummaryPreview(direction: "B") }
#Preview("C · Heart rate") { FinishSummaryPreview(direction: "C") }
#endif
