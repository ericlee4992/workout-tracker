import SwiftUI

// PROTOTYPE — pieces shared by the Ask AI steps: the glass top bar, the step indicator,
// the pinned action bar, selectable tiles, the equipment glyph set and a scroll view that
// can open on its 2nd / 3rd viewport (capture variants "p2" / "p3").

// MARK: - Actions the steps call (the flow screen owns navigation)

struct AIFlowActions {
    var next: () -> Void = {}
    var back: () -> Void = {}
    var generate: () -> Void = {}
    var retry: () -> Void = {}
    var stopGenerating: () -> Void = {}
    var changePreferences: () -> Void = {}
    var save: () -> Void = {}
    var openDay: (UUID) -> Void = { _ in }
    var openTemplate: (UUID) -> Void = { _ in }
    var close: () -> Void = {}
}

// MARK: - Top bar

/// Floating glass chrome: back (leading) · ✦ Ask AI · Cancel (trailing), with the step
/// indicator pinned under it. The indicator names the step (the steps carry no large title of
/// their own), so "where am I" stays visible while a long step scrolls. Cancel sits in the same
/// place on every step. At accessibility sizes the "Ask AI" title leaves the bar.
struct AITopBar: View {
    var title = "Ask AI"
    var showsSparkle = true
    var backLabel = "Back"
    /// 0 Goals, 1 Equipment, 2 Your week; nil hides the indicator (day editor, saved).
    var step: Int?
    /// The current step is being built: its bar fills with this progress (generating).
    var progress: Double?
    /// The hairline under the bar (off where nothing scrolls beneath it).
    var divider = true
    var onBack: (() -> Void)?
    var onCancel: (() -> Void)?
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if !typeSize.isAccessibilitySize {
                    HStack(spacing: 6) {
                        if showsSparkle {
                            Image(systemName: "sparkles").font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                        }
                        Text(title).font(look.font.navTitle).foregroundStyle(look.textPrimary).lineLimit(1)
                    }
                    .padding(.horizontal, 104)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
                HStack(spacing: 8) {
                    if let onBack { GlassIconButton("chevron.left", accessibilityLabel: backLabel, action: onBack) }
                    Spacer(minLength: 0)
                    if let onCancel { GlassCapsuleButton("Cancel", action: onCancel) }
                }
            }
            .frame(minHeight: 44)
            if let step {
                AIStepIndicator(current: step, progress: progress)
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 4)
        .padding(.bottom, 10)
        // Solid ground under the chrome: scrolled content never ghosts behind the step labels.
        .background { look.ground.ignoresSafeArea(edges: .top) }
        .overlay(alignment: .bottom) { if divider { LookDivider() } }
    }
}

// MARK: - Step indicator

/// Goals → Equipment → Your week, and the name of the screen. A: scoreboard bars — done steps
/// lit, the current one outlined (it fills with progress while the week is being built, and is
/// never lit on the error step). B: the same in pearl. C: punches — inked with a check when done,
/// a dashed cobalt ring for "here", dotted ahead. The current step's name is the page heading;
/// at accessibility sizes only it keeps its label.
struct AIStepIndicator: View {
    /// 0 Goals, 1 Equipment, 2 Your week.
    var current: Int
    /// While generating: how far the current step is built (0…1).
    var progress: Double?
    static let titles = ["Goals", "Equipment", "Your week"]

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.aiStill) private var still
    @State private var turn = false

    private var reduceMotion: Bool { systemReduceMotion || still }

    var body: some View {
        Group {
            if look.id.isPaperClub { punches } else { bars }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of 3, \(Self.titles[current])")
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            guard progress != nil, !reduceMotion else { return }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { turn = true }
        }
    }

    @ViewBuilder private var bars: some View {
        if typeSize.isAccessibilitySize {
            // AX: the bars alone, then the current step's name on its own full-width line.
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in bar(index).frame(maxWidth: .infinity) }
                }
                label(current)
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 7) {
                        bar(index)
                        label(index)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder private func bar(_ index: Int) -> some View {
        let height: CGFloat = look.id == .anatomy ? 6 : 5
        let shape = RoundedRectangle(cornerRadius: look.id == .anatomy ? 3 : 2, style: .continuous)
        if index < current {
            shape.fill(look.done).frame(height: height)
        } else if index == current {
            // Here: an outlined bar; while the week is built it fills from the leading edge.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    shape.fill(look.ringTrack)
                    if let progress {
                        shape.fill(look.done)
                            .frame(width: max(height, geo.size.width * min(1, max(0, progress))))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: progress)
                    }
                    shape.strokeBorder(look.done, lineWidth: 1.5)
                }
            }
            .frame(height: height + 2)
        } else {
            shape.fill(look.ringTrack).frame(height: height)
        }
    }

    private var punches: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                if index > 0 {
                    Rectangle().fill(index <= current ? look.textPrimary : look.hairline)
                        .frame(width: typeSize.isAccessibilitySize ? 14 : nil, height: 1.5)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? 14 : .infinity)
                }
                HStack(spacing: 6) {
                    punch(index)
                    if index == current || !typeSize.isAccessibilitySize { label(index).fixedSize() }
                }
            }
        }
    }

    @ViewBuilder private func punch(_ index: Int) -> some View {
        let size: CGFloat = 22
        if index < current {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(look.onDone)
                .frame(width: size, height: size)
                .background(look.done, in: Circle())
        } else if index == current {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .heavy).width(.expanded))
                .foregroundStyle(look.actionText)
                .frame(width: size, height: size)
                .overlay {
                    Circle().strokeBorder(look.actionText, style: StrokeStyle(lineWidth: 2, dash: [3.5, 2.5]))
                        .rotationEffect(.degrees(turn ? 360 : 0))
                }
        } else {
            Circle()
                .strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 2.5]))
                .frame(width: size, height: size)
        }
    }

    /// The current step's name is the page heading (bold, a size up); the others stay captions.
    @ViewBuilder private func label(_ index: Int) -> some View {
        let design: Font.Design = look.id == .anatomy ? .rounded : (look.id.isPaperClub && index == current ? .serif : .default)
        let isCurrent = index == current
        Text(Self.titles[index])
            .font(isCurrent
                  ? .system(.headline, design: design, weight: look.id == .floodlight ? .heavy : .bold)
                    .width(look.id == .floodlight ? .expanded : .standard)
                  : .system(.caption, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
            .foregroundStyle(isCurrent ? look.textPrimary : (index < current ? look.textSecondary : look.textTertiary))
            .lineLimit(1)
            .minimumScaleFactor(isCurrent ? 0.8 : 1)
    }
}

// MARK: - Pinned action bar

/// The thumb zone: an optional readout above the step's one filled command. Content that
/// scrolls under it fades out over a short soft edge, so nothing looks cut in half.
struct AIBottomBar<Content: View>: View {
    /// The soft fade above the bar (off where nothing scrolls beneath it).
    var fade = true
    @ViewBuilder var content: Content
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 10) { content }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background { look.ground.ignoresSafeArea(edges: .bottom) }
            .background(alignment: .top) {
                if fade {
                    LinearGradient(colors: [look.ground.opacity(0), look.ground], startPoint: .top, endPoint: .bottom)
                        .frame(height: 36)
                        .offset(y: -36)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// The step's filled command, or its quiet disabled face (no shadow, no fill colour).
struct AIPrimaryButton: View {
    var title: String
    var symbol: String?
    /// A and B draw the glyph after the label ("Next →"); C keeps its leading icon disc.
    var trailingSymbol = false
    var isEnabled = true
    /// Tapping the disabled face (e.g. scroll to the switch that is still off).
    var onDisabledTap: (() -> Void)?
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56

    init(_ title: String, symbol: String? = nil, trailingSymbol: Bool = false, isEnabled: Bool = true,
         onDisabledTap: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.trailingSymbol = trailingSymbol
        self.isEnabled = isEnabled
        self.onDisabledTap = onDisabledTap
        self.action = action
    }

    var body: some View {
        if isEnabled {
            if trailingSymbol && !look.id.isPaperClub, let symbol {
                Button(action: action) {
                    HStack(spacing: 10) {
                        Text(title)
                        Image(systemName: symbol).font(.body.weight(.bold))
                    }
                }
                .buttonStyle(.lookPrimary)
            } else {
                PrimaryButton(title, symbol: symbol, action: action)
            }
        } else {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol).font(.body.weight(.semibold)) }
                Text(title).font(look.font.button)
            }
            .foregroundStyle(look.id == .floodlight ? look.textSecondary : look.textTertiary)
            .frame(maxWidth: .infinity, minHeight: look.id.isPaperClub ? height + 6 : height)
            .background(disabledFill, in: Capsule())
            .overlay {
                if look.id.isPaperClub {
                    Capsule().strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
            .contentShape(Capsule())
            .onTapGesture {
                disabledTaps += 1
                onDisabledTap?()
            }
            .sensoryFeedback(.warning, trigger: disabledTaps)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityRemoveTraits(.isStaticText)
            .accessibilityHint("Unavailable")
            .accessibilityAction { onDisabledTap?() }
        }
    }

    @State private var disabledTaps = 0

    private var disabledFill: Color {
        switch look.id {
        case .floodlight: look.surfaceRaised
        case .anatomy: look.controlFill
        case .paper, .carbon: look.ground
        }
    }
}

// MARK: - Selectable tile

/// A tile that is on or off (experience, equipment, cardio), drawn with the flow's one
/// selection treatment (`AISelectionPaint`). Every tile also carries a check mark, so colour
/// is never the only cue.
struct AISelectTile<Content: View>: View {
    var isSelected: Bool
    var minHeight: CGFloat = 56
    var alignment: Alignment = .leading
    var action: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let paint = AISelectionPaint(look: look, isSelected: isSelected)
        Button(action: action) {
            content
                .foregroundStyle(paint.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .frame(minHeight: minHeight)
                .background {
                    shape.fill(paint.fill)
                    if let wash = paint.wash { shape.fill(wash) }
                }
                .overlay { shape.strokeBorder(paint.edge, lineWidth: paint.edgeWidth) }
                .contentShape(shape)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var radius: CGFloat {
        switch look.id {
        case .floodlight: 12
        case .anatomy: 18
        case .paper, .carbon: 14
        }
    }
}

/// The on/off mark inside a selectable tile or chip. A: an ink disc with a lit check on the
/// lit tile. B: a pearl disc with an ink check. C: a cobalt check disc (C's selection mark)
/// on the inked tile.
struct AICheckMark: View {
    var isOn: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 22

    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(onFill)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .heavy))
                    .foregroundStyle(onGlyph)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle().strokeBorder(offEdge, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isOn)
        .accessibilityHidden(true)
    }

    private var onFill: Color {
        switch look.id {
        case .floodlight: look.onDone
        case .anatomy: look.done
        case .paper, .carbon: look.actionText
        }
    }
    private var onGlyph: Color {
        switch look.id {
        case .floodlight: look.done
        case .anatomy: look.onDone
        case .paper, .carbon: look.onAction
        }
    }
    private var offEdge: Color {
        switch look.id {
        case .floodlight, .anatomy: look.textTertiary
        case .paper, .carbon: look.textSecondary
        }
    }
}

/// A goal phrase chip, drawn with the flow's selection treatment (not the Look chip, whose C
/// selection is a cobalt fill — cobalt fill stays the one primary here).
struct AIGoalChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 34

    var body: some View {
        let paint = AISelectionPaint(look: look, isSelected: isSelected)
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? "checkmark" : "plus").font(.system(.footnote, weight: .bold))
                Text(title).font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? paint.foreground : (look.id.isPaperClub ? look.textPrimary : look.textSecondary))
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background {
                Capsule().fill(isSelected ? paint.fill : (look.id == .anatomy ? look.surface : .clear))
                if let wash = paint.wash { Capsule().fill(wash) }
            }
            .overlay {
                Capsule().strokeBorder(paint.edge, lineWidth: look.id.isPaperClub ? 1.5 : paint.edgeWidth)
            }
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Equipment glyphs

/// One line-drawn set for the eight equipment toggles, on the same 24-unit grid and stroke
/// as the machine weight-stack glyph, so the checklist reads as one family of icons.
struct AIEquipmentGlyph: Shape {
    var kind: RoutineEquipment

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.midX - 12 * s, oy = rect.midY - 12 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            p.move(to: pt(x1, y1)); p.addLine(to: pt(x2, y2))
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            p.addRoundedRect(in: CGRect(origin: pt(x, y), size: CGSize(width: w * s, height: h * s)),
                             cornerSize: CGSize(width: r * s, height: r * s))
        }
        switch kind {
        case .dumbbells:
            line(8, 12, 16, 12)
            box(4.6, 6.8, 3.4, 10.4, 1.2); box(16, 6.8, 3.4, 10.4, 1.2)
            box(2, 9.4, 2.6, 5.2, 0.9); box(19.4, 9.4, 2.6, 5.2, 0.9)
        case .bench:
            box(2.5, 8.2, 19, 3.6, 1.6)
            line(6, 11.8, 6, 18.5); line(18, 11.8, 18, 18.5)
            line(3.5, 18.5, 8.5, 18.5); line(15.5, 18.5, 20.5, 18.5)
        case .adjustableBench:
            box(10.5, 11.6, 11, 3.2, 1.4)
            p.move(to: pt(2.8, 5.6)); p.addLine(to: pt(5.2, 3.9)); p.addLine(to: pt(11.6, 12.1))
            p.addLine(to: pt(9.2, 13.8)); p.closeSubpath()
            line(12, 14.8, 12, 19.5); line(19.5, 14.8, 19.5, 19.5)
            line(9.5, 19.5, 14.5, 19.5); line(17, 19.5, 22, 19.5)
        case .barbellRack:
            line(5, 3, 5, 21); line(19, 3, 19, 21)
            line(2.5, 21, 7.5, 21); line(16.5, 21, 21.5, 21)
            line(1.5, 9, 22.5, 9)
            box(6.9, 5.2, 2.4, 7.6, 0.8); box(14.7, 5.2, 2.4, 7.6, 0.8)
        case .cable:
            box(2.5, 2.5, 6.5, 19, 1.5)
            line(2.5, 8.2, 9, 8.2); line(2.5, 12.2, 9, 12.2); line(2.5, 16.2, 9, 16.2)
            line(9, 4, 15.2, 4)
            p.addEllipse(in: CGRect(origin: pt(15.2, 2.2), size: CGSize(width: 4 * s, height: 4 * s)))
            line(19.2, 4.2, 19.2, 14.5)
            p.move(to: pt(16.2, 14.5)); p.addLine(to: pt(22.2, 14.5))
            p.addQuadCurve(to: pt(16.2, 14.5), control: pt(19.2, 20.5))
        case .smith:
            line(5, 2.5, 5, 21); line(19, 2.5, 19, 21)
            line(5, 2.5, 19, 2.5)
            line(2.5, 21, 21.5, 21)
            line(1.5, 12, 22.5, 12)
            line(7.6, 9.6, 7.6, 14.4); line(16.4, 9.6, 16.4, 14.4)
        case .pullupBar:
            line(1.5, 5.5, 22.5, 5.5)
            line(5.5, 5.5, 5.5, 21); line(18.5, 5.5, 18.5, 21)
            line(3.5, 21, 7.5, 21); line(16.5, 21, 20.5, 21)
            line(9.5, 3.2, 9.5, 7.8); line(14.5, 3.2, 14.5, 7.8)
        case .dipStation:
            line(1.5, 8.5, 10, 8.5); line(14, 8.5, 22.5, 8.5)
            line(6, 8.5, 6, 20); line(18, 8.5, 18, 20)
            line(3, 20, 9, 20); line(15, 20, 21, 20)
            line(6, 14.5, 18, 14.5)
        }
        return p
    }
}

struct AIEquipmentIcon: View {
    var kind: RoutineEquipment
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 28

    var body: some View {
        AIEquipmentGlyph(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: max(1.5, size * 0.068), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Experience as rising bars: one, two or three lit.
struct AIExperienceBars: View {
    var level: Int
    var lit: Color
    var unlit: Color
    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 24

    var body: some View {
        HStack(alignment: .bottom, spacing: height * 0.14) {
            ForEach(1...3, id: \.self) { bar in
                Capsule()
                    .fill(bar <= level ? lit : unlit)
                    .frame(width: height * 0.26, height: height * CGFloat(bar + 1) / 4)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - Flow layout (chips)

struct AIFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var sizes: [CGSize] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > width { size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            row.sizes.append(size)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

// MARK: - A scroll view that can open on a later viewport

/// Opens scrolled to viewport `initialPage` (2 or 3) once its content is measured; used by the
/// "p2" / "p3" capture variants so reviewers can see a long screen whole.
struct AIPagedScrollView<Content: View>: View {
    var initialPage: Int?
    /// Set to a child's `.id` to scroll it into view (the view clears it again).
    var scrollTarget: Binding<String?> = .constant(nil)
    @ViewBuilder var content: Content
    @State private var position = ScrollPosition(edge: .top)
    @State private var didScroll = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
            }
            .scrollPosition($position)
            .scrollEdgeEffectStyle(.hard, for: .all)
            .onScrollGeometryChange(for: [CGFloat].self) { geo in
                [geo.contentSize.height, geo.containerSize.height, geo.contentInsets.top, geo.contentInsets.bottom]
            } action: { _, m in
                guard let page = initialPage, page > 1, !didScroll, m[0] > 0, m[1] > 0 else { return }
                didScroll = true
                let visible = m[1] - m[2] - m[3]
                let maxOffset = max(0, m[0] - visible)
                let target = min(maxOffset, CGFloat(page - 1) * visible * 0.92)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    position.scrollTo(y: target)
                }
            }
            .onChange(of: scrollTarget.wrappedValue) { _, id in
                guard let id else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { proxy.scrollTo(id, anchor: .center) }
                scrollTarget.wrappedValue = nil
            }
        }
    }
}

// MARK: - Figures

/// "4 exercises" with the number big and the word small (numbers big, labels small).
struct AIInlineFigure: View {
    var number: Int
    var label: String
    var numberFont: Font?
    var tint: Color?
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(number)")
                .font(numberFont ?? look.font.smallNumber)
                .foregroundStyle(tint ?? look.textPrimary)
                .contentTransition(.numericText(value: Double(number)))
            Text(label)
                .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

extension Int {
    /// "exercise" / "exercises".
    func aiPlural(_ word: String) -> String { self == 1 ? word : word + "s" }
}
