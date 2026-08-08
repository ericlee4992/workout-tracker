import SwiftData
import SwiftUI

/// Snapshot-keyed layered performance: this exact equipment context can
/// prefill; same-model-at-another-gym and exercise-wide history are clearly
/// labeled reference only (D1/D11/D23).
struct PreviousPerformanceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var entry: ExerciseEntry
    @State private var layers: [PerformanceLayerResult] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(layers) { layer in
                    Section {
                        if let snapshot = layer.snapshot {
                            snapshotView(snapshot)
                        } else {
                            Text(emptyMessage(for: layer.kind))
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
            .task(id: queryIdentity) {
                loadLayers()
            }
        }
    }

    private func snapshotView(_ snapshot: PreviousPerformanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(snapshot.equipmentLabel)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(snapshot.workoutDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let gymName = snapshot.gymName {
                Text(gymName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(snapshot.sets) { set in
                HStack {
                    Text(set.type.marker ?? "\(set.order + 1)")
                        .font(.caption.weight(.semibold))
                        .frame(width: 24, alignment: .leading)
                    Text(set.displayLabel)
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func header(for kind: PerformanceLayerKind) -> some View {
        switch kind {
        case .thisEquipment:
            Label {
                Text("This equipment — \(entry.equipmentDisplayLabel)")
            } icon: {
                Image(systemName: "target").foregroundStyle(.green)
            }
        case .sameModelElsewhere:
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
    private func footer(for kind: PerformanceLayerKind) -> some View {
        switch kind {
        case .thisEquipment:
            Text("Only this exact equipment context prefills your sets.")
        case .sameModelElsewhere:
            Text("Same hardware at a different gym — shown for reference, never prefilled.")
        case .anyEquipment:
            Text("Exercise-wide history — equipment may differ, so it is reference only and never prefilled.")
        }
    }

    private func emptyMessage(for kind: PerformanceLayerKind) -> String {
        switch kind {
        case .thisEquipment:
            entry.machine == nil
                ? "No completed sets with this equipment yet."
                : "No completed sets on this machine yet."
        case .sameModelElsewhere:
            "No other gyms with this model logged yet."
        case .anyEquipment:
            "No history for this exercise yet."
        }
    }

    private var queryIdentity: String {
        [
            entry.id.uuidString,
            entry.machine?.id.uuidString ?? "no-machine",
            entry.machine?.model?.id.uuidString ?? "no-model",
            entry.freeWeightTag?.rawValue ?? "no-tag",
        ].joined(separator: "|")
    }

    private func loadLayers() {
        guard !entry.isDeleted else { return }
        do {
            layers = try PerformanceHistory(context: modelContext).layers(for: entry)
        } catch {
            assertionFailure("Failed to load performance layers: \(error)")
            layers = []
        }
    }
}
