import SwiftUI

// PROTOTYPE — E03 New Exercise. The name, then the choice that matters most (load type) as
// four tiles with its one consequence line, then body area (NEW: the real sheet never asked,
// so custom exercises fell into "Uncategorized") as chips carrying their family colour mark,
// then equipment as multi-select chips. Add is the one filled command; it stays off while the
// name is blank or already taken. From the Exercises tab, Add opens the new exercise (E02);
// over a live workout it adds the exercise to the workout.

struct NewExerciseSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name = ""
    @State private var loadType: LoadType = .weighted
    @State private var muscleGroup: MuscleGroup?
    @State private var tags: Set<EquipmentTag> = []
    @State private var page = 0
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var addedTick = 0
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var taken: Bool { store.exercisesNameTaken(trimmed) }
    private var canAdd: Bool { !trimmed.isEmpty && !taken }

    var body: some View {
        VStack(spacing: 0) {
            ExercisesSheetHeader(title: "New Exercise", cancel: { router.dismissSheet() },
                                 trailing: .commit("Add", enabled: canAdd, action: add))
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    nameField
                    section("Load type") { ExercisesLoadTypeGrid(selection: $loadType) }
                    section("Body area") { bodyAreaChips }
                    section("Equipment") { equipmentChips }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollPosition($scroll)
            .exercisesPaging(page, position: $scroll)
        }
        .exercisesSheetPresentation(look)
        .sensoryFeedback(.success, trigger: addedTick)
        .onAppear(perform: prepare)
    }

    // MARK: Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(look.textTertiary))
                .font(look.id.isPaperClub ? look.font.title3 : look.font.title3)
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(.horizontal, 14)
                .frame(minHeight: 58)
                .lookSurface(.field)
                .exercisesFieldError(taken)
                .accessibilityLabel("Name")
            if taken {
                ExercisesErrorLine(text: "“\(trimmed)” is already an exercise.")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: taken)
    }

    // MARK: Body area

    private var bodyAreaChips: some View {
        ExercisesFlowLayout(spacing: 8, lineSpacing: 2) {
            ForEach(MuscleGroup.allCases) { group in
                ExercisesSelectChip(group.label, isSelected: muscleGroup == group, action: {
                    let next: MuscleGroup? = muscleGroup == group ? nil : group
                    if reduceMotion { muscleGroup = next } else { withAnimation(.snappy(duration: 0.2)) { muscleGroup = next } }
                }) {
                    // A no-family group (Neck, Core, Full Body) carries no mark in A.
                    if group.family != nil || look.id != .floodlight {
                        ExercisesFamilyMark(family: group.family)
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: muscleGroup)
    }

    // MARK: Equipment

    private var equipmentChips: some View {
        ExercisesFlowLayout(spacing: 8, lineSpacing: 2) {
            ForEach(EquipmentTag.allCases) { tag in
                let on = tags.contains(tag)
                ExercisesSelectChip(tag.label, isSelected: on, action: {
                    if reduceMotion { toggle(tag) } else { withAnimation(.snappy(duration: 0.2)) { toggle(tag) } }
                }) {
                    ExercisesGlyph(tag, style: .footnote)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: tags)
    }

    private func toggle(_ tag: EquipmentTag) {
        if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(look.id.isPaperClub ? look.font.title3 : look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    // MARK: Actions

    private func add() {
        guard canAdd else { return }
        let ordered = EquipmentTag.allCases.filter { tags.contains($0) }
        let id = store.createExercise(name: trimmed, loadType: loadType, muscleGroup: muscleGroup, tags: ordered)
        addedTick += 1
        router.dismissSheet()
        if store.session != nil && store.isSessionPresented {
            store.addExercise(id)
        } else if router.tab == .exercises {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(.exerciseDetail(exerciseID: id)) }
        }
    }

    private func prepare() {
        if let pending = ExercisesDraft.pendingName {
            name = pending
            ExercisesDraft.pendingName = nil
        }
        guard let variant = ExercisesVariant.consume(.e03, store: store, router: router) else { return }
        page = ExercisesVariant.page(variant)
        if ExercisesVariant.has(variant, "filled") {
            name = "Landmine Row"
            loadType = .weighted
            muscleGroup = .back
            tags = [.barbell]
        }
        if ExercisesVariant.has(variant, "taken") { name = "Bench press" }
        if ExercisesVariant.has(variant, "assisted") {
            name = "Assisted Chin-Up"
            loadType = .assisted
            muscleGroup = .back
            tags = [.machine]
        }
    }
}
