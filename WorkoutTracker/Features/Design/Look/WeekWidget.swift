import SwiftUI

// "This week" on Home: a scoreboard — five family maps with set counts, seven day cells lit
// with minutes, and a Workouts · Time · Last week footer divided by hairlines.

struct WeekWidget: View {
    var summary: WeekSummary
    @Environment(\.look) private var look

    var body: some View {
        FloodlightWeek(summary: summary)
    }
}

/// "1 h 43 min" split into number and unit runs so numbers can be big and units small.
struct DurationFigure: View {
    var minutes: Int
    var numberFont: Font
    var unitFont: Font
    var numberColor: Color
    var unitColor: Color

    var body: some View {
        let h = minutes / 60, m = minutes % 60
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if h > 0 {
                Text("\(h)").font(numberFont).foregroundStyle(numberColor)
                Text("h").font(unitFont).foregroundStyle(unitColor)
                    .padding(.trailing, 3)
            }
            if m > 0 || h == 0 {
                Text("\(m)").font(numberFont).foregroundStyle(numberColor)
                Text("min").font(unitFont).foregroundStyle(unitColor)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(h > 0 ? "\(h) hours \(m) minutes" : "\(m) minutes")
    }
}

extension WeekSummary {
    fileprivate func count(_ family: MuscleFamily) -> Int { setsByFamily.first { $0.family == family }?.sets ?? 0 }
    /// All five families head to toe, zero counts included.
    fileprivate var allFamilies: [FamilyCount] { MuscleFamily.allCases.map { FamilyCount(family: $0, sets: count($0)) } }
    fileprivate var summaryLabel: String {
        "Sets this week: " + MuscleFamily.allCases.map { "\($0.label) \(count($0))" }.joined(separator: ", ")
    }
}

extension WeekDaySummary {
    fileprivate var trained: Bool { !workouts.isEmpty }
    fileprivate var spoken: String {
        let day = LookFormat.weekday(date)
        if trained { return "\(day), \(workouts.map(\.title).joined(separator: ", ")), \(minutes) minutes" }
        if isToday { return "Today, \(day)" }
        return isFuture ? day : "\(day), no workout"
    }
}

// MARK: - Scoreboard

private struct FloodlightWeek: View {
    var summary: WeekSummary
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This week").font(look.font.sectionTitle).foregroundStyle(look.textPrimary)
            FamilyTallyGroup(counts: summary.allFamilies, mapSize: 56, showsNames: false,
                             appearDelay: 0.24, stagger: 0.06)
                .accessibilityLabel(summary.summaryLabel)
            HStack(spacing: 6) {
                ForEach(Array(summary.days.enumerated()), id: \.element.id) { index, day in
                    DayCell(day: day, index: index, showsMinutes: !typeSize.isAccessibilitySize)
                }
            }
            LookDivider().padding(.top, 2)
            // AX sizes: three rows, number leading and label trailing (A SPEC §9).
            let rows = typeSize.isAccessibilitySize
            let layout = rows ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            layout {
                footerCell(label: "Workouts", row: rows, inset: 2) {
                    CountUpText(summary.workoutCount).font(look.font.statNumber).foregroundStyle(look.textPrimary)
                }
                LookDivider(vertical: !rows)
                footerCell(label: "Time", row: rows, inset: 12) {
                    DurationFigure(minutes: summary.minutes, numberFont: look.font.statNumber,
                                   unitFont: .system(.footnote, weight: .semibold),
                                   numberColor: look.textPrimary, unitColor: look.textSecondary)
                }
                LookDivider(vertical: !rows)
                footerCell(label: "Last week", row: rows, inset: 12) {
                    Text("\(summary.lastWeekWorkoutCount)").font(look.font.statNumber).foregroundStyle(look.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
        .lookSurface(.panel)
    }

    @ViewBuilder
    private func footerCell<V: View>(label: String, row: Bool, inset: CGFloat, @ViewBuilder value: () -> V) -> some View {
        if row {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                value()
                Spacer(minLength: 8)
                Text(label).font(look.font.footnote).foregroundStyle(look.textSecondary)
            }
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                value()
                Text(label).font(look.font.footnote).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, inset)
            .padding(.trailing, 2)
        }
    }
}

/// A scoreboard bulb: lit (white) on a trained day with its minutes.
private struct DayCell: View {
    var day: WeekDaySummary
    var index: Int
    var showsMinutes: Bool
    @State private var lit = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 64

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let on = day.trained && (lit || reduceMotion)
        VStack(alignment: .leading, spacing: 0) {
            Text(day.letter)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(letterColor(on))
            Spacer(minLength: 0)
            if on && showsMinutes {
                Text("\(day.minutes)")
                    .font(look.font.smallNumber)
                    .foregroundStyle(look.onDone)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("min")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(look.onDone.opacity(0.62))
                    .padding(.top, -2)
            }
        }
        .padding(.horizontal, 7).padding(.top, 7).padding(.bottom, 6)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background {
            if on { shape.fill(look.done) } else if !day.isFuture && !day.isToday { shape.fill(look.surfaceRaised) }
        }
        .overlay {
            if day.isToday && !day.trained {
                shape.strokeBorder(look.textPrimary.opacity(0.62), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            } else if day.isFuture {
                shape.strokeBorder(look.hairline, lineWidth: 1)
            }
        }
        .onAppear {
            guard day.trained, !lit else { return }
            if reduceMotion { lit = true; return }
            withAnimation(.easeOut(duration: 0.25).delay(0.1 + Double(index) * 0.12)) { lit = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.spoken)
    }

    private func letterColor(_ on: Bool) -> Color {
        if on { return look.onDone.opacity(0.62) }
        if day.isToday { return look.textPrimary }
        return day.isFuture ? look.textTertiary : look.textSecondary
    }
}
