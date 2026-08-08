import SwiftData
import SwiftUI

extension ExerciseEntry {
    /// Display label for the entry's current equipment choice.
    var equipmentDisplayLabel: String {
        if let machine { return machine.label }
        if let freeWeightTag { return freeWeightTag.label }
        return "Choose equipment"
    }
}

struct ExerciseEntryCard: View {
    @Environment(\.modelContext) private var modelContext
    var entry: ExerciseEntry
    var showMachinePicker: () -> Void
    var showPerformance: () -> Void
    var completionChanged: (SetRecord, Bool) -> Void
    @State private var showingRestSettings = false

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    private var orderedSets: [SetRecord] {
        entry.isDeleted ? [] : WorkoutSession.orderedSets(of: entry)
    }

    private var loadType: LoadType {
        entry.exercise?.loadType ?? entry.snapshotLoadType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            machineRow

            if loadType == .assisted {
                Label("Assisted: lower weight = harder. Records track least assistance.", systemImage: "arrow.down.right.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            columnHeaders

            ForEach(orderedSets) { set in
                SetRowView(
                    set: set,
                    index: workingIndex(of: set),
                    onCompletionChanged: { completed in
                        completionChanged(set, completed)
                    },
                    onDelete: { deleteSet(set) })
            }

            Button {
                addSet()
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .sheet(isPresented: $showingRestSettings) {
            if let exercise = entry.exercise {
                ExerciseRestSettingsSheet(exercise: exercise)
            }
        }
    }

    private var titleRow: some View {
        HStack {
            Text(entry.exercise?.name ?? entry.snapshotExerciseName)
                .font(.headline)
            Spacer()
            Menu {
                if entry.exercise != nil {
                    Button("Rest Durations…", systemImage: "timer") {
                        showingRestSettings = true
                    }
                }
                Button("Delete Exercise", systemImage: "trash", role: .destructive) {
                    deleteEntry()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Exercise options")
            Button(action: showPerformance) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(.tint)
            }
            .accessibilityLabel("Previous performance")
        }
    }

    private var machineRow: some View {
        Button(action: showMachinePicker) {
            HStack(spacing: 6) {
                Image(systemName: entry.machine != nil ? "gearshape.2" : "dumbbell")
                    .font(.caption)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.equipmentDisplayLabel)
                        .font(.subheadline.weight(.medium))
                    if let model = entry.machine?.model {
                        Text(model.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 34)
            Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
            Text(weightHeader).frame(width: 88)
            Text("REPS").frame(width: 48)
            Color.clear.frame(width: 30)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private var weightHeader: String {
        loadType == .assisted ? "ASSIST" : "WEIGHT"
    }

    private func workingIndex(of set: SetRecord) -> Int {
        var index = 0
        for s in orderedSets {
            if s.type != .warmup { index += 1 }
            if s.id == set.id { break }
        }
        return index
    }

    // MARK: Actions

    private func addSet() {
        do {
            try session.addSet(to: entry)
        } catch {
            assertionFailure("Failed to add set: \(error)")
        }
    }

    private func deleteSet(_ set: SetRecord) {
        do {
            try session.deleteSet(set)
        } catch {
            assertionFailure("Failed to delete set: \(error)")
        }
    }

    private func deleteEntry() {
        do {
            try session.deleteEntry(entry)
        } catch {
            assertionFailure("Failed to delete entry: \(error)")
        }
    }
}

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    var set: SetRecord
    var index: Int
    /// Called after either completion direction so the rest timer can start,
    /// replace, or cancel its persisted source.
    var onCompletionChanged: (Bool) -> Void
    var onDelete: () -> Void

    // In-progress keystrokes live here; they hit the store only on commit
    // (end-editing / completion) — SPEC's durability boundary.
    @State private var weightText: String
    @State private var repsText: String
    @State private var previousLabel = "—"
    @State private var isDirty = false
    @FocusState private var focusedField: Field?

    private enum Field { case weight, reps }

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    init(
        set: SetRecord, index: Int,
        onCompletionChanged: @escaping (Bool) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.set = set
        self.index = index
        self.onCompletionChanged = onCompletionChanged
        self.onDelete = onDelete
        _weightText = State(initialValue: set.weightValue.map(Format.weight) ?? "")
        _repsText = State(initialValue: set.reps.map(String.init) ?? "")
    }

    private var isCompleted: Bool { !set.isDeleted && set.completedAt != nil }

    var body: some View {
        HStack(spacing: 8) {
            setTypeButton

            Text(previousLabel)
                .font(.footnote)
                .foregroundStyle(previousLabel == "—" ? .tertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                TextField("–", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .multilineTextAlignment(.center)
                    .frame(width: 48)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button {
                    toggleUnit()
                } label: {
                    UnitBadge(unit: set.isDeleted ? .kg : set.weightUnit)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 88)

            TextField("–", text: $repsText)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps)
                .multilineTextAlignment(.center)
                .frame(width: 48)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            completeButton
                .frame(width: 30)
        }
        .font(.subheadline)
        .opacity(isCompleted ? 0.75 : 1)
        .contextMenu {
            Button("Delete Set", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .onChange(of: focusedField) { previous, _ in
            // Field commit on end-editing (SPEC durability boundary).
            switch previous {
            case .weight: commitWeight()
            case .reps: commitReps()
            case nil: break
            }
        }
        .onChange(of: weightText) { _, _ in
            if focusedField == .weight { isDirty = true }
        }
        .onChange(of: repsText) { _, _ in
            if focusedField == .reps { isDirty = true }
        }
        .task(id: prefillTaskID) {
            loadPreviousAndPrefill()
        }
    }

    private var setTypeButton: some View {
        Button {
            cycleType()
        } label: {
            Text(set.isDeleted ? "" : (set.type.marker ?? "\(index)"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(markerColor)
                .frame(width: 34, height: 28)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var markerColor: Color {
        guard !set.isDeleted else { return .primary }
        switch set.type {
        case .warmup: return .orange
        case .working: return .primary
        case .failure: return .red
        }
    }

    private var completeButton: some View {
        Button {
            toggleCompletion()
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isCompleted ? Color.green : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Commits

    private func commitWeight() {
        guard !set.isDeleted else { return }
        do {
            try session.commitWeight(weightText, for: set)
        } catch {
            assertionFailure("Failed to commit weight: \(error)")
        }
    }

    private func commitReps() {
        guard !set.isDeleted else { return }
        do {
            try session.commitReps(repsText, for: set)
        } catch {
            assertionFailure("Failed to commit reps: \(error)")
        }
    }

    private func toggleUnit() {
        guard !set.isDeleted else { return }
        isDirty = true
        do {
            // Commit any in-progress weight text first so the toggle applies
            // to what is on screen.
            try session.commitWeight(weightText, for: set)
            try session.toggleUnit(of: set)
        } catch {
            assertionFailure("Failed to toggle unit: \(error)")
        }
    }

    private func cycleType() {
        guard !set.isDeleted else { return }
        do {
            try session.cycleSetType(set)
        } catch {
            assertionFailure("Failed to cycle set type: \(error)")
        }
    }

    private func toggleCompletion() {
        guard !set.isDeleted else { return }
        do {
            // Completion is a commit boundary: on-screen values first.
            try session.commitWeight(weightText, for: set)
            try session.commitReps(repsText, for: set)
            try session.toggleCompletion(of: set)
        } catch {
            assertionFailure("Failed to toggle completion: \(error)")
        }
        let completed = set.completedAt != nil
        if completed {
            focusedField = nil
        }
        onCompletionChanged(completed)
    }

    /// Snapshot-keyed ticket-11 query. The label always shows the selected
    /// historical row; values are applied only while this draft remains
    /// untouched, so a delayed refresh can never clobber typing.
    private func loadPreviousAndPrefill() {
        guard !set.isDeleted else { return }
        do {
            let history = PerformanceHistory(context: modelContext)
            guard let candidate = try history.prefill(for: set) else {
                previousLabel = "—"
                return
            }
            previousLabel = candidate.displayLabel
            guard try history.applyPrefill(candidate, to: set, isDirty: isDirty) else {
                return
            }
            weightText = candidate.weightValue.map(Format.weight) ?? ""
            repsText = String(candidate.reps)
        } catch {
            assertionFailure("Failed to load previous performance: \(error)")
        }
    }

    /// Changing equipment, set type, or type-relative order selects a new
    /// candidate. A dirty row still refreshes its PREVIOUS reference label
    /// but `loadPreviousAndPrefill` refuses to overwrite its inputs.
    private var prefillTaskID: String {
        let entry = set.entry
        return [
            set.id.uuidString,
            String(set.order),
            set.type.rawValue,
            entry?.machine?.id.uuidString ?? "no-machine",
            entry?.freeWeightTag?.rawValue ?? "no-tag",
        ].joined(separator: "|")
    }
}
