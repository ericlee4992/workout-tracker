import SwiftData
import SwiftUI

/// "Save as Template" — the naming alert and its failure alert, shared by the
/// finish sheet (milestone 9) and History's workout detail (ticket 13: the
/// user asked to save a template from History). One flow, so the two never
/// drift: the same title, the same field, the same consequence line, the
/// same failure copy. Present it by setting `isPresented`; the default name
/// is filled in at that moment ("Workout <date>").
struct SaveAsTemplateFlow: ViewModifier {
    var workout: Workout?
    @Binding var isPresented: Bool
    var onSaved: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var templateName = ""
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, presented in
                if presented { templateName = Self.defaultName(for: workout) }
            }
            .alert("Save as Template", isPresented: $isPresented) {
                TextField("Template name", text: $templateName)
                Button("Save", action: save)
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(workout?.recordedCardio.isEmpty == false
                     ? "Saves lifting exercises, sets and target reps. Cardio, weights and rest times are not included."
                     : "Saves exercises, sets and target reps — not weights or rest times.")
            }
            .alert(
                "Couldn't Save Template",
                isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
            ) {
                Button("OK", role: .cancel) { failure = nil }
            } message: {
                Text(failure ?? "")
            }
    }

    private func save() {
        guard let workout, !workout.isDeleted else { return }
        do {
            let template = try WorkoutTemplateService(context: modelContext)
                .saveAsTemplate(workout, name: templateName)
            onSaved(template.name)
        } catch {
            failure = Self.failureMessage(error)
        }
    }

    static func defaultName(for workout: Workout?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = workout.map { $0.isDeleted ? Date.now : $0.startedAt } ?? .now
        return "Workout \(formatter.string(from: date))"
    }

    static func failureMessage(_ error: Error) -> String {
        switch error as? WorkoutTemplateError {
        case .emptyName:
            return "Give the template a name and try again."
        case .noExercises:
            return "This workout has no completed sets or recorded cardio to save as a template."
        case .invalidCardioTargets:
            return error.localizedDescription
        case nil:
            return "The template could not be saved: \(error.localizedDescription)"
        }
    }
}

extension View {
    func saveAsTemplateFlow(
        workout: Workout?,
        isPresented: Binding<Bool>,
        onSaved: @escaping (String) -> Void
    ) -> some View {
        modifier(SaveAsTemplateFlow(workout: workout, isPresented: isPresented, onSaved: onSaved))
    }
}
