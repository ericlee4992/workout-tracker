import SwiftData
import SwiftUI

struct GymsView: View {
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name)
    private var gyms: [Gym]
    @State private var showingAddGym = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(gyms) { gym in
                        NavigationLink(value: gym.id) {
                            GymRow(gym: gym)
                        }
                    }
                    Button("Add Gym…", systemImage: "plus") {
                        showingAddGym = true
                    }
                } footer: {
                    Text("A gym's unit is the default for sets logged there — machines can override it, and so can you on any set.")
                }

                AppSettingsSection()
            }
            .navigationTitle("Gyms")
            .navigationDestination(for: UUID.self) { gymID in
                if let gym = gyms.first(where: { $0.id == gymID }) {
                    GymDetailView(gym: gym)
                }
            }
            .sheet(isPresented: $showingAddGym) {
                AddGymSheet()
            }
        }
    }
}

private struct GymRow: View {
    var gym: Gym

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(gym.name)
                    .font(.headline)
                if let city = gym.city {
                    Text(city)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let unit = gym.defaultUnit {
                UnitBadge(unit: unit)
            } else {
                Text("app default")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GymDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var gym: Gym
    @State private var showingAddMachine = false
    @State private var renamingGym = false
    @State private var gymName = ""
    @State private var renamingMachine: MachineInstance?
    @State private var machineLabel = ""
    @State private var correctingMachine: MachineInstance?
    @State private var renamingModel: EquipmentModel?
    @State private var modelManufacturer = ""
    @State private var modelName = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Default unit")
                    Spacer()
                    if let unit = gym.defaultUnit {
                        UnitBadge(unit: unit)
                    } else {
                        Text("App preference")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("City")
                    Spacer()
                    Text(gym.city ?? "—").foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(gym.activeMachines) { machine in
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
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button("Rename Machine…") {
                            machineLabel = machine.label
                            renamingMachine = machine
                        }
                        Button("Correct Model…") {
                            correctingMachine = machine
                        }
                        if let model = machine.model, !model.isSeeded {
                            Button("Rename Model…") {
                                modelManufacturer = model.manufacturer
                                modelName = model.modelName
                                renamingModel = model
                            }
                        }
                        Button("Archive Machine", role: .destructive) {
                            archive(machine)
                        }
                    }
                }
                if gym.activeMachines.isEmpty {
                    Text("No machines yet")
                        .foregroundStyle(.secondary)
                }
                Button("Add Machine…", systemImage: "plus") {
                    showingAddMachine = true
                }
            } header: {
                Text("Machines")
            } footer: {
                // Model-less machines are allowed: when logging machine-first
                // they open the full exercise picker instead of auto-filling.
                Text("The model is optional — a machine without one asks for the exercise when you log with it.")
            }
        }
        .navigationTitle(gym.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename Gym…") {
                        gymName = gym.name
                        renamingGym = true
                    }
                    Button("Archive Gym", role: .destructive) {
                        archiveGym()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddMachine) {
            AddMachineSheet(gym: gym)
        }
        .sheet(item: $correctingMachine) { machine in
            MachineModelCorrectionSheet(machine: machine)
        }
        .alert("Rename Gym", isPresented: $renamingGym) {
            TextField("Name", text: $gymName)
            Button("Save") { renameGym() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Existing workout history keeps the name captured when each workout was logged.")
        }
        .alert(
            "Rename Machine",
            isPresented: Binding(
                get: { renamingMachine != nil },
                set: { if !$0 { renamingMachine = nil } }
            ),
            presenting: renamingMachine
        ) { machine in
            TextField("Label", text: $machineLabel)
            Button("Save") { rename(machine) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Existing history keeps the machine label captured at log time.")
        }
        .alert(
            "Rename Model",
            isPresented: Binding(
                get: { renamingModel != nil },
                set: { if !$0 { renamingModel = nil } }
            ),
            presenting: renamingModel
        ) { model in
            TextField("Manufacturer", text: $modelManufacturer)
            TextField("Model", text: $modelName)
            Button("Save") { rename(model) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Only custom models can be renamed. Existing history keeps its captured model name.")
        }
    }

    private var lifecycle: EquipmentLifecycle {
        EquipmentLifecycle(context: modelContext)
    }

    private func renameGym() {
        do { try lifecycle.rename(gym, to: gymName) }
        catch { assertionFailure("Failed to rename gym: \(error)") }
    }

    private func rename(_ machine: MachineInstance) {
        do { try lifecycle.rename(machine, to: machineLabel) }
        catch { assertionFailure("Failed to rename machine: \(error)") }
    }

    private func rename(_ model: EquipmentModel) {
        do {
            try lifecycle.rename(
                model, manufacturer: modelManufacturer, modelName: modelName)
        } catch {
            assertionFailure("Failed to rename model: \(error)")
        }
    }

    private func archive(_ machine: MachineInstance) {
        do { try lifecycle.archive(machine) }
        catch { assertionFailure("Failed to archive machine: \(error)") }
    }

    private func archiveGym() {
        do {
            try lifecycle.archive(gym)
            dismiss()
        } catch {
            assertionFailure("Failed to archive gym: \(error)")
        }
    }
}

private struct AddGymSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var defaultUnit: WeightUnit?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("City (optional)", text: $city)
                }
                Section {
                    Picker("Default unit", selection: $defaultUnit) {
                        Text("App preference").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue).tag(WeightUnit?.some(unit))
                        }
                    }
                } footer: {
                    Text("Leave on App preference to fall through to your app-wide unit.")
                }
            }
            .navigationTitle("New Gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addGym() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addGym() {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(Gym(
            name: trimmedName,
            city: trimmedCity.isEmpty ? nil : trimmedCity,
            defaultUnit: defaultUnit))
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save new gym: \(error)")
        }
        dismiss()
    }
}

// MARK: - Add Machine (ticket 06)

// Internal (not private): the active-workout machine picker (ticket 07)
// reuses it to add a machine mid-workout.
struct AddMachineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var gym: Gym
    @State private var label = ""
    @State private var model: EquipmentModel?
    @State private var defaultUnit: WeightUnit?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (e.g. “Chest press by the window”)", text: $label)
                } footer: {
                    Text("How you'll recognize this machine at \(gym.name).")
                }
                Section {
                    NavigationLink {
                        ModelPickerView(selection: $model)
                    } label: {
                        HStack {
                            Text("Catalog model")
                            Spacer()
                            Text(model?.displayName ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Optional. Without a model, logging on this machine opens the full exercise picker.")
                }
                Section {
                    Picker("Default unit", selection: $defaultUnit) {
                        Text("Gym default").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue).tag(WeightUnit?.some(unit))
                        }
                    }
                } footer: {
                    Text("Leave on Gym default to fall through to the gym's unit (then the app preference).")
                }
            }
            .navigationTitle("New Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addMachine() }
                        .disabled(trimmedLabel.isEmpty)
                }
            }
        }
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addMachine() {
        modelContext.insert(MachineInstance(
            label: trimmedLabel,
            defaultUnit: defaultUnit,
            gym: gym,
            model: model))
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save new machine: \(error)")
        }
        dismiss()
    }
}

/// Searchable picker over the whole equipment-model catalog (seeded + user),
/// with "None" for model-less machines and inline user-model creation for
/// models the catalog lacks.
struct ModelPickerView: View {
    @Binding var selection: EquipmentModel?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [
        SortDescriptor(\EquipmentModel.manufacturer),
        SortDescriptor(\EquipmentModel.modelName),
    ]) private var models: [EquipmentModel]
    @State private var searchText = ""
    @State private var showingAddModel = false

    private var filtered: [EquipmentModel] {
        guard !searchText.isEmpty else { return models }
        return models.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                        Spacer()
                        if selection == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Section {
                ForEach(filtered) { model in
                    Button {
                        selection = model
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                if !model.isSeeded {
                                    Text("Custom")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selection?.id == model.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Button("New Model…", systemImage: "plus") {
                    showingAddModel = true
                }
            } footer: {
                Text("Can't find the machine's model? Add it — your models live alongside the catalog.")
            }
        }
        .searchable(text: $searchText, prompt: "Search models")
        .navigationTitle("Catalog Model")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddModel) {
            AddModelSheet { newModel in
                selection = newModel
                dismiss()
            }
        }
    }
}

/// Inline user-model creation (D24: user ID space, `isSeeded == false`;
/// must link at least one exercise).
private struct AddModelSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onCreate: (EquipmentModel) -> Void
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var manufacturer = ""
    @State private var modelName = ""
    @State private var linkedExerciseIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $modelName)
                }
                Section {
                    ForEach(exercises) { exercise in
                        Button {
                            toggle(exercise.id)
                        } label: {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                if linkedExerciseIDs.contains(exercise.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("Link at least one exercise this model serves — multi-exercise stations can link several.")
                }
            }
            .navigationTitle("New Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addModel() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var trimmedManufacturer: String {
        manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedModelName: String {
        modelName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedManufacturer.isEmpty && !trimmedModelName.isEmpty
            && !linkedExerciseIDs.isEmpty
    }

    private func toggle(_ id: UUID) {
        if linkedExerciseIDs.contains(id) {
            linkedExerciseIDs.remove(id)
        } else {
            linkedExerciseIDs.insert(id)
        }
    }

    private func addModel() {
        // Preserve the catalog's display order in the stored link list.
        let orderedIDs = exercises.map(\.id).filter(linkedExerciseIDs.contains)
        let model = EquipmentModel(
            manufacturer: trimmedManufacturer,
            modelName: trimmedModelName,
            exerciseIDs: orderedIDs,
            isSeeded: false)
        modelContext.insert(model)
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save new model: \(error)")
        }
        onCreate(model)
        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    container.mainContext.insert(Gym(name: "Gangnam Fitness", city: "Seoul", defaultUnit: .kg))
    container.mainContext.insert(Gym(name: "Hotel Gym"))
    return GymsView()
        .modelContainer(container)
}
