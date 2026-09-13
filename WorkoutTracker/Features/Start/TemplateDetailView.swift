import SwiftData
import SwiftUI

/// UI redesign ticket 11: a template, opened from its tile — the user:
/// "when users click template they should be able to view the list of
/// exercises in the template." The job: see what the template holds and
/// start it in one tap. The eye lands on the exercise list; the bold
/// element, the amber Start capsule, sits at the thumb, pinned above the
/// tab bar so it is there however long the list is. Edit is a toolbar word.
struct TemplateDetailView: View {
    var template: WorkoutTemplate
    /// The Start screen's chosen gym — machines resolve to the last-used
    /// there when the template starts (ticket 15).
    var gym: Gym?
    var onWorkoutStarted: (Workout) -> Void

    @State private var request: WorkoutStartRequest?
    @State private var showingEditor = false
    /// Ticket 15: Delete lives here, confirmed — the tile's long-press menu
    /// deleted the wrong template on the phone and is gone.
    @State private var confirmingDelete = false
    /// View-owned: set BEFORE the model is deleted, so a re-evaluation after
    /// the save never renders a deleted model (`isDeleted` flips back to false
    /// once saved — codex-review-15). The screen goes blank and pops.
    @State private var deleted = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // A deleted template (the tile's long-press menu, while this screen
        // is on the stack) renders empty rather than faulting.
        let items = (deleted || template.isDeleted) ? [] : WorkoutTemplateService.orderedItems(of: template)
        let labels = Supersets.memberLabels(groupIDs: items.map(\.supersetGroupID))
        let families = MuscleFamily.families(of: items.map { $0.exercise?.muscleGroup })
        List {
            if !families.isEmpty {
                Section {
                    MuscleFamilyStrip(families: families)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 0))
                        .accessibilityIdentifier("templateFamilies")
                }
            }
            Section {
                ForEach(Array(zip(items, labels)), id: \.0.id) { item, label in
                    row(item, supersetLabel: label)
                }
            }
            .listRowBackground(Theme.card)
            .listRowSeparatorTint(Theme.hairline)
            // The destructive command last, never primary (ios-design): a red
            // text button after the content, above the pinned Start.
            Section {
                Button("Delete Template…", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("deleteTemplate")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .alert("Delete Template", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: deleteTemplate)
            Button("Cancel", role: .cancel) {}
        } message: {
            // The consequence, in one line: the plan goes, the record stays (D23).
            Text("Workouts already logged from it are kept.")
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle((deleted || template.isDeleted) ? "" : template.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditor = true }
                    .accessibilityIdentifier("editTemplate")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { request = WorkoutStartRequest(template: template) } label: {
                HeroCapsuleLabel(title: "Start", subtitle: startSubtitle(items.count),
                                 symbol: "figure.strengthtraining.traditional", trailing: "arrow.up.right",
                                 live: false)
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Space.large)
            .padding(.bottom, Theme.Space.small)
            .frame(maxWidth: .infinity)
            // Rows scroll under the capsule and fade out beneath it, rather
            // than showing through (the AXL capture, ticket 11).
            .background(
                LinearGradient(colors: [Theme.background.opacity(0), Theme.background],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false))
            .accessibilityIdentifier("startTemplate")
        }
        .workoutStartFlow(request: $request, gym: gym, onWorkoutStarted: onWorkoutStarted)
        .sheet(isPresented: $showingEditor) {
            TemplateEditorSheet(template: template)
        }
        // No identifier on the whole screen: one here is inherited by the
        // capsule in the safe-area inset and hides `startTemplate`.
    }

    /// Name over its targets; the superset chip leads, as in the workout.
    /// At accessibility sizes the chip sits above the name rather than
    /// squeezing it.
    private func row(_ item: TemplateItem, supersetLabel: String?) -> some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.small))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            if let supersetLabel {
                Chip(tint: Theme.accent, selected: true) { Text(supersetLabel) }
                    .accessibilityLabel("Superset position \(supersetLabel)")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.exercise?.name ?? "Missing exercise")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.text)
                Text(item.editableTargets.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("templateExercise.\(item.exercise?.name ?? "")")
    }

    private func deleteTemplate() {
        guard !deleted, !template.isDeleted else { return }
        deleted = true
        do {
            try WorkoutTemplateService(context: modelContext).delete(template)
            dismiss()
        } catch {
            assertionFailure("Failed to delete template: \(error)")
        }
    }

    /// The resume capsule's pattern: "<gym> · N exercises".
    private func startSubtitle(_ count: Int) -> String {
        let exercises = "\(count) \(count == 1 ? "exercise" : "exercises")"
        guard let gymName = gym?.name else { return exercises }
        return "\(gymName) · \(exercises)"
    }
}
