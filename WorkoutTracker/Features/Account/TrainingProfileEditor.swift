import SwiftUI

/// Public beta ticket 05: the training-profile editor — a sheet with staged edits (Cancel / Save), in Ask AI's own
/// vocabulary (A01): the goal with its phrase chips, experience tiles, the week's days and minutes (the bold element,
/// as in A01: the session count), then height and weight. Height and weight keep the unit they were entered in (D52):
/// an empty field takes the app's units; a stored value shows in its own.
struct TrainingProfileEditor: View {
    var usCustomary: Bool
    var onSave: (TrainingProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: TrainingProfile
    /// Height and weight as typed, staged together (codex-review-05b): the measurements come from these strings.
    @State private var height: MeasureDraft
    @State private var weight: MeasureDraft
    private let original: TrainingProfile
    @FocusState private var focus: Field?

    private enum Field: Hashable { case goals, heightA, heightB, weight }

    init(profile: TrainingProfile?, usCustomary: Bool, onSave: @escaping (TrainingProfile) -> Void) {
        let start = profile ?? .empty
        _draft = State(initialValue: start)
        // The stored unit, else the app's (D52: a stored value is never shown converted).
        _height = State(initialValue: MeasureDraft(start.height, kind: .height,
                                                   imperial: start.height.map { $0.unit == .inches } ?? usCustomary))
        _weight = State(initialValue: MeasureDraft(start.weight, kind: .weight,
                                                   imperial: start.weight.map { $0.unit == .lb } ?? usCustomary))
        original = start
        self.usCustomary = usCustomary
        self.onSave = onSave
    }

    /// The profile Save would commit; nil while a height or weight entry is not a valid number.
    private var staged: TrainingProfile? {
        guard case .some(let h) = height.measure, case .some(let w) = weight.measure else { return nil }
        var profile = draft
        profile.height = h
        profile.weight = w
        return profile
    }

    private var canSave: Bool {
        guard let staged else { return false }
        return staged.isValid && staged != original
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(cancel: { dismiss() }, title: "Training Profile", commit: save, commitEnabled: canSave,
                        commitIdentifier: "trainingSave", reflowsTitle: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    goalField.padding(.top, 6)
                    chips.padding(.top, 8)
                    experience.padding(.top, look.space.section)
                    schedule.padding(.top, look.space.section)
                    measures.padding(.top, look.space.section)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .lookSheetGround()
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(staged != original)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }.fontWeight(.semibold)
            }
        }
    }

    private func save() {
        guard canSave, let staged else { return }
        var saved = staged
        saved.goals = saved.goals.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(saved)
        dismiss()
    }

    // MARK: Goal

    private var goalField: some View {
        TextField("", text: $draft.goals,
                  prompt: Text("What would you like to work toward?").foregroundStyle(look.textSecondary),
                  axis: .vertical)
            .lineLimit(2...6)
            .font(.system(.body, weight: .medium))
            .foregroundStyle(look.textPrimary)
            .focused($focus, equals: .goals)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .lookSurface(.field, radius: look.radius.tile - 4)
            .accessibilityLabel("Goals")
            .accessibilityIdentifier("trainingGoals")
    }

    private var chips: some View {
        WrapLayout(spacing: 8) {
            ForEach(AIGoalPhrase.allCases) { phrase in
                AIGoalChip(title: phrase.rawValue, isSelected: phrase.isIn(draft.goals)) {
                    draft.goals = phrase.toggled(in: draft.goals)
                }
            }
        }
    }

    // MARK: Experience

    private var experience: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Experience")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { experienceTiles }
                VStack(spacing: 8) { experienceTiles }
            }
        }
    }

    @ViewBuilder private var experienceTiles: some View {
        ForEach(Array(TrainingProfile.experiences.enumerated()), id: \.element) { index, level in
            let selected = draft.experience == level
            AISelectTile(isSelected: selected, minHeight: 84) {
                draft.experience = level
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        let lit = AISelectionPaint(look: look, isSelected: selected).foreground
                        AIExperienceBars(level: index + 1, lit: lit, unlit: lit.opacity(0.28))
                        Spacer(minLength: 8)
                        AICheckMark(isOn: selected)
                    }
                    Text(level)
                        .font(.system(.subheadline, weight: selected ? .bold : .semibold))
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(level)
            .accessibilityIdentifier("trainingExperience.\(level)")
        }
    }

    // MARK: Days and minutes (the bold element)

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 0) {
            figure(draft.days, draft.days == 1 ? "day per week" : "days per week")
            AIDayCountPicker(count: draft.days) { draft.days = $0 }
                .padding(.top, 14)
                .padding(.horizontal, -10)
            LookDivider().padding(.vertical, 18)
            figure(draft.minutes, "minutes per session")
            AIMinutesControl(value: $draft.minutes)
                .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .lookSurface(.panel)
    }

    private func figure(_ number: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(look.font.heroNumber)
                .foregroundStyle(look.textPrimary)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(number)))
                .animation(reduceMotion ? nil : .snappy, value: number)
            Text(label)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Height and weight (optional; kept as entered)

    private var measures: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Height and weight", trailing: "Optional")
            VStack(spacing: 0) {
                row("Height") { heightFields }
                LookDivider().padding(.leading, 16)
                row("Weight") { weightField }
            }
            .lookSurface(.panel)
        }
    }

    private func row<Fields: View>(_ title: String, @ViewBuilder fields: () -> Fields) -> some View {
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(title)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
            if !ax { Spacer(minLength: 8) }
            HStack(spacing: 8) { fields() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    /// Values show and save exactly as typed (codex-review-05, 05b): feet and inches are read together; an entry that
    /// is not a number Save can store exactly (more than two decimals, 12 inches or more) shows in the destructive
    /// colour and keeps Save off.
    @ViewBuilder private var heightFields: some View {
        let invalid = height.measure == nil
        if height.imperial {
            MeasureField(text: $height.first, unit: "ft", decimal: false, invalid: invalid,
                         accessibility: "Height, feet", identifier: "trainingHeightFeet", focus: $focus, field: .heightA)
            MeasureField(text: $height.second, unit: "in", decimal: true, invalid: invalid,
                         accessibility: "Height, inches", identifier: "trainingHeightInches", focus: $focus, field: .heightB)
        } else {
            MeasureField(text: $height.first, unit: "cm", decimal: true, invalid: invalid,
                         accessibility: "Height, centimetres", identifier: "trainingHeight", focus: $focus, field: .heightA)
        }
    }

    private var weightField: some View {
        MeasureField(text: $weight.first, unit: weight.imperial ? "lb" : "kg", decimal: true, invalid: weight.measure == nil,
                     accessibility: "Weight, \(weight.imperial ? "pounds" : "kilograms")",
                     identifier: "trainingWeight", focus: $focus, field: .weight)
    }
}

/// A short number field with its unit (as Ask AI's profile fields); its text is the editor's staged text.
private struct MeasureField<F: Hashable>: View {
    @Binding var text: String
    var unit: String
    var decimal: Bool
    var invalid: Bool
    var accessibility: String
    var identifier: String
    var focus: FocusState<F?>.Binding
    var field: F
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var width: CGFloat = 58

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            TextField("", text: $text, prompt: Text("–").foregroundStyle(look.textSecondary))
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .font(look.font.fieldNumber)
                .foregroundStyle(invalid ? look.destructive : look.textPrimary)
                .focused(focus, equals: field)
                .frame(width: width)
                .frame(minHeight: 44)
                .lookSurface(.field)
                .accessibilityLabel(accessibility)
                .accessibilityValue(invalid ? "\(text), not a valid entry" : text)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
    }
}
