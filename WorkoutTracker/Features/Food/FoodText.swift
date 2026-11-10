import Foundation

extension MealSlot {
    /// The meal's name on its chip and in "Log to Breakfast".
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

enum FoodCopy {
    /// "380 cal" — whole calories.
    static func calories(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0)))) cal" }

    /// A food row's second line: "Fage · 100 cal · 1 container (170 g)".
    static func foodLine(brand: String?, calories: Double, serving: String) -> String {
        [brand, Self.calories(calories), serving].compactMap(\.self).joined(separator: " · ")
    }

    /// The Undo toast: "Logged Greek yogurt to Breakfast"; a Manual Add without a name says its calories.
    static func logged(_ receipt: FoodLogReceipt, to meal: MealSlot) -> String {
        "Logged \(receipt.title ?? calories(receipt.calories)) to \(meal.label)"
    }

    static let saveFailed = "Couldn't save"
}
