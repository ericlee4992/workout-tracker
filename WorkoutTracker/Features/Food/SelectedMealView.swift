import SwiftData
import SwiftUI

/// Nutrition N4 — one of My meals, opened from its row: its total, its foods, Log. Edit (the Create meal form, filled
/// in) and Delete Meal… (in the "…" menu, like a template's) sit in the bar (the user, 2026-11-10: meals can be edited
/// and deleted). Entries already logged from the meal stay through either.
///
/// The eye lands on the meal's calories (the hero); Log is the one primary command at the bottom.
struct SelectedMealView: View {
    var savedMeal: SavedMeal
    var meal: MealSlot
    var onLogged: (FoodLogReceipt) -> Void
    var onDeleted: () -> Void
    @Environment(\.look) private var look
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var confirmingDelete = false
    /// Set BEFORE the meal is deleted, so a re-evaluation after the save never renders a deleted model (as
    /// TemplateDetailView, codex-review-15).
    @State private var deleted = false
    @State private var failure: String?

    var body: some View {
        Group {
            if deleted { Color.clear } else { content }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
                    .font(.system(.body, weight: .semibold))
                    .accessibilityIdentifier("selectedMealEdit")
                    .disabled(deleted)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Meal…", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                        .accessibilityIdentifier("deleteMeal")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("selectedMealMore")
                .disabled(deleted)
            }
        }
        .alert("Delete Meal", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            // The consequence, in one line: the meal goes, what was logged from it stays.
            Text("Food already logged from it is kept.")
        }
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .navigationDestination(isPresented: $editing) { CreateMealView(editing: savedMeal) { editing = false } }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(savedMeal.name, subtitle: savedMeal.usualMeal.map { "Usually for \($0.label)" })
                    MacroSummary(macros: savedMeal.macros)
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Foods")
                        LookList(separatorInset: 16) {
                            ForEach(savedMeal.orderedItems) { item in
                                LookRow(item.name,
                                        subtitle: "\(FoodCopy.calories(item.calories * item.servings)) · \(item.servingText)",
                                        value: "×\(FoodNumber.text(item.servings))", showsChevron: false)
                            }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Log to \(meal.label)") {
                do { onLogged(try FoodLog.log(savedMeal, meal: meal, in: context)) }
                catch { failure = error.localizedDescription }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 10)
            .accessibilityIdentifier("selectedMealLog")
        }
    }

    private func delete() {
        deleted = true
        do {
            try FoodLog.delete(savedMeal, in: context)
            onDeleted()
        } catch {
            deleted = false
            failure = error.localizedDescription
        }
    }
}
