import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var workout: Workout
    /// The set being corrected, if any (milestone 8, ticket 03).
    @State private var editingSet: SetRecord?
    @State private var confirmingDelete = false
    /// Whole-view convert toggle (D9): nil shows every weight as entered;
    /// a unit renders everything in that unit with conversions ≈-marked.
    /// Display-only — storage is never touched.
    @State private var displayUnit: WeightUnit?

    var body: some View {
        List {
            Section {
                HStack {
                    Label(workout.historyGymName ?? "No gym", systemImage: "mappin.and.ellipse")
                    Spacer()
                    // E3 (ticket 17): seconds below a minute, here too.
                    Text(workout.durationLabel ?? "—")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            ForEach(WorkoutSession.orderedEntries(of: workout)) { entry in
                Section {
                    let sets = WorkoutSession.orderedSets(of: entry)
                        .filter { $0.completedAt != nil }
                    ForEach(Array(sets.enumerated()), id: \.element.id) { pair in
                        setLine(index: pair.offset, set: pair.element)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("historySetLine")
                            .contentShape(Rectangle())
                            .onTapGesture { editingSet = pair.element }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteSet(pair.element)
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                } header: {
                    // Snapshot display strings ONLY (D23) — never the live
                    // exercise/machine/model relationships.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.snapshotExerciseName)
                        Text(entry.snapshotEquipmentLabel)
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let edited = workout.isDeleted ? nil : workout.historyEditedAt {
                Section {
                    Label(
                        "Edited \(edited.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("historyEditedMark")
                }
            }

            Section {
            } footer: {
                Text(displayUnit == nil
                    ? "Equipment shown as it was when this workout was logged. Weights display in the unit you entered."
                    : "Converted values are approximate (≈). Your sets stay stored exactly as entered.")
            }
        }
        .navigationTitle(workout.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSet) { set in
            EditLoggedSetSheet(record: set)
        }
        .confirmationDialog(
            "Delete this workout?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive) { deleteWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            // Names what is lost. This phone holds the only copy of the user's
            // training history, so "are you sure?" about an unknown quantity is
            // not good enough.
            let impact = HistoryEditing.impact(ofDeleting: workout)
            Text("\(impact.sets) set\(impact.sets == 1 ? "" : "s") across \(impact.exercises) exercise\(impact.exercises == 1 ? "" : "s") will be permanently deleted. Records and volume will be recalculated without them.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Workout…", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                    .accessibilityIdentifier("deleteWorkout")
                    Divider()
                    Picker("Units", selection: $displayUnit) {
                        Text("As entered").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text("Show in \(unit.rawValue)").tag(WeightUnit?.some(unit))
                        }
                    }
                } label: {
                    Label(displayUnit?.rawValue ?? "As entered", systemImage: "scalemass")
                }
                .accessibilityIdentifier("workoutDetailMenu")
            }
        }
    }

    private func deleteSet(_ set: SetRecord) {
        let entry = HistoryEditing.deleteSet(set, in: modelContext)
        if let entry { HistoryEditing.pruneIfEmpty(entry, in: modelContext) }
        save()
    }

    private func deleteWorkout() {
        modelContext.delete(workout)
        save()
        dismiss()
    }

    private func save() {
        do { try modelContext.save() }
        catch { assertionFailure("Failed to save history edit: \(error)") }
    }

    /// Weight text for a set under the current toggle: as entered by default,
    /// ≈-marked when rendered in the other unit (WeightMath, D25).
    private func weightLabel(for set: SetRecord) -> String {
        guard let value = set.weightValue,
              let stored = StoredWeight(value: value, unit: set.weightUnit) else {
            return "—"
        }
        return WeightMath.displayLabel(for: stored, in: displayUnit ?? stored.unit)
    }

    private func setLine(index: Int, set: SetRecord) -> some View {
        HStack(spacing: 10) {
            Text(set.type.marker ?? "\(index + 1)")
                .font(.subheadline.weight(.semibold))
                // Same marker tints as the active workout (W/F/D), so a `D`
                // in history means what it meant while logging (D26).
                .foregroundStyle(set.type.markerColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(weightLabel(for: set)) × \(set.reps.map(String.init) ?? "—")")
                    .font(.body)
                if let breakdown = barBreakdown(for: set) {
                    Text(breakdown)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    /// D39: how a bar-mode set was loaded — `45 + 45 × 2 = 135 lb`. The weight
    /// above it is the total, and always was; this only says where it came from.
    ///
    /// Shown as entered only. Under the convert toggle the numbers above are
    /// ≈ values (D9/D25), and an ≈ sum of two ≈ parts reads as arithmetic the
    /// app is claiming rather than reporting.
    private func barBreakdown(for set: SetRecord) -> String? {
        guard displayUnit == nil || displayUnit == set.weightUnit,
              let bar = set.barWeightValue, let total = set.weightValue
        else { return nil }
        return BarbellMath.breakdownLabel(
            barWeight: bar, total: total, unit: set.weightUnit)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let workout = Workout(
        startedAt: .now.addingTimeInterval(-3600), finishedAt: .now,
        snapshotGymName: "Gold's Gym Gangnam",
        gym: Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg))
    container.mainContext.insert(workout)
    let entry = ExerciseEntry(
        order: 0, workout: workout,
        snapshotCapturedAt: .now,
        snapshotExerciseID: UUID(),
        snapshotLoadType: .weighted,
        snapshotExerciseName: "Seated Chest Press",
        snapshotMachineLabel: "Chest Press #1",
        snapshotModelName: "Life Fitness Insignia Chest Press")
    container.mainContext.insert(entry)
    container.mainContext.insert(SetRecord(
        order: 0, type: .warmup, reps: 12, weightValue: 40,
        normalizedKg: 40, completedAt: .now, entry: entry))
    container.mainContext.insert(SetRecord(
        order: 1, reps: 10, weightValue: 60,
        normalizedKg: 60, completedAt: .now, entry: entry))
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
