import SwiftUI

// PROTOTYPE — the whole redesigned app with sample data and a floating look switcher.
// Launch arguments (also used by scripts/capture.sh):
//   -look final|floodlight|anatomy|paper|carbon   -screen <ScreenID>   -variant <name>
//   -appearance system|light|dark (the final look's Appearance setting; overrides the saved one)
//   -freezeClock YES   -hideSwitcher YES   -axl YES   -gallery YES

@main
struct PrototypeApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var lookModel: LookModel
    private let hideSwitcher: Bool
    private let showGallery: Bool

    init() {
        let defaults = UserDefaults.standard
        let screen = defaults.string(forKey: "screen").flatMap(ScreenID.init(argument:))
        let store = Store(screen: screen, freezeClock: defaults.bool(forKey: "freezeClock"))
        let router = Router()
        if let screen {
            router.apply(screen, store: store)
            Launch.applyVariant(defaults.string(forKey: "variant"), screen: screen, store: store, router: router)
        }
        if defaults.bool(forKey: "axl") { router.dynamicTypeOverride = .accessibility1 }
        _store = State(initialValue: store)
        _router = State(initialValue: router)
        _lookModel = State(initialValue: LookModel(
            id: LookID(argument: defaults.string(forKey: "look") ?? "") ?? .final,
            appearance: defaults.string(forKey: "appearance").flatMap(Appearance.init(argument:))))
        hideSwitcher = defaults.bool(forKey: "hideSwitcher")
        showGallery = defaults.bool(forKey: "gallery") || defaults.object(forKey: "galleryPage") != nil
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showGallery {
                    ComponentGallery(model: lookModel, page: UserDefaults.standard.integer(forKey: "galleryPage"))
                } else {
                    RootView()
                }
            }
            .environment(store)
            .environment(router)
            .environment(lookModel)
            .onAppear {
                if !hideSwitcher && !showGallery {
                    SwitcherOverlay.install(store: store, router: router, lookModel: lookModel)
                }
            }
        }
    }
}

/// Opening screens and their variants (shared by launch arguments and ScreenIndex).
@MainActor
enum Launch {
    /// Store-level capture variants. View-level ones stay in `router.variant` for the screen.
    static func applyVariant(_ variant: String?, screen: ScreenID, store: Store, router: Router) {
        router.variant = variant
        guard let variant else { return }
        switch (screen, variant) {
        case (.l04, "degraded"): store.setSensor(.none)
        case (_, "stale"): store.setSensor(.stale)
        case (_, "noSensor"): store.setSensor(.none)
        case (.c04, "gpsLost"): store.setGPSUnavailable(true)
        case (.s01, "failure"), (.s03, "failure"): store.scanSetSimulateFailure(true)
        case (.x03, "failure"): store.exportSetSimulateFailure(true)
        case (.g07, "empty"):
            let gangnam = SampleData.gymID("Gangnam Fitness")
            router.gymsPath = NavigationPath()
            router.gymsPath.append(Route.gymDetail(gymID: gangnam))
            router.gymsPath.append(Route.deletedMachines(gymID: gangnam))
        default: break
        }
    }

    /// Reset the sample data to a screen and navigate there (used by ScreenIndex).
    static func open(_ screen: ScreenID, variant: String? = nil, store: Store, router: Router) {
        router.sheet = nil
        router.aiRoutinePresented = false
        store.minimise()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            store.reset(to: screen)
            router.apply(screen, store: store)
            applyVariant(variant, screen: screen, store: store, router: router)
        }
    }
}
