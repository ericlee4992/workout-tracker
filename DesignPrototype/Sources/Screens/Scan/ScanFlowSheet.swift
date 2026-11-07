import SwiftUI

// S01–S06 — Scan Machine: one sheet driven by `store.scan.step`
// (no key → camera → consent → identifying → result → confirmed; error → retake).
// Steps change by a short hand-over: the outgoing step (with its pinned buttons) is gone in
// 0.1 s, then the incoming one fades in, so two steps' chrome never overlaps. The captured photo
// travels between steps (matched geometry), so the answer is always shown beside the picture it
// came from.
//
// View-level variants (tokens joined by "-", e.g. "generic-p2"):
//   p2 / p3     scroll long steps to the 2nd / 3rd viewport
//   rm          the Reduce Motion stills (without changing the simulator's settings)
//   S01         flash · nocamera · nokey
//   S03         failure (under a frozen clock the error shows at once)
//   S04         confirmed · generic (the user chose "Use generic identity") · duplicate (the
//               model is already at Iron Temple) · noname (the name emptied) · editing (name
//               focused, keyboard up)
//   S05         chosen (first candidate picked) · none ("None of these")
//   S06         newModel (re-runs identification as a new model, ≈2.5 s) · exercises (Change
//               exercises) plus exercises-query / exercises-none / exercises-full
// State variants are applied without animation, so captures never catch a transition.

struct ScanFlowSheet: View {
    let gymID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @Namespace private var photoSpace
    @State private var path: [ScanPage] = []
    @State private var appliedVariant = false
    @State private var cameraOff = false

    /// What the sheet shows. Under a frozen clock the S03 failure variant cannot finish its
    /// simulated call, so it is shown as the error it would end in. Without an API key nothing
    /// can be identified, so the camera waits behind the key step.
    private var step: ScanSheetStep {
        let scan = store.scan
        if scan.step == .identifying, scan.simulateFailure, store.freezeClock, router.scanVariant("failure") {
            return .flow(.error)
        }
        if scan.step == .camera && !store.settings.aiKeySaved { return .noKey }
        return .flow(scan.step)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                switch step {
                case .noKey:
                    ScanNoKeyStep(onCancel: cancel, onSettings: openAISettings, onManual: chooseManually)
                        .transition(stepTransition)
                case .flow(.camera):
                    ScanCameraStep(gymName: gymName, machineCount: machineCount, photoSpace: photoSpace,
                                   cameraOff: $cameraOff, onCancel: cancel)
                        .transition(stepTransition)
                case .flow(.consent):
                    ScanConsentStep(photoSpace: photoSpace, onCancel: cancel)
                        .transition(stepTransition)
                case .flow(.identifying):
                    ScanIdentifyingStep(photoSpace: photoSpace, onCancel: cancel)
                        .transition(stepTransition)
                case .flow(.error):
                    ScanErrorStep(photoSpace: photoSpace, onCancel: cancel, onManual: chooseManually)
                        .transition(stepTransition)
                case .flow(.result):
                    ScanResultStep(gymName: gymName, photoSpace: photoSpace, onCancel: cancel,
                                   onChangeExercises: { path.append(.exercises) })
                        .transition(stepTransition)
                case .flow(.confirmed):
                    ScanConfirmedStep(gymName: gymName, photoSpace: photoSpace, onDone: done,
                                      onScanAnother: { withAnimation(stepAnimation) { store.scanBegin(gymID: gymID) } })
                        .transition(stepTransition)
                }
            }
            .animation(stepAnimation, value: step)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ScanPage.self) { page in
                switch page {
                case .exercises:
                    ScanExercisePicker(onBack: { path.removeLast() })
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .lookSheetGround()
        .environment(\.scanForcedReduceMotion, router.scanVariant("rm"))
        .scanTypeOverride(router.dynamicTypeOverride)
        .presentationDetents([.large])
        .presentationBackground(step == .flow(.camera) ? Color.black : look.groundSheet)
        .interactiveDismissDisabled(step == .flow(.result) || step == .flow(.identifying))
        .onAppear(perform: prepare)
        .onDisappear { store.scanCancel() }
    }

    private var gymName: String { store.gym(store.scan.gymID ?? gymID)?.name ?? "this gym" }
    private var machineCount: Int { store.gymStats(store.scan.gymID ?? gymID).machineCount }

    private var stepAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.86)
    }

    /// Out first, then in: the old step's buttons never sit under the new step's.
    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity.animation(.easeInOut(duration: 0.18)) }
        return .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.3).delay(0.08)),
                           removal: .opacity.animation(.easeIn(duration: 0.1)))
    }

    private func prepare() {
        // A stale flow (a finished scan, or one begun for another gym) starts over at the camera.
        // A caller that forgot scanBegin (no gym yet) also starts fresh, so Add never lands on
        // the wrong gym.
        if store.scan.step == .confirmed || store.scan.gymID != gymID {
            store.scanBegin(gymID: gymID)
        }
        guard !appliedVariant else { return }
        appliedVariant = true
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { applyVariant() }
    }

    private func applyVariant() {
        switch store.scan.step {
        case .camera:
            if router.scanVariant("flash") && !store.scan.torchOn { store.scanToggleTorch() }
            if router.scanVariant("nocamera") { cameraOff = true }
            if router.scanVariant("nokey") { store.removeAIKey() }
        case .result:
            if router.scanVariant("confirmed") {
                store.scanConfirm()
            } else if router.scanVariant("chosen"), let first = store.scan.result?.candidates.first {
                store.scanSelectCandidate(first.id)
            } else if router.scanVariant("newModel") {
                store.scanRetake()
                store.scanSetDemoKind(.newModel)
                store.scanShutter()
            } else if router.scanVariant("exercises") {
                path = [.exercises]
            } else if router.scanVariant("noname") {
                store.scanSetLabel("")
            } else if router.scanVariant("duplicate") {
                ScanDuplicate.seed(store: store, gymID: gymID)
            }
        default:
            break
        }
    }

    private func cancel() {
        store.scanCancel()
        router.dismissSheet()
    }

    private func done() {
        router.dismissSheet()
    }

    /// "Choose a catalog model": the catalog model picker takes the sheet slot.
    private func chooseManually() {
        store.scanSetSimulateFailure(false)
        router.present(.modelPicker(machineID: nil))
    }

    /// "Open AI Settings": the AI settings sheet takes the sheet slot.
    private func openAISettings() {
        router.present(.aiSettings)
    }
}

/// The sheet's steps: the store's flow, plus the no-key gate in front of the camera.
enum ScanSheetStep: Hashable {
    case noKey
    case flow(ScanStep)
}

/// Pages pushed inside the scan sheet.
enum ScanPage: Hashable {
    case exercises
}
