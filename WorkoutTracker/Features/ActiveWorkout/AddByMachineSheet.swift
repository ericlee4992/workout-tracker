import SwiftData
import SwiftUI

/// Machine-first logging (D7): pick a machine at the workout's gym, and the
/// entry's exercise fills itself in. A single-exercise model auto-fills with
/// zero extra prompts; a multi-exercise station pushes a chooser restricted
/// to that model's linked exercises; a model-less machine pushes the full
/// exercise picker (per ticket 06). The created entry always carries the
/// machine. Only offered for workouts at a gym — there are no machines to
/// list otherwise.
struct AddByMachineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var workout: Workout
    @State private var chooser: ExerciseChoice?
    @State private var showingAddMachine = false

    /// Push target after picking a machine whose exercise isn't determined:
    /// `linked` restricts the list to the model's exercises; nil means
    /// model-less → full catalog.
    struct ExerciseChoice: Hashable {
        var machine: MachineInstance
        var linked: [Exercise]?
    }

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    private var gym: Gym? { workout.gym }

    private var machines: [MachineInstance] {
        (gym?.machines ?? [])
            .filter { !$0.archived }
            .sorted { $0.label < $1.label }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(machines) { machine in
                        Button {
                            select(machine: machine)
                        } label: {
                            machineRow(machine)
                        }
                        .buttonStyle(.plain)
                    }
                    if machines.isEmpty {
                        Text("No machines yet")
                            .foregroundStyle(.secondary)
                    }
                    Button("Add Machine…", systemImage: "plus") {
                        showingAddMachine = true
                    }
                } header: {
                    if let gym {
                        Text("Machines at \(gym.name)")
                    }
                } footer: {
                    Text("Pick the machine and the exercise fills itself in — stations that serve several exercises ask which one.")
                }
            }
            .navigationTitle("Add by Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $chooser) { choice in
                MachineExerciseList(choice: choice) { exercise in
                    add(exercise: exercise, machine: choice.machine)
                }
            }
            .sheet(isPresented: $showingAddMachine) {
                if let gym {
                    AddMachineSheet(gym: gym)
                }
            }
        }
    }

    private func machineRow(_ machine: MachineInstance) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.label)
                    .font(.body.weight(.medium))
                Text(machine.model?.displayName ?? "No model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let unit = machine.defaultUnit {
                UnitBadge(unit: unit)
            }
        }
    }

    /// D7 branch point: one linked exercise → auto-fill, several → restricted
    /// chooser, none (model-less) → full exercise picker.
    private func select(machine: MachineInstance) {
        let linked = (try? session.exercisesFor(machine: machine)) ?? []
        if linked.count == 1 {
            add(exercise: linked[0], machine: machine)
        } else {
            chooser = ExerciseChoice(
                machine: machine, linked: linked.isEmpty ? nil : linked)
        }
    }

    private func add(exercise: Exercise, machine: MachineInstance) {
        do {
            try session.addEntry(machine: machine, exercise: exercise, to: workout)
        } catch {
            assertionFailure("Failed to add entry by machine: \(error)")
        }
        dismiss()
    }
}

/// Second step of the machine-first path: the exercise list for a picked
/// machine — restricted to the model's linked exercises, or the full
/// searchable catalog when the machine has no model.
private struct MachineExerciseList: View {
    var choice: AddByMachineSheet.ExerciseChoice
    var onSelect: (Exercise) -> Void
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var searchText = ""

    private var exercises: [Exercise] {
        let base = choice.linked ?? allExercises
        guard choice.linked == nil, !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(exercises) { exercise in
            Button {
                onSelect(exercise)
            } label: {
                ExerciseRow(exercise: exercise)
            }
            .buttonStyle(.plain)
        }
        .modifier(FullCatalogSearch(enabled: choice.linked == nil, text: $searchText))
        .navigationTitle(choice.linked == nil ? "Pick Exercise" : choice.machine.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Search only makes sense on the full catalog — a station's short linked
/// list is scanned at a glance.
private struct FullCatalogSearch: ViewModifier {
    var enabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if enabled {
            content.searchable(text: $text, prompt: "Search exercises")
        } else {
            content
        }
    }
}
