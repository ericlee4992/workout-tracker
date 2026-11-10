import SwiftData
import SwiftUI

/// Nutrition N4 — Add food (D81): creates one of **My foods** in two steps, like the user's reference. Step 1 names the
/// food and its serving (brand and servings per container optional) → Next → step 2, its nutrition per serving →
/// Save food. Reached from the bottom of the My foods tab, and as Edit (filled in) from one of My foods; editing
/// leaves the entries already logged as they were (each keeps its own snapshot, N2).
///
/// Step 1's eye lands on the description (the one field the food needs to exist); step 2's on calories, first in the
/// list. Next / Save food is the one primary command at the bottom of each step.
struct AddFoodView: View {
    var editing: SavedFood?
    var onSaved: (SavedFood) -> Void
    @Environment(\.look) private var look
    @State private var brand: String
    @State private var name: String
    @State private var serving: String
    @State private var perContainer: String
    @State private var next = false

    init(editing: SavedFood? = nil, onSaved: @escaping (SavedFood) -> Void) {
        self.editing = editing
        self.onSaved = onSaved
        _brand = State(initialValue: editing?.brand ?? "")
        _name = State(initialValue: editing?.name ?? "")
        _serving = State(initialValue: editing?.servingText ?? "")
        _perContainer = State(initialValue: FoodNumber.text(editing?.servingsPerContainer))
    }

    /// Step 1 is complete: a description, a serving, and servings per container blank or a number above zero.
    private var parsed: (serving: ServingText, perContainer: Double?)? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let serving = ServingText.parse(serving),
              let perContainer = optionalNumber(perContainer), perContainer.map({ $0 > 0 }) ?? true
        else { return nil }
        return (serving, perContainer)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(editing == nil ? "Add food" : "Edit food")
                    LookList(separatorInset: 16) {
                        FoodFormField("Brand", text: $brand, prompt: "Optional", identifier: "addFoodBrand")
                        FoodFormField("Description", text: $name, prompt: "e.g. Overnight oats",
                                      identifier: "addFoodName")
                    }
                    LookList(separatorInset: 16) {
                        FoodFormField("Serving size", text: $serving, prompt: "e.g. 1 cup", identifier: "addFoodServing")
                        FoodFormField("Servings per container", text: $perContainer, prompt: "Optional", number: true,
                                      identifier: "addFoodPerContainer")
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            PrimaryButton("Next") { next = true }
                .disabled(parsed == nil)
                .opacity(parsed == nil ? 0.4 : 1)
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("addFoodNext")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $next) {
            if let parsed {
                AddFoodNutritionView(editing: editing, brand: brand, name: name, serving: parsed.serving,
                                     perContainer: parsed.perContainer, onSaved: onSaved)
            }
        }
    }
}

/// Add food, step 2: the nutrition of one serving. Calories, protein, carbs, total fat and saturated fat first (the
/// user's reference order), then fiber, sugar and sodium — the facts a saved food stores (N2).
struct AddFoodNutritionView: View {
    var editing: SavedFood?
    var brand: String
    var name: String
    var serving: ServingText
    var perContainer: Double?
    var onSaved: (SavedFood) -> Void
    @Environment(\.look) private var look
    @Environment(\.modelContext) private var context
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var saturatedFat: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var sodium: String
    @State private var failure: String?

    init(editing: SavedFood?, brand: String, name: String, serving: ServingText, perContainer: Double?,
         onSaved: @escaping (SavedFood) -> Void) {
        self.editing = editing
        self.brand = brand
        self.name = name
        self.serving = serving
        self.perContainer = perContainer
        self.onSaved = onSaved
        _calories = State(initialValue: FoodNumber.text(editing?.calories))
        // A macro stored as 0 shows as "0" when editing (the user may have typed it); a new food starts blank.
        _protein = State(initialValue: FoodNumber.text(editing?.proteinGrams))
        _carbs = State(initialValue: FoodNumber.text(editing?.carbsGrams))
        _fat = State(initialValue: FoodNumber.text(editing?.fatGrams))
        _saturatedFat = State(initialValue: FoodNumber.text(editing?.saturatedFatGrams))
        _fiber = State(initialValue: FoodNumber.text(editing?.fiberGrams))
        _sugar = State(initialValue: FoodNumber.text(editing?.sugarGrams))
        _sodium = State(initialValue: FoodNumber.text(editing?.sodiumMilligrams))
    }

    /// Calories are needed; every other number is blank or a number.
    private var nutrition: FoodNutrition? {
        guard let calories = FoodNumber.parse(calories), let protein = optionalNumber(protein),
              let carbs = optionalNumber(carbs), let fat = optionalNumber(fat),
              let saturatedFat = optionalNumber(saturatedFat), let fiber = optionalNumber(fiber),
              let sugar = optionalNumber(sugar), let sodium = optionalNumber(sodium) else { return nil }
        return FoodNutrition(calories: calories, proteinGrams: protein ?? 0, carbsGrams: carbs ?? 0, fatGrams: fat ?? 0,
                             saturatedFatGrams: saturatedFat, fiberGrams: fiber, sugarGrams: sugar,
                             sodiumMilligrams: sodium)
    }

    private var subtitle: String {
        "\(name.trimmingCharacters(in: .whitespacesAndNewlines)) · \(ServingText.format(value: serving.value, unit: serving.unit, grams: serving.grams))"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Nutrition", subtitle: subtitle)
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Per serving")
                        MacroFields(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat,
                                    fatTitle: "Total fat", identifier: "addFood") {
                            FoodFormField("Saturated fat", text: $saturatedFat, prompt: "Optional", unit: "g",
                                          number: true, identifier: "addFoodSaturatedFat")
                        }
                    }
                    LookList(separatorInset: 16) {
                        FoodFormField("Fiber", text: $fiber, prompt: "Optional", unit: "g", number: true,
                                      identifier: "addFoodFiber")
                        FoodFormField("Sugar", text: $sugar, prompt: "Optional", unit: "g", number: true,
                                      identifier: "addFoodSugar")
                        FoodFormField("Sodium", text: $sodium, prompt: "Optional", unit: "mg", number: true,
                                      identifier: "addFoodSodium")
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            PrimaryButton("Save food", action: save)
                .disabled(nutrition == nil)
                .opacity(nutrition == nil ? 0.4 : 1)
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("addFoodSave")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func save() {
        guard let nutrition else { return }
        let draft = FoodDraft(brand: brand, name: name, serving: serving, servingsPerContainer: perContainer,
                              nutrition: nutrition)
        do {
            if let editing {
                try FoodLog.update(editing, with: draft, in: context)
                onSaved(editing)
            } else {
                onSaved(try FoodLog.createFood(draft, in: context))
            }
        } catch {
            failure = error.localizedDescription
        }
    }
}
