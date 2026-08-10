import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    var workout: Workout
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

            Section {
            } footer: {
                Text(displayUnit == nil
                    ? "Equipment shown as it was when this workout was logged. Weights display in the unit you entered."
                    : "Converted values are approximate (≈). Your sets stay stored exactly as entered.")
            }
        }
        .navigationTitle(workout.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Units", selection: $displayUnit) {
                        Text("As entered").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text("Show in \(unit.rawValue)").tag(WeightUnit?.some(unit))
                        }
                    }
                } label: {
                    Label(displayUnit?.rawValue ?? "As entered", systemImage: "scalemass")
                }
            }
        }
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
            Text("\(weightLabel(for: set)) × \(set.reps.map(String.init) ?? "—")")
                .font(.body)
            Spacer()
        }
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
