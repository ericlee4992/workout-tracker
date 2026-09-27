import SwiftUI

// Floodlight redesign ticket 05 — History's own pieces: the month card (three figures over a
// strip of every day), the week lists' panel rows, a workout row, the small marks (new-best
// count, unit badge, Edited) and the empty mark. Ported from the approved prototype
// (`redesign-prototype/…/Screens/History/`), Floodlight only, over the real models.

// MARK: - Type

extension Look {
    /// Workout row titles (Headline class, the look's display face).
    var historyRowTitle: Font {
        switch id {
        case .floodlight: Font.system(.headline, weight: .heavy).width(.expanded)
        case .paper, .carbon: .system(.headline, design: .serif, weight: .heavy)
        }
    }

    /// The day number in a row's date column.
    var historyDayNumber: Font { Font.system(.title3, weight: .heavy).width(.expanded).monospacedDigit() }

    /// A figure inside a row (volume, distance, a set's value).
    var historyRowNumber: Font { Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit() }

    /// Small labels under figures ("Workouts", "lb").
    var historyFigureLabel: Font { .system(.footnote, weight: id == .floodlight ? .regular : .semibold) }
}

// MARK: - Formatting

enum HistoryFormat {
    private static func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
    private static let dayF = formatter("d")
    private static let weekdayShortF = formatter("EEE")
    private static let monthF = formatter("MMMM")
    private static let monthYearF = formatter("MMMyyyy")
    private static let hoursF: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()

    /// "21"
    static func dayNumber(_ date: Date) -> String { dayF.string(from: date) }
    /// "Mon"
    static func weekdayShort(_ date: Date) -> String { weekdayShortF.string(from: date) }
    /// "September"
    static func month(_ date: Date) -> String { monthF.string(from: date) }
    /// "Sep 2026"
    static func monthYear(_ date: Date) -> String { monthYearF.string(from: date) }
    /// "Saturday, Sep 19"
    static func dayTitle(_ date: Date) -> String { "\(LookFormat.weekday(date)), \(LookFormat.shortDate(date))" }
    /// "Sat, Sep 19"
    static func shortDayTitle(_ date: Date) -> String { "\(weekdayShort(date)), \(LookFormat.shortDate(date))" }
    /// "6:40 PM"
    static func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    /// "10:30 AM – 11:37 AM"
    static func timeRange(_ start: Date, _ end: Date?) -> String {
        guard let end else { return time(start) }
        return "\(time(start)) – \(time(end))"
    }
    /// "7.9" — hours as one number for a big figure beside a small "h".
    static func hoursNumber(_ hours: Double) -> String {
        hoursF.string(from: hours as NSNumber) ?? String(format: "%.1f", hours)
    }
    /// "9 workouts", "1 workout"
    static func workouts(_ n: Int) -> String { HistoryRendering.pluralized(n, "workout", "workouts") }
    /// "12 workouts · 180 sets · 9.5 h"
    static func monthLine(_ summary: HistoryMonthSummary) -> String {
        [workouts(summary.workouts), HistoryRendering.pluralized(summary.sets, "set", "sets"),
         "\(hoursNumber(summary.hours)) h"].joined(separator: " · ")
    }
    /// "3.1" — a distance in its unit, ≤ 2 decimals.
    static func distance(_ distance: HistoryDistance) -> String { LookFormat.number(distance.value) }
    /// "7 hours 54 minutes" (VoiceOver for the Time figure).
    static func spokenHours(seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes / 60) hours \(minutes % 60) minutes"
    }
}

// MARK: - Panel rows (a list section drawn as one Floodlight panel)

extension View {
    /// A `List` row drawn as one segment of a panel: the first row rounds the top, the last the
    /// bottom, and rows after the first carry a hairline inset past `separatorInset` (nil: no
    /// hairline). Keeps the row a native list row, so its swipe actions still work.
    func historyPanelRow(first: Bool, last: Bool, separatorInset: CGFloat? = 16) -> some View {
        modifier(HistoryPanelRowModifier(first: first, last: last, separatorInset: separatorInset))
    }

    /// A `List` row that is not in a panel: the page margin, no background, no separator.
    func historyPageRow(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private struct HistoryPanelRowModifier: ViewModifier {
    var first: Bool
    var last: Bool
    var separatorInset: CGFloat?
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(
                HistoryPanelSegment(first: first, last: last, separatorInset: separatorInset,
                                    fill: onSheet ? look.surfaceSheet : look.surface,
                                    edge: look.hairline, radius: look.radius.panel)
                    .padding(.horizontal, 20))
    }
}

/// One row's slice of a panel: its fill, the panel's hairline edge (open where it joins the
/// next row) and the separator above it.
struct HistoryPanelSegment: View {
    var first: Bool
    var last: Bool
    var separatorInset: CGFloat?
    var fill: Color
    var edge: Color
    var radius: CGFloat

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: first ? radius : 0, bottomLeadingRadius: last ? radius : 0,
            bottomTrailingRadius: last ? radius : 0, topTrailingRadius: first ? radius : 0,
            style: .continuous)
        shape.fill(fill)
            .overlay { SegmentEdge(first: first, last: last, radius: radius).stroke(edge, lineWidth: 1) }
            .overlay(alignment: .top) {
                if !first, let separatorInset {
                    Rectangle().fill(edge).frame(height: 1).padding(.leading, separatorInset)
                }
            }
    }

    /// The panel's outline for one slice: both sides, plus the rounded top on the first slice
    /// and the rounded bottom on the last, so stacked slices draw one continuous edge.
    private struct SegmentEdge: Shape {
        var first: Bool
        var last: Bool
        var radius: CGFloat

        func path(in full: CGRect) -> Path {
            let r = full.insetBy(dx: 0.5, dy: 0)
            let top = first ? r.minY + 0.5 : r.minY
            let bottom = last ? r.maxY - 0.5 : r.maxY
            let radius = min(self.radius, r.width / 2, (bottom - top) / 2)
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: last ? bottom - radius : bottom))
            if first {
                p.addLine(to: CGPoint(x: r.minX, y: top + radius))
                p.addArc(tangent1End: CGPoint(x: r.minX, y: top), tangent2End: CGPoint(x: r.minX + radius, y: top), radius: radius)
                p.addLine(to: CGPoint(x: r.maxX - radius, y: top))
                p.addArc(tangent1End: CGPoint(x: r.maxX, y: top), tangent2End: CGPoint(x: r.maxX, y: top + radius), radius: radius)
            } else {
                p.addLine(to: CGPoint(x: r.minX, y: top))
                p.move(to: CGPoint(x: r.maxX, y: top))
            }
            p.addLine(to: CGPoint(x: r.maxX, y: last ? bottom - radius : bottom))
            if last {
                p.addArc(tangent1End: CGPoint(x: r.maxX, y: bottom), tangent2End: CGPoint(x: r.maxX - radius, y: bottom), radius: radius)
                p.addLine(to: CGPoint(x: r.minX + radius, y: bottom))
                p.addArc(tangent1End: CGPoint(x: r.minX, y: bottom), tangent2End: CGPoint(x: r.minX, y: bottom - radius), radius: radius)
            }
            return p
        }
    }
}

// MARK: - Month card

/// The month's figures (Workouts · Sets · Time) over its day strip, one scoreboard panel
/// divided by hairlines. The strip opens the calendar. AX sizes: the figures stack as rows.
struct HistoryMonthCard: View {
    var summary: HistoryMonthSummary
    var days: [HistoryDay]
    var onOpenCalendar: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(HistoryFormat.month(summary.month))
            VStack(alignment: .leading, spacing: 0) {
                figures
                LookDivider()
                Button(action: onOpenCalendar) {
                    HistoryMonthStrip(days: days)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.lookPressable)
                .accessibilityHint("Opens the calendar")
                .accessibilityIdentifier("historyMonthStrip")
            }
            .lookSurface(.panel)
        }
    }

    @ViewBuilder private var figures: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            cell("Workouts", stacked: stacked) {
                CountUpText(summary.workouts).font(look.font.bigNumber).foregroundStyle(look.textPrimary)
            }
            LookDivider(vertical: !stacked)
            cell("Sets", stacked: stacked) {
                CountUpText(summary.sets).font(look.font.bigNumber).foregroundStyle(look.textPrimary)
            }
            LookDivider(vertical: !stacked)
            cell("Time", stacked: stacked) {
                // "7.9 h": one number fits the scoreboard column ("7 h 54 min" does not).
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(HistoryFormat.hoursNumber(summary.hours))
                        .font(look.font.bigNumber)
                        .foregroundStyle(look.textPrimary)
                    Text("h")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(look.textSecondary)
                }
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(HistoryFormat.spokenHours(seconds: summary.seconds))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func cell<V: View>(_ label: String, stacked: Bool, @ViewBuilder value: () -> V) -> some View {
        if stacked {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                value()
                Spacer(minLength: 8)
                Text(label).font(look.historyFigureLabel).foregroundStyle(look.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                value()
                Text(label).font(look.historyFigureLabel).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.vertical, 14)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Every day of the month in one row, week-spaced: a bulb per day, lit brighter with more
/// sets; today dashed, future days outlined. Week starts carry their day number.
struct HistoryMonthStrip: View {
    var days: [HistoryDay]
    @State private var shown = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var cellHeight: CGFloat = 30
    @ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 13

    var body: some View {
        let on = shown || reduceMotion
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 6) {
                    bulb(day, index: index, on: on)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(cellHeight, 40), alignment: .bottom)
                    // An overlay, so a label never widens its column.
                    Color.clear
                        .frame(height: labelHeight)
                        .overlay(alignment: .top) {
                            if index == 0 || day.isWeekStart {
                                Text("\(day.dayNumber)")
                                    .font(.system(.caption2, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(look.textTertiary)
                                    .fixedSize()
                            }
                        }
                }
                .padding(.leading, day.isWeekStart && index > 0 ? 3 : 0)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onAppear {
            guard !shown else { return }
            if reduceMotion { shown = true; return }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { shown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        guard let first = days.first else { return "" }
        let month = HistoryFormat.month(first.date)
        let trained = days.filter { $0.intensity > 0 }
        if trained.isEmpty { return "\(month), no workouts yet" }
        return "\(month), trained on " + trained.map { "\($0.dayNumber)" }.joined(separator: ", ")
    }

    private func bulb(_ day: HistoryDay, index: Int, on: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        let levels: [Double] = [0, 0.42, 0.62, 0.82, 1]
        return shape
            .fill(day.intensity > 0 ? look.done.opacity(on ? levels[min(4, day.intensity)] : 0.08)
                  : (day.isFuture || day.isToday ? Color.clear : look.surfaceRaised))
            .overlay {
                if day.isToday && day.intensity == 0 {
                    shape.strokeBorder(look.textPrimary.opacity(0.62), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
                } else if day.isFuture {
                    shape.strokeBorder(look.hairline, lineWidth: 1)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22).delay(Double(index) * 0.018), value: on)
    }
}

/// An older month opens with its name and totals in one line.
struct HistoryMonthBreak: View {
    var summary: HistoryMonthSummary
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(HistoryFormat.month(summary.month))
                .font(look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(HistoryFormat.monthLine(summary))
                .font(look.font.subhead)
                .monospacedDigit()
                .foregroundStyle(look.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A week's heading: its title, and its workout count.
struct HistoryWeekHeader: View {
    var title: String
    var count: Int
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(look.font.headline)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(HistoryFormat.workouts(count))
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Workout row

enum HistoryRowDateStyle {
    /// The day tile (the day's first workout).
    case shown
    /// Another workout the same day: the column stays, empty.
    case continued
    /// No column (the calendar's selected day).
    case hidden
}

/// One finished workout in a list: date column · title, "6:40 PM · 55 min · 14 sets", then
/// the families trained with the marks (new bests, unit, Edited) · trailing the volume in the
/// app unit (cardio only: the distance). AX sizes: one column, the figure inline.
struct HistoryWorkoutRow: View {
    var workout: Workout
    var facts: HistoryWorkoutFacts?
    var appUnit: WeightUnit
    var dateStyle: HistoryRowDateStyle = .shown
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var dateColumn: CGFloat = 40

    private var isCardioOnly: Bool { facts.map { !$0.hasLifting && $0.hasCardio } ?? false }
    private var unitBadge: String? { facts?.unitBadge(appUnit: appUnit) }
    private var families: [MuscleFamily] { facts?.families ?? [] }
    private var newBests: Int { facts?.newBests ?? 0 }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { stacked } else { standard }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // No combined label of its own: the row's button reads its texts in order (title, date,
        // times and sets, the marks' own labels), and each stays findable on its own.
    }

    private var standard: some View {
        HStack(alignment: .top, spacing: 14) {
            switch dateStyle {
            case .shown: dateBlock.frame(width: dateColumn, alignment: .leading)
            case .continued: Color.clear.frame(width: dateColumn, height: 1)
            case .hidden: EmptyView()
            }
            VStack(alignment: .leading, spacing: 5) {
                title
                meta
                if hasMarks { marks.padding(.top, 2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dateStyle == .shown {
                Text("\(HistoryFormat.weekdayShort(workout.startedAt)) \(HistoryFormat.dayNumber(workout.startedAt))")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
            }
            title
            meta
            trailing
            if hasMarks { marks }
        }
    }

    private var dateBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(HistoryFormat.dayNumber(workout.startedAt))
                .font(look.historyDayNumber)
                .foregroundStyle(look.textPrimary)
            Text(HistoryFormat.weekdayShort(workout.startedAt))
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
    }

    private var title: some View {
        Text(workout.historyTitle)
            .font(look.historyRowTitle)
            .foregroundStyle(look.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "6:40 PM · 55 min · 14 sets"; cardio only: the distance instead of sets.
    private var metaText: String {
        var parts = [HistoryFormat.time(workout.startedAt)]
        if let duration = workout.durationLabel { parts.append(duration) }
        if let facts, facts.hasLifting {
            parts.append(HistoryRendering.pluralized(facts.sets, "set", "sets"))
        } else if let segment = workout.recordedCardio.first, let meters = segment.distanceMeters,
                  !segment.activity.usesSpeed {
            // Cardio only: the pace (the distance is the trailing figure).
            let seconds = segment.activeDuration(at: segment.endedAt ?? segment.lastCheckpointAt)
            let pace = CardioMath.paceText(CardioMath.pace(seconds: seconds, meters: meters, unit: segment.unit))
            parts.append("\(pace) /\(segment.unit.rawValue)")
        }
        return parts.joined(separator: " · ")
    }

    private var meta: some View {
        Text(metaText)
            .font(look.font.footnote)
            .monospacedDigit()
            .foregroundStyle(look.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var hasMarks: Bool {
        !families.isEmpty || newBests > 0 || unitBadge != nil || workout.historyEditedAt != nil
            || (facts.map { $0.hasLifting && $0.hasCardio } ?? false)
    }

    private var marks: some View {
        WrapLayout(spacing: 8, lineSpacing: 6) {
            if !families.isEmpty {
                FamilyStrip(families: families, size: 28, spacing: 1)
            }
            if let facts, facts.hasLifting, let segment = workout.recordedCardio.first {
                HStack(spacing: 3) {
                    Image(systemName: segment.activity.symbol).font(.system(.caption, weight: .semibold))
                    if let distance = facts.distance {
                        Text("\(HistoryFormat.distance(distance)) \(distance.unit.rawValue)")
                            .font(.system(.caption, weight: .semibold).monospacedDigit())
                    }
                }
                .foregroundStyle(look.textSecondary)
                .fixedSize()
            }
            if newBests > 0 { HistoryPRMark(count: newBests) }
            if let unitBadge { HistoryTextBadge(unitBadge) }
            if workout.historyEditedAt != nil { HistoryEditedMark() }
        }
    }

    @ViewBuilder private var trailing: some View {
        if isCardioOnly, let distance = facts?.distance {
            figure(HistoryFormat.distance(distance), distance.unit.rawValue)
        } else if let volume = facts?.volumeKg, volume > 0 {
            figure(volumeText(volume), appUnit.rawValue)
        }
    }

    /// The row's glance figure: whole units, grouped ("24,136"). A mixed-unit workout converts
    /// to fractions ("4,907.01") that the detail's tile keeps (D25); a list row rounds.
    private func volumeText(_ kg: Double) -> String {
        LookFormat.grouped(WeightMath.convert(kg, from: .kg, to: appUnit))
    }

    /// The number over its unit; at accessibility sizes inline ("24,136 lb").
    private func figure(_ value: String, _ unit: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 4))
            : AnyLayout(VStackLayout(alignment: .trailing, spacing: 0))
        return layout {
            Text(value).font(look.historyRowNumber).foregroundStyle(look.textPrimary)
            Text(unit).font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
        }
        .fixedSize()
    }

}

// MARK: - Marks

/// "New bests in this workout": an outlined plate with a burst and the count.
struct HistoryPRMark: View {
    var count: Int
    @Environment(\.look) private var look

    var body: some View {
        Group {
            switch look.id {
            case .floodlight:
                HStack(spacing: 3) {
                    Image(systemName: "burst.fill").font(.system(.caption2, weight: .bold))
                    Text("\(count)").font(.system(.caption, weight: .heavy).monospacedDigit())
                }
                .foregroundStyle(look.positive)
                .padding(.horizontal, 6)
                .frame(minHeight: 20)
                .overlay {
                    RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous)
                        .strokeBorder(look.positive, lineWidth: 1.5)
                }
            case .paper, .carbon:
                Text(count == 1 ? "New best" : "\(count) new bests")
                    .font(look.font.badge)
                    .foregroundStyle(look.onPositive)
                    .padding(.horizontal, 6).padding(.top, 1).padding(.bottom, 2)
                    .background(look.positive, in: RoundedRectangle(cornerRadius: look.radius.badge, style: .continuous))
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "1 new best" : "\(count) new bests")
    }
}

/// A quiet text badge: the unit ("kg", "kg + lb") or a load type ("Assisted").
struct HistoryTextBadge: View {
    var text: String
    @Environment(\.look) private var look

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.caption, weight: .bold))
            .foregroundStyle(look.textSecondary)
            .padding(.horizontal, 7)
            .frame(minHeight: 20)
            .overlay { Capsule().strokeBorder(look.textTertiary, lineWidth: 1) }
            .fixedSize()
    }
}

/// "Edited" (D47) on a row.
struct HistoryEditedMark: View {
    @Environment(\.look) private var look
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "pencil.circle").font(.system(.caption, weight: .semibold))
            Text("Edited").font(.system(.caption, weight: .medium))
        }
        .foregroundStyle(look.textSecondary)
        .fixedSize()
    }
}

// MARK: - Empty

/// "Nothing yet": an unlit segmented ring around the History symbol.
struct HistoryEmptyMark: View {
    var size: CGFloat = 132
    @Environment(\.look) private var look

    var body: some View {
        ZStack {
            let width = size * 0.075
            ForEach(0..<24, id: \.self) { index in
                let step = 1.0 / 24
                RingArc(start: Double(index) * step + step * 0.14, end: Double(index + 1) * step - step * 0.14)
                    .stroke(look.ringTrack, style: StrokeStyle(lineWidth: width))
            }
            .padding(width / 2)
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(look.textTertiary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
