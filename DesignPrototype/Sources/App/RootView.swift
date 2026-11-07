import SwiftUI

// PROTOTYPE — tab shell, navigation stacks, covers and the single sheet slot.
// Sheet rule: the top-most layer presents `router.sheet` (live cover > Ask AI cover > tabs),
// except `.finish`, which always shows over the tabs once the live cover has gone.

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LookModel.self) private var lookModel
    @Environment(\.colorScheme) private var systemScheme

    private var liveCoverUp: Bool { store.session != nil && store.isSessionPresented }

    @State private var softTab: SoftTab = {
        switch UserDefaults.standard.string(forKey: "softTab") {
        case "train": .train
        case "progress": .progress
        case "profile": .profile
        default: .today
        }
    }()
    @State private var softAddShown = UserDefaults.standard.bool(forKey: "softAdd")
    @State private var softCover: SoftCover? = UserDefaults.standard.string(forKey: "softCover").flatMap(SoftCover.init(rawValue:))

    var body: some View {
        @Bindable var router = router
        let look = lookModel.look(system: systemScheme)
        tabs
        .tint(look.selection)
        .overlay {
            if softAddShown {
                SoftAddMenu(shown: $softAddShown) { choice in
                    switch choice {
                    case "train": selectSoft(.train)
                    case "logFood": softCover = .logFood
                    case "scanFood": softCover = .scanFood
                    default: softCover = .logWeight
                    }
                }
                .lookLayer(lookModel)
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: Binding(get: { softCover == .logWeight ? nil : softCover }, set: { softCover = $0 })) { cover in
            Group {
                if cover == .scanFood { SoftScanFoodScreen() } else { SoftLogFoodScreen() }
            }
            .lookLayer(lookModel)
        }
        .sheet(isPresented: Binding(get: { softCover == .logWeight }, set: { if !$0 { softCover = nil } })) {
            SoftLogWeightSheet().presentationDetents([.medium]).lookLayer(lookModel)
        }
        .templateDriftPresenter()
        .sheet(item: rootSheet) { route in
            SheetContent(route: route).lookLayer(lookModel)
        }
        .fullScreenCover(isPresented: liveCoverBinding, onDismiss: presentFinishIfNeeded) {
            LiveWorkoutScreen()
                .sheet(item: coverSheet) { route in SheetContent(route: route).lookLayer(lookModel) }
                .lookLayer(lookModel)
                .dynamicTypeOverride(router.dynamicTypeOverride)
        }
        .fullScreenCover(isPresented: $router.aiRoutinePresented) {
            AIRoutineFlowScreen()
                .sheet(item: coverSheet) { route in SheetContent(route: route).lookLayer(lookModel) }
                .lookLayer(lookModel)
                .dynamicTypeOverride(router.dynamicTypeOverride)
        }
        .lookLayer(lookModel)
        .dynamicTypeOverride(router.dynamicTypeOverride)
        .animation(.easeInOut(duration: 0.25), value: lookModel.id)
        .animation(.easeInOut(duration: 0.25), value: lookModel.appearance)
    }

    // MARK: Tabs

    @ViewBuilder private var tabs: some View {
        if lookModel.id == .soft { softTabs } else { classicTabs }
    }

    /// EXPLORATION (2026-11-07) — Soft: Today · Train · Progress · Profile in a floating capsule,
    /// and the + as its own black circle beside it (opens the add menu). Each tab keeps its stack.
    private var softTabs: some View {
        @Bindable var router = router
        return ZStack {
            softPage(.today) { NavigationStack(path: $router.exercisesPath) { SoftTodayScreen().routeDestinations() } }
            softPage(.train) { NavigationStack(path: $router.workoutPath) { WorkoutHomeScreen().routeDestinations() } }
            softPage(.progress) { NavigationStack(path: $router.historyPath) { SoftProgressScreen().routeDestinations() } }
            softPage(.profile) { NavigationStack(path: $router.gymsPath) { SoftProfileScreen().routeDestinations() } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SoftTabBar(selection: softTab, select: selectSoft) {
                withAnimation(.easeOut(duration: 0.2)) { softAddShown = true }
            }
        }
        .onAppear { selectSoft(softTab) }
    }

    private func softPage<C: View>(_ tab: SoftTab, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .opacity(softTab == tab ? 1 : 0)
            .allowsHitTesting(softTab == tab)
            .accessibilityHidden(softTab != tab)
    }

    private func selectSoft(_ tab: SoftTab) {
        softTab = tab
        switch tab {
        case .today: router.tab = .exercises
        case .train: router.tab = .workout
        case .progress: router.tab = .history
        case .profile, .add: router.tab = .gyms
        }
    }

    private var classicTabs: some View {
        @Bindable var router = router
        return TabView(selection: $router.tab) {
            Tab(AppTab.workout.label, systemImage: AppTab.workout.symbol, value: AppTab.workout) {
                NavigationStack(path: $router.workoutPath) {
                    WorkoutHomeScreen().routeDestinations()
                }
            }
            Tab(AppTab.history.label, systemImage: AppTab.history.symbol, value: AppTab.history) {
                NavigationStack(path: $router.historyPath) {
                    HistoryScreen().routeDestinations()
                }
            }
            Tab(AppTab.gyms.label, systemImage: AppTab.gyms.symbol, value: AppTab.gyms) {
                NavigationStack(path: $router.gymsPath) {
                    GymsScreen().routeDestinations()
                }
            }
            Tab(AppTab.exercises.label, systemImage: AppTab.exercises.symbol, value: AppTab.exercises) {
                NavigationStack(path: $router.exercisesPath) {
                    ExercisesScreen().routeDestinations()
                }
            }
        }
    }

    private var liveCoverBinding: Binding<Bool> {
        Binding(get: { liveCoverUp },
                set: { up in if !up { store.minimise() } })
    }

    /// Sheets over the tabs: only while no cover is up, never before the finish handoff.
    private var rootSheet: Binding<SheetRoute?> {
        Binding(get: {
            guard !liveCoverUp, !router.aiRoutinePresented, !router.showFinishAfterCover else { return nil }
            return router.sheet
        }, set: { router.sheet = $0 })
    }

    /// Sheets over a cover (live workout or Ask AI). The finish receipt never shows here.
    private var coverSheet: Binding<SheetRoute?> {
        Binding(get: { router.sheet == .finish ? nil : router.sheet },
                set: { router.sheet = $0 })
    }

    private func presentFinishIfNeeded() {
        guard router.showFinishAfterCover else { return }
        router.showFinishAfterCover = false
        if store.finishSummary != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { router.sheet = .finish }
        }
    }
}

extension View {
    /// Pushed destinations for every tab stack.
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { RouteContent(route: $0) }
    }

    @ViewBuilder
    func dynamicTypeOverride(_ size: DynamicTypeSize?) -> some View {
        if let size { dynamicTypeSize(size) } else { self }
    }
}

/// EXPLORATION (2026-11-07): the Soft look's tabs (+ opens the add menu, never a page).
enum SoftTab: Hashable { case today, train, progress, profile, add }
