import SwiftUI

// Pieces of the Workout tab (Floodlight redesign; the prototype's Screens/Workout). They take
// plain values; the screen owns the data.

enum WorkoutDates {
    /// Home's date line: "Thursday, Sep 24".
    static func homeSubtitle(_ date: Date) -> String { subtitle.string(from: date) }

    private static let subtitle: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return f
    }()
}

// MARK: - Resume capsule

/// While a workout is minimised the Start pair becomes ONE capsule: the activity disc,
/// "Resume workout", what is running, and the running clock led by a live pulse.
struct WorkoutResumeCapsule: View {
    var symbol: String
    var detail: String
    var startedAt: Date
    /// The workout's time at a date (`Workout.trainingSeconds`, ticket 17).
    var elapsedAt: (Date) -> TimeInterval
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var disc: CGFloat = 44
    @ScaledMetric(relativeTo: .headline) private var dot: CGFloat = 9
    @State private var taps = 0

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = max(0, Int(elapsedAt(context.date)))
            Button {
                taps += 1
                action()
            } label: {
                Group {
                    if typeSize.isAccessibilitySize {
                        HStack(alignment: .center, spacing: 12) {
                            IconDisc(symbol: symbol, size: disc, context: .onAction)
                            VStack(alignment: .leading, spacing: 4) {
                                title
                                detailText
                                clock(elapsed)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                    } else {
                        HStack(spacing: 10) {
                            IconDisc(symbol: symbol, size: disc, context: .onAction)
                            VStack(alignment: .leading, spacing: 1) {
                                title
                                detailText
                            }
                            Spacer(minLength: 8)
                            clock(elapsed)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(look.onAction)
            }
            .buttonStyle(StartCapsuleStyle())
            .sensoryFeedback(.impact(weight: .heavy), trigger: taps)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Resume workout")
            .accessibilityValue("\(detail), \(LookFormat.spokenElapsed(elapsed))")
            .accessibilityAddTraits(.isButton)
        }
    }

    private var title: some View {
        Text("Resume workout")
            .font(look.font.button)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var detailText: some View {
        Text(detail)
            .font(.system(.footnote, weight: .semibold))
            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
    }

    private func clock(_ elapsed: Int) -> some View {
        HStack(spacing: 8) {
            WorkoutLivePulse(color: look.onAction, size: dot)
            Text(LookFormat.elapsed(elapsed))
                .font(look.font.statNumber)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - Live dot

/// The minimised workout's live pulse: a dot with a ring that ripples out.
/// Reduce Motion: a still dot.
struct WorkoutLivePulse: View {
    var color: Color
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripple = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .stroke(color, lineWidth: max(1.5, size * 0.22))
                    .scaleEffect(ripple ? 2.4 : 1)
                    .opacity(ripple ? 0 : 0.8)
            }
            Circle().fill(color)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { ripple = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Make rows

/// A "make one" row: the disc and the label inside a dashed outline (the AX-size and first-run
/// forms of New Template… and Ask AI for Templates).
struct WorkoutMakeRow: View {
    var title: String
    var symbol: String = "plus"
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 56

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconDisc(symbol: symbol, size: disc, context: .make)
                    .background { Circle().fill(look.surfaceRaised) }
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
            }
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .dashedOutline(look.dash, radius: 14)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(title)
    }
}

// MARK: - First-run template invitation

/// "New Template…" as a dashed make-one card carrying the five family maps, unlit: the
/// picture a template tile will light up. One action.
struct WorkoutTemplateInvite: View {
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 40

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 0) {
                    ForEach(MuscleFamily.allCases) { family in
                        FamilySticker(family: family, lit: false, size: 50)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
                HStack(spacing: 12) {
                    IconDisc(symbol: "plus", size: disc, context: .make)
                        .background { Circle().fill(look.surfaceRaised) }
                    Text("New Template…")
                        .font(look.font.button)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashedOutline(look.dash, radius: look.radius.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("New Template…")
    }
}

// MARK: - First-run week

/// Before any workout exists the week is not a scoreboard of zeros: seven quiet day cells and
/// today's, dashed and breathing, waiting for the first workout. Reduce Motion: still.
struct WorkoutFirstWeekCard: View {
    var days: [WeekDaySummary]
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var cellHeight: CGFloat = 52
    @State private var breathe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This week")
                .font(look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                ForEach(days) { day in
                    cell(day)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day.isToday ? "Today, \(LookFormat.weekday(day.date))" : LookFormat.weekday(day.date))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private func cell(_ day: WeekDaySummary) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Text(day.letter)
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(day.isToday ? look.textPrimary : look.textTertiary)
            .padding(.horizontal, 7).padding(.top, 7)
            .frame(maxWidth: .infinity, minHeight: cellHeight, alignment: .topLeading)
            .background { if !day.isToday { shape.fill(look.surfaceRaised.opacity(day.isFuture ? 0.55 : 1)) } }
            .overlay {
                if day.isToday {
                    shape.strokeBorder(look.textPrimary.opacity(breathe ? 0.9 : 0.5),
                                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
    }
}

// MARK: - Soft redesign S3: Train's lead

/// The template due next (`TemplateStats.dueNext`) as Train's one decision: its name, the families it trains, its
/// exercises on one line, when it was last done, and ONE Start (the prototype's `ProposedUpNextCard`). The header
/// opens the template; Start runs the same flow as the template's own Start.
struct TrainUpNextCard: View {
    var name: String
    var families: [MuscleFamily]
    var exercises: [String]
    var lastRun: Date?
    var averageSeconds: Int?
    var startSubtitle: String?
    var open: () -> Void
    var start: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Up next").font(look.font.footnote.weight(.medium)).foregroundStyle(look.textSecondary)
                            Text(name)
                                .font(look.font.title)
                                .foregroundStyle(look.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(look.textTertiary)
                    }
                    if !families.isEmpty {
                        FamilyStrip(families: families, size: typeSize.isAccessibilitySize ? 40 : 34, spacing: 4)
                    }
                    if !exercises.isEmpty {
                        Text(exerciseLine)
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                            .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let lastLine {
                        Label(lastLine, systemImage: "clock.arrow.circlepath")
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the template")
            // The same identifier as the template's tile: the template is shown once, as this card or as a tile.
            .accessibilityIdentifier("templateTile.\(name)")

            TemplateStartCapsule(subtitle: startSubtitle, action: start)
                .accessibilityIdentifier("startUpNext")
        }
        .padding(16)
        .lookSurface(.panel)
    }

    /// Up to three names, then "+N"; every name at AX sizes.
    private var exerciseLine: String {
        if typeSize.isAccessibilitySize || exercises.count <= 3 { return exercises.joined(separator: " · ") }
        return exercises.prefix(3).joined(separator: " · ") + " · +\(exercises.count - 3)"
    }

    private var lastLine: String? {
        guard let lastRun else { return nil }
        var parts = ["Last done \(look.lastDoneLabel(lastRun, now: .now))"]
        if let averageSeconds { parts.append("about \(averageSeconds / 60) min") }
        return parts.joined(separator: " · ")
    }
}

/// Start Lifting / Start Cardio one step quieter than the template's Start, when a template leads.
struct TrainQuickStarts: View {
    var startLifting: () -> Void
    var startCardio: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            Button(action: startLifting) {
                Label("Start Lifting", systemImage: "figure.strengthtraining.traditional")
            }
            .buttonStyle(.lookSecondary)
            .accessibilityIdentifier("startEmptyWorkout")
            Button(action: startCardio) {
                Label("Start Cardio", systemImage: "figure.run")
            }
            .buttonStyle(.lookSecondary)
            .accessibilityIdentifier("startCardio")
        }
    }
}

/// New Template… / Ask AI as plain card rows below the templates (the prototype's `ProposedMakeRow`).
struct TrainMakeRow: View {
    var title: String
    var symbol: String
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 56

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconDisc(symbol: symbol, size: 32, context: .onSurface)
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .lookSurface(.card)
        .accessibilityLabel(title)
    }
}
