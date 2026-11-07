import SwiftUI

// PROTOTYPE — E04 Presets: the named variations (grip, stance…) that split an exercise's
// history (D36–D38). Each preset shows how many workouts used it and its best set; tap to
// rename (logged sets keep the old name), swipe left to delete (confirmed). Add by typing (a
// duplicate is refused with one line) or by tapping a common suggestion, which flies into the
// list. Everything saves as it happens, so the only chrome is Done. Empty: one compact row with
// the kept line on what "no presets" means. Opens as a short sheet over the exercise.

struct PresetsSheet: View {
    let exerciseID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The sheet root sits outside the prototype's type override (applied inside), so read it too.
    private var isAX: Bool { (router.dynamicTypeOverride ?? typeSize).isAccessibilitySize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft = ""
    @State private var revealed: UUID?
    @State private var renaming: ExercisePreset?
    @State private var renameText = ""
    @State private var deleting: ExercisePreset?
    @State private var addedTick = 0
    @State private var justAdded: UUID?
    @State private var headerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0
    @FocusState private var fieldFocused: Bool

    private var exercise: Exercise? { store.exercise(exerciseID) }
    private var presets: [ExercisePreset] { exercise?.presets ?? [] }
    private var trimmed: String { draft.trimmingCharacters(in: .whitespaces) }
    private var duplicate: ExercisePreset? {
        presets.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }
    private var canAdd: Bool { !trimmed.isEmpty && duplicate == nil }
    private var suggestions: [String] {
        SampleData.presetSuggestions.filter { s in !presets.contains { $0.name.caseInsensitiveCompare(s) == .orderedSame } }
    }

    var body: some View {
        VStack(spacing: 0) {
            ExercisesSheetHeader(title: "Presets", subtitle: exercise?.name, cancel: nil,
                                 trailing: .done { router.dismissSheet() })
                .exercisesMeasureHeight($headerHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if presets.isEmpty {
                        emptyRow
                            .transition(.opacity)
                    } else {
                        presetList
                    }
                    addRow
                    if !suggestions.isEmpty { suggestionCloud }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: presets.map(\.id))
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .exercisesMeasureContent($bodyHeight)
        }
        .exercisesSheetPresentation(look, fitted: headerHeight + bodyHeight)
        .sensoryFeedback(.success, trigger: addedTick)
        .alert("Rename Preset", isPresented: renameShown) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let renaming { store.renamePreset(renaming.id, to: renameText, exerciseID: exerciseID) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("Logged sets keep the old name.")
        }
        .confirmationDialog(deleting.map { "Delete “\($0.name)”?" } ?? "", isPresented: deleteShown, titleVisibility: .visible) {
            Button("Delete Preset", role: .destructive) {
                if let deleting { remove(deleting) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil; revealed = nil }
        } message: {
            Text("Logged sets keep it.")
        }
        .onAppear(perform: applyVariant)
    }

    // MARK: List

    private var presetList: some View {
        let usage = store.exercisesPresetUsage(exerciseID)
        let bests = store.exercisesPresetBests(exerciseID)
        return LookList(separatorInset: 14) {
            ForEach(presets) { preset in
                ExercisesSwipeRow(revealed: revealedBinding(preset.id), onDelete: { deleting = preset }) {
                    presetRow(preset, workouts: usage[preset.id] ?? 0, best: bests[preset.id])
                }
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                                                                   removal: .opacity))
            }
        }
    }

    private func presetRow(_ preset: ExercisePreset, workouts: Int, best: SetValue?) -> some View {
        Button {
            renameText = preset.name
            renaming = preset
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(look.exercisesRowTitle)
                        .foregroundStyle(look.textPrimary)
                    Text(workouts == 0 ? "Not used yet" : Format.count(workouts, "workout"))
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                    if isAX, let best, let exercise {
                        ExercisesBestValue(value: best, loadType: exercise.loadType, rowUnit: store.displayUnit,
                                           style: .row, marked: false)
                    }
                }
                Spacer(minLength: 8)
                if !isAX, let best, let exercise {
                    ExercisesBestValue(value: best, loadType: exercise.loadType, rowUnit: store.displayUnit,
                                       style: .row, marked: false)
                }
                Image(systemName: "pencil")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(justAdded == preset.id ? (look.id.isPaperClub ? look.pressedFill : look.selectionFill) : .clear)
        }
        .buttonStyle(ExercisesRowPressStyle())
        .accessibilityLabel([preset.name, workouts == 0 ? "Not used yet" : Format.count(workouts, "workout"),
                             best.map { "Best \(Format.set($0, loadType: exercise?.loadType ?? .weighted))" }]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Renames the preset")
    }

    /// Empty: one compact panel (the disc beside the kept title, the kept line under both at full
    /// width so it never breaks one word short), so the add field and the suggestions stay in the
    /// short sheet.
    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .center, spacing: 14) {
            IconDisc(symbol: "slider.horizontal.3", size: 40, context: .make)
                .overlay {
                    if look.id != .anatomy && !look.id.isPaperClub {
                        Circle().strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
            Text("No presets yet")
                .font(look.id.isPaperClub ? look.font.title3 : look.font.tileTitle)
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
    }

    private func revealedBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { revealed == id }, set: { revealed = $0 ? id : (revealed == id ? nil : revealed) })
    }

    // MARK: Add

    private var addRow: some View {
        let layout = isAX ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: 10) {
            layout {
                TextField("New preset (e.g. Wide grip)", text: $draft,
                          prompt: Text("New preset (e.g. Wide grip)").foregroundStyle(look.textTertiary))
                    .font(look.font.body)
                    .foregroundStyle(look.textPrimary)
                    .tint(look.actionText)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .onSubmit(addDraft)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .lookSurface(.field)
                    .exercisesFieldError(duplicate != nil)
                Button(action: addDraft) {
                    ExercisesCommitFace(title: "Add", enabled: canAdd, minHeight: 50)
                }
                .buttonStyle(.lookPressable)
                .disabled(!canAdd)
                .animation(.easeOut(duration: 0.15), value: canAdd)
            }
            if let duplicate {
                ExercisesErrorLine(text: "\(duplicate.name) is already a preset here.")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: duplicate?.id)
    }

    // MARK: Suggestions

    private var suggestionCloud: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common")
                .font(look.id.isPaperClub ? look.font.title3 : look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ExercisesFlowLayout(spacing: 8, lineSpacing: 2) {
                ForEach(suggestions, id: \.self) { suggestion in
                    ExercisesSelectChip(suggestion, isSelected: false, action: { add(suggestion) }) {
                        Image(systemName: "plus").font(.system(.caption, weight: .bold))
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: suggestions)
        }
    }

    // MARK: Actions

    private func addDraft() {
        guard canAdd else { return }
        add(trimmed)
        draft = ""
    }

    private func add(_ name: String) {
        let apply = {
            if let id = store.addPreset(name: name, exerciseID: exerciseID) {
                justAdded = id
                addedTick += 1
            }
        }
        if reduceMotion { apply() } else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { apply() } }
        let added = justAdded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if justAdded == added { withAnimation(.easeOut(duration: 0.4)) { justAdded = nil } }
        }
    }

    private func remove(_ preset: ExercisePreset) {
        if reduceMotion { store.deletePreset(preset.id, exerciseID: exerciseID) } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { store.deletePreset(preset.id, exerciseID: exerciseID) }
        }
        revealed = nil
    }

    private var renameShown: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
    private var deleteShown: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    // MARK: Variants

    private func applyVariant() {
        guard let variant = ExercisesVariant.consume(.e04, store: store, router: router) else { return }
        if ExercisesVariant.has(variant, "empty") {
            // Opens already empty: no removal animation behind the empty panel.
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                for preset in presets { store.deletePreset(preset.id, exerciseID: exerciseID) }
            }
        }
        if ExercisesVariant.has(variant, "duplicate") { draft = "narrow grip" }
        if ExercisesVariant.has(variant, "swipe") { revealed = presets.first?.id }
        if ExercisesVariant.has(variant, "rename"), let first = presets.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                renameText = first.name
                renaming = first
            }
        }
        if ExercisesVariant.has(variant, "delete"), let first = presets.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { deleting = first }
        }
    }
}
