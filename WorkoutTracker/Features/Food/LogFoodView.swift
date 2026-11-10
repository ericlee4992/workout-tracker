import SwiftUI

/// Nutrition N4 — Log Food, opened by Today's "Log food" pill. **MOCK for the user's review** (sample foods, nothing
/// stored). Laid out like the approved prototype (`SoftLogFoodScreen`): the meal, tabs (All / My foods / My meals /
/// Saved), a search over the user's own foods, "Recently logged" with a one-tap + (one serving, with Undo), and Manual
/// Add / Quick Add at the bottom (Voice Log is out of scope).
///
/// The eye lands on the recent list (what most logs are); the + on each row is the action, quiet until tapped.
struct LogFoodView: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var meal = MealSlot.forTime(.now)
    @State private var tab = 0
    @State private var search = ""
    @State private var added: Set<String> = []
    @State private var undo: MockFood?
    @State private var addMode: AddMode?
    @State private var selected: MockFood?

    enum AddMode: Identifiable { case manual, quick; var id: Self { self } }

    private let tabs = ["All", "My foods", "My meals", "Saved"]

    private var foods: [MockFood] {
        let base = tab == 3 ? MockFood.recent.filter(\.saved) : MockFood.recent
        guard !search.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Log food")
                    mealChips
                    tabBar
                    searchField
                    if tab == 2 { myMeals } else { recent }
                    // At accessibility sizes the two stacked buttons scroll with the list: pinned, they left room for one
                    // food row.
                    if typeSize.isAccessibilitySize { bottomButtons.padding(.horizontal, -look.space.margin) }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            if !typeSize.isAccessibilitySize { bottomButtons }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { if let undo { undoToast(undo) } }
        .navigationDestination(item: $selected) { SelectedFoodView(food: $0, meal: meal) }
        .navigationDestination(item: $addMode) { ManualAddView(quick: $0 == .quick, meal: meal) }
    }

    private var mealChips: some View {
        WrapLayout(spacing: 8, lineSpacing: 8) {
            ForEach(MealSlot.allCases) { slot in
                Chip(slot.label, isSelected: meal == slot) { meal = slot }
                    .accessibilityIdentifier("logFoodMeal.\(slot.rawValue)")
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 22) {
                ForEach(tabs.indices, id: \.self) { index in
                    Button { withAnimation(.snappy) { tab = index } } label: {
                        VStack(spacing: 8) {
                            Text(tabs[index])
                                .font(.system(.body, weight: tab == index ? .semibold : .medium))
                                .foregroundStyle(tab == index ? look.textPrimary : look.textSecondary)
                            Capsule().fill(tab == index ? look.textPrimary : .clear).frame(height: 2)
                        }
                        .fixedSize()
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tab == index ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(look.textSecondary)
            TextField("Search your foods", text: $search)
                .accessibilityIdentifier("logFoodSearch")
        }
        .padding(14)
        .lookSurface(.panel)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(tab == 3 ? "Saved" : tab == 1 ? "My foods" : "Recently logged")
            LookList(separatorInset: 16) {
                ForEach(foods) { food in foodRow(food) }
            }
        }
    }

    private func foodRow(_ food: MockFood) -> some View {
        HStack(spacing: 12) {
            Button { selected = food } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                    Text("\(food.calories.formatted()) cal · \(food.serving)")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("logFoodRow.\(food.name)")
            Button {
                withAnimation(.snappy) {
                    added.insert(food.name)
                    undo = food
                }
            } label: {
                Image(systemName: added.contains(food.name) ? "checkmark" : "plus")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(added.contains(food.name) ? look.onAction : look.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(added.contains(food.name) ? look.action : look.ground, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log one serving of \(food.name)")
            .accessibilityIdentifier("logFoodAdd.\(food.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var myMeals: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("My meals")
            LookList(separatorInset: 16) {
                ForEach(MockFood.myMeals, id: \.name) { item in
                    LookRow(item.name, subtitle: "\(item.calories.formatted()) cal · \(item.detail)",
                            showsChevron: false) {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(look.ground, in: Circle())
                    }
                }
            }
        }
    }

    private var bottomButtons: some View {
        // Stacked at accessibility sizes: side by side the labels broke mid-word ("Manu-al Add").
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button { addMode = .manual } label: { Label("Manual Add", systemImage: "square.and.pencil") }
                .buttonStyle(.lookSecondary)
                .accessibilityIdentifier("logFoodManualAdd")
            Button { addMode = .quick } label: { Label("Quick Add", systemImage: "bolt") }
                .buttonStyle(.lookSecondary)
                .accessibilityIdentifier("logFoodQuickAdd")
        }
        .padding(.horizontal, look.space.margin)
        .padding(.vertical, 10)
    }

    private func undoToast(_ food: MockFood) -> some View {
        HStack(spacing: 12) {
            Text("Logged \(food.name) to \(meal.label)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.onAction)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo") {
                withAnimation(.snappy) {
                    added.remove(food.name)
                    undo = nil
                }
            }
            .font(.system(.subheadline, weight: .bold))
            .foregroundStyle(look.onAction)
            .accessibilityIdentifier("logFoodUndo")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
        .background(look.action, in: Capsule())
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, 76)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Today's "Log food" pill (D68; the approved prototype's `SoftLogFoodPill`): black, above the tab bar, Today only.
struct LogFoodPill: View {
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(.subheadline, weight: .bold))
                Text("Log food").font(.system(.headline, weight: .semibold))
            }
            .foregroundStyle(look.onAction)
            .padding(.horizontal, 22)
            .frame(minHeight: 50)
            .background(look.action, in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        }
        .buttonStyle(.lookPressable)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .accessibilityIdentifier("logFoodPill")
    }
}
