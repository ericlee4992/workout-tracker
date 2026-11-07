import SwiftUI

// PROTOTYPE — pieces shared by the Exercises screens: the family colour mark (section
// headers only — never a muscle icon per row), the catalog row, the family filter strip (the
// maps as an index, a summary), the best-set mark per look, stat strip, tags, choice tiles,
// chips, sheet chrome and the swipe-to-delete row.

// MARK: - Family colour mark

/// A small mark in the family's colour for a SECTION header (A a lit bar, B a dot, C an
/// outlined index tab). No family (Core, Neck, Full Body, Uncategorized): A draws nothing (a
/// hollow bar read as a missing glyph) but keeps the slot so titles align; B an open circle;
/// C a dashed tab.
struct ExercisesFamilyMark: View {
    var family: MuscleFamily?
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 18

    var body: some View {
        let color = family.map { look.family($0) }
        Group {
            switch look.id {
            case .floodlight:
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color ?? .clear)
                    .frame(width: max(5, height * 0.32), height: height)
            case .anatomy:
                Circle().fill(color ?? .clear)
                    .overlay { if color == nil { Circle().strokeBorder(look.textTertiary, lineWidth: 1.5) } }
                    .frame(width: height * 0.6, height: height * 0.6)
            case .paper, .carbon:
                let shape = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                shape.fill(color ?? .clear)
                    .overlay {
                        if color == nil {
                            shape.strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                        } else {
                            shape.strokeBorder(look.outline, lineWidth: 1.5)
                        }
                    }
                    .frame(width: height * 0.72, height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Section header

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
                .font(look.id.isPaperClub ? look.font.title3 : look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
            Spacer(minLength: 8)
            if let count {
                Text("\(count)")
                    .font(.system(.footnote, weight: .semibold).monospacedDigit())
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.map { "\(title), \(Format.count($0, "exercise"))" } ?? title)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Best set (the look's "new best" meaning)

/// A best set, formatted by load type (`ExercisesValue`): A a burst before it, B a star disc,
/// C the yellow highlighter behind it. `marked` means "the last session set this best" (see
/// `ExercisesCatalogStat.lastWasNewBest`); `false` draws the value plainly.
struct ExercisesBestValue: View {
    enum Style { case row, hero, tile }
    var value: SetValue
    var loadType: LoadType
    var rowUnit: WeightUnit
    var style: Style = .row
    var marked = true
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var heroDisc: CGFloat = 32
    @ScaledMetric(relativeTo: .subheadline) private var rowDisc: CGFloat = 20

    private var text: String {
        ExercisesValue.label(value, loadType: loadType, rowUnit: rowUnit, alwaysUnit: style == .hero)
    }

    private var font: Font {
        switch style {
        case .row: look.exercisesRowValue
        case .tile: look.font.statNumber
        case .hero: look.font.heroNumber
        }
    }

    var body: some View {
        HStack(spacing: style == .hero ? 10 : 6) {
            if marked && !look.id.isPaperClub { glyph }
            Text(text)
                .font(font)
                .foregroundStyle(marked && look.id.isPaperClub ? look.onPositive : look.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, marked && look.id.isPaperClub ? (style == .hero ? 10 : 5) : 0)
                .padding(.vertical, marked && look.id.isPaperClub ? (style == .hero ? 2 : 1) : 0)
                .background {
                    if marked && look.id.isPaperClub {
                        RoundedRectangle(cornerRadius: style == .hero ? 4 : 3, style: .continuous).fill(look.positive)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(marked ? "New best, set last session, \(ExercisesValue.spoken(value, loadType: loadType))"
                                   : "Best \(ExercisesValue.spoken(value, loadType: loadType))")
    }

    @ViewBuilder private var glyph: some View {
        switch look.id {
        case .floodlight:
            Image(systemName: "burst.fill")
                .font(style == .hero ? .system(.title2, weight: .bold) : .system(.caption, weight: .bold))
                .foregroundStyle(look.positive)
        case .anatomy:
            let side = style == .hero ? heroDisc : rowDisc
            Image(systemName: "star.fill")
                .font(.system(size: side * 0.48, weight: .heavy))
                .foregroundStyle(look.textPrimary)
                .frame(width: side, height: side)
                .background(look.positive.opacity(0.14), in: Circle())
        case .paper, .carbon:
            EmptyView()
        }
    }
}

// MARK: - One logged set in a history line

/// A logged set at one size for every set in the line (no jumping baselines). Warmups are
/// dim with their "W"; a set that was a new best carries the look's mark: A the burst, B the
/// pearl star, C the yellow highlighter behind the value.
struct ExercisesSetText: View {
    var value: SetValue
    var type: SetType
    var loadType: LoadType
    var rowUnit: WeightUnit
    var isNewBest: Bool
    @Environment(\.look) private var look

    var body: some View {
        let label = ExercisesValue.label(value, loadType: loadType, rowUnit: rowUnit)
        HStack(spacing: 3) {
            if isNewBest {
                switch look.id {
                case .floodlight:
                    Image(systemName: "burst.fill").font(.system(.caption2, weight: .bold)).foregroundStyle(look.positive)
                case .anatomy:
                    Image(systemName: "star.fill").font(.system(.caption2, weight: .heavy)).foregroundStyle(look.textPrimary)
                case .paper, .carbon:
                    EmptyView()
                }
            }
            if let marker = type.marker {
                Text(marker).font(.system(.caption2, weight: .heavy)).foregroundStyle(look.textTertiary)
            }
            Text(label)
                .font(.system(.footnote, weight: isNewBest ? .heavy : .semibold).monospacedDigit())
                .foregroundStyle(foreground)
                .padding(.horizontal, isNewBest && look.id.isPaperClub ? 4 : 0)
                .background {
                    if isNewBest && look.id.isPaperClub {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(look.positive)
                    }
                }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((isNewBest ? "New best, " : "") + (type == .warmup ? "Warmup, " : "") + ExercisesValue.spoken(value, loadType: loadType))
    }

    private var foreground: Color {
        if isNewBest { return look.id.isPaperClub ? look.onPositive : look.textPrimary }
        return type == .warmup ? look.textTertiary : look.textSecondary
    }
}

// MARK: - Stat strip

struct ExercisesStat: Identifiable {
    var id: String { label }
    var value: String
    var label: String
    var isWord = false
}

/// Big numbers, small labels. A: one panel divided by hairlines; B: separate tiles;
/// C: one ticket with rules. At accessibility sizes: rows (value leading, label trailing).
struct ExercisesStatStrip: View {
    var stats: [ExercisesStat]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 { LookDivider() }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        value(stat)
                        Spacer(minLength: 8)
                        label(stat).multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .lookSurface(.stat)
        } else if look.id == .anatomy {
            HStack(spacing: 10) {
                ForEach(stats) { stat in
                    cell(stat)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lookSurface(.stat)
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 { LookDivider(vertical: true) }
                    cell(stat)
                        .padding(.leading, 14)
                        .padding(.trailing, 8)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .lookSurface(.stat)
        }
    }

    private func cell(_ stat: ExercisesStat) -> some View {
        VStack(alignment: .leading, spacing: look.id == .floodlight ? 3 : 2) {
            value(stat)
            label(stat)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.label) \(stat.value)")
    }

    private func value(_ stat: ExercisesStat) -> some View {
        Text(stat.value)
            .font(stat.isWord ? look.exercisesStatWord : look.font.statNumber)
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func label(_ stat: ExercisesStat) -> some View {
        Text(look.id.isPaperClub ? stat.label.lowercased() : stat.label)
            .font(.system(.footnote, weight: look.id == .floodlight ? .regular : .semibold))
            .foregroundStyle(look.textSecondary)
            .lineLimit(1)
    }
}

// MARK: - Tag

/// A small label (equipment, load type, Custom). A: a raised cell; B: a white 8 % capsule;
/// C: a pressed-paper tag.
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
            Text(text).font(.system(.caption, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
        }
        .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            switch look.id {
            case .floodlight: RoundedRectangle(cornerRadius: 6, style: .continuous).fill(look.surfaceRaised)
            case .anatomy: Capsule().fill(look.controlFill)
            // C: a pressed-paper fill, no outline (a solid outline means "you can press this").
            case .paper, .carbon: RoundedRectangle(cornerRadius: 6, style: .continuous).fill(look.pressedFill)
            }
        }
        .fixedSize()
    }
}

// MARK: - Choice surfaces

/// A selectable tile. Selection is a state: A a flood outline on a lifted fill, B a pearl
/// outline, C fills cobalt (C's selected chip).
struct ExercisesChoiceSurface: ViewModifier {
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
    func exercisesChoiceSurface(isSelected: Bool, radius: CGFloat? = nil) -> some View {
        modifier(ExercisesChoiceSurface(isSelected: isSelected, radius: radius))
    }
}

extension Look {
    func exercisesChoiceText(_ selected: Bool) -> Color { id.isPaperClub && selected ? onAction : textPrimary }
    func exercisesChoiceSecondary(_ selected: Bool) -> Color { id.isPaperClub && selected ? onAction.opacity(0.86) : textSecondary }
}

// MARK: - Load type picker (E03, E05)

/// The four load types as tiles (2 × 2; one column at accessibility sizes): glyph and name,
/// with the look's selected mark. Which way records rank is said once, by the selected type's
/// consequence line under the grid (its arrow glyph), not repeated on every tile.
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
                ForEach(LoadType.allCases) { type in tile(type) }
            }
            ExercisesNotice(symbol: selection.exercisesRankSymbol, text: selection.exercisesExplanation)
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
                Image(systemName: type.exercisesSymbol)
                    .font(.system(.title3, weight: .semibold))
                Text(type.badge)
                    .font(look.id == .anatomy ? look.font.button : .system(.headline, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(look.exercisesChoiceText(selected))
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .exercisesChoiceSurface(isSelected: selected)
            .overlay(alignment: .bottomTrailing) {
                if selected && !look.id.isPaperClub {
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
        .accessibilityValue(type.higherIsBetter ? "Higher is better" : "Lower is better")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Notice (one consequence line)

struct ExercisesNotice: View {
    var symbol: String
    var text: String
    var emphasized = false
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.system(.footnote, weight: .bold))
            Text(text)
                .font(.system(.footnote, weight: emphasized ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
        .padding(.horizontal, 4)
    }
}

// MARK: - Chips

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
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .lineLimit(1)
                if isSelected && !look.id.isPaperClub {
                    Image(systemName: "checkmark").font(.system(.caption, weight: .heavy))
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 13)
            .frame(minHeight: height)
            .background(fill, in: Capsule())
            .overlay { Capsule().strokeBorder(edge, lineWidth: edgeWidth) }
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        switch look.id {
        case .floodlight, .anatomy: isSelected ? look.selection : look.textSecondary
        case .paper, .carbon: isSelected ? look.onAction : look.textPrimary
        }
    }
    private var fill: Color {
        switch look.id {
        case .floodlight: isSelected ? look.segmentFill : .clear
        case .anatomy: isSelected ? look.segmentFill : look.surfaceSheet
        case .paper, .carbon: isSelected ? look.action : look.surface
        }
    }
    private var edge: Color {
        switch look.id {
        case .floodlight: isSelected ? look.textPrimary.opacity(0.9) : look.hairline
        case .anatomy: isSelected ? look.textPrimary.opacity(0.5) : look.hairline
        case .paper, .carbon: look.outline
        }
    }
    private var edgeWidth: CGFloat { look.id.isPaperClub ? 1.5 : (isSelected ? 1.5 : 1) }
}

// MARK: - Dashed "make one" row

struct ExercisesMakeRow: View {
    var title: String
    var symbol = "plus"
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconDisc(symbol: symbol, size: 34, context: .make)
                Text(title).font(.system(.body, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: look.radius.row,
                           lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [6, 4])
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
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

/// Leading glass button · title (and subtitle) · trailing glass "Done" or the sheet's one
/// filled command. At accessibility sizes the title leaves the bar and wraps.
struct ExercisesSheetHeader: View {
    enum Trailing {
        case done(() -> Void)
        case commit(String, enabled: Bool, action: () -> Void)
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
            // One order in every look: the sheet's title, then the exercise it belongs to.
            if let subtitle {
                subtitleText(subtitle, ax: ax)
            }
        }
    }

    private func subtitleText(_ text: String, ax: Bool) -> some View {
        Text(text)
            .font(.system(.footnote, weight: .medium))
            .foregroundStyle(look.textSecondary)
            .lineLimit(ax ? nil : 1)
            .multilineTextAlignment(ax ? .leading : .center)
    }

    @ViewBuilder private var leadingButton: some View {
        if let cancel { GlassCapsuleButton("Cancel", action: cancel) } else { Color.clear.frame(width: 1, height: 1) }
    }

    @ViewBuilder private var trailingButton: some View {
        switch trailing {
        case .done(let action):
            GlassCapsuleButton("Done", action: action)
        case .commit(let title, let enabled, let action):
            Button(action: action) {
                ExercisesCommitFace(title: title, enabled: enabled, minHeight: height, horizontalPadding: 18)
            }
            .buttonStyle(.lookPressable)
            .disabled(!enabled)
            .animation(.easeOut(duration: 0.15), value: enabled)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer { Text(title) }
        }
    }
}

// MARK: - Swipe to delete

/// A row that reveals a Delete tile when swiped left (the same gesture as deleting a set).
/// Tapping the tile asks `onDelete`; a VoiceOver "Delete" action does the same.
struct ExercisesSwipeRow<Content: View>: View {
    @Binding var revealed: Bool
    var onDelete: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    private let tileWidth: CGFloat = 88

    var body: some View {
        let base = revealed ? -tileWidth : 0
        let offset = min(0, max(-tileWidth * 1.3, base + drag))
        ZStack(alignment: .trailing) {
            deleteTile
                .frame(width: tileWidth)
                .opacity(offset < -4 ? 1 : 0)
            content
                .background(look.surfaceSheet)
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .updating($drag) { value, state, _ in
                    if abs(value.translation.width) > abs(value.translation.height) { state = value.translation.width }
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let open = (base + value.translation.width) < -tileWidth / 2
                    if reduceMotion { revealed = open } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { revealed = open }
                    }
                })
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: revealed)
        .accessibilityAction(named: "Delete", onDelete)
    }

    /// The Delete tile. C draws one 2 pt rule tight to the tile's edge (the inner second rule
    /// squeezed the caption onto the rule), with a 20 pt ink disc and a caption2 verb; when the row is too short for both (accessibility
    /// sizes squeeze it the other way: the row grows), `ViewThatFits` keeps the disc alone.
    private var deleteTile: some View {
        Button(action: onDelete) {
            ViewThatFits(in: .vertical) {
                VStack(spacing: 3) { glyph; Text("Delete").font(.system(.caption2, weight: .bold)).lineLimit(1) }
                glyph
            }
            .foregroundStyle(tileForeground)
            .padding(look.id.isPaperClub ? 8 : 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tileFill)
            .overlay {
                if look.id.isPaperClub {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(look.outline, lineWidth: 2).padding(2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var glyph: some View {
        if look.id.isPaperClub {
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(look.surface)
                .frame(width: 20, height: 20)
                .background(look.textPrimary, in: Circle())
        } else {
            Image(systemName: "trash").font(.system(.body, weight: .semibold))
        }
    }

    private var tileFill: Color {
        switch look.id {
        case .floodlight: look.destructive
        case .anatomy: look.surfaceRaised
        case .paper, .carbon: look.surface
        }
    }
    private var tileForeground: Color {
        switch look.id {
        case .floodlight: look.onAction
        case .anatomy, .paper, .carbon: look.textPrimary
        }
    }
}

// MARK: - Commit face (Add / Save)

/// A sheet's commit capsule. Enabled: the look's filled command (C adds its 2 pt outline).
/// Disabled: a quiet capsule at reduced opacity with NO outline (in C a solid outline means
/// "you can press this", so a disabled button must not carry one).
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
            .background(enabled ? look.action : (look.id.isPaperClub ? look.pressedFill : look.surfaceRaised), in: Capsule())
            .overlay { if look.id.isPaperClub && enabled { Capsule().strokeBorder(look.outline, lineWidth: 2) } }
            .opacity(enabled ? 1 : 0.55)
            .contentShape(Capsule())
    }
}

// MARK: - Field error (a block, not a hint)

/// The look's warning treatment for an entry that is refused. A: danger text with a warning
/// triangle; B (no hue for errors): pearl text with a filled pearl mark; C: ink text beside an
/// ink-filled "!" disc. Pair it with `.exercisesFieldError(_:)` on the field.
struct ExercisesErrorLine: View {
    var text: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var disc: CGFloat = 18

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            switch look.id {
            case .floodlight:
                Image(systemName: "exclamationmark.triangle.fill").font(.system(.footnote, weight: .bold))
            case .anatomy:
                Image(systemName: "exclamationmark.circle.fill").font(.system(.footnote, weight: .bold))
            case .paper, .carbon:
                Text("!")
                    .font(.system(size: disc * 0.62, weight: .black))
                    .foregroundStyle(look.surface)
                    .frame(width: disc, height: disc)
                    .background(look.textPrimary, in: Circle())
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + disc * 0.22 }
            }
            Text(text)
                .font(.system(.footnote, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(look.id == .floodlight ? look.destructive : look.textPrimary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// The field's refused state: A a danger edge, B a pearl edge, C a solid 2 pt ink rule.
    func exercisesFieldError(_ isError: Bool) -> some View {
        modifier(ExercisesFieldErrorEdge(isError: isError))
    }
}

private struct ExercisesFieldErrorEdge: ViewModifier {
    var isError: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content.overlay {
            if isError {
                RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                    .strokeBorder(look.id == .floodlight ? look.destructive : (look.id.isPaperClub ? look.outline : look.textPrimary),
                                  lineWidth: look.id.isPaperClub ? 2 : 1.5)
                    .transition(.opacity)
            }
        }
    }
}
