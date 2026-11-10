import SwiftUI

/// Nutrition N4 — a food chosen from Log Food: how much, its numbers, Log. **MOCK for the user's review.**
/// The eye lands on the calories for the chosen amount (the hero); servings is the control above it; Log is the one
/// primary command at the bottom. The bookmark in the bar saves the food to Saved foods from anywhere (D81); one of My
/// foods also offers Edit (the Add food form, filled in).
struct SelectedFoodView: View {
    var food: MockFood
    var meal: MealSlot
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var servings = 1.0
    @State private var saved: Bool
    @State private var showsOther = false
    @State private var editing = false

    init(food: MockFood, meal: MealSlot) {
        self.food = food
        self.meal = meal
        _saved = State(initialValue: food.saved)
    }

    private var eaten: Macros { food.macros.scaled(by: servings) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(food.name, subtitle: food.brand)
                    amount
                    numbers
                    other
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Log to \(meal.label)") {}
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("selectedFoodLog")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if food.mine {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editing = true }
                        .font(.system(.body, weight: .semibold))
                        .accessibilityIdentifier("selectedFoodEdit")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { withAnimation(.snappy) { saved.toggle() } } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(saved ? look.action : look.textPrimary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(saved ? "Remove from Saved foods" : "Save to Saved foods")
                .accessibilityIdentifier("selectedFoodSave")
            }
        }
        .navigationDestination(isPresented: $editing) { AddFoodView(editing: food) }
    }

    private var amount: some View {
        LookList(separatorInset: 54) {
            if typeSize.isAccessibilitySize {
                // The stepper under its title: beside it, "Servings" broke mid-word.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Servings").font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
                    stepper
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LookRow("Servings", symbol: "number", showsChevron: false) { stepper }
            }
            ProfileRow("Serving", symbol: "scalemass", value: food.serving) {}
            if let perContainer = food.servingsPerContainer {
                // A fact of the food, not a choice: no chevron.
                LookRow("Servings per container", symbol: "shippingbox", value: perContainer.formatted(),
                        showsChevron: false)
            }
        }
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            stepButton("minus") { servings = max(0.25, servings - 0.5) }
            Text(servings.formatted(.number.precision(.fractionLength(0...2))))
                .font(look.font.statNumber)
                .monospacedDigit()
                .frame(minWidth: 44)
                .contentTransition(.numericText(value: servings))
            stepButton("plus") { servings += 0.5 }
        }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Image(systemName: symbol).font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: 44, height: 44)
                .background(look.ground, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var numbers: some View { MacroSummary(macros: eaten) }

    private var other: some View {
        DisclosureGroup("Other nutrition facts", isExpanded: $showsOther) {
            VStack(spacing: 8) {
                fact("Saturated fat", food.saturatedFat, unit: "g")
                fact("Fiber", food.fiber, unit: "g")
                fact("Sugar", food.sugar, unit: "g")
                fact("Sodium", food.sodium, unit: "mg")
            }
            .padding(.top, 8)
        }
        .font(.system(.body, weight: .semibold))
        .foregroundStyle(look.textPrimary)
        .padding(16)
        .lookSurface(.panel)
    }

    private func fact(_ name: String, _ perServing: Double?, unit: String) -> some View {
        HStack {
            Text(name).foregroundStyle(look.textSecondary)
            Spacer()
            Text(perServing.map { "\(($0 * servings).formatted(.number.precision(.fractionLength(0...1)))) \(unit)" } ?? "–")
                .monospacedDigit()
                .foregroundStyle(look.textPrimary)
        }
        .font(look.font.subhead)
    }
}

/// Nutrition N4 — Manual Add (D81): logs a one-off entry and creates no food. The name and serving are optional, so it
/// is also the quick add (Quick Add merged into it): calories alone are enough. **MOCK.** The macros' own calories are
/// shown when they disagree with the total — shown, never blocked (the ticket).
struct ManualAddView: View {
    var meal: MealSlot
    @Environment(\.look) private var look
    @State private var name = ""
    @State private var serving = ""
    @State private var calories = "420"
    @State private var protein = "30"
    @State private var carbs = "40"
    @State private var fat = "12"

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Manual Add")
                    LookList(separatorInset: 16) {
                        FoodFormField("Name", text: $name, prompt: "Optional")
                        FoodFormField("Serving", text: $serving, prompt: "Optional")
                    }
                    MacroFields(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Log to \(meal.label)") {}
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("manualAddLog")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Calories, protein, carbs and fat, with the macros' own calories shown under them when they disagree with the total
/// by more than 10 % (and 10 cal) — shown, never blocked. Shared by Manual Add and Add food's step 2.
struct MacroFields<Extra: View>: View {
    @Binding var calories: String
    @Binding var protein: String
    @Binding var carbs: String
    @Binding var fat: String
    var fatTitle = "Fat"
    @ViewBuilder var extra: () -> Extra
    @Environment(\.look) private var look

    private var macroCalories: Double {
        NutritionMath.macroCalories(proteinGrams: Double(protein) ?? 0, carbsGrams: Double(carbs) ?? 0,
                                    fatGrams: Double(fat) ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            LookList(separatorInset: 16) {
                FoodFormField("Calories", text: $calories, prompt: "0", unit: "cal", number: true)
                FoodFormField("Protein", text: $protein, prompt: "Optional", unit: "g", number: true)
                FoodFormField("Carbs", text: $carbs, prompt: "Optional", unit: "g", number: true)
                FoodFormField(fatTitle, text: $fat, prompt: "Optional", unit: "g", number: true)
                extra()
            }
            if let total = Double(calories), abs(macroCalories - total) > max(10, total * 0.1) {
                SettingsNotice(symbol: "info.circle",
                               text: "Protein, carbs and fat add up to \(macroCalories.formatted(.number.precision(.fractionLength(0)))) cal.")
            }
        }
    }
}

extension MacroFields where Extra == EmptyView {
    init(calories: Binding<String>, protein: Binding<String>, carbs: Binding<String>, fat: Binding<String>) {
        self.init(calories: calories, protein: protein, carbs: carbs, fat: fat, extra: { EmptyView() })
    }
}

/// One labelled entry row of the food forms: the title leading, the value trailing with its unit. At accessibility
/// sizes the value goes under the title, so neither breaks mid-word.
struct FoodFormField: View {
    var title: String
    @Binding var text: String
    var prompt: String
    var unit: String?
    var number = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: String, text: Binding<String>, prompt: String, unit: String? = nil, number: Bool = false) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.unit = unit
        self.number = number
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            Text(title).font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
            HStack(spacing: 6) {
                TextField(prompt, text: $text)
                    .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                    .keyboardType(number ? .decimalPad : .default)
                    .foregroundStyle(look.textPrimary)
                    .accessibilityLabel(title)
                if let unit { Text(unit).foregroundStyle(look.textSecondary) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, typeSize.isAccessibilitySize ? 10 : 0)
        .frame(minHeight: 50)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The calories of an amount as the screen's hero number, with protein, carbs and fat under it (stacked at accessibility
/// sizes). Shared by Selected food and Selected meal.
struct MacroSummary: View {
    var macros: Macros
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(macros.calories.formatted(.number.precision(.fractionLength(0))))
                    .font(look.font.heroNumber)
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: macros.calories))
                Text("cal").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
            }
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                ForEach(MacroKind.allCases) { macro in
                    HStack(spacing: 8) {
                        MacroGlyph(macro: macro)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(macro.grams(of: macros).formatted(.number.precision(.fractionLength(0...1)))) g")
                                .font(.system(.headline, weight: .semibold))
                                .foregroundStyle(look.textPrimary)
                            Text(macro.name).font(look.font.footnote).foregroundStyle(look.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .lookSurface(.panel)
    }
}
