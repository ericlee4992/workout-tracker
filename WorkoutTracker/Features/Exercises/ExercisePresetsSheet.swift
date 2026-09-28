import SwiftData
import SwiftUI

/// Presets for one exercise (Floodlight ticket 08, E04): the grips, stances and single/double
/// variations the user actually switches between (D36–D38), each with how many workouts used it
/// and its best set. Tap renames (logged sets keep the old name); swipe deletes after a
/// confirmation; Edit shows the reorder handles (user decision 2 — the order is the order presets
/// are offered in a workout). Add by typing (a duplicate is refused with one line) or by tapping a
/// common suggestion. Everything saves as it happens, so the only commit is Done.
///
/// Attached to the exercise, seeded or not (D37). A preset on a seeded exercise is user data
/// hanging off a catalog row — the same shape D27 already blessed for user-created exercises
/// linked to seeded models — so catalog reconciliation leaves it alone.
struct ExercisePresetsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allPreferences: [AppPreferences]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var finished: [Workout]
    var exercise: Exercise

    @State private var newName = ""
    @State private var editing: ExercisePreset?
    @State private var editText = ""
    @State private var deleting: ExercisePreset?
    @State private var editMode: EditMode = .inactive
    @State private var addedTick = 0
    @State private var headerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0

    private var presets: [ExercisePreset] {
        (exercise.presets ?? []).filter { !$0.isDeleted }.sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    private var existingNames: [String] { presets.map(\.name) }

    private var unusedSuggestions: [String] {
        ExercisePresets.suggestions.filter { !ExercisePresets.isDuplicate($0, among: existingNames) }
    }

    private var displayUnit: WeightUnit {
        UnitPrecedence.defaultUnit(machineUnit: nil, gymUnit: nil,
                                   appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
    }

    var body: some View {
        let _ = finished.count
        let sets = (try? ExerciseOverview.loggedSets(in: modelContext))?[exercise.id] ?? []
        let usage = ExerciseOverview.presetUsage(sets)
        let bests = ExerciseOverview.presetBests(sets, currentLoadType: exercise.loadType)
        VStack(spacing: 0) {
            header
                .exercisesMeasureHeight($headerHeight)
            List {
                Section {
                    if presets.isEmpty {
                        emptyPanel
                            .plainListRow()
                    }
                    ForEach(presets) { preset in
                        presetRow(preset, workouts: usage[preset.id] ?? 0, best: bests[preset.id].flatMap(SetValue.init))
                            .lookListRows()
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash") { deleting = preset }
                                    .tint(look.destructive)
                            }
                    }
                    .onMove(perform: move)
                    .onDelete { offsets in deleting = offsets.first.map { presets[$0] } }
                }
                Section {
                    addRow
                        .plainListRow()
                }
                if !unusedSuggestions.isEmpty {
                    Section {
                        suggestionCloud
                            .plainListRow()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(22)
            .environment(\.defaultMinListRowHeight, 44)
            .lookGroupedList()
            .environment(\.editMode, $editMode)
            .scrollDismissesKeyboard(.interactively)
            .exercisesMeasureContent($bodyHeight)
        }
        .exercisesSheetChrome(fitted: headerHeight + bodyHeight)
        .sensoryFeedback(.success, trigger: addedTick)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: presets.map(\.id))
        .alert(
            "Rename Preset",
            isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }),
            presenting: editing
        ) { preset in
            TextField("Name", text: $editText)
            Button("Save") { rename(preset) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Logged sets keep the old name.")
        }
        .confirmationDialog(
            deleting.map { "Delete “\($0.name)”?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { preset in
            Button("Delete Preset", role: .destructive) { delete(preset) }
                .accessibilityIdentifier("presetDelete")
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Logged sets keep it.")
        }
    }

    // MARK: Header

    /// Edit (reorder handles) · "Presets" over the exercise · Done. While editing, the leading
    /// button ends editing and the trailing Done steps aside, so the sheet never shows two Dones.
    private var header: some View {
        let isEditing = editMode.isEditing
        return ExercisesSheetHeader(
            title: "Presets", subtitle: exercise.isDeleted ? nil : exercise.name, cancel: nil,
            trailing: .done { dismiss() })
            .opacity(isEditing ? 0 : 1)
            .overlay {
                if isEditing {
                    HStack {
                        Spacer()
                        GlassCapsuleButton("Done") { withAnimation { editMode = .inactive } }
                            .accessibilityIdentifier("presetsEndEdit")
                    }
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 6)
                }
            }
            .overlay(alignment: .topLeading) {
                if presets.count > 1 && !isEditing {
                    GlassCapsuleButton("Edit") { withAnimation { editMode = .active } }
                        .accessibilityIdentifier("presetsEdit")
                        .padding(.leading, look.space.margin)
                        .padding(.top, 16)
                }
            }
    }

    // MARK: Rows

    private func presetRow(_ preset: ExercisePreset, workouts: Int, best: SetValue?) -> some View {
        let ax = typeSize.isAccessibilitySize
        let usage = workouts == 0 ? "Not used yet" : "\(workouts) workout\(workouts == 1 ? "" : "s")"
        return Button {
            editText = preset.name
            editing = preset
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(look.exercisesRowTitle)
                        .foregroundStyle(look.textPrimary)
                    Text(usage)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                    if ax, let best {
                        ExercisesBestValue(value: best, loadType: exercise.loadType, userUnit: displayUnit)
                    }
                }
                Spacer(minLength: 8)
                if !ax, let best {
                    ExercisesBestValue(value: best, loadType: exercise.loadType, userUnit: displayUnit)
                }
                if !editMode.isEditing {
                    Image(systemName: "pencil")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                        .padding(.leading, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([preset.name, usage,
                             best.map { "Best \(ExerciseValueText.spoken($0, loadType: exercise.loadType))" }]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Renames the preset")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("preset.\(preset.name)")
    }

    /// Empty: one compact panel — the disc beside the title, the line on what "no presets" means
    /// under both at full width — so the add field and the suggestions stay in the short sheet.
    private var emptyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                IconDisc(symbol: "slider.horizontal.3", size: 40, context: .make)
                    .overlay { Circle().strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
                Text("No presets yet")
                    .font(look.font.tileTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Text("Without any, this exercise is logged as one thing.")
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("noPresets")
    }

    private var addRow: some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        let duplicate = ExercisePresets.isDuplicate(newName, among: existingNames)
        let canAdd = ExercisePresets.isValid(newName, existing: existingNames)
        return VStack(alignment: .leading, spacing: 10) {
            layout {
                TextField("New preset (e.g. Wide grip)", text: $newName,
                          prompt: Text("New preset (e.g. Wide grip)").foregroundStyle(look.textTertiary))
                    .font(look.font.body)
                    .foregroundStyle(look.textPrimary)
                    .tint(look.actionText)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .lookSurface(.field)
                    .exercisesFieldError(duplicate)
                    .accessibilityIdentifier("newPresetName")
                Button(action: add) {
                    ExercisesCommitFace(title: "Add", enabled: canAdd, minHeight: 50)
                }
                .buttonStyle(.lookPressable)
                .disabled(!canAdd)
                .animation(.easeOut(duration: 0.15), value: canAdd)
                .accessibilityIdentifier("addPreset")
            }
            if duplicate {
                ExercisesErrorLine(text: "\(ExercisePresets.cleanedName(newName)) is already a preset here.")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: duplicate)
    }

    private var suggestionCloud: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common")
                .font(look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            WrapLayout(spacing: 8, lineSpacing: 2) {
                ForEach(unusedSuggestions, id: \.self) { suggestion in
                    ExercisesSelectChip(suggestion, isSelected: false, action: { add(named: suggestion) }) {
                        Image(systemName: "plus").font(.system(.caption, weight: .bold))
                    }
                    .accessibilityIdentifier("presetSuggestion.\(suggestion)")
                }
            }
        }
    }

    // MARK: Editing

    private func add() { add(named: newName) }

    private func add(named name: String) {
        let cleaned = ExercisePresets.cleanedName(name)
        guard ExercisePresets.isValid(cleaned, existing: existingNames) else { return }
        let preset = ExercisePreset(
            name: cleaned,
            order: ExercisePresets.nextOrder(after: presets.map(\.order)),
            exercise: exercise)
        modelContext.insert(preset)
        save()
        newName = ""
        addedTick += 1
    }

    private func rename(_ preset: ExercisePreset) {
        let cleaned = ExercisePresets.cleanedName(editText)
        let others = presets.filter { $0.id != preset.id }.map(\.name)
        guard ExercisePresets.isValid(cleaned, existing: others) else { return }
        preset.name = cleaned
        save()
    }

    private func delete(_ preset: ExercisePreset) {
        modelContext.delete(preset)
        renumber()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = presets
        ordered.move(fromOffsets: source, toOffset: destination)
        for (preset, order) in zip(ordered, ExercisePresets.renumbered(ordered.count)) {
            preset.order = order
        }
        save()
    }

    private func renumber() {
        for (preset, order) in zip(presets, ExercisePresets.renumbered(presets.count)) {
            preset.order = order
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save presets: \(error)")
        }
    }
}

private extension View {
    /// A list row that draws its own surface (the empty panel, the add field, the suggestions).
    func plainListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}
