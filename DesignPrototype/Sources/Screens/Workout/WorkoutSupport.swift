import SwiftUI

// PROTOTYPE — helpers for the Workout area (Home, gym menu). Area-prefixed so parallel
// authors never collide; the integrator may promote them into Look/ or Model/.

// MARK: - Dates

enum WorkoutDates {
    /// Home's date line. A and B: "Thursday, Sep 24"; C (both finishes): "Thursday, September 24".
    static func homeSubtitle(_ date: Date, look: LookStyle) -> String {
        (look.isPaperClub ? long : short).string(from: date)
    }

    private static func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Format.locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
    private static let short = formatter("EEEEMMMd")
    private static let long = formatter("EEEEMMMMd")
}

// MARK: - Capture variants: scroll to the 2nd / 3rd viewport

/// `-variant p2` / `p3` / `p4` scrolls a long screen to its 2nd / 3rd / 4th viewport (`end`: the bottom) once it has laid out,
/// so reviewers can see the whole screen. Other variants leave the scroll alone.
struct WorkoutVariantScroll: ViewModifier {
    var variant: String?
    var active: Bool
    @State private var position = ScrollPosition(edge: .top)
    @State private var applied = false

    /// Reads a page token anywhere in the variant ("p2", "odd-end").
    private var page: Int? {
        let tokens = (variant ?? "").split(separator: "-").map(String.init)
        if tokens.contains("p2") { return 1 }
        if tokens.contains("p3") { return 2 }
        if tokens.contains("p4") { return 3 }
        if tokens.contains("end") { return 99 }
        return nil
    }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: WorkoutScrollMetrics.self) { geo in
                WorkoutScrollMetrics(viewport: geo.containerSize.height, content: geo.contentSize.height)
            } action: { _, metrics in
                guard active, !applied, let page, metrics.viewport > 0, metrics.content > metrics.viewport else { return }
                applied = true
                let target = metrics.viewport * 0.88 * CGFloat(page)
                let last = target >= metrics.content - metrics.viewport - 1
                // The last page scrolls to the bottom edge (it respects bottom insets such as a pinned bar).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if last { position.scrollTo(edge: .bottom) } else { position.scrollTo(y: target) }
                }
            }
    }
}

struct WorkoutScrollMetrics: Equatable {
    var viewport: CGFloat
    var content: CGFloat
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

// MARK: - Make rows (Add Gym…, first-run Ask AI)

/// A "make one" row: the disc and the label inside a dashed outline, sized like the gym picker
/// it stands in for (first run, the end of the gym menu, first-run Ask AI).
struct WorkoutMakeRow: View {
    var title: String
    var symbol: String = "plus"
    var trailingSymbol: String?
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 56

    private var radius: CGFloat {
        switch look.id {
        case .floodlight: 14
        case .anatomy: typeSize.isAccessibilitySize ? look.radius.panel : minHeight / 2
        case .paper, .carbon: 16
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconDisc(symbol: symbol, size: disc, context: .make)
                    .background { if look.id == .floodlight { Circle().fill(look.surfaceRaised) } }
                Text(title)
                    .font(.system(.body, weight: look.id.isPaperClub ? .bold : .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let trailingSymbol {
                    LookIcon(trailingSymbol, style: .body)
                        .foregroundStyle(look.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: radius,
                           lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: look.id.isPaperClub ? [6, 4] : [5, 4])
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.lookPressable)
    }
}

/// "Add Gym…" (first run, and the end of the gym menu).
struct WorkoutAddGymRow: View {
    var action: () -> Void
    @Environment(\.look) private var look
    var body: some View {
        WorkoutMakeRow(title: "Add Gym…", trailingSymbol: look.gymSymbol, action: action)
    }
}

// MARK: - AccessibilityL inside sheets

/// Sheets are hosted outside the tab view's environment, so the capture override
/// (`router.dynamicTypeOverride`, Z04 / `-axl YES`) is re-applied at a sheet's root.
struct WorkoutTypeOverride: ViewModifier {
    var size: DynamicTypeSize?
    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}

// MARK: - First-run week (W03)

/// Before any workout exists the week is not a scoreboard of zeros: it is seven quiet days
/// and today's slot, marked in the look's "now" colour, waiting for the first workout.
/// A: day cells (today dashed). B: the day-bar tracks at full height, unlit, today's outlined.
/// C: punch card (today's dashed punch).
/// Reduce Motion: today's mark is still.
struct WorkoutFirstWeekCard: View {
    var days: [WeekDaySummary]
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var cellHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .caption) private var punch: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var barAreaScaled: CGFloat = 44
    /// B's bar area, as in the filled week (grows with Dynamic Type, at most 1.3×).
    private var barArea: CGFloat { min(barAreaScaled, 57) }
    @State private var breathe = false

    var body: some View {
        VStack(alignment: .leading, spacing: look.id.isPaperClub ? 14 : 16) {
            Text("This week")
                .font(look.id.isPaperClub ? look.font.title3 : look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: look.id == .floodlight ? 6 : 0) {
                ForEach(days) { day in
                    marker(day)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day.isToday ? "Today, \(Format.weekday(day.date))" : Format.weekday(day.date))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, look.id == .anatomy ? 18 : 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    @ViewBuilder private func marker(_ day: WeekDaySummary) -> some View {
        switch look.id {
        case .floodlight: cell(day)
        case .anatomy: dot(day)
        case .paper, .carbon: punchMark(day)
        }
    }

    /// A: an unlit scoreboard cell; today dashed and breathing.
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

    /// B: the week strip's day-bar tracks at their full height, unlit (the shape the filled week
    /// takes); today's track outlined in pearl, breathing.
    private func dot(_ day: WeekDaySummary) -> some View {
        let track = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return VStack(spacing: 6) {
            Group {
                if day.isToday {
                    track.strokeBorder(look.textPrimary.opacity(breathe ? 1 : 0.55), lineWidth: 2)
                } else {
                    track.fill(day.isFuture ? look.dayDotFuture : look.dayDotPast)
                }
            }
            .frame(width: 16, height: barArea)
            Text(day.letter)
                .font(day.isToday ? .system(.caption, design: .rounded, weight: .black) : .system(.caption, weight: .semibold))
                .foregroundStyle(day.isToday ? look.textPrimary : look.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// C: open punches; today's dashed cobalt punch.
    private func punchMark(_ day: WeekDaySummary) -> some View {
        let size = min(punch, 44)
        return VStack(spacing: 6) {
            Text(day.letter)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(day.isToday ? look.actionText : look.textSecondary)
            Group {
                if day.isToday {
                    Circle().strokeBorder(look.actionText, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
                        .rotationEffect(.degrees(breathe ? 20 : 0))
                } else {
                    Circle().strokeBorder(look.textSecondary.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 2.5]))
                }
            }
            .frame(width: size, height: size)
        }
        .frame(maxWidth: .infinity)
    }
}
