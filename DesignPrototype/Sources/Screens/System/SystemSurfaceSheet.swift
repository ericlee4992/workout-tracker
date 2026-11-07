import SwiftUI

// PROTOTYPE — the System area's one public view: a full-height sheet that stages a surface
// outside the app (Z01 Live Activity + Dynamic Island, Z02 app icon, Z03 rest-complete
// notifications). The sheet's own chrome is in the look; the stages are true to iOS at 1:1.
//
// Variants (`-variant`, tokens combine, e.g. "cardio-paused-p2"):
//   Z01  ready (rest ran out: next set + notification) · best (the moment of a new best: rest at
//        2:00) · superset (next set is superset A) · warmup (next set is a warmup on the next
//        exercise) · nohr (no heart-rate reading) · nogym (no gym selected; pair with ready) ·
//        cardio · cardio-paused · cardio-target (planned 20 min reached) · p2 (Dynamic Island) ·
//        p3 (the expanded island)
//   Z02  dark · clear · tinted · light (Default on the light wallpaper) · p2 / p3 (home screen)
//   Z03  timer · recovered (default: the store's last outcome) · cap · noreading (one viewport)
//
// Every variant is drawn from the shared store or from a throwaway store of its own; opening a
// preview never changes the shared workout.

struct SystemSurfaceSheet: View {
    let screen: ScreenID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Z01: 0 Lifting, 1 Cardio.
    @State private var activityMode = 0
    /// Z02.
    @State private var appearance: SystemIconAppearance = .standard
    @State private var lightWallpaper = false
    /// Z03: 0 Timer, 1 Recovered, 2 Cap, 3 No reading.
    @State private var outcomeIndex = 1
    /// Z01's cardio sample runs in its own store (C02), so Pause / Resume really work.
    @State private var cardioStore: Store?
    /// Z01 cardio-target: the planned target reached (drawn from C05's run), with its own pause.
    @State private var cardioTargetModel: SystemActivityModel?
    /// Z01 lifting states the shared workout is not in (best / superset / warmup), each in a
    /// throwaway store, so tapping +15s / Skip there works without touching the shared workout.
    @State private var liftingSample: Store?
    @State private var liftingSampleScreen: ScreenID = .l01
    @State private var showsReady = false
    @State private var hidesHeart = false
    @State private var hidesGym = false
    /// Z01: rest ran out while the sheet was open, so its notification landed.
    @State private var expiryBanner: SystemRestResult?
    @State private var didApplyVariant = false
    /// The visible height under the header, and whether the page has left the top.
    @State private var metrics = SystemScrollMetrics(viewport: 700, isScrolled: false)
    /// The header's position on screen: it moves while the sheet is still presenting.
    @State private var headerTop: CGFloat = 0

    /// Used only if no workout is running (the sheet opened after the workout ended).
    private static let liftingFallback = Store.liveActivitySample(.z01)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                page
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .onScrollGeometryChange(for: SystemScrollMetrics.self) { geometry in
                SystemScrollMetrics(
                    // containerSize is already the area between the header and the bottom safe area.
                    viewport: max(300, geometry.containerSize.height),
                    isScrolled: geometry.contentOffset.y + geometry.contentInsets.top > 1)
            } action: { _, new in
                metrics = new
            }
            .onAppear { applyVariant(proxy) }
        }
        .lookSheetGround()
        .presentationDetents([.large])
        .presentationBackground(look.groundSheet)
        .presentationCornerRadius(look.radius.sheet)
        .modifier(SystemTypeSizeOverride(size: router.dynamicTypeOverride))
        .sensoryFeedback(.success, trigger: store.restExpiryCount)
        .onChange(of: activityMode) { _, mode in
            if mode == 1 { makeCardioStore() }
        }
        .onChange(of: store.restExpiryCount) { _, _ in
            guard screen == .z01, liftingSample == nil else { return }
            expiryBanner = bannerResult(store.lastRestOutcome)
        }
        .onChange(of: store.rest?.startedAt) { _, started in
            if started != nil { expiryBanner = nil; showsReady = false }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The title sits beside Done while it fits on one line; at large sizes Done keeps the
            // top row and the title takes the full width below it (words never break).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    title.lineLimit(1).fixedSize()
                    Spacer(minLength: 8)
                    done
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Spacer(minLength: 0); done }
                    title.fixedSize(horizontal: false, vertical: true)
                }
            }
            switch screen {
            case .z01:
                SegmentedPills(["Lifting", "Cardio"], selection: $activityMode)
            case .z03:
                SystemOutcomePicker(selection: $outcomeIndex)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .background(look.groundSheet)
        // Content scrolling under the pinned header fades out instead of meeting a hard edge.
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [look.groundSheet, look.groundSheet.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
                .offset(y: 24)
                .opacity(metrics.isScrolled ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: metrics.isScrolled)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { headerTop = $0 }
    }

    private var title: some View {
        Text(screen.title)
            .font(look.font.title)
            .foregroundStyle(look.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var done: some View {
        GlassCapsuleButton("Done") { router.dismissSheet() }
    }

    // MARK: Pages

    @ViewBuilder private var page: some View {
        switch screen {
        case .z02:
            SystemAppIconPage(appearance: $appearance, lightWallpaper: $lightWallpaper, viewport: metrics.viewport,
                              onLaunch: launchApp)
        case .z03:
            let result = restResults[min(max(outcomeIndex, 0), 3)]
            SystemNotificationPage(result: result, model: notificationModel(result), actions: actions(for: store, open: .l01),
                                   now: store.now, viewport: metrics.viewport)
        default:
            if activityMode == 1, let model = currentCardioModel {
                SystemLiveActivityPage(model: model, actions: currentCardioActions, now: cardioStore?.now ?? store.now,
                                       viewport: metrics.viewport)
            } else {
                let source = liftingSample ?? store
                SystemLiveActivityPage(model: liftingModel(source), actions: actions(for: source, open: liftingSampleScreen),
                                       now: source.now, banner: expiryBanner, viewport: metrics.viewport)
            }
        }
    }

    // MARK: Models

    private func liftingModel(_ source: Store) -> SystemActivityModel {
        let snapshot = source.liveActivity ?? Self.liftingFallback
            ?? LiveActivitySnapshot(title: "Workout", gymName: nil, startedAt: source.now, elapsedSeconds: 0, isCardio: false,
                                    exerciseName: nil, completedSets: 0, totalSets: 0, bpm: nil, zone: nil, restEndsAt: nil,
                                    restRemaining: nil, restTotal: nil, activity: nil, cardioSeconds: nil, distanceMeters: nil,
                                    distanceUnit: source.distanceUnit, paceSecondsPerUnit: nil, isCardioPaused: false)
        let next = source.nextSet
        var model = SystemActivityModel(
            snapshot: snapshot, nextLine: source.systemNextLine(), nextMarker: source.systemNextMarker,
            nextValue: next?.value, nextLoadType: next?.loadType ?? .weighted, nextPrevious: source.systemNextPrevious(),
            nextExerciseName: next?.isNewExercise == true ? next?.exerciseName : nil,
            nextSupersetLetter: source.systemNextSupersetLetter,
            restFollowsNewBest: source.systemRestFollowsNewBest,
            bestMoment: source.systemBestMoment)
        if showsReady, let remaining = model.snapshot.restRemaining {
            // The same workout the moment its rest ran out (drawn, not skipped: the shared rest
            // keeps running underneath and reaches this picture by itself).
            model.snapshot.elapsedSeconds += remaining
            model.snapshot.restEndsAt = nil
            model.snapshot.restRemaining = nil
            model.snapshot.restTotal = nil
            model.bestMoment = nil
        }
        if hidesHeart {
            model.snapshot.bpm = nil
            model.snapshot.zone = nil
        }
        if hidesGym { model.snapshot.gymName = nil }
        return model
    }

    /// Z03: the activity agrees with the notification ("Heart rate down to 108 bpm" shows 108).
    private func notificationModel(_ result: SystemRestResult) -> SystemActivityModel {
        var model = liftingModel(store)
        model.restResult = result
        model.restFollowsNewBest = false
        model.bestMoment = nil
        switch result {
        case .recovered(let bpm, _), .cap(let bpm, _, _):
            model.snapshot.bpm = bpm
            model.snapshot.zone = store.zone(for: bpm)
        case .noReading:
            model.snapshot.bpm = nil
            model.snapshot.zone = nil
        case .timer:
            break
        }
        return model
    }

    private var restResults: [SystemRestResult] {
        let rule = store.systemRestRule
        var recovered = 108
        if case .recovered(let bpm) = store.lastRestOutcome { recovered = bpm }
        let capped = max(rule.target + 8, store.currentBPM ?? 124)
        return [.timer(seconds: rule.timer), .recovered(bpm: recovered, target: rule.target),
                .cap(bpm: capped, target: rule.target, capSeconds: rule.cap), .noReading(seconds: rule.timer)]
    }

    private func bannerResult(_ outcome: RestOutcome?) -> SystemRestResult? {
        let rule = store.systemRestRule
        switch outcome {
        case .timerDone: return .timer(seconds: rule.timer)
        case .recovered(let bpm): return .recovered(bpm: bpm, target: rule.target)
        case .cap: return .cap(bpm: store.currentBPM ?? rule.target, target: rule.target, capSeconds: rule.cap)
        case .skipped, .none: return nil
        }
    }

    private var currentCardioModel: SystemActivityModel? {
        if let cardioTargetModel { return cardioTargetModel }
        guard let cardioStore, let snapshot = cardioStore.liveActivity, snapshot.isCardio else { return nil }
        return SystemActivityModel(snapshot: snapshot, cardioTarget: cardioStore.systemCardioTarget)
    }

    // MARK: Actions

    private func actions(for source: Store, open screen: ScreenID) -> SystemActivityActions {
        SystemActivityActions(
            add15: { source.addRest(seconds: 15) },
            skip: {
                source.skipRest()
                showsReady = false
            },
            pauseResume: {},
            open: { openLifting(source, screen: screen) })
    }

    private var currentCardioActions: SystemActivityActions {
        if cardioTargetModel != nil {
            return SystemActivityActions(
                pauseResume: { cardioTargetModel?.snapshot.isCardioPaused.toggle() },
                open: { Launch.open(.c05, store: store, router: router) })
        }
        guard let cardio = cardioStore else { return SystemActivityActions() }
        return SystemActivityActions(
            pauseResume: {
                guard let segment = cardio.session?.unfinishedCardio else { return }
                if segment.isPaused { cardio.resumeCardio() } else { cardio.pauseCardio() }
            },
            // The app opens on the same run, paused or not, as the activity showed it.
            open: {
                let paused = cardio.session?.unfinishedCardio?.isPaused == true
                Launch.open(paused ? .c03 : .c02, store: store, router: router)
            })
    }

    /// Tapping a Live Activity or the notification opens the app on the live workout.
    private func openLifting(_ source: Store, screen: ScreenID) {
        if source !== store {
            Launch.open(screen, store: store, router: router)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { store.resume() }
            return
        }
        guard store.session != nil else { router.dismissSheet(); return }
        router.dismissSheet()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.resume() }
    }

    /// Tapping the home-screen icon "launches" the app: back to the Workout tab.
    private func launchApp() {
        router.dismissSheet()
        router.select(.workout)
    }

    private func makeCardioStore() {
        guard cardioStore == nil else { return }
        cardioStore = Store(screen: .c02, freezeClock: store.freezeClock)
    }

    /// C05's run at the moment it reached its 20-minute plan, still recording.
    private func makeCardioTargetModel() -> SystemActivityModel? {
        let sample = Store(screen: .c05, freezeClock: true)
        guard let session = sample.session, let segment = session.cardio.first,
              let plan = session.plannedCardio.first else { return nil }
        let end = segment.endedAt ?? sample.now
        let snapshot = LiveActivitySnapshot(
            title: sample.sessionTitle, gymName: session.gymID.flatMap { sample.gym($0) }?.name,
            startedAt: session.startedAt, elapsedSeconds: Int(end.timeIntervalSince(session.startedAt)), isCardio: true,
            exerciseName: nil, completedSets: session.completedSetCount, totalSets: session.totalSetCount,
            bpm: sample.currentBPM ?? segment.averageHeartRate, zone: (sample.currentBPM ?? segment.averageHeartRate).flatMap { sample.zone(for: $0) },
            restEndsAt: nil, restRemaining: nil, restTotal: nil, activity: segment.activity,
            cardioSeconds: segment.activeSeconds(at: end), distanceMeters: segment.distanceMeters, distanceUnit: segment.unit,
            paceSecondsPerUnit: segment.paceSecondsPerUnit(at: end), isCardioPaused: false)
        return SystemActivityModel(snapshot: snapshot, cardioTarget: SystemCardioTarget(minutes: plan.minutes, progress: 1))
    }

    /// The warmup variant: the shared workout's next step after set 3 — Incline Chest Press opens
    /// with a warmup set (45 lb × 12).
    private func makeWarmupSample() -> Store {
        let sample = Store(screen: .z01, freezeClock: store.freezeClock)
        if let session = sample.session,
           let chest = session.entries.first(where: { sample.exercise($0.exerciseID)?.name == "Seated Chest Press" }),
           let open = chest.sets.first(where: { !$0.isCompleted }) {
            sample.completeSet(entryID: chest.id, setID: open.id)
            sample.skipRest()
        }
        if let session = sample.session,
           let incline = session.entries.first(where: { sample.exercise($0.exerciseID)?.name == "Incline Chest Press" }),
           let first = incline.sets.first {
            sample.setType(.warmup, entryID: incline.id, setID: first.id)
            sample.updateWeight(45, entryID: incline.id, setID: first.id)
            sample.updateReps(12, entryID: incline.id, setID: first.id)
        }
        return sample
    }

    // MARK: Variants

    private func applyVariant(_ proxy: ScrollViewProxy) {
        guard !didApplyVariant else { return }
        didApplyVariant = true
        let variant = SystemVariant(router.variant)
        switch screen {
        case .z01:
            if variant.has("cardio") {
                if variant.has("target") {
                    cardioTargetModel = makeCardioTargetModel()
                } else {
                    makeCardioStore()
                    if variant.has("paused") { cardioStore?.pauseCardio() }
                }
                activityMode = 1
            } else {
                if variant.has("best") {
                    liftingSample = Store(screen: .l03, freezeClock: store.freezeClock)
                    liftingSampleScreen = .l03
                } else if variant.has("superset") {
                    liftingSample = Store(screen: .l02, freezeClock: store.freezeClock)
                    liftingSampleScreen = .l02
                } else if variant.has("warmup") {
                    liftingSample = makeWarmupSample()
                    liftingSampleScreen = .l01
                }
                if variant.has("ready") {
                    showsReady = true
                    expiryBanner = .timer(seconds: store.systemRestRule.timer)
                }
                hidesHeart = variant.has("nohr")
                hidesGym = variant.has("nogym")
            }
        case .z02:
            if let match = SystemIconAppearance.allCases.first(where: { variant.has($0.rawValue) || variant.has($0.label.lowercased()) }) {
                appearance = match
            }
            lightWallpaper = variant.has("light")
        case .z03:
            if variant.has("timer") {
                outcomeIndex = 0
            } else if variant.has("cap") {
                outcomeIndex = 2
            } else if variant.has("noreading") {
                outcomeIndex = 3
            } else if variant.has("recovered") {
                outcomeIndex = 1
            } else {
                switch store.lastRestOutcome {
                case .timerDone: outcomeIndex = 0
                case .cap: outcomeIndex = 2
                default: outcomeIndex = 1
                }
            }
        default:
            break
        }
        if let page = variant.page, screen != .z03 {
            scroll(proxy, to: page)
        }
    }

    /// Scrolls to a page once the sheet has settled: it re-anchors every 0.1 s until the header
    /// has held still for half a second (a fixed delay can fire mid-presentation).
    private func scroll(_ proxy: ScrollViewProxy, to page: Int) {
        let anchor: SystemScrollAnchor = (page >= 3 && screen == .z01) ? .page3 : .page2
        Task { @MainActor in
            var last = CGFloat.nan
            var still = 0
            for _ in 0..<50 {
                try? await Task.sleep(for: .milliseconds(100))
                proxy.scrollTo(anchor, anchor: .top)
                still = abs(headerTop - last) < 0.5 ? still + 1 : 0
                last = headerTop
                if still >= 5 { break }
            }
        }
    }
}

/// Z03's four outcomes: one segmented row; at accessibility sizes a 2 × 2 grid of chips, so no
/// label is squeezed or cut. (Its own view: the sheet applies the type size below its root.)
private struct SystemOutcomePicker: View {
    @Binding var selection: Int
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let labels = ["Timer", "Recovered", "Cap", "No reading"]

    var body: some View {
        if typeSize.isAccessibilitySize {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow { chip(0); chip(1) }
                GridRow { chip(2); chip(3) }
            }
        } else {
            SegmentedPills(Self.labels, selection: $selection)
        }
    }

    private func chip(_ index: Int) -> some View {
        Chip(Self.labels[index], isSelected: selection == index) {
            if reduceMotion { selection = index } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = index }
            }
        }
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }
}
