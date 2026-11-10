import SwiftUI

/// Nutrition N4 — Log Food, opened by Today's "Log food" pill. **MOCK for the user's review** (sample foods, nothing
/// stored), in the user's structure (D81): the meal, tabs All / My foods / My meals / Saved foods, a search over the
/// user's own foods, and a one-tap + (one serving, with Undo) on every food row. All ends with **Manual Add** (a one-off
/// entry, name optional — Quick Add merged into it); My foods ends with **Add food** (the two-step form that creates
/// one of My foods). Voice Log is out of scope; Scan joins in N7.
///
/// The eye lands on the list (what most logs are); the + on each row is the action, quiet until tapped.
struct LogFoodView: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var meal = MealSlot.forTime(.now)
    @State private var tab = Tab.all
    @State private var search = ""
    @State private var added: Set<String> = []
    /// The name of what the last + logged (a food or a meal), for the Undo toast.
    @State private var undo: String?
    @State private var route: Route?
    @State private var selected: MockFood?
    @State private var selectedMeal: MockMeal?

    enum Tab: CaseIterable, Identifiable {
        case all, myFoods, myMeals, saved
        var id: Self { self }
        var title: String {
            switch self {
            case .all: "All"
            case .myFoods: "My foods"
            case .myMeals: "My meals"
            case .saved: "Saved foods"
            }
        }
    }

    enum Route: Identifiable { case manualAdd, addFood, createMeal; var id: Self { self } }

    private var foods: [MockFood] {
        let base = switch tab {
        case .all, .myMeals: MockFood.recentFoods
        case .myFoods: MockFood.myFoods
        case .saved: MockFood.savedFoods
        }
        guard !search.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    /// The tab's own command at the bottom: Manual Add on All, Add food on My foods (D81), Create meal on My meals; none
    /// on Saved foods. An empty My foods / My meals carries its command in its empty state instead.
    private var command: Route? {
        switch tab {
        case .all: .manualAdd
        case .myFoods: MockFood.myFoods.isEmpty ? nil : .addFood
        case .myMeals: MockFood.showsEmpty ? nil : .createMeal
        case .saved: nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Log food")
                    mealChips
                    tabBar
                    searchField
                    content
                    // At accessibility sizes the command scrolls with the list: pinned, it left room for one food row.
                    if typeSize.isAccessibilitySize, let command { commandButton(command).padding(.horizontal, -look.space.margin) }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            if !typeSize.isAccessibilitySize, let command { commandButton(command) }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { if let undo { undoToast(undo) } }
        .navigationDestination(item: $selected) { SelectedFoodView(food: $0, meal: meal) }
        .navigationDestination(item: $selectedMeal) { SelectedMealView(savedMeal: $0, meal: meal) }
        .navigationDestination(item: $route) { route in
            switch route {
            case .manualAdd: ManualAddView(meal: meal)
            case .addFood: AddFoodView()
            case .createMeal: CreateMealView()
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .myMeals where MockFood.myMeals.isEmpty && search.isEmpty:
            EmptyStateView(symbol: "takeoutbag.and.cup.and.straw", title: "No meals yet",
                           message: "Save foods you eat together, then log them in one tap.",
                           actionTitle: "Create meal") {
                route = .createMeal
            }
        case .myMeals: myMeals
        case .myFoods where foods.isEmpty && search.isEmpty:
            EmptyStateView(symbol: "fork.knife", title: "No foods yet",
                           message: "Add a food once, then log it in one tap.", actionTitle: "Add food") {
                route = .addFood
            }
        case .saved where foods.isEmpty && search.isEmpty:
            EmptyStateView(symbol: "bookmark", title: "No saved foods",
                           message: "Tap the bookmark on any food to keep it here.")
        default: foodList
        }
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
        // Scrolls at accessibility sizes, where "Saved foods" lies past the edge; the chosen tab is scrolled into view.
        ScrollViewReader { proxy in
        ScrollView(.horizontal) {
            HStack(spacing: 22) {
                ForEach(Tab.allCases) { item in
                    Button { withAnimation(.snappy) { tab = item } } label: {
                        VStack(spacing: 8) {
                            Text(item.title)
                                .font(.system(.body, weight: tab == item ? .semibold : .medium))
                                .foregroundStyle(tab == item ? look.textPrimary : look.textSecondary)
                            Capsule().fill(tab == item ? look.textPrimary : .clear).frame(height: 2)
                        }
                        .fixedSize()
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
                    .accessibilityIdentifier("logFoodTab.\(item.title)")
                    .id(item)
                }
            }
        }
        .scrollIndicators(.hidden)
        .onChange(of: tab) { _, item in withAnimation(.snappy) { proxy.scrollTo(item, anchor: .center) } }
        }
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

    private var foodList: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(tab == .all ? "Recently logged" : tab.title)
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
                    Text([food.brand, "\(food.calories.formatted()) cal", food.serving].compactMap(\.self)
                        .joined(separator: " · "))
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
                    undo = food.name
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

    /// My meals, the chosen meal's own first (a meal usually for Breakfast leads while Breakfast is chosen).
    private var meals: [MockMeal] {
        let all = MockFood.myMeals.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
        return all.filter { $0.usual == meal } + all.filter { $0.usual != meal }
    }

    private var myMeals: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("My meals")
            LookList(separatorInset: 16) {
                ForEach(meals) { item in mealRow(item) }
            }
        }
    }

    private func mealRow(_ item: MockMeal) -> some View {
        HStack(spacing: 12) {
            Button { selectedMeal = item } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                    Text("\(item.macros.calories.formatted(.number.precision(.fractionLength(0)))) cal · \(item.detail)")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("logFoodMealRow.\(item.name)")
            Button {
                withAnimation(.snappy) {
                    added.insert(item.name)
                    undo = item.name
                }
            } label: {
                Image(systemName: added.contains(item.name) ? "checkmark" : "plus")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(added.contains(item.name) ? look.onAction : look.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(added.contains(item.name) ? look.action : look.ground, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log \(item.name)")
            .accessibilityIdentifier("logFoodMealAdd.\(item.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func commandButton(_ command: Route) -> some View {
        Group {
            switch command {
            case .manualAdd:
                Button { route = .manualAdd } label: { Label("Manual Add", systemImage: "square.and.pencil") }
                    .accessibilityIdentifier("logFoodManualAdd")
            case .addFood:
                Button { route = .addFood } label: { Label("Add food", systemImage: "plus") }
                    .accessibilityIdentifier("logFoodAddFood")
            case .createMeal:
                Button { route = .createMeal } label: { Label("Create meal", systemImage: "plus") }
                    .accessibilityIdentifier("logFoodCreateMeal")
            }
        }
        .buttonStyle(.lookSecondary)
        .padding(.horizontal, look.space.margin)
        .padding(.vertical, 10)
    }

    private func undoToast(_ name: String) -> some View {
        HStack(spacing: 12) {
            Text("Logged \(name) to \(meal.label)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.onAction)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo") {
                withAnimation(.snappy) {
                    added.remove(name)
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
        .padding(.bottom, command == nil || typeSize.isAccessibilitySize ? 16 : 76)
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
