import SwiftUI

/// Nutrition N4 — Create meal (the user, 2026-11-10): makes one of **My meals** from the bottom of that tab, the same
/// pattern as Add food on My foods. One screen: the meal's name, the foods in it (each with its servings), and the
/// user's foods to add with a + (adding one again adds a serving). **MOCK for the user's review**: nothing is stored.
/// Later N5 adds "Save as meal" to a meal on Today.
///
/// The eye lands on the meal's foods and their total; the + on each food below is the action; Save meal is the one
/// primary command at the bottom.
struct CreateMealView: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var name = ""
    @State private var items: [(food: MockFood, servings: Double)] = []
    @State private var search = ""

    private var candidates: [MockFood] {
        let foods = MockFood.all
        guard !search.isEmpty else { return foods }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var totalCalories: Double { items.reduce(0) { $0 + $1.food.calories * $1.servings } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Create meal")
                    LookList(separatorInset: 16) {
                        FoodFormField("Name", text: $name, prompt: "e.g. Usual breakfast")
                    }
                    if !items.isEmpty { mealFoods }
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Add foods")
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(look.textSecondary)
                            TextField("Search your foods", text: $search)
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
            PrimaryButton("Save meal") {}
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .disabled(items.isEmpty)
                .opacity(items.isEmpty ? 0.4 : 1)
                .accessibilityIdentifier("createMealSave")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mealFoods: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Foods", trailing: "\(totalCalories.formatted(.number.precision(.fractionLength(0)))) cal")
            LookList(separatorInset: 16) {
                ForEach(items.indices, id: \.self) { index in itemRow(index) }
            }
        }
        .transition(.opacity)
    }

    private func itemRow(_ index: Int) -> some View {
        let item = items[index]
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.food.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                Text("\((item.food.calories * item.servings).formatted(.number.precision(.fractionLength(0)))) cal · \(item.food.serving)")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                stepButton(item.servings <= 0.5 ? "trash" : "minus",
                           label: item.servings <= 0.5 ? "Remove \(item.food.name)" : "Fewer servings") {
                    if items[index].servings <= 0.5 { items.remove(at: index) } else { items[index].servings -= 0.5 }
                }
                Text(item.servings.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.system(.headline, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 28)
                    .accessibilityLabel("\(item.servings.formatted()) servings")
                stepButton("plus", label: "More servings") { items[index].servings += 0.5 }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityIdentifier("createMealItem.\(item.food.name)")
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

    private func candidateRow(_ food: MockFood) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                Text([food.brand, "\(food.calories.formatted()) cal", food.serving].compactMap(\.self)
                    .joined(separator: " · "))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.snappy) {
                    if let index = items.firstIndex(where: { $0.food == food }) {
                        items[index].servings += 1
                    } else {
                        items.append((food, 1))
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
