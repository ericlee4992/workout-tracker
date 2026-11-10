import SwiftUI

/// Nutrition N4 — Add food (D81): creates one of **My foods** in two steps, like the user's reference. Step 1 names the
/// food and its serving (brand and servings per container optional) → Next → step 2, its nutrition per serving →
/// Save food. Reached from the bottom of the My foods tab, and as Edit (filled in) from one of My foods. **MOCK for the
/// user's review**: nothing is stored.
///
/// Step 1's eye lands on the description (the one field the food needs to exist); step 2's on calories, first in the
/// list. Next / Save food is the one primary command at the bottom of each step.
struct AddFoodView: View {
    var editing: MockFood?
    @Environment(\.look) private var look
    @State private var brand: String
    @State private var name: String
    @State private var serving: String
    @State private var perContainer: String
    @State private var next = false

    init(editing: MockFood? = nil) {
        self.editing = editing
        _brand = State(initialValue: editing?.brand ?? "")
        _name = State(initialValue: editing?.name ?? "")
        _serving = State(initialValue: editing?.serving ?? "")
        _perContainer = State(initialValue: editing?.servingsPerContainer?.formatted() ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle(editing == nil ? "Add food" : "Edit food")
                    LookList(separatorInset: 16) {
                        FoodFormField("Brand", text: $brand, prompt: "Optional")
                        FoodFormField("Description", text: $name, prompt: "e.g. Overnight oats")
                    }
                    LookList(separatorInset: 16) {
                        FoodFormField("Serving size", text: $serving, prompt: "e.g. 1 cup")
                        FoodFormField("Servings per container", text: $perContainer, prompt: "Optional", number: true)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Next") { next = true }
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("addFoodNext")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $next) {
            AddFoodNutritionView(editing: editing, name: name, serving: serving)
        }
    }
}

/// Add food, step 2: the nutrition of one serving. Calories, protein, carbs, total fat and saturated fat first (the
/// user's reference order), then fiber, sugar and sodium — the facts a saved food stores (N2).
struct AddFoodNutritionView: View {
    var editing: MockFood?
    var name: String
    var serving: String
    @Environment(\.look) private var look
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var saturatedFat: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var sodium: String

    init(editing: MockFood?, name: String, serving: String) {
        self.editing = editing
        self.name = name
        self.serving = serving
        func text(_ value: Double?) -> String { value.map { $0.formatted() } ?? "" }
        _calories = State(initialValue: text(editing?.calories))
        _protein = State(initialValue: text(editing?.protein))
        _carbs = State(initialValue: text(editing?.carbs))
        _fat = State(initialValue: text(editing?.fat))
        _saturatedFat = State(initialValue: text(editing?.saturatedFat))
        _fiber = State(initialValue: text(editing?.fiber))
        _sugar = State(initialValue: text(editing?.sugar))
        _sodium = State(initialValue: text(editing?.sodium))
    }

    private var subtitle: String? {
        let parts = [name, serving].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Nutrition", subtitle: subtitle)
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Per serving")
                        MacroFields(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat,
                                    fatTitle: "Total fat") {
                            FoodFormField("Saturated fat", text: $saturatedFat, prompt: "Optional", unit: "g",
                                          number: true)
                        }
                    }
                    LookList(separatorInset: 16) {
                        FoodFormField("Fiber", text: $fiber, prompt: "Optional", unit: "g", number: true)
                        FoodFormField("Sugar", text: $sugar, prompt: "Optional", unit: "g", number: true)
                        FoodFormField("Sodium", text: $sodium, prompt: "Optional", unit: "mg", number: true)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Save food") {}
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("addFoodSave")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}
