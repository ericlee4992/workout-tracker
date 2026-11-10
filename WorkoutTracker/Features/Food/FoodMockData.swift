import Foundation

/// Nutrition N4 — **MOCK for the user's review** (2026-11-10, reworked to D81): sample foods for the Log Food screens,
/// nothing stored. Replaced by the user's own foods (`SavedFood`, `FoodEntry`) when the screens are wired.
struct MockFood: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var brand: String?
    var serving: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var saturatedFat: Double?
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    /// Optional on the user's own foods (D81).
    var servingsPerContainer: Double?
    /// In My foods: made by the user with Add food (D81).
    var mine = false
    /// In Saved foods: bookmarked from anywhere (D81).
    var saved = false
    /// Among "Recently logged" on All.
    var recent = true

    var macros: Macros { Macros(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat) }

    static let all: [MockFood] = [
        MockFood(name: "Greek yogurt", brand: "Fage", serving: "1 container (170 g)", calories: 100, protein: 18,
                 carbs: 6, fat: 0.5, saturatedFat: 0.3, fiber: 0, sugar: 6, sodium: 65, saved: true),
        MockFood(name: "Overnight oats", serving: "1 jar", calories: 380, protein: 22, carbs: 52, fat: 9,
                 saturatedFat: 2, fiber: 8, sugar: 14, sodium: 120, mine: true, saved: true),
        MockFood(name: "Chicken breast", serving: "100 g", calories: 165, protein: 31, carbs: 0, fat: 3.6,
                 saturatedFat: 1, sodium: 74, saved: true),
        MockFood(name: "Banana", serving: "1 medium", calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1,
                 sugar: 14),
        MockFood(name: "Protein shake", brand: "Optimum", serving: "1 scoop (31 g)", calories: 120, protein: 24,
                 carbs: 3, fat: 1.5, servingsPerContainer: 74, saved: true),
        MockFood(name: "Turkey chili", serving: "1 bowl", calories: 420, protein: 38, carbs: 34, fat: 14,
                 saturatedFat: 4, fiber: 9, sodium: 780, servingsPerContainer: 6, mine: true),
        MockFood(name: "Protein pancakes", serving: "3 pancakes", calories: 310, protein: 28, carbs: 30, fat: 8,
                 mine: true, recent: false),
    ]

    /// UI-test switch for the mock's empty My foods / Saved foods (`-logFoodMockEmpty`).
    static var showsEmpty: Bool { ProcessInfo.processInfo.arguments.contains("-logFoodMockEmpty") }

    static var recentFoods: [MockFood] { all.filter(\.recent) }
    static var myFoods: [MockFood] { showsEmpty ? [] : all.filter(\.mine) }
    static var savedFoods: [MockFood] { showsEmpty ? [] : all.filter(\.saved) }

    static let myMeals: [(name: String, detail: String, calories: Double)] = [
        ("Usual breakfast", "Overnight oats, Banana", 485),
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
