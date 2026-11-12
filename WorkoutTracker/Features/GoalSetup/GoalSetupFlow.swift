import SwiftUI

/// Nutrition N13 — the goal setup: one question a page (sex, date of birth, height and weight, workouts a week, the
/// goal, the desired weight, the pace) and then the plan, every number editable. A full-screen flow: Back steps through
/// it; on first launch it cannot be closed, from Nutrition goals it can.
///
/// Composition (every page): the question top-leading in the title style — where the eye lands; the answer in the
/// middle; Continue, the one filled command, in the thumb's bottom third.
struct GoalSetupFlow: View {
    @Bindable var draft: GoalSetupDraft
    /// The plan's commit (first launch: "Start"; Nutrition goals: "Save Goals"). The host saves the answers.
    var onFinish: (GoalSetupStore.Answers) -> Void
    /// Nutrition goals only: closes without saving. nil on first launch (no way out unfinished).
    var onClose: (() -> Void)?
    /// First launch (D84): the plan page also offers the tour — the answers are saved first.
    var onTour: ((GoalSetupStore.Answers) -> Void)?
    /// N14 (D85): the server's plan, signed in; nil = the calculation.
    var generator: GoalSetupDraft.Generator? = nil
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing: NutritionGoalsView.Number?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                page
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .id(draft.step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            bottomBar
        }
        .lookScreenBackground()
        .sheet(item: $editing) { number in editor(number) }
        // N14: reaching the plan page (or changing an answer that shapes it) asks the server once.
        .task(id: draft.generationRequest) {
            if let generator { await draft.generate(with: generator) }
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 12) {
            if draft.isFirst {
                Color.clear.frame(width: 44, height: 44)
            } else {
                GlassIconButton("chevron.left", accessibilityLabel: "Back") { move(draft.back) }
                    .accessibilityIdentifier("goalSetupBack")
            }
            progress
            if let onClose {
                GlassIconButton("xmark", accessibilityLabel: "Close", action: onClose)
                    .accessibilityIdentifier("goalSetupClose")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    /// One short bar a step, the ones done in the action colour (a state, not a command).
    private var progress: some View {
        let steps = draft.steps
        let index = steps.firstIndex(of: draft.step) ?? 0
        return HStack(spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { offset, _ in
                Capsule()
                    .fill(offset <= index ? look.action : look.hairline)
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Step \(index + 1) of \(steps.count)")
    }

    private var bottomBar: some View {
        VStack(spacing: 6) {
            if draft.step == .plan {
                PrimaryButton(draft.isExistingUser ? "Save Goals" : "Start") {
                    if let answers = draft.answers { onFinish(answers) }
                }
                .disabled(draft.answers == nil)
                .accessibilityIdentifier("goalSetupFinish")
                if let onTour, !draft.isExistingUser {
                    Button { if let answers = draft.answers { onTour(answers) } } label: {
                        Text("Show Me Around")
                            .font(look.font.body.weight(.semibold))
                            .foregroundStyle(look.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("goalSetupTour")
                }
            } else {
                PrimaryButton("Continue") { move(draft.advance) }
                    .disabled(!draft.canContinue)
                    .opacity(draft.canContinue ? 1 : 0.4)
                    .accessibilityIdentifier("goalSetupContinue")
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func move(_ action: () -> Void) {
        if reduceMotion { action() } else { withAnimation(.snappy(duration: 0.3)) { action() } }
    }

    // MARK: Pages

    @ViewBuilder private var page: some View {
        switch draft.step {
        case .sex: sexPage
        case .birthDate: birthDatePage
        case .body: bodyPage
        case .workouts: workoutsPage
        case .goal: goalPage
        case .desired: desiredPage
        case .pace: pacePage
        case .plan: planPage
        }
    }

    private func question(_ title: String, _ subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(look.font.title)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }

    private var sexPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question("What's your sex?", "Used to estimate your calories.")
            OptionList(options: BiologicalSex.allCases.map { ($0, $0.label, nil, nil) },
                       selection: $draft.sex, idPrefix: "goalSetupSex")
        }
    }

    private var birthDatePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question("When were you born?")
            VStack(spacing: 4) {
                DatePicker("Date of birth", selection: $draft.birthDate, in: ...draft.now, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("goalSetupBirthDate")
                Text("\(draft.ageYears) years old")
                    .font(look.font.subhead.weight(.semibold))
                    .foregroundStyle(look.textSecondary)
                    .contentTransition(.numericText(value: Double(draft.ageYears)))
            }
            .padding(.vertical, 12)
            .lookSurface(.panel)
        }
    }

    private var bodyPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question("Your height and weight")
            SegmentedPills(["Metric", "Imperial"], selection: Binding(
                get: { draft.units.rawValue },
                set: { draft.switchUnits(to: GoalSetupDraft.Units(rawValue: $0) ?? .metric) }))
            .padding(.bottom, look.space.section)
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Height")
                heightWheels
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .lookSurface(.panel)
            }
            .padding(.bottom, look.space.section)
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Weight")
                FigureStepper(text: $draft.weightText, unit: draft.weightUnit.rawValue, fieldID: "goalSetupWeight",
                              onStep: draft.stepWeight(by:))
            }
        }
    }

    @ViewBuilder private var heightWheels: some View {
        if draft.units == .metric {
            Picker("Height", selection: $draft.heightCm) {
                ForEach(120...230, id: \.self) { Text("\($0) cm").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .accessibilityIdentifier("goalSetupHeightCm")
        } else {
            HStack(spacing: 0) {
                Picker("Feet", selection: Binding(
                    get: { draft.heightInches / 12 },
                    set: { draft.heightInches = $0 * 12 + draft.heightInches % 12 })) {
                    ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("goalSetupHeightFeet")
                Picker("Inches", selection: Binding(
                    get: { draft.heightInches % 12 },
                    set: { draft.heightInches = (draft.heightInches / 12) * 12 + $0 })) {
                    ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("goalSetupHeightInches")
            }
            .frame(height: 150)
        }
    }

    private var workoutsPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question("How often do you work out?", "Sets how active you are for the estimate.")
            OptionList(options: [
                (.few, "0–2 a week", "Now and then", "figure.walk"),
                (.some, "3–5 a week", "A few times a week", "figure.strengthtraining.traditional"),
                (.many, "6 or more a week", "Most days", "flame"),
            ], selection: $draft.workouts, idPrefix: "goalSetupWorkouts")
        }
    }

    private var goalPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question("What's your goal?")
            OptionList(options: [
                (.lose, WeightGoal.lose.label, nil, "arrow.down.right"),
                (.maintain, WeightGoal.maintain.label, nil, "equal"),
                (.gain, WeightGoal.gain.label, nil, "arrow.up.right"),
            ], selection: $draft.goal, idPrefix: "goalSetupGoal")
            if let block = draft.goalBlocked {
                Text(goalBlockText(block))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("goalSetupGoalBlocked")
            }
        }
    }

    private func goalBlockText(_ block: GoalSetupDraft.GoalBlock) -> String {
        switch block {
        case .atLowestWeight: "You're already at the lowest healthy weight for your height."
        case .calorieFloor(let floor): "Losing would take your calories under \(GoalSetupFormat.calories(floor)) a day."
        }
    }

    private var desiredPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question("What weight are you aiming for?")
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(GoalSetupFormat.number(draft.desired))
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText(value: draft.desired))
                        .accessibilityIdentifier("goalSetupDesired")
                    Text(draft.weightUnit.rawValue)
                        .font(look.font.headline.weight(.medium))
                        .foregroundStyle(look.textSecondary)
                }
                .padding(.top, 8)
                if let weight = draft.weight {
                    Text(GoalSetupFormat.change(from: weight, to: draft.desired, unit: draft.weightUnit))
                        .font(look.font.subhead.weight(.semibold))
                        .foregroundStyle(look.textSecondary)
                }
                HStack(spacing: 16) {
                    StepCapsule(symbol: "minus", label: "Less") { move { draft.stepDesired(by: -1) } }
                    StepCapsule(symbol: "plus", label: "More") { move { draft.stepDesired(by: 1) } }
                }
                if draft.desiredAtLowest {
                    Text("The lowest healthy weight for your height.")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .lookSurface(.panel)
        }
    }

    private var pacePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question(draft.goal == .gain ? "How fast do you want to gain?" : "How fast do you want to lose?")
            if let paces = draft.paces {
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(GoalSetupFormat.pace(draft.paceKg, unit: draft.weightUnit))
                            .font(look.font.heroNumber)
                            .foregroundStyle(look.textPrimary)
                            .contentTransition(.numericText(value: draft.paceKg))
                            .accessibilityIdentifier("goalSetupPace")
                        Text("\(draft.weightUnit.rawValue) a week")
                            .font(look.font.headline.weight(.medium))
                            .foregroundStyle(look.textSecondary)
                    }
                    .padding(.top, 8)
                    if paces.fast > paces.slow {
                        Slider(value: $draft.paceKg, in: paces.slow...paces.fast,
                               step: GoalPlan.paceStepKg(draft.weightUnit)) { Text("Weekly pace") }
                            .tint(look.action)
                            .accessibilityLabel("Weekly pace")
                            .accessibilityIdentifier("goalSetupPaceSlider")
                            .accessibilityValue("\(GoalSetupFormat.pace(draft.paceKg, unit: draft.weightUnit)) \(draft.weightUnit.rawValue) a week")
                    }
                    paceStops(paces)
                    if paces.heldByFloor {
                        Text("Held so your calories stay at or above \(GoalSetupFormat.calories(NutritionGoals.calorieFloor(draft.sex ?? .unspecified))) a day.")
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .lookSurface(.panel)
                .padding(.bottom, look.space.section)
                paceOutcome
            }
        }
    }

    /// Slow / Recommended / Fast: equal options under the slider, the chosen one in the selection state; stacked at
    /// accessibility sizes so no name truncates.
    private func paceStops(_ paces: GoalPlan.Paces) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { paceStopButtons(paces) }
            VStack(spacing: 8) { paceStopButtons(paces) }
        }
    }

    @ViewBuilder private func paceStopButtons(_ paces: GoalPlan.Paces) -> some View {
        let stops: [(String, Double)] = [("Slow", paces.slow), ("Recommended", paces.recommended), ("Fast", paces.fast)]
        ForEach(stops, id: \.0) { title, value in
            let selected = abs(draft.paceKg - value) < 0.001
            Button { move { draft.paceKg = value } } label: {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(selected ? look.onAction : look.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(selected ? look.action : look.ground.opacity(0.6), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("goalSetupPace\(title)")
        }
    }

    /// The live outcome: when the desired weight is reached and the calories it takes (two equal stats).
    private var paceOutcome: some View {
        GoalSetupStats(items: [
            ("Goal reached", draft.arrival.map(GoalSetupFormat.date) ?? "—",
             draft.weeks.map(GoalSetupFormat.weeks)),
            ("Daily calories", draft.calculatedCalories.map(GoalSetupFormat.calories) ?? "—", nil),
        ])
    }

    private var planPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            question(draft.isGenerating ? "Making your plan" : "Your plan is ready", planSummary)
            if draft.isGenerating {
                generatingPanel
            } else if let plan = draft.plan {
                planNumbers(plan)
                if draft.generationFailed {
                    Text("Couldn't reach the server, so this plan was calculated on your phone.")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .accessibilityIdentifier("goalSetupCalculatedFallback")
                }
            }
            if draft.overrides != .none {
                Button("Recalculate") { move { draft.overrides = .none } }
                    .buttonStyle(.borderless)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("goalSetupRecalculate")
            }
            Text("An estimate from your details, not medical advice.")
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .padding(.top, 14)
        }
    }

    /// "Lose 6.4 kg by Mar 14, 2027" / "Stay at 82.4 kg".
    private var planSummary: String {
        guard let weight = draft.weight, let goal = draft.goal else { return "" }
        let unit = draft.weightUnit.rawValue
        switch goal {
        case .maintain:
            return "Stay at \(GoalSetupFormat.number(weight)) \(unit)"
        case .lose, .gain:
            let amount = GoalSetupFormat.number(abs(weight - draft.desired))
            let verb = goal == .lose ? "Lose" : "Gain"
            let date = draft.arrival.map { " by \(GoalSetupFormat.date($0))" } ?? ""
            return "\(verb) \(amount) \(unit)\(date)"
        }
    }

    private func planNumbers(_ plan: Macros) -> some View {
        PlanNumbersPanel(plan: plan, overrides: draft.overrides, generated: draft.generatedPlan != nil) { editing = $0 }
    }

    /// While the server works: the panel's place, a spinner and one line (no numbers to edit yet).
    private var generatingPanel: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Working out your calories and macros…")
                .font(look.font.subhead.weight(.semibold))
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(18)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goalSetupGenerating")
    }

    @ViewBuilder private func editor(_ number: NutritionGoalsView.Number) -> some View {
        switch number {
        case .calories:
            NumberEditorSheet(title: "Calories", unit: "cal a day", initial: draft.plan?.calories,
                              range: 500...10_000, fieldID: "goalCaloriesField") { value in
                draft.overrides.calories = value.rounded()
            }
        case .macro(let macro):
            NumberEditorSheet(title: macro.name, unit: "g", initial: draft.plan.map(macro.grams(of:)),
                              range: 0...1_000, fieldID: "goal\(macro.name)Field") { value in
                switch macro {
                case .protein: draft.overrides.proteinGrams = value.rounded()
                case .carbs: draft.overrides.carbsGrams = value.rounded()
                case .fat: draft.overrides.fatGrams = value.rounded()
                }
            }
        }
    }
}

// MARK: - Pieces

/// Equal choices as rows of one list: the chosen row checked in the action colour (a state).
private struct OptionList<Value: Hashable>: View {
    var options: [(Value, String, String?, String?)]
    @Binding var selection: Value?
    var idPrefix: String
    @Environment(\.look) private var look

    var body: some View {
        LookList(separatorInset: options.contains { $0.3 != nil } ? 54 : 16) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let (value, title, subtitle, symbol) = option
                let selected = selection == value
                LookRow(title, subtitle: subtitle, symbol: symbol, symbolTint: selected ? look.action : nil,
                        showsChevron: false, action: { selection = value }) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(selected ? look.action : look.textTertiary)
                        .accessibilityHidden(true)
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("\(idPrefix).\(String(describing: value))")
            }
        }
    }
}

/// A weight figure to type over, with − / + steps (the Log weight sheet's pattern).
private struct FigureStepper: View {
    @Binding var text: String
    var unit: String
    var fieldID: String
    var onStep: (Double) -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", text: $text)
                    .font(look.font.heroNumber)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .foregroundStyle(look.textPrimary)
                    // codex-review-n13 R3: the quantity being edited, not the "0" placeholder.
                    .accessibilityLabel("Current weight, \(unit)")
                    .accessibilityIdentifier(fieldID)
                Text(unit).font(look.font.headline.weight(.medium)).foregroundStyle(look.textSecondary)
            }
            HStack(spacing: 16) {
                StepCapsule(symbol: "minus", label: "Less") { onStep(-1) }
                StepCapsule(symbol: "plus", label: "More") { onStep(1) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .lookSurface(.panel)
    }
}

private struct StepCapsule: View {
    var symbol: String
    var label: String
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(.title3, weight: .semibold)).foregroundStyle(look.textPrimary)
                .frame(width: 64, height: 52)
                .background(look.ground.opacity(0.6), in: Capsule())
                .overlay { Capsule().strokeBorder(look.hairline) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Two or three equal stats in one panel (a figure and its small label).
struct GoalSetupStats: View {
    var items: [(String, String, String?)]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            ForEach(items, id: \.0) { label, value, detail in
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(look.font.footnote).foregroundStyle(look.textSecondary)
                    Text(value)
                        .font(look.font.statNumber)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let detail {
                        Text(detail).font(look.font.footnote).foregroundStyle(look.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }
}

/// The plan's numbers: the calories as the hero, the three macros as equal tiles; each opens its editor (the Nutrition
/// goals screen's panel, N3).
struct PlanNumbersPanel: View {
    var plan: Macros
    var overrides: NutritionGoals.Overrides
    /// N14: the untyped numbers came from the server's plan ("Generated") rather than the calculation.
    var generated = false
    var onEdit: (NutritionGoalsView.Number) -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { onEdit(.calories) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(plan.calories.formatted(.number.precision(.fractionLength(0))))
                            .font(look.font.heroNumber)
                            .foregroundStyle(look.textPrimary)
                            .contentTransition(.numericText(value: plan.calories))
                        Text("cal a day")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                        Spacer(minLength: 8)
                        pencil
                    }
                    Text(overrides.calories != nil ? "Typed by you" : (generated ? "Generated" : "Calculated"))
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("goalSetupCalories")
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                ForEach(MacroKind.allCases) { macro in tile(macro) }
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }

    private func tile(_ macro: MacroKind) -> some View {
        Button { onEdit(.macro(macro)) } label: {
            VStack(alignment: .leading, spacing: 8) {
                MacroGlyph(macro: macro)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(macro.grams(of: plan).formatted(.number.precision(.fractionLength(0))))
                        .font(look.font.statNumber)
                        .foregroundStyle(look.textPrimary)
                    Text("g").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
                Text(macro.name).font(look.font.footnote).foregroundStyle(look.textSecondary)
                if typed(macro) {
                    Text("Typed by you").font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(look.ground.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("goalSetup.\(macro.name)")
    }

    private func typed(_ macro: MacroKind) -> Bool {
        switch macro {
        case .protein: overrides.proteinGrams != nil
        case .carbs: overrides.carbsGrams != nil
        case .fat: overrides.fatGrams != nil
        }
    }

    private var pencil: some View {
        Image(systemName: "pencil")
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textTertiary)
            .accessibilityHidden(true)
    }
}

/// The setup's number formats (as entered; D52 plain conversions).
enum GoalSetupFormat {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// kg a week shown in the weight's unit: 0.4 (kg), 0.9 (lb).
    static func pace(_ kg: Double, unit: WeightUnit) -> String {
        let value = WeightMath.convert(kg, from: .kg, to: unit)
        return value.formatted(.number.precision(.fractionLength(unit == .kg ? 1...2 : 1...1)))
    }

    static func change(from current: Double, to desired: Double, unit: WeightUnit) -> String {
        let difference = desired - current
        let sign = difference < 0 ? "−" : "+"
        return "\(sign)\(number(abs(difference))) \(unit.rawValue) from now"
    }

    static func calories(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) cal"
    }

    static func date(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day().year()) }

    static func weeks(_ weeks: Double) -> String {
        let whole = Int(weeks.rounded(.up))
        return whole == 1 ? "in 1 week" : "in \(whole) weeks"
    }
}
