import SwiftUI

struct ExerciseEntryCard: View {
    @Binding var entry: WorkoutEntry
    var showMachinePicker: () -> Void
    var showPerformance: () -> Void
    var setCompleted: (SetType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            machineRow

            if entry.exercise.loadType == .assisted {
                Label("Assisted: lower weight = harder. Records track least assistance.", systemImage: "arrow.down.right.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            columnHeaders

            ForEach($entry.sets) { $set in
                SetRow(set: $set, index: workingIndex(of: set), onComplete: {
                    setCompleted(set.type)
                })
            }

            Button {
                var newSet = LoggedSet()
                newSet.unit = entry.sets.last?.unit ?? .kg
                newSet.prevWeight = entry.sets.last?.prevWeight
                newSet.prevReps = entry.sets.last?.prevReps
                newSet.prevUnit = entry.sets.last?.prevUnit ?? .kg
                entry.sets.append(newSet)
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
    }

    private var titleRow: some View {
        HStack {
            Text(entry.exercise.name)
                .font(.headline)
            Spacer()
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
                    Text(entry.equipmentLabel)
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
        entry.exercise.loadType == .assisted ? "ASSIST" : "WEIGHT"
    }

    private func workingIndex(of set: LoggedSet) -> Int {
        var index = 0
        for s in entry.sets {
            if s.type != .warmup { index += 1 }
            if s.id == set.id { break }
        }
        return index
    }
}

struct SetRow: View {
    @Binding var set: LoggedSet
    var index: Int
    var onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            setTypeButton

            previousButton
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                TextField("–", text: $set.weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 48)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button {
                    set.unit = set.unit.toggled
                } label: {
                    UnitBadge(unit: set.unit)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 88)

            TextField("–", text: $set.repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 48)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            completeButton
                .frame(width: 30)
        }
        .font(.subheadline)
        .opacity(set.completed ? 0.75 : 1)
    }

    private var setTypeButton: some View {
        Button {
            switch set.type {
            case .working: set.type = .warmup
            case .warmup: set.type = .failure
            case .failure: set.type = .working
            }
        } label: {
            Text(set.type.marker ?? "\(index)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(markerColor)
                .frame(width: 34, height: 28)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var markerColor: Color {
        switch set.type {
        case .warmup: .orange
        case .working: .primary
        case .failure: .red
        }
    }

    private var previousButton: some View {
        Button {
            // One tap pulls same-machine previous numbers into the fields.
            if let w = set.prevWeight { set.weightText = Format.weight(w) }
            if let r = set.prevReps { set.repsText = String(r) }
            set.unit = set.prevUnit
        } label: {
            Text(set.previousLabel ?? "—")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .disabled(set.previousLabel == nil)
    }

    private var completeButton: some View {
        Button {
            set.completed.toggle()
            if set.completed { onComplete() }
        } label: {
            Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(set.completed ? Color.green : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
