import SwiftUI

// Layered previous-performance panel. The real history queries (this machine
// → same model elsewhere → any equipment, D1) land with ticket 11; until then
// the sheet shows the layer scaffold with honest empty states on the real
// entry's equipment context.
struct PreviousPerformanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    var entry: ExerciseEntry

    private enum LayerKind {
        case thisMachine
        case sameModel
        case anyEquipment
    }

    private var layers: [(kind: LayerKind, lines: [String])] {
        guard !entry.isDeleted else { return [] }
        if entry.machine != nil {
            return [
                (.thisMachine, ["No completed sets on this machine yet."]),
                (.sameModel, ["No other gyms with this model logged yet."]),
                (.anyEquipment, ["No history for this exercise yet."]),
            ]
        }
        return [
            (.thisMachine, ["No completed sets with this equipment yet."]),
            (.anyEquipment, ["No history for this exercise yet."]),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                    Section {
                        ForEach(layer.lines, id: \.self) { line in
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        header(for: layer.kind)
                    } footer: {
                        footer(for: layer.kind)
                    }
                }
            }
            .navigationTitle(entry.isDeleted ? "" : (entry.exercise?.name ?? entry.snapshotExerciseName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func header(for kind: LayerKind) -> some View {
        switch kind {
        case .thisMachine:
            Label {
                Text("This machine — \(entry.equipmentDisplayLabel)")
            } icon: {
                Image(systemName: "target").foregroundStyle(.green)
            }
        case .sameModel:
            Label {
                Text("Same model elsewhere")
            } icon: {
                Image(systemName: "gearshape.2").foregroundStyle(.orange)
            }
        case .anyEquipment:
            Label {
                Text("Any equipment")
            } icon: {
                Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func footer(for kind: LayerKind) -> some View {
        switch kind {
        case .thisMachine:
            Text("Only this machine's history prefills your sets.")
        case .sameModel:
            Text("Same hardware at a different gym — shown for reference.")
        case .anyEquipment:
            Text("Different machines — weights are not comparable.")
        }
    }
}
