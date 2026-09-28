import SwiftUI

// Floodlight ticket 10 — pieces the Ask AI steps share: the top bar with the step indicator, the
// pinned action bar, the step's primary command, selectable tiles and chips, the equipment
// glyphs, inline figures and the consent switch. Ported from the prototype's `AIComponents.swift`
// and `AISupport.swift` (Floodlight only).

// MARK: - Top bar

/// Back (leading) · ✦ Ask AI · Cancel (trailing), with the step indicator under it. The indicator
/// names the step, so "where am I" stays visible while a long step scrolls. At accessibility sizes
/// the "Ask AI" title leaves the bar.
struct AITopBar: View {
    var title = "Ask AI"
    var showsSparkle = true
    var backLabel = "Back"
    /// 0 Goals, 1 Equipment, 2 Your week; nil hides the indicator.
    var step: Int?
    /// While the week is built, the current step's bar fills with this.
    var progress: Double?
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
                    if let onBack {
                        GlassIconButton("chevron.left", accessibilityLabel: backLabel, action: onBack)
                            .accessibilityIdentifier("routineBack")
                    }
                    Spacer(minLength: 0)
                    if let onCancel {
                        GlassCapsuleButton("Cancel", action: onCancel)
                            .accessibilityIdentifier("routineCancel")
                    }
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

/// Goals → Equipment → Your week: done steps lit, the current one outlined (it fills while the week
/// is being built). The current step's name is the page heading; at accessibility sizes only it
/// keeps its label.
struct AIStepIndicator: View {
    var current: Int
    var progress: Double?
    static let titles = ["Goals", "Equipment", "Your week"]

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of 3, \(Self.titles[current])")
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private func bar(_ index: Int) -> some View {
        let height: CGFloat = 5
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        if index < current {
            shape.fill(look.done).frame(height: height)
        } else if index == current {
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

    private func label(_ index: Int) -> some View {
        let isCurrent = index == current
        return Text(Self.titles[index])
            .font(isCurrent ? Font.system(.headline, weight: .heavy).width(.expanded) : .system(.caption, weight: .semibold))
            .foregroundStyle(isCurrent ? look.textPrimary : (index < current ? look.textSecondary : look.textTertiary))
            .lineLimit(1)
            .minimumScaleFactor(isCurrent ? 0.8 : 1)
    }
}

// MARK: - Pinned action bar

/// The thumb zone: an optional readout above the step's one filled command. Content scrolling under
/// it fades over a short soft edge.
struct AIBottomBar<Content: View>: View {
    var fade = true
    @ViewBuilder var content: Content
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 10) { content }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 8)
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

/// The step's filled command, or its quiet off face (no fill colour). A tap on the off face can
/// point at what is missing (`onDisabledTap`).
struct AIPrimaryButton: View {
    var title: String
    var symbol: String?
    var trailingSymbol = false
    var isEnabled = true
    var identifier: String?
    var onDisabledTap: (() -> Void)?
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56
    @State private var disabledTaps = 0

    init(_ title: String, symbol: String? = nil, trailingSymbol: Bool = false, isEnabled: Bool = true,
         identifier: String? = nil, onDisabledTap: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.trailingSymbol = trailingSymbol
        self.isEnabled = isEnabled
        self.identifier = identifier
        self.onDisabledTap = onDisabledTap
        self.action = action
    }

    var body: some View {
        Group {
            if isEnabled {
                if trailingSymbol, let symbol {
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
                // Still a button (so tests and VoiceOver find it, not enabled): a tap only points.
                Button {
                    disabledTaps += 1
                    onDisabledTap?()
                } label: {
                    HStack(spacing: 10) {
                        if let symbol { Image(systemName: symbol).font(.body.weight(.semibold)) }
                        Text(title).font(look.font.button)
                    }
                    .foregroundStyle(look.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: height)
                    .background(look.surfaceRaised, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.warning, trigger: disabledTaps)
                .accessibilityHint("Unavailable")
                .accessibilityAddTraits(.isButton)
                .accessibilityValue("Unavailable")
                .accessibilityRepresentation {
                    Button(title) { onDisabledTap?() }.disabled(true)
                }
            }
        }
        .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - Selection

/// How a chosen tile, chip or cell is drawn everywhere in the flow: lit like a scoreboard bulb
/// (the flood fill, ink content). Selection is a state, so it never takes the action colour.
struct AISelectionPaint {
    var look: Look
    var isSelected: Bool
    var fill: Color { isSelected ? look.done : look.surface }
    var foreground: Color { isSelected ? look.onDone : look.textSecondary }
    var edge: Color { isSelected ? .clear : look.hairline }
}

/// A tile that is on or off (experience, equipment, cardio). Every tile also carries a check mark,
/// so colour is never the only cue.
struct AISelectTile<Content: View>: View {
    var isSelected: Bool
    var minHeight: CGFloat = 56
    var alignment: Alignment = .leading
    var action: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let paint = AISelectionPaint(look: look, isSelected: isSelected)
        Button(action: action) {
            content
                .foregroundStyle(paint.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .frame(minHeight: minHeight)
                .background(paint.fill, in: shape)
                .overlay { shape.strokeBorder(paint.edge, lineWidth: 1) }
                .contentShape(shape)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// The on/off mark inside a selectable tile: an ink disc with a lit check on the lit tile.
struct AICheckMark: View {
    var isOn: Bool
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 22

    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(look.onDone)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .heavy))
                    .foregroundStyle(look.done)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            } else {
                Circle().strokeBorder(look.textTertiary, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isOn)
        .accessibilityHidden(true)
    }
}

/// A goal phrase chip, drawn with the flow's selection treatment.
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
                Text(title).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(isSelected ? paint.foreground : look.textSecondary)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background(isSelected ? paint.fill : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(paint.edge, lineWidth: 1) }
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Equipment glyphs

/// One line-drawn set for the eight equipment tiles, on the machine glyph's 24-unit grid and stroke.
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

// MARK: - Figures

/// "4 exercises" with the number big and the word small.
struct AIInlineFigure: View {
    var number: Int
    var label: String
    var numberFont: Font?
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(number)")
                .font(numberFont ?? look.font.smallNumber)
                .foregroundStyle(look.textPrimary)
                .contentTransition(.numericText(value: Double(number)))
            Text(label)
                .font(.system(.footnote, weight: .semibold))
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

extension String {
    /// "Day 1 — Fitness" may wrap only before the dash, never leaving it stranded or splitting "Day 1".
    var aiWrapFriendly: String {
        replacingOccurrences(of: " — ", with: " —\u{00A0}")
            .replacingOccurrences(of: "Day ", with: "Day\u{00A0}")
    }
}

extension CardioActivity {
    /// Indoor walks and runs take the treadmill figures, so the cardio tiles differ by more than a word.
    var aiSymbol: String {
        switch self {
        case .indoorWalk: "figure.walk.treadmill"
        case .indoorRun: "figure.run.treadmill"
        default: symbol
        }
    }
}

// MARK: - Switch

/// The routine-consent switch: a state, not a command, so it never takes the action colour — the lit
/// (flood) track with a white knob and a small ink check. VoiceOver and tests see a standard switch.
struct AISwitchStyle: ToggleStyle {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        Button {
            if reduceMotion { configuration.isOn.toggle() } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { configuration.isOn.toggle() }
            }
        } label: {
            HStack(spacing: 0) {
                configuration.label
                Spacer(minLength: 12)
                Capsule()
                    .fill(on ? look.done : look.ringTrack)
                    .frame(width: 51, height: 31)
                    .overlay(alignment: .leading) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(look.onDone)
                            .padding(.leading, 9)
                            .opacity(on ? 1 : 0)
                    }
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle()
                            .fill(on ? Color.white : look.textSecondary)
                            .overlay { Circle().strokeBorder(Color.black.opacity(on ? 0.22 : 0), lineWidth: 1) }
                            .frame(width: 27, height: 27)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .padding(2)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
