import SwiftUI

// PROTOTYPE — the only place that maps routes to area screens.

struct RouteContent: View {
    let route: Route

    var body: some View {
        switch route {
        case .settings: SettingsScreen()
        case .export: ExportScreen()
        case .templateDetail(let id): TemplateDetailScreen(templateID: id)
        case .workoutDetail(let id): WorkoutDetailScreen(workoutID: id)
        case .progress(let id, let variation): ProgressChartScreen(exerciseID: id, variationID: variation)
        case .gymDetail(let id): GymDetailScreen(gymID: id)
        case .machineDetail(let id): MachineDetailScreen(machineID: id)
        case .deletedMachines(let id): DeletedMachinesScreen(gymID: id)
        case .exerciseDetail(let id): ExerciseDetailScreen(exerciseID: id)
        }
    }
}

struct SheetContent: View {
    let route: SheetRoute

    var body: some View {
        switch route {
        case .gymMenu: GymMenuSheet()
        case .templateEditor(let id): TemplateEditorSheet(templateID: id)
        case .saveAsTemplate(let id): SaveAsTemplateSheet(workoutID: id)
        case .exercisePicker: ExercisePickerSheet()
        case .addByMachine: AddByMachineSheet()
        case .equipment(let id): EquipmentSheet(entryID: id)
        case .barPicker(let entry, let set): BarPickerSheet(entryID: entry, setID: set)
        case .previousPerformance(let id): PreviousPerformanceSheet(entryID: id)
        case .restSettings(let id): RestSettingsSheet(entryID: id)
        case .maxHeartRate: MaxHeartRateSheet()
        case .cardioPicker: CardioPickerSheet()
        case .cardioDistance(let id): CardioDistanceSheet(segmentID: id)
        case .finish: FinishSummarySheet()
        case .calendar: HistoryCalendarSheet()
        case .editSet(let w, let e, let s): EditSetSheet(workoutID: w, entryID: e, setID: s)
        case .newExercise: NewExerciseSheet()
        case .presets(let id): PresetsSheet(exerciseID: id)
        case .loadType(let id): LoadTypeSheet(exerciseID: id)
        case .editGym(let id): EditGymSheet(gymID: id)
        case .modelPicker(let id): ModelPickerSheet(machineID: id)
        case .scan(let id): ScanFlowSheet(gymID: id)
        case .modelCorrection(let id): ModelCorrectionSheet(machineID: id)
        case .aiSettings: AISettingsSheet()
        case .system(let screen): SystemSurfaceSheet(screen: screen)
        }
    }
}
