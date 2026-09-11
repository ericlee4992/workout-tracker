import SwiftData
import SwiftUI

/// One request to start a workout — empty, or from a template. A fresh id
/// per request, so tapping Start twice on the same template fires twice.
struct WorkoutStartRequest: Equatable {
    let id = UUID()
    var template: WorkoutTemplate?

    static func == (lhs: WorkoutStartRequest, rhs: WorkoutStartRequest) -> Bool {
        lhs.id == rhs.id
    }
}

/// UI redesign ticket 11: the start flow, lifted out of `StartWorkoutView`
/// so the pushed template detail can run it too. A dialog attached to the
/// Start screen's List does not present while a pushed screen covers it, so
/// each screen that can start a workout wears this modifier and its own
/// dialogs. Setting `request` runs the flow; the modifier clears it.
///
/// The flow (unchanged from ticket 10): start-while-active offers Resume or
/// Finish-and-start-new; finishing a workout that drifted from its template
/// asks how to save the template first (D48's drift dialog); the replaced
/// workout's heart-rate summary is banked before anything finishes it
/// (codex-review 05, 05b).
struct WorkoutStartFlow: ViewModifier {
    @Binding var request: WorkoutStartRequest?
    var gym: Gym?
    var onWorkoutStarted: (Workout) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutHeartRateCoordinator.self) private var heartRateCoordinator
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var showingResumeDialog = false
    @State private var replacementWorkout: Workout?
    @State private var replacementSourceTemplate: WorkoutTemplate?
    @State private var showingReplacementDrift = false

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "A workout is already in progress",
                isPresented: $showingResumeDialog,
                titleVisibility: .visible
            ) {
                Button("Resume Workout") { resumeActive() }
                Button("Finish It & Start New") { finishActiveThenStartTapped() }
                Button("Cancel", role: .cancel) {}
            } message: {
                // A consequence, not a tutorial: finishing discards every
                // uncompleted set (codex-review 06).
                Text("Only its completed sets are kept.")
            }
            .templateDriftDialog(
                isPresented: $showingReplacementDrift,
                message: "The active workout differs from the template it started from. Choose how to save that template before starting the next workout.",
                cancelLabel: "Keep Current Workout",
                resolve: resolveReplacementDrift)
            .onChange(of: request) { _, new in
                guard let new else { return }
                request = nil
                startTapped(template: new.template)
            }
    }

    private func startTapped(template: WorkoutTemplate?) {
        pendingTemplate = template
        if (try? session.resumableWorkout()) != nil {
            showingResumeDialog = true
        } else {
            startNew()
        }
    }

    private func startNew() {
        do {
            // Any still-active workout is auto-finished by `startWorkout`,
            // which ends its rest timer and pending notification — but NOT its
            // heart-rate session, which lives in the coordinator. Bank and end
            // it here first, or the replaced workout reaches History with no
            // summary (codex-review 05, critical).
            if let active = try session.resumableWorkout() {
                heartRateCoordinator.end(active)
            }
            let workout: Workout
            if let template = pendingTemplate {
                workout = try WorkoutTemplateService(context: modelContext)
                    .start(template, at: gym)
            } else {
                workout = try session.startWorkout(at: gym)
            }
            pendingTemplate = nil
            onWorkoutStarted(workout)
        } catch {
            assertionFailure("Failed to start workout: \(error)")
        }
    }

    private func finishActiveThenStartTapped() {
        do {
            guard let active = try session.resumableWorkout() else {
                startNew()
                return
            }
            let drift = TemplateDriftService(context: modelContext)
            if let template = try drift.sourceTemplate(for: active),
               try drift.shouldPrompt(for: active, template: template) {
                replacementWorkout = active
                replacementSourceTemplate = template
                showingReplacementDrift = true
            } else {
                startNew()
            }
        } catch {
            assertionFailure("Failed to inspect active workout drift: \(error)")
        }
    }

    private func resolveReplacementDrift(_ resolution: TemplateDriftResolution) {
        do {
            if let workout = replacementWorkout,
               let template = replacementSourceTemplate {
                // BEFORE resolve, which finishes and saves the workout: after
                // that it is no longer resumable, `startNew` would find nothing
                // to end, and the summary would be lost (codex-review 05b,
                // critical). Banked here while this view still holds it.
                heartRateCoordinator.end(workout)
                try TemplateDriftService(context: modelContext).resolve(
                    resolution, workout: workout, to: template)
            }
            replacementWorkout = nil
            replacementSourceTemplate = nil
            startNew()
        } catch {
            assertionFailure("Failed to resolve template before starting: \(error)")
        }
    }

    private func resumeActive() {
        pendingTemplate = nil
        if let workout = try? session.resumableWorkout() {
            onWorkoutStarted(workout)
        }
    }
}

extension View {
    func workoutStartFlow(
        request: Binding<WorkoutStartRequest?>,
        gym: Gym?,
        onWorkoutStarted: @escaping (Workout) -> Void
    ) -> some View {
        modifier(WorkoutStartFlow(request: request, gym: gym, onWorkoutStarted: onWorkoutStarted))
    }
}
