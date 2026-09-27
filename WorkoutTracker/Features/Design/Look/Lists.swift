import SwiftUI

// Lists, rows and small controls. Rows are ≥ 44 pt; groups are one surface with hairline
// separators. Selection is a state (A: white lozenge, B: white lozenge + pearl, C: cobalt).

// MARK: - Grouped list

/// A grouped section: one surface, hairline separators inset from the leading edge.
struct LookList<Content: View>: View {
    var header: String?
    var footer: String?
    var separatorInset: CGFloat = 16
    @ViewBuilder var content: Content
    @Environment(\.look) private var look

    init(header: String? = nil, footer: String? = nil, separatorInset: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = footer
        self.separatorInset = separatorInset
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                Text(header)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                        if index > 0 { LookDivider().padding(.leading, separatorInset) }
                        subview
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
            .lookSurface(.panel)
            if let footer {
                Text(footer)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// A list row: optional glyph, title / subtitle, trailing value or view, chevron.
struct LookRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var symbol: String?
    var symbolTint: Color?
    var showsChevron: Bool
    var action: (() -> Void)?
    @ViewBuilder var trailing: Trailing
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    /// `symbol` is an SF Symbol name or `LookIcon.machine`.
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, symbolTint: Color? = nil,
         showsChevron: Bool = true, action: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.symbolTint = symbolTint
        self.showsChevron = showsChevron
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        if let action {
            Button(action: action) { row }.buttonStyle(RowPressStyle())
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            if let symbol {
                LookIcon(symbol, style: .body)
                    .foregroundStyle(symbolTint ?? (look.id.isPaperClub ? look.textPrimary : look.textSecondary))
                    .frame(width: glyphColumn)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: look.id == .floodlight ? .semibold : .medium))
                    .foregroundStyle(look.textPrimary)
                if let subtitle {
                    Text(subtitle).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 50 : 60, alignment: .leading)
        .contentShape(Rectangle())
    }
}

extension LookRow where Trailing == LookRowValue {
    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, symbolTint: Color? = nil, value: String? = nil,
         showsChevron: Bool = true, action: (() -> Void)? = nil) {
        self.init(title, subtitle: subtitle, symbol: symbol, symbolTint: symbolTint, showsChevron: showsChevron, action: action) {
            LookRowValue(text: value)
        }
    }
}

struct LookRowValue: View {
    var text: String?
    @Environment(\.look) private var look
    var body: some View {
        if let text {
            Text(text).font(look.font.subhead).monospacedDigit().foregroundStyle(look.textSecondary)
        }
    }
}

/// Rows highlight with the pressed fill (no scale, so lists don't wobble).
private struct RowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.pressedFill : .clear)
    }
}

// MARK: - Chips

struct Chip: View {
    var title: String
    var symbol: String?
    var isSelected = false
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 34

    init(_ title: String, symbol: String? = nil, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.symbol = symbol
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { LookIcon(symbol, style: .footnote) }
                Text(title).font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background(fill, in: Capsule())
            .overlay { Capsule().strokeBorder(edge, lineWidth: look.id.isPaperClub ? 1.5 : 1) }
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        switch look.id {
        case .floodlight: isSelected ? look.selection : look.textSecondary
        case .paper, .carbon: isSelected ? look.onAction : look.textPrimary
        }
    }
    private var fill: Color {
        switch look.id {
        case .floodlight: isSelected ? look.segmentFill : .clear
        case .paper, .carbon: isSelected ? look.action : look.surface
        }
    }
    private var edge: Color {
        switch look.id {
        case .floodlight: isSelected ? .clear : look.hairline
        case .paper, .carbon: look.outline
        }
    }
}

// MARK: - Search

struct SearchFieldView: View {
    @Binding var text: String
    var prompt: String = "Search"
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    init(text: Binding<String>, prompt: String = "Search") {
        _text = text
        self.prompt = prompt
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(look.textTertiary))
                .font(look.font.body)
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(look.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -12)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: height)
        .background(searchFill, in: Capsule())
        .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.outline, lineWidth: 1.5) } }
    }

    private var searchFill: Color {
        switch look.id {
        case .floodlight: look.surfaceRaised
        case .paper, .carbon: look.surface
        }
    }
}

// MARK: - Toggle row

struct LookToggleRow: View {
    var title: String
    var subtitle: String?
    @Binding var isOn: Bool
    @Environment(\.look) private var look

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
                if let subtitle { Text(subtitle).font(look.font.footnote).foregroundStyle(look.textSecondary) }
            }
        }
        .toggleStyle(.look)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }
}

/// The look's switch: the system switch tinted with the action colour.
struct LookToggleStyle: ToggleStyle {
    @Environment(\.look) private var look

    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration).toggleStyle(.switch).tint(look.action)
    }
}

extension ToggleStyle where Self == LookToggleStyle {
    static var look: LookToggleStyle { LookToggleStyle() }
}

// MARK: - Stepper pill

/// − value + in a capsule (rest defaults, targets). Buttons are 44 pt.
struct NumberStepperPill: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int = 1
    var format: (Int) -> String = { "\($0)" }
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, format: @escaping (Int) -> String = { "\($0)" }) {
        _value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", enabled: value - step >= range.lowerBound) { value = max(range.lowerBound, value - step) }
            Text(format(value))
                .font(look.id == .floodlight ? Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit() : look.font.fieldNumber)
                .foregroundStyle(look.textPrimary)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(value)))
                .frame(minWidth: 56)
                .animation(reduceMotion ? nil : .snappy, value: value)
            stepButton("plus", enabled: value + step <= range.upperBound) { value = min(range.upperBound, value + step) }
        }
        .background(fill, in: Capsule())
        .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.outline, lineWidth: 1.5) } }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private var fill: Color {
        switch look.id {
        case .floodlight: look.surfaceRaised
        case .paper, .carbon: look.surface
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(enabled ? look.textPrimary : look.textTertiary.opacity(0.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .disabled(!enabled)
    }
}

// MARK: - Segmented pills

/// A styled segmented control (Lifting | Cardio, metric pickers).
struct SegmentedPills: View {
    var options: [String]
    @Binding var selection: Int
    @Namespace private var namespace
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 38 + 3 pt track padding each side = 44 pt segments.
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 38

    init(_ options: [String], selection: Binding<Int>) {
        self.options = options
        _selection = selection
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let selected = index == selection
                Button {
                    if reduceMotion { selection = index } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = index }
                    }
                } label: {
                    Text(option)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(selected ? selectedText : look.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background {
                            if selected {
                                Capsule().fill(selectedFill)
                                    .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.outline, lineWidth: 1.5) } }
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(trackFill, in: Capsule())
        .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.hairline, lineWidth: 1.5) } }
        .frame(minHeight: 44)
    }

    private var trackFill: Color {
        switch look.id {
        case .floodlight: look.surface
        case .paper, .carbon: look.ground
        }
    }
    private var selectedFill: Color {
        switch look.id {
        case .floodlight: look.segmentFill
        case .paper, .carbon: look.action
        }
    }
    private var selectedText: Color { look.id.isPaperClub ? look.onAction : look.selection }
}

// MARK: - Empty state

struct EmptyStateView: View {
    var symbol: String
    var title: String
    /// One short consequence line at most (no helper paragraphs).
    var message: String?
    var actionTitle: String?
    var action: () -> Void = {}
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .title2) private var disc: CGFloat = 72

    init(symbol: String, title: String, message: String? = nil, actionTitle: String? = nil, action: @escaping () -> Void = {}) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            LookIcon(symbol, style: .title2)
                .foregroundStyle(look.id == .floodlight ? look.textSecondary : look.textPrimary)
                .frame(width: disc, height: disc)
                .background {
                    switch look.id {
                    case .floodlight: Circle().fill(look.surface).overlay { Circle().strokeBorder(look.hairline, lineWidth: 1) }
                    case .paper, .carbon: Circle().fill(look.surface).overlay { Circle().strokeBorder(look.outline, lineWidth: 2) }
                    }
                }
            Text(title)
                .font(look.font.title3)
                .foregroundStyle(look.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.lookSecondary)
                    .frame(maxWidth: 260)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sheet header

/// Cancel · Title · Commit for form sheets. Cancel is glass chrome; the commit is the
/// sheet's one filled command (A Ultra, B pearl, C cobalt with its outline).
struct SheetHeader: View {
    var title: String
    var cancelTitle = "Cancel"
    var commitTitle = "Save"
    var commitEnabled = true
    /// The commit button's accessibility identifier (UI tests find Save by it).
    var commitIdentifier: String?
    /// At accessibility sizes the title leaves the bar and becomes the first line under the
    /// buttons (a long title ran into Cancel and Save — ticket 06's Edit Gym).
    var reflowsTitle = false
    var cancel: () -> Void = {}
    var commit: () -> Void = {}
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    init(cancel: @escaping () -> Void = {}, title: String, commit: @escaping () -> Void = {},
         cancelTitle: String = "Cancel", commitTitle: String = "Save", commitEnabled: Bool = true,
         commitIdentifier: String? = nil, reflowsTitle: Bool = false) {
        self.commitIdentifier = commitIdentifier
        self.reflowsTitle = reflowsTitle
        self.cancel = cancel
        self.title = title
        self.commit = commit
        self.cancelTitle = cancelTitle
        self.commitTitle = commitTitle
        self.commitEnabled = commitEnabled
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if reflowsTitle && typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    buttons
                    Text(title)
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ZStack {
                    Text(title)
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 100)
                        .accessibilityAddTraits(.isHeader)
                    buttons
                }
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var buttons: some View {
        HStack {
            GlassCapsuleButton(cancelTitle, action: cancel)
            Spacer()
            Button(action: commit) {
                Text(commitTitle)
                    .font(look.font.button)
                    .foregroundStyle(commitEnabled ? look.onAction : look.textTertiary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: height)
                    .background(commitEnabled ? look.action : look.surfaceRaised, in: Capsule())
                    .overlay {
                        if look.id.isPaperClub && commitEnabled { Capsule().strokeBorder(look.outline, lineWidth: 2) }
                    }
            }
            .buttonStyle(.lookPressable)
            .disabled(!commitEnabled)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer { Text(commitTitle) }
            .accessibilityIdentifier(commitIdentifier ?? commitTitle)
        }
    }
}

// MARK: - Large title

/// The screen's large title with its subtitle (the date on Home). B puts the subtitle
/// above the title; A and C below it.
struct LookNavTitle: View {
    var title: String
    var subtitle: String?
    @Environment(\.look) private var look

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(look.font.largeTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle { subtitleText(subtitle) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subtitleText(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, weight: look.id == .floodlight ? .regular : .semibold))
            .foregroundStyle(look.textSecondary)
    }
}

