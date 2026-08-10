import SwiftData
import SwiftUI

/// C2 (ticket 17) — the receipt for a finished workout. Finishing used to
/// drop you on the Workout tab with no confirmation and no way back to what
/// you just logged. This says what was saved, offers the workout itself, and
/// carries the save-as-template option that used to block Finish (B2).
///
/// A2: `workout` is nil when the workout was empty and got discarded instead
/// of finished. The same receipt then says *that* — silently vanishing and
/// confirming a save are both lies about what happened.
///
/// Light and skippable: Done is always one tap away.
struct WorkoutFinishedSheet: View {
    @Environment(\.modelContext) private var modelContext
    /// The saved workout, or nil when nothing was logged (A2).
    var workout: Workout?
    /// Dismisses the sheet and shows the workout in History.
    var viewInHistory: () -> Void
    var done: () -> Void

    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var templateFailure: String?
    @State private var savedTemplateName: String?

    /// The workout only when it really reached history — a deleted or
    /// missing one is the discarded case, whatever the caller passed.
    private var savedWorkout: Workout? {
        guard let workout, !workout.isDeleted, workout.finishedAt != nil else {
            return nil
        }
        return workout
    }

    private var entryCount: Int {
        savedWorkout.map { WorkoutSession.orderedEntries(of: $0).count } ?? 0
    }

    private var setCount: Int {
        savedWorkout?.completedSets.count ?? 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            savedWorkout == nil ? "Nothing to save" : "Workout saved",
                            systemImage: savedWorkout == nil
                                ? "tray" : "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(savedWorkout == nil ? Color.secondary : Color.green)
                        Text(summaryLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("finishedSummary")
                    }
                    .padding(.vertical, 4)
                }

                if savedWorkout != nil {
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
            }
            .navigationTitle(savedWorkout == nil ? "Nothing logged" : "Nice work")
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
        guard let saved = savedWorkout else {
            return "No sets were completed, so this workout wasn't saved."
        }
        var parts = [
            HistoryRendering.pluralized(entryCount, "exercise", "exercises"),
            HistoryRendering.pluralized(setCount, "set", "sets"),
        ]
        // The snapshot name (D23), like the rest of history — the receipt
        // describes what was logged, not what the gym is called now.
        if let gymName = saved.historyGymName {
            parts.append(gymName)
        }
        return parts.joined(separator: " · ")
    }

    /// A workout can only become a template once something has been
    /// completed — `saveAsTemplate` captures completed sets only and throws
    /// `noExercises` otherwise.
    private var canSaveAsTemplate: Bool {
        savedWorkout.map(WorkoutTemplateService.canSaveAsTemplate) ?? false
    }

    private var defaultTemplateName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = savedWorkout?.startedAt ?? .now
        return "Workout \(formatter.string(from: date))"
    }

    private func saveTemplate() {
        guard let saved = savedWorkout else { return }
        do {
            let template = try WorkoutTemplateService(context: modelContext)
                .saveAsTemplate(saved, name: templateName)
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
    let workout = Workout(
        startedAt: .now.addingTimeInterval(-2_700), finishedAt: .now,
        snapshotGymName: gym.name, gym: gym)
    context.insert(workout)
    return WorkoutFinishedSheet(workout: workout, viewInHistory: {}, done: {})
        .modelContainer(container)
}
