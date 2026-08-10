import SwiftData
import SwiftUI

/// C2 (ticket 17) — the receipt for a finished workout. Finishing used to
/// drop you on the Workout tab with no confirmation and no way back to what
/// you just logged. This says what was saved, offers the workout itself, and
/// carries the save-as-template option that used to block Finish (B2).
///
/// Light and skippable: Done is always one tap away.
struct WorkoutFinishedSheet: View {
    @Environment(\.modelContext) private var modelContext
    var workout: Workout
    /// Dismisses the sheet and shows the workout in History.
    var viewInHistory: () -> Void
    var done: () -> Void

    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var templateFailure: String?
    @State private var savedTemplateName: String?

    private var entryCount: Int {
        workout.isDeleted ? 0 : WorkoutSession.orderedEntries(of: workout).count
    }

    private var setCount: Int {
        workout.isDeleted ? 0 : workout.completedSets.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Workout saved", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text(summaryLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("finishedSummary")
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button("View in History", systemImage: "clock.arrow.circlepath") {
                        viewInHistory()
                    }
                    .accessibilityIdentifier("viewFinishedWorkout")

                    if let savedTemplateName {
                        Label("Saved as template “\(savedTemplateName)”", systemImage: "checkmark")
                            .foregroundStyle(.secondary)
                    } else if canSaveAsTemplate {
                        Button("Save as Template", systemImage: "square.on.square") {
                            templateName = defaultTemplateName
                            namingTemplate = true
                        }
                        .accessibilityIdentifier("saveAsTemplate")
                    }
                } footer: {
                    if savedTemplateName == nil, canSaveAsTemplate {
                        Text("Completed sets become target set and rep slots. Weights and rest times are not saved.")
                    }
                }
            }
            .navigationTitle("Nice work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { done() }
                        .font(.headline)
                        .accessibilityIdentifier("finishedDone")
                }
            }
            .alert("Save as Template", isPresented: $namingTemplate) {
                TextField("Template name", text: $templateName)
                Button("Save") { saveTemplate() }
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Completed sets become target set and rep slots. Weights and rest times are not saved.")
            }
            .alert(
                "Couldn't Save Template",
                isPresented: Binding(
                    get: { templateFailure != nil },
                    set: { if !$0 { templateFailure = nil } })
            ) {
                Button("OK", role: .cancel) { templateFailure = nil }
            } message: {
                Text(templateFailure ?? "")
            }
        }
    }

    private var summaryLine: String {
        var parts = [
            "\(entryCount) \(entryCount == 1 ? "exercise" : "exercises")",
            "\(setCount) \(setCount == 1 ? "set" : "sets")",
        ]
        if let gymName = workout.isDeleted ? nil : workout.gym?.name {
            parts.append(gymName)
        }
        return parts.joined(separator: " · ")
    }

    /// A workout can only become a template once something has been
    /// completed — `saveAsTemplate` captures completed sets only and throws
    /// `noExercises` otherwise.
    private var canSaveAsTemplate: Bool {
        !workout.isDeleted && WorkoutTemplateService.canSaveAsTemplate(workout)
    }

    private var defaultTemplateName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Workout \(formatter.string(from: workout.startedAt))"
    }

    private func saveTemplate() {
        do {
            let template = try WorkoutTemplateService(context: modelContext)
                .saveAsTemplate(workout, name: templateName)
            savedTemplateName = template.name
        } catch {
            templateFailure = Self.templateFailureMessage(error)
        }
    }

    private static func templateFailureMessage(_ error: Error) -> String {
        switch error as? WorkoutTemplateError {
        case .emptyName:
            return "Give the template a name and try again."
        case .noExercises:
            return "This workout has no completed sets, so there is nothing to save as a template."
        case nil:
            return "The template could not be saved: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let context = container.mainContext
    let gym = Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg)
    context.insert(gym)
    let workout = Workout(startedAt: .now.addingTimeInterval(-2_700), finishedAt: .now, gym: gym)
    context.insert(workout)
    return WorkoutFinishedSheet(workout: workout, viewInHistory: {}, done: {})
        .modelContainer(container)
}
