import SwiftData
import SwiftUI

/// What a caller wants a `NewExerciseSheet` opened with — a prefilled name
/// (the search text that matched nothing) and, optionally, the equipment model
/// the new exercise should be linked to. `Identifiable` so pickers can present
/// the sheet with `.sheet(item:)` and re-present it with a different name.
struct NewExerciseRequest: Identifiable {
    let id = UUID()
    /// Prefilled into the name field — the user typed it once already.
    var name: String = ""
    /// The station the exercise is being invented on (ticket 19): linking it
    /// makes the movement selectable on that machine next time. nil = plain
    /// creation (model-less machine, or the plain exercise picker).
    var linkTo: EquipmentModel?
}

/// User-created exercise creation (ticket 06; Floodlight ticket 08, E03), shared by the Exercises
/// tab and the mid-workout pickers (ticket 19): the name, then the choice that matters most (load
/// type) as four tiles with its consequence line, the body area (user decision 4 — custom
/// exercises no longer fall into "Uncategorized" unless left unset) and the equipment. Add is the
/// one filled command; it stays off while the name is blank or already an exercise's (decision 4).
/// Lands in the user ID space (`isSeeded == false`).
///
/// `onCreate` lets the caller act on the row the moment it exists — a mid-workout picker selects
/// it for the entry being added; the Exercises tab opens it.
struct NewExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var exercises: [Exercise]
    var initialName: String
    /// Model to link the created exercise to (appended to its `exerciseIDs`).
    var linkTo: EquipmentModel?
    var onCreate: ((Exercise) -> Void)?
    @State private var name = ""
    @State private var loadType: LoadType = .weighted
    @State private var muscleGroup: String?
    @State private var tags: Set<EquipmentTag> = []
    @State private var loaded = false
    @State private var addedTick = 0

    init(initialName: String = "", linkTo: EquipmentModel? = nil, onCreate: ((Exercise) -> Void)? = nil) {
        self.initialName = initialName
        self.linkTo = linkTo
        self.onCreate = onCreate
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var taken: Bool {
        ExerciseNames.isTaken(trimmedName, among: exercises.filter { !$0.isDeleted }.map(\.name))
    }
    private var canAdd: Bool { !trimmedName.isEmpty && !taken }

    var body: some View {
        VStack(spacing: 0) {
            ExercisesSheetHeader(title: "New Exercise", cancel: { dismiss() },
                                 trailing: .commit("Add", enabled: canAdd, identifier: "saveNewExercise", action: addExercise))
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    nameField
                    section("Load type") {
                        ExercisesLoadTypeGrid(selection: $loadType)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("newExerciseLoadType")
                    }
                    section("Body area") { bodyAreaChips }
                    section("Equipment") { equipmentChips }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .exercisesSheetChrome()
        .sensoryFeedback(.success, trigger: addedTick)
        .onAppear(perform: load)
    }

    // MARK: Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(look.textSecondary))
                .font(look.font.title3)
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .frame(minHeight: 58)
                .lookSurface(.field)
                .exercisesFieldError(taken)
                .accessibilityIdentifier("newExerciseName")
            if taken {
                ExercisesErrorLine(text: "“\(trimmedName)” is already an exercise.")
                    .accessibilityIdentifier("newExerciseTaken")
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: taken)
    }

    // MARK: Body area and equipment

    private var bodyAreaChips: some View {
        WrapLayout(spacing: 8, lineSpacing: 2) {
            ForEach(BodyArea.order, id: \.self) { area in
                ExercisesSelectChip(area, isSelected: muscleGroup == area, action: {
                    let next: String? = muscleGroup == area ? nil : area
                    if reduceMotion { muscleGroup = next } else { withAnimation(.snappy(duration: 0.2)) { muscleGroup = next } }
                }) {
                    // Neck, Core and Full Body belong to no family and carry no mark.
                    if let family = MuscleFamily(muscleGroup: area) {
                        ExercisesFamilyMark(family: family).scaleEffect(0.8)
                    }
                }
                .accessibilityIdentifier("newExerciseBodyArea.\(area)")
            }
        }
        .sensoryFeedback(.selection, trigger: muscleGroup)
    }

    private var equipmentChips: some View {
        WrapLayout(spacing: 8, lineSpacing: 2) {
            ForEach(EquipmentTag.allCases) { tag in
                ExercisesSelectChip(tag.label, isSelected: tags.contains(tag), action: {
                    if reduceMotion { toggle(tag) } else { withAnimation(.snappy(duration: 0.2)) { toggle(tag) } }
                }) {
                    ExercisesGlyph(tag, style: .footnote)
                }
                .accessibilityIdentifier("newExerciseTag.\(tag.rawValue)")
            }
        }
        .sensoryFeedback(.selection, trigger: tags)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(look.font.tileTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        name = initialName
    }

    private func toggle(_ tag: EquipmentTag) {
        if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
    }

    private func addExercise() {
        guard canAdd else { return }
        let orderedTags = EquipmentTag.allCases.filter(tags.contains)
        do {
            let exercise = try EquipmentLifecycle(context: modelContext).createExercise(
                name: trimmedName,
                loadType: loadType,
                equipmentTypeTags: orderedTags,
                muscleGroup: muscleGroup,
                linkedTo: linkTo)
            addedTick += 1
            onCreate?(exercise)
        } catch {
            assertionFailure("Failed to save new exercise: \(error)")
        }
        dismiss()
    }
}
