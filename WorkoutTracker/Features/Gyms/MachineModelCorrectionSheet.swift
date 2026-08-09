import SwiftData
import SwiftUI

/// D10's explicit model-correction prompt. Merely renaming a model never
/// rewrites history; changing which model a machine is attaches the selected
/// scope to the save operation.
struct MachineModelCorrectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var machine: MachineInstance
    @State private var model: EquipmentModel?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ModelPickerView(selection: $model)
                    } label: {
                        HStack {
                            Text("Correct model")
                            Spacer()
                            Text(model?.displayName ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Choose whether existing workout snapshots for this exact machine should also move to the corrected model.")
                }
                Section {
                    Button("Future Workouts Only") {
                        apply(.futureOnly)
                    }
                    Button("Apply to Past Workouts Too") {
                        apply(.applyToPast)
                    }
                }
            }
            .navigationTitle("Correct Model")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { model = machine.model }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func apply(_ scope: ModelCorrectionScope) {
        do {
            try EquipmentLifecycle(context: modelContext)
                .correctModel(of: machine, to: model, scope: scope)
            dismiss()
        } catch {
            assertionFailure("Failed to correct model: \(error)")
        }
    }
}
