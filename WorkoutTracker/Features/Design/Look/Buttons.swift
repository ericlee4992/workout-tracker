import SwiftUI

// Buttons. One filled command per screen state (the Start pair counts as one peer group).
// A: Ultra capsules with ink labels, scale 0.97 on press.
// B: pearl capsules with ink labels and a faint pearl halo, scale 0.97.
// C: cobalt capsules with a 2.5 pt outline and the screen's only hard 4 pt offset shadow;
//    pressed, the capsule physically sinks into its shadow.
// Reduce Motion: no scale or sink, an opacity dip instead (PressFeedback).

// MARK: - Icon disc

/// The user's "icon disc": a circle holding an activity glyph.
struct IconDisc: View {
    enum Context { case onAction, onSurface, make }
    var symbol: String
    var size: CGFloat
    var context: Context = .onSurface
    @Environment(\.look) private var look

    var body: some View {
        let glyph = discGlyph
        switch (look.id, context) {
        case (.floodlight, .onAction):
            glyph.foregroundStyle(look.action)
                .frame(width: size, height: size)
                .background(look.onAction, in: Circle())
        case (.paper, .onAction):
            glyph.foregroundStyle(look.textPrimary)
                .frame(width: size, height: size)
                .background(look.surface, in: Circle())
                .overlay { Circle().strokeBorder(look.outline, lineWidth: 2) }
        case (.carbon, .onAction):
            glyph.foregroundStyle(look.ground)
                .frame(width: size, height: size)
                .background(look.textPrimary, in: Circle())
        case (.floodlight, _):
            glyph.foregroundStyle(look.textPrimary)
                .frame(width: size, height: size)
        case (.paper, _), (.carbon, _):
            glyph.foregroundStyle(look.textPrimary)
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(look.outline, lineWidth: 1.5) }
        }
    }

    @ViewBuilder private var discGlyph: some View {
        if symbol == LookIcon.machine {
            WeightStackGlyph()
                .stroke(style: StrokeStyle(lineWidth: max(1.4, size * 0.04), lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.48, height: size * 0.48)
        } else {
            Image(systemName: symbol).font(.system(size: size * 0.45, weight: .semibold))
        }
    }
}

// MARK: - Start capsule (the user's defended pattern)

/// "Start Lifting" / "Start Cardio": an equal-peer capsule with the activity icon in a disc.
struct StartCapsule: View {
    var title: String
    var symbol: String
    var action: () -> Void = {}
    @State private var taps = 0

    init(title: String, symbol: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            StartCapsuleLabel(title: title, symbol: symbol)
        }
        .buttonStyle(StartCapsuleStyle())
        .sensoryFeedback(.impact(weight: .heavy), trigger: taps)
        .accessibilityLabel(title)
    }
}

private struct StartCapsuleLabel: View {
    var title: String
    var symbol: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var discA: CGFloat = 44
    @ScaledMetric(relativeTo: .headline) private var discC: CGFloat = 46

    var body: some View {
        let disc: CGFloat = switch look.id {
        case .floodlight: discA
        case .paper, .carbon: discC
        }
        HStack(spacing: 8) {
            IconDisc(symbol: symbol, size: disc, context: .onAction)
            Text(title)
                .font(look.font.button)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.leading, look.id.isPaperClub ? 8 : 10)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .foregroundStyle(look.onAction)
    }
}

struct StartCapsuleStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        CapsuleFace(pressed: configuration.isPressed, minHeight: nil) { configuration.label }
    }
}

/// The filled capsule shared by the Start pair and the primary command.
private struct CapsuleFace<Label: View>: View {
    var pressed: Bool
    var minHeight: CGFloat?
    @ViewBuilder var label: Label
    @Environment(\.look) private var look

    var body: some View {
        switch look.id {
        case .floodlight:
            label
                .frame(minHeight: minHeight)
                .background(look.action, in: Capsule())
                .contentShape(Capsule())
                .pressFeedback(pressed, .scale)
        case .paper, .carbon:
            HardShadowCapsule(pressed: pressed) {
                label.frame(minHeight: minHeight)
            }
        }
    }
}

/// C's primary: cobalt capsule, 2.5 pt outline, a 4 × 4 pt hard offset it sinks into.
private struct HardShadowCapsule<Label: View>: View {
    var pressed: Bool
    @ViewBuilder var label: Label
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let sink = look.motion.pressSink
        let down = pressed && !reduceMotion
        label
            .background(look.action, in: Capsule())
            .overlay { Capsule().strokeBorder(look.outline, lineWidth: look.stroke.primary) }
            .contentShape(Capsule())
            .offset(x: down ? sink : 0, y: down ? sink : 0)
            .background {
                Capsule().fill(look.shadowInk).offset(x: sink, y: sink)
            }
            .opacity(pressed && reduceMotion ? look.motion.reducedPressOpacity : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: pressed)
    }
}

/// The Start pair: two EQUAL capsules side by side; they stack only when a label can't fit.
struct StartPair: View {
    var onLifting: () -> Void = {}
    var onCardio: () -> Void = {}
    @Environment(\.look) private var look

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: look.id.isPaperClub ? 14 : 10) { capsules }
            VStack(spacing: 12) { capsules }
        }
    }

    @ViewBuilder private var capsules: some View {
        StartCapsule(title: "Start Lifting", symbol: "figure.strengthtraining.traditional", action: onLifting)
            .frame(maxWidth: .infinity)
        StartCapsule(title: "Start Cardio", symbol: "figure.run", action: onCardio)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Primary / secondary

/// The one filled command on a screen state (View in History, Add Exercise, Save…).
/// C gets its icon disc at leading with the label centred.
struct PrimaryButton: View {
    var title: String
    var symbol: String?
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56
    @ScaledMetric(relativeTo: .headline) private var discSize: CGFloat = 46

    init(_ title: String, symbol: String? = nil, action: @escaping () -> Void = {}) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if look.id.isPaperClub, let symbol {
                ZStack {
                    Text(title).font(look.font.button).padding(.horizontal, discSize + 16)
                    HStack {
                        IconDisc(symbol: symbol, size: discSize, context: .onAction)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity, minHeight: height + 6)
                .foregroundStyle(look.onAction)
            } else {
                HStack(spacing: 10) {
                    if let symbol { Image(systemName: symbol).font(.body.weight(.semibold)) }
                    Text(title).font(look.font.button)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(look.onAction)
            }
        }
        .buttonStyle(PrimaryButtonStyle.Bare())
    }
}

/// Filled primary for any label.
struct PrimaryButtonStyle: ButtonStyle {
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56
    @Environment(\.look) private var look

    func makeBody(configuration: Configuration) -> some View {
        CapsuleFace(pressed: configuration.isPressed, minHeight: nil) {
            configuration.label
                .font(look.font.button)
                .foregroundStyle(look.onAction)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: look.id.isPaperClub ? height + 6 : height)
        }
    }

    /// Used by PrimaryButton, which lays out its own label.
    struct Bare: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            CapsuleFace(pressed: configuration.isPressed, minHeight: nil) { configuration.label }
        }
    }
}

/// The secondary command (Save as Template…): a quiet capsule.
struct SecondaryButtonStyle: ButtonStyle {
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 50
    @Environment(\.look) private var look

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(look.font.button)
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: height)
        switch look.id {
        case .floodlight:
            label
                .background(look.surfaceRaised, in: Capsule())
                .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
                .contentShape(Capsule())
                .pressFeedback(configuration.isPressed)
        case .paper, .carbon:
            label
                .background(configuration.isPressed ? look.pressedFill : look.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(look.outline, lineWidth: look.stroke.pressable) }
                .contentShape(Capsule())
        }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var lookPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var lookSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Pills (+15s / Skip)

/// Compact pills for the rest bar. `prominent` = Skip (the filled command while resting).
/// A/B scale while pressed; C's pills darken (only C's primary sinks), per C SPEC §6.
struct PillButtonStyle: ButtonStyle {
    var prominent = false
    @ScaledMetric(relativeTo: .subheadline) private var heightAB: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var heightC: CGFloat = 48
    @Environment(\.look) private var look

    func makeBody(configuration: Configuration) -> some View {
        let isC = look.id.isPaperClub
        let pressed = configuration.isPressed
        let label = configuration.label
            .font(.system(.callout, weight: prominent || isC ? .bold : .semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, prominent ? 18 : 14)
            .frame(minWidth: 56, minHeight: isC ? heightC : heightAB)
        Group {
            switch (look.id, prominent) {
            case (.floodlight, true):
                label.foregroundStyle(look.onAction).background(look.action, in: Capsule())
            case (.floodlight, false):
                label.foregroundStyle(look.textPrimary)
                    .background(look.pillFill, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            case (_, true):
                label.foregroundStyle(look.onAction)
                    .background(look.action, in: Capsule())
                    .overlay { Capsule().fill(Color.black.opacity(pressed ? 0.18 : 0)) }
                    .overlay { Capsule().strokeBorder(look.onSlab, lineWidth: 2) }
            case (_, false):
                label.foregroundStyle(look.onSlab)
                    .background(look.onSlab.opacity(pressed ? 0.16 : 0), in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 2) }
            }
        }
        .contentShape(Capsule())
        .pressFeedback(pressed, isC ? .none : .scale)
    }
}

// MARK: - Glass chrome

/// Toolbar chrome is capped at xxxLarge (like system bar items) and shows the large-content
/// viewer on long press at accessibility sizes instead of growing past the bar.
private let chromeTypeCap = DynamicTypeSize.xxxLarge

/// Toolbar icon button on Liquid Glass (gear, minimise).
struct GlassIconButton: View {
    var symbol: String
    var tint: Color?
    var accessibilityLabel: String?
    var action: () -> Void = {}

    init(_ symbol: String, tint: Color? = nil, accessibilityLabel: String? = nil, action: @escaping () -> Void = {}) {
        self.symbol = symbol
        self.tint = tint
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            GlassIconFace(symbol: symbol, tint: tint)
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...chromeTypeCap)
        .accessibilityLabel(accessibilityLabel ?? symbol)
        .accessibilityShowsLargeContentViewer {
            Label(accessibilityLabel ?? symbol, systemImage: symbol)
        }
    }
}

private struct GlassIconFace: View {
    var symbol: String
    var tint: Color?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(.body, weight: .semibold))
            .imageScale(.large)
            .foregroundStyle(tint ?? look.textPrimary)
            .frame(width: size, height: size)
            .glassEffect(.regular.interactive(), in: Circle())
    }
}

/// Toolbar text button on Liquid Glass (Finish, Done, Cancel).
struct GlassCapsuleButton: View {
    enum Role { case normal, destructive }
    var title: String
    var role: Role = .normal
    var action: () -> Void = {}

    init(_ title: String, role: Role = .normal, action: @escaping () -> Void = {}) {
        self.title = title
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            GlassCapsuleFace(title: title, role: role)
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...chromeTypeCap)
        .accessibilityShowsLargeContentViewer { Text(title) }
    }
}

private struct GlassCapsuleFace: View {
    var title: String
    var role: GlassCapsuleButton.Role
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        Text(title)
            .font(.system(.body, weight: look.id.isPaperClub ? .bold : .semibold))
            .foregroundStyle(role == .destructive ? look.destructive : look.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 18)
            .frame(minHeight: height)
            .glassEffect(.regular.interactive(), in: Capsule())
    }
}

/// Round icon buttons inside a card (previous performance, options).
/// The visual is 32 (Floodlight, a bare glyph) or 36 (the live workout, an outlined disc); the
/// hit area is 44 but takes only the visual's layout space, so a card title keeps its rhythm.
/// Glyphs are text styles, so they scale with Dynamic Type.
struct CardIconButton: View {
    var symbol: String
    var accessibilityLabel: String?
    var action: () -> Void = {}

    init(_ symbol: String, accessibilityLabel: String? = nil, action: @escaping () -> Void = {}) {
        self.symbol = symbol
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) { CardIconFace(symbol: symbol) }
            .buttonStyle(.lookPressable)
            .accessibilityLabel(accessibilityLabel ?? symbol)
    }
}

/// The face of a `CardIconButton`, also usable as a `Menu` label: the visual plus a 44 pt hit
/// area that takes no extra layout space.
struct CardIconFace: View {
    var symbol: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var discC: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var bareA: CGFloat = 32

    private var visual: CGFloat { look.id == .floodlight ? bareA : discC }

    var body: some View {
        let outset = max(0, (44 - visual) / 2)
        face
            .frame(width: visual, height: visual)
            .padding(outset)
            .contentShape(Rectangle())
            .padding(-outset)
    }

    @ViewBuilder private var face: some View {
        switch look.id {
        case .floodlight:
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        case .paper, .carbon:
            Image(systemName: symbol)
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(look.textPrimary)
                .frame(width: visual, height: visual)
                .overlay { Circle().strokeBorder(look.outline, lineWidth: 1.5) }
        }
    }
}

// MARK: - Make tiles

/// A dashed "make one" tile: New Template…, Ask AI for Templates (equal flat peers).
struct MakeTile: View {
    var title: String
    var symbol: String
    var action: () -> Void = {}
    @Environment(\.look) private var look

    init(title: String, symbol: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(.lookPressable)
            .accessibilityLabel(title)
    }

    @ViewBuilder private var content: some View {
        switch look.id {
        case .floodlight:
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: symbol).font(.system(.title3, weight: .semibold))
                Spacer(minLength: 12)
                Text(title).font(.system(.subheadline, weight: .semibold)).lineLimit(2)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .dashedOutline(look.dash, radius: look.radius.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile))
        case .paper, .carbon:
            VStack(spacing: 9) {
                IconDisc(symbol: symbol, size: 40, context: .make)
                Text(title).font(.system(.subheadline, weight: .semibold)).multilineTextAlignment(.center)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 118)
            .dashedOutline(look.outline, radius: look.radius.tile, lineWidth: 2, dash: [6, 4])
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile))
        }
    }
}

// MARK: - Destructive row

/// "Discard Workout…", "Delete Template". A: danger red-orange. B: no hue (pearl word + trash).
/// C: the double rule + trash in a solid disc (red means heart).
struct DestructiveRowButton: View {
    var title: String
    var symbol: String = "trash"
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 52
    @ScaledMetric(relativeTo: .headline) private var disc: CGFloat = 30

    init(_ title: String, symbol: String = "trash", action: @escaping () -> Void = {}) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(.lookPressable)
            .accessibilityLabel(title)
    }

    @ViewBuilder private var content: some View {
        switch look.id {
        case .floodlight:
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(title).font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(look.destructive)
            .frame(maxWidth: .infinity, minHeight: height)
            .lookSurface(.panel)
        case .paper, .carbon:
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.surface)
                    .frame(width: disc, height: disc)
                    .background(look.textPrimary, in: Circle())
                Text(title).font(look.font.button)
            }
            .foregroundStyle(look.textPrimary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(look.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(look.outline, lineWidth: 2) }
            .overlay { Capsule().inset(by: 4.5).strokeBorder(look.outline, lineWidth: 1.5) }
        }
    }
}
