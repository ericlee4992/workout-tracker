import SwiftData
import SwiftUI

// Milestone 8, ticket 02 — correcting an exercise's load type.
//
// WHY THIS EXISTS: the assisted maths was always right. `RecordsMath` ranks
// assisted lower-is-better and excludes it from e1RM, and `isLoggable` already
// accepts 0 for assisted and bodyweight-plus. What the user could not do was
// FIX A WRONG TAG. `loadType` was set once, at creation, and never again — so a
// supported dip logged as `weighted` ranked heaviest-wins forever, and the only
// escape was a different exercise, which splits history (D23, D36).

struct EditExerciseLoadTypeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    @State private var loadType: LoadType = .weighted
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Load type", selection: $loadType) {
                        ForEach(LoadType.allCases, id: \.self) { type in
                            Text(type.badge).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityIdentifier("editLoadTypePicker")
                } header: {
                    Text(exercise.isDeleted ? "" : exercise.name)
                } footer: {
                    Text(explanation)
                }

                if loadType != originalLoadType {
                    Section("What this changes") {
                        Label(
                            "Sets you log from now on are judged as \(loadType.badge).",
                            systemImage: "arrow.forward.circle")
                        // The honest half, and the one a user would otherwise
                        // assume the other way round.
                        Label(
                            "\(loggedSetCount) set\(loggedSetCount == 1 ? "" : "s") already logged keep the type they were logged under. History is frozen on purpose (D23) — this does not rewrite the past.",
                            systemImage: "clock.arrow.circlepath")
                        .accessibilityIdentifier("editLoadTypeHistoryNote")
                    }
                }
            }
            .navigationTitle("Load Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(loadType == originalLoadType)
                        .accessibilityIdentifier("saveLoadType")
                }
            }
            .onAppear {
                guard !loaded, !exercise.isDeleted else { return }
                loadType = exercise.loadType
                loaded = true
            }
        }
    }

    private var originalLoadType: LoadType {
        exercise.isDeleted ? .weighted : exercise.loadType
    }

    /// How many frozen entries already carry a snapshot of this exercise. Shown
    /// so "does not rewrite the past" is a number, not a reassurance.
    private var loggedSetCount: Int {
        guard !exercise.isDeleted else { return 0 }
        return (exercise.entries ?? [])
            .filter { !$0.isDeleted && $0.snapshotCapturedAt != nil }
            .reduce(0) { $0 + ($1.sets ?? []).filter { !$0.isDeleted }.count }
    }

    private var explanation: String {
        switch loadType {
        case .weighted:
            "More weight is harder. Records rank the heaviest set."
        case .bodyweight:
            "Your body is the load. Log reps alone — no weight needed."
        case .bodyweightPlus:
            "Your body plus any weight you add. Enter 0 for a plain set."
        case .assisted:
            "The machine takes weight off you, so LESS assistance is harder. Records rank the least assistance, and 0 means unassisted. This is the setting for supported dips and pull-ups."
        }
    }

    private func save() {
        guard !exercise.isDeleted else { dismiss(); return }
        exercise.loadType = loadType
        // Marks the row so `CatalogSeeder` stops overwriting it. Without this
        // the correction survives only until the next catalog version and then
        // silently reverts (see the field's own comment).
        exercise.loadTypeUserOverridden = true
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save load type: \(error)")
        }
        dismiss()
    }
}
