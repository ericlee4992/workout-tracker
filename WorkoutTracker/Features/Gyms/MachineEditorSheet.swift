import SwiftData
import SwiftUI

// MARK: - Machine editor (ticket 06 add-sheet, ticket 17 edit-sheet)

// Internal (not private): the active-workout machine picker (ticket 07)
// reuses it to add a machine mid-workout.
struct MachineEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    var gym: Gym
    /// nil = create a new machine at `gym`; non-nil = edit that machine
    /// (D2, ticket 17 — its default unit was previously set-once).
    var machine: MachineInstance?
    /// Routine setup enters the same confirmed AI flow directly; ordinary editors stay unchanged.
    var startsWithScanner = false
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var recognizedIDs: Set<UUID> = []
    @State private var identified: EquipmentIdentification?
    @State private var saveFailure: String?
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
    @State private var showingOfflineScanner = false
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
                .lookListRows()
                if machine == nil {
                    Section {
                        NavigationLink {
                            ModelPickerView(selection: $model, gym: gym)
                        } label: {
                            HStack(spacing: 12) {
                                EquipmentTile(category: model?.equipmentType, size: 32)
                                Text("Catalog model")
                                Spacer()
                                Text(model?.displayName ?? "None")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .accessibilityIdentifier("catalogModel")
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan equipment…", systemImage: "camera.viewfinder")
                        }
                        .accessibilityIdentifier("scanMachineLabel")
                        Button("Read label on device") { showingOfflineScanner = true }
                            .accessibilityIdentifier("scanLabelOffline")
                    }
                    .lookListRows()
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
                    .lookListRows()
                }
                if model == nil {
                    Section("Exercises") {
                        ForEach(allExercises.filter { recognizedIDs.contains($0.id) }) { Text($0.name) }
                        NavigationLink("Choose exercises") {
                            AIExerciseSelection(exercises: allExercises, selected: $recognizedIDs)
                        }
                        if let identified, identified.identity == "specific" {
                            Text("\(identified.manufacturer) \(identified.modelName)").foregroundStyle(.secondary)
                        }
                    }
                    .lookListRows()
                }
                if let saveFailure { Text(saveFailure).foregroundStyle(look.destructive).lookListRows() }
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
                    .lookListRows()
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
                .lookListRows()
            }
            // Floodlight redesign ticket 06: the same form (the user kept it, 2026-09-27) on the
            // native Form in the look's colours, like the other kept forms.
            .lookGroupedList()
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
            .onChange(of: model?.id) { _, _ in
                if model != nil { identified = nil }
                applyModelDefaultLabel()
            }
            .sheet(isPresented: $showingScanner) {
                IdentifyEquipmentSheet { result in
                    identified = result
                    recognizedIDs = Set(result.exerciseIDs)
                    let available = (try? modelContext.fetch(FetchDescriptor<EquipmentModel>())) ?? []
                    if case .catalog(let match) = EquipmentIdentityResolution.resolve(result, among: available, exerciseNames: allExercises.filter(\.isSeeded).map(\.name)) { model = match }
                    else { model = nil }
                    if result.labelWasEdited || trimmedLabel.isEmpty || trimmedLabel == modelDerivedLabel {
                        label = result.label
                        // D3: a confirmed hand-edited name is user-owned, not a replaceable model default.
                        modelDerivedLabel = result.labelWasEdited ? nil : result.label
                    }
                }
            }
            .sheet(isPresented: $showingOfflineScanner) {
                ScanMachineLabelSheet(onUseModel: { model = $0 }, onCreateNew: { manufacturer, modelName, lines in
                    scanCreatedModel = ScanDraft(manufacturer: manufacturer, modelName: modelName, plateLines: lines)
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
        if machine == nil && startsWithScanner { showingScanner = true }
        guard let machine else { return }
        label = machine.label
        model = machine.model
        recognizedIDs = Set(machine.recognizedExerciseIDs)
        defaultUnit = machine.defaultUnit
        defaultPresetID = machine.defaultPresetID
    }

    /// The single exercise this machine's model serves, when there is exactly
    /// one. A cable station serving five movements has no single preset list,
    /// so it is offered none here; the choice still exists at log time, where
    /// the exercise is known.
    private var servedExercise: Exercise? {
        guard (model?.exerciseIDs ?? recognizedIDs.sorted { $0.uuidString < $1.uuidString }).count == 1,
              let exerciseID = (model?.exerciseIDs ?? recognizedIDs.sorted { $0.uuidString < $1.uuidString }).first
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
                machine.recognizedExerciseIDs = recognizedIDs.sorted { $0.uuidString < $1.uuidString }
                try modelContext.save()
            } else {
                if model == nil, let identified {
                    let available = try modelContext.fetch(FetchDescriptor<EquipmentModel>())
                    switch EquipmentIdentityResolution.resolve(identified, among: available, exerciseNames: allExercises.filter(\.isSeeded).map(\.name)) {
                    case .catalog(let existing): model = existing
                    case .newModel(let manufacturer, let name):
                        let custom = EquipmentModel(manufacturer: manufacturer, modelName: name,
                            exerciseIDs: recognizedIDs.sorted { $0.uuidString < $1.uuidString }, isSeeded: false)
                        modelContext.insert(custom); model = custom
                    case .generic, .ambiguous: break
                    }
                }
                let created = MachineInstance(
                    label: trimmedLabel,
                    defaultUnit: defaultUnit,
                    defaultPresetID: defaultPresetID,
                    gym: gym,
                    model: model)
                created.recognizedExerciseIDs = model?.exerciseIDs.isEmpty != false ? recognizedIDs.sorted { $0.uuidString < $1.uuidString } : []
                modelContext.insert(created)
                try modelContext.save()
            }
        } catch {
            saveFailure = error.localizedDescription
            return
        }
        dismiss()
    }
}
