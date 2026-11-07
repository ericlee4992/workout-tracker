import SwiftUI

// G06 Catalog Model picker. Search the catalog, filter by equipment type with visible chips
// (each type has its own glyph), group by manufacturer / body area / A–Z from one compact menu;
// while a search is typed the results are one flat list. Rows show the model, what it serves
// and — with the gym's pin — that a machine here already uses it (its label only when it says
// something the exercise line doesn't). Picking a model adds the machine (label = the
// movement, D3) — or, for an existing machine, asks how far the correction goes (D10). The two
// ways out when the machine isn't listed — New Model… (the in-sheet form, prefilled from the
// search) and Scan Machine — are pinned under the search field, and become the result itself
// when a search matches nothing.
//
// Capture variants (G06): "search" ("hack squat"), "nomatch" ("belt squat"), "type"
// (Plate-loaded), "body" / "az" (groupings), "correct" (correcting Chest Press 2: the Current
// group), "correctalert" (its scope question), "new" (New Model, prefilled), "newblank",
// "consent" (the OpenAI consent alert), "suggested" (AI-linked exercises with reasons), "p2", "p3".

struct ModelPickerSheet: View {
    let machineID: UUID?

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsNewModel = false
    @State private var newModelPrefill = (manufacturer: "", model: "")
    /// A model just made in the New Model form while correcting a machine: the browser asks
    /// its correction scope as if it had been picked.
    @State private var autoPick: EquipmentModel?
    @State private var query = ""
    @State private var category: EquipmentCategory?
    @State private var grouping = 0
    @State private var captureMachineID: UUID?
    @State private var formVariant: String?
    @State private var alertVariant = false
    @State private var appeared = false

    private var shownMachineID: UUID? { captureMachineID ?? machineID }

    private var gymID: UUID? {
        if let machine = store.machine(shownMachineID) { return machine.gymID }
        return GymsPickerContext.gymID ?? store.screenTarget.gymID ?? store.selectedGymID
    }

    var body: some View {
        ZStack {
            if showsNewModel {
                GymsNewModelForm(manufacturer: newModelPrefill.manufacturer, modelName: newModelPrefill.model,
                                 captureVariant: formVariant,
                                 onCancel: { setNewModel(false) },
                                 onAdd: { model in
                                     if shownMachineID == nil {
                                         if let gymID {
                                             store.addMachine(gymID: gymID, label: store.gymsDefaultLabel(for: model), modelID: model.id)
                                         }
                                         router.dismissSheet()
                                     } else {
                                         autoPick = model
                                         setNewModel(false)
                                     }
                                 })
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            } else {
                GymsModelBrowser(machineID: shownMachineID, gymID: gymID, query: $query, category: $category,
                                 grouping: $grouping, autoPick: $autoPick, showsCorrectionAlert: $alertVariant,
                                 onNewModel: { query in
                                     newModelPrefill = store.gymsNewModelPrefill(query)
                                     formVariant = nil
                                     setNewModel(true)
                                 })
                .transition(reduceMotion ? .opacity : .move(edge: .leading))
            }
        }
        .lookSheetGround()
        .presentationBackground(look.groundSheet)
        .presentationDragIndicator(.visible)
        .gymsSheetTypeOverride(router.dynamicTypeOverride)
        .onAppear(perform: appear)
    }

    private func setNewModel(_ on: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.9)) { showsNewModel = on }
    }

    private func appear() {
        guard !appeared else { return }
        appeared = true
        guard machineID == store.screenTarget.machineID,
              let variant = GymsCapture.take(.g06, store: store, router: router) else { return }
        switch variant {
        case "search": query = "hack squat"
        case "nomatch": query = "belt squat"
        case "type": category = .plateLoaded
        case "body": grouping = 1
        case "az": grouping = 2
        case "correct", "correctalert":
            captureMachineID = GymsCapture.machine("Chest Press 2")
            alertVariant = variant == "correctalert"
        case "new", "consent", "suggested":
            newModelPrefill = ("Rogue", "Monster Hack Squat")
            formVariant = variant
            showsNewModel = true
        case "newblank":
            showsNewModel = true
        default: break
        }
    }
}

// MARK: - Browser

private struct GymsModelBrowser: View {
    var machineID: UUID?
    var gymID: UUID?
    @Binding var query: String
    @Binding var category: EquipmentCategory?
    @Binding var grouping: Int
    @Binding var autoPick: EquipmentModel?
    @Binding var showsCorrectionAlert: Bool
    var onNewModel: (String) -> Void

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var pendingCorrection: EquipmentModel?
    @State private var scroll = ScrollPosition(edge: .top)

    private static let groupings = ["Manufacturer", "Body area", "A–Z"]
    private var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        let results = store.searchModels(query: query, category: category)
        let machine = store.machine(machineID)
        VStack(spacing: 0) {
            GymsSheetHeader(title: "Catalog Model", cancel: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.group + 6) {
                    SearchFieldView(text: $query, prompt: "Search \(Format.grouped(SampleData.catalogModelCount)) models")
                    if !results.isEmpty { makePair }
                    categoryChips
                    resultsBar(results.count)
                    if let machine, let current = store.model(machine.modelID), !searching, category == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            GymsGroupHeader(title: "Current", showsSwatch: false, count: nil)
                            LookList(separatorInset: 64) {
                                // Picking the current model changes nothing: it just closes.
                                GymsModelRow(model: current, showsManufacturer: true, isCurrent: true, gymID: gymID) { dismiss() }
                            }
                        }
                    }
                    if results.isEmpty {
                        noMatch
                    } else {
                        sections(results)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 32)
                .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: searching)
            }
            .scrollPosition($scroll)
            .gymsCapturePaging(GymsCapture.variant(.g06, store: store, router: router), position: $scroll)
            .scrollDismissesKeyboard(.immediately)
        }
        .onAppear {
            if showsCorrectionAlert {
                showsCorrectionAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    pendingCorrection = store.model(SampleData.modelID("Life Fitness Signature Series Chest Press"))
                }
            }
            guard let model = autoPick else { return }
            autoPick = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pick(model) }
        }
        .alert("Correct Model", isPresented: correctionShown, presenting: pendingCorrection) { model in
            ForEach(CorrectionScope.allCases) { scope in
                Button(scope.title) { correct(to: model, scope: scope) }
            }
            Button("Cancel", role: .cancel) { pendingCorrection = nil }
        } message: { model in
            Text(correctionMessage(model))
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                // AX: the grouping menu leads the chip row (its own line pushed the first
                // model below the fold).
                if typeSize.isAccessibilitySize && !searching {
                    GymsGroupingMenu(titles: Self.groupings, selection: $grouping, accessibilityName: "Group By")
                }
                GymsCategoryChip(title: "All", category: nil, showsGlyph: false, isSelected: category == nil) { category = nil }
                ForEach(EquipmentCategory.allCases) { option in
                    GymsCategoryChip(title: option.label, category: option, showsGlyph: true, isSelected: category == option) {
                        category = category == option ? nil : option
                    }
                }
            }
            .padding(.horizontal, look.space.margin)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -look.space.margin)
        .sensoryFeedback(.selection, trigger: category)
    }

    /// One line: the grouping menu (hidden while a search is typed: results are one flat list),
    /// and the result count once anything narrows the catalog.
    @ViewBuilder
    private func resultsBar(_ count: Int) -> some View {
        // No match: the empty state says so (a "0 models" count would repeat it).
        let narrowed = (searching || category != nil) && count > 0
        let showsMenu = !searching && !typeSize.isAccessibilitySize
        if showsMenu || narrowed {
            HStack(alignment: .center, spacing: 12) {
                if showsMenu {
                    GymsGroupingMenu(titles: Self.groupings, selection: $grouping, accessibilityName: "Group By")
                }
                if narrowed {
                    Text(Format.count(count, "model"))
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .contentTransition(.numericText())
                        .padding(.leading, searching ? 4 : 0)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func sections(_ results: [EquipmentModel]) -> some View {
        let currentID = store.machine(machineID)?.modelID
        if searching {
            LookList(separatorInset: 64) {
                ForEach(results) { model in
                    GymsModelRow(model: model, showsManufacturer: true, isCurrent: model.id == currentID, gymID: gymID) { pick(model) }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: look.space.group + 8) {
                ForEach(groupsFor(results), id: \.id) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = group.title {
                            GymsGroupHeader(title: title, family: group.family, showsSwatch: grouping == 1, count: group.models.count)
                        }
                        LookList(separatorInset: 64) {
                            ForEach(group.models) { model in
                                GymsModelRow(model: model, showsManufacturer: grouping != 0, isCurrent: model.id == currentID,
                                             gymID: gymID) { pick(model) }
                            }
                        }
                    }
                }
            }
        }
    }

    private struct ModelGroup {
        var id: String
        var title: String?
        var family: MuscleFamily?
        var models: [EquipmentModel]
    }

    private func groupsFor(_ models: [EquipmentModel]) -> [ModelGroup] {
        switch grouping {
        case 0:
            let byMaker = Dictionary(grouping: models, by: \.manufacturer)
            return byMaker.keys.sorted().map { maker in
                ModelGroup(id: maker, title: maker, family: nil,
                           models: byMaker[maker]!.sorted { $0.modelName.localizedCompare($1.modelName) == .orderedAscending })
            }
        case 1:
            // Each model once, under the body area of its first exercise (display only, D23).
            var byFamily: [MuscleFamily: [EquipmentModel]] = [:]
            var other: [EquipmentModel] = []
            for model in models {
                if let family = store.exercise(model.exerciseIDs.first)?.family { byFamily[family, default: []].append(model) } else { other.append(model) }
            }
            var groups = MuscleFamily.allCases.compactMap { family in
                byFamily[family].map { ModelGroup(id: family.rawValue, title: family.label, family: family, models: $0) }
            }
            if !other.isEmpty {
                groups.append(ModelGroup(id: "other", title: "Uncategorized", family: nil, models: other))
            }
            return groups
        default:
            return [ModelGroup(id: "all", title: nil, family: nil, models: models)]
        }
    }

    /// Pinned under the search field: New Model… (prefilled from the search) · Scan Machine
    /// (only when adding a machine). Side by side; stacked when a label can't fit.
    /// AX: New Model… keeps its words and Scan Machine becomes its glyph in a 1:1 pill on the
    /// same line (two stacked full-width pills pushed the first model below the fold).
    @ViewBuilder private var makePair: some View {
        if typeSize.isAccessibilitySize {
            HStack(spacing: 10) {
                GymsMakePill(title: "New Model…", symbol: "plus") { onNewModel(query) }
                if machineID == nil, let gymID {
                    GymsMakePill(title: "Scan Machine", symbol: "camera.viewfinder", iconOnly: true) { scan(gymID) }
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { makePills }
                VStack(spacing: 10) { makePills }
            }
        }
    }

    @ViewBuilder private var makePills: some View {
        GymsMakePill(title: "New Model…", symbol: "plus") { onNewModel(query) }
        if machineID == nil, let gymID {
            GymsMakePill(title: "Scan Machine", symbol: "camera.viewfinder") { scan(gymID) }
        }
    }

    /// No match: the ways out are the result, New Model… showing the name it will start from.
    private var noMatch: some View {
        let prefill = store.gymsNewModelPrefill(query)
        let name = "\(prefill.manufacturer) \(prefill.model)".trimmingCharacters(in: .whitespaces)
        return VStack(spacing: look.space.grid) {
            EmptyStateView(symbol: "magnifyingglass", title: "No models match")
                .padding(.vertical, -6)
            GymsMakeRow(title: "New Model…", detail: name.isEmpty ? nil : name) { onNewModel(query) }
            if machineID == nil, let gymID {
                GymsMakeRow(title: "Scan Machine", symbol: "camera.viewfinder") { scan(gymID) }
            }
        }
    }

    private func scan(_ gymID: UUID) {
        store.scanBegin(gymID: gymID)
        router.present(.scan(gymID: gymID))
    }

    // MARK: Picking

    private func pick(_ model: EquipmentModel) {
        guard let machine = store.machine(machineID) else {
            if let gymID {
                store.addMachine(gymID: gymID, label: store.gymsDefaultLabel(for: model), modelID: model.id)
            }
            dismiss()
            return
        }
        guard model.id != machine.modelID else { dismiss(); return }
        if store.correctionImpact(machineID: machine.id).workouts == 0 {
            store.correctModel(machineID: machine.id, to: model.id, scope: .futureOnly)
            dismiss()
        } else {
            pendingCorrection = model
        }
    }

    private var correctionShown: Binding<Bool> {
        Binding(get: { pendingCorrection != nil }, set: { if !$0 { pendingCorrection = nil } })
    }

    private func correctionMessage(_ model: EquipmentModel) -> String {
        guard let machine = store.machine(machineID) else { return "" }
        let impact = store.correctionImpact(machineID: machine.id)
        return "\(model.displayName). \(Format.count(impact.workouts, "workout")) · \(Format.count(impact.sets, "set")) were logged on \(machine.label)."
    }

    private func correct(to model: EquipmentModel, scope: CorrectionScope) {
        guard let machineID else { return }
        store.correctModel(machineID: machineID, to: model.id, scope: scope)
        pendingCorrection = nil
        dismiss()
    }
}

// MARK: - Rows and chips

/// Model · what it serves, then the gym's pin when a machine here uses it — with that
/// machine's label only when it differs from the exercise line ("Seated Chest Press ·
/// [pin] Chest Press 2"; "Leg Extension [pin]").
private struct GymsModelRow: View {
    var model: EquipmentModel
    var showsManufacturer: Bool
    var isCurrent: Bool
    var gymID: UUID?
    var action: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        let exercises = model.exerciseIDs.compactMap { store.exercise($0)?.name }
        let here = store.gymsMachineLabels(usingModel: model.id, gymID: gymID)
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                GymsEquipmentDisc(category: model.category, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(showsManufacturer ? model.displayName : model.modelName)
                        .font(.system(.body, weight: look.id == .floodlight ? .semibold : .bold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !exercises.isEmpty || !here.isEmpty {
                        servesLine(exercises, here: here)
                            .font(look.font.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !model.isSeeded { GymsTag("Custom").padding(.top, 2) }
                }
                Spacer(minLength: 8)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(look.actionText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(GymsRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([model.displayName, model.category?.label, exercises.joined(separator: ", "),
                             here.isEmpty ? nil : "At this gym: \(here.joined(separator: ", "))"].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private func servesLine(_ names: [String], here: [String]) -> Text {
        let served = Text(verbatim: exerciseLine(names)).foregroundStyle(look.textSecondary)
        guard !here.isEmpty else { return served }
        let differing = here.filter { !names.contains($0) }
        let pin = Text(Image(systemName: look.gymSymbol)).foregroundStyle(look.textPrimary).fontWeight(.bold)
        let mark = differing.isEmpty ? pin
            : Text("\(pin) \(Text(verbatim: differing.joined(separator: ", ")).foregroundStyle(look.textPrimary).fontWeight(.semibold))")
        return names.isEmpty ? mark : Text("\(served)  \(mark)")
    }

    private func exerciseLine(_ names: [String]) -> String {
        names.count <= 2 ? names.joined(separator: ", ") : "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
    }
}

/// A filter chip with the equipment glyph (Chip only takes symbol names). Chips toggle, so C
/// outlines them in ink.
struct GymsCategoryChip: View {
    var title: String
    var category: EquipmentCategory?
    var showsGlyph: Bool
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 34
    @ScaledMetric(relativeTo: .subheadline) private var glyph: CGFloat = 16

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsGlyph { GymsEquipmentGlyph(category: category, side: glyph) }
                Text(title)
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background(fill, in: Capsule())
            .overlay { Capsule().strokeBorder(edge, lineWidth: look.id.isPaperClub ? 1.5 : 1) }
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(category?.label ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        switch look.id {
        case .floodlight, .anatomy: isSelected ? look.selection : look.textSecondary
        case .paper, .carbon: isSelected ? look.onAction : look.textPrimary
        }
    }
    private var fill: Color {
        switch look.id {
        case .floodlight: isSelected ? look.segmentFill : .clear
        case .anatomy: isSelected ? look.segmentFill : look.surfaceSheet
        case .paper, .carbon: isSelected ? look.action : look.surface
        }
    }
    private var edge: Color {
        switch look.id {
        case .floodlight: isSelected ? .clear : look.hairline
        case .anatomy: look.hairline
        case .paper, .carbon: look.outline
        }
    }
}

// MARK: - New Model form

/// New Model: manufacturer and model (labelled, like New Gym), equipment type (visual
/// choices), and the exercises it serves — searchable, with the linked ones as removable chips
/// on top and the optional "Suggest exercises with AI" (consent first; simulated). Add needs a
/// name and ≥ 1 exercise.
private struct GymsNewModelForm: View {
    @State var manufacturer: String
    @State var modelName: String
    var captureVariant: String?
    var onCancel: () -> Void
    var onAdd: (EquipmentModel) -> Void

    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var category: EquipmentCategory?
    @State private var selected: [UUID] = []
    @State private var reasons: [UUID: String] = [:]
    @State private var exerciseQuery = ""
    @State private var consentShown = false
    @State private var linkedTick = 0
    @State private var appeared = false
    @FocusState private var focus: Field?
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 112

    private enum Field { case maker, model }

    init(manufacturer: String, modelName: String, captureVariant: String?,
         onCancel: @escaping () -> Void, onAdd: @escaping (EquipmentModel) -> Void) {
        _manufacturer = State(initialValue: manufacturer)
        _modelName = State(initialValue: modelName)
        self.captureVariant = captureVariant
        self.onCancel = onCancel
        self.onAdd = onAdd
    }

    private var maker: String { manufacturer.trimmingCharacters(in: .whitespaces) }
    private var name: String { modelName.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !maker.isEmpty && !name.isEmpty && !selected.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            GymsSheetHeader(title: "New Model", cancel: cancel, commitTitle: "Add", commitEnabled: canAdd, commit: add)
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section - 6) {
                    preview
                    LookList {
                        field("Manufacturer", text: $manufacturer, which: .maker)
                        field("Model", text: $modelName, which: .model)
                    }
                    typeSection
                    exercisesSection
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: store.modelSuggest) { _, state in
            switch state {
            case .needsConsent: consentShown = true
            case .suggested(let list):
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                    for s in list where !selected.contains(s.exerciseID) { selected.append(s.exerciseID) }
                    for s in list { reasons[s.exerciseID] = s.reason }
                }
                linkedTick += 1
            default: break
            }
        }
        .alert("Send model details to OpenAI?", isPresented: $consentShown) {
            Button("Allow and send") { store.allowModelDetailsAndSuggest(manufacturer: maker, modelName: name) }
            Button("Cancel", role: .cancel) { store.cancelModelSuggestion() }
        } message: {
            Text("Sends the typed manufacturer/model, plate text and exercise names to OpenAI. You can revoke this in Settings. OpenAI API data policies apply.")
        }
        .sensoryFeedback(.success, trigger: linkedTick)
        .onAppear(perform: appear)
        .onDisappear { store.cancelModelSuggestion() }
    }

    private func appear() {
        guard !appeared else { return }
        appeared = true
        switch captureVariant {
        case "consent":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                store.suggestModelExercises(manufacturer: maker, modelName: name)
            }
        case "suggested":
            category = .plateLoaded
            store.allowModelDetailsAndSuggest(manufacturer: maker, modelName: name)
        default: break
        }
    }

    private var preview: some View {
        let empty = maker.isEmpty && name.isEmpty
        return HStack(spacing: 14) {
            GymsEquipmentDisc(category: category, size: 56)
                .animation(.snappy(duration: 0.2), value: category)
            VStack(alignment: .leading, spacing: 5) {
                Text(empty ? "New Model" : "\(maker) \(name)".trimmingCharacters(in: .whitespaces))
                    .font(look.font.cardTitle)
                    .foregroundStyle(empty ? look.textTertiary : look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                GymsFlow(spacing: 6) {
                    GymsTag("Custom")
                    if let category { GymsTag(category.label, category: .some(category)) }
                    if !selected.isEmpty { GymsTag(Format.count(selected.count, "exercise")) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.tile)
        .accessibilityElement(children: .combine)
    }

    /// Label column like New Gym's Name / City; at AX the label sits above the field.
    private func field(_ label: String, text: Binding<String>, which: Field) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(label)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(look.textSecondary)
                .lineLimit(1)
                .frame(width: ax ? nil : labelWidth, alignment: .leading)
            TextField(label, text: text, prompt: Text("Required").foregroundStyle(look.textTertiary))
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(which == .maker ? .next : .done)
                .focused($focus, equals: which)
                .onSubmit { focus = which == .maker ? .model : nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, ax ? 10 : 0)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focus = which }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Equipment type")
                .font(look.font.headline)
                .foregroundStyle(look.textPrimary)
                .padding(.leading, 4)
            GymsFlow(spacing: 8) {
                ForEach(EquipmentCategory.allCases) { option in
                    GymsCategoryChip(title: option.label, category: option, showsGlyph: true, isSelected: category == option) {
                        withAnimation(.snappy(duration: 0.2)) { category = category == option ? nil : option }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        let all = store.exercises.filter { $0.isMachineExercise || $0.tags.contains(.cable) || $0.tags.contains(.smith) }
        let matches = (exerciseQuery.isEmpty ? all : all.filter { Store.matches($0.name, exerciseQuery) })
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercises")
                    .font(look.font.headline)
                    .foregroundStyle(look.textPrimary)
                Spacer()
                Text(selected.isEmpty ? "Link at least one." : Format.count(selected.count, "linked", "linked"))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 4)
            if !selected.isEmpty {
                GymsFlow(spacing: 8) {
                    ForEach(selected, id: \.self) { id in
                        Chip(store.exercise(id)?.name ?? "", symbol: "xmark", isSelected: true) {
                            withAnimation(.snappy(duration: 0.2)) { toggle(id) }
                        }
                        .accessibilityHint("Removes it")
                    }
                }
                .transition(.opacity)
                // Why the AI linked each one (one line each, only for its picks).
                ForEach(selected.filter { reasons[$0] != nil }, id: \.self) { id in
                    Label(reasons[id] ?? "", systemImage: "sparkles")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                }
            }
            suggestControl
            SearchFieldView(text: $exerciseQuery, prompt: "Search exercises")
            LookList(separatorInset: 16) {
                ForEach(matches) { exercise in
                    exerciseRow(exercise)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestControl: some View {
        switch store.modelSuggest {
        case .asking:
            HStack(spacing: 10) {
                ProgressView().tint(look.textPrimary)
                Text("Asking AI…").font(look.font.subhead).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        case .empty:
            suggestButton
            Text(ModelSuggestSimulator.emptyMessage).font(look.font.footnote).foregroundStyle(look.textSecondary).padding(.horizontal, 4)
        case .failed(let message):
            suggestButton
            Text(message).font(look.font.footnote).foregroundStyle(look.textSecondary).padding(.horizontal, 4)
        default:
            suggestButton
        }
    }

    private var suggestButton: some View {
        Button {
            store.suggestModelExercises(manufacturer: maker, modelName: name)
        } label: {
            Label("Suggest exercises with AI", systemImage: "sparkles")
        }
        .buttonStyle(.lookSecondary)
        .disabled(maker.isEmpty || name.isEmpty)
        .opacity(maker.isEmpty || name.isEmpty ? 0.45 : 1)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let on = selected.contains(exercise.id)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { toggle(exercise.id) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(.body, weight: on ? .semibold : .regular))
                        .foregroundStyle(look.textPrimary)
                    if on, let reason = reasons[exercise.id] {
                        Label(reason, systemImage: "sparkles")
                            .font(look.font.caption)
                            .foregroundStyle(look.textSecondary)
                    } else if let group = exercise.muscleGroup {
                        Text(group.label).font(look.font.caption).foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(on ? look.actionText : look.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(GymsRowPressStyle())
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func toggle(_ id: UUID) {
        if let i = selected.firstIndex(of: id) { selected.remove(at: i) } else { selected.append(id) }
    }

    private func cancel() {
        store.cancelModelSuggestion()
        onCancel()
    }

    private func add() {
        guard canAdd else { return }
        let order = store.exercises.map(\.id)
        let ids = selected.sorted { (order.firstIndex(of: $0) ?? 0) < (order.firstIndex(of: $1) ?? 0) }
        let id = store.addModel(manufacturer: maker, modelName: name, category: category, exerciseIDs: ids)
        if let model = store.model(id) { onAdd(model) }
    }
}
