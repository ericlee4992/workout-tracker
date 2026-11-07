import SwiftUI
import UIKit

// PROTOTYPE — the live workout cover (L01–L05, L13, Z05). The user's skeleton is kept:
// toolbar (minimise [+ Cancel in A and B] · title with rename · Finish), the header line
// (gym · clock with seconds · N/M sets ring), the vitals strip, Lifting | Cardio once cardio
// exists, exercise cards in template order (drag to reorder, or "Reorder Exercises"), Add
// Exercise / Add by Machine / Add Cardio, and the rest slab at the thumb. C moves discarding to
// "Discard Workout…" at the end of the list.
//
// Capture variants (-variant, "+"-joined): top p2 p3 end edit idle first loads long reorder noGym
// empty (+noSensor) done recovered cap lifting; L02: swipe menu top; L05: rename superset delete;
// L13: finish; rm (Reduce Motion). Store-level (alone): stale, noSensor, degraded (L04).

struct LiveWorkoutScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var model = LiveScreenModel()
    @Environment(LookModel.self) private var lookModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// The final look draws the lifting workout in Paper Club's structure, re-skinned in
    /// Floodlight (FinalLook.swift); cardio focus stays plain Floodlight. Other looks: unchanged.
    private var liveLook: Look {
        // Soft (2026-11 exploration) keeps the same live structure, re-skinned in its own tokens.
        if look.origin == .soft, store.session?.focus != .cardio {
            var live = Look.finalLive(dark: look.isDark, skin: look).withAccent(.mono, live: true)
            live.origin = .soft
            live.font = .soft
            live.outline = look.textPrimary.opacity(0.18)
            live.dash = look.textPrimary.opacity(0.3)
            live.hairline = look.textPrimary.opacity(0.08)
            live.radius = look.radius
            return live
        }
        // Blend (Direction C): the shipped live structure in Mono; exercise cards lifted in light.
        if look.origin == .blend, store.session?.focus != .cardio {
            var live = Look.finalLive(dark: look.isDark, skin: look).withAccent(.mono, live: true)
            live.origin = .blend
            return live
        }
        guard look.origin == .final, store.session?.focus != .cardio else { return look }
        return (look.isDark ? Look.finalLiveDark : Look.finalLiveLight).withAccent(lookModel.accent, live: true)
    }

    var body: some View {
        Group {
            if store.session == nil {
                // The cover is leaving (finished / discarded).
                Color.clear
            } else if store.session?.focus == .cardio {
                LiveCardioFocus()
            } else if model.reordering {
                LiveReorderList()
            } else {
                LiveLiftingList()
            }
        }
        .lookScreenBackground()
        .safeAreaBar(edge: .top) { LiveCoverTopBar() }
        .overlay { LiveMenuLayer() }
        .modifier(LiveDialogs())
        .environment(model)
        // Capture variant "rm": the Reduce Motion alternatives (still stamps, no strobe or swipe).
        .environment(\.liveReduceMotion, systemReduceMotion || LiveVariants.tokens(router.variant).contains("rm"))
        .onAppear {
            applyLaunch()
            applyPendingDialog()
        }
        .onChange(of: router.pendingDialog) { _, _ in applyPendingDialog() }
        .onChange(of: store.session?.id) { _, _ in model.reordering = false }
        .environment(\.look, liveLook)
    }

    /// Once per session: the seeded Push Day's template order, then the session-level capture
    /// variants (they may start a fresh session, which is remembered too).
    private func applyLaunch() {
        guard let session = store.session, !LiveLaunchMemory.appliedSessionIDs.contains(session.id) else { return }
        LiveLaunchMemory.appliedSessionIDs.insert(session.id)
        store.liveRestoreTemplateOrder()
        LiveVariants.applySessionVariants(LiveVariants.tokens(router.variant), store: store, router: router, model: model)
        if let id = store.session?.id { LiveLaunchMemory.appliedSessionIDs.insert(id) }
    }

    /// L05 / L13 open their dialog or menu state from the router (then clear it).
    private func applyPendingDialog() {
        guard let dialog = router.pendingDialog, store.session != nil else { return }
        let tokens = LiveVariants.tokens(router.variant)
        let entryID = store.screenTarget.entryID ?? store.currentEntryID
        router.pendingDialog = nil
        // Let the cover finish presenting (and the list settle) before a menu or alert rises.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            switch dialog {
            case .l05:
                if tokens.contains("rename") {
                    model.beginRename(store: store)
                } else if tokens.contains("delete") {
                    model.deleteEntryID = entryID
                } else if tokens.contains("superset") {
                    // The "…" of a superset member (Break superset): bring its card in first.
                    let member = store.session?.entries.first { store.supersetLabel(entryID: $0.id) != nil }?.id
                    if let member {
                        model.scrollRequest = LiveScrollRequest(id: member, anchor: UnitPoint(x: 0.5, y: 0.2))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { model.openMenu(.entry(member)) }
                    }
                } else if let entryID {
                    // If the card's "…" is out of view (AX sizes), bring the title in first, then drop
                    // the menu from it.
                    let button = model.anchors[.entry(entryID)]
                    let visible = button.map { $0.minY > model.topBarBottom && $0.maxY < (model.dockTop ?? .infinity) } ?? false
                    if visible {
                        model.openMenu(.entry(entryID))
                    } else {
                        model.scrollRequest = LiveScrollRequest(id: entryID, anchor: UnitPoint(x: 0.5, y: 0))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { model.openMenu(.entry(entryID)) }
                    }
                }
            case .l13:
                if tokens.contains("finish") {
                    model.confirmFinish = true
                } else if liveLook.id.isPaperClub {
                    // C discards from "Discard Workout…" at the end of the list: show it there.
                    model.scrollRequest = LiveScrollRequest(id: LiveRowID.end, anchor: .bottom)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { model.confirmDiscard = true }
                } else {
                    model.confirmDiscard = true
                }
            default:
                break
            }
        }
    }
}

// MARK: - Lifting focus

private struct LiveLiftingList: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let session = store.session
        let entries = session?.entries ?? []
        ScrollViewReader { proxy in
            List {
                LiveHeaderRow().liveRowFrame(LiveRowID.header, model)
                    .background { LiveScrollProbe(model: model) }
                    .liveRow(top: 4, bottom: 6).id(LiveRowID.header)
                LiveVitalsRow().liveRowFrame(LiveRowID.vitals, model).liveRow(top: 6, bottom: 8).id(LiveRowID.vitals)
                if session?.hasCardio == true {
                    LiveFocusSwitch().liveRowFrame(LiveRowID.focus, model).liveRow(top: 4, bottom: 6).id(LiveRowID.focus)
                }
                if let cardio = session?.unfinishedCardio {
                    LiveCardioReturnRow(cardioID: cardio.id).liveRow(top: 2, bottom: 8)
                }
                ForEach(entries) { entry in
                    let position = store.liveSupersetPosition(entry.id)
                    let joinedAbove = position == .middle || position == .last
                    let joinedBelow = position == .first || position == .middle
                    LiveExerciseCard(entryID: entry.id)
                        .liveRowFrame(entry.id, model)
                        .liveRow(top: joinedAbove ? 1 : 6, bottom: joinedBelow ? 1 : 6)
                        .id(entry.id)
                }
                .onMove { source, destination in
                    model.endEditing()
                    withAnimation(reduceMotion ? nil : .default) {
                        store.moveEntries(fromOffsets: source, toOffset: destination)
                    }
                }
                if let planned = session?.plannedCardio, !planned.isEmpty {
                    LivePlannedCardioSection(planned: planned).liveRowFrame(LiveRowID.planned, model)
                        .liveRow(top: 18, bottom: 6).id(LiveRowID.planned)
                }
                LiveAddBlock(isEmpty: entries.isEmpty).liveRowFrame(LiveRowID.add, model).liveRow(top: entries.isEmpty ? 10 : 18, bottom: 8).id(LiveRowID.add)
                if entries.isEmpty, let gymID = session?.gymID, !store.recentExercises(gymID: gymID, limit: 1).isEmpty {
                    LiveRecentSection(gymID: gymID).liveRow(top: 18, bottom: 4)
                }
                // As shipped: discarding is the red Cancel at the top left, not a row here.
                Color.clear.frame(height: 12).liveRow(top: 0, bottom: 0).id(LiveRowID.end)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { LiveBottomDock() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let screen = UIScreen.main.bounds.height
                model.keyboardTop = end.minY >= screen - 1 ? nil : end.minY
            }
            .onAppear { applyLaunchState(proxy) }
            .proposalScreen("live")
            .overlay(alignment: .center) {
                if LiveVariants.tokens(router.variant).contains("debug") {
                    Text(model.debugLines.joined(separator: "\n")).font(.system(size: 11).monospaced())
                        .padding(6).background(.yellow).foregroundStyle(.black)
                        .dynamicTypeSize(.large)
                }
            }
            .onChange(of: model.editing) { old, new in
                guard let new, new.setID != old?.setID else { return }
                // The number pad already up (Next): reveal now. Otherwise wait for it to land
                // (keyboardDidShow), with a late safety pass in case that notice is missed.
                if model.keyboardTop != nil { reveal(new, proxy: proxy, after: 0.15) }
                reveal(new, proxy: proxy, after: 1.2)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if let editing = model.editing { reveal(editing, proxy: proxy, after: 0.05) }
            }
            .onChange(of: model.scrollRequest) { _, request in
                guard let request else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { proxy.scrollTo(request.id, anchor: request.anchor) }
            }
            .onChange(of: model.confirmFinish) { _, isUp in
                guard isUp, let first = store.liveFirstUnloggedSet else { return }
                // Above the centred alert, so the flagged row stays in view while it asks.
                aim(setID: first.setID, entryID: first.entryID, at: 0.1, onlyIfHidden: false, proxy: proxy)
            }
        }
    }

    // MARK: Aimed scrolling

    /// The clear band between the glass top bar and whatever floats at the thumb (the rest slab,
    /// the NEW BEST band, or — while typing — the entry bar riding on the number pad). Both edges
    /// are measured on screen, so the band is right at every text size and with the keyboard up.
    private var clearTop: CGFloat { model.topBarBottom + 4 }
    private var clearBottom: CGFloat { model.dockTop ?? UIScreen.main.bounds.height - 40 }

    /// Scrolls so a set row sits at fraction `t` of the clear band (less `gap` at the bottom),
    /// by moving the list's content offset by exactly the measured distance (anchors cannot place
    /// a row that sits deep inside a card taller than the screen, as at AX sizes). A row not laid
    /// out yet gets its card scrolled in first. Each move is checked once more after it lands
    /// (the number pad or the cover may still have been moving).
    private func aim(setID: UUID, entryID: UUID, at t: CGFloat, onlyIfHidden: Bool, proxy: ScrollViewProxy,
                     gap: CGFloat = 0, step: Int = 0) {
        let screen = UIScreen.main.bounds.height
        guard let p = model.rows[setID], p.cardHeight > 0, let scroll = model.scrollView,
              p.globalMid > -screen, p.globalMid < screen * 2 else {
            proxy.scrollTo(entryID, anchor: .top)
            if step < 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    aim(setID: setID, entryID: entryID, at: t, onlyIfHidden: onlyIfHidden, proxy: proxy, gap: gap, step: step + 1)
                }
            }
            return
        }
        let top = clearTop, bottom = clearBottom - gap
        let rowTop = p.globalMid - p.height / 2, rowBottom = p.globalMid + p.height / 2
        model.debugLines.append(String(format: "aim%d clear %.0f-%.0f row %.0f-%.0f off %.0f", step, top, bottom, rowTop, rowBottom, scroll.contentOffset.y))
        if (onlyIfHidden || step > 0) && rowTop > top + 2 && rowBottom < bottom - 2 { return }
        let span = max(1, bottom - top)
        let half = p.height / 2 + 8
        let wanted = top + min(max(t * span, half), max(half, span - half))
        let delta = wanted - p.globalMid
        guard abs(delta) > 4 else { return }
        let inset = scroll.adjustedContentInset
        let minY = -inset.top
        let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
        let y = min(max(scroll.contentOffset.y - delta, minY), maxY)
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: y), animated: !reduceMotion)
        guard step < 2 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.15 : 0.45)) {
            aim(setID: setID, entryID: entryID, at: t, onlyIfHidden: onlyIfHidden, proxy: proxy, gap: gap, step: step + 1)
        }
    }

    /// Bring the row being typed above the entry bar (which rides on the number pad), unless it
    /// is already clear: the whole field must sit at least 12 pt above the bar.
    private func reveal(_ target: LiveEditTarget, proxy: ScrollViewProxy, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard model.editing?.setID == target.setID else { return }
            aim(setID: target.setID, entryID: target.entryID, at: 0.5, onlyIfHidden: true, proxy: proxy, gap: 12)
        }
    }

    /// Capture variants, once per session: p2 / p3 scroll to the middle / end; L02 opens the
    /// set-type menu on one row and swipes another open; "edit" starts typing the next set.
    /// Every opening (and every resume) brings the next-up set into view.
    private func applyLaunchState(_ proxy: ScrollViewProxy) {
        guard let session = store.session else { return }
        let firstTime = !LiveLaunchMemory.scrolledSessionIDs.contains(session.id)
        LiveLaunchMemory.scrolledSessionIDs.insert(session.id)
        let tokens = firstTime ? LiveVariants.tokens(router.variant) : []
        let screen = store.currentScreen
        let target = store.screenTarget
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let entries = store.session?.entries ?? []
            if tokens.contains("top") {
                proxy.scrollTo(LiveRowID.header, anchor: .top)
            } else if tokens.contains("p2") {
                let anchor = store.nextEntryID ?? entries.dropFirst().first?.id
                if let anchor { proxy.scrollTo(anchor, anchor: .top) }
            } else if tokens.contains("p3") {
                if entries.count >= 4 {
                    proxy.scrollTo(entries[entries.count - 2].id, anchor: .top)
                } else {
                    proxy.scrollTo(LiveRowID.end, anchor: .bottom)
                }
            } else if tokens.contains("end") || tokens.contains("p4") || tokens.contains("noGym") {
                proxy.scrollTo(LiveRowID.end, anchor: .bottom)
            } else if tokens.contains("first") || tokens.contains("loads") {
                let from = tokens.contains("loads") ? max(0, entries.count - 3) : entries.count - 1
                if entries.indices.contains(from) { proxy.scrollTo(entries[from].id, anchor: .top) }
            } else if tokens.contains("lifting") {
                proxy.scrollTo(LiveRowID.planned, anchor: .center)
            } else if tokens.contains("edit") {
                if let next = store.nextSet {
                    let takesWeight = store.loadType(entryID: next.entryID).takesWeight
                    model.beginEditing(LiveEditTarget(entryID: next.entryID, setID: next.setID,
                                                      field: takesWeight ? .weight : .reps))
                }
            } else if screen == .l02 && (tokens.isEmpty || tokens.contains("swipe") || tokens.contains("menu")) {
                let showMenu = !tokens.contains("swipe"), showSwipe = !tokens.contains("menu")
                let swipedEntry = store.session?.entries.first { $0.sets.contains { $0.id == target.setID } }?.id
                if let entry = showSwipe ? (swipedEntry ?? target.entryID) : target.entryID {
                    proxy.scrollTo(entry, anchor: showSwipe ? .bottom : .center)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Menu first (opening a menu closes any swiped row), then the swipe.
                    if showMenu, let entry = target.entryID, let set = target.secondarySetID {
                        model.openMenu(.setType(entryID: entry, setID: set))
                    }
                    if showSwipe { model.swipedSetID = target.setID }
                }
            } else if let next = store.nextSet {
                // The screen's one glance job: what do I do now.
                aim(setID: next.setID, entryID: next.entryID, at: typeSize.isAccessibilitySize ? 0.42 : 0.55,
                    onlyIfHidden: true, proxy: proxy)
            }
        }
    }
}

enum LiveRowID: Hashable { case title, header, vitals, focus, planned, add, end }

extension View {
    /// Records the row's global frame (for choosing a scroll anchor).
    func liveRowFrame(_ id: AnyHashable, _ model: LiveScreenModel) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.rowFrames[id] = $0 }
    }

    /// A bare list row: no separator, no background, the 20 pt margin.
    func liveRow(top: CGFloat, bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

/// Gym · clock with seconds · N/M sets ring (reads the ticking clock).
private struct LiveHeaderRow: View {
    var showsSets = true
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let session = store.session
        let gym = store.gym(session?.gymID)?.name ?? "No gym"
        let done = session?.completedSetCount ?? 0, total = session?.totalSetCount ?? 0
        if typeSize.isAccessibilitySize {
            // The workout name leaves the top bar and joins the header.
            LiveAXHeader(gym: gym, elapsed: store.sessionElapsed, done: done, total: total, showsSets: showsSets)
        } else {
            LiveHeaderBar(gym: gym, elapsed: store.sessionElapsed, done: done, total: total, showsSets: showsSets)
        }
    }
}

/// Heart rate · active calories · total volume. Missing facts are absent, never 0.
private struct LiveVitalsRow: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let hr: Int?
        let stale: Bool
        let staleSeconds: Int?
        switch store.hrFeed {
        case .live: hr = store.currentBPM; stale = false; staleSeconds = nil
        case .stale(let last, let ago): hr = last; stale = true; staleSeconds = ago
        case .waiting: hr = nil; stale = false; staleSeconds = nil
        }
        return LiveVitals(hr: hr, zone: hr.flatMap { store.zone(for: $0) }, isStale: stale, staleSeconds: staleSeconds,
                          activeCal: store.liveActiveCalories,
                          volume: store.displayUnit.fromKg(store.sessionVolumeKg).rounded(), unit: store.displayUnit,
                          onHeartRate: { router.present(.maxHeartRate) })
    }
}

/// Lifting | Cardio (appears once the workout has cardio).
private struct LiveFocusSwitch: View {
    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model

    var body: some View {
        SegmentedPills(["Lifting", "Cardio"], selection: Binding(
            get: { store.session?.focus == .cardio ? 1 : 0 },
            set: { index in
                model.endEditing()
                store.setFocus(index == 1 ? .cardio : .lifting)
            }))
            .accessibilityLabel("Activity")
    }
}

// MARK: - Reorder mode

/// "Reorder Exercises": every card folds to one line — its chip, name and N/M sets — with the
/// system drag handle, so moving a 400 pt card is a short, visible drag. Done (top bar) returns.
/// A long press on a full card still lifts it too.
private struct LiveReorderList: View {
    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let entries = store.session?.entries ?? []
        List {
            LiveHeaderRow().liveRow(top: 4, bottom: 10)
            ForEach(entries) { entry in
                LiveReorderRow(entryID: entry.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onMove { source, destination in
                withAnimation(reduceMotion ? nil : .default) {
                    store.moveEntries(fromOffsets: source, toOffset: destination)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .environment(\.editMode, .constant(.active))
        .safeAreaInset(edge: .bottom, spacing: 0) { LiveBottomDock() }
        .transition(.opacity)
    }
}

private struct LiveReorderRow: View {
    let entryID: UUID
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        let entry = store.liveEntry(entryID)
        let progress = store.liveProgress(entryID: entryID)
        let letter = store.supersetLabel(entryID: entryID)
        let done = progress.total > 0 && progress.done == progress.total
        HStack(spacing: 10) {
            if letter != nil || done { LiveSupersetChip(letter: letter, done: done) }
            Text(store.exercise(entry?.exerciseID)?.name ?? "Exercise")
                .font(look.id.isPaperClub ? look.font.cardTitle : .system(.headline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text("\(progress.done)/\(progress.total)")
                .font(.system(.subheadline, weight: .heavy).width(look.id == .anatomy ? .standard : .expanded).monospacedDigit())
                .foregroundStyle(look.textSecondary)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .modifier(LiveCardSurface())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cardio focus

/// The cardio focus: the same header, the switch, then the Cardio area's panel (it owns its
/// pinned Pause / End controls). No rest bar here: starting cardio skips rest.
private struct LiveCardioFocus: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 12) {
                LiveHeaderRow(showsSets: false)
                LiveFocusSwitch()
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            CardioLivePanel()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .proposalScreen("cardio")
    }
}

/// Lifting focus while a cardio segment runs in the background: a live row back to it.
private struct LiveCardioReturnRow: View {
    let cardioID: UUID
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        if let cardio = store.session?.cardio.first(where: { $0.id == cardioID }) {
            let running = cardio.isRunning
            Button { store.setFocus(.cardio) } label: {
                HStack(spacing: 12) {
                    IconDisc(symbol: cardio.activity.symbol, size: 40, context: .onSurface)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cardio.activity.name).font(look.font.headline).foregroundStyle(look.textPrimary)
                        HStack(spacing: 6) {
                            if running { LiveRecordingDot() }
                            Text(running ? "Recording" : "Paused")
                                .font(look.font.footnote)
                                .foregroundStyle(running ? look.textPrimary : look.textSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(Format.elapsed(cardio.activeSeconds(at: store.now)))
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 60)
                .lookSurface(.tile)
            }
            .buttonStyle(.lookPressable)
            .accessibilityHint("Shows the cardio")
        }
    }
}

// MARK: - Planned cardio

/// Template cardio targets after the lifting: activity, the planned minutes (and distance),
/// an explicit Start, then Recording / Paused with the target filling, and Done.
private struct LivePlannedCardioSection: View {
    let planned: [PlannedCardio]
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Planned cardio")
            VStack(spacing: 0) {
                ForEach(Array(planned.enumerated()), id: \.element.id) { index, plan in
                    if index > 0 { LookDivider().padding(.leading, 66) }
                    LivePlannedCardioRow(plan: plan)
                }
            }
            .lookSurface(.card)
        }
    }
}

private struct LivePlannedCardioRow: View {
    let plan: PlannedCardio
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let status = store.plannedStatus(plan.id)
        let busy = store.session?.unfinishedCardio != nil
        let target = plan.distance.map { "\(plan.minutes) min · \(Format.number($0)) \(plan.unit.label)" } ?? "\(plan.minutes) min"
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        VStack(alignment: .leading, spacing: 8) {
            layout {
                HStack(spacing: 12) {
                    IconDisc(symbol: plan.activity.symbol, size: 40, context: .onSurface)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.activity.name).font(look.font.headline).foregroundStyle(look.textPrimary)
                        Text(target).font(look.font.subhead).foregroundStyle(look.textSecondary)
                    }
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                trailing(status, busy: busy)
            }
            if status != .notStarted, let p = store.plannedProgress(plan.id) {
                LivePlannedBar(progress: p, done: status == .done)
                    .padding(.leading, typeSize.isAccessibilitySize ? 0 : 52)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { if status == .recording || status == .paused { store.setFocus(.cardio) } }
    }

    @ViewBuilder private func trailing(_ status: PlannedCardioStatus, busy: Bool) -> some View {
        switch status {
        case .notStarted:
            Button("Start") {
                withAnimation(reduceMotion ? nil : .default) { store.startPlannedCardio(plan.id) }
            }
            .buttonStyle(LiveSmallCapsuleStyle())
            .disabled(busy)
            .accessibilityLabel("Start \(plan.activity.name)")
        case .recording, .paused:
            HStack(spacing: 6) {
                if status == .recording { LiveRecordingDot() } else {
                    Image(systemName: "pause.fill").font(.system(.caption2, weight: .bold)).foregroundStyle(look.textSecondary)
                }
                Text(status == .recording ? "Recording" : "Paused")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(status == .recording ? look.textPrimary : look.textSecondary)
            }
        case .done:
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(.footnote, weight: .heavy))
                Text("Done").font(.system(.subheadline, weight: .semibold))
            }
            .foregroundStyle(look.textPrimary)
        }
    }
}

/// The planned target filling: live colour while it runs, the look's done colour once it is met.
private struct LivePlannedBar: View {
    var progress: Double
    var done: Bool
    @Environment(\.look) private var look

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(look.ringTrack)
                Capsule().fill(done ? look.done : look.live)
                    .frame(width: max(6, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Add block

/// Add Exercise (the filled command when nothing else is — rest is not running and, in A, no
/// set is waiting for its check) with Add by Machine and Add Cardio as equal quiet peers.
private struct LiveAddBlock: View {
    var isEmpty: Bool
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let hasGym = store.session?.gymID != nil
        let resting = store.rest != nil
        let primary = !resting && (look.id != .floodlight || store.nextSet == nil)
        VStack(spacing: 10) {
            if primary {
                PrimaryButton("Add Exercise", symbol: "plus") { open(.exercisePicker) }
            } else {
                Button { open(.exercisePicker) } label: {
                    if look.id.isPaperClub { peerLabel("Add Exercise", symbol: "plus") } else { Label("Add Exercise", systemImage: "plus") }
                }
                .buttonStyle(.lookSecondary)
            }
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) { peers(hasGym: hasGym) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { peers(hasGym: hasGym) }
                    VStack(spacing: 10) { peers(hasGym: hasGym) }
                }
            }
            if !hasGym {
                Text("Pick a gym to log by machine")
                    .font(look.font.caption)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private func peers(hasGym: Bool) -> some View {
        Button { open(.addByMachine) } label: { peerLabel("Add by Machine", symbol: LookIcon.machine) }
            .buttonStyle(.lookSecondary)
            .disabled(!hasGym)
            .opacity(hasGym ? 1 : 0.4)
        Button { open(.cardioPicker) } label: { peerLabel("Add Cardio", symbol: "figure.run") }
            .buttonStyle(.lookSecondary)
    }

    private func peerLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            IconDisc(symbol: symbol, size: 30, context: .onSurface)
            Text(title).lineLimit(typeSize.isAccessibilitySize ? 2 : 1).fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
        }
        .padding(.horizontal, -12)
    }

    private func open(_ route: SheetRoute) {
        model.endEditing()
        router.present(route)
    }
}

// MARK: - Empty workout: recent at this gym

/// An empty workout is not half a screen of black: the exercises last done at this gym, newest
/// first, each one tap from a card (the same list the exercise picker opens with).
private struct LiveRecentSection: View {
    let gymID: UUID
    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        let exercises = store.recentExercises(gymID: gymID, limit: 5)
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Recent at \(store.gym(gymID)?.name ?? "this gym")")
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    if index > 0 { LookDivider().padding(.leading, 16) }
                    row(exercise)
                }
            }
            .lookSurface(.card)
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        Button {
            model.endEditing()
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
                _ = store.addExercise(exercise.id)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(look.font.headline)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let date = store.lastTrained(exerciseID: exercise.id) {
                        Text(look.lastDoneLabel(date, now: store.now))
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                IconDisc(symbol: "plus", size: 34, context: .onSurface)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("Add \(exercise.name)")
    }
}

// MARK: - Dialogs

/// Rename, discard, finish with unticked rows, and delete-exercise confirmations. Alerts (not
/// confirmation dialogs): iOS 26 draws a dialog attached to a whole screen as a popover that
/// drops its cancel button, so "Keep Logging" would vanish. An alert always shows both.
private struct LiveDialogs: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        @Bindable var model = model
        let unlogged = store.unloggedSetCount
        let deleteEntry = store.liveEntry(model.deleteEntryID)
        let deleteName = deleteEntry.flatMap { store.exercise($0.exerciseID)?.name } ?? "Exercise"
        let deleteLogged = deleteEntry?.completedCount ?? 0
        content
            .alert("Workout Name", isPresented: $model.renaming) {
                TextField(store.liveDerivedTitle, text: $model.renameText)
                Button("Save") { store.renameWorkout(model.renameText) }
                Button("Cancel", role: .cancel) {}
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                // The rename field opens with the current name selected: type to replace, or edit it.
                guard model.renaming, let field = note.object as? UITextField else { return }
                DispatchQueue.main.async { field.selectAll(nil) }
            }
            .alert("Cancel this workout?", isPresented: $model.confirmDiscard) {
                Button("Discard Workout", role: .destructive) { store.cancelWorkout() }
                Button("Keep Logging", role: .cancel) {}
            } message: {
                Text("The workout and everything logged in it will be deleted.")
            }
            .alert(unlogged == 1 ? "1 set isn’t ticked" : "\(unlogged) sets aren’t ticked", isPresented: $model.confirmFinish) {
                Button("Finish Anyway", role: .destructive) { model.finish(store: store, router: router) }
                Button("Keep Logging", role: .cancel) {}
            } message: {
                Text(unlogged == 1 ? "It won’t be saved." : "They won’t be saved.")
            }
            .alert("Delete \(deleteName)?", isPresented: Binding(
                get: { model.deleteEntryID != nil }, set: { if !$0 { model.deleteEntryID = nil } })) {
                Button("Delete Exercise", role: .destructive) {
                    if let id = model.deleteEntryID {
                        withAnimation { store.removeExercise(entryID: id) }
                    }
                    model.deleteEntryID = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if deleteLogged > 0 {
                    Text(deleteLogged == 1 ? "1 logged set will be deleted." : "\(deleteLogged) logged sets will be deleted.")
                }
            }
    }
}

extension LiveScreenModel {
    /// Rename opens with the current title in the field (selected), not an empty field.
    func beginRename(store: Store) {
        endEditing()
        closeMenu()
        renameText = store.sessionTitle
        renaming = true
    }

    /// Finish: with typed-but-unticked rows, say they will not be saved first.
    func finishTapped(store: Store, router: Router) {
        endEditing()
        closeMenu()
        if store.unloggedSetCount > 0 {
            confirmFinish = true
        } else {
            finish(store: store, router: router)
        }
    }

    func finish(store: Store, router: Router) {
        _ = store.finish()
        router.finishWorkout()
    }
}
