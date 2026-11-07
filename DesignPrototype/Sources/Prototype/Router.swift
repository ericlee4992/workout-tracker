import SwiftUI

// PROTOTYPE — navigation state for the redesign prototype. Every screen/state that has a
// ScreenID must be reachable from Router state alone, so `-screen <ID>` and ScreenIndex can
// open it. Screens navigate by calling these methods; only App/ maps routes to views.

/// A screen pushed on a tab's navigation stack.
enum Route: Hashable {
    case settings                                        // X01 (from the Workout tab's gear)
    case export                                          // X03 (from Settings)
    case templateDetail(templateID: UUID)                // T01
    case workoutDetail(workoutID: UUID)                  // H03, H04
    case progress(exerciseID: UUID, variationID: String?) // H06 (also from E02)
    case gymDetail(gymID: UUID)                          // G03
    case machineDetail(machineID: UUID)                  // G04
    case deletedMachines(gymID: UUID)                    // G07
    case exerciseDetail(exerciseID: UUID)                // E02
}

/// A sheet. Shown over the live workout while it is presented, otherwise over the tabs
/// (or over the Ask AI cover while that is up).
enum SheetRoute: Identifiable, Hashable {
    case gymMenu                                         // W04 (the gym picker, drawn as a compact sheet)
    case templateEditor(templateID: UUID?)               // T02 (nil = New Template…)
    case saveAsTemplate(workoutID: UUID)                 // T04
    case exercisePicker                                  // L06
    case addByMachine                                    // L07
    case equipment(entryID: UUID)                        // L08
    case barPicker(entryID: UUID, setID: UUID?)          // L09
    case previousPerformance(entryID: UUID)              // L10
    case restSettings(entryID: UUID)                     // L11
    case maxHeartRate                                    // L12
    case cardioPicker                                    // C01
    case cardioDistance(segmentID: UUID)                 // C05
    case finish                                          // F01–F03 (store.finishSummary)
    case calendar                                        // H02
    case editSet(workoutID: UUID, entryID: UUID, setID: UUID) // H05
    case newExercise                                     // E03
    case presets(exerciseID: UUID)                       // E04
    case loadType(exerciseID: UUID)                      // E05
    case editGym(gymID: UUID?)                           // G05 (nil = Add Gym…)
    case modelPicker(machineID: UUID?)                   // G06
    case scan(gymID: UUID)                               // S01–S06 (store.scan drives the step)
    case modelCorrection(machineID: UUID)                // S07
    case aiSettings                                      // X02
    case system(ScreenID)                                // Z01–Z03 system-surface mocks

    var id: Self { self }
}

@Observable
final class Router {
    var tab: AppTab = .workout
    var workoutPath = NavigationPath()
    var historyPath = NavigationPath()
    var gymsPath = NavigationPath()
    var exercisesPath = NavigationPath()
    /// PROPOSAL (Soft, 2026-11-07): Today and Profile get their own stacks; `pushTarget` sends pushes there.
    var todayPath = NavigationPath()
    var profilePath = NavigationPath()
    enum PushTarget { case today, profile }
    var pushTarget: PushTarget?

    /// The one sheet currently shown (see SheetRoute for where it attaches).
    var sheet: SheetRoute?
    /// Ask AI for Templates, a full-screen flow (A01–A05). The live workout cover is driven
    /// by `store.isSessionPresented` instead.
    var aiRoutinePresented = false
    /// Z04/Z05 capture Home/Live at AccessibilityL.
    var dynamicTypeOverride: DynamicTypeSize?
    /// A dialog/menu state a screen should open itself in (W05, T03, L05, L13…), set by
    /// `apply`. Screens read it on appear and clear it.
    var pendingDialog: ScreenID?
    /// A capture variant from `-variant <name>` or ScreenIndex (e.g. "degraded", "gpsLost",
    /// "empty", "failure"). Store-level variants are applied by the shell; view-level ones
    /// (e.g. "empty") are read by the screen that owns them.
    var variant: String?
    /// Set by the live workout's Finish: once the live cover has dismissed, the shell presents
    /// the finish sheet over the tabs. (Live screens call `finishWorkout()` after `store.finish()`.)
    var showFinishAfterCover = false

    func finishWorkout() { showFinishAfterCover = true }

    // MARK: Navigation used by screens

    func push(_ route: Route) {
        if let pushTarget {
            switch pushTarget {
            case .today: todayPath.append(route)
            case .profile: profilePath.append(route)
            }
            return
        }
        switch tab {
        case .workout: workoutPath.append(route)
        case .history: historyPath.append(route)
        case .gyms: gymsPath.append(route)
        case .exercises: exercisesPath.append(route)
        }
    }

    func present(_ route: SheetRoute) { sheet = route }
    func dismissSheet() { sheet = nil }

    func select(_ newTab: AppTab) {
        tab = newTab
    }

    func popToRoot() {
        workoutPath = NavigationPath()
        historyPath = NavigationPath()
        gymsPath = NavigationPath()
        exercisesPath = NavigationPath()
    }

    // MARK: Opening a ScreenID (ScreenIndex and the -screen launch argument)

    /// Call after `store.reset(to: screen)`. Sets tab, stack, sheet and cover so the app
    /// shows exactly that screen/state.
    func apply(_ screen: ScreenID, store: Store) {
        let t = store.screenTarget
        popToRoot()
        sheet = nil
        aiRoutinePresented = false
        dynamicTypeOverride = nil
        pendingDialog = nil
        showFinishAfterCover = false
        tab = screen.tab

        switch screen {
        case .w01, .w02, .w03, .h01, .h07, .g01, .g02, .e01:
            break
        case .w04:
            sheet = .gymMenu
        case .w05, .t03, .l05, .l13:
            pendingDialog = screen
        case .t01:
            if let id = t.templateID { workoutPath.append(Route.templateDetail(templateID: id)) }
        case .t02:
            sheet = .templateEditor(templateID: t.templateID)
        case .t04:
            if let id = t.workoutID { sheet = .saveAsTemplate(workoutID: id) }
        case .a01, .a02, .a03, .a04, .a05:
            aiRoutinePresented = true
        case .l01, .l02, .l03, .l04, .c02, .c03, .c04:
            break
        case .l06:
            sheet = .exercisePicker
        case .l07:
            sheet = .addByMachine
        case .l08:
            if let id = t.entryID { sheet = .equipment(entryID: id) }
        case .l09:
            if let id = t.entryID { sheet = .barPicker(entryID: id, setID: t.secondarySetID) }
        case .l10:
            if let id = t.entryID { sheet = .previousPerformance(entryID: id) }
        case .l11:
            if let id = t.entryID { sheet = .restSettings(entryID: id) }
        case .l12:
            sheet = .maxHeartRate
        case .c01:
            sheet = .cardioPicker
        case .c05:
            if let id = t.segmentID { sheet = .cardioDistance(segmentID: id) }
        case .f01, .f02, .f03:
            sheet = .finish
        case .h02:
            sheet = .calendar
        case .h03, .h04:
            if let id = t.workoutID { historyPath.append(Route.workoutDetail(workoutID: id)) }
        case .h05:
            if let w = t.workoutID, let e = t.entryID, let s = t.setID {
                historyPath.append(Route.workoutDetail(workoutID: w))
                sheet = .editSet(workoutID: w, entryID: e, setID: s)
            }
        case .h06:
            if let id = t.exerciseID { historyPath.append(Route.progress(exerciseID: id, variationID: nil)) }
        case .g03:
            if let id = t.gymID { gymsPath.append(Route.gymDetail(gymID: id)) }
        case .g04:
            if let g = t.gymID { gymsPath.append(Route.gymDetail(gymID: g)) }
            if let m = t.machineID { gymsPath.append(Route.machineDetail(machineID: m)) }
        case .g05:
            if let id = t.gymID {
                gymsPath.append(Route.gymDetail(gymID: id))
                sheet = .editGym(gymID: id)
            }
        case .g06:
            if let id = t.gymID { gymsPath.append(Route.gymDetail(gymID: id)) }
            sheet = .modelPicker(machineID: t.machineID)
        case .g07:
            if let id = t.gymID {
                gymsPath.append(Route.gymDetail(gymID: id))
                gymsPath.append(Route.deletedMachines(gymID: id))
            }
        case .s01, .s02, .s03, .s04, .s05, .s06:
            if let id = t.gymID {
                gymsPath.append(Route.gymDetail(gymID: id))
                sheet = .scan(gymID: id)
            }
        case .s07:
            if let g = t.gymID { gymsPath.append(Route.gymDetail(gymID: g)) }
            if let m = t.machineID {
                gymsPath.append(Route.machineDetail(machineID: m))
                sheet = .modelCorrection(machineID: m)
            }
        case .e02:
            if let id = t.exerciseID { exercisesPath.append(Route.exerciseDetail(exerciseID: id)) }
        case .e03:
            sheet = .newExercise
        case .e04:
            if let id = t.exerciseID {
                exercisesPath.append(Route.exerciseDetail(exerciseID: id))
                sheet = .presets(exerciseID: id)
            }
        case .e05:
            if let id = t.exerciseID {
                exercisesPath.append(Route.exerciseDetail(exerciseID: id))
                sheet = .loadType(exerciseID: id)
            }
        case .x01:
            workoutPath.append(Route.settings)
        case .x02:
            workoutPath.append(Route.settings)
            sheet = .aiSettings
        case .x03:
            workoutPath.append(Route.settings)
            workoutPath.append(Route.export)
        case .z01, .z02, .z03:
            sheet = .system(screen)
        case .z04:
            dynamicTypeOverride = .accessibility1
        case .z05:
            dynamicTypeOverride = .accessibility1
        }
    }
}
