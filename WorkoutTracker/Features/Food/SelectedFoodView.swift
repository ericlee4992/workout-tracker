import SwiftUI

/// Nutrition N4 — a food chosen from Log Food: how much, its numbers, Log. **MOCK for the user's review.**
/// The eye lands on the calories for the chosen amount (the hero); servings is the control above it; Log is the one
/// primary command at the bottom.
struct SelectedFoodView: View {
    var food: MockFood
    var meal: MealSlot
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var servings = 1.0
    @State private var saveToMyFoods = false
    @State private var showsOther = false

    private var eaten: Macros { food.macros.scaled(by: servings) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(food.name, subtitle: food.brand)
                    amount
                    numbers
                    other
                    LookList {
                        LookRow("Save to My foods", symbol: "bookmark", showsChevron: false) {
                            Toggle("Save to My foods", isOn: $saveToMyFoods).labelsHidden().toggleStyle(.settings)
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
                .accessibilityIdentifier("selectedFoodLog")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
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

    private var numbers: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(eaten.calories.formatted(.number.precision(.fractionLength(0))))
                    .font(look.font.heroNumber)
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: eaten.calories))
                Text("cal").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
            }
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                ForEach(MacroKind.allCases) { macro in
                    HStack(spacing: 8) {
                        MacroGlyph(macro: macro)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(macro.grams(of: eaten).formatted(.number.precision(.fractionLength(0...1)))) g")
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

    private var other: some View {
        DisclosureGroup("Other nutrition facts", isExpanded: $showsOther) {
            VStack(spacing: 8) {
                fact("Fiber", "0 g")
                fact("Sugar", "6 g")
                fact("Saturated fat", "0.3 g")
                fact("Sodium", "65 mg")
            }
            .padding(.top, 8)
        }
        .font(.system(.body, weight: .semibold))
        .foregroundStyle(look.textPrimary)
        .padding(16)
        .lookSurface(.panel)
    }

    private func fact(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(look.textSecondary)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(look.textPrimary)
        }
        .font(look.font.subhead)
    }
}

/// Nutrition N4 — Manual Add (a named food) and Quick Add (calories, optional macros, no name). **MOCK.** The macros'
/// own calories are shown beside the total when they disagree — shown, never blocked (the ticket).
struct ManualAddView: View {
    var quick: Bool
    var meal: MealSlot
    @Environment(\.look) private var look
    @State private var name = ""
    @State private var serving = ""
    @State private var calories = "420"
    @State private var protein = "30"
    @State private var carbs = "40"
    @State private var fat = "12"
    @State private var saveToMyFoods = true

    private var macroCalories: Double {
        NutritionMath.macroCalories(proteinGrams: Double(protein) ?? 0, carbsGrams: Double(carbs) ?? 0,
                                    fatGrams: Double(fat) ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(quick ? "Quick Add" : "Manual Add")
                    if !quick {
                        LookList(separatorInset: 16) {
                            field("Name", text: $name, prompt: "e.g. Chicken burrito")
                            field("Serving", text: $serving, prompt: "e.g. 1 bowl")
                        }
                    }
                    VStack(alignment: .leading, spacing: look.space.header) {
                        LookList(separatorInset: 16) {
                            field("Calories", text: $calories, prompt: "0", unit: "cal", number: true)
                            field("Protein", text: $protein, prompt: "Optional", unit: "g", number: true)
                            field("Carbs", text: $carbs, prompt: "Optional", unit: "g", number: true)
                            field("Fat", text: $fat, prompt: "Optional", unit: "g", number: true)
                        }
                        if let total = Double(calories), abs(macroCalories - total) > max(10, total * 0.1) {
                            SettingsNotice(symbol: "info.circle",
                                           text: "Protein, carbs and fat add up to \(macroCalories.formatted(.number.precision(.fractionLength(0)))) cal.")
                        }
                    }
                    if !quick {
                        LookList {
                            LookRow("Save to My foods", symbol: "bookmark", showsChevron: false) {
                                Toggle("Save to My foods", isOn: $saveToMyFoods).labelsHidden().toggleStyle(.settings)
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
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ title: String, text: Binding<String>, prompt: String, unit: String? = nil,
                       number: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
            TextField(prompt, text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(number ? .decimalPad : .default)
                .foregroundStyle(look.textPrimary)
            if let unit { Text(unit).foregroundStyle(look.textSecondary) }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }
}
