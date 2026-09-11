import SwiftUI

/// UI redesign ticket 05 — Settings as its own screen, reached from the gear
/// on the Workout tab. The two sections are the SAME views that used to sit
/// at the bottom of the Gyms list (`AppSettingsSection`, `ExportSection`),
/// so every row, identifier and string the tests read is unchanged; only
/// the way in moved (the user's choice, 2026-09-10).
struct SettingsView: View {
    var body: some View {
        List {
            AppSettingsSection()
            ExportSection()
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
