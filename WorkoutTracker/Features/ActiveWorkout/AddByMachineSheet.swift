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
    /// Deleting a machine mid-workout (2026-09-10): the same swipe, menu and
    /// dialog as the Gyms tab, archival underneath (D10). An entry already
    /// logged on it this workout keeps its snapshot.
    @State private var deletingMachine: MachineInstance?

    /// Push target after picking a machine whose exercise isn't determined:
    /// `linked` restricts the list to the model's exercises; nil means
    /// model-less → full catalog.
    struct ExerciseChoice: Hashable {
        var machine: MachineInstance
        var linked: [Exercise]?
    }

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    private var gym: Gym? { workout.gym }

    private var machines: [MachineInstance] { gym?.activeMachines ?? [] }

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
                        .accessibilityIdentifier("machineOption.\(machine.label)")
                        .machineDeleteActions(machine) { deletingMachine = $0 }
                        .contextMenu {
                            DeleteMachineMenuItem(machine: machine) { deletingMachine = $0 }
                        }
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
                }
            }
            .navigationTitle("Add by Machine")
            .navigationBarTitleDisplayMode(.inline)
            .deleteMachineConfirmation($deletingMachine) { machine in
                do { try EquipmentLifecycle(context: modelContext).archive(machine) }
                catch { assertionFailure("Failed to delete machine: \(error)") }
            }
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
                    MachineEditorSheet(gym: gym)
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
    /// Non-nil while the inline creation form is up (ticket 19).
    @State private var creating: NewExerciseRequest?

    private var exercises: [Exercise] {
        let base = choice.linked ?? allExercises
        let tokens = CatalogBrowsing.tokens(searchText)
        guard choice.linked == nil, !tokens.isEmpty else { return base }
        return base.filter {
            CatalogBrowsing.matches(CatalogBrowsing.normalize($0.name), tokens: tokens)
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ticket 19: an exercise invented at a station is linked to that
    /// station's model, so the movement is offered here next time. A
    /// model-less machine has nothing to link to — plain creation then.
    private var model: EquipmentModel? { choice.machine.model }

    var body: some View {
        List {
            Section {
                ForEach(exercises) { exercise in
                    Button {
                        select(exercise)
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("exerciseOption.\(exercise.name)")
                }
                if exercises.isEmpty, !trimmedSearch.isEmpty {
                    Button {
                        creating = request(named: trimmedSearch)
                    } label: {
                        Label("Create “\(trimmedSearch)”", systemImage: "plus")
                    }
                    .accessibilityIdentifier("createExerciseFromSearch")
                }
            }
            Section {
                Button("New Exercise…", systemImage: "plus") {
                    creating = request(named: trimmedSearch)
                }
                .accessibilityIdentifier("newExercise")
            }
        }
        .modifier(FullCatalogSearch(enabled: choice.linked == nil, text: $searchText))
        .navigationTitle(choice.linked == nil ? "Pick Exercise" : choice.machine.label)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $creating) { request in
            NewExerciseSheet(initialName: request.name, linkTo: request.linkTo) { exercise in
                select(exercise)
            }
        }
    }

    private func request(named name: String) -> NewExerciseRequest {
        NewExerciseRequest(name: name, linkTo: model)
    }

    private func select(_ exercise: Exercise) {
        creating = nil
        onSelect(exercise)
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
