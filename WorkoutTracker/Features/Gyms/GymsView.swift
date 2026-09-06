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
                }

                AppSettingsSection()
                ExportSection()
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
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allPreferences: [AppPreferences]
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

            // Ticket 21: a 30-machine gym is only scannable grouped, and a
            // 3-machine gym does not want headers at all — hence A–Z as a
            // first-class mode, remembered between visits.
            ForEach(machineSections) { section in
                Section {
                    ForEach(section.rows) { row in
                        if let machine = machinesByID[row.id] {
                            machineRow(machine)
                        }
                    }
                } header: {
                    Text(section.title ?? "Machines")
                }
            }

            Section {
                if gym.activeMachines.isEmpty {
                    Text("No machines yet")
                        .foregroundStyle(.secondary)
                }
                Button("Add Machine…", systemImage: "plus") {
                    showingAddMachine = true
                }
                .accessibilityIdentifier("addMachine")
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
                    Menu("Group Machines By") {
                        ForEach(MachineGrouping.allCases) { mode in
                            BrowseMenuOption(
                                title: mode.label, isSelected: machineGrouping == mode
                            ) {
                                setMachineGrouping(mode)
                            }
                            .accessibilityIdentifier("machineGrouping.\(mode.rawValue)")
                        }
                    }
                    Button("Edit Gym…") { editingGym = true }
                    Button("Archive Gym", role: .destructive) {
                        archiveGym()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("gymMenu")
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
            Text("History keeps the captured name.")
        }
    }

    /// The gym's machines, grouped the way this user last asked for. Pure
    /// display state (D23) — the machines themselves are untouched.
    private var machineSections: [CatalogSection<MachineBrowseRow>] {
        let exercisesByID = Dictionary(exercises.map { ($0.id, $0) }) { first, _ in first }
        let rows = gym.activeMachines.map {
            MachineBrowseRow($0, exercisesByID: exercisesByID)
        }
        return CatalogBrowsing.machineSections(rows, by: machineGrouping)
    }

    private var machinesByID: [UUID: MachineInstance] {
        Dictionary(gym.activeMachines.map { ($0.id, $0) }) { first, _ in first }
    }

    private var machineGrouping: MachineGrouping {
        AppPreferences.canonical(of: allPreferences)?.machineBrowseGrouping ?? .alphabetical
    }

    private func setMachineGrouping(_ mode: MachineGrouping) {
        do {
            let preferences = try AppPreferences.canonical(in: modelContext)
            preferences.machineBrowseGrouping = mode
            preferences.updatedAt = .now
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save machine grouping: \(error)")
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
    @State private var defaultPresetID: UUID?
    @State private var loaded = false
    /// D3: the label this sheet filled in from a picked model. Only a label
    /// the sheet wrote itself may be overwritten by the next pick — anything
    /// typed is the user's.
    @State private var modelDerivedLabel: String?
    @State private var showingScanner = false
    /// A scan that found nothing in the catalog hands its reading here, so the
    /// New Model sheet opens prefilled with what the plate said (D35).
    @State private var scanCreatedModel: ScanDraft?

    private struct ScanDraft: Identifiable {
        let id = UUID()
        let manufacturer: String
        let modelName: String
        /// The plate as read, for the exercise proposal (ticket 06).
        let plateLines: [String]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (e.g. “Chest press by the window”)", text: $label)
                        .accessibilityIdentifier("machineLabel")
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
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan label…", systemImage: "camera.viewfinder")
                        }
                        .accessibilityIdentifier("scanMachineLabel")
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
                if let exercise = servedExercise, !(exercise.presets ?? []).isEmpty {
                    Section {
                        Picker("Usually", selection: $defaultPresetID) {
                            Text("Ask each time").tag(UUID?.none)
                            ForEach(orderedPresets(of: exercise)) { preset in
                                Text(preset.name).tag(UUID?.some(preset.id))
                            }
                        }
                        .accessibilityIdentifier("machinePresetPicker")
                    } header: {
                        Text("Preset")
                    } footer: {
                        // D38: preselected, never binding — the choice that
                        // matters is the one made at log time.
                        Text("Preselected when you log on this machine — you can switch in one tap. Records are kept separately for each preset.")
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
            .sheet(isPresented: $showingScanner) {
                ScanMachineLabelSheet(
                    // Accepting a scanned model goes through exactly the same
                    // state a hand-picked one does, so the label default (D3)
                    // has one implementation, not two.
                    onUseModel: { model = $0 },
                    onCreateNew: { manufacturer, modelName, plateLines in
                        scanCreatedModel = ScanDraft(
                            manufacturer: manufacturer, modelName: modelName, plateLines: plateLines)
                    })
            }
            .sheet(item: $scanCreatedModel) { draft in
                AddModelSheet(
                    initialManufacturer: draft.manufacturer,
                    initialModelName: draft.modelName,
                    plateLines: draft.plateLines,
                    onCreate: { model = $0 })
            }
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
        defaultPresetID = machine.defaultPresetID
    }

    /// The single exercise this machine's model serves, when there is exactly
    /// one. A cable station serving five movements has no single preset list,
    /// so it is offered none here; the choice still exists at log time, where
    /// the exercise is known.
    private var servedExercise: Exercise? {
        guard let model, model.exerciseIDs.count == 1,
              let exerciseID = model.exerciseIDs.first
        else { return nil }
        return try? modelContext.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.id == exerciseID })).first
    }

    private func orderedPresets(of exercise: Exercise) -> [ExercisePreset] {
        (exercise.presets ?? []).sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    /// D3: picking a catalog model supplies the label, so Add is immediately
    /// enabled instead of waiting for a name to be invented. Still editable,
    /// and a machine with no model still needs one typed.
    ///
    /// The label is the **movement**, not the hardware: "Leg Press", not
    /// "Insignia Series Leg Press". The machine row already prints the model's
    /// full name underneath, so naming the machine after its model said the
    /// same thing twice and left the row saying nothing about what you do on
    /// it. Multi-exercise stations (a cable crossover serving five movements)
    /// have no single answer, so those keep the model name.
    private func applyModelDefaultLabel() {
        guard let model else { return }
        guard trimmedLabel.isEmpty || trimmedLabel == modelDerivedLabel else { return }
        // The choice itself lives in `MachineLabelDefaults`; the view only
        // fetches the names and assigns the result.
        let derived = MachineLabelDefaults.label(
            modelName: model.modelName, exerciseNames: exerciseNames(of: model))
        label = derived
        modelDerivedLabel = derived
    }

    private func exerciseNames(of model: EquipmentModel) -> [String] {
        let ids = model.exerciseIDs
        guard !ids.isEmpty else { return [] }
        let matches = (try? modelContext.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { ids.contains($0.id) }))) ?? []
        return matches.map(\.name)
    }

    private func save() {
        do {
            if let machine {
                try EquipmentLifecycle(context: modelContext).update(
                    machine, label: label, defaultUnit: defaultUnit)
                machine.defaultPresetID = defaultPresetID
                try modelContext.save()
            } else {
                modelContext.insert(MachineInstance(
                    label: trimmedLabel,
                    defaultUnit: defaultUnit,
                    defaultPresetID: defaultPresetID,
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

extension View {
    /// Runs `action` whenever a store save touched the catalog (equipment
    /// models or exercises) — the invalidation signal for a cached
    /// `CatalogModelIndex`. Rebuilding on `models.count` alone left a rename,
    /// an `equipmentType` change, a link change or a muscle-group edit invisible
    /// until the view was recreated (codex-review-4); rebuilding on every body
    /// evaluation would cost a full index build per keystroke.
    func onCatalogChange(_ action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { note in
            let touched = [
                ModelContext.NotificationKey.insertedIdentifiers,
                ModelContext.NotificationKey.updatedIdentifiers,
                ModelContext.NotificationKey.deletedIdentifiers,
            ].flatMap { key -> [PersistentIdentifier] in
                note.userInfo?[key.rawValue] as? [PersistentIdentifier] ?? []
            }
            // A save whose payload cannot be read is treated as a change: a
            // missed rebuild shows stale rows, a spare one costs milliseconds.
            let unreadable = touched.isEmpty
            if unreadable || CatalogIndexInvalidation
                .touchesCatalog(entityNames: touched.map(\.entityName)) {
                action()
            }
        }
    }
}

/// Picker over the whole equipment-model catalog (seeded + user). With ~1900
/// seeded models (ticket 20) a flat A–Z list is unusable, so this is the
/// screen ticket 21 is really about: grouped (manufacturer / body area /
/// equipment type), filterable by body area and equipment type, and searched
/// across manufacturer *and* model together so "hammer incline" lands on the
/// row. Grouping and filtering are display state only (D23) — remembered in
/// AppPreferences, never written into anything logged.
struct ModelPickerView: View {
    @Binding var selection: EquipmentModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\EquipmentModel.manufacturer),
        SortDescriptor(\EquipmentModel.modelName),
    ]) private var models: [EquipmentModel]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allPreferences: [AppPreferences]
    @State private var searchText = ""
    @State private var showingAddModel = false
    /// Built once per catalog change, not per keystroke: filtering value types
    /// is fast, re-reading 1900 SwiftData rows is not.
    @State private var index = CatalogModelIndex.empty
    @State private var modelsByID: [UUID: EquipmentModel] = [:]

    private var preferences: AppPreferences? {
        AppPreferences.canonical(of: allPreferences)
    }

    private var grouping: CatalogGrouping {
        preferences?.modelBrowseGrouping ?? .manufacturer
    }

    private var filter: CatalogModelFilter {
        CatalogModelFilter(
            searchText: searchText,
            bodyArea: preferences?.modelBrowseMuscleGroup,
            equipmentType: preferences?.modelBrowseEquipmentType)
    }

    private var sections: [CatalogSection<CatalogModelRow>] {
        CatalogBrowsing.browse(index, filter: filter, grouping: grouping)
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

            if filter.hasActiveFilters {
                Section {
                    HStack {
                        Label(filterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") { clearFilters() }
                            .font(.caption.weight(.semibold))
                            .accessibilityIdentifier("clearModelFilters")
                    }
                }
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        modelButton(row)
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }

            Section {
                if sections.isEmpty {
                    Text("No models match")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("noModelsMatch")
                }
                Button("New Model…", systemImage: "plus") {
                    showingAddModel = true
                }
            } footer: {
                Text("Can't find the machine's model? Add it — your models live alongside the catalog.")
            }
        }
        .searchable(text: $searchText, prompt: "Search manufacturer or model")
        .navigationTitle("Catalog Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                browseMenu
            }
        }
        // `initial: true` is what builds the index for the first frame; the
        // count is no longer the invalidation signal — see `onCatalogChange`.
        .onChange(of: models.count, initial: true) { _, _ in rebuildIndex() }
        .onCatalogChange { rebuildIndex() }
        .sheet(isPresented: $showingAddModel) {
            AddModelSheet(onCreate: { newModel in
                selection = newModel
                dismiss()
            })
        }
    }

    private func modelButton(_ row: CatalogModelRow) -> some View {
        Button {
            select(row)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.displayName)
                    HStack(spacing: 6) {
                        // D24: a user's own model sits in the same list as the
                        // catalog's, labelled rather than segregated.
                        if !row.isSeeded {
                            Text("Custom")
                        }
                        if let type = row.equipmentType {
                            Text(type.label)
                        }
                        if !row.bodyAreas.isEmpty {
                            Text(row.bodyAreas.joined(separator: " · "))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if selection?.id == row.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("modelOption.\(row.displayName)")
    }

    /// Grouping and both filters in one menu. Deliberately plain `Button`s
    /// rather than `Picker`s: a menu button can carry its own accessibility
    /// identifier, which is what makes this screen drivable from a UI test.
    private var browseMenu: some View {
        Menu {
            Menu("Group By") {
                ForEach(CatalogGrouping.allCases) { mode in
                    BrowseMenuOption(title: mode.label, isSelected: grouping == mode) {
                        write { $0.modelBrowseGrouping = mode }
                    }
                    .accessibilityIdentifier("modelGrouping.\(mode.rawValue)")
                }
            }

            Menu("Body Area") {
                BrowseMenuOption(title: "All body areas", isSelected: filter.bodyArea == nil) {
                    write { $0.modelBrowseMuscleGroup = nil }
                }
                .accessibilityIdentifier("modelFilter.bodyArea.all")
                ForEach(index.bodyAreas, id: \.self) { area in
                    BrowseMenuOption(title: area, isSelected: filter.bodyArea == area) {
                        write { $0.modelBrowseMuscleGroup = area }
                    }
                    .accessibilityIdentifier("modelFilter.bodyArea.\(area)")
                }
            }

            Menu("Equipment Type") {
                BrowseMenuOption(
                    title: "All types", isSelected: filter.equipmentType == nil
                ) {
                    write { $0.modelBrowseEquipmentType = nil }
                }
                .accessibilityIdentifier("modelFilter.type.all")
                ForEach(index.equipmentTypes) { type in
                    BrowseMenuOption(
                        title: type.label, isSelected: filter.equipmentType == type
                    ) {
                        write { $0.modelBrowseEquipmentType = type }
                    }
                    .accessibilityIdentifier("modelFilter.type.\(type.rawValue)")
                }
            }

            if filter.hasActiveFilters {
                Button("Clear Filters", systemImage: "xmark.circle") { clearFilters() }
            }
        } label: {
            Label(
                "Browse",
                systemImage: filter.hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier("modelBrowseMenu")
    }

    private var filterSummary: String {
        [filter.bodyArea, filter.equipmentType?.label]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func clearFilters() {
        write {
            $0.modelBrowseMuscleGroup = nil
            $0.modelBrowseEquipmentType = nil
        }
    }

    private func write(_ change: (AppPreferences) -> Void) {
        do {
            let preferences = try AppPreferences.canonical(in: modelContext)
            change(preferences)
            preferences.updatedAt = .now
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save catalog browsing preference: \(error)")
        }
    }

    private func select(_ row: CatalogModelRow) {
        selection = modelsByID[row.id]
        dismiss()
    }

    private func rebuildIndex() {
        index = CatalogModelIndex.build(models: models, exercises: exercises)
        modelsByID = Dictionary(models.map { ($0.id, $0) }) { first, _ in first }
    }
}

/// Inline user-model creation (D24: user ID space, `isSeeded == false`;
/// must link at least one exercise).
struct AddModelSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Prefill from a scanned name plate (D35). Both stay editable: the scan
    /// proposes a name, the user owns it.
    var initialManufacturer: String = ""
    var initialModelName: String = ""
    /// The plate as the scanner read it (ticket 06): with a reading and Ask
    /// AI available, the Exercises section offers "Suggest with AI". Empty
    /// for a hand-entered model, and then nothing is offered.
    var plateLines: [String] = []
    var onCreate: (EquipmentModel) -> Void
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var manufacturer = ""
    @State private var modelName = ""
    @State private var equipmentType: EquipmentCategory?
    @State private var linkedExerciseIDs: Set<UUID> = []
    @State private var loadedPrefill = false
    /// Why AI ticked a row, shown under it until the user unticks it.
    @State private var proposalReasons: [UUID: String] = [:]
    @State private var proposing = false
    @State private var proposalNote: String?
    /// The proposal in flight, so Cancel, Add and the sheet going away
    /// CANCEL the paid request rather than let it land on dead state
    /// (codex-review-05b).
    @State private var proposalTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $modelName)
                    // Optional (ticket 21): a model with no type still shows
                    // up — under "Uncategorized" — rather than being hidden
                    // by a filter it cannot answer (D24).
                    Picker("Equipment type", selection: $equipmentType) {
                        Text("Not set").tag(EquipmentCategory?.none)
                        ForEach(EquipmentCategory.allCases) { type in
                            Text(type.label).tag(EquipmentCategory?.some(type))
                        }
                    }
                    .accessibilityIdentifier("newModelEquipmentType")
                }
                // Ticket 06 (D53's rules): one tap, one call, the app's own
                // exercise list in and ids from it out; the ticks stay the
                // user's to change, and nothing is saved until Add.
                if !plateLines.isEmpty, AskAI.isAvailable {
                    Section {
                        if proposing {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Asking AI…")
                            }
                            .accessibilityIdentifier("newModelSuggestStatus")
                        } else {
                            Button("Suggest exercises with AI") { suggestExercises() }
                                .accessibilityIdentifier("newModelSuggestExercises")
                        }
                    } footer: {
                        if let proposalNote {
                            Text(proposalNote)
                                .accessibilityIdentifier("newModelSuggestNote")
                        } else {
                            Text("Sends the plate's text and this exercise list to Claude, with your key; it picks from the list and you keep the final say.")
                        }
                    }
                }
                Section {
                    ForEach(exercises) { exercise in
                        Button {
                            toggle(exercise.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                    if linkedExerciseIDs.contains(exercise.id),
                                       let reason = proposalReasons[exercise.id], !reason.isEmpty {
                                        Text(reason)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .accessibilityIdentifier("newModelExerciseReason.\(exercise.name)")
                                    }
                                }
                                Spacer()
                                if linkedExerciseIDs.contains(exercise.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("newModelExercise.\(exercise.name)")
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
                    Button("Cancel") {
                        abandonProposal()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addModel() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("saveNewModel")
                }
            }
            .onAppear(perform: applyPrefill)
            .onDisappear(perform: abandonProposal)
        }
    }

    /// Once only: after this the fields are the user's, even if the view
    /// re-appears behind another sheet.
    private func applyPrefill() {
        guard !loadedPrefill else { return }
        loadedPrefill = true
        if manufacturer.isEmpty { manufacturer = initialManufacturer }
        if modelName.isEmpty { modelName = initialModelName }
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
            proposalReasons[id] = nil
        } else {
            linkedExerciseIDs.insert(id)
        }
    }

    /// Ticket 06: ask once, tick what comes back, say why. Any failure
    /// leaves the sheet exactly as it was, with a note under the button.
    private func suggestExercises() {
        guard !proposing, let proposer = AskAI.proposer else { return }
        let candidates = exercises.map {
            ExerciseCandidate(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup)
        }
        let plate = PlateDescription(
            brand: trimmedManufacturer, model: trimmedModelName, lines: plateLines)
        proposing = true
        proposalTask = Task {
            let outcome: Result<[ExerciseProposal], Error>
            do {
                outcome = .success(try await proposer.propose(plate: plate, candidates: candidates))
            } catch {
                outcome = .failure(error)
            }
            // Cancelled (Cancel, Add, dismissal): the sheet is gone or
            // done; nothing here may touch it.
            guard !Task.isCancelled else { return }
            proposalTask = nil
            proposing = false
            switch outcome {
            case .success(let proposals) where proposals.isEmpty:
                proposalNote = "AI could not tell which exercises this machine serves."
            case .success(let proposals):
                for proposal in proposals {
                    linkedExerciseIDs.insert(proposal.id)
                    proposalReasons[proposal.id] = proposal.reason
                }
                proposalNote = nil
            case .failure(let error):
                proposalNote = error.localizedDescription
            }
        }
    }

    private func abandonProposal() {
        proposalTask?.cancel()
        proposalTask = nil
        proposing = false
    }

    private func addModel() {
        abandonProposal()
        // Preserve the catalog's display order in the stored link list.
        let orderedIDs = exercises.map(\.id).filter(linkedExerciseIDs.contains)
        let model = EquipmentModel(
            manufacturer: trimmedManufacturer,
            modelName: trimmedModelName,
            exerciseIDs: orderedIDs,
            equipmentType: equipmentType,
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
