import SwiftUI

// PROTOTYPE — F01–F03: the finish receipt, the celebration moment.
//
// The user's kept skeleton, top to bottom: nav "Nice work" + Done; status ring + "Workout
// saved" + summary; View in History (the one filled command) and Save as Template; the paired
// tiles in the user's order; then the engagement layer — new bests, the last run of the
// template, the families trained, the heart-rate graph with time in zones directly below, and
// the exercises with their best sets. A mixed session keeps its lifting facts together and
// then the run: new bests → the template comparison → Cardio (route map) → Heart rate (the
// whole session) → Lifting. Nothing logged → the "wasn't saved" state.
//
// Motion — the header plays once the sheet lands: the ring draws while the running totals
// count up (heart rate fades in at its final values), the check lands (success haptic). Every
// section below plays its own entry when the user reaches it (40 % scrolled into view): the
// new bests land one by one (light haptics), B's maps light, C's muscle-group tiles land,
// the route traces, the heart-rate graph draws in, and the exercise marks swipe in. Tapping
// the ring replays all of it. Reduce Motion: everything is drawn in its final state at once.
// A frozen-clock launch (`-screen F01 -freezeClock YES`, the captures) also opens fully
// drawn, per the prototype contract; the ring tap still plays the reveal there.
//
// Save as Template opens T04 from inside the receipt (its own sheet), so Save or Cancel comes
// back here, where "Saved as template “{name}”" replaces the button.
//
// States: `store.finishSummary` (F01 / F02 saved, F03 `saved == false`). Review variants
// (`-variant a+b`, see FinishVariant): p2…p9 (open on that page), saved, saveSheet, noHR,
// firstRun, freeform, cardioOnly, indoor, firsts, assisted, offline, long, rm.

struct FinishSummarySheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// The receipt as it was when the sheet opened (with any review variant applied), so
    /// nothing blanks while it slides away.
    @State private var snapshot: FinishSummary?
    @State private var variant = FinishVariant(nil)
    @State private var didSetUp = false
    @State private var revealStarted = false
    /// The header's check has landed; sections on screen may play from here on.
    @State private var headerDone = false
    @State private var visible: Set<FinishRevealSection> = []
    @State private var revealed: Set<FinishRevealSection> = []
    @State private var replayID = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var didApplyVariant = false
    /// The scroll view's latest sizes (the page variants read them when they fire).
    @State private var scrollMetrics = FinishScrollMetrics(viewport: 0, content: 0, top: 0, bottom: 0)
    /// Where each section and card starts (content coordinates), so "pN" lands on a boundary.
    @State private var marks: [UUID: FinishSectionTop.Mark] = [:]
    private var sectionTops: [FinishSectionTop.Mark] { marks.values.sorted() }
    /// "Nothing to save" sizes its sheet to its content (a compact confirmation, not a
    /// half-empty page).
    @State private var compactHeight: CGFloat = 300
    /// Templates that existed when the receipt opened; one that appears later was saved here.
    @State private var templateBaseline: Set<UUID>?
    @State private var templateSheet: FinishTemplateSheetItem?

    private var summary: FinishSummary {
        snapshot ?? store.finishSummary ?? Derived.notSavedSummary(at: store.now)
    }

    private var reduceMotion: Bool { systemReduceMotion || variant.reduceMotion }

    /// Draw the final state at once: Reduce Motion, or a frozen capture launch (until a replay).
    private var instant: Bool { reduceMotion || (store.freezeClock && replayID == 0) }

    var body: some View {
        let data = store.finishData(for: summary)
        NavigationStack {
            ScrollView {
                content(data)
                    .id(summary.id)
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, summary.saved ? 6 : 4)
                    .padding(.bottom, summary.saved ? 44 : 20)
                    .coordinateSpace(name: FinishSectionTop.space)
                    .environment(\.finishMarkReport) { id, mark in marks[id] = mark }
                    .transaction { transaction in
                        // No entry motion at all in the instant state (components animate on appear).
                        if instant { transaction.disablesAnimations = true; transaction.animation = nil }
                    }
            }
            .scrollPosition($position)
            .onScrollGeometryChange(for: FinishScrollMetrics.self) { geo in
                FinishScrollMetrics(viewport: geo.containerSize.height, content: geo.contentSize.height,
                                    top: geo.contentInsets.top, bottom: geo.contentInsets.bottom)
            } action: { _, metrics in
                applyScrollVariant(metrics)
                if !summary.saved, metrics.content > 0 {
                    compactHeight = (metrics.content + metrics.top + 8).rounded()
                }
            }
            .lookSheetGround()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $templateSheet) { item in
                SaveAsTemplateSheet(workoutID: item.id)
                    .preferredColorScheme(look.colorScheme)
            }
        }
        .modifier(FinishTypeSizeOverride(size: router.dynamicTypeOverride))
        .modifier(FinishReduceMotionOverride(on: variant.reduceMotion))
        .presentationDetents(summary.saved ? [.large] : [.height(compactHeight)])
        .presentationBackground(look.groundSheet)
        .presentationCornerRadius(look.radius.sheet)
        .onAppear(perform: setUp)
        .proposalScreen("finish")
        .task(id: replayID) { await runReveal(store.finishData(for: summary)) }
        .onDisappear { store.dismissFinish() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if summary.saved {
            ToolbarItem(placement: .principal) {
                Text("Nice work")
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { router.dismissSheet() } label: {
                Text("Done")
                    .font(look.id == .anatomy ? look.font.button : .system(.body, weight: look.id.isPaperClub ? .bold : .semibold))
                    .foregroundStyle(look.textPrimary)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    // MARK: - Content

    @ViewBuilder private func content(_ data: FinishData) -> some View {
        VStack(alignment: .leading, spacing: look.space.section) {
            VStack(alignment: .leading, spacing: look.id == .floodlight ? 26 : 22) {
                FinishStatusHeader(data: data, ringShown: revealStarted || instant, replayID: replayID) {
                    replayID += 1
                }
                // PROPOSAL: the peak first — the new bests, big — then the figures as one line.
                if summary.saved && !data.bests.isEmpty {
                    ProposedBestsHero(bests: data.bests)
                        .revealWhenVisible(.bests, report: sectionVisibility)
                }
                if summary.saved { ProposedSummaryList(summary: summary) }
                if summary.saved { actions(data) }
            }
            if summary.saved {
                // PROPOSAL: compare with last time only when it is a like-for-like session (not a
                // short or partial one that would end the receipt on a big drop).
                if let comparison = summary.comparison, comparison.lastVolumeKg > 0, comparison.volumeKg > 0,
                   (comparison.volumeChangePercent ?? 0) >= -25 {
                    FinishComparisonSection(comparison: comparison, unit: store.displayUnit)
                        .finishSectionTop()
                }
                if data.cardio.isEmpty {
                    if look.id.isPaperClub { families(data) }
                    heartRate(data)
                    exercises(data, title: "Exercises")
                } else {
                    cardio(data)
                    heartRate(data)
                    if look.id.isPaperClub { families(data) }
                    exercises(data, title: "Lifting")
                }
            }
        }
    }

    // MARK: Actions

    @ViewBuilder private func actions(_ data: FinishData) -> some View {
        VStack(spacing: look.id.isPaperClub ? 14 : 10) {
            PrimaryButton("View in History", symbol: "clock.arrow.circlepath") { viewInHistory() }
            if let id = summary.workoutID {
                if let saved = savedTemplate {
                    FinishSavedTemplateLine(name: saved.name)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if store.canSaveAsTemplate(workoutID: id) {
                    Button { templateSheet = FinishTemplateSheetItem(id: id) } label: {
                        Label("Save as Template", systemImage: "square.on.square")
                    }
                    .buttonStyle(.lookSecondary)
                    .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.75), value: savedTemplate?.id)
    }

    /// The template saved from this receipt (it appeared after the receipt opened).
    private var savedTemplate: Template? {
        guard let baseline = templateBaseline else { return nil }
        return store.templates.last { !baseline.contains($0.id) }
    }

    // MARK: Workout details

    @ViewBuilder private func details(_ data: FinishData) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            if !look.id.isPaperClub { SectionHeader("Workout details") }
            ZStack(alignment: .top) {
                if revealStarted || instant {
                    FinishStatGrid(tiles: summary.tiles, animated: !instant)
                        .id(replayID)
                        .transition(.opacity)
                } else {
                    // Holds the grid's place until the reveal starts, so nothing jumps.
                    FinishStatGrid(tiles: summary.tiles, animated: false).hidden()
                }
            }
            if look.id == .anatomy && !data.trainedFamilies.isEmpty {
                FinishFamiliesSection(data: data, revealed: revealed.contains(.families), instant: instant)
                    .revealWhenVisible(.families, report: sectionVisibility)
                    .finishSectionTop()
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Sections below

    @ViewBuilder private func families(_ data: FinishData) -> some View {
        if !data.trainedFamilies.isEmpty {
            FinishFamiliesSection(data: data, revealed: revealed.contains(.families), instant: instant)
                .revealWhenVisible(.families, report: sectionVisibility)
                .finishSectionTop()
        }
    }

    @ViewBuilder private func heartRate(_ data: FinishData) -> some View {
        if !data.hrSlots.isEmpty || !data.zoneTimes.isEmpty {
            FinishHeartRateSection(summary: summary, slots: data.hrSlots, zoneSeconds: data.zoneSeconds,
                                   maxHeartRate: store.maxHeartRate,
                                   revealed: revealed.contains(.heartRate))
                .revealWhenVisible(.heartRate, report: sectionVisibility)
                .finishSectionTop()
        }
    }

    @ViewBuilder private func exercises(_ data: FinishData, title: String) -> some View {
        if !data.exercises.isEmpty {
            FinishExercisesSection(rows: data.exercises, title: title, revealed: revealed.contains(.exercises))
                .revealWhenVisible(.exercises, report: sectionVisibility)
                .finishSectionTop()
        }
    }

    @ViewBuilder private func cardio(_ data: FinishData) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Cardio")
            ForEach(data.cardio) { segment in
                FinishCardioCard(segment: segment, heartRate: store.finishSegmentHeartRate(segment, in: data.workout),
                                 traceShown: revealed.contains(.cardio), offline: variant.offline,
                                 waitsForSheet: !store.freezeClock)
            }
        }
        .revealWhenVisible(.cardio, report: sectionVisibility)
        .finishSectionTop()
    }

    // MARK: - Set-up

    private func setUp() {
        guard !didSetUp else { return }
        didSetUp = true
        templateBaseline = Set(store.templates.map(\.id))
        let base = store.finishSummary
        // Review variants apply only to the receipt a `-screen F01/F02` reset produced.
        let isReset = (store.currentScreen.map { [ScreenID.f01, .f02].contains($0) } ?? false)
            && base?.workoutID != nil && base?.workoutID == store.screenTarget.workoutID
        guard isReset, let base else { snapshot = base; return }
        variant = FinishVariant(router.variant)
        snapshot = variant.apply(to: base, store: store)
        if variant.saved, let id = snapshot?.workoutID {
            store.saveAsTemplate(workoutID: id, name: store.defaultTemplateName(workoutID: id))
        }
        if variant.saveSheet, let id = snapshot?.workoutID {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { templateSheet = FinishTemplateSheetItem(id: id) }
        }
    }

    // MARK: - Reveal

    /// When the ring's check lands, per look (the ring's draw time).
    private func checkDelay(_ data: FinishData) -> Double {
        switch look.id {
        case .floodlight: Double(min(max(data.allSetsByFamily.reduce(0) { $0 + $1.sets }, 1), 24)) * 0.028 + 0.35
        case .anatomy: 0.8 + Double(max(0, data.workingSetsByFamily.count - 1)) * 0.25
        case .paper, .carbon: 0.9
        }
    }

    /// The sections in page order (B's families card sits right under the tiles; C's muscle
    /// groups follow the lifting summary).
    private func pageOrder(_ data: FinishData) -> [FinishRevealSection] {
        var order: [FinishRevealSection] = look.id == .anatomy ? [.families, .bests] : [.bests]
        if data.cardio.isEmpty {
            if look.id.isPaperClub { order.append(.families) }
            order.append(.heartRate)
        } else {
            order += [.cardio, .heartRate]
            if look.id.isPaperClub { order.append(.families) }
        }
        order.append(.exercises)
        return order
    }

    private func sectionVisibility(_ section: FinishRevealSection, _ isVisible: Bool) {
        if isVisible { visible.insert(section) } else { visible.remove(section) }
        if isVisible, headerDone, !revealed.contains(section) { revealed.insert(section) }
    }

    private func runReveal(_ data: FinishData) async {
        guard summary.saved else { return }
        if instant {
            revealStarted = true
            headerDone = true
            revealed = Set(FinishRevealSection.allCases)
            return
        }
        if replayID == 0 {
            // Let the sheet land first, then play.
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.2)) { revealStarted = true }
        } else {
            headerDone = false
            revealed = []
        }
        try? await Task.sleep(for: .milliseconds(Int(checkDelay(data) * 1000)))
        guard !Task.isCancelled else { return }
        headerDone = true
        // The sections already on screen play in page order; the rest wait for the user.
        for section in pageOrder(data) where visible.contains(section) && !revealed.contains(section) {
            revealed.insert(section)
            let pause = section == .bests ? 160 * data.bests.count + 120 : 220
            try? await Task.sleep(for: .milliseconds(pause))
            if Task.isCancelled { return }
        }
    }

    // MARK: - Navigation

    /// Dismiss, switch to History and open this workout.
    private func viewInHistory() {
        guard let id = summary.workoutID else { return }
        router.dismissSheet()
        router.select(.history)
        router.historyPath = NavigationPath()
        router.historyPath.append(Route.workoutDetail(workoutID: id))
    }

    // MARK: - Capture variants ("p2"…"p9")

    private func applyScrollVariant(_ metrics: FinishScrollMetrics) {
        scrollMetrics = metrics
        guard !didApplyVariant, let page = variant.page,
              metrics.viewport > 0, metrics.content > metrics.viewport else { return }
        didApplyVariant = true
        // Page down one viewport at a time, landing each page on a section title (pulled back
        // to the section that starts inside the page, or forward to the next one). Asked again
        // after the sheet has surely landed: a scroll requested mid-presentation can be lost,
        // and the sizes measured mid-presentation (insets, content) are not final — so every
        // pass reads the latest ones.
        for delay in [0.35, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let m = scrollMetrics
                let visibleHeight = m.viewport - m.top - m.bottom
                let maxOffset = max(0, m.content - visibleHeight)
                let step = visibleHeight - 56
                var target: CGFloat = 0
                for _ in 1..<page { target = snapped(target + step, visible: visibleHeight) }
                position.scrollTo(y: min(maxOffset, max(0, target)))
            }
        }
    }

    /// The offset that puts a section title just under the navigation bar — or, when no
    /// section starts near this page (a section taller than the screen), a card's top edge.
    /// A boundary is taken from a little before the plain page break (repeating up to a third
    /// of a screen) to just past it (the previous page's overlap), so no content is skipped.
    private func snapped(_ target: CGFloat, visible: CGFloat) -> CGFloat {
        let sections = sectionTops.filter(\.isSection).map { $0.y - 26 }
        let cards = sectionTops.filter { !$0.isSection }.map { $0.y - 14 }
        func near(_ tops: [CGFloat]) -> CGFloat? { tops.filter { $0 >= target - visible * 0.35 && $0 <= target + 50 }.max() }
        return near(sections) ?? near(cards) ?? target
    }
}

/// The scroll view's size facts (for the capture variants and the compact F03 sheet).
struct FinishScrollMetrics: Equatable {
    var viewport: CGFloat
    var content: CGFloat
    var top: CGFloat
    var bottom: CGFloat
}

/// The T04 sheet presented from inside the receipt.
struct FinishTemplateSheetItem: Identifiable {
    let id: UUID
}

/// "Saved as template “Push Day copy”" in the Save as Template slot: a check in the look's
/// done treatment (A lit, B pearl, C inked) that stamps in once, then the existing line.
struct FinishSavedTemplateLine: View {
    let name: String
    @State private var stamped = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(.footnote, weight: .heavy))
                .foregroundStyle(look.onDone)
                .frame(width: 26, height: 26)
                .background(look.done, in: Circle())
                .scaleEffect(stamped || reduceMotion ? 1 : 1.6)
                .rotationEffect(.degrees(stamped || reduceMotion ? 0 : look.motion.stampRotation))
                .opacity(stamped || reduceMotion ? 1 : 0)
            Text("Saved as template “\(name)”")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .onAppear {
            guard !reduceMotion else { stamped = true; return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55).delay(0.15)) { stamped = true }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// Reports when a section is (40 %) in or out of the scroll view's visible region.
    func revealWhenVisible(_ section: FinishRevealSection,
                           report: @escaping (FinishRevealSection, Bool) -> Void) -> some View {
        onScrollVisibilityChange(threshold: 0.4) { report(section, $0) }
    }
}
