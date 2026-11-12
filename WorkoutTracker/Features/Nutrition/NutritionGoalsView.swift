import SwiftData
import SwiftUI

/// Nutrition N3 — Profile → Goals & tracking → Nutrition goals (mock approved by the user 2026-11-09). N14 (D85, the
/// user 2026-11-12): the numbers and one command, Generate Goals, which runs the goal setup (prefilled); the Personal
/// details, Activity and Goal weight rows are gone (Personal details stays in Profile → Settings).
///
/// The eye lands on the calorie figure (the hero); the three macros sit under it as equal tiles; Generate Goals under
/// them. Tapping a number opens a small editor (the user's choice); a typed number reads "Typed by you", the server's
/// "Generated", and Recalculate (back to the calculation) appears. Every change is stored through `NutritionGoalStore`
/// (a dated goal: past days keep theirs). Without complete Personal details there is nothing to show: Generate Goals
/// alone, which collects them.
struct NutritionGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var goals: [NutritionGoal]
    @Query private var allPreferences: [AppPreferences]
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var weights: [BodyWeightEntry]
    @State private var editing: Number?
    /// N13 (D84): the goal setup, run from the Goal weight row, prefilled.
    @State private var setup: GoalSetupDraft?
    @State private var saveFailure: String?
    @Environment(AccountStore.self) private var account

    enum Number: Identifiable, Hashable {
        case calories
        case macro(MacroKind)
        var id: Self { self }
    }

    private var current: NutritionGoal? {
        goals.max { ($0.effectiveFrom, $0.createdAt, $0.id.uuidString) < ($1.effectiveFrom, $1.createdAt, $1.id.uuidString) }
    }

    private var choices: NutritionGoalStore.Choices { NutritionGoalStore.choices(of: current) }

    private var macros: Macros? {
        current.map { Macros(calories: $0.calories, proteinGrams: $0.proteinGrams, carbsGrams: $0.carbsGrams,
                             fatGrams: $0.fatGrams) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Nutrition goals")
                // Without complete details nothing can be calculated or edited (codex-review-n3): no numbers.
                if hasDetails, let macros { numbers(macros) }
                // N14 (D85): one command — the goal setup, prefilled; its plan comes from the server when signed in.
                PrimaryButton("Generate Goals", symbol: "sparkles", action: openSetup)
                    .accessibilityIdentifier("nutritionGoalsGenerate")
                if hasDetails && (choices.overrides != .none || choices.generated != nil) {
                    Button("Recalculate") { change { $0.overrides = .none; $0.generated = nil } }
                        .buttonStyle(.borderless)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("nutritionGoalsRecalculate")
                }
                Text("An estimate from your details, not medical advice.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        // Personal details may have changed since the goal was stored (e.g. a new day's age): bring it up to date.
        .task { refresh() }
        .fullScreenCover(item: $setup) { draft in
            GoalSetupFlow(draft: draft, onFinish: saveSetup, onClose: { setup = nil }, onTour: nil,
                          generator: GoalPlanService.generator(account))
                .lookLayer()
                .alert("Couldn't save", isPresented: Binding(get: { saveFailure != nil },
                                                             set: { if !$0 { saveFailure = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: { Text(saveFailure ?? "") }
        }
        .sheet(item: $editing) { number in editor(number) }
        .alert("Couldn't save", isPresented: Binding(get: { saveFailure != nil }, set: { if !$0 { saveFailure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveFailure ?? "") }
    }

    // MARK: The numbers (the bold element: calories)

    private func numbers(_ macros: Macros) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { editing = .calories } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(macros.calories.formatted(.number.precision(.fractionLength(0))))
                            .font(look.font.heroNumber)
                            .foregroundStyle(look.textPrimary)
                            .contentTransition(.numericText(value: macros.calories))
                        Text("cal a day")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                        Spacer(minLength: 8)
                        pencil
                    }
                    Text(choices.overrides.calories != nil ? "Typed by you"
                         : (choices.generated != nil ? "Generated" : "Calculated"))
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("nutritionGoalsCalories")
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                ForEach(MacroKind.allCases) { macro in
                    macroTile(macro, grams: macro.grams(of: macros))
                }
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }

    private func macroTile(_ macro: MacroKind, grams: Double) -> some View {
        Button { editing = .macro(macro) } label: {
            VStack(alignment: .leading, spacing: 8) {
                MacroGlyph(macro: macro)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(grams.formatted(.number.precision(.fractionLength(0))))
                        .font(look.font.statNumber)
                        .foregroundStyle(look.textPrimary)
                    Text("g").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                }
                Text(macro.name).font(look.font.footnote).foregroundStyle(look.textSecondary)
                if typed(macro) != nil {
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
        .accessibilityIdentifier("nutritionGoals.\(macro.name)")
    }

    private var pencil: some View {
        Image(systemName: "pencil")
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textTertiary)
            .accessibilityHidden(true)
    }

    private func typed(_ macro: MacroKind) -> Double? {
        switch macro {
        case .protein: choices.overrides.proteinGrams
        case .carbs: choices.overrides.carbsGrams
        case .fat: choices.overrides.fatGrams
        }
    }

    private func openSetup() {
        do { setup = GoalSetupDraft(prefill: try GoalSetupStore.prefill(in: modelContext)) }
        catch { saveFailure = error.localizedDescription }
    }

    private func saveSetup(_ answers: GoalSetupStore.Answers) {
        do {
            try GoalSetupStore.commit(answers, in: modelContext)
            setup = nil
        } catch {
            saveFailure = error.localizedDescription
        }
    }

    private var hasDetails: Bool { detailsSummary != "Not set" }

    /// "80 kg · 180 cm · 30" — as entered; "Not set" until every detail is there.
    private var detailsSummary: String {
        let preferences = AppPreferences.canonical(of: allPreferences)
        guard let weight = weights.first, let value = preferences?.heightValue, let unit = preferences?.heightUnit,
              let birthDate = preferences?.birthDate, preferences?.sex != nil
        else { return "Not set" }
        return [DetailFormat.weight(weight), DetailFormat.height(value: value, unit: unit),
                "\(NutritionGoals.age(birthDate: birthDate, on: .now))"].joined(separator: " · ")
    }

    // MARK: Editing

    @ViewBuilder private func editor(_ number: Number) -> some View {
        switch number {
        case .calories:
            NumberEditorSheet(title: "Calories", unit: "cal a day", initial: macros?.calories,
                              range: 500...10_000, fieldID: "goalCaloriesField") { value in
                change { $0.overrides.calories = value.rounded() }
            }
        case .macro(let macro):
            NumberEditorSheet(title: macro.name, unit: "g", initial: macros.map(macro.grams(of:)),
                              range: 0...1_000, fieldID: "goal\(macro.name)Field") { value in
                change { choices in
                    switch macro {
                    case .protein: choices.overrides.proteinGrams = value.rounded()
                    case .carbs: choices.overrides.carbsGrams = value.rounded()
                    case .fat: choices.overrides.fatGrams = value.rounded()
                    }
                }
            }
        }
    }

    /// Brings the stored goal up to date with Personal details (a new day's age, a weight logged elsewhere).
    private func refresh() {
        do { try NutritionGoalStore.update(in: modelContext) } catch { saveFailure = error.localizedDescription }
    }

    private func change(_ apply: (inout NutritionGoalStore.Choices) -> Void) {
        guard hasDetails else { return }  // nothing shown to change without details (the numbers are absent)
        do {
            try withoutActuallyEscaping(apply) { try NutritionGoalStore.update(in: modelContext, change: $0) }
        } catch {
            saveFailure = error.localizedDescription
        }
    }
}
