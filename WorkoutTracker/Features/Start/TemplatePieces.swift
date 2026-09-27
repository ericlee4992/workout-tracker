import SwiftUI

// Pieces of the template detail (Floodlight redesign; the prototype's Screens/Templates).

// MARK: - Start capsule

/// The template's Start: the icon-disc capsule, full width, with what starts where. With
/// `startedAt` it is the running workout's Resume capsule, ending in a live pulse and the clock.
struct TemplateStartCapsule: View {
    var title = "Start"
    var subtitle: String?
    var startedAt: Date?
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var disc: CGFloat = 44
    @State private var taps = 0

    var body: some View {
        TimelineView(.periodic(from: startedAt ?? .now, by: 1)) { context in
            let elapsed = startedAt.map { max(0, Int(context.date.timeIntervalSince($0))) }
            Button {
                taps += 1
                action()
            } label: {
                HStack(spacing: 10) {
                    IconDisc(symbol: "figure.strengthtraining.traditional", size: disc, context: .onAction)
                    if typeSize.isAccessibilitySize, let elapsed {
                        // AX sizes (Resume): the title gets the full width; the clock and the
                        // sets count share the second line.
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(look.font.button).fixedSize(horizontal: false, vertical: true)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                clock(elapsed)
                                if let subtitle {
                                    Text(subtitle).font(.system(.footnote, weight: .semibold))
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title).font(look.font.button)
                            // AX sizes: the pinned Start stays one line tall (VoiceOver reads the subtitle).
                            if let subtitle, !typeSize.isAccessibilitySize {
                                Text(subtitle).font(.system(.footnote, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        if let elapsed { clock(elapsed) }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(look.onAction)
                .opacity(isEnabled ? 1 : 0.5)
            }
            .buttonStyle(StartCapsuleStyle())
            .sensoryFeedback(.impact(weight: .heavy), trigger: taps)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue([subtitle, elapsed.map(LookFormat.spokenElapsed)].compactMap { $0 }.joined(separator: ", "))
            .accessibilityAddTraits(.isButton)
        }
    }

    private func clock(_ elapsed: Int) -> some View {
        HStack(spacing: 8) {
            WorkoutLivePulse(color: look.onAction, size: 9)
            Text(LookFormat.elapsed(elapsed))
                .font(look.font.statNumber)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - Stats

/// Times run · Last run · Avg. time: one scoreboard panel split by hairlines, numbers big and
/// labels small. AX sizes: one panel of rows (label leading, value trailing).
struct TemplateStatsPanel: View {
    var stats: TemplateStats
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                row("Times run") { timesRun }
                if let last = stats.lastRun { LookDivider(); row("Last run") { lastRun(last) } }
                if let avg = stats.averageDurationSeconds { LookDivider(); row("Avg. time") { average(avg) } }
            }
            .lookSurface(.stat)
        } else {
            HStack(spacing: 0) {
                cell("Times run", symbol: "arrow.clockwise") { timesRun }
                if let last = stats.lastRun {
                    LookDivider(vertical: true)
                    cell("Last run", symbol: "clock.arrow.circlepath") { lastRun(last) }
                }
                if let avg = stats.averageDurationSeconds {
                    LookDivider(vertical: true)
                    cell("Avg. time", symbol: "timer") { average(avg) }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .lookSurface(.stat)
        }
    }

    private var unitFont: Font { .system(.subheadline, weight: .semibold) }

    private var timesRun: some View {
        Text("\(stats.timesRun)")
            .font(look.font.bigNumber)
            .monospacedDigit()
            .foregroundStyle(look.textPrimary)
            .contentTransition(.numericText())
    }

    private func lastRun(_ date: Date) -> some View {
        Text(look.lastDoneLabel(date, now: .now))
            .font(look.font.statNumber)
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func average(_ seconds: Int) -> some View {
        DurationFigure(minutes: max(1, seconds / 60), numberFont: look.font.bigNumber, unitFont: unitFont,
                       numberColor: look.textPrimary, unitColor: look.textSecondary)
    }

    private func cell<V: View>(_ label: String, symbol: String, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: symbol).font(.system(.caption, weight: .semibold))
                Text(label).font(.system(.footnote)).lineLimit(1)
            }
            .foregroundStyle(look.textSecondary)
            value()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func row<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(look.font.subhead).foregroundStyle(look.textSecondary)
            Spacer(minLength: 12)
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Superset marks

/// "A" / "B": a superset member's position, as a small outlined letter tag.
struct TemplateSupersetTag: View {
    var letter: String
    @Environment(\.look) private var look

    var body: some View {
        Text(letter)
            .font(.system(.caption, weight: .heavy))
            .foregroundStyle(look.textPrimary)
            .frame(minWidth: 22, minHeight: 20)
            .background { RoundedRectangle(cornerRadius: 5).strokeBorder(look.textPrimary, lineWidth: 1.5) }
            .accessibilityLabel("Superset position \(letter)")
    }
}

/// The filled chain link on the seam between two superset members. Decorative (the A/B tags
/// carry the meaning for VoiceOver).
struct TemplateLinkSeal: View {
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 24

    var body: some View {
        Image(systemName: "link")
            .font(.system(size: side * 0.46, weight: .heavy))
            .foregroundStyle(look.onDone)
            .frame(width: side, height: side)
            .background { Circle().fill(look.done) }
            .accessibilityHidden(true)
    }
}

// MARK: - Editor pieces

/// A dashed "make one" row inside the editor: Add Exercise, Add Cardio Target.
struct TemplateMakeRow: View {
    var title: String
    var symbol: String = "plus"
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 52

    var body: some View {
        let radius = look.radius.row + 2
        Button(action: action) {
            HStack(spacing: 10) {
                LookIcon(symbol, style: .body, weight: .bold)
                Text(title).font(.system(.body, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isEnabled ? look.textPrimary : look.textTertiary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .dashedOutline(look.dash, radius: radius)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(title)
    }
}

/// A set's rep target as a number pill (0 = no target, "—"); selected = its stepper is open.
struct TemplateRepPill: View {
    var reps: Int
    var selected: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var side: CGFloat = 44

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.field + 2, style: .continuous)
        Text(reps == 0 ? "—" : "\(reps)")
            .font(look.font.fieldNumber)
            .foregroundStyle(selected ? look.onDone : look.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(minWidth: side, minHeight: side)
            .background(selected ? look.selection : look.field, in: shape)
            .overlay { if !selected { shape.strokeBorder(look.hairline, lineWidth: 1) } }
            .contentTransition(.numericText())
    }
}

/// Left-to-right rows that wrap (rep pills: up to 12 per exercise, bigger at AX sizes).
struct TemplateFlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width + 0.5 {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        // Take the offered width when there is one, so placement wraps exactly as measured.
        return CGSize(width: width.isFinite ? width : maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX + 0.5 {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
