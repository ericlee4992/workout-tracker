import SwiftUI

// PROTOTYPE — helpers for the Templates area (detail, editor, drift, save as template).
// Area-prefixed so parallel authors never collide; the integrator may promote them.

// MARK: - Store helpers

/// What a template row resolves to at a gym: the machine last used there, else the
/// free-weight tag, else the only machine that serves it (the same rule a start uses, D6).
struct TemplatesEquipment: Hashable {
    var symbol: String
    var label: String
}

extension Store {
    func templatesEquipment(for item: TemplateItem, gymID: UUID?) -> TemplatesEquipment? {
        if let tag = item.equipmentTag {
            return TemplatesEquipment(symbol: tag == .machine ? LookIcon.machine : tag.symbol, label: tag.label)
        }
        if let gymID {
            for w in history where w.gymID == gymID {
                if let id = w.entries.first(where: { $0.exerciseID == item.exerciseID && $0.machineID != nil })?.machineID,
                   let m = machine(id), !m.isDeleted {
                    return TemplatesEquipment(symbol: LookIcon.machine, label: m.label)
                }
            }
        }
        if let tag = exercise(item.exerciseID)?.tags.first(where: { $0 != .machine }) {
            return TemplatesEquipment(symbol: tag.symbol, label: tag.label)
        }
        let options = machines(for: item.exerciseID, gymID: gymID)
        if options.count == 1 { return TemplatesEquipment(symbol: LookIcon.machine, label: options[0].label) }
        return nil
    }

    /// Target sets per family (all five, head to toe; zero = not in the template).
    func templatesFamilyCounts(items: [TemplateItem]) -> [FamilyCount] {
        var counts: [MuscleFamily: Int] = [:]
        for item in items {
            if let family = exercise(item.exerciseID)?.family { counts[family, default: 0] += item.setCount }
        }
        return MuscleFamily.allCases.map { FamilyCount(family: $0, sets: counts[$0] ?? 0) }
    }

    func templatesFamilies(items: [TemplateItem]) -> [MuscleFamily] {
        families(exerciseIDs: items.map(\.exerciseID))
    }
}

extension Template {
    /// "5 exercises · 18 sets" (the finish summary's pattern).
    var templatesSummary: String {
        var parts: [String] = []
        if !items.isEmpty { parts.append(Format.count(items.count, "exercise")) }
        if setCount > 0 { parts.append(Format.count(setCount, "set")) }
        return parts.joined(separator: " · ")
    }
}

extension PlannedCardio {
    /// "20 min" or "20 min · 2.5 km".
    var templatesSummary: String {
        var text = "\(minutes) min"
        if let distance { text += " · \(Format.number(distance)) \(unit.label)" }
        return text
    }
}

// MARK: - Start capsule (template detail)

/// The template's Start: the user's icon-disc capsule, full width, with what starts where
/// (no arrow: the disc carries the action, as in the Start pair). With `elapsed` it is the
/// running workout's Resume capsule instead, ending in a live pulse and the running clock.
struct TemplatesStartCapsule: View {
    var title = "Start"
    var subtitle: String?
    var elapsed: Int?
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var discA: CGFloat = 44
    @ScaledMetric(relativeTo: .headline) private var discB: CGFloat = 40
    @ScaledMetric(relativeTo: .headline) private var discC: CGFloat = 46
    @State private var taps = 0

    private var disc: CGFloat {
        switch look.id {
        case .floodlight: discA
        case .anatomy: discB
        case .paper, .carbon: discC
        }
    }

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: look.id == .anatomy ? 12 : 10) {
                IconDisc(symbol: "figure.strengthtraining.traditional", size: disc, context: .onAction)
                if typeSize.isAccessibilitySize, let elapsed {
                    // AX sizes (Resume): the title gets the full width; the running clock and the
                    // sets count share the second line.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(look.font.button).fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            clock(elapsed)
                            if let subtitle {
                                Text(subtitle)
                                    .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(look.font.button)
                        // AX sizes: the pinned Start capsule stays one line tall (VoiceOver still reads the subtitle).
                        if let subtitle, !typeSize.isAccessibilitySize {
                            Text(subtitle)
                                .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    if let elapsed { clock(elapsed) }
                }
            }
            .padding(.leading, look.id == .floodlight ? 10 : 8)
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
        .accessibilityValue([subtitle, elapsed.map(Format.spokenElapsed)].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    /// The running clock led by the live pulse.
    private func clock(_ elapsed: Int) -> some View {
        HStack(spacing: 8) {
            TemplatesLiveDot(color: look.onAction, size: 9)
            Text(Format.elapsed(elapsed))
                .font(look.font.statNumber)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy, value: elapsed)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - Rep pills

/// A set's rep target as a small number pill. The drift diff and the editor share it.
/// plain = an open target; changed / added = inked (filled "done"); removed = dashed and faint;
/// dim = a target an option leaves alone; selected = the editor's selection (A flood-white,
/// B pearl, C cobalt fill).
struct TemplatesRepPill: View {
    enum Style: Hashable { case plain, changed, added, removed, dim, selected }
    var reps: Int?
    var style: Style
    var large = false
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var smallHeight: CGFloat = 26
    @ScaledMetric(relativeTo: .footnote) private var smallWidth: CGFloat = 30
    @ScaledMetric(relativeTo: .headline) private var largeSide: CGFloat = 44

    private var text: String {
        guard let reps else { return "•" }
        return reps == 0 ? "—" : "\(reps)"
    }

    var body: some View {
        let radius: CGFloat = large ? look.radius.field + 2 : 7
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Text(text)
            .font(large ? look.font.fieldNumber : Font.system(.footnote, design: look.id == .anatomy ? .rounded : .default,
                                                              weight: .bold).monospacedDigit())
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, large ? 10 : 6)
            .frame(minWidth: large ? largeSide : smallWidth, minHeight: large ? largeSide : smallHeight)
            .background(fill, in: shape)
            .overlay {
                switch style {
                case .removed:
                    shape.strokeBorder(look.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                case .plain:
                    shape.strokeBorder(plainEdge, lineWidth: look.id.isPaperClub ? 1.5 : 1)
                case .dim:
                    shape.strokeBorder(look.hairline, lineWidth: 1)
                case .selected:
                    if look.id.isPaperClub { shape.strokeBorder(look.outline, lineWidth: 2) }
                case .changed, .added:
                    EmptyView()
                }
            }
            .contentTransition(.numericText())
    }

    private var plainEdge: Color {
        switch look.id {
        case .floodlight: look.hairline
        case .anatomy: Color.white.opacity(0.05)
        case .paper, .carbon: look.dash
        }
    }

    private var fill: Color {
        switch style {
        case .plain: look.field
        case .changed, .added: look.done
        case .removed, .dim: .clear
        case .selected: look.id.isPaperClub ? look.action : look.selection
        }
    }

    private var foreground: Color {
        switch style {
        case .plain: look.textPrimary
        case .changed, .added: look.onDone
        case .removed, .dim: look.textTertiary
        case .selected: look.id.isPaperClub ? look.onAction : look.onDone
        }
    }
}

// MARK: - Superset letter

/// "A" / "B": a superset member's position, as a small outlined letter tag.
struct TemplatesSupersetTag: View {
    var letter: String
    @Environment(\.look) private var look

    var body: some View {
        Text(letter)
            .font(.system(.caption, design: look.id == .anatomy ? .rounded : .default, weight: .heavy))
            .foregroundStyle(look.id.isPaperClub ? look.onDone : look.textPrimary)
            .frame(minWidth: 22, minHeight: 20)
            .background {
                // Letter and edge in the text colour (A flood, B pearl): full contrast on the card.
                switch look.id {
                case .floodlight: RoundedRectangle(cornerRadius: 5).strokeBorder(look.textPrimary, lineWidth: 1.5)
                case .anatomy: Capsule().strokeBorder(look.textPrimary, lineWidth: 1.5)
                case .paper, .carbon: RoundedRectangle(cornerRadius: 5).fill(look.done)
                }
            }
            .accessibilityLabel("Superset position \(letter)")
    }
}

// MARK: - Flow layout

/// Left-to-right rows that wrap (rep pills: up to 12 per exercise, bigger at AX sizes).
struct TemplatesFlowLayout: Layout {
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

// MARK: - Stats (template detail)

/// Times run · Last run · Avg. time, numbers big and labels small.
/// A: one scoreboard panel split by hairlines. B: three solid tiles. C: one ticket with rules.
/// AX sizes: one panel of rows (label leading, value trailing).
struct TemplatesStatsPanel: View {
    var stats: TemplateStats
    var now: Date
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
        } else if look.id == .anatomy {
            HStack(spacing: 10) {
                cell("Times run", symbol: "arrow.clockwise") { timesRun }.lookSurface(.stat)
                if let last = stats.lastRun { cell("Last run", symbol: "clock.arrow.circlepath") { lastRun(last) }.lookSurface(.stat) }
                if let avg = stats.averageDurationSeconds { cell("Avg. time", symbol: "timer") { average(avg) }.lookSurface(.stat) }
            }
            .fixedSize(horizontal: false, vertical: true)
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

    private var numberFont: Font { look.font.bigNumber }
    private var unitFont: Font {
        .system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: look.id == .anatomy ? .bold : .semibold)
    }

    private var timesRun: some View {
        Text("\(stats.timesRun)")
            .font(numberFont)
            .monospacedDigit()
            .foregroundStyle(look.textPrimary)
            .contentTransition(.numericText())
    }

    @ViewBuilder private func lastRun(_ date: Date) -> some View {
        let cal = Calendar.app
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        if look.id.isPaperClub && days >= 2 && days <= 60 {
            // C words it "7 days ago": the number big, the words small.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(days)").font(numberFont).foregroundStyle(look.textPrimary)
                Text("days ago").font(unitFont).foregroundStyle(look.textSecondary)
            }
            .lineLimit(1)
        } else {
            Text(look.lastDoneLabel(date, now: now))
                .font(look.font.statNumber)
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func average(_ seconds: Int) -> some View {
        DurationFigure(minutes: max(1, seconds / 60), numberFont: numberFont, unitFont: unitFont,
                       numberColor: look.textPrimary, unitColor: look.textSecondary)
    }

    private func cell<V: View>(_ label: String, symbol: String, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: look.id == .floodlight ? 6 : 4) {
            // Centre-aligned so every label sits on one line across the cells, whatever its glyph.
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: symbol).font(.system(.caption, weight: .semibold))
                Text(label).font(.system(.footnote, weight: look.id == .floodlight ? .regular : .semibold)).lineLimit(1)
            }
            .foregroundStyle(look.textSecondary)
            value()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, look.id == .floodlight ? 15 : 13)
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

// MARK: - Capture variants: scroll to the 2nd / 3rd viewport

/// `-variant p2` / `p3` / `p4` scrolls a long screen to its 2nd / 3rd / 4th viewport (`end`: the bottom) once it has laid out.
struct TemplatesVariantScroll: ViewModifier {
    var variant: String?
    var active: Bool
    @State private var position = ScrollPosition(edge: .top)
    @State private var applied = false

    /// Reads a page token anywhere in the variant ("p2", "drift-end", "keep-p2").
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
            .onScrollGeometryChange(for: TemplatesScrollMetrics.self) { geo in
                TemplatesScrollMetrics(viewport: geo.containerSize.height, content: geo.contentSize.height)
            } action: { _, metrics in
                guard active, !applied, let page, metrics.viewport > 0, metrics.content > metrics.viewport else { return }
                applied = true
                let target = metrics.viewport * 0.85 * CGFloat(page)
                let last = target >= metrics.content - metrics.viewport - 1
                // The last page scrolls to the bottom edge (it respects bottom insets such as a pinned bar).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if last { position.scrollTo(edge: .bottom) } else { position.scrollTo(y: target) }
                }
            }
    }
}

struct TemplatesScrollMetrics: Equatable {
    var viewport: CGFloat
    var content: CGFloat
}

// MARK: - Make row

/// A dashed "make one" row (Add exercise, Add cardio target): flat, full width.
struct TemplatesMakeRow: View {
    var title: String
    var symbol: String = "plus"
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 52

    var body: some View {
        let radius: CGFloat = look.id == .anatomy ? height / 2 : look.radius.row + 2
        Button(action: action) {
            HStack(spacing: 10) {
                LookIcon(symbol, style: .body, weight: .bold)
                Text(title).font(.system(.body, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isEnabled ? look.textPrimary : look.textTertiary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: radius,
                           lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: look.id.isPaperClub ? [6, 4] : [5, 4])
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.lookPressable)
    }
}

// MARK: - Single-line names in a wrapping field

/// A vertical-axis `TextField` wraps a long name, but Return would insert a newline. This
/// binding drops newlines and treats Return as the submit action instead.
enum TemplatesSingleLine {
    static func binding(_ text: Binding<String>, onReturn: @escaping () -> Void) -> Binding<String> {
        Binding(get: { text.wrappedValue }, set: { new in
            if new.contains("\n") {
                text.wrappedValue = new.replacingOccurrences(of: "\n", with: "")
                onReturn()
            } else {
                text.wrappedValue = new
            }
        })
    }
}

// MARK: - AccessibilityL inside sheets

/// Sheets are hosted outside the tab view's environment, so the capture override
/// (`router.dynamicTypeOverride`, `-axl YES`) is re-applied at a sheet's root.
struct TemplatesTypeOverride: ViewModifier {
    var size: DynamicTypeSize?
    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}

// MARK: - Row press

/// List rows highlight with the pressed fill instead of scaling, so a panel never wobbles.
/// Reduce Motion needs nothing extra: there is no motion.
struct TemplatesRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.pressedFill : .clear)
    }
}

// MARK: - Superset seal (template detail)

/// The filled chain link that sits on the seam between two superset members: the same mark the
/// editor's linked seam shows, so a pair reads the same on both screens. Decorative (the A/B
/// tags carry the meaning for VoiceOver).
struct TemplatesLinkSeal: View {
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 24

    var body: some View {
        Image(systemName: "link")
            .font(.system(size: side * 0.46, weight: .heavy))
            .foregroundStyle(look.onDone)
            .frame(width: side, height: side)
            .background { Circle().fill(look.done) }
            .overlay { if look.id.isPaperClub { Circle().strokeBorder(look.outline, lineWidth: 1.5) } }
            .accessibilityHidden(true)
    }
}

// MARK: - Capture samples (template detail variants)

/// Sample templates for T01's `fresh` (never run) and `ai` (Ask AI, made for another gym)
/// variants. Stable ids; saving twice replaces.
enum TemplatesSamples {
    static var freshTemplate: Template {
        Template(id: .stable("templates.sample.fresh"), name: "Arms", items: [
            TemplateItem(id: .stable("templates.sample.fresh.1"), exerciseID: SampleData.exerciseID("Machine Biceps Curl"),
                         targetReps: [12, 10, 10], restSeconds: 60),
            TemplateItem(id: .stable("templates.sample.fresh.2"), exerciseID: SampleData.exerciseID("Triceps Pushdown"),
                         targetReps: [12, 12, 10], restSeconds: 60),
            TemplateItem(id: .stable("templates.sample.fresh.3"), exerciseID: SampleData.exerciseID("Dumbbell Curl"),
                         targetReps: [12, 10, 10], restSeconds: 60, equipmentTag: .dumbbell),
        ])
    }

    static var aiTemplate: Template {
        Template(id: .stable("templates.sample.ai"), name: "Day 1 — Fitness", items: [
            TemplateItem(id: .stable("templates.sample.ai.1"), exerciseID: SampleData.exerciseID("Leg Press"),
                         targetReps: [10, 10, 10], restSeconds: 60),
            TemplateItem(id: .stable("templates.sample.ai.2"), exerciseID: SampleData.exerciseID("Hack Squat"),
                         targetReps: [10, 10, 10], restSeconds: 60),
            TemplateItem(id: .stable("templates.sample.ai.3"), exerciseID: SampleData.exerciseID("Seated Chest Press"),
                         targetReps: [10, 10, 10], restSeconds: 60),
            TemplateItem(id: .stable("templates.sample.ai.4"), exerciseID: SampleData.exerciseID("Lat Pulldown"),
                         targetReps: [10, 10, 10], restSeconds: 60),
        ], cardio: [PlannedCardio(id: .stable("templates.sample.ai.cardio"), activity: .indoorCycle, minutes: 15,
                                  distance: nil, unit: .mi)],
        generatedForGymID: SampleData.gymID("Gangnam Fitness"))
    }
}
