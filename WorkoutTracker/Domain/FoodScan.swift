import Foundation
import ImageIO
import SwiftData

// Nutrition N7 — Scan Food's domain: the server's food replies read and checked as the server checks them (the server
// is not trusted to have), a meal photo or a description logged as ONE entry named for the meal with its items (D82,
// D83), its edits, a label logged (optionally as one of My foods), and when a picked photo was taken.

/// A food-photo or food-describe reply (N6 + D83's `mealName`): the meal's name and its items.
struct FoodEstimate: Equatable {
    struct Item: Equatable, Identifiable {
        var id = UUID()
        var name: String
        var portion: String
        var grams: Double?
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double

        var macros: Macros { Macros(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat) }
    }

    var mealName: String
    var items: [Item]

    var totals: Macros { items.reduce(Macros.zero) { $0 + $1.macros } }

    /// The entry's name: the meal's, else (an older or odd reply) the first item's.
    var entryName: String {
        let name = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? (items.first?.name ?? "") : name
    }

    private struct Wire: Decodable {
        struct Item: Decodable { var name: String; var portion: String; var grams: Double; var calories: Double
            var protein: Double; var carbs: Double; var fat: Double; var confidence: String }
        var mealName: String?
        var items: [Item]
    }

    /// The reply, or nil when it breaks the server's own bounds (at most 15 items, each named, numbers finite, ≥ 0 and
    /// within a plate's limits). No items is a valid answer: nothing was recognised.
    static func parse(_ data: Data) -> FoodEstimate? {
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data), wire.items.count <= 15 else { return nil }
        let within = { (value: Double, max: Double) in value.isFinite && value >= 0 && value <= max }
        var items: [Item] = []
        for item in wire.items {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 100, item.portion.count <= 100, within(item.grams, 5000),
                  within(item.calories, 10000), within(item.protein, 1000), within(item.carbs, 1000),
                  within(item.fat, 1000), ["high", "medium", "low"].contains(item.confidence) else { return nil }
            items.append(Item(name: name, portion: item.portion.trimmingCharacters(in: .whitespacesAndNewlines),
                              grams: item.grams > 0 ? item.grams : nil, calories: item.calories,
                              protein: item.protein, carbs: item.carbs, fat: item.fat))
        }
        let mealName = (wire.mealName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard mealName.count <= 60 else { return nil }
        return FoodEstimate(mealName: mealName, items: items)
    }
}

/// A food-label reply (N6): the numbers printed for one serving, nil where not printed.
struct FoodLabelReading: Equatable {
    var found: Bool
    var servingSize: String
    var servingGrams: Double?
    var servingsPerContainer: Double?
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var saturatedFat: Double?
    var fiber: Double?
    var sugar: Double?
    var sodiumMg: Double?

    private struct Wire: Decodable {
        var found: Bool
        var servingSize: String
        var servingGrams: Double?
        var servingsPerContainer: Double?
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var saturatedFat: Double?
        var fiber: Double?
        var sugar: Double?
        var sodiumMg: Double?
    }

    /// The reply, or nil when a number is negative, not finite or beyond a serving's bounds (as the server checks).
    static func parse(_ data: Data) -> FoodLabelReading? {
        guard let w = try? JSONDecoder().decode(Wire.self, from: data), w.servingSize.count <= 100 else { return nil }
        let ok = { (value: Double?, max: Double) in value.map { $0.isFinite && $0 >= 0 && $0 <= max } ?? true }
        guard ok(w.servingGrams, 5000), ok(w.servingsPerContainer, 1000), ok(w.calories, 5000), ok(w.protein, 1000),
              ok(w.carbs, 1000), ok(w.fat, 1000), ok(w.saturatedFat, 1000), ok(w.fiber, 1000), ok(w.sugar, 1000),
              ok(w.sodiumMg, 50000) else { return nil }
        return FoodLabelReading(found: w.found, servingSize: w.servingSize.trimmingCharacters(in: .whitespaces),
                                servingGrams: w.servingGrams, servingsPerContainer: w.servingsPerContainer,
                                calories: w.calories, protein: w.protein, carbs: w.carbs, fat: w.fat,
                                saturatedFat: w.saturatedFat, fiber: w.fiber, sugar: w.sugar, sodiumMg: w.sodiumMg)
    }

    /// A label is usable when it was found and printed calories.
    var isUsable: Bool { found && calories != nil }

    /// The serving as printed ("2/3 cup (55 g)" → 2/3 cup, 55 g); a size that does not parse is one serving, with the
    /// printed grams when there are any.
    var serving: ServingText {
        var serving = ServingText.parse(servingSize) ?? ServingText(value: 1, unit: ServingText.defaultUnit)
        if serving.grams == nil { serving.grams = servingGrams }
        return serving
    }

    var nutrition: FoodNutrition {
        FoodNutrition(calories: calories ?? 0, proteinGrams: protein ?? 0, carbsGrams: carbs ?? 0, fatGrams: fat ?? 0,
                      saturatedFatGrams: saturatedFat, fiberGrams: fiber, sugarGrams: sugar, sodiumMilligrams: sodiumMg)
    }

    /// The label as a food for Add food's model (the name and brand are the user's).
    func draft(name: String, brand: String?) -> FoodDraft {
        FoodDraft(brand: brand, name: name, serving: serving, servingsPerContainer: servingsPerContainer,
                  nutrition: nutrition)
    }
}

enum FoodScan {
    /// When a photo's meal was eaten: a library photo's own date when it has one (D83 — "use the photo's time for
    /// library picks"), never in the future; otherwise now. The meal follows that time.
    static func when(photoTaken: Date?, now: Date = .now) -> (date: Date, meal: MealSlot) {
        let date = photoTaken.map { min($0, now) } ?? now
        return (date, MealSlot.forTime(date))
    }

    /// Logs an estimate as ONE entry named for the meal (D83): its numbers the sum of the items, one serving, the
    /// photo kept with it (D82). An estimate with no items logs nothing (the caller shows "No food found").
    @discardableResult
    static func log(_ estimate: FoodEstimate, photo: Data?, source: FoodSource, meal: MealSlot, at date: Date,
                    now: Date = .now, in context: ModelContext) throws -> FoodEntry {
        let totals = estimate.totals
        let entry = FoodEntry(loggedAt: date, meal: meal, name: estimate.entryName, servings: 1, servingValue: 1,
                              servingUnit: ServingText.defaultUnit, calories: totals.calories,
                              proteinGrams: totals.proteinGrams, carbsGrams: totals.carbsGrams,
                              fatGrams: totals.fatGrams, source: source, createdAt: now)
        context.insert(entry)
        if let photo { entry.photo = FoodPhoto(data: photo) }
        entry.items = items(estimate.items)
        try context.save()
        return entry
    }

    /// An edit on the items screen: the name, the meal and the items (changed, removed, added) replace what was
    /// there; the entry's numbers become the items' sum again.
    static func update(_ entry: FoodEntry, name: String, meal: MealSlot, items edited: [FoodEstimate.Item],
                       at date: Date = .now, in context: ModelContext) throws {
        for item in entry.items ?? [] { context.delete(item) }
        entry.items = items(edited)
        let totals = edited.reduce(Macros.zero) { $0 + $1.macros }
        entry.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.meal = meal
        entry.servings = 1
        entry.calories = totals.calories
        entry.proteinGrams = totals.proteinGrams
        entry.carbsGrams = totals.carbsGrams
        entry.fatGrams = totals.fatGrams
        entry.updatedAt = date
        try context.save()
    }

    /// The entry's items as the editor's values.
    static func editable(_ entry: FoodEntry) -> [FoodEstimate.Item] {
        entry.orderedItems.map { item in
            FoodEstimate.Item(id: item.id, name: item.name, portion: item.portion, grams: item.grams,
                              calories: item.calories, protein: item.proteinGrams, carbs: item.carbsGrams,
                              fat: item.fatGrams)
        }
    }

    private static func items(_ values: [FoodEstimate.Item]) -> [FoodEntryItem] {
        values.enumerated().map { index, item in
            FoodEntryItem(id: item.id, order: index, name: item.name, portion: item.portion, grams: item.grams,
                          calories: item.calories, proteinGrams: item.protein, carbsGrams: item.carbs,
                          fatGrams: item.fat)
        }
    }

    /// A label logged (N7): as one of My foods when the user keeps "Save to My foods" on — then it is in My foods
    /// for the next time — else as a one-off entry. Either way the entry's source is the label.
    @discardableResult
    static func logLabel(_ draft: FoodDraft, servings: Double, meal: MealSlot, saveToMyFoods: Bool, at date: Date = .now,
                         in context: ModelContext) throws -> FoodLogReceipt {
        if saveToMyFoods {
            let food = try FoodLog.createFood(draft, at: date, in: context)
            return try FoodLog.log(food, servings: servings, meal: meal, at: date, source: .label, in: context)
        }
        let n = draft.nutrition
        let brand = draft.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = FoodEntry(loggedAt: date, meal: meal, name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                              brand: brand?.isEmpty == false ? brand : nil, servings: servings,
                              servingValue: draft.serving.value, servingUnit: draft.serving.unit,
                              servingGrams: draft.serving.grams, calories: n.calories, proteinGrams: n.proteinGrams,
                              carbsGrams: n.carbsGrams, fatGrams: n.fatGrams, fiberGrams: n.fiberGrams,
                              sugarGrams: n.sugarGrams, saturatedFatGrams: n.saturatedFatGrams,
                              sodiumMilligrams: n.sodiumMilligrams, source: .label, createdAt: date)
        context.insert(entry)
        try context.save()
        return FoodLogReceipt(title: entry.name, calories: n.calories * servings, entries: [entry])
    }
}

/// When a photo was taken, from its own metadata (EXIF DateTimeOriginal, with its offset when recorded; TIFF DateTime
/// otherwise) — no photo-library permission needed, the picked file carries it.
enum PhotoDate {
    static func taken(in data: Data, zone: TimeZone = .current) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        guard let text = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
                ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String) else { return nil }
        let offset = exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String
        return parse(text, offset: offset, zone: zone)
    }

    /// "2026:11:10 12:40:05" (+ "-05:00") → the instant; without an offset, the phone's zone.
    static func parse(_ text: String, offset: String?, zone: TimeZone = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        if let offset, let parsed = TimeZone(offsetText: offset) {
            formatter.timeZone = parsed
        } else {
            formatter.timeZone = zone
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }
}

private extension TimeZone {
    /// "+05:30" / "-05:00" → a fixed-offset zone.
    init?(offsetText: String) {
        let sign: Int
        switch offsetText.first {
        case "+": sign = 1
        case "-": sign = -1
        default: return nil
        }
        let parts = offsetText.dropFirst().split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        self.init(secondsFromGMT: sign * (hours * 3600 + minutes * 60))
    }
}
