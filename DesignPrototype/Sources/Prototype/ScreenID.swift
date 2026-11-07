import Foundation

/// The app's four tabs (icons and labels are kept from the shipped app).
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case workout, history, gyms, exercises

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .workout: "figure.strengthtraining.traditional"
        case .history: "clock.arrow.circlepath"
        case .gyms: "building.2"
        case .exercises: "list.bullet.rectangle"
        }
    }
}

/// How a screen is reached.
enum ScreenPresentation: String, Hashable {
    /// The tab's root.
    case tabRoot
    /// Pushed on the tab's navigation stack.
    case push
    /// A sheet over the tab (or over the live workout for L/C sheets).
    case sheet
    /// A full-screen cover (Ask AI, the live workout, the scanner).
    case cover
    /// A dialog / alert / menu over its parent.
    case dialog
    /// A system surface mock (Live Activity, icon, notification).
    case system
}

/// Every screen and state in screen-list.md. `-screen <rawValue>` and ScreenIndex
/// call `Store.reset(to:)`, which builds the exact store state for the screen.
enum ScreenID: String, CaseIterable, Identifiable, Hashable {
    case w01 = "W01", w02 = "W02", w03 = "W03", w04 = "W04", w05 = "W05"
    case t01 = "T01", t02 = "T02", t03 = "T03", t04 = "T04"
    case a01 = "A01", a02 = "A02", a03 = "A03", a04 = "A04", a05 = "A05"
    case l01 = "L01", l02 = "L02", l03 = "L03", l04 = "L04", l05 = "L05", l06 = "L06", l07 = "L07"
    case l08 = "L08", l09 = "L09", l10 = "L10", l11 = "L11", l12 = "L12", l13 = "L13"
    case c01 = "C01", c02 = "C02", c03 = "C03", c04 = "C04", c05 = "C05"
    case f01 = "F01", f02 = "F02", f03 = "F03"
    case h01 = "H01", h02 = "H02", h03 = "H03", h04 = "H04", h05 = "H05", h06 = "H06", h07 = "H07"
    case g01 = "G01", g02 = "G02", g03 = "G03", g04 = "G04", g05 = "G05", g06 = "G06", g07 = "G07"
    case s01 = "S01", s02 = "S02", s03 = "S03", s04 = "S04", s05 = "S05", s06 = "S06", s07 = "S07"
    case e01 = "E01", e02 = "E02", e03 = "E03", e04 = "E04", e05 = "E05"
    case x01 = "X01", x02 = "X02", x03 = "X03"
    case z01 = "Z01", z02 = "Z02", z03 = "Z03", z04 = "Z04", z05 = "Z05"

    var id: String { rawValue }

    /// Parses "H03", "h03" or "H03-WorkoutDetail".
    init?(argument: String) {
        let code = argument.split(separator: "-").first.map { String($0).uppercased() } ?? ""
        self.init(rawValue: code)
    }

    /// Row number in screen-list.md (1…12).
    var row: Int {
        switch rawValue.first {
        case "W": 1
        case "T": 2
        case "A": 3
        case "L": 4
        case "C": 5
        case "F": 6
        case "H": 7
        case "G": 8
        case "S": 9
        case "E": 10
        case "X": 11
        default: 12
        }
    }

    var rowName: String {
        [1: "Workout tab", 2: "Templates", 3: "Ask AI for Templates", 4: "Live lifting", 5: "Cardio",
         6: "Finish", 7: "History", 8: "Gyms", 9: "Scan & AI identification", 10: "Exercises",
         11: "Settings", 12: "System surfaces and accessibility"][row] ?? ""
    }

    /// The artboard name from screen-list.md (after the ID).
    var title: String {
        switch self {
        case .w01: "Home"
        case .w02: "Home — Live"
        case .w03: "Home — First Run"
        case .w04: "Gym Menu"
        case .w05: "Finish It & Start New"
        case .t01: "Template Detail"
        case .t02: "Template Editor"
        case .t03: "Template Drift"
        case .t04: "Save as Template"
        case .a01: "AI — Goals"
        case .a02: "AI — Equipment"
        case .a03: "AI — Generating"
        case .a04: "AI — Week Preview"
        case .a05: "AI — Day Editor"
        case .l01: "Live"
        case .l02: "Live — Set States"
        case .l03: "Live — New Best"
        case .l04: "Live — HR Rest"
        case .l05: "Live — Menu + Rename"
        case .l06: "Exercise Picker"
        case .l07: "Add by Machine"
        case .l08: "Equipment Sheet"
        case .l09: "Bar Picker"
        case .l10: "Previous Performance"
        case .l11: "Rest Settings"
        case .l12: "Max Heart Rate"
        case .l13: "Discard Confirm"
        case .c01: "Cardio Picker"
        case .c02: "Cardio Live"
        case .c03: "Cardio Paused"
        case .c04: "Cardio Outdoor"
        case .c05: "Cardio Distance"
        case .f01: "Finish"
        case .f02: "Finish — Cardio"
        case .f03: "Finish — Not Saved"
        case .h01: "History"
        case .h02: "Calendar"
        case .h03: "Workout Detail"
        case .h04: "Workout Detail — Cardio"
        case .h05: "Edit Set"
        case .h06: "Progress Chart"
        case .h07: "History — Empty"
        case .g01: "Gyms"
        case .g02: "Gyms — Empty"
        case .g03: "Gym Detail"
        case .g04: "Machine Detail"
        case .g05: "Edit Gym"
        case .g06: "Model Picker"
        case .g07: "Deleted Machines"
        case .s01: "Scan Camera"
        case .s02: "Photo Consent"
        case .s03: "Identifying"
        case .s04: "Result — Specific"
        case .s05: "Result — Ambiguous"
        case .s06: "Result — Generic"
        case .s07: "Model Correction"
        case .e01: "Exercises"
        case .e02: "Exercise Detail"
        case .e03: "New Exercise"
        case .e04: "Presets"
        case .e05: "Load Type"
        case .x01: "Settings"
        case .x02: "AI Settings"
        case .x03: "Export"
        case .z01: "Live Activity"
        case .z02: "App Icon"
        case .z03: "Notification"
        case .z04: "Home — AX L"
        case .z05: "Live — AX L"
        }
    }

    /// One line of what the state shows (from screen-list.md).
    var note: String {
        switch self {
        case .w01: "Idle at Iron Temple, 4 templates, this week"
        case .w02: "A workout is running: Resume capsule with elapsed time and live pulse"
        case .w03: "No gym, no templates, no history"
        case .w04: "Gym picker open over Home"
        case .w05: "Starting Whole Body while Push Day runs (then the replacement drift dialog)"
        case .t01: "Push Day: families, stats, Start, exercise rows, superset A/B"
        case .t02: "Editing Push Day"
        case .t03: "Push Day changed: four resolutions with a visual diff"
        case .t04: "Name entry for today's Push Day"
        case .a01: "Step 1: goals, experience, days, minutes, profile"
        case .a02: "Step 2: gym, machines, equipment, cardio, consent"
        case .a03: "Generating (progress)"
        case .a04: "Three generated sessions"
        case .a05: "Editing Day 1"
        case .l01: "Push Day, 18:42, 7/18 sets, rest 1:24"
        case .l02: "W/F/D, superset A/B, bar mode, prefilled/typed/done"
        case .l03: "Seated Chest Press 110 × 8 just beat 105 × 8"
        case .l04: "Rest until below 110 bpm, 4:00 cap"
        case .l05: "Seated Chest Press entry menu; rename"
        case .l06: "Add Exercise sheet"
        case .l07: "Machines at Iron Temple"
        case .l08: "Seated Chest Press equipment (frozen); Lateral Raise counterpart offer"
        case .l09: "Bench Press bar: 45 lb bar + per side"
        case .l10: "Seated Chest Press on Chest Press 2: three layers"
        case .l11: "Seated Chest Press rest settings"
        case .l12: "Measured max 185 bpm, zone ladder"
        case .l13: "Discard confirmation; 2 unticked rows"
        case .c01: "Nine activities"
        case .c02: "Indoor Run recording, 20-min target"
        case .c03: "Indoor Run paused"
        case .c04: "Outdoor Run recording (no map); GPS-lost variant"
        case .c05: "Distance editor over an ended segment"
        case .f01: "Push Day summary"
        case .f02: "Push Day + Outdoor Run with route"
        case .f03: "Nothing logged"
        case .h01: "September, grouped by week"
        case .h02: "Month grid, Sep 21 selected"
        case .h03: "Whole Body, Sep 19 (edited): bar, superset, cardio"
        case .h04: "Outdoor Run, Aug 29, Central Park"
        case .h05: "Editing set 2 of Seated Chest Press, Sep 17"
        case .h06: "Seated Chest Press progress"
        case .h07: "No history"
        case .g01: "Three gyms"
        case .g02: "No gyms"
        case .g03: "Iron Temple"
        case .g04: "Chest Press 2 (Seated Row: usual preset)"
        case .g05: "Edit Iron Temple"
        case .g06: "Catalog search"
        case .g07: "Two deleted machines at Iron Temple"
        case .s01: "Viewfinder at Iron Temple"
        case .s02: "What leaves the phone"
        case .s03: "Identifying with the photo (failure variant)"
        case .s04: "Matrix MG-PL71 Hack Squat"
        case .s05: "Three Watson candidates"
        case .s06: "No model claimed"
        case .s07: "Correct Lat Pulldown's model"
        case .e01: "Grouped by body area"
        case .e02: "Seated Chest Press"
        case .e03: "New Exercise sheet"
        case .e04: "Seated Chest Press presets"
        case .e05: "Dip load type"
        case .x01: "Settings, history update line"
        case .x02: "Key saved, consents"
        case .x03: "CSV / JSON export (failure variant)"
        case .z01: "Lock screen + Dynamic Island, rest running; cardio variant"
        case .z02: "App icon"
        case .z03: "Rest complete notifications"
        case .z04: "Home at AccessibilityL"
        case .z05: "Live at AccessibilityL"
        }
    }

    /// The tab the screen lives under (live/cardio screens: the Workout tab, under the live cover).
    var tab: AppTab {
        switch row {
        case 7: .history
        case 8, 9: .gyms
        case 10: .exercises
        default: .workout
        }
    }

    var presentation: ScreenPresentation {
        switch self {
        case .w01, .w02, .w03, .h01, .h07, .g01, .g02, .e01, .z04: .tabRoot
        case .t01, .h03, .h04, .g03, .g04, .g07, .e02, .x01: .push
        case .w04, .w05, .t03, .l05, .l13: .dialog
        case .a01, .a02, .a03, .a04, .a05, .l01, .l02, .l03, .l04, .c02, .c03, .c04, .z05,
             .s01, .s02, .s03, .s04, .s05, .s06: .cover
        case .z01, .z02, .z03: .system
        default: .sheet
        }
    }

    /// The live workout cover is up underneath this screen.
    var overLiveWorkout: Bool {
        switch self {
        case .l01, .l02, .l03, .l04, .l05, .l06, .l07, .l08, .l09, .l10, .l11, .l12, .l13,
             .c02, .c03, .c04, .c05, .z05: true
        default: false
        }
    }

    static var rows: [(row: Int, name: String, screens: [ScreenID])] {
        Dictionary(grouping: allCases, by: \.row).keys.sorted().map { row in
            let screens = allCases.filter { $0.row == row }
            return (row, screens[0].rowName, screens)
        }
    }
}
