import SwiftUI

struct PreviousPerformanceSheet: View {
    @EnvironmentObject private var store: SampleStore
    @Environment(\.dismiss) private var dismiss
    var entry: WorkoutEntry

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.performanceLayers(for: entry)) { layer in
                    Section {
                        ForEach(layer.lines, id: \.self) { line in
                            Text(line)
                                .font(.subheadline)
                        }
                    } header: {
                        header(for: layer.kind)
                    } footer: {
                        footer(for: layer.kind)
                    }
                }
            }
            .navigationTitle(entry.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func header(for kind: PerformanceLayer.Kind) -> some View {
        switch kind {
        case .thisMachine:
            Label {
                Text("This machine — \(entry.equipmentLabel)")
            } icon: {
                Image(systemName: "target").foregroundStyle(.green)
            }
        case .sameModel(let gymName):
            Label {
                Text("Same model — \(gymName)")
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
    private func footer(for kind: PerformanceLayer.Kind) -> some View {
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
