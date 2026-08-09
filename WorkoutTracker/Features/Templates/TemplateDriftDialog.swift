import SwiftUI

extension View {
    /// D18's four-option drift prompt: update the template's structure, its
    /// values only, both, or keep the original. Every place a
    /// template-sourced workout is closed out asks the same question with the
    /// same four options in the same order — only the explanatory message and
    /// the wording of the do-nothing button differ — so the options live here
    /// once and cannot drift apart between screens.
    ///
    /// `resolve` is called with the chosen resolution; the cancel button is
    /// the only path that leaves both workout and template untouched.
    func templateDriftDialog(
        isPresented: Binding<Bool>,
        message: String,
        cancelLabel: String,
        resolve: @escaping (TemplateDriftResolution) -> Void
    ) -> some View {
        confirmationDialog(
            "Update workout template?",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Update Template") { resolve(.updateTemplate) }
            Button("Update Values Only") { resolve(.updateValuesOnly) }
            Button("Update Both") { resolve(.updateBoth) }
            Button("Keep Original") { resolve(.keepOriginal) }
            Button(cancelLabel, role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
