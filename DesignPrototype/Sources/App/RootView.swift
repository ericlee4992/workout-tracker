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

    var body: some View {
        @Bindable var router = router
        let look = lookModel.look(system: systemScheme)

        TabView(selection: $router.tab) {
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
        .tint(look.selection)
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
