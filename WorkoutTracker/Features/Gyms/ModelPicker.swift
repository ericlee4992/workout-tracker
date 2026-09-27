import SwiftData
import SwiftUI

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
///
/// Floodlight redesign ticket 06 (G06): the equipment type is a row of visible chips (each with
/// its glyph) instead of a submenu; the grouping is a compact capsule menu; New Model… sits at
/// the top, prefilled from the search; each row shows its glyph, what the model serves and a pin
/// when a machine at this gym already uses it. The native search field stays (UI tests and the
/// iOS 27 search drawer rely on it).
struct ModelPickerView: View {
    @Binding var selection: EquipmentModel?
    /// The gym the machine belongs to, for the "already here" pin (nil: no pin).
    var gym: Gym?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: [
        SortDescriptor(\EquipmentModel.manufacturer),
        SortDescriptor(\EquipmentModel.modelName),
    ]) private var models: [EquipmentModel]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allPreferences: [AppPreferences]
    @State private var searchText = ""
    @State private var newModel: NewModelDraft?
    /// Built once per catalog change, not per keystroke: filtering value types
    /// is fast, re-reading 1900 SwiftData rows is not.
    @State private var index = CatalogModelIndex.empty
    @State private var modelsByID: [UUID: EquipmentModel] = [:]
    @State private var servedByModel: [UUID: [String]] = [:]

    private struct NewModelDraft: Identifiable {
        let id = UUID()
        let manufacturer: String
        let modelName: String
    }

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

    private var searching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sections: [CatalogSection<CatalogModelRow>] {
        CatalogBrowsing.browse(index, filter: filter, grouping: grouping)
    }

    var body: some View {
        let sections = sections
        let resultCount = sections.reduce(0) { $0 + $1.rows.count }
        let here = machinesHere
        List {
            Section {
                controls(resultCount: resultCount)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        EquipmentTile(category: nil, size: 36)
                        Text("None").foregroundStyle(look.textPrimary)
                        Spacer()
                        if selection == nil {
                            Image(systemName: "checkmark")
                                .font(.system(.body, weight: .bold))
                                .foregroundStyle(look.actionText)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .lookListRows()

            if filter.hasActiveFilters {
                Section {
                    HStack {
                        Label(filterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")
                            .font(.caption)
                            .foregroundStyle(look.textSecondary)
                        Spacer()
                        Button("Clear") { clearFilters() }
                            .font(.caption.weight(.semibold))
                            .accessibilityIdentifier("clearModelFilters")
                    }
                }
                .lookListRows()
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        modelButton(row, here: here[row.id] ?? [])
                    }
                } header: {
                    if let title = section.title {
                        GymGroupHeader(title: title, family: grouping == .bodyArea ? MuscleFamily(muscleGroup: title) : nil,
                                       showsSwatch: grouping == .bodyArea, count: section.rows.count)
                            .textCase(nil)
                            .padding(.leading, -4)
                    }
                }
                .lookListRows()
            }

            if sections.isEmpty {
                Section {
                    VStack(spacing: look.space.grid) {
                        EmptyStateView(symbol: "magnifyingglass", title: "No models match")
                            .padding(.vertical, -6)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("noModelsMatch")
                        let prefill = prefillFromSearch
                        let name = "\(prefill.manufacturer) \(prefill.modelName)".trimmingCharacters(in: .whitespaces)
                        // The same way out as the pinned pill (hidden while nothing matches).
                        MakeRow(title: "New Model…", detail: name.isEmpty ? nil : name) { openNewModel() }
                            .accessibilityIdentifier("newModelFromSearch")
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .lookGroupedList()
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
        .sheet(item: $newModel) { draft in
            AddModelSheet(initialManufacturer: draft.manufacturer, initialModelName: draft.modelName,
                          onCreate: { created in
                              selection = created
                              dismiss()
                          })
        }
    }

    // MARK: Controls

    /// New Model… (prefilled from the search) · the type chips · the grouping menu and, once
    /// anything narrows the catalog, the result count. While a search is typed the results are
    /// one flat list, so the grouping menu steps aside.
    private func controls(resultCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if resultCount > 0 {
                Button { openNewModel() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(.subheadline, weight: .bold))
                        Text("New Model…")
                            .font(.system(.subheadline, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(look.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay { Capsule().strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
                    .contentShape(Capsule())
                }
                .buttonStyle(.lookPressable)
                .accessibilityIdentifier("newModelFromSearch")
            }
            typeChips
            HStack(alignment: .center, spacing: 12) {
                if !searching {
                    GroupingMenu(options: CatalogGrouping.allCases, title: \.label,
                                 identifier: { "modelGrouping.\($0.rawValue)" },
                                 selection: Binding(get: { grouping }, set: { mode in write { $0.modelBrowseGrouping = mode } }),
                                 accessibilityName: "Group By")
                }
                if (searching || filter.hasActiveFilters) && resultCount > 0 {
                    Text("\(resultCount) model\(resultCount == 1 ? "" : "s")")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// All · one chip per equipment type the catalog has; a chip toggles its filter.
    private var typeChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                TypeChip(title: "All", category: nil, isSelected: filter.equipmentType == nil) {
                    write { $0.modelBrowseEquipmentType = nil }
                }
                .accessibilityIdentifier("modelFilter.type.all")
                ForEach(index.equipmentTypes) { type in
                    TypeChip(title: type.label, category: type, isSelected: filter.equipmentType == type) {
                        write { $0.modelBrowseEquipmentType = filter.equipmentType == type ? nil : type }
                    }
                    .accessibilityIdentifier("modelFilter.type.\(type.rawValue)")
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
        .sensoryFeedback(.selection, trigger: filter.equipmentType)
    }

    /// Model · what it serves, then the gym's pin when a machine here uses it — with that
    /// machine's label only when it says something the exercise line doesn't.
    private func modelButton(_ row: CatalogModelRow, here: [String]) -> some View {
        let served = servedByModel[row.id] ?? []
        let showsMaker = searching || grouping != .manufacturer
        return Button {
            select(row)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                EquipmentTile(category: row.equipmentType, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(showsMaker ? row.displayName : row.modelName)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !served.isEmpty || !here.isEmpty {
                        servesLine(served, here: here)
                            .font(look.font.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // D24: a user's own model sits in the same list as the catalog's, labelled
                    // rather than segregated.
                    if !row.isSeeded { GymTag("Custom").padding(.top, 2) }
                }
                Spacer(minLength: 8)
                if selection?.id == row.id {
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(look.actionText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([row.displayName, row.equipmentType?.label, served.joined(separator: ", "),
                             here.isEmpty ? nil : "At this gym: \(here.joined(separator: ", "))",
                             row.isSeeded ? nil : "Custom"]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(selection?.id == row.id ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("modelOption.\(row.displayName)")
    }

    private func servesLine(_ names: [String], here: [String]) -> Text {
        let line = names.count <= 2 ? names.joined(separator: ", ")
            : "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
        let served = Text(verbatim: line).foregroundStyle(look.textSecondary)
        guard !here.isEmpty else { return served }
        let differing = here.filter { !names.contains($0) }
        let pin = Text(Image(systemName: look.gymSymbol)).foregroundStyle(look.textPrimary).fontWeight(.bold)
        let mark = differing.isEmpty ? pin
            : Text("\(pin) \(Text(verbatim: differing.joined(separator: ", ")).foregroundStyle(look.textPrimary).fontWeight(.semibold))")
        return names.isEmpty ? mark : Text("\(served)  \(mark)")
    }

    /// The body-area filter (the type is on the chips, the grouping in its capsule).
    /// Deliberately plain `Button`s rather than `Picker`s: a menu button can carry its own
    /// accessibility identifier, which is what makes this screen drivable from a UI test.
    private var browseMenu: some View {
        Menu {
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

            if filter.hasActiveFilters {
                Button("Clear Filters", systemImage: "xmark.circle") { clearFilters() }
            }
        } label: {
            Label(
                "Browse",
                systemImage: filter.bodyArea != nil
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
        }
        .tint(look.textPrimary)
        .accessibilityIdentifier("modelBrowseMenu")
    }

    // MARK: Data

    /// Labels of this gym's machines per model they use.
    private var machinesHere: [UUID: [String]] {
        guard let gym else { return [:] }
        var result: [UUID: [String]] = [:]
        for machine in gym.activeMachines {
            if let id = machine.model?.id { result[id, default: []].append(machine.label) }
        }
        return result
    }

    private var prefillFromSearch: (manufacturer: String, modelName: String) {
        let prefill = GymOverviewMath.newModelPrefill(query: searchText, manufacturers: index.manufacturers)
        return (prefill.manufacturer, prefill.model)
    }

    private func openNewModel() {
        let prefill = prefillFromSearch
        newModel = NewModelDraft(manufacturer: prefill.manufacturer, modelName: prefill.modelName)
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
        let names = Dictionary(exercises.map { ($0.id, $0.name) }) { first, _ in first }
        servedByModel = Dictionary(models.map { model in
            (model.id, model.exerciseIDs.compactMap { names[$0] })
        }) { first, _ in first }
    }
}

/// A filter chip with the equipment glyph.
struct TypeChip: View {
    var title: String
    var category: EquipmentCategory?
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 34
    @ScaledMetric(relativeTo: .subheadline) private var glyph: CGFloat = 16

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category { EquipmentGlyph(category: category, side: glyph) }
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? look.selection : look.textSecondary)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background(isSelected ? look.segmentFill : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(isSelected ? .clear : look.hairline, lineWidth: 1) }
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Inline user-model creation (D24: user ID space, `isSeeded == false`;
/// must link at least one exercise).
///
/// Floodlight redesign ticket 06 (G06 New Model): a preview of what will be made, the manufacturer
/// and model, the equipment type as glyph chips, then the exercises — the linked ones as removable
/// chips on top, "Suggest exercises with AI" (unchanged rules), a search and the checklist.
struct AddModelSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Prefill from a scanned name plate (D35) or the picker's search. Both stay editable: the
    /// prefill proposes a name, the user owns it.
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
    @State private var exerciseQuery = ""
    @State private var loadedPrefill = false
    /// Why AI ticked a row, shown under it until the user unticks it.
    @State private var proposalReasons: [UUID: String] = [:]
    @State private var proposing = false
    @State private var proposalNote: String?
    /// The proposal in flight, so Cancel, Add and the sheet going away
    /// CANCEL the paid request rather than let it land on dead state
    /// (codex-review-05b).
    @AppStorage(TerraAccess.exerciseConsentKey) private var exerciseConsent = false
    @State private var confirmSendModel = false
    @State private var proposalTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                }
                Section {
                    field("Manufacturer", text: $manufacturer)
                    field("Model", text: $modelName)
                }
                .lookListRows()
                // Optional (ticket 21): a model with no type still shows up — under
                // "Uncategorized" — rather than being hidden by a filter it cannot answer (D24).
                Section {
                    WrapLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(EquipmentCategory.allCases) { type in
                            TypeChip(title: type.label, category: type, isSelected: equipmentType == type) {
                                withAnimation(.snappy(duration: 0.2)) { equipmentType = equipmentType == type ? nil : type }
                            }
                            .accessibilityIdentifier("newModelType.\(type.rawValue)")
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("newModelEquipmentType")
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    sectionTitle("Equipment type")
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
                            Button {
                                if exerciseConsent || AskAI.fixtureIsEnabled { suggestExercises() }
                                else { confirmSendModel = true }
                            } label: {
                                Label("Suggest exercises with AI", systemImage: "sparkles")
                            }
                            .accessibilityIdentifier("newModelSuggestExercises")
                        }
                    } footer: {
                        if let proposalNote {
                            Text(proposalNote)
                                .accessibilityIdentifier("newModelSuggestNote")
                        } else {
                            Text("Sends the manufacturer and model above, the plate's text and this exercise list (names and muscle groups) to OpenAI (GPT-5.6 Terra), with your key; it picks from the list and you keep the final say.")
                        }
                    }
                    .lookListRows()
                }
                Section {
                    if !linkedExerciseIDs.isEmpty {
                        WrapLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(linkedOrder) { exercise in
                                Chip(exercise.name, symbol: "xmark", isSelected: true) {
                                    withAnimation(.snappy(duration: 0.2)) { toggle(exercise.id) }
                                }
                                .accessibilityHint("Removes it")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                    SearchFieldView(text: $exerciseQuery, prompt: "Search exercises")
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        sectionTitle("Exercises")
                        Spacer()
                        Text(linkedExerciseIDs.isEmpty ? "Link at least one." : "\(linkedExerciseIDs.count) linked")
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .textCase(nil)
                    }
                }
                Section {
                    ForEach(matchingExercises) { exercise in
                        exerciseRow(exercise)
                    }
                }
                .lookListRows()
            }
            .lookGroupedList()
            .alert("Send model details to OpenAI?", isPresented: $confirmSendModel) {
                Button("Allow and send") { exerciseConsent = true; suggestExercises() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sends the typed manufacturer/model, plate text and exercise names to OpenAI. You can revoke this in Settings. OpenAI API data policies apply.")
            }
            .onChange(of: exerciseConsent) { _, allowed in if !allowed { abandonProposal() } }
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

    // MARK: Pieces

    private var preview: some View {
        let empty = trimmedManufacturer.isEmpty && trimmedModelName.isEmpty
        return HStack(spacing: 14) {
            EquipmentTile(category: equipmentType, size: 56)
                .animation(.snappy(duration: 0.2), value: equipmentType)
            VStack(alignment: .leading, spacing: 5) {
                Text(empty ? "New Model" : "\(trimmedManufacturer) \(trimmedModelName)".trimmingCharacters(in: .whitespaces))
                    .font(look.font.cardTitle)
                    .foregroundStyle(empty ? look.textTertiary : look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    GymTag("Custom")
                    if let equipmentType { GymTag(equipmentType.label, category: .some(equipmentType)) }
                    if !linkedExerciseIDs.isEmpty {
                        GymTag("\(linkedExerciseIDs.count) exercise\(linkedExerciseIDs.count == 1 ? "" : "s")")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.tile)
        .accessibilityElement(children: .combine)
    }

    /// Label column like New Gym's Name / City; at AX the label sits above the field. The field's
    /// title stays its accessibility label ("Manufacturer", "Model").
    private func field(_ label: String, text: Binding<String>) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(label)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(look.textSecondary)
                .frame(minWidth: ax ? nil : 112, alignment: .leading)
                .accessibilityHidden(true)
            TextField(label, text: text, prompt: Text("Required").foregroundStyle(look.textTertiary))
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel(Text(label))
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(look.font.headline)
            .foregroundStyle(look.textPrimary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let on = linkedExerciseIDs.contains(exercise.id)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { toggle(exercise.id) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(.body, weight: on ? .semibold : .regular))
                        .foregroundStyle(look.textPrimary)
                    if on, let reason = proposalReasons[exercise.id], !reason.isEmpty {
                        Label(reason, systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(look.textSecondary)
                            .accessibilityIdentifier("newModelExerciseReason.\(exercise.name)")
                    } else if let group = exercise.muscleGroup {
                        Text(group).font(.caption).foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(on ? look.actionText : look.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("newModelExercise.\(exercise.name)")
    }

    private var matchingExercises: [Exercise] {
        let query = exerciseQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedStandardContains(query) }
    }

    /// The linked exercises in the catalog's order (the order they are stored in).
    private var linkedOrder: [Exercise] {
        exercises.filter { linkedExerciseIDs.contains($0.id) }
    }

    // MARK: Behaviour (unchanged)

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
        guard exerciseConsent || AskAI.fixtureIsEnabled else { return }
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
