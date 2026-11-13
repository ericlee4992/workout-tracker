import SwiftData
import SwiftUI

/// Nutrition N4 — a food chosen from Log Food: how much, its numbers, Log. The eye lands on the calories for the
/// chosen amount (the hero); servings is the control above it; Log is the one primary command at the bottom. The
/// bookmark in the bar puts the food in Saved foods or takes it out (D81); one of My foods also offers Edit (the Add
/// food form, filled in). N8: a food from a database offers its other servings (by weight) and credits its source; N12:
/// one whose source leaves macros blank says so under them.
struct SelectedFoodView: View {
    var food: SavedFood
    var meal: MealSlot
    var source: FoodSource
    var onLogged: (FoodLogReceipt) -> Void
    var onDeleted: () -> Void = {}
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @State private var servings = 1.0
    /// N8: which of `FoodLog.servingChoices` (0 = the food's own serving).
    @State private var choice = 0
    @State private var showsOther = false
    @State private var editing = false
    @State private var confirmingDelete = false
    /// Set BEFORE the food is deleted, so a re-evaluation after the save never renders a deleted model (as
    /// TemplateDetailView, codex-review-15).
    @State private var deleted = false
    @State private var failure: String?

    private var choices: [ServingOption] { FoodLog.servingChoices(food) }
    private var option: ServingOption? { choice > 0 && choice < choices.count ? choices[choice] : nil }
    /// One chosen serving as a multiple of the food's own.
    private var factor: Double { option.flatMap { FoodLog.scale(of: $0, in: food) } ?? 1 }
    private var eaten: Macros { food.macros.scaled(by: servings * factor) }

    var body: some View {
        Group {
            if deleted { Color.clear } else { content }
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if !deleted { toolbar } }
        .navigationDestination(isPresented: $editing) { AddFoodView(editing: food) { _ in editing = false } }
        .alert("Delete Food", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            // The consequence, in one line: the food goes, what was logged and the meals keep their copy.
            Text("Food already logged and meals with it are kept.")
        }
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(food.name, subtitle: food.brand)
                    amount
                    MacroSummary(macros: eaten)
                    if FoodDatabase.macrosIncomplete(databaseID: food.databaseID, calories: food.calories,
                                                     protein: food.proteinGrams, carbs: food.carbsGrams, fat: food.fatGrams) {
                        // N12 (D86): a source that leaves macros blank (restaurant chains); they count as 0.
                        Text("Not all macros are listed for this food; they count as 0.")
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .accessibilityIdentifier("selectedFoodMacrosNotListed")
                    }
                    other
                    if let credit = FoodDatabase.attribution(databaseID: food.databaseID) {
                        Text(credit)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .accessibilityIdentifier("selectedFoodAttribution")
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Log to \(meal.label)") {
                do {
                    onLogged(try FoodLog.log(food, servings: servings, option: option, meal: meal, source: source,
                                             in: context))
                }
                catch { failure = error.localizedDescription }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 10)
            .accessibilityIdentifier("selectedFoodLog")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if food.createdByUser {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
                    .font(.system(.body, weight: .semibold))
                    .accessibilityIdentifier("selectedFoodEdit")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                do { try withAnimation(reduceMotion ? nil : .snappy) { try FoodLog.setSaved(food, !food.isSaved, in: context) } }
                catch { failure = error.localizedDescription }
            } label: {
                Image(systemName: food.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(food.isSaved ? look.action : look.textPrimary)
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
            }
            .accessibilityLabel(food.isSaved ? "Remove from Saved foods" : "Save to Saved foods")
            .accessibilityIdentifier("selectedFoodSave")
        }
        if food.createdByUser {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Food…", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                        .accessibilityIdentifier("deleteFood")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("selectedFoodMore")
            }
        }
    }

    private func delete() {
        deleted = true
        do {
            try FoodLog.delete(food, in: context)
            onDeleted()
        } catch {
            deleted = false
            failure = error.localizedDescription
        }
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
            // A fact of the food, no chevron — unless a database gave it other servings (N8): then a choice.
            if choices.count > 1 {
                Menu {
                    Picker("Serving", selection: $choice) {
                        ForEach(choices.indices, id: \.self) { index in
                            Text(Self.text(choices[index])).tag(index)
                        }
                    }
                } label: {
                    LookRow("Serving", symbol: "scalemass", value: Self.text(choices[min(choice, choices.count - 1)]),
                            showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("selectedFoodServing")
            } else {
                LookRow("Serving", symbol: "scalemass", value: food.servingText, showsChevron: false)
            }
            if let perContainer = food.servingsPerContainer {
                LookRow("Servings per container", symbol: "shippingbox", value: FoodNumber.text(perContainer),
                        showsChevron: false)
            }
        }
    }

    private static func text(_ option: ServingOption) -> String {
        ServingText.format(value: option.value, unit: option.unit, grams: option.grams)
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            stepButton("minus", label: "Fewer servings", enabled: servings > 0.5) { servings = max(0.5, servings - 0.5) }
            Text(servings.formatted(.number.precision(.fractionLength(0...2))))
                .font(look.font.statNumber)
                .monospacedDigit()
                .frame(minWidth: 44)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: servings))
                .accessibilityIdentifier("selectedFoodServings")
            stepButton("plus", label: "More servings", enabled: true) { servings += 0.5 }
        }
    }

    private func stepButton(_ symbol: String, label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(reduceMotion ? nil : .snappy) { action() } } label: {
            Image(systemName: symbol).font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: 44, height: 44)
                .background(look.ground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }

    private var other: some View {
        DisclosureGroup("Other nutrition facts", isExpanded: $showsOther) {
            VStack(spacing: 8) {
                fact("Saturated fat", food.saturatedFatGrams, unit: "g")
                fact("Fiber", food.fiberGrams, unit: "g")
                fact("Sugar", food.sugarGrams, unit: "g")
                fact("Sodium", food.sodiumMilligrams, unit: "mg")
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
            Text(perServing.map { "\(($0 * servings * factor).formatted(.number.precision(.fractionLength(0...1)))) \(unit)" } ?? "–")
                .monospacedDigit()
                .foregroundStyle(look.textPrimary)
        }
        .font(look.font.subhead)
    }
}

/// Nutrition N4 — Manual Add (D81): logs a one-off entry and creates no food. The name and serving are optional, so it
/// is also the quick add (Quick Add merged into it): calories alone are enough. The macros' own calories are shown when
/// they disagree with the total — shown, never blocked (the ticket).
struct ManualAddView: View {
    var meal: MealSlot
    var onLogged: (FoodLogReceipt) -> Void
    @Environment(\.look) private var look
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var serving = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var failure: String?

    /// Calories are needed; every other number is blank or a number; the serving blank or one (a serving that is not
    /// one never silently becomes "1 serving").
    private var nutrition: FoodNutrition? {
        guard ServingText.isBlank(serving) || ServingText.parse(serving) != nil,
              let calories = FoodNumber.parse(calories),
              let protein = FoodNumber.optional(protein), let carbs = FoodNumber.optional(carbs), let fat = FoodNumber.optional(fat) else { return nil }
        return FoodNutrition(calories: calories, proteinGrams: protein ?? 0, carbsGrams: carbs ?? 0, fatGrams: fat ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Manual Add")
                    LookList(separatorInset: 16) {
                        FoodFormField("Name", text: $name, prompt: "Optional", identifier: "manualAddName")
                        FoodFormField("Serving", text: $serving, prompt: "Optional", identifier: "manualAddServing")
                    }
                    MacroFields(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat, identifier: "manualAdd")
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            PrimaryButton("Log to \(meal.label)") {
                guard let nutrition else { return }
                do {
                    onLogged(try FoodLog.logManual(name: name, serving: ServingText.parse(serving),
                                                   nutrition: nutrition, meal: meal, in: context))
                } catch {
                    failure = error.localizedDescription
                }
            }
            .disabled(nutrition == nil)
            .opacity(nutrition == nil ? 0.4 : 1)
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 10)
            .accessibilityIdentifier("manualAddLog")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
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
    /// Prefix of the fields' accessibility identifiers ("manualAdd" → "manualAddCalories").
    var identifier = "food"
    @ViewBuilder var extra: () -> Extra
    @Environment(\.look) private var look

    private var macroCalories: Double {
        NutritionMath.macroCalories(proteinGrams: FoodNumber.parse(protein) ?? 0,
                                    carbsGrams: FoodNumber.parse(carbs) ?? 0, fatGrams: FoodNumber.parse(fat) ?? 0)
    }

    /// Shown once a macro is typed and the two disagree by more than 10 % (and 10 cal).
    private var mismatch: Bool {
        guard let total = FoodNumber.parse(calories), [protein, carbs, fat].contains(where: { FoodNumber.parse($0) != nil })
        else { return false }
        return abs(macroCalories - total) > max(10, total * 0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            LookList(separatorInset: 16) {
                FoodFormField("Calories", text: $calories, prompt: "0", unit: "cal", number: true,
                              identifier: "\(identifier)Calories")
                FoodFormField("Protein", text: $protein, prompt: "Optional", unit: "g", number: true,
                              identifier: "\(identifier)Protein")
                FoodFormField("Carbs", text: $carbs, prompt: "Optional", unit: "g", number: true,
                              identifier: "\(identifier)Carbs")
                FoodFormField(fatTitle, text: $fat, prompt: "Optional", unit: "g", number: true,
                              identifier: "\(identifier)Fat")
                extra()
            }
            if mismatch {
                SettingsNotice(symbol: "info.circle",
                               text: "Protein, carbs and fat add up to \(macroCalories.formatted(.number.precision(.fractionLength(0)))) cal.")
            }
        }
    }
}

extension MacroFields where Extra == EmptyView {
    init(calories: Binding<String>, protein: Binding<String>, carbs: Binding<String>, fat: Binding<String>,
         identifier: String) {
        self.init(calories: calories, protein: protein, carbs: carbs, fat: fat, identifier: identifier,
                  extra: { EmptyView() })
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
    var identifier: String?
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: String, text: Binding<String>, prompt: String, unit: String? = nil, number: Bool = false,
         identifier: String? = nil) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.unit = unit
        self.number = number
        self.identifier = identifier
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
                    .accessibilityIdentifier(identifier ?? "foodField.\(title)")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(macros.calories.formatted(.number.precision(.fractionLength(0))))
                    .font(look.font.heroNumber)
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: macros.calories))
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
