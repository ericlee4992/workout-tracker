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
    private let original: TrainingProfile
    @FocusState private var focus: Field?

    private enum Field: Hashable { case goals, heightA, heightB, weight }

    init(profile: TrainingProfile?, usCustomary: Bool, onSave: @escaping (TrainingProfile) -> Void) {
        let start = profile ?? .empty
        _draft = State(initialValue: start)
        original = start
        self.usCustomary = usCustomary
        self.onSave = onSave
    }

    private var canSave: Bool {
        !draft.goals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.isValid && draft != original
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
        .interactiveDismissDisabled(draft != original)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }.fontWeight(.semibold)
            }
        }
    }

    private func save() {
        guard canSave else { return }
        var saved = draft
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

    /// The unit a height field uses: the stored one, else the app's.
    private var heightInInches: Bool { draft.height.map { $0.unit == .inches } ?? usCustomary }
    private var weightInPounds: Bool { draft.weight.map { $0.unit == .lb } ?? usCustomary }

    /// Values show and save as typed, decimals included (codex-review-05 #2): no rounding on display or save. Each field
    /// keeps its own text while typing (so "82." can become "82.5"); the draft follows every edit.
    @ViewBuilder private var heightFields: some View {
        if heightInInches {
            let total = draft.height?.value
            MeasureField(initial: total.map { String(Int($0 / 12)) } ?? "", unit: "ft", decimal: false,
                         accessibility: "Height, feet", identifier: "trainingHeightFeet", focus: $focus, field: .heightA) { text in
                let inches = draft.height.map { $0.value - Double(Int($0.value / 12) * 12) } ?? 0
                draft.height = AIProfileUnits.parse(text).map { BodyMeasure(value: Double($0 * 12) + inches, unit: .inches) }
            }
            MeasureField(initial: total.map { BodyMeasure.number($0 - Double(Int($0 / 12) * 12)) } ?? "", unit: "in", decimal: true,
                         accessibility: "Height, inches", identifier: "trainingHeightInches", focus: $focus, field: .heightB) { text in
                let wholeFeet = draft.height.map { Double(Int($0.value / 12) * 12) } ?? 0
                let inches = min(11.99, BodyMeasure.parse(text) ?? 0)
                draft.height = BodyMeasure(value: wholeFeet + inches, unit: .inches)
            }
        } else {
            MeasureField(initial: draft.height.map { BodyMeasure.number($0.value) } ?? "", unit: "cm", decimal: true,
                         accessibility: "Height, centimetres", identifier: "trainingHeight", focus: $focus, field: .heightA) { text in
                draft.height = BodyMeasure.parse(text).map { BodyMeasure(value: $0, unit: .cm) }
            }
        }
    }

    private var weightField: some View {
        MeasureField(initial: draft.weight.map { BodyMeasure.number($0.value) } ?? "", unit: weightInPounds ? "lb" : "kg",
                     decimal: true, accessibility: "Weight, \(weightInPounds ? "pounds" : "kilograms")",
                     identifier: "trainingWeight", focus: $focus, field: .weight) { text in
            draft.weight = BodyMeasure.parse(text).map { BodyMeasure(value: $0, unit: weightInPounds ? .lb : .kg) }
        }
    }
}

/// A short number field with its unit (as Ask AI's profile fields), holding its own text while typing.
private struct MeasureField<F: Hashable>: View {
    var initial: String
    var unit: String
    var decimal = false
    var accessibility: String
    var identifier: String
    var focus: FocusState<F?>.Binding
    var field: F
    var onEdit: (String) -> Void
    @State private var text: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var width: CGFloat = 58

    init(initial: String, unit: String, decimal: Bool, accessibility: String, identifier: String,
         focus: FocusState<F?>.Binding, field: F, onEdit: @escaping (String) -> Void) {
        self.initial = initial
        self.unit = unit
        self.decimal = decimal
        self.accessibility = accessibility
        self.identifier = identifier
        self.focus = focus
        self.field = field
        self.onEdit = onEdit
        _text = State(initialValue: initial)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            TextField("", text: $text, prompt: Text("–").foregroundStyle(look.textSecondary))
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .font(look.font.fieldNumber)
                .foregroundStyle(look.textPrimary)
                .focused(focus, equals: field)
                .frame(width: width)
                .frame(minHeight: 44)
                .lookSurface(.field)
                .accessibilityLabel(accessibility)
                .accessibilityIdentifier(identifier)
                .onChange(of: text) { _, new in onEdit(new) }
            Text(unit)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
    }
}
