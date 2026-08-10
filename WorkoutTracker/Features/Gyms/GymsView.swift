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
                        .accessibilityIdentifier("gymRow.\(gym.name)")
                    }
                    Button("Add Gym…", systemImage: "plus") {
                        showingAddGym = true
                    }
                    .accessibilityIdentifier("addGym")
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
                GymEditorSheet()
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
    @State private var editingGym = false
    @State private var editingMachine: MachineInstance?
    @State private var correctingMachine: MachineInstance?
    @State private var renamingModel: EquipmentModel?
    @State private var modelManufacturer = ""
    @State private var modelName = ""

    var body: some View {
        List {
            // D2 (ticket 17): these used to be a dead end — read-only rows
            // with only Rename/Archive in the menu, so a wrong unit meant
            // archive-and-recreate. Editing is now one tap from where the
            // wrong value is displayed.
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
                Button("Edit Gym…", systemImage: "pencil") {
                    editingGym = true
                }
                .accessibilityIdentifier("editGym")
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
                        // D2: label *and* default unit, not rename alone.
                        Button("Edit Machine…") {
                            editingMachine = machine
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
                .accessibilityIdentifier("addMachine")
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
                    Button("Edit Gym…") { editingGym = true }
                    Button("Archive Gym", role: .destructive) {
                        archiveGym()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddMachine) {
            MachineEditorSheet(gym: gym)
        }
        .sheet(isPresented: $editingGym) {
            GymEditorSheet(gym: gym)
        }
        .sheet(item: $editingMachine) { machine in
            MachineEditorSheet(gym: gym, machine: machine)
        }
        .sheet(item: $correctingMachine) { machine in
            MachineModelCorrectionSheet(machine: machine)
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

/// Ticket 06's add-gym form, doubling as the edit form (D2, ticket 17): the
/// fields a gym is created with are exactly the fields it can be corrected
/// with, so there is one place to learn and one place to maintain.
private struct GymEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// nil = create a new gym; non-nil = edit that gym in place.
    var gym: Gym?
    @State private var name = ""
    @State private var city = ""
    @State private var defaultUnit: WeightUnit?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("gymName")
                    TextField("City (optional)", text: $city)
                } footer: {
                    if gym != nil {
                        Text("Existing workout history keeps the name captured when each workout was logged.")
                    }
                }
                Section {
                    Picker("Default unit", selection: $defaultUnit) {
                        Text("App preference").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue).tag(WeightUnit?.some(unit))
                        }
                    }
                    .accessibilityIdentifier("gymUnitPicker")
                } footer: {
                    Text(gym == nil
                        ? "Leave on App preference to fall through to your app-wide unit."
                        : "Changing this affects future sets only — sets already logged keep the unit you entered them in.")
                }
            }
            .navigationTitle(gym == nil ? "New Gym" : "Edit Gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(gym == nil ? "Add" : "Save") { save() }
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier("saveGym")
                }
            }
            .onAppear(perform: load)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let gym else { return }
        name = gym.name
        city = gym.city ?? ""
        defaultUnit = gym.defaultUnit
    }

    private func save() {
        do {
            if let gym {
                try EquipmentLifecycle(context: modelContext).update(
                    gym, name: name, city: city, defaultUnit: defaultUnit)
            } else {
                let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
                modelContext.insert(Gym(
                    name: trimmedName,
                    city: trimmedCity.isEmpty ? nil : trimmedCity,
                    defaultUnit: defaultUnit))
                try modelContext.save()
            }
        } catch {
            assertionFailure("Failed to save gym: \(error)")
        }
        dismiss()
    }
}

// MARK: - Machine editor (ticket 06 add-sheet, ticket 17 edit-sheet)

// Internal (not private): the active-workout machine picker (ticket 07)
// reuses it to add a machine mid-workout.
struct MachineEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var gym: Gym
    /// nil = create a new machine at `gym`; non-nil = edit that machine
    /// (D2, ticket 17 — its default unit was previously set-once).
    var machine: MachineInstance?
    @State private var label = ""
    @State private var model: EquipmentModel?
    @State private var defaultUnit: WeightUnit?
    @State private var loaded = false
    /// D3: the label this sheet filled in from a picked model. Only a label
    /// the sheet wrote itself may be overwritten by the next pick — anything
    /// typed is the user's.
    @State private var modelDerivedLabel: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (e.g. “Chest press by the window”)", text: $label)
                        .accessibilityIdentifier("machineLabel")
                } footer: {
                    Text("How you'll recognize this machine at \(gym.name).")
                }
                if machine == nil {
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
                        .accessibilityIdentifier("catalogModel")
                    } footer: {
                        Text("Optional — picking one names the machine for you. Without a model, logging on this machine opens the full exercise picker.")
                    }
                } else {
                    Section {
                        HStack {
                            Text("Catalog model")
                            Spacer()
                            Text(machine?.model?.displayName ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        // Changing an existing machine's model has past-vs-
                        // future consequences (D10), so it keeps its own flow.
                        Text("Use “Correct Model…” on the machine to change this — it asks whether to apply the correction to past workouts.")
                    }
                }
                Section {
                    Picker("Default unit", selection: $defaultUnit) {
                        Text("Gym default").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue).tag(WeightUnit?.some(unit))
                        }
                    }
                    .accessibilityIdentifier("machineUnitPicker")
                } footer: {
                    Text("Leave on Gym default to fall through to the gym's unit (then the app preference).")
                }
            }
            .navigationTitle(machine == nil ? "New Machine" : "Edit Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(machine == nil ? "Add" : "Save") { save() }
                        .disabled(trimmedLabel.isEmpty)
                        .accessibilityIdentifier("saveMachine")
                }
            }
            .onAppear(perform: load)
            .onChange(of: model?.id) { _, _ in applyModelDefaultLabel() }
        }
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let machine else { return }
        label = machine.label
        model = machine.model
        defaultUnit = machine.defaultUnit
    }

    /// D3: picking a catalog model supplies the label, so Add is immediately
    /// enabled instead of waiting for a name to be invented. Still editable,
    /// and a machine with no model still needs one typed.
    private func applyModelDefaultLabel() {
        guard let model else { return }
        guard trimmedLabel.isEmpty || trimmedLabel == modelDerivedLabel else { return }
        label = model.modelName
        modelDerivedLabel = model.modelName
    }

    private func save() {
        do {
            if let machine {
                try EquipmentLifecycle(context: modelContext).update(
                    machine, label: label, defaultUnit: defaultUnit)
            } else {
                modelContext.insert(MachineInstance(
                    label: trimmedLabel,
                    defaultUnit: defaultUnit,
                    gym: gym,
                    model: model))
                try modelContext.save()
            }
        } catch {
            assertionFailure("Failed to save machine: \(error)")
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
                    .accessibilityIdentifier("modelOption.\(model.displayName)")
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
