import SwiftUI

// PROTOTYPE — shared pieces for the sheets over the live workout (L06–L12): one sheet chrome,
// a scroll container that honours the p2 / p3 capture variants, selectable rows and tiles,
// free-weight glyphs the SF set lacks, plate math and a few read-only Store helpers.
// Everything here is area-prefixed (LiveSheets…) so the integrator can promote it.

// MARK: - Capture variants

enum LiveSheetsVariant {
    /// The view-level variant for one of `screens` (e.g. "empty", "heartRate", "p2"), read once.
    /// It is cleared afterwards so a later, ordinary presentation opens in its default state.
    static func consume(_ screens: Set<ScreenID>, store: Store, router: Router) -> String? {
        guard let current = store.currentScreen, screens.contains(current), let variant = router.variant else { return nil }
        router.variant = nil
        return variant
    }

    /// "p2" / "p3" (alone or inside a compound variant such as "heartRate-p2").
    static func page(_ variant: String?) -> Int? {
        guard let variant else { return nil }
        if variant.contains("p3") { return 3 }
        if variant.contains("p2") { return 2 }
        return nil
    }

    static func has(_ variant: String?, _ flag: String) -> Bool {
        variant?.localizedCaseInsensitiveContains(flag) ?? false
    }
}

// MARK: - Sheet chrome

/// Cancel · Title · commit, one chrome for every live sheet. The leading button is glass
/// (Cancel or back), the trailing one is either glass "Done" (nothing to commit) or the
/// sheet's one filled command. At accessibility sizes the title leaves the bar and wraps.
struct LiveSheetsHeader: View {
    enum Leading {
        case none
        case cancel(() -> Void)
        case back(String, () -> Void)
    }
    enum Trailing {
        case none
        case done(() -> Void)
        case commit(String, enabled: Bool, action: () -> Void)
    }

    var title: String
    var subtitle: String?
    var leading: Leading = .none
    var trailing: Trailing = .none
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) { leadingButton; Spacer(minLength: 8); trailingButton }
                    titleBlock(alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ZStack {
                    titleBlock(alignment: .center)
                        .padding(.horizontal, 92)
                    HStack(spacing: 12) { leadingButton; Spacer(minLength: 8); trailingButton }
                }
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func titleBlock(alignment: HorizontalAlignment) -> some View {
        let ax = typeSize.isAccessibilitySize
        return VStack(alignment: alignment, spacing: 1) {
            // A long exercise name ("Machine Shoulder Press" in A's Expanded) wraps to a
            // second line rather than truncating.
            Text(title)
                .font(ax ? look.font.title3 : look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .lineLimit(ax ? nil : 2)
                .minimumScaleFactor(ax ? 1 : 0.9)
                .multilineTextAlignment(ax ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(look.textSecondary)
                    .lineLimit(ax ? nil : 2)
                    .multilineTextAlignment(ax ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var leadingButton: some View {
        switch leading {
        case .none:
            Color.clear.frame(width: 1, height: 44)
        case .cancel(let action):
            GlassCapsuleButton("Cancel", action: action)
        case .back(let label, let action):
            GlassIconButton("chevron.backward", accessibilityLabel: label, action: action)
        }
    }

    @ViewBuilder private var trailingButton: some View {
        switch trailing {
        case .none:
            Color.clear.frame(width: 1, height: 44)
        case .done(let action):
            GlassCapsuleButton("Done", action: action)
        case .commit(let title, let enabled, let action):
            LiveSheetsCommitButton(title: title, enabled: enabled, action: action)
        }
    }
}

/// The sheet's one filled command (A Ultra, B pearl, C cobalt with its ink outline).
struct LiveSheetsCommitButton: View {
    var title: String
    var enabled: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(look.font.button)
                .foregroundStyle(enabled ? look.onAction : look.textTertiary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 18)
                .frame(minHeight: height)
                .background(enabled ? look.action : look.surfaceRaised, in: Capsule())
                .overlay {
                    if look.id.isPaperClub && enabled { Capsule().strokeBorder(look.outline, lineWidth: 2) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .disabled(!enabled)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer { Text(title) }
    }
}

extension View {
    /// Sheet presentation shared by the live sheets: the look's sheet ground, a grabber, the
    /// look's sheet radius, and the prototype's Dynamic Type override (a sheet is its own
    /// presentation, so `-axl` / Z05 must be applied inside it).
    func liveSheetsPresentation(_ look: Look) -> some View {
        self
            .lookSheetGround()
            .modifier(LiveSheetsTypeOverride())
            .presentationBackground(look.groundSheet)
            .presentationCornerRadius(look.radius.sheet)
            .presentationDragIndicator(.visible)
    }
}

/// Applies `router.dynamicTypeOverride` inside a live sheet.
struct LiveSheetsTypeOverride: ViewModifier {
    @Environment(Router.self) private var router
    func body(content: Content) -> some View {
        if let size = router.dynamicTypeOverride { content.dynamicTypeSize(size) } else { content }
    }
}

// MARK: - Scroll container (p2 / p3 variants)

/// A vertical scroll view that, for the "p2" / "p3" capture variants, scrolls to its second or
/// third viewport once it has laid out, so reviewers can see the whole sheet.
struct LiveSheetsScroll<Content: View>: View {
    var page: Int?
    @ViewBuilder var content: Content
    @State private var position = ScrollPosition(edge: .top)
    @State private var viewport: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scheduled = false

    init(page: Int?, @ViewBuilder content: () -> Content) {
        self.page = page
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { contentHeight = geo.size.height; schedule() }
                            .onChange(of: geo.size.height) { _, h in contentHeight = h }
                    }
                }
        }
        .scrollPosition($position)
        .scrollDismissesKeyboard(.interactively)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewport = geo.size.height; schedule() }
                    .onChange(of: geo.size.height) { _, h in viewport = h }
            }
        }
        .onAppear { schedule() }
        .onChange(of: page) { schedule() }
    }

    /// Scrolls once, after the sheet has settled, to the requested viewport (clamped to the end).
    private func schedule() {
        guard !scheduled, let page, page > 1 else { return }
        scheduled = true
        // Again after the sheet has certainly settled: a scroll issued while the presentation
        // is still animating can be lost on a slow device.
        for delay in [0.9, 1.8, 2.8] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let height = viewport > 0 ? viewport : 700
                let maxOffset = contentHeight > 0 ? max(0, contentHeight - height) : .greatestFiniteMagnitude
                position.scrollTo(y: min(maxOffset, height * 0.82 * CGFloat(page - 1)))
            }
        }
    }
}

// MARK: - Selectable surfaces

extension Look {
    /// Label colour on a selectable tile (C fills a selected tile with cobalt).
    func liveSheetsChoiceText(_ selected: Bool) -> Color { id.isPaperClub && selected ? onAction : textPrimary }
    func liveSheetsChoiceSecondary(_ selected: Bool) -> Color { id.isPaperClub && selected ? onAction.opacity(0.86) : textSecondary }
}

/// A pressable tile that can be selected. Selection is a state, never the action colour's
/// "do this": A lights a flood outline, B a pearl outline on a lifted fill, C fills cobalt
/// (C's selected chip / segment).
struct LiveSheetsChoiceSurface: ViewModifier {
    var isSelected: Bool
    var radius: CGFloat?
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius ?? look.radius.tile, style: .continuous)
        let base = onSheet ? look.surfaceSheet : look.surface
        switch look.id {
        case .floodlight:
            content
                .background(isSelected ? look.surfaceRaised : base, in: shape)
                .overlay { shape.strokeBorder(isSelected ? look.textPrimary : look.hairline, lineWidth: isSelected ? 2 : 1) }
        case .anatomy:
            content
                .background(base, in: shape)
                .background { if isSelected { shape.fill(look.selectionFill) } }
                .overlay { shape.strokeBorder(isSelected ? look.textPrimary : look.hairline, lineWidth: isSelected ? 1.5 : 1) }
        case .paper, .carbon:
            content
                .background(isSelected ? look.action : base, in: shape)
                .overlay { shape.strokeBorder(look.outline, lineWidth: isSelected ? look.stroke.primary : look.stroke.pressable) }
        }
    }
}

extension View {
    func liveSheetsChoiceSurface(isSelected: Bool, radius: CGFloat? = nil) -> some View {
        modifier(LiveSheetsChoiceSurface(isSelected: isSelected, radius: radius))
    }
}

/// Rows inside a LookList highlight with the pressed fill (no scale, so lists don't wobble).
struct LiveSheetsRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.pressedFill : .clear)
            .contentShape(Rectangle())
    }
}

// MARK: - Glyphs

/// What a row's leading glyph draws: an SF Symbol, the machine weight stack, or one of the
/// free-weight glyphs SF Symbols lacks (so Barbell, Cable and Smith stop sharing `dumbbell`).
enum LiveSheetsGlyphKind: Hashable {
    case symbol(String)
    case machine
    case barbell
    case cable
    case smith

    static func of(_ tag: EquipmentTag) -> LiveSheetsGlyphKind {
        switch tag {
        case .machine: .machine
        case .barbell: .barbell
        case .dumbbell: .symbol("dumbbell")
        case .cable: .cable
        case .smith: .smith
        case .bodyweight: .symbol("figure.strengthtraining.functional")
        }
    }
}

/// Renders a glyph kind at a text style's size (custom shapes scale with Dynamic Type).
struct LiveSheetsGlyph: View {
    var kind: LiveSheetsGlyphKind
    var style: Font.TextStyle = .body
    @ScaledMetric private var side: CGFloat

    init(_ kind: LiveSheetsGlyphKind, style: Font.TextStyle = .body) {
        self.kind = kind
        self.style = style
        _side = ScaledMetric(wrappedValue: style == .title2 ? 24 : (style == .title3 ? 22 : 19), relativeTo: style)
    }

    var body: some View {
        switch kind {
        case .symbol(let name):
            Image(systemName: name).font(.system(style, weight: .semibold))
        case .machine:
            LookIcon(LookIcon.machine, style: style)
        case .barbell:
            shape(LiveSheetsBarbellShape())
        case .cable:
            shape(LiveSheetsCableShape())
        case .smith:
            shape(LiveSheetsSmithShape())
        }
    }

    private func shape<S: Shape>(_ s: S) -> some View {
        s.stroke(style: StrokeStyle(lineWidth: max(1.4, side * 0.085), lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

/// 24-unit grid helper for the custom glyphs.
private struct LiveSheetsGrid {
    let s: CGFloat, ox: CGFloat, oy: CGFloat
    init(_ rect: CGRect) {
        s = min(rect.width, rect.height) / 24
        ox = rect.midX - 12 * s
        oy = rect.midY - 12 * s
    }
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(origin: pt(x, y), size: CGSize(width: w * s, height: h * s))
    }
}

/// A barbell: the bar with two plates a side.
struct LiveSheetsBarbellShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = LiveSheetsGrid(rect)
        var p = Path()
        p.move(to: g.pt(1, 12)); p.addLine(to: g.pt(23, 12))
        p.addRoundedRect(in: g.rect(4, 5.5, 3, 13), cornerSize: CGSize(width: g.s, height: g.s))
        p.addRoundedRect(in: g.rect(17, 5.5, 3, 13), cornerSize: CGSize(width: g.s, height: g.s))
        p.addRoundedRect(in: g.rect(7.5, 8, 2, 8), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        p.addRoundedRect(in: g.rect(14.5, 8, 2, 8), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        return p
    }
}

/// A cable station: pulley, cable and a straight handle.
struct LiveSheetsCableShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = LiveSheetsGrid(rect)
        var p = Path()
        p.move(to: g.pt(12, 0.8)); p.addLine(to: g.pt(12, 2.5))
        p.addEllipse(in: g.rect(7.5, 2.5, 9, 9))
        p.addEllipse(in: g.rect(11, 6, 2, 2))
        p.move(to: g.pt(16.5, 7)); p.addLine(to: g.pt(16.5, 16.5))
        p.move(to: g.pt(16.5, 16.5)); p.addLine(to: g.pt(12.5, 20))
        p.move(to: g.pt(16.5, 16.5)); p.addLine(to: g.pt(20.5, 20))
        p.move(to: g.pt(10, 20.5)); p.addLine(to: g.pt(23, 20.5))
        return p
    }
}

/// A Smith machine: two rails and the guided bar with its plates.
struct LiveSheetsSmithShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = LiveSheetsGrid(rect)
        var p = Path()
        p.move(to: g.pt(5, 2)); p.addLine(to: g.pt(5, 22))
        p.move(to: g.pt(19, 2)); p.addLine(to: g.pt(19, 22))
        p.move(to: g.pt(2, 22)); p.addLine(to: g.pt(22, 22))
        p.move(to: g.pt(1.5, 10)); p.addLine(to: g.pt(22.5, 10))
        p.addRoundedRect(in: g.rect(7, 6.5, 2.4, 7), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        p.addRoundedRect(in: g.rect(14.6, 6.5, 2.4, 7), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        return p
    }
}

/// A glyph in the look's icon disc, for the top card of a sheet: A a raised disc, B the control
/// fill, C an outlined disc on the sheet ground.
struct LiveSheetsGlyphDisc: View {
    var kind: LiveSheetsGlyphKind
    var dashed = false
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 54

    var body: some View {
        LiveSheetsGlyph(kind, style: .title2)
            .foregroundStyle(dashed ? look.textSecondary : look.textPrimary)
            .frame(width: size, height: size)
            .background {
                switch look.id {
                case .floodlight: Circle().fill(look.surfaceRaised)
                case .anatomy: Circle().fill(look.controlFill)
                case .paper, .carbon:
                    Circle().fill(look.groundSheet)
                        .overlay {
                            Circle().strokeBorder(look.outline, style: StrokeStyle(lineWidth: 2, dash: dashed ? [5, 4] : []))
                        }
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Consequence line

/// The one short consequence line a sheet may carry. `emphasized` when the pending change
/// is the one it describes (it bumps once as it lights).
struct LiveSheetsNotice: View {
    var symbol: String
    var text: String
    var emphasized = false
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(.footnote, weight: .bold))
            Text(text)
                .font(.system(.footnote, weight: emphasized ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: look.radius.row, style: .continuous)
            switch look.id {
            case .floodlight:
                shape.fill(emphasized ? look.surfaceRaised : look.surfaceSheet)
            case .anatomy:
                shape.fill(emphasized ? look.selectionFill : look.controlFill.opacity(0.5))
            case .paper, .carbon:
                // Information, not a button: the sheet fill and the 1.5 pt rule (solid once
                // the change it describes is staged), never the pressable ink outline.
                shape.fill(look.surface)
                    .overlay {
                        shape.strokeBorder(look.hairline,
                                           style: StrokeStyle(lineWidth: 1.5, dash: emphasized ? [] : [4, 3]))
                    }
            }
        }
        .celebrate(emphasized)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Big stepper

/// A big number between two round − / + buttons (hold to repeat). The value is the bold
/// element; labels stay small. VoiceOver adjusts it like a stepper.
struct LiveSheetsBigStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int
    var unit: String?
    var isEnabled = true
    var accessibilityName: String
    var format: (Int) -> String
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var button: CGFloat = 48

    init(value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String? = nil, isEnabled: Bool = true,
         accessibilityName: String, format: @escaping (Int) -> String = { "\($0)" }) {
        _value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.isEnabled = isEnabled
        self.accessibilityName = accessibilityName
        self.format = format
    }

    private var primary: Color { onSlab ? look.onSlab : look.textPrimary }
    private var secondary: Color { onSlab ? look.onSlabSecondary : look.textSecondary }

    var body: some View {
        HStack(spacing: 10) {
            roundButton("minus", enabled: isEnabled && value - step >= range.lowerBound) { change(-step) }
            Spacer(minLength: 4)
            // The unit sits beside the number, or under it when both don't fit on one line
            // (accessibility sizes: "4:00" over "at the latest").
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) { number; unitText }
                VStack(spacing: 0) { number; unitText.multilineTextAlignment(.center) }
            }
            Spacer(minLength: 4)
            roundButton("plus", enabled: isEnabled && value + step <= range.upperBound) { change(step) }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue([format(value), unit].compactMap { $0 }.joined(separator: " "))
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: change(step)
            case .decrement: change(-step)
            @unknown default: break
            }
        }
    }

    private func change(_ delta: Int) {
        let next = min(range.upperBound, max(range.lowerBound, value + delta))
        guard next != value else { return }
        if reduceMotion { value = next } else { withAnimation(.snappy(duration: 0.22)) { value = next } }
    }

    private var number: some View {
        Text(format(value))
            .font(look.font.heroNumber)
            .foregroundStyle(isEnabled ? primary : secondary)
            .contentTransition(.numericText(value: Double(value)))
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder private var unitText: some View {
        if let unit {
            Text(unit)
                .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func roundButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        LiveSheetsRoundButton(symbol: symbol, enabled: enabled, size: button, action: action)
            .accessibilityHidden(true)
    }
}

/// A round − / + button (hold to repeat): A a raised disc, B the control fill, C an ink or
/// bone outline (bone on the slab).
struct LiveSheetsRoundButton: View {
    var symbol: String
    var enabled: Bool
    var size: CGFloat
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab

    private var primary: Color { onSlab ? look.onSlab : look.textPrimary }
    private var secondary: Color { onSlab ? look.onSlabSecondary : look.textSecondary }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(enabled ? primary : secondary.opacity(0.45))
                .frame(width: size, height: size)
                .background {
                    switch look.id {
                    case .floodlight: Circle().fill(onSlab ? look.wash(0.10) : look.surfaceRaised)
                    case .anatomy: Circle().fill(look.controlFill)
                    case .paper, .carbon:
                        Circle().fill(onSlab ? Color.clear : look.surface)
                            .overlay { Circle().strokeBorder(onSlab ? look.onSlab.opacity(enabled ? 0.9 : 0.3) : look.outline.opacity(enabled ? 1 : 0.35), lineWidth: 2) }
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.lookPressable)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
    }
}

// MARK: - Plate math (plain: bar + per side × 2 = total)

enum LiveSheetsPlates {
    /// Plates for one side, heaviest first (greedy; a remainder that no plate covers is left off).
    static func perSide(_ weight: Double, unit: WeightUnit) -> [Double] {
        let sizes: [Double] = unit == .lb ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
        var left = weight, plates: [Double] = []
        for size in sizes {
            while left + 1e-6 >= size && plates.count < 8 {
                plates.append(size)
                left -= size
            }
        }
        return plates
    }

    /// Plate height relative to the biggest plate.
    static func heightFraction(_ plate: Double, unit: WeightUnit) -> CGFloat {
        let top = unit == .lb ? 45.0 : 25.0
        return CGFloat(0.30 + 0.70 * min(1, plate / top))
    }

    /// Plate thickness side-on: heavier plates are wider.
    static func width(_ plate: Double, unit: WeightUnit) -> CGFloat {
        let table: [Double: CGFloat] = unit == .lb
            ? [45: 22, 35: 19, 25: 16, 10: 12, 5: 9, 2.5: 7]
            : [25: 22, 20: 20, 15: 17, 10: 14, 5: 10, 2.5: 8, 1.25: 6]
        return table[plate] ?? 7
    }

    /// Weight-coded tone: the heaviest plate is the look's full text colour, each lighter
    /// size a step fainter, so 45 + 5 never reads as one plate.
    static func tone(_ plate: Double, unit: WeightUnit) -> Double {
        let sizes: [Double] = unit == .lb ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
        let steps: [Double] = [1.0, 0.8, 0.64, 0.5, 0.38, 0.3, 0.24]
        return steps[min(steps.count - 1, sizes.firstIndex(of: plate) ?? steps.count - 1)]
    }
}

/// A side-on barbell with its plates, drawn from the per-side weight: the bar, a collar each
/// side and the plates stacked out along the sleeve, heaviest inside. Plates slide on and off
/// when the per-side weight changes (Reduce Motion: they swap in place).
struct LiveSheetsBarbellDiagram: View {
    var perSide: Double?
    var unit: WeightUnit
    var hasBar: Bool
    var height: CGFloat = 84
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sideWidth: CGFloat = 140
    private var plates: [Double] { hasBar ? LiveSheetsPlates.perSide(perSide ?? 0, unit: unit) : [] }
    private var steel: Color { look.id.isPaperClub ? look.textPrimary : look.textTertiary }

    var body: some View {
        HStack(spacing: 0) {
            side(mirrored: true)
            Capsule().fill(steel).frame(height: 6).frame(maxWidth: .infinity)
            side(mirrored: false)
        }
        .frame(height: height)
        .opacity(hasBar ? 1 : 0.3)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.72), value: plates)
        .accessibilityHidden(true)
    }

    private func side(mirrored: Bool) -> some View {
        let list = Array(plates.enumerated())
        return ZStack(alignment: mirrored ? .trailing : .leading) {
            // The sleeve the plates slide onto.
            Capsule().fill(steel.opacity(look.id.isPaperClub ? 1 : 0.8))
                .frame(width: sideWidth - 6, height: 11)
            HStack(spacing: 2) {
                if mirrored {
                    ForEach(list.reversed(), id: \.offset) { item in plate(item.element) }
                    collar
                } else {
                    collar
                    ForEach(list, id: \.offset) { item in plate(item.element) }
                }
            }
        }
        .frame(width: sideWidth, alignment: mirrored ? .trailing : .leading)
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 2.5).fill(steel).frame(width: 7, height: height * 0.34)
    }

    private func plate(_ weight: Double) -> some View {
        let h = height * LiveSheetsPlates.heightFraction(weight, unit: unit)
        let w = LiveSheetsPlates.width(weight, unit: unit)
        let shape = RoundedRectangle(cornerRadius: look.id == .anatomy ? 5 : 3, style: .continuous)
        return shape
            .fill(look.textPrimary.opacity(LiveSheetsPlates.tone(weight, unit: unit)))
            .overlay {
                if look.id.isPaperClub {
                    shape.strokeBorder(look.outline, lineWidth: 1.5)
                } else {
                    // The hub: a darker line down the middle so a plate reads as a disc side-on.
                    Rectangle().fill(Color.black.opacity(0.22)).frame(width: 1.5).padding(.vertical, h * 0.18)
                }
            }
            .frame(width: w, height: h)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity),
                                                               removal: .opacity))
    }
}

// MARK: - Read-only Store helpers

extension Store {
    /// The newest workout at a gym that trained this exercise: its date and best counted set.
    func liveSheetsLastLog(exerciseID: UUID, gymID: UUID?) -> (date: Date, best: SetValue?)? {
        for workout in history where gymID == nil || workout.gymID == gymID {
            let entries = workout.entries.filter { $0.exerciseID == exerciseID }
            guard !entries.isEmpty else { continue }
            let loadType = entries[0].loadType
            let best = Records.best(entries.flatMap { $0.countedSets.compactMap(\.value) }, loadType: loadType)
            return (workout.startedAt, best)
        }
        return nil
    }

    /// true when a live entry already uses this machine.
    func liveSheetsMachineInSession(_ machineID: UUID) -> Bool {
        session?.entries.contains { $0.machineID == machineID } ?? false
    }

    /// true when a live entry already logs this exercise.
    func liveSheetsExerciseInSession(_ exerciseID: UUID) -> Bool {
        session?.entries.contains { $0.exerciseID == exerciseID } ?? false
    }

    /// A live entry's equipment in words ("Chest Press 2", "Barbell"), nil when none is chosen.
    func liveSheetsEquipmentLabel(_ entry: LiveEntry) -> String? {
        if let machine = machine(entry.machineID) { return machine.label }
        return entry.freeWeightTag?.label
    }

    /// The row label for one live set: "Set 2" for working sets, else the kind ("Warmup").
    func liveSheetsSetLabel(entryID: UUID, setID: UUID) -> String {
        let marker = setMarker(entryID: entryID, setID: setID)
        if Int(marker) != nil { return "Set \(marker)" }
        return liveEntry(entryID)?.sets.first { $0.id == setID }?.type.displayName ?? "Set"
    }

    /// The newest workout that logged this exercise on this machine: its date and its best
    /// counted set there (any preset).
    func liveSheetsLastOnMachine(exerciseID: UUID, machineID: UUID) -> (date: Date, best: SetValue?)? {
        for workout in history {
            let entries = workout.entries.filter { $0.exerciseID == exerciseID && $0.machineID == machineID }
            guard !entries.isEmpty else { continue }
            let best = Records.best(entries.flatMap { $0.countedSets.compactMap(\.value) }, loadType: entries[0].loadType)
            return (workout.startedAt, best)
        }
        return nil
    }
}

// MARK: - Section header with the family mark

/// A list section's caption with its body area's colour mark (as on the Exercises tab: A a
/// bar, B a dot, C an outlined swatch), or a small glyph for non-family sections such as
/// "Recent at Iron Temple". Rows never carry a muscle mark; only the section does.
struct LiveSheetsSectionHeader: View {
    var title: String
    var family: MuscleFamily?
    var symbol: String?
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.textSecondary)
                    .accessibilityHidden(true)
            } else if look.id != .anatomy {
                // B keeps family colour for summaries only, so its list headers stay neutral.
                LiveSheetsFamilyMark(family: family)
            }
            Text(title)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The family's colour as a small mark beside its section title; a body area outside the five
/// families (Core, Neck, Full Body, Uncategorized) gets the same mark hollow.
struct LiveSheetsFamilyMark: View {
    var family: MuscleFamily?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 13

    var body: some View {
        let color = family.map { look.family($0) } ?? .clear
        Group {
            switch look.id {
            case .floodlight:
                let shape = RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                shape.fill(color)
                    .overlay { if family == nil { shape.strokeBorder(look.textTertiary, lineWidth: 1.25) } }
                    .frame(width: max(4, height * 0.32), height: height)
            case .anatomy:
                Circle().fill(color)
                    .overlay { if family == nil { Circle().strokeBorder(look.textTertiary, lineWidth: 1.25) } }
                    .frame(width: height * 0.62, height: height * 0.62)
            case .paper, .carbon:
                let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
                shape.fill(color)
                    .overlay {
                        if family == nil {
                            shape.strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.25, dash: [2.5, 2]))
                        } else {
                            shape.strokeBorder(look.outline, lineWidth: 1.25)
                        }
                    }
                    .frame(width: height * 0.72, height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

extension String {
    /// nil for an empty string (joins of optional parts).
    var liveSheetsNilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Flow layout (chips that wrap)

/// Lays chips out left to right and wraps them onto new lines (preset chips, bar tiles at AX).
struct LiveSheetsFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let width = min(size.width, maxWidth)
            if x > 0 && x + width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let width = min(size.width, bounds.width)
            if x > bounds.minX && x + width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: size.height))
            x += width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Option row (one choice in a list)

/// A choice inside a LookList: glyph, title, subtitle, and the selection mark. Selection is a
/// state: A / B light the row with the selection lozenge fill and a flood / pearl check;
/// C washes it cobalt and stamps a cobalt disc.
struct LiveSheetsOptionRow: View {
    var glyph: LiveSheetsGlyphKind
    var title: String
    var subtitle: String?
    var badge: String?
    var isSelected: Bool
    var trailingSymbol: String?
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 26

    init(glyph: LiveSheetsGlyphKind, title: String, subtitle: String? = nil, badge: String? = nil,
         isSelected: Bool, trailingSymbol: String? = nil, action: @escaping () -> Void) {
        self.glyph = glyph
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.isSelected = isSelected
        self.trailingSymbol = trailingSymbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LiveSheetsGlyph(glyph)
                    .foregroundStyle(isSelected || look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                    .frame(width: glyphColumn)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.system(.body, design: look.id == .anatomy ? .rounded : .default,
                                          weight: isSelected ? .bold : (look.id.isPaperClub ? .medium : .semibold)))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let badge {
                            Text(badge)
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(look.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .overlay { Capsule().strokeBorder(look.id.isPaperClub ? look.outline : look.hairline, lineWidth: 1) }
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let trailingSymbol, !isSelected {
                    Image(systemName: trailingSymbol)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                }
                mark
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 54 : 62, alignment: .leading)
            .background(isSelected ? selectedFill : Color.clear)
        }
        .buttonStyle(LiveSheetsRowPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedFill: Color {
        look.id.isPaperClub ? look.actionText.opacity(look.isDark ? 0.16 : 0.10) : look.selectionFill
    }

    @ViewBuilder private var mark: some View {
        if isSelected {
            if look.id.isPaperClub {
                Image(systemName: "checkmark")
                    .font(.system(size: disc * 0.5, weight: .heavy))
                    .foregroundStyle(look.onAction)
                    .frame(width: disc, height: disc)
                    .background(look.action, in: Circle())
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Image(systemName: "checkmark")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(look.selection)
                    .frame(width: disc, height: disc)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Settings switches (Floodlight keeps Ultra for the one action)

/// The switch used on the live sheets. Floodlight's Ultra means "the one action or the live
/// thing", so its switches are lit flood (a flood track with an ink thumb) and Save stays the
/// only Ultra; B and C use the look's own switch.
struct LiveSheetsToggleStyle: ToggleStyle {
    @Environment(\.look) private var look

    func makeBody(configuration: Configuration) -> some View {
        if look.id == .floodlight {
            LiveSheetsFloodSwitch(configuration: configuration)
        } else {
            Toggle(configuration).toggleStyle(.look)
        }
    }
}

private struct LiveSheetsFloodSwitch: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let on = configuration.isOn
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(on ? look.textPrimary : look.controlFill)
                    .overlay { Capsule().strokeBorder(on ? Color.clear : look.hairline, lineWidth: 1) }
                Circle().fill(on ? look.onAction : look.textSecondary)
                    .padding(3)
                    .frame(width: 31, height: 31)
            }
            .frame(width: 51, height: 31)
            .opacity(isEnabled ? 1 : 0.4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            if reduceMotion { configuration.isOn.toggle() } else {
                withAnimation(.snappy(duration: 0.2)) { configuration.isOn.toggle() }
            }
        }
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// LookToggleRow with the live sheets' switch.
struct LiveSheetsToggleRow: View {
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
        .toggleStyle(LiveSheetsToggleStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }
}

// MARK: - Model captions (the hardware in as few words as it takes)

extension Store {
    /// The manufacturer + series most machines at this gym share ("Life Fitness Insignia
    /// Series"), so rows can drop it and keep only what tells machines apart.
    func liveSheetsDominantSeries(gymID: UUID?) -> (manufacturer: String, series: String?)? {
        let models = activeMachines(gymID: gymID).compactMap { model($0.modelID) }
        guard models.count >= 3 else { return nil }
        let byMaker = Dictionary(grouping: models, by: \.manufacturer)
        guard let (maker, items) = byMaker.max(by: { $0.value.count < $1.value.count }), items.count * 2 >= models.count else { return nil }
        // A shared leading "<Name> Series" in the model names.
        let series: String? = {
            let prefixes = items.compactMap { m -> String? in
                guard let r = m.modelName.range(of: " Series ") else { return nil }
                return String(m.modelName[..<r.upperBound])
            }
            guard let first = prefixes.first, prefixes.filter({ $0 == first }).count * 2 >= items.count else { return nil }
            return first
        }()
        return (maker, series)
    }

    /// The row caption for a machine: its model minus the gym's dominant brand and series, and
    /// nothing at all when what is left only repeats the machine's own label ("Chest Press" on
    /// "Chest Press 2") or there is no model.
    func liveSheetsModelCaption(_ machine: Machine, gymID: UUID?) -> String? {
        guard let model = model(machine.modelID) else { return nil }
        var text = model.displayName
        if let dominant = liveSheetsDominantSeries(gymID: gymID), model.manufacturer == dominant.manufacturer {
            text = model.modelName
            if let series = dominant.series, text.hasPrefix(series) { text = String(text.dropFirst(series.count)) }
        }
        func letters(_ s: String) -> String { s.lowercased().filter(\.isLetter) }
        let rest = letters(text), label = letters(machine.label)
        if rest.isEmpty || label.contains(rest) || rest.contains(label) { return nil }
        return text
    }
}

extension LiveSheetsGlyphKind {
    /// The glyph a machine's catalog category earns (plate-loaded hardware draws plates, a
    /// cable station its pulley); selectorized and unknown machines are the weight stack.
    static func of(_ category: EquipmentCategory?) -> LiveSheetsGlyphKind {
        switch category {
        case .plateLoaded: .barbell
        case .cable: .cable
        case .rackOrSmith: .smith
        case .bodyweight: .symbol("figure.strengthtraining.functional")
        case .selectorized, nil: .machine
        }
    }

    /// For each item, its glyph only when it differs from the list's most common glyph (the
    /// section norm), so a column of identical icons never appears.
    static func exceptions(_ kinds: [LiveSheetsGlyphKind]) -> [LiveSheetsGlyphKind?] {
        let counts = Dictionary(kinds.map { ($0, 1) }, uniquingKeysWith: +)
        guard let norm = counts.max(by: { a, b in a.value != b.value ? a.value < b.value : b.key == .machine })?.key else { return kinds.map { _ in nil } }
        return kinds.map { $0 == norm ? nil : $0 }
    }
}

/// The plates on one side, heaviest first, as small chips in their diagram tone ("45", "5").
struct LiveSheetsPlateList: View {
    var plates: [Double]
    var unit: WeightUnit
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(look.textPrimary.opacity(LiveSheetsPlates.tone(plate, unit: unit)))
                        .overlay {
                            if look.id.isPaperClub {
                                RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(look.outline, lineWidth: 1)
                            }
                        }
                        .frame(width: 5, height: 14 * LiveSheetsPlates.heightFraction(plate, unit: unit) + 4)
                    Text(Format.weight(plate))
                        .font(.system(.footnote, weight: .bold).monospacedDigit())
                        .foregroundStyle(look.textPrimary)
                }
                .padding(.horizontal, 8)
                .frame(minHeight: 26)
                .background(Capsule().fill(look.id.isPaperClub ? look.groundSheet : look.surfaceRaised))
                .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.hairline, lineWidth: 1) } }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plates per side: " + plates.map { Format.weight($0, unit) }.joined(separator: ", "))
    }
}
