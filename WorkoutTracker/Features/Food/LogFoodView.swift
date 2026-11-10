import SwiftData
import SwiftUI

/// Nutrition N4 — Log Food, opened by Today's "Log food" pill, in the user's structure (D81): the meal, tabs All / My
/// foods / My meals / Saved foods, a search over the user's own foods, and a one-tap + (one serving, with Undo) on every
/// food and meal row. All ends with **Manual Add** (a one-off entry, name optional — Quick Add merged into it); My foods
/// with **Add food**; My meals with **Create meal**. Voice Log is out of scope; Scan joins in N7, online search in N8.
///
/// The eye lands on the list (what most logs are); the + on each row is the action, quiet until tapped.
struct LogFoodView: View {
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Query private var foods: [SavedFood]
    @Query private var savedMeals: [SavedMeal]
    @State private var meal = MealSlot.forTime(.now)
    @State private var tab = Tab.all
    @State private var search = ""
    /// The rows whose + was tapped on this visit (they show a check until Undo).
    @State private var logged: Set<PersistentIdentifier> = []
    /// What the last log wrote, for the Undo toast.
    @State private var receipt: FoodLogReceipt?
    @State private var route: Route?
    @State private var selected: SavedFood?
    @State private var selectedMeal: SavedMeal?
    @State private var failure: String?
    /// N7 MOCK: the scan camera from Log food's bar; a meal photo or a description returns to Today (D82's card).
    @State private var showScan = false
    @Environment(\.dismiss) private var dismiss

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

    private var searching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The tab's foods. Searching on All looks through every food the user has, not only the recent ones.
    private var tabFoods: [SavedFood] {
        switch tab {
        case .all: searching ? FoodLog.all(foods) : FoodLog.recent(foods)
        case .myFoods: FoodLog.mine(foods)
        case .saved: FoodLog.saved(foods)
        case .myMeals: []
        }
    }

    private var shownFoods: [SavedFood] { FoodLog.matching(tabFoods, search) }

    private var shownMeals: [SavedMeal] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return FoodLog.meals(savedMeals, for: meal).filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// The tab's own command at the bottom: Manual Add on All, Add food on My foods, Create meal on My meals; none on
    /// Saved foods. An empty My foods / My meals carries its command in its empty state instead.
    private var command: Route? {
        switch tab {
        case .all: .manualAdd
        case .myFoods: FoodLog.mine(foods).isEmpty ? nil : .addFood
        case .myMeals: savedMeals.isEmpty ? nil : .createMeal
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
                    if tab == .all && searching { describeRow }
                    content
                    // At accessibility sizes the command scrolls with the list: pinned, it left room for one food row.
                    if typeSize.isAccessibilitySize, let command {
                        commandButton(command).padding(.horizontal, -look.space.margin)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            if !typeSize.isAccessibilitySize, let command { commandButton(command) }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showScan = true } label: {
                    Image(systemName: "camera.viewfinder").font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                }
                .accessibilityLabel("Scan food")
                .accessibilityIdentifier("logFoodScan")
            }
        }
        .fullScreenCover(isPresented: $showScan) {
            FoodScanFlow(meal: meal, onMealPhoto: { showScan = false; dismiss() },
                         onManualAdd: { route = .manualAdd })
        }
        .overlay(alignment: .bottom) { if let receipt { undoToast(receipt) } }
        .sensoryFeedback(.success, trigger: receipt?.entries.first?.id) { _, new in new != nil }
        .task(id: receipt?.entries.first?.id) {
            // The toast leaves after a few seconds; the log stays. A newer log cancels this wait, and the wait only ever
            // clears its own receipt, so the newer log keeps its Undo (codex-review-n4).
            guard let shown = receipt?.entries.first?.id else { return }
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard receipt?.entries.first?.id == shown else { return }
            withAnimation(motion) { receipt = nil }
        }
        .navigationDestination(item: $selected) { food in
            SelectedFoodView(food: food, meal: meal, source: tab == .all ? .recent : .saved,
                             onLogged: { receipt in selected = nil; show(receipt) },
                             onDeleted: {
                                 // Its Undo would have no food to put back; the entries it logged stay.
                                 if receipt?.food === food { receipt = nil }
                                 selected = nil
                             })
        }
        .navigationDestination(item: $selectedMeal) { savedMeal in
            SelectedMealView(savedMeal: savedMeal, meal: meal,
                             onLogged: { receipt in selectedMeal = nil; show(receipt) },
                             onDeleted: { selectedMeal = nil })
        }
        .navigationDestination(item: $route) { route in
            switch route {
            case .manualAdd: ManualAddView(meal: meal) { receipt in self.route = nil; show(receipt) }
            case .addFood: AddFoodView { _ in self.route = nil }
            case .createMeal: CreateMealView { self.route = nil }
            }
        }
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .myMeals where savedMeals.isEmpty:
            EmptyStateView(symbol: "takeoutbag.and.cup.and.straw", title: "No meals yet",
                           message: "Save foods you eat together, then log them in one tap.",
                           actionTitle: "Create meal") {
                route = .createMeal
            }
        case .myFoods where FoodLog.mine(foods).isEmpty:
            EmptyStateView(symbol: "fork.knife", title: "No foods yet",
                           message: "Add a food once, then log it in one tap.", actionTitle: "Add food") {
                route = .addFood
            }
        case .saved where FoodLog.saved(foods).isEmpty:
            EmptyStateView(symbol: "bookmark", title: "No saved foods",
                           message: "Tap the bookmark on any food to keep it here.")
        case .all where !searching && FoodLog.recent(foods).isEmpty:
            EmptyStateView(symbol: "clock", title: "Nothing logged yet",
                           message: "Foods you log appear here.")
        case .all where searching && shownFoods.isEmpty:
            // The estimate row above is the way forward; no "No Results" under it (N7).
            EmptyView()
        case .myMeals where shownMeals.isEmpty, .all where shownFoods.isEmpty, .myFoods where shownFoods.isEmpty,
             .saved where shownFoods.isEmpty:
            ContentUnavailableView.search(text: search)
        case .myMeals: myMeals
        default: foodList
        }
    }

    /// N7: what was typed, estimated by AI (food-describe) — logged at once like a meal photo, its card on Today.
    private var describeRow: some View {
        let text = search.trimmingCharacters(in: .whitespaces)
        return Button {
            FoodScanMock.shared.startDescribe(text, meal: meal)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(look.surfaceRaised, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Estimate “\(text)”")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(3)
                    Text("With AI · logs to \(meal.label)")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .lookSurface(.panel)
        .accessibilityIdentifier("logFoodDescribe")
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
                        Button { withAnimation(motion) { tab = item } } label: {
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
            .onChange(of: tab) { _, item in withAnimation(motion) { proxy.scrollTo(item, anchor: .center) } }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(look.textSecondary)
            TextField("Search your foods", text: $search)
                .submitLabel(.search)
                .accessibilityIdentifier("logFoodSearch")
        }
        .padding(14)
        .lookSurface(.panel)
    }

    private var foodList: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(tab == .all ? (searching ? "Your foods" : "Recently logged") : tab.title)
            LookList(separatorInset: 16) {
                ForEach(shownFoods) { food in
                    logRow(title: food.name,
                           subtitle: FoodCopy.foodLine(brand: food.brand, calories: food.calories,
                                                       serving: food.servingText),
                           id: food.persistentModelID, identifier: food.name,
                           open: { selected = food },
                           log: { try FoodLog.log(food, meal: meal, source: tab == .all ? .recent : .saved, in: context) })
                }
            }
        }
    }

    private var myMeals: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("My meals")
            LookList(separatorInset: 16) {
                ForEach(shownMeals) { item in
                    logRow(title: item.name,
                           subtitle: "\(FoodCopy.calories(item.macros.calories)) · \(item.orderedItems.map(\.name).joined(separator: ", "))",
                           id: item.persistentModelID, identifier: "meal.\(item.name)",
                           open: { selectedMeal = item },
                           log: { try FoodLog.log(item, meal: meal, in: context) })
                }
            }
        }
    }

    /// A food or meal row: tapping it opens it; its + logs it at once, with Undo.
    private func logRow(title: String, subtitle: String, id: PersistentIdentifier, identifier: String,
                        open: @escaping () -> Void, log: @escaping () throws -> FoodLogReceipt) -> some View {
        let done = logged.contains(id)
        return HStack(spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                    Text(subtitle).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("logFoodRow.\(identifier)")
            Button {
                do {
                    let receipt = try log()
                    withAnimation(motion) {
                        logged.insert(id)
                        self.receipt = receipt
                    }
                } catch {
                    failure = error.localizedDescription
                }
            } label: {
                Image(systemName: done ? "checkmark" : "plus")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(done ? look.onAction : look.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(done ? look.action : look.ground, in: Circle())
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log \(title)")
            .accessibilityIdentifier("logFoodAdd.\(identifier)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func show(_ receipt: FoodLogReceipt) {
        withAnimation(motion) { self.receipt = receipt }
    }

    /// Reduce Motion: changes land without movement (the toast fades instead of sliding).
    private var motion: Animation? { reduceMotion ? nil : .snappy }

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

    private func undoToast(_ receipt: FoodLogReceipt) -> some View {
        HStack(spacing: 12) {
            Text(FoodCopy.logged(receipt, to: receipt.entries.first?.meal ?? meal))
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.onAction)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("logFoodToast")
            Button("Undo") {
                do {
                    try FoodLog.undo(receipt, in: context)
                    withAnimation(motion) {
                        receipt.food.map { logged.remove($0.persistentModelID) }
                        receipt.meal.map { logged.remove($0.persistentModelID) }
                        self.receipt = nil
                    }
                } catch {
                    failure = error.localizedDescription
                }
            }
            .font(.system(.subheadline, weight: .bold))
            .foregroundStyle(look.onAction)
            .frame(minHeight: 44)
            .accessibilityIdentifier("logFoodUndo")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
        .background(look.action, in: Capsule())
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, command == nil || typeSize.isAccessibilitySize ? 16 : 76)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
}

/// Today's "Log food" pill (D68; the approved prototype's `SoftLogFoodPill`): black, above the tab bar, Today only.
struct LogFoodPill: View {
    var action: () -> Void
    /// N7: Scan food, a round camera button beside the pill (one tap from Today to the camera).
    var scan: (() -> Void)?
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 10) {
            if let scan {
                Button(action: scan) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .frame(width: 50, height: 50)
                        .background(look.surface, in: Circle())
                        .overlay { Circle().strokeBorder(look.hairline, lineWidth: 1) }
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                }
                .buttonStyle(.lookPressable)
                .accessibilityLabel("Scan food")
                .accessibilityIdentifier("scanFoodButton")
            }
            pill
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    private var pill: some View {
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
        .accessibilityIdentifier("logFoodPill")
    }
}
