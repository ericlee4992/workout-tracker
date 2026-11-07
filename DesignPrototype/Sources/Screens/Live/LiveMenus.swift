import SwiftUI

// PROTOTYPE — the live screen's floating menus: an exercise's "…" menu and a set row's set-type
// menu. They are drawn by the screen (not system popovers) so that (a) they sit on an opaque
// surface in the look's own material, (b) they always keep the 20 pt screen margin, and (c) a
// capture state can open them (router.pendingDialog). They drop from the control that opened
// them — below it, or above it when the thumb is low — and grow from that corner.

struct LiveMenuLayer: View {
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.liveReduceMotion) private var reduceMotion
    @State private var size: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            ZStack(alignment: .topLeading) {
                if let menu = model.menu {
                    Color.black.opacity(look.isDark ? 0.34 : 0.14)
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                        .accessibilityLabel("Close menu")
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity)
                    let placed = placement(menu, in: frame)
                    card(menu)
                        .frame(width: placed.width)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                        .offset(x: placed.x, y: placed.y)
                        .opacity(size == .zero ? 0 : 1)
                        .transition(reduceMotion ? .opacity
                                    : .scale(scale: 0.86, anchor: placed.anchor).combined(with: .opacity))
                        .accessibilityAddTraits(.isModal)
                }
            }
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.86),
                   value: model.menu?.target)
    }

    private func close() { model.closeMenu() }

    /// Width, position (top-leading, in the layer's space) and the corner it grows from.
    private func placement(_ menu: LiveMenuState, in frame: CGRect) -> (width: CGFloat, x: CGFloat, y: CGFloat, anchor: UnitPoint) {
        let margin = look.space.margin
        let maxWidth = frame.width - margin * 2
        let isEntry: Bool = if case .entry = menu.target { true } else { false }
        let preferred: CGFloat = isEntry ? 268 : 244
        let width = typeSize.isAccessibilitySize ? maxWidth : min(preferred, maxWidth)
        let a = menu.anchor.offsetBy(dx: -frame.minX, dy: -frame.minY)
        let h = size.height
        // "…" is at the trailing edge: align the menu's trailing edge with it. The set marker is
        // at the leading edge: align leading edges.
        var x = isEntry ? a.maxX - width + 6 : a.minX - 6
        x = min(max(x, margin), frame.width - margin - width)
        let below = a.maxY + 8
        let fitsBelow = below + h <= frame.height - 44
        var y = fitsBelow ? below : a.minY - 8 - h
        // Never over the glass top bar.
        y = max(y, model.topBarBottom - frame.minY + 6)
        let anchor: UnitPoint = switch (isEntry, fitsBelow) {
        case (true, true): .topTrailing
        case (true, false): .bottomTrailing
        case (false, true): .topLeading
        case (false, false): .bottomLeading
        }
        return (width, x, y, anchor)
    }

    @ViewBuilder private func card(_ menu: LiveMenuState) -> some View {
        Group {
            switch menu.target {
            case .entry(let entryID): LiveEntryMenu(entryID: entryID)
            case .setType(let entryID, let setID): LiveSetTypeMenu(entryID: entryID, setID: setID)
            }
        }
        .padding(.vertical, 6)
        .background { LiveMenuSurface() }
    }
}

/// The menu's material: opaque, one step above the cards, per look. A raised cell with a
/// floating shadow; B the sheet card with its hairline; C a paper sheet with the ink outline
/// (no soft shadow — C keeps shadows for the one primary).
private struct LiveMenuSurface: View {
    @Environment(\.look) private var look

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.id.isPaperClub ? 18 : 16, style: .continuous)
        switch look.id {
        case .floodlight:
            shape.fill(look.isDark ? look.surfaceRaised : look.surface)
                .overlay { shape.strokeBorder(look.wash(0.12), lineWidth: 1) }
                .shadow(color: look.floatShadow(0.6), radius: 24, x: 0, y: 14)
        case .anatomy:
            shape.fill(look.surfaceSheet)
                .overlay { shape.strokeBorder(look.hairline, lineWidth: 1) }
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 14)
        case .paper, .carbon:
            shape.fill(look.surface)
                .overlay { shape.strokeBorder(look.outline, lineWidth: 1.5) }
        }
    }
}

// MARK: - The "…" menu

struct LiveEntryMenu: View {
    let entryID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let entry = store.liveEntry(entryID)
        let exercise = store.exercise(entry?.exerciseID)
        let grouped = store.supersetLabel(entryID: entryID) != nil
        let count = store.session?.entries.count ?? 0
        VStack(spacing: 0) {
            LiveMenuRow(title: "Rest Settings…", symbol: "timer") { open(.restSettings(entryID: entryID)) }
            LiveMenuDivider()
            LiveMenuRow(title: "Previous Performance", symbol: "chart.line.uptrend.xyaxis") {
                open(.previousPerformance(entryID: entryID))
            }
            if let exercise {
                LiveMenuDivider()
                LiveMenuRow(title: "Change Load Type…", symbol: "scalemass") { open(.loadType(exerciseID: exercise.id)) }
            }
            if grouped {
                LiveMenuDivider()
                LiveMenuRow(title: "Break superset", symbol: "arrow.triangle.branch") {
                    model.closeMenu()
                    withAnimation(reduceMotion ? nil : .default) { store.breakSuperset(entryID: entryID) }
                }
            } else if store.liveHasNextEntry(entryID) {
                LiveMenuDivider()
                LiveMenuRow(title: "Superset with next", symbol: "arrow.triangle.merge") {
                    model.closeMenu()
                    withAnimation(reduceMotion ? nil : .default) { store.supersetWithNext(entryID: entryID) }
                }
            }
            if count > 1 {
                LiveMenuDivider()
                LiveMenuRow(title: "Reorder Exercises", symbol: "arrow.up.arrow.down") {
                    model.closeMenu()
                    withAnimation(reduceMotion ? nil : .snappy) { model.reordering = true }
                }
            }
            LiveMenuGap()
            LiveMenuRow(title: "Delete Exercise", symbol: "trash", isDestructive: true) {
                model.closeMenu()
                model.deleteEntryID = entryID
            }
        }
    }

    private func open(_ route: SheetRoute) {
        model.closeMenu()
        // Let the menu leave before the sheet rises.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { router.present(route) }
    }
}

// MARK: - Set-type menu

struct LiveSetTypeMenu: View {
    let entryID: UUID
    let setID: UUID
    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var markerSide: CGFloat = 30

    var body: some View {
        let current = store.liveEntry(entryID)?.sets.first { $0.id == setID }?.type ?? .working
        VStack(spacing: 0) {
            ForEach([SetType.warmup, .working, .failure, .drop], id: \.self) { type in
                LiveMenuRow(title: type.displayName, symbol: nil, isChecked: type == current) {
                    model.closeMenu()
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        store.setType(type, entryID: entryID, setID: setID)
                    }
                } leading: {
                    SetMarker(kind: type, number: workingNumber, done: false, side: markerSide)
                        .frame(width: markerSide + 4)
                }
                if type != .drop { LiveMenuDivider().padding(.leading, markerSide + 32) }
            }
            LiveMenuGap()
            LiveMenuRow(title: "Delete Set", symbol: "trash", isDestructive: true) {
                model.closeMenu()
                if model.editing?.setID == setID { model.endEditing() }
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)) {
                    store.deleteSet(entryID: entryID, setID: setID)
                }
            }
        }
    }

    /// The number this row would carry as a working set.
    private var workingNumber: Int {
        guard let entry = store.liveEntry(entryID) else { return 1 }
        let counted = entry.sets.filter { $0.type != .warmup || $0.id == setID }
        return (counted.firstIndex { $0.id == setID } ?? 0) + 1
    }
}

// MARK: - Rows

/// A menu row: label leading, glyph trailing (the iOS menu layout), at least 48 pt tall. The
/// label wraps at large sizes instead of truncating.
struct LiveMenuRow<Leading: View>: View {
    var title: String
    var symbol: String?
    var isDestructive = false
    var isChecked = false
    var action: () -> Void
    @ViewBuilder var leading: Leading
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                Text(title)
                    .font(.system(.body, design: look.id == .anatomy ? .rounded : .default,
                                  weight: look.id == .anatomy ? .semibold : .regular))
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                if isChecked {
                    Image(systemName: "checkmark").font(.system(.subheadline, weight: .bold)).foregroundStyle(look.textPrimary)
                } else if let symbol {
                    LookIcon(symbol, style: .body, weight: .regular).foregroundStyle(color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiveMenuRowStyle())
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }

    /// A's destructive is danger red-orange; B and C have no destructive hue (the word and the
    /// trash glyph carry it, and every delete is confirmed or undoable by re-adding).
    private var color: Color {
        isDestructive && look.id == .floodlight ? look.destructive : look.textPrimary
    }
}

extension LiveMenuRow where Leading == EmptyView {
    init(title: String, symbol: String?, isDestructive: Bool = false, isChecked: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, symbol: symbol, isDestructive: isDestructive, isChecked: isChecked, action: action) { EmptyView() }
    }
}

private struct LiveMenuRowStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.textPrimary.opacity(0.1) : .clear)
    }
}

/// A hairline between rows.
struct LiveMenuDivider: View {
    @Environment(\.look) private var look
    var body: some View {
        Rectangle().fill(look.textPrimary.opacity(look.isDark ? 0.12 : 0.14)).frame(height: 1)
    }
}

/// The wider gap that sets the destructive row apart (the iOS menu's section gap).
struct LiveMenuGap: View {
    @Environment(\.look) private var look
    var body: some View {
        Rectangle().fill(look.textPrimary.opacity(look.isDark ? 0.07 : 0.08)).frame(height: 8)
    }
}
