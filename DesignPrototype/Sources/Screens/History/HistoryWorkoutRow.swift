import SwiftUI

// One finished workout in a list (History, the calendar's selected day). A list row, not a
// card: date column · title, time/duration/sets, then the families trained with the marks
// (new bests, unit, Edited) · a trailing figure (volume, or distance) or the route thumbnail.

struct HistoryWorkoutRow: View {
    var workout: Workout
    var dateStyle: HistoryRowDateStyle = .shown
    var action: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var dateColumn: CGFloat = 40
    @ScaledMetric(relativeTo: .headline) private var thumb: CGFloat = 54

    private var families: [MuscleFamily] { store.families(ofWorkout: workout.id) }
    private var prCount: Int { store.newBestCount(workoutID: workout.id) }
    private var volumeKg: Double { Derived.volumeKg(of: workout) }
    private var route: [RoutePoint]? { workout.cardio.first(where: \.hasRoute)?.route }
    private var isCardioOnly: Bool { !workout.hasLifting && workout.hasCardio }

    /// The unit badge only when it tells something ("kg + lb", or a unit that is not the app's).
    private var unitBadge: String? { workout.historyUnitBadge(appUnit: store.displayUnit) }

    var body: some View {
        Button(action: action) {
            Group {
                if typeSize.isAccessibilitySize { stacked } else { standard }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(HistoryRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Layouts

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

    // MARK: Pieces

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
        Text(workout.title)
            .font(look.historyRowTitle)
            .foregroundStyle(look.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var metaText: String {
        var parts = [Format.time(workout.startedAt), Format.minutes(workout.durationSeconds)]
        if workout.hasLifting {
            parts.append(Format.count(workout.setCount, "set"))
        } else if let segment = workout.cardio.first {
            if route != nil, let distance = HistoryFormat.distance(workout) {
                parts.append(Format.distanceLabel(meters: distance.meters, distance.unit))
            } else if let pace = HistoryFormat.paceOrSpeed(segment) {
                parts.append("\(pace.value) \(pace.unit)")
            }
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
        !families.isEmpty || prCount > 0 || unitBadge != nil || workout.isEdited || (workout.hasLifting && workout.hasCardio)
    }

    private var marks: some View {
        HistoryFlowLayout(spacing: 8, lineSpacing: 6) {
            if !families.isEmpty {
                FamilyStrip(families: families, size: 28, spacing: look.id.isPaperClub ? 3 : 1)
            }
            if workout.hasLifting, let segment = workout.cardio.first {
                HStack(spacing: 3) {
                    Image(systemName: segment.activity.symbol).font(.system(.caption, weight: .semibold))
                    if let distance = HistoryFormat.distance(workout) {
                        Text(Format.distanceLabel(meters: distance.meters, distance.unit))
                            .font(.system(.caption, weight: .semibold).monospacedDigit())
                    }
                }
                .foregroundStyle(look.id == .anatomy ? look.heartRate : look.textSecondary)
                .fixedSize()
            }
            if prCount > 0 { HistoryPRMark(count: prCount) }
            if let unitBadge { HistoryTextBadge(unitBadge) }
            if workout.isEdited { HistoryEditedMark() }
        }
    }

    @ViewBuilder private var trailing: some View {
        if isCardioOnly, let route {
            HistoryRouteMap(route: route, lineWidth: 2.4, inset: 7)
                .frame(width: thumb, height: thumb)
                .background(look.id.isPaperClub ? look.ground : look.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: look.radius.field, style: .continuous))
                .overlay {
                    if look.id.isPaperClub {
                        RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                            .strokeBorder(look.hairline, lineWidth: 1.5)
                    }
                }
        } else if isCardioOnly, let distance = HistoryFormat.distance(workout) {
            figure(Format.distance(meters: distance.meters, distance.unit), distance.unit.label)
        } else if volumeKg > 0 {
            figure(Format.volumeNumber(kilograms: volumeKg, in: store.displayUnit), store.displayUnit.label)
        }
    }

    /// Trailing: the number over its unit. At accessibility sizes it reads inline ("24,136 lb").
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

    private var spoken: String {
        var parts = [workout.title, HistoryFormat.dayTitle(workout.startedAt), metaText]
        if volumeKg > 0 { parts.append(Format.volume(kilograms: volumeKg, in: store.displayUnit)) }
        if !families.isEmpty { parts.append(families.map(\.label).joined(separator: ", ")) }
        if prCount > 0 { parts.append(prCount == 1 ? "1 new best" : "\(prCount) new bests") }
        if let unitBadge { parts.append(unitBadge == "kg + lb" ? "kilograms and pounds" : unitBadge) }
        if workout.isEdited { parts.append("Edited") }
        return parts.joined(separator: ", ")
    }
}

enum HistoryRowDateStyle {
    /// The day tile (the day's first workout).
    case shown
    /// Another workout the same day: the column stays, empty.
    case continued
    /// No column (the calendar's selected day).
    case hidden
}

/// Rows highlight with the pressed fill (no scale, so lists don't wobble).
struct HistoryRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.pressedFill : Color.clear)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A grouped list surface: rows divided by hairlines (inset past the date column). Navigable
/// rows make it pressable in C (its 2 pt outline).
struct HistoryListPanel<Content: View>: View {
    var separatorInset: CGFloat = 16
    @ViewBuilder var content: Content
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet

    init(separatorInset: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.separatorInset = separatorInset
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                    if index > 0 { LookDivider().padding(.leading, separatorInset) }
                    subview
                }
            }
        }
        .background(look.historyCardFill(onSheet: onSheet))
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.tile)
    }
}
