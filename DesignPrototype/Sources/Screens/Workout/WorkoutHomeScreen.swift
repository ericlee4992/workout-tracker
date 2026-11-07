import SwiftUI

// PROTOTYPE — the Workout tab (W01 idle, W02 live, W03 first run, Z04 at AccessibilityL).
// The user's kept skeleton: gear · "Workout" + date · gym picker · the Start pair (or ONE
// Resume capsule while a workout is minimised) · This week · the template grid, with
// "New Template…" and "Ask AI for Templates" as the grid's last row. No long-press menus.
// Scrolled, the large title hands over to an inline "Workout" and content fades out under the
// bar (hard top edge). Capture variants on W01: odd (three templates), long (a long tile name);
// on W02: running (the running template's tile centred, its live dot in view).

struct WorkoutHomeScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleInBar = false

    private var isLive: Bool { store.session != nil }
    private var scrollVariantActive: Bool {
        [.w01, .w02, .w03, .z04].contains(store.currentScreen)
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            // PROPOSAL (2026-11): the next workout leads (one Start), the empty-workout and cardio
            // starts step down to a quiet pair, the other templates follow, and "This week" moves
            // to the end (it is a look back, not the reason to open the app).
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle(look.origin == .soft || look.origin == .blend ? "Train" : "Workout", subtitle: WorkoutDates.homeSubtitle(store.now, look: look.id))
                VStack(spacing: 12) {
                    gymControl
                    if isLive {
                        WorkoutResumeCapsule().transition(swapTransition)
                    } else if let next = upNext {
                        ProposedUpNextCard(template: next)
                    }
                    if !isLive { ProposedQuickStarts() }
                }
                templatesSection
                if look.origin == .blend && BlendOptions.shared.tabs == .food { BlendTrainLibrary() }
                if store.history.isEmpty && store.session == nil {
                    // First run: no scoreboard of zeros, just the week waiting for its first workout.
                    WorkoutFirstWeekCard(days: store.weekSummary.days)
                } else {
                    WeekWidget(summary: store.weekSummary)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82), value: isLive)
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 70 : 46)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .modifier(WorkoutVariantScroll(variant: router.variant, active: scrollVariantActive))
        .onAppear {
            // `-variant running` (W02, Z04): the running template's tile centred, its live dot in view.
            guard scrollVariantActive, router.variant == "running", let id = store.session?.templateID else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo(id, anchor: .center) }
        }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: applyVariant)
        .proposalScreen("workout")
        // Scrolled: the bar takes the solid ground, so nothing shows through under the status
        // bar, the title and the bar buttons.
        .toolbarBackground(look.ground, for: .navigationBar)
        .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Workout")
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .opacity(titleInBar ? 1 : 0)
                    .accessibilityHidden(!titleInBar)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(.settings) } label: {
                    Image(systemName: "gearshape")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    /// `-screen W01 -variant odd`: three templates (the last row is a tile beside New Template…,
    /// Ask AI spanning below). `long`: a template with a long name that wraps in its tile.
    private func applyVariant() {
        guard store.currentScreen == .w01, let variant = router.variant else { return }
        let tokens = Set(variant.split(separator: "-").map(String.init))
        if tokens.contains("odd") { store.deleteTemplate(SampleData.templateID("Pull Day")) }
        if tokens.contains("long"), var t = store.template(SampleData.templateID("Whole Body")) {
            t.name = "Whole Body Strength Circuit"
            store.saveTemplate(t)
        }
    }

    // MARK: Gym

    @ViewBuilder private var gymControl: some View {
        if let gym = store.selectedGym {
            GymPickerButton(name: gym.name, city: gym.city, unit: gym.defaultUnit ?? store.displayUnit) {
                router.present(.gymMenu)
            }
        } else if store.activeGyms.isEmpty {
            // First run: the gym slot is an invitation, not an empty "No gym" card.
            WorkoutAddGymRow { router.present(.editGym(gymID: nil)) }
        } else {
            GymPickerButton(name: "No gym", unit: store.displayUnit) { router.present(.gymMenu) }
        }
    }

    // MARK: Start / Resume

    private var startControl: some View {
        ZStack {
            if isLive {
                WorkoutResumeCapsule()
                    .transition(swapTransition)
            } else {
                StartPair(onLifting: { store.startLifting() },
                          onCardio: { router.present(.cardioPicker) })
                    .transition(swapTransition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82), value: isLive)
    }

    private var swapTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    // MARK: Templates

    /// The template due next: the one done longest ago (never-run templates first).
    private var upNext: Template? {
        store.sortedTemplates.min { a, b in
            (store.templateStats(a.id).lastRun ?? .distantPast) < (store.templateStats(b.id).lastRun ?? .distantPast)
        }
    }

    /// Every template except the one leading the screen.
    private var otherTemplates: [Template] {
        store.sortedTemplates.filter { $0.id != (isLive ? nil : upNext?.id) }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(isLive || upNext == nil ? "Templates" : "Other templates", level: .page)
            if !store.templates.isEmpty {
                VStack(spacing: look.space.grid) {
                    if typeSize.isAccessibilitySize {
                        ForEach(otherTemplates) { tile($0) }
                    } else {
                        proposedGrid
                    }
                    ProposedMakeRow(title: "New Template…", symbol: "plus") { router.present(.templateEditor(templateID: nil)) }
                    ProposedMakeRow(title: "Ask AI for Templates", symbol: "sparkles") { router.aiRoutinePresented = true }
                }
            } else if store.templates.isEmpty {
                // First run: an invitation that shows what a template becomes (its family maps).
                VStack(spacing: look.space.grid) {
                    WorkoutTemplateInvite { router.present(.templateEditor(templateID: nil)) }
                    WorkoutMakeRow(title: "Ask AI for Templates", symbol: "sparkles") { router.aiRoutinePresented = true }
                }
            } else if typeSize.isAccessibilitySize {
                // AX sizes: one column; the two "make one" tiles become equal full-width rows
                // (disc leading, label trailing) so they don't turn into two tall empty slots.
                VStack(spacing: look.space.grid) {
                    ForEach(store.sortedTemplates) { tile($0) }
                    WorkoutMakeRow(title: "New Template…", symbol: "plus") { router.present(.templateEditor(templateID: nil)) }
                    WorkoutMakeRow(title: "Ask AI for Templates", symbol: "sparkles") { router.aiRoutinePresented = true }
                }
            } else {
                grid
            }
        }
    }

    /// Two columns of the other templates; an odd last tile sits alone at half width.
    private var proposedGrid: some View {
        let templates = otherTemplates
        let rows = stride(from: 0, to: templates.count, by: 2).map { Array(templates[$0..<min($0 + 2, templates.count)]) }
        return Grid(horizontalSpacing: look.space.grid, verticalSpacing: look.space.grid) {
            ForEach(rows, id: \.first!.id) { row in
                GridRow(alignment: .top) {
                    ForEach(row) { tile($0) }
                    if row.count == 1 { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                }
            }
        }
    }

    private var grid: some View {
        let templates = store.sortedTemplates
        let odd = templates.count % 2 == 1
        let pairs = stride(from: 0, to: templates.count - (odd ? 1 : 0), by: 2).map { Array(templates[$0..<$0 + 2]) }
        return Grid(horizontalSpacing: look.space.grid, verticalSpacing: look.space.grid) {
            ForEach(pairs, id: \.first!.id) { pair in
                GridRow(alignment: .top) {
                    ForEach(pair) { tile($0) }
                }
            }
            if odd, let last = templates.last {
                // An odd count: New Template… fills the half-row; Ask AI spans below (no orphan slot).
                GridRow(alignment: .top) {
                    tile(last)
                    newTemplateTile
                }
                GridRow { askAITile.gridCellColumns(2) }
            } else {
                GridRow(alignment: .top) {
                    newTemplateTile
                    askAITile
                }
            }
        }
    }

    private func tile(_ template: Template) -> some View {
        let names = template.items.compactMap { store.exercise($0.exerciseID)?.name } + template.cardio.map(\.activity.name)
        let running = store.session?.templateID == template.id
        return TemplateTile(name: template.name, families: store.families(ofTemplate: template.id), exercises: names,
                            lastDone: store.templateStats(template.id).lastRun, now: store.now) {
            router.push(.templateDetail(templateID: template.id))
        }
        // W02: the template that is running carries the live pulse in a free corner: beside the
        // map strip in A and B; in C on the footer line, clear of the family band's maps.
        .overlay(alignment: look.id.isPaperClub ? .bottomTrailing : .topTrailing) {
            if running {
                ZStack {
                    Circle().fill(look.surface).frame(width: 24, height: 24)
                    // C: a small outlined sticker.
                    if look.id.isPaperClub { Circle().strokeBorder(look.outline, lineWidth: 1.5).frame(width: 24, height: 24) }
                    WorkoutLivePulse(color: look.live, size: 9)
                }
                .padding(look.id.isPaperClub ? 12 : 10)
                .allowsHitTesting(false)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityValue(running ? "In progress" : "")
        .id(template.id)
    }

    private var newTemplateTile: some View {
        MakeTile(title: "New Template…", symbol: "plus") { router.present(.templateEditor(templateID: nil)) }
    }

    private var askAITile: some View {
        MakeTile(title: "Ask AI for Templates", symbol: "sparkles") { router.aiRoutinePresented = true }
    }
}

// MARK: - Resume capsule (W02)

/// While a workout is minimised the Start pair becomes ONE capsule (the user's choice): the
/// activity disc with a live pulse, "Resume workout", what is running, and the running clock.
struct WorkoutResumeCapsule: View {
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var discA: CGFloat = 44
    @ScaledMetric(relativeTo: .headline) private var discB: CGFloat = 40
    @ScaledMetric(relativeTo: .headline) private var discC: CGFloat = 46
    @ScaledMetric(relativeTo: .headline) private var dot: CGFloat = 9
    @State private var taps = 0

    private var disc: CGFloat {
        switch look.id {
        case .floodlight: discA
        case .anatomy: discB
        case .paper, .carbon: discC
        }
    }

    private var symbol: String {
        if let s = store.session, s.focus == .cardio, let cardio = s.unfinishedCardio { return cardio.activity.symbol }
        return "figure.strengthtraining.traditional"
    }

    private var subtitle: String {
        guard let s = store.session else { return "" }
        if s.focus == .cardio, let cardio = s.unfinishedCardio { return cardio.activity.name }
        if s.totalSetCount > 0 { return "\(store.sessionTitle) · \(s.completedSetCount)/\(s.totalSetCount) sets" }
        return store.sessionTitle
    }

    var body: some View {
        let elapsed = store.sessionElapsed
        Button {
            taps += 1
            store.resume()
        } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    // AX: the disc stays in the capsule's rounded end; the lines stack beside it,
                    // clear of the curve.
                    HStack(alignment: .center, spacing: 12) {
                        discView
                        VStack(alignment: .leading, spacing: 4) {
                            title
                            detail
                            clock(elapsed)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                } else {
                    HStack(spacing: look.id == .anatomy ? 12 : 10) {
                        discView
                        VStack(alignment: .leading, spacing: 1) {
                            title
                            detail
                        }
                        Spacer(minLength: 8)
                        clock(elapsed)
                    }
                }
            }
            .padding(.leading, look.id == .floodlight ? 10 : 8)
            .padding(.trailing, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(look.onAction)
        }
        .buttonStyle(StartCapsuleStyle())
        .sensoryFeedback(.impact(weight: .heavy), trigger: taps)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Resume workout")
        .accessibilityValue("\(subtitle), \(Format.spokenElapsed(elapsed))")
        .accessibilityAddTraits(.isButton)
    }

    private var discView: some View {
        IconDisc(symbol: symbol, size: disc, context: .onAction)
    }

    private var title: some View {
        Text("Resume workout")
            .font(look.font.button)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var detail: some View {
        Text(subtitle)
            .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
    }

    /// The running clock led by a recording-style live pulse.
    private func clock(_ elapsed: Int) -> some View {
        HStack(spacing: 8) {
            WorkoutLivePulse(color: look.onAction, size: dot)
            Text(Format.elapsed(elapsed))
                .font(look.font.statNumber)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy, value: elapsed)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - First-run template invitation (W03)

/// "New Template…" as a dashed make-one card carrying the five family maps, unlit: the
/// picture a template tile will light up. One action.
struct WorkoutTemplateInvite: View {
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 40

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 0) {
                    ForEach(MuscleFamily.allCases) { family in
                        FamilySticker(family: family, lit: false, size: look.id.isPaperClub ? 46 : 50)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
                HStack(spacing: 12) {
                    IconDisc(symbol: "plus", size: disc, context: .make)
                        .background { if look.id == .floodlight { Circle().fill(look.surfaceRaised) } }
                    Text("New Template…")
                        .font(look.font.button)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: look.radius.tile,
                           lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: look.id.isPaperClub ? [6, 4] : [5, 4])
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("New Template…")
    }
}
