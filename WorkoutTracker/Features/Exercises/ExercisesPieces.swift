import SwiftUI

// Floodlight ticket 08 — pieces shared by the Exercises screens (E01–E05): the family colour
// mark (section headers only — never a muscle icon per row), the family filter strip, the best
// value, tags, choice tiles and chips, the load-type grid, the sheet header and chrome, the
// refused-entry line and the equipment glyphs. Ported from the prototype's Floodlight branch.

// MARK: - Family colour mark and section header

/// A lit bar in the family's colour. No family (Core, Neck, Full Body, Uncategorized) keeps the
/// slot empty so titles align.
struct ExercisesFamilyMark: View {
    var family: MuscleFamily?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(family.map { look.family($0) } ?? .clear)
            .frame(width: max(5, height * 0.32), height: height)
            .accessibilityHidden(true)
    }
}

struct ExercisesSectionHeader: View {
    var title: String
    var family: MuscleFamily?
    var showsMark = true
    var count: Int?
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if showsMark { ExercisesFamilyMark(family: family) }
            Text(title)
                .font(look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
            Spacer(minLength: 8)
            if let count {
                Text(verbatim: "\(count)")
                    .font(.system(.footnote, weight: .semibold).monospacedDigit())
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.map { "\(title), \($0) exercise\($0 == 1 ? "" : "s")" } ?? title)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Family filter strip (E01's bold element)

/// The five families as map tiles. Tap one to show only its exercises: it stays lit and washes in
/// its colour, the others go unlit. Tap it again to show everything. Two columns at AX sizes.
struct ExercisesFamilyStrip: View {
    @Binding var selection: MuscleFamily?
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var axMap: CGFloat = 34
    /// Families lit so far by the entry motion (head to toe once; Reduce Motion: at once). Kept here
    /// so a filter chosen during the entry motion is never overridden by it.
    @State private var awake: Set<MuscleFamily> = []

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(MuscleFamily.allCases) { tile($0, stacked: false) }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(MuscleFamily.allCases) { tile($0, stacked: true) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            guard awake.isEmpty else { return }
            if reduceMotion { awake = Set(MuscleFamily.allCases); return }
            for (index, family) in MuscleFamily.allCases.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + 0.07 * Double(index)) { awake.insert(family) }
            }
        }
    }

    private func tile(_ family: MuscleFamily, stacked: Bool) -> some View {
        let selected = selection == family
        let lit = awake.contains(family) && (selection == nil || selected)
        let shape = RoundedRectangle(cornerRadius: look.radius.row + 2, style: .continuous)
        return Button {
            if reduceMotion { selection = selected ? nil : family } else {
                withAnimation(.snappy(duration: 0.3)) { selection = selected ? nil : family }
            }
        } label: {
            Group {
                if stacked {
                    VStack(spacing: 5) {
                        MuscleMap(family: family, lit: lit, size: 46)
                        name(family, lit: selection == nil || selected)
                    }
                    .padding(.top, 9)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 10) {
                        MuscleMap(family: family, lit: lit, size: axMap)
                        name(family, lit: selection == nil || selected)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }
            }
            .background(selected ? look.familyTint(family) : look.surface, in: shape)
            .overlay {
                shape.strokeBorder(selected ? look.textPrimary : look.hairline, lineWidth: selected ? 2 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(family.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(selected ? "Shows every body area" : "Shows only \(family.label)")
        .accessibilityIdentifier("exerciseFamily.\(family.rawValue)")
    }

    private func name(_ family: MuscleFamily, lit: Bool) -> some View {
        Text(family.label)
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(lit ? look.textPrimary : look.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Best value

/// A best set, formatted by load type (`ExerciseValueText`). `marked`: the latest session set it
/// (the new-best burst before it); otherwise plain.
struct ExercisesBestValue: View {
    enum Style { case row, hero }
    var value: SetValue
    var loadType: LoadType
    var userUnit: WeightUnit?
    var style: Style = .row
    var marked = false
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: style == .hero ? 10 : 6) {
            if marked {
                Image(systemName: "burst.fill")
                    .font(style == .hero ? .system(.title2, weight: .bold) : .system(.caption, weight: .bold))
                    .foregroundStyle(look.positive)
            }
            Text(ExerciseValueText.label(value, loadType: loadType, userUnit: userUnit, alwaysUnit: style == .hero))
                .font(style == .hero ? look.font.heroNumber : look.exercisesRowValue)
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(marked ? "New best, set last session, \(ExerciseValueText.spoken(value, loadType: loadType))"
                                   : "Best \(ExerciseValueText.spoken(value, loadType: loadType))")
    }
}

/// One logged set in a history line, at one size for every set. Warmups are dim with their "W";
/// a new best carries the burst.
struct ExercisesSetText: View {
    var value: SetValue
    var type: SetType
    var loadType: LoadType
    var userUnit: WeightUnit?
    var isNewBest: Bool
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 3) {
            if isNewBest {
                Image(systemName: "burst.fill").font(.system(.caption2, weight: .bold)).foregroundStyle(look.positive)
            }
            if type == .warmup {
                Text(verbatim: "W").font(.system(.caption2, weight: .heavy)).foregroundStyle(look.textTertiary)
            }
            Text(ExerciseValueText.label(value, loadType: loadType, userUnit: userUnit))
                .font(.system(.footnote, weight: isNewBest ? .heavy : .semibold).monospacedDigit())
                .foregroundStyle(isNewBest ? look.textPrimary : (type == .warmup ? look.textTertiary : look.textSecondary))
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((isNewBest ? "New best, " : "") + (type == .warmup ? "Warmup, " : "")
                            + ExerciseValueText.spoken(value, loadType: loadType))
    }
}

// MARK: - Tag

/// A small label (equipment, load type, Custom): information, never a control.
struct ExercisesTag: View {
    var text: String
    var symbol: String?
    @Environment(\.look) private var look

    init(_ text: String, symbol: String? = nil) {
        self.text = text
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(.caption2, weight: .bold)) }
            Text(text).font(.system(.caption, weight: .semibold))
        }
        .foregroundStyle(look.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(look.surfaceRaised))
        .fixedSize()
    }
}

// MARK: - Choices

/// A selectable tile: selection is a state — a lifted fill with a bright outline.
private struct ExercisesChoiceSurface: ViewModifier {
    var isSelected: Bool
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous)
        content
            .background(isSelected ? look.surfaceRaised : (onSheet ? look.surfaceSheet : look.surface), in: shape)
            .overlay { shape.strokeBorder(isSelected ? look.textPrimary : look.hairline, lineWidth: isSelected ? 2 : 1) }
    }
}

/// The four load types as tiles (2 × 2; one column at AX sizes), then the selected type's one
/// consequence line with the way its records rank.
struct ExercisesLoadTypeGrid: View {
    @Binding var selection: LoadType
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let columns = typeSize.isAccessibilitySize ? [GridItem(.flexible())]
                : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(LoadType.allCases, id: \.self) { tile($0) }
            }
            ExercisesNotice(symbol: selection.rankSymbol, text: selection.consequence)
                .id(selection)
                .transition(.opacity)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tile(_ type: LoadType) -> some View {
        let selected = type == selection
        return Button {
            if reduceMotion { selection = type } else { withAnimation(.snappy(duration: 0.22)) { selection = type } }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: type.pickerSymbol)
                    .font(.system(.title3, weight: .semibold))
                Text(type.badge)
                    .font(.system(.headline, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(look.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .modifier(ExercisesChoiceSurface(isSelected: selected))
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(look.textPrimary)
                        .padding(12)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(type.badge)
        .accessibilityValue(type == .assisted ? "Lower is better" : "Higher is better")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("loadType.\(type.rawValue)")
    }
}

/// One consequence line (the selected load type's).
struct ExercisesNotice: View {
    var symbol: String
    var text: String
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.system(.footnote, weight: .bold))
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(look.textSecondary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A selectable chip with an optional leading view (a family mark or an equipment glyph).
struct ExercisesSelectChip<Leading: View>: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    @ViewBuilder var leading: Leading
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36

    init(_ title: String, isSelected: Bool, action: @escaping () -> Void, @ViewBuilder leading: () -> Leading) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.leading = leading()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                leading
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
                if isSelected {
                    Image(systemName: "checkmark").font(.system(.caption, weight: .heavy))
                }
            }
            .foregroundStyle(isSelected ? look.selection : look.textSecondary)
            .padding(.horizontal, 13)
            .frame(minHeight: height)
            .background(isSelected ? look.segmentFill : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(isSelected ? look.textPrimary.opacity(0.9) : look.hairline, lineWidth: isSelected ? 1.5 : 1) }
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Row press

struct ExercisesRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.pressedFill : .clear)
            .contentShape(Rectangle())
    }
}

// MARK: - Sheet chrome

/// Leading glass Cancel · title (and the exercise under it) · trailing glass Done or the sheet's
/// one filled command. At AX sizes the title leaves the bar and wraps.
struct ExercisesSheetHeader: View {
    enum Trailing {
        case done(() -> Void)
        case commit(String, enabled: Bool, identifier: String, action: () -> Void)
    }

    var title: String
    var subtitle: String?
    var cancel: (() -> Void)?
    var trailing: Trailing
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) { leadingButton; Spacer(minLength: 8); trailingButton }
                    titleBlock(.leading).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ZStack {
                    titleBlock(.center).padding(.horizontal, 96)
                    HStack(spacing: 12) { leadingButton; Spacer(minLength: 8); trailingButton }
                }
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func titleBlock(_ alignment: HorizontalAlignment) -> some View {
        let ax = typeSize.isAccessibilitySize
        return VStack(alignment: alignment, spacing: 1) {
            Text(title)
                .font(ax ? look.font.title3 : look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .lineLimit(ax ? nil : 2)
                .minimumScaleFactor(ax ? 1 : 0.85)
                .multilineTextAlignment(ax ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(look.textSecondary)
                    .lineLimit(ax ? nil : 1)
                    .multilineTextAlignment(ax ? .leading : .center)
            }
        }
    }

    @ViewBuilder private var leadingButton: some View {
        if let cancel { GlassCapsuleButton("Cancel", action: cancel) } else { Color.clear.frame(width: 1, height: 1) }
    }

    @ViewBuilder private var trailingButton: some View {
        switch trailing {
        case .done(let action):
            GlassCapsuleButton("Done", action: action)
        case .commit(let title, let enabled, let identifier, let action):
            Button(action: action) {
                ExercisesCommitFace(title: title, enabled: enabled, minHeight: height, horizontalPadding: 18)
            }
            .buttonStyle(.lookPressable)
            .disabled(!enabled)
            .animation(.easeOut(duration: 0.15), value: enabled)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer { Text(title) }
            .accessibilityIdentifier(identifier)
        }
    }
}

/// A sheet's commit capsule: the filled command, or a quiet capsule when off.
struct ExercisesCommitFace: View {
    var title: String
    var enabled: Bool
    var minHeight: CGFloat
    var horizontalPadding: CGFloat = 20
    @Environment(\.look) private var look

    var body: some View {
        Text(title)
            .font(look.font.button)
            .foregroundStyle(enabled ? look.onAction : look.textSecondary)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minHeight)
            .background(enabled ? look.action : look.surfaceRaised, in: Capsule())
            .opacity(enabled ? 1 : 0.55)
            .contentShape(Capsule())
    }
}

extension View {
    /// A sheet's root: the sheet ground, the drag indicator, and — `fitted`, the measured content
    /// height — a short detent at exactly that height (drag up for the full height) so a small
    /// choice keeps its exercise in view. AX sizes, or content taller than the screen: full height.
    func exercisesSheetChrome(fitted: CGFloat? = nil) -> some View {
        modifier(ExercisesSheetChrome(fitted: fitted))
    }

    /// Reports a view's height (for a fitted sheet).
    func exercisesMeasureHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { new in
            if abs(height.wrappedValue - new) > 0.5 { height.wrappedValue = new }
        }
    }

    /// Reports a scroll view's content height (for a fitted sheet).
    func exercisesMeasureContent(_ height: Binding<CGFloat>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, new in
            if abs(height.wrappedValue - new) > 0.5 { height.wrappedValue = new }
        }
    }

    /// The refused-entry edge on a field.
    func exercisesFieldError(_ isError: Bool) -> some View {
        modifier(ExercisesFieldErrorEdge(isError: isError))
    }
}

private struct ExercisesSheetChrome: ViewModifier {
    var fitted: CGFloat?
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var expanded = false

    func body(content: Content) -> some View {
        // Whole points, so a sub-point re-measure never re-seats the sheet.
        let height = fitted.map { ($0 + 12).rounded(.up) }
        let short: PresentationDetent? = (!typeSize.isAccessibilitySize && (height ?? 0) > 120 && (height ?? 0) < 780)
            ? .height(height!) : nil
        content
            .lookSheetGround()
            .presentationDragIndicator(.visible)
            .presentationDetents(short.map { [$0, .large] } ?? [.large],
                                 selection: Binding(get: { expanded || short == nil ? .large : short! },
                                                    set: { expanded = ($0 == .large) }))
    }
}

// MARK: - Refused entry

/// A refused entry's line: danger text after a warning triangle.
struct ExercisesErrorLine: View {
    var text: String
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(.footnote, weight: .bold))
            Text(text)
                .font(.system(.footnote, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(look.destructive)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ExercisesFieldErrorEdge: ViewModifier {
    var isError: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content.overlay {
            if isError {
                RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                    .strokeBorder(look.destructive, lineWidth: 1.5)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Fonts and glyphs

extension Look {
    /// A list row's title.
    var exercisesRowTitle: Font { .system(.body, weight: .semibold) }
    /// A number inside a row ("105 × 8").
    var exercisesRowValue: Font { Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit() }
}

extension LoadType {
    /// The load type's tile glyph.
    var pickerSymbol: String {
        switch self {
        case .weighted: "scalemass"
        case .bodyweight: "figure.strengthtraining.functional"
        case .bodyweightPlus: "plus.circle"
        case .assisted: "arrow.down.circle"
        }
    }
}

extension Exercise {
    /// The equipment tags worth showing beside the load badge: "Bodyweight" is left out when the
    /// badge already says it (so "Dip" reads "BW + added", not "Bodyweight · BW + added").
    var shownEquipmentTags: [EquipmentTag] {
        equipmentTypeTags.filter { !($0 == .bodyweight && loadType != .weighted) }
    }

    /// "Machine · Cable"
    var equipmentLine: String { shownEquipmentTags.map(\.label).joined(separator: " · ") }
}

/// An equipment glyph: the machine weight stack, a barbell, a cable, a Smith machine or a symbol.
struct ExercisesGlyph: View {
    var tag: EquipmentTag?
    var style: Font.TextStyle = .body
    @ScaledMetric private var side: CGFloat

    init(_ tag: EquipmentTag?, style: Font.TextStyle = .body) {
        self.tag = tag
        self.style = style
        _side = ScaledMetric(wrappedValue: style == .title2 ? 26 : (style == .title3 ? 22 : (style == .footnote ? 16 : 19)),
                             relativeTo: style)
    }

    var body: some View {
        switch tag {
        case .machine: LookIcon(LookIcon.machine, style: style)
        case .barbell: shape(ExercisesBarbellShape())
        case .cable: shape(ExercisesCableShape())
        case .smith: shape(ExercisesSmithShape())
        case .dumbbell: Image(systemName: "dumbbell").font(.system(style, weight: .semibold))
        case .bodyweight: Image(systemName: "figure.strengthtraining.functional").font(.system(style, weight: .semibold))
        case nil: Image(systemName: "questionmark.square.dashed").font(.system(style, weight: .semibold))
        }
    }

    private func shape<S: Shape>(_ s: S) -> some View {
        s.stroke(style: StrokeStyle(lineWidth: max(1.4, side * 0.085), lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

private struct ExercisesGrid {
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

struct ExercisesBarbellShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = ExercisesGrid(rect)
        var p = Path()
        p.move(to: g.pt(1, 12)); p.addLine(to: g.pt(23, 12))
        p.addRoundedRect(in: g.rect(4, 5.5, 3, 13), cornerSize: CGSize(width: g.s, height: g.s))
        p.addRoundedRect(in: g.rect(17, 5.5, 3, 13), cornerSize: CGSize(width: g.s, height: g.s))
        p.addRoundedRect(in: g.rect(7.5, 8, 2, 8), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        p.addRoundedRect(in: g.rect(14.5, 8, 2, 8), cornerSize: CGSize(width: g.s * 0.8, height: g.s * 0.8))
        return p
    }
}

struct ExercisesCableShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = ExercisesGrid(rect)
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

struct ExercisesSmithShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = ExercisesGrid(rect)
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

// MARK: - Navigation

/// Pushes an exercise's detail (E02) from any stack: the Exercises tab, a machine page, or E02
/// itself (a machine's exercise).
struct ExerciseDetailLink: Hashable {
    var exerciseID: UUID
}
