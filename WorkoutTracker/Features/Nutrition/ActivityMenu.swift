import SwiftUI

/// Activity as a menu showing its value (Nutrition goals). The owner applies a change; before Personal details are
/// complete it holds the choice for the first goal. N13 (D84): the goal itself is set by the goal setup (the Goal weight
/// row), so its menu is gone.
struct ActivityMenu: View {
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
    }
}
