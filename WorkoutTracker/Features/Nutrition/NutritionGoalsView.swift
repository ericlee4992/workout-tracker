import SwiftUI

/// Nutrition N3 — Profile → Goals & tracking → Nutrition goals. **MOCK for the user's review:** sample inputs in local
/// state, nothing saved; the numbers are the real calculation (`NutritionGoals`). Wired to Personal details and a dated
/// `NutritionGoal` after the user approves the screen and its strings.
///
/// In this screen's one state the eye lands on the calorie figure (the hero); the three macros sit under it as equal
/// tiles; the two choices the goal is "based on" (activity, goal) are rows below, with Personal details one tap away.
struct NutritionGoalsView: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    // Sample inputs (mock).
    @State private var inputs = NutritionGoals.Inputs(weightKg: 80, heightCm: 180, ageYears: 30, sex: .male,
                                                      activity: .moderate, goal: .maintain)
    @State private var overrides = NutritionGoals.Overrides.none

    private var goal: Macros { NutritionGoals.resolve(inputs, overrides: overrides) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Nutrition goals")
                numbers
                basedOn
                if overrides != .none {
                    Button("Recalculate") { withAnimation(.snappy) { overrides = .none } }
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
    }

    // MARK: The numbers (the bold element: calories)

    private var numbers: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(goal.calories.formatted(.number.precision(.fractionLength(0))))
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText(value: goal.calories))
                    Text("cal a day")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    Spacer(minLength: 8)
                    editMark(typed: overrides.calories != nil)
                }
                Text(overrides.calories == nil ? "Calculated" : "Typed by you")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("nutritionGoalsCalories")
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                ForEach(MacroKind.allCases) { macro in
                    macroTile(macro)
                }
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }

    private func macroTile(_ macro: MacroKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MacroGlyph(macro: macro)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(macro.grams(of: goal).formatted(.number.precision(.fractionLength(0))))
                    .font(look.font.statNumber)
                    .foregroundStyle(look.textPrimary)
                Text("g").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
            }
            Text(macro.name).font(look.font.footnote).foregroundStyle(look.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(look.ground.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nutritionGoals.\(macro.name)")
    }

    private func editMark(typed: Bool) -> some View {
        Image(systemName: "pencil")
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textTertiary)
            .accessibilityHidden(true)
    }

    // MARK: Based on

    private var basedOn: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Based on")
            LookList(separatorInset: 54) {
                ProfileRow("Activity", symbol: "figure.walk", value: activityName(inputs.activity)) {}
                ProfileRow("Goal", symbol: "flag", value: goalName(inputs.goal)) {}
                ProfileRow("Personal details", symbol: "person.text.rectangle", value: "80 kg · 180 cm · 30") {}
            }
        }
    }

    private func activityName(_ activity: ActivityLevel) -> String {
        switch activity {
        case .sedentary: "Sedentary"
        case .light: "Light"
        case .moderate: "Moderate"
        case .veryActive: "Very active"
        case .extraActive: "Extra active"
        }
    }

    private func goalName(_ goal: WeightGoal) -> String {
        switch goal {
        case .lose: "Lose weight"
        case .maintain: "Maintain"
        case .gain: "Gain weight"
        }
    }
}
