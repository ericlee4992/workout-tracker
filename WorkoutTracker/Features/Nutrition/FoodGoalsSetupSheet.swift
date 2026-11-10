import SwiftData
import SwiftUI

/// Nutrition N3 — the onboarding step (the user, 2026-11-09: "Both" — this for new installs, Today's invitation in N5
/// for everyone). Shown once after the Welcome page is answered, when there is no goal yet. Personal details, Activity
/// and Goal, and the calculated calories once the details are complete. Every row saves as it changes, so the sheet
/// offers Done (ios-design: a sheet whose edits apply immediately). Skippable by Done or a swipe; the goals stay in
/// Profile.
struct FoodGoalsSetupSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Query private var goals: [NutritionGoal]
    @Query private var allPreferences: [AppPreferences]
    @Query private var weights: [BodyWeightEntry]
    @State private var saveFailure: String?
    /// Choices made before Personal details are complete (no goal to hold them yet); applied to the first goal.
    @State private var pending: NutritionGoalStore.Choices?

    private var current: NutritionGoal? {
        goals.max { ($0.effectiveFrom, $0.createdAt, $0.id.uuidString) < ($1.effectiveFrom, $1.createdAt, $1.id.uuidString) }
    }

    private var hasDetails: Bool {
        let preferences = AppPreferences.canonical(of: allPreferences)
        return !weights.isEmpty && preferences?.heightCm != nil && preferences?.birthDate != nil && preferences?.sex != nil
    }

    private var choices: NutritionGoalStore.Choices {
        hasDetails ? NutritionGoalStore.choices(of: current) : pending ?? NutritionGoalStore.choices(of: current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Nutrition goals")
                    if hasDetails, let current {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(current.calories.formatted(.number.precision(.fractionLength(0))))
                                .font(look.font.heroNumber)
                                .foregroundStyle(look.textPrimary)
                                .contentTransition(.numericText(value: current.calories))
                            Text("cal a day")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("foodGoalsCalories")
                    }
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Personal details")
                        PersonalDetailsList()
                    }
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Based on")
                        LookList(separatorInset: 54) {
                            GoalChoiceMenus(choices: choices) { apply in change(apply) }
                        }
                    }
                    Text("An estimate from your details, not medical advice.")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .lookScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("foodGoalsDone")
                }
            }
            .alert("Couldn't save", isPresented: Binding(get: { saveFailure != nil }, set: { if !$0 { saveFailure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(saveFailure ?? "") }
            .onChange(of: hasDetails) { _, complete in
                if complete, let pending { change { $0 = pending } }  // every held choice, Recalculate (no overrides) too
            }
        }
    }

    private func change(_ apply: (inout NutritionGoalStore.Choices) -> Void) {
        guard hasDetails else {
            var held = pending ?? NutritionGoalStore.choices(of: current)
            apply(&held)
            pending = held
            return
        }
        do {
            try withoutActuallyEscaping(apply) { try NutritionGoalStore.update(in: modelContext, change: $0) }
            pending = nil
        } catch {
            saveFailure = error.localizedDescription
        }
    }
}

/// Activity and Goal as menus showing their values (Nutrition goals and the onboarding sheet). The owner applies a
/// change; before Personal details are complete it holds the choice for the first goal.
struct GoalChoiceMenus: View {
    var choices: NutritionGoalStore.Choices
    var change: ((inout NutritionGoalStore.Choices) -> Void) -> Void

    var body: some View {
        Menu {
            Picker("Activity", selection: Binding(get: { choices.activity },
                                                  set: { value in change { $0.activity = value } })) {
                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        } label: {
            ProfileRow("Activity", symbol: "figure.walk", value: choices.activity.label, action: nil)
        }
        .accessibilityIdentifier("nutritionGoalsActivity")
        Menu {
            Picker("Goal", selection: Binding(get: { choices.goal },
                                              set: { value in change { $0.goal = value } })) {
                ForEach(WeightGoal.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        } label: {
            ProfileRow("Goal", symbol: "flag", value: choices.goal.label, action: nil)
        }
        .accessibilityIdentifier("nutritionGoalsGoal")
    }
}
