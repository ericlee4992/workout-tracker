import SwiftUI

/// Nutrition N4 — one of My meals, opened from its row: its total, its foods, Log. **MOCK for the user's review.**
/// Edit (the Create meal form, filled in) and Delete Meal… (in the "…" menu, like a template's) sit in the bar (the
/// user, 2026-11-10: meals can be edited and deleted).
///
/// The eye lands on the meal's calories (the hero); Log is the one primary command at the bottom.
struct SelectedMealView: View {
    var savedMeal: MockMeal
    var meal: MealSlot
    @Environment(\.look) private var look
    @State private var editing = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(savedMeal.name, subtitle: savedMeal.usual.map { "Usually for \($0.label)" })
                    MacroSummary(macros: savedMeal.macros)
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Foods")
                        LookList(separatorInset: 16) {
                            ForEach(savedMeal.items, id: \.food) { item in
                                LookRow(item.food.name,
                                        subtitle: "\((item.food.calories * item.servings).formatted(.number.precision(.fractionLength(0)))) cal · \(item.food.serving)",
                                        value: "×\(item.servings.formatted())", showsChevron: false)
                            }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Log to \(meal.label)") {}
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("selectedMealLog")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
                    .font(.system(.body, weight: .semibold))
                    .accessibilityIdentifier("selectedMealEdit")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Meal…", systemImage: "trash", role: .destructive) {}
                        .accessibilityIdentifier("deleteMeal")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("selectedMealMore")
            }
        }
        .navigationDestination(isPresented: $editing) { CreateMealView(editing: savedMeal) }
    }
}
