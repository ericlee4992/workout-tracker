import SwiftUI

// PROTOTYPE — one exercise inside the live workout: title (+ superset letter / done chip),
// previous-performance and "…" buttons, the equipment row, the bar chip, the set grid (SetRowView
// with a set-type menu on the marker, typed entry, swipe to delete) and Add Set. Superset members
// share one backing, split by a seam. No family colour and no muscle map on the card (user rule).

struct LiveExerciseCard: View {
    let entryID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion
    @State private var cardHeight: CGFloat = 0

    var body: some View {
        if let entry = store.liveEntry(entryID) {
            card(entry)
        }
    }

    private func card(_ entry: LiveEntry) -> some View {
        let loadType = store.loadType(entryID: entryID)
        let badges = store.liveBadges(entryID: entryID)
        let next = store.nextSet
        let isResting = store.rest != nil
        let isCurrent = (next?.entryID ?? store.currentEntryID) == entryID
        let equipment = store.liveEquipment(entryID: entryID)
        let weightTitle = entry.isBarMode ? "PER SIDE" : loadType.weightColumn
        let position = store.liveSupersetPosition(entryID)
        let name = store.exercise(entry.exerciseID)?.name ?? "Exercise"

        return VStack(alignment: .leading, spacing: 10) {
            LiveCardHeader(entryID: entryID, title: name,
                           subtitle: look.id == .anatomy && !entry.targetReps.isEmpty ? "Target: \(Format.targets(entry.targetReps))" : nil,
                           letter: store.supersetLabel(entryID: entryID),
                           isDone: !entry.sets.isEmpty && entry.sets.allSatisfy(\.isCompleted),
                           onPrevious: {
                               model.endEditing()
                               router.present(.previousPerformance(entryID: entryID))
                           },
                           onOptions: { model.openMenu(.entry(entryID)) })
            LiveEquipmentRow(title: equipment.title, subtitle: equipment.subtitle, symbol: equipment.symbol) {
                model.endEditing()
                router.present(.equipment(entryID: entryID))
            }
            if entry.isBarMode || store.offersBar(entryID: entryID) {
                barChip(entry)
            }
            SetColumnHeader(weightTitle: weightTitle).padding(.top, 4)
            VStack(spacing: 4) {
                ForEach(entry.sets) { set in
                    LiveSetRow(entryID: entryID, set: set,
                               marker: store.setMarker(entryID: entryID, setID: set.id),
                               last: store.previousValue(entryID: entryID, setID: set.id),
                               loadType: loadType,
                               barTotal: entry.isBarMode && set.weight != nil ? entry.total(of: set) : nil,
                               isNextUp: next?.setID == set.id,
                               isResting: isResting,
                               badge: badges[set.id],
                               weightTitle: weightTitle,
                               cardHeight: cardHeight)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .trailing))))
                }
            }
            AddSetRow {
                model.endEditing()
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                    _ = store.addSet(entryID: entryID)
                }
            }
            .accessibilityHint("Adds a row to \(name)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .modifier(LiveCardSurface(joinTop: position == .middle || position == .last,
                                  joinBottom: position == .first || position == .middle,
                                  highlighted: look.id == .anatomy && isCurrent))
        .coordinateSpace(.named(entryID))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
        .accessibilityElement(children: .contain)
    }

    // MARK: Bar chip

    private func barChip(_ entry: LiveEntry) -> some View {
        let unit = entry.sets.first?.unit ?? store.displayUnit
        let title = entry.barWeight.map { "Bar: \(Format.weight($0, unit))" } ?? "No bar — enter total weight"
        return HStack {
            Chip(title, isSelected: false) {
                model.endEditing()
                router.present(.barPicker(entryID: entryID, setID: nil))
            }
            .accessibilityHint("Changes the bar")
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Set row

/// One set: SetRowView plus the live behaviour around it — the set-type menu on the marker,
/// typed entry (a hidden field focused under the row so the list scrolls it above the
/// keyboard), the bar total in bar mode, swipe left to reveal Delete (or swipe all the way to
/// delete), and the "not ticked" mark while the finish notice is up.
struct LiveSetRow: View {
    let entryID: UUID
    let set: LiveSet
    let marker: String
    let last: SetValue?
    let loadType: LoadType
    /// Bar mode: the set's total (bar + 2 × per side) for the "= 135 lb" caption.
    let barTotal: Double?
    let isNextUp: Bool
    let isResting: Bool
    let badge: SetBadge?
    let weightTitle: String
    /// The card's height, to place this row when the list scrolls to it.
    let cardHeight: CGFloat

    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.liveReduceMotion) private var reduceMotion
    @Environment(\.lookOnSheet) private var onSheet
    @ScaledMetric(relativeTo: .body) private var gridScale: CGFloat = 1
    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var pastFullSwipe = false
    @State private var rowWidth: CGFloat = 360
    /// This row's centre within its card and on screen (for scrolling it into view).
    @State private var midInCard: CGFloat = 0
    @State private var globalMid: CGFloat = 0
    @State private var rowHeight: CGFloat = 48

    private let revealWidth: CGFloat = 80
    private var isOpen: Bool { model.swipedSetID == set.id }
    private var metrics: SetGridMetrics { .make(look, scale: gridScale) }
    private var fullSwipe: CGFloat { max(revealWidth * 2, rowWidth * 0.55) }
    private var editingField: LiveEntryField? {
        guard let e = model.editing, e.setID == set.id else { return nil }
        return e.field
    }
    /// Typed but not ticked, while the finish notice asks about it.
    private var flagged: Bool { model.confirmFinish && set.state == .typed }

    var body: some View {
        let offset = min(0, (isOpen ? -revealWidth : 0) + dragX)
        let swiping = offset < 0
        rowStack
            .background { if flagged { flagMark } }
            // Opaque only while sliding over the delete tile (so check ripples and the row
            // flash are never covered by the next row).
            .background(swiping ? (onSheet ? look.surfaceSheet : look.surface) : Color.clear)
            .overlay {
                if isOpen {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { close() }
                        .accessibilityHidden(true)
                }
            }
            .offset(x: offset)
            .background(alignment: .trailing) {
                if swiping { deleteTile(width: max(revealWidth, -offset)) }
            }
            // While swiping, the row is clipped at its own leading edge and its first 96 pt fade
            // out, so the marker and PREVIOUS dissolve instead of leaving a cut fragment in the
            // card's padding. At rest the mask is generous (check ripples and the strobe spill out).
            .mask {
                if swiping {
                    HStack(spacing: 0) {
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.5),
                                               .init(color: .black, location: 1)],
                                       startPoint: .leading, endPoint: .trailing).frame(width: 96)
                        Rectangle()
                    }
                    .padding(.trailing, -8)
                } else {
                    Rectangle().padding(-60)
                }
            }
            .simultaneousGesture(swipe)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            .onChange(of: cardHeight) { _, _ in record() }
            .sensoryFeedback(.impact(weight: .medium), trigger: pastFullSwipe) { _, new in new }
            .accessibilityActions {
                Button("Delete Set") { delete() }
                Button("Set type") { model.openMenu(.setType(entryID: entryID, setID: set.id)) }
            }
    }

    private var rowStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if typeSize.isAccessibilitySize { axBlock } else { oneLineRow }
            }
                .overlay(alignment: typeSize.isAccessibilitySize ? .topLeading : .leading) { markerButton }
                .overlay { editingRing }
                .background {
                    if let field = editingField {
                        let target = LiveEditTarget(entryID: entryID, setID: set.id, field: field)
                        LiveEntryCatcher(target: target).id(target)
                    }
                }
            if let barTotal { barCaption(barTotal) }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(entryID)) } action: { frame in
            midInCard = frame.midY
            rowHeight = frame.height
            record()
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { mid in
            globalMid = mid
            record()
        }
    }

    /// AX sizes: the Live two-line block (labels and values on one leading edge).
    private var axBlock: some View {
        LiveAXSetBlock(kind: set.type, number: Int(marker) ?? 0,
                       previous: last.map { look.previousLabel($0, rowUnit: set.unit, loadType: loadType) },
                       weight: loadType.takesWeight ? set.weight : nil, unit: set.unit, reps: set.reps,
                       state: set.state, isNextUp: isNextUp, isResting: isResting, badge: badge,
                       weightTitle: weightTitle, showsWeight: loadType.takesWeight,
                       onCheck: {
                           model.editPlacement = placement
                           model.toggleCheck(entryID: entryID, setID: set.id, store: store, reduceMotion: reduceMotion)
                       },
                       onWeight: { if loadType.takesWeight { edit(.weight) } },
                       onReps: { edit(.reps) },
                       onUnit: { store.toggleUnit(entryID: entryID, setID: set.id) })
    }

    private var oneLineRow: some View {
            SetRowView(kind: set.type, number: Int(marker) ?? 0, last: last, loadType: loadType,
                       weight: loadType.takesWeight ? set.weight : nil, unit: set.unit, reps: set.reps,
                       state: set.state, isNextUp: isNextUp, isResting: isResting, badge: badge,
                       weightColumnTitle: weightTitle,
                       onCheck: {
                           model.editPlacement = placement
                           model.toggleCheck(entryID: entryID, setID: set.id, store: store, reduceMotion: reduceMotion)
                       },
                       onWeight: { if loadType.takesWeight { edit(.weight) } },
                       onReps: { edit(.reps) },
                       onUnit: { store.toggleUnit(entryID: entryID, setID: set.id) })
    }

    private func record() {
        model.rows[set.id] = LiveRowPlacement(entryID: entryID, midInCard: midInCard, cardHeight: cardHeight,
                                              globalMid: globalMid, height: rowHeight)
    }

    private var placement: LiveEditPlacement {
        LiveEditPlacement(fraction: cardHeight > 0 ? min(0.95, max(0.05, midInCard / cardHeight)) : 0.5, globalMidY: globalMid)
    }

    private func edit(_ field: LiveEntryField) {
        model.editPlacement = placement
        model.beginEditing(LiveEditTarget(entryID: entryID, setID: set.id, field: field))
    }

    // MARK: Marker → set-type menu

    private var markerButton: some View {
        let m = metrics
        // A 44 pt target centred on the marker (reaching into the card's padding when the marker is narrower).
        let width = typeSize.isAccessibilitySize ? 48 : max(44, m.marker + 6)
        let shift = typeSize.isAccessibilitySize ? 0 : -(width - m.marker) / 2
        let target = LiveMenuTarget.setType(entryID: entryID, setID: set.id)
        return Button {
            model.openMenu(target)
        } label: {
            Color.clear
                .frame(width: width, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: shift)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.anchors[target] = $0 }
        .accessibilityLabel("Set type")
        .accessibilityValue(set.type.displayName)
        .accessibilityHint("Opens warmup, working, failure and drop")
    }

    // MARK: Typing highlight

    @ViewBuilder private var editingRing: some View {
        if let field = editingField {
            let shape = RoundedRectangle(cornerRadius: look.radius.field + 1, style: .continuous)
            // A keeps Ultra for the one command (Done / Skip); the field being typed is lit floodlight.
            let ringColor = look.id == .floodlight ? look.textPrimary : look.actionText
            if typeSize.isAccessibilitySize {
                RoundedRectangle(cornerRadius: look.radius.row, style: .continuous)
                    .strokeBorder(ringColor, lineWidth: 2)
                    .padding(-4)
                    .allowsHitTesting(false)
            } else {
                let m = metrics
                HStack(spacing: m.spacing) {
                    Color.clear.frame(width: m.marker)
                    Color.clear.frame(maxWidth: .infinity)
                    Group { if field == .weight { shape.strokeBorder(ringColor, lineWidth: 2) } else { Color.clear } }
                        .frame(width: m.weight + 4, height: 44)
                        .frame(width: m.weight)
                    Group { if field == .reps { shape.strokeBorder(ringColor, lineWidth: 2) } else { Color.clear } }
                        .frame(width: m.reps + 4, height: 44)
                        .frame(width: m.reps)
                    Color.clear.frame(width: 44)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
    }

    /// The finish notice's mark on a typed-but-unticked row: a tinted band with the action edge.
    private var flagMark: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.row, style: .continuous)
        return shape.fill(look.actionText.opacity(look.isDark ? 0.16 : 0.1))
            .overlay { shape.strokeBorder(look.actionText, lineWidth: 2) }
            .padding(.horizontal, -8)
            .padding(.vertical, -3)
            .accessibilityHidden(true)
    }

    // MARK: Bar total

    private func barCaption(_ total: Double) -> some View {
        let m = metrics
        let text = Text(Format.barTotal(total, set.unit))
            .font(.system(.caption, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(look.textSecondary)
            .lineLimit(1)
            .fixedSize()
        return Group {
            if typeSize.isAccessibilitySize {
                text.padding(.top, 2).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: m.spacing) {
                    Color.clear.frame(width: m.marker, height: 1)
                    Spacer(minLength: 0)
                    text.frame(width: m.weight)
                    Color.clear.frame(width: m.reps, height: 1)
                    Color.clear.frame(width: 44, height: 1)
                }
                // C's dashed draft box sits lower in its row: keep the total clear of its edge.
                .padding(.top, look.id.isPaperClub ? 0 : -5)
                .padding(.bottom, 2)
            }
        }
        .accessibilityLabel("Total \(Format.weight(total, set.unit))")
    }

    // MARK: Swipe to delete

    /// Swipe left: past half the delete tile it stays open; past about half the row it deletes
    /// (the tile grows to the full swipe and a tap of haptic marks the point of no return).
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard model.editing == nil else { return }
                let dx = value.translation.width, dy = value.translation.height
                if !isDragging {
                    guard abs(dx) > abs(dy) * 1.4, dx < 0 || isOpen else { return }
                    isDragging = true
                    if model.swipedSetID != set.id && model.swipedSetID != nil { model.swipedSetID = nil }
                }
                let base: CGFloat = isOpen ? -revealWidth : 0
                dragX = min(0, base + dx) - base
                let travel = -(base + dragX)
                if (travel > fullSwipe) != pastFullSwipe { pastFullSwipe = travel > fullSwipe }
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                let base: CGFloat = isOpen ? -revealWidth : 0
                let final = -(base + value.translation.width)
                let predicted = -(base + value.predictedEndTranslation.width)
                pastFullSwipe = false
                if final > fullSwipe || predicted > rowWidth * 0.95 {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { dragX = -rowWidth - base }
                    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.16)) { delete() }
                    return
                }
                let open = final > revealWidth / 2 || predicted > revealWidth * 1.2
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                    model.swipedSetID = open ? set.id : (model.swipedSetID == set.id ? nil : model.swipedSetID)
                    dragX = 0
                }
            }
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { model.swipedSetID = nil }
    }

    private func delete() {
        if model.editing?.setID == set.id { model.endEditing() }
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)) {
            model.swipedSetID = nil
            dragX = 0
            store.deleteSet(entryID: entryID, setID: set.id)
        }
    }

    /// The delete tile behind a swiped row. A: danger red-orange. B: no hue (a raised tile with a
    /// pearl trash). C: the destructive double rule with a solid trash disc (red means heart).
    private func deleteTile(width: CGFloat) -> some View {
        Button(action: delete) {
            Group {
                switch look.id {
                case .floodlight:
                    Image(systemName: "trash.fill").font(.system(.body, weight: .bold))
                        .foregroundStyle(look.onAction)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(look.destructive, in: RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
                case .anatomy:
                    Image(systemName: "trash").font(.system(.body, weight: .bold))
                        .foregroundStyle(look.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(look.controlFill, in: RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: look.radius.row, style: .continuous).strokeBorder(look.hairline, lineWidth: 1) }
                case .paper, .carbon:
                    let shape = RoundedRectangle(cornerRadius: look.radius.row, style: .continuous)
                    Image(systemName: "trash").font(.system(.footnote, weight: .bold))
                        .foregroundStyle(look.surface)
                        .frame(width: 30, height: 30)
                        .background(look.destructive, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(look.surface, in: shape)
                        // `destructive` is the ink in Paper / Carbon; the final look's red-orange.
                        .overlay { shape.strokeBorder(look.destructive, lineWidth: 2) }
                        .overlay { shape.inset(by: 4).strokeBorder(look.destructive, lineWidth: 1.5) }
                }
            }
            .padding(.vertical, 3)
            .padding(.leading, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .frame(width: width)
        .accessibilityLabel("Delete set")
    }
}

// MARK: - Hidden entry field

/// A hidden text field placed under the row being edited. Focusing it raises the system number
/// pad and lets the list scroll that row above the keyboard; every key updates the Store, so the
/// row's own field shows the number as it is typed.
struct LiveEntryCatcher: View {
    let target: LiveEditTarget
    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        // Only real keystrokes reach the Store: focusing writes the current text back
        // through the binding, which must not clear the row.
        TextField("", text: Binding(get: { model.entryText },
                                    set: { text in
                                        guard text != model.entryText else { return }
                                        model.entryText = text
                                        model.apply(text, store: store)
                                    }))
            .keyboardType(target.field == .weight ? .decimalPad : .numberPad)
            .focused($focused)
            .foregroundStyle(.clear)
            .tint(.clear)
            .opacity(0.02)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { focused = true }
            .onChange(of: focused) { _, isFocused in
                if !isFocused && model.editing == target { model.endEditing() }
            }
    }
}

// MARK: - Editing actions

extension LiveScreenModel {
    func beginEditing(_ target: LiveEditTarget) {
        swipedSetID = nil
        menu = nil
        entryText = ""
        editing = target
    }

    func endEditing() {
        guard editing != nil else { return }
        editing = nil
        entryText = ""
    }

    /// Writes the typed text into the edited field.
    func apply(_ text: String, store: Store) {
        guard let t = editing else { return }
        switch t.field {
        case .weight: store.updateWeight(LiveNumberEntry.weight(text), entryID: t.entryID, setID: t.setID)
        case .reps: store.updateReps(LiveNumberEntry.reps(text), entryID: t.entryID, setID: t.setID)
        }
    }

    /// −/+ on the entry bar. The next key typed replaces the stepped value.
    func step(up: Bool, store: Store) {
        guard let t = editing, let set = store.liveEntry(t.entryID)?.sets.first(where: { $0.id == t.setID }) else { return }
        switch t.field {
        case .weight:
            let s = store.liveWeightStep(entryID: t.entryID, setID: t.setID)
            store.updateWeight(max(0, (set.weight ?? 0) + (up ? s : -s)), entryID: t.entryID, setID: t.setID)
        case .reps:
            let v = max(0, (set.reps ?? 0) + (up ? 1 : -1))
            store.updateReps(v == 0 ? nil : v, entryID: t.entryID, setID: t.setID)
        }
        entryText = ""
    }

    /// The field after the one being edited: weight → reps, then the next unfinished set.
    func nextTarget(store: Store) -> LiveEditTarget? {
        guard let t = editing, let entry = store.liveEntry(t.entryID) else { return nil }
        let takesWeight = store.loadType(entryID: t.entryID).takesWeight
        if t.field == .weight { return LiveEditTarget(entryID: t.entryID, setID: t.setID, field: .reps) }
        guard let i = entry.sets.firstIndex(where: { $0.id == t.setID }),
              let following = entry.sets[(i + 1)...].first(where: { !$0.isCompleted }) else { return nil }
        return LiveEditTarget(entryID: t.entryID, setID: following.id, field: takesWeight ? .weight : .reps)
    }

    func next(store: Store) {
        if let target = nextTarget(store: store) { beginEditing(target) } else { endEditing() }
    }

    /// The check: completes a loggable row (the look's stamp, rest, new best), un-ticks a done
    /// row, or — on a row that is still missing a number — starts typing it.
    func toggleCheck(entryID: UUID, setID: UUID, store: Store, reduceMotion: Bool) {
        guard let entry = store.liveEntry(entryID), let set = entry.sets.first(where: { $0.id == setID }) else { return }
        swipedSetID = nil
        menu = nil
        if set.isCompleted {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                store.uncompleteSet(entryID: entryID, setID: setID)
            }
            return
        }
        if store.isLoggable(entryID: entryID, setID: setID) {
            endEditing()
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) {
                _ = store.completeSet(entryID: entryID, setID: setID)
            }
        } else {
            let needsWeight = store.loadType(entryID: entryID).takesWeight && entry.total(of: set) == nil
            beginEditing(LiveEditTarget(entryID: entryID, setID: setID, field: needsWeight ? .weight : .reps))
        }
    }
}
