import SwiftData
import SwiftUI

/// Nutrition N4 — Create meal (the user, 2026-11-10): makes one of **My meals** from the bottom of that tab, the same
/// pattern as Add food on My foods. One screen: the meal's name, the meal it is usually for (Any, or one of the four;
/// that meal's own lead My meals while it is chosen), the foods in it (each with its servings), and the user's foods to
/// add with a + (adding one again adds a serving). As **Edit meal** it opens filled in from a meal's page; entries already
/// logged from the meal stay as they were. **MOCK for the user's review**: nothing is stored.
/// Later N5 adds "Save as meal" to a meal on Today.
///
/// The eye lands on the meal's foods and their total; the + on each food below is the action; Save meal is the one
/// primary command at the bottom.
struct CreateMealView: View {
    var editing: SavedMeal?
    var onSaved: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.modelContext) private var context
    @Query private var foods: [SavedFood]
    @State private var name: String
    @State private var usual: MealSlot?
    @State private var items: [MealDraftItem]
    @State private var search = ""
    @State private var failure: String?

    init(editing: SavedMeal? = nil, onSaved: @escaping () -> Void) {
        self.editing = editing
        self.onSaved = onSaved
        _name = State(initialValue: editing?.name ?? "")
        _usual = State(initialValue: editing?.usualMeal)
        _items = State(initialValue: editing?.orderedItems.map(MealDraftItem.init(item:)) ?? [])
    }

    private var candidates: [SavedFood] { FoodLog.matching(FoodLog.all(foods), search) }

    private var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }

    private var canSave: Bool { !items.isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(editing == nil ? "Create meal" : "Edit meal")
                    LookList(separatorInset: 16) {
                        FoodFormField("Name", text: $name, prompt: "e.g. Usual breakfast", identifier: "createMealName")
                    }
                    usualFor
                    if !items.isEmpty { mealFoods }
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Add foods")
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(look.textSecondary)
                            TextField("Search your foods", text: $search)
                                .accessibilityIdentifier("createMealSearch")
                        }
                        .padding(14)
                        .lookSurface(.panel)
                        LookList(separatorInset: 16) {
                            ForEach(candidates) { food in candidateRow(food) }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            PrimaryButton("Save meal") {
                do {
                    try FoodLog.saveMeal(editing, name: name, usualMeal: usual, items: items, in: context)
                    onSaved()
                } catch {
                    failure = error.localizedDescription
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 10)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
            .accessibilityIdentifier("createMealSave")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private var usualFor: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Usually for")
            WrapLayout(spacing: 8, lineSpacing: 8) {
                Chip("Any", isSelected: usual == nil) { usual = nil }
                    .accessibilityIdentifier("createMealUsual.any")
                ForEach(MealSlot.allCases) { slot in
                    Chip(slot.label, isSelected: usual == slot) { usual = slot }
                        .accessibilityIdentifier("createMealUsual.\(slot.rawValue)")
                }
            }
        }
    }

    private var mealFoods: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Foods", trailing: FoodCopy.calories(totalCalories))
            LookList(separatorInset: 16) {
                ForEach(items) { item in itemRow(item) }
            }
        }
        .transition(.opacity)
    }

    private func itemRow(_ item: MealDraftItem) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                Text("\(FoodCopy.calories(item.calories)) · \(ServingText.format(value: item.servingValue, unit: item.servingUnit, grams: item.servingGrams))")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                stepButton(item.servings <= 0.5 ? "trash" : "minus",
                           label: item.servings <= 0.5 ? "Remove \(item.name)" : "Fewer servings") {
                    guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
                    if items[index].servings <= 0.5 { items.remove(at: index) } else { items[index].servings -= 0.5 }
                }
                Text(item.servings.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.system(.headline, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 28)
                    .accessibilityLabel("\(item.servings.formatted()) servings")
                stepButton("plus", label: "More servings") {
                    guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
                    items[index].servings += 0.5
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("createMealItem.\(item.name)")
    }

    private func stepButton(_ symbol: String, label: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Image(systemName: symbol).font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: 44, height: 44)
                .background(look.ground, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func candidateRow(_ food: SavedFood) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                Text(FoodCopy.foodLine(brand: food.brand, calories: food.calories, serving: food.servingText))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.snappy) {
                    if let index = items.firstIndex(where: { $0.savedFood?.persistentModelID == food.persistentModelID }) {
                        items[index].servings += 1
                    } else {
                        items.append(MealDraftItem(food: food))
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(look.ground, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(food.name) to the meal")
            .accessibilityIdentifier("createMealAdd.\(food.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
