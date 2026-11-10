import Foundation

/// Nutrition N4 — **MOCK for the user's review** (2026-11-10): sample foods for the Log Food screens, nothing stored.
/// Replaced by the user's own recent and saved foods (`SavedFood`, `FoodEntry`) when the screens are wired.
struct MockFood: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var brand: String?
    var serving: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var saved = false

    var macros: Macros { Macros(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat) }

    static let recent: [MockFood] = [
        MockFood(name: "Greek yogurt", brand: "Fage", serving: "1 container (170 g)", calories: 100, protein: 18,
                 carbs: 6, fat: 0.5, saved: true),
        MockFood(name: "Chicken breast", serving: "100 g", calories: 165, protein: 31, carbs: 0, fat: 3.6, saved: true),
        MockFood(name: "Banana", serving: "1 medium", calories: 105, protein: 1.3, carbs: 27, fat: 0.4),
        MockFood(name: "Protein shake", brand: "Optimum", serving: "1 scoop (31 g)", calories: 120, protein: 24,
                 carbs: 3, fat: 1.5, saved: true),
        MockFood(name: "Oatmeal", serving: "40 g", calories: 150, protein: 5, carbs: 27, fat: 3),
    ]

    static let myMeals: [(name: String, detail: String, calories: Double)] = [
        ("Usual breakfast", "Oatmeal, Banana, Greek yogurt", 355),
        ("Post-workout", "Protein shake, Banana", 225),
    ]
}

extension MealSlot {
    var label: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snacks: "Snacks"
        }
    }

    /// The meal a log defaults to by the time of day: breakfast before 10:30, lunch before 15:00, dinner before 21:00,
    /// else snacks.
    static func forTime(_ date: Date, calendar: Calendar = .current) -> MealSlot {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        switch minutes {
        case ..<(10 * 60 + 30): return .breakfast
        case ..<(15 * 60): return .lunch
        case ..<(21 * 60): return .dinner
        default: return .snacks
        }
    }
}
