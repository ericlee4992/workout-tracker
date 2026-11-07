import SwiftUI

// "This week" on Home, one component with three signature treatments:
// A: a scoreboard — five family maps with set counts, seven day cells lit with minutes,
//    and a Workouts · Time · Last week footer divided by hairlines.
// B: lit anatomy — five family maps with counts in family colour, then a week strip of
//    per-day bars (height = minutes, split by family).
// C: a punch card — seven punches, then workouts / time and the week's family stickers.

struct WeekWidget: View {
    var summary: WeekSummary
    @Environment(\.look) private var look

    var body: some View {
        switch look.id {
        case .floodlight: FloodlightWeek(summary: summary)
        case .anatomy: AnatomyWeek(summary: summary)
        case .paper, .carbon: PunchCardWeek(summary: summary)
        }
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
    fileprivate var minutes: Int { workouts.reduce(0) { $0 + $1.minutes } }
    fileprivate var spoken: String {
        let day = Format.weekday(date)
        if trained { return "\(day), \(workouts.map(\.title).joined(separator: ", ")), \(minutes) minutes" }
        if isToday { return "Today, \(day)" }
        return isFuture ? day : "\(day), no workout"
    }
}

// MARK: - A · scoreboard

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
            // PROPOSAL: at AX sizes the strip becomes a list of the days trained (no empty slabs).
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(summary.days.filter { $0.trained }) { day in
                        HStack(alignment: .firstTextBaseline) {
                            Text(Format.weekday(day.date)).font(.system(.body, weight: .semibold))
                            Spacer(minLength: 8)
                            Text("\(day.minutes) min").font(look.font.smallNumber)
                        }
                        .foregroundStyle(look.textPrimary)
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day.spoken)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(summary.days.enumerated()), id: \.element.id) { index, day in
                        DayCell(day: day, index: index, showsMinutes: true)
                    }
                }
            }
            // PROPOSAL: one sentence instead of a three-number strip (and "last week" says what it counts).
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(summary.workoutCount)").font(look.font.smallNumber)
                    Text(summary.workoutCount == 1 ? " workout · " : " workouts · ").font(.system(.subheadline, weight: .semibold))
                    DurationFigure(minutes: summary.minutes, numberFont: look.font.smallNumber,
                                   unitFont: .system(.subheadline, weight: .semibold),
                                   numberColor: look.textPrimary, unitColor: look.textPrimary)
                }
                .foregroundStyle(look.textPrimary)
                Text("Last week: \(summary.lastWeekWorkoutCount) \(summary.lastWeekWorkoutCount == 1 ? "workout" : "workouts")")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .padding(.top, 2)
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
                    .foregroundStyle(look.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("min")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .padding(.top, -2)
            }
        }
        .padding(.horizontal, 7).padding(.top, 7).padding(.bottom, 6)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        // PROPOSAL: a trained day is a tinted tile (not a solid white / black slab); rest days
        // stay flat; today is a solid outline (dashes now mean only "not logged yet").
        .background {
            if on { shape.fill(look.textPrimary.opacity(look.isDark ? 0.17 : 0.09)) }
            else if !day.isFuture && !day.isToday { shape.fill(look.surfaceRaised.opacity(0.6)) }
        }
        .overlay {
            if day.isToday {
                shape.strokeBorder(look.textPrimary, lineWidth: 1.5)
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
        if on { return look.textSecondary }
        if day.isToday { return look.textPrimary }
        return day.isFuture ? look.textTertiary : look.textSecondary
    }
}

// MARK: - B · lit anatomy

private struct AnatomyWeek: View {
    var summary: WeekSummary
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .caption) private var barAreaScaled: CGFloat = 44
    /// Bars grow with Dynamic Type but at most 1.3× (B SPEC §8).
    private var barArea: CGFloat { min(barAreaScaled, 57) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: 8)
                    totals
                }
                VStack(alignment: .leading, spacing: 4) { title; totals }
            }
            .padding(.horizontal, 4)
            FamilyTallyGroup(counts: summary.allFamilies, mapSize: 68, appearDelay: 0.08, stagger: 0.09, spacing: 0)
                .accessibilityLabel(summary.summaryLabel)
            LookDivider().padding(.horizontal, 4)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(summary.days.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 6) {
                        DayBar(day: day, weights: weights, area: barArea, delay: Double(index) * 0.09)
                            .frame(height: barArea, alignment: .bottom)
                        Text(day.letter)
                            .font(day.isToday ? .system(.caption, design: .rounded, weight: .black)
                                  : .system(.caption, weight: .semibold))
                            .foregroundStyle(day.trained || day.isToday ? look.textPrimary : look.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.spoken)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 16)
        .lookSurface(.panel)
    }

    private var title: some View {
        Text("This week").font(look.font.sectionTitle).foregroundStyle(look.textPrimary)
    }
    private var totals: some View {
        let h = summary.minutes / 60, m = summary.minutes % 60
        let time = h > 0 ? "\(h) h \(m) min" : "\(m) min"
        let count = summary.workoutCount
        return Text("\(count) workout\(count == 1 ? "" : "s") · \(time)")
            .font(look.font.subhead).monospacedDigit()
            .foregroundStyle(look.textSecondary)
    }

    /// Per-day split: a day's families weighted by the week's set counts.
    private var weights: [MuscleFamily: Int] {
        Dictionary(uniqueKeysWithValues: summary.setsByFamily.map { ($0.family, max(1, $0.sets)) })
    }
}

private struct DayBar: View {
    var day: WeekDaySummary
    var weights: [MuscleFamily: Int]
    var area: CGFloat
    var delay: Double
    @State private var grown = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if day.trained {
            let height = min(area, max(12, CGFloat(day.minutes) / 60 * area * 0.8))
            let families = MuscleFamily.ordered(day.workouts.flatMap(\.families))
            let total = families.reduce(0) { $0 + (weights[$1] ?? 1) }
            let gaps = CGFloat(max(0, families.count - 1)) * 2
            VStack(spacing: 2) {
                if families.isEmpty {
                    Rectangle().fill(look.textSecondary)
                } else {
                    ForEach(families.reversed()) { family in
                        Rectangle()
                            .fill(look.family(family))
                            .frame(height: (height - gaps) * CGFloat(weights[family] ?? 1) / CGFloat(max(1, total)))
                    }
                }
            }
            .frame(width: 16, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(x: 1, y: grown || reduceMotion ? 1 : 0.01, anchor: .bottom)
            .onAppear {
                guard !grown, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.7).delay(delay)) { grown = true }
            }
        } else if day.isToday {
            Circle().strokeBorder(look.textPrimary, lineWidth: 2).frame(width: 16, height: 16)
        } else {
            Circle()
                .fill(day.isFuture ? look.dayDotFuture : look.dayDotPast)
                .frame(width: 6, height: 6)
                .padding(.bottom, 2)
        }
    }
}

// MARK: - C · punch card

private struct PunchCardWeek: View {
    var summary: WeekSummary
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .caption) private var punch: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("This week").font(look.font.title3).foregroundStyle(look.textPrimary)
                HStack(spacing: 0) {
                    ForEach(summary.days) { day in
                        VStack(spacing: 6) {
                            Text(day.letter)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(day.isToday ? look.actionText : look.textSecondary)
                            Punch(day: day, size: min(punch, 44))
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day.spoken)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
            LookDivider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 14) {
                    figures
                    Spacer(minLength: 4)
                    stickers
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .bottom, spacing: 14) { figures }
                    stickers
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .lookSurface(.panel)
    }

    @ViewBuilder private var figures: some View {
        VStack(alignment: .leading, spacing: 0) {
            CountUpText(summary.workoutCount).font(look.font.statNumber).foregroundStyle(look.textPrimary)
            Text(summary.workoutCount == 1 ? "workout" : "workouts").font(look.font.caption).foregroundStyle(look.textSecondary)
        }
        VStack(alignment: .leading, spacing: 0) {
            DurationFigure(minutes: summary.minutes, numberFont: look.font.statNumber,
                           unitFont: .system(.footnote, weight: .bold),
                           numberColor: look.textPrimary, unitColor: look.textPrimary)
            Text("time").font(look.font.caption).foregroundStyle(look.textSecondary)
        }
    }

    private var stickers: some View {
        HStack(spacing: 4) {
            ForEach(MuscleFamily.allCases) { family in
                FamilySticker(family: family, lit: summary.count(family) > 0, size: 28)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.summaryLabel)
    }
}

private struct Punch: View {
    var day: WeekDaySummary
    var size: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        Group {
            if day.trained {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(look.onDone)
                    .frame(width: size, height: size)
                    .background(look.done, in: Circle())
            } else if day.isToday {
                Circle().strokeBorder(look.actionText, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
            } else if day.isFuture {
                Circle().strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 2.5]))
            } else {
                Circle().strokeBorder(look.textSecondary, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
    }
}
