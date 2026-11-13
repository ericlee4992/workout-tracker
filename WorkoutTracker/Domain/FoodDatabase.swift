import Foundation
import SwiftData

// Nutrition N8 (D72): foods from a database — a scanned barcode (Open Food Facts, then USDA branded foods) or a search
// by name (USDA generic foods), through the app's server (server/README → Food databases). N12 (D86): a search in Korean
// comes from 식품의약품안전처's 식품영양성분DB, and a Korean barcode may too (or from Food QR's label). The server
// normalises every source to one shape; the app checks every answer again (the server is not trusted to have) and keeps a food the
// user opens or logs as a `SavedFood` (not one of My foods), so it works offline next time.

/// A scanned code as the server's key: a GTIN with a valid check digit — EAN-8, UPC-A or EAN-13 (a 14-digit GTIN with
/// a leading 0 too) — with UPC-A as its EAN-13 form ("0" + 12 digits), so one product is one code however it was read.
enum FoodBarcode {
    /// The GTIN, or nil when `raw` is not a product code. `upcE`: the scanner read a UPC-E (8 digits, zeros
    /// suppressed), expanded to its UPC-A first.
    static func normalize(_ raw: String, upcE: Bool = false) -> String? {
        var code = raw.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, code.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
        if upcE {
            guard let expanded = expandUPCE(code) else { return nil }
            code = expanded
        }
        guard [8, 12, 13, 14].contains(code.count), code.contains(where: { $0 != "0" }), validCheckDigit(code) else {
            return nil
        }
        if code.count == 12 { return "0" + code }
        if code.count == 14, code.hasPrefix("0") { return String(code.dropFirst()) }
        return code
    }

    /// UPC-E (number system 0 or 1, six digits, check digit) → UPC-A, by the standard zero-suppression rules.
    static func expandUPCE(_ code: String) -> String? {
        let d = code.compactMap(\.wholeNumberValue)
        guard d.count == 8, d.count == code.count, d[0] <= 1 else { return nil }
        let x = Array(d[1...6])
        let body: [Int]
        switch x[5] {
        case 0, 1, 2: body = [x[0], x[1], x[5], 0, 0, 0, 0, x[2], x[3], x[4]]
        case 3: body = [x[0], x[1], x[2], 0, 0, 0, 0, 0, x[3], x[4]]
        case 4: body = [x[0], x[1], x[2], x[3], 0, 0, 0, 0, 0, x[4]]
        default: body = [x[0], x[1], x[2], x[3], x[4], 0, 0, 0, 0, x[5]]
        }
        return ([d[0]] + body + [d[7]]).map(String.init).joined()
    }

    /// The GTIN check digit: weights 3, 1, 3, … from the digit left of the check digit.
    static func validCheckDigit(_ code: String) -> Bool {
        var digits = code.compactMap(\.wholeNumberValue)
        guard digits.count == code.count, let check = digits.popLast() else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 3 : 1) }
        return (10 - sum % 10) % 10 == check
    }
}

/// A food as the server answers (one shape for every database), checked by the app.
struct DatabaseFood: Equatable, Identifiable, Sendable {
    enum Source: String, Sendable {
        case openFoodFacts, usda
        /// N12: 식품의약품안전처 — 식품영양성분DB, and Food QR's label numbers.
        case mfds, foodQR

        /// The prefix of its foods' ids (`SavedFood.databaseID`).
        var idPrefix: String {
            switch self {
            case .openFoodFacts: "off:"
            case .usda: "usda:"
            case .mfds: "mfds:"
            case .foodQR: "foodqr:"
            }
        }
    }
    /// What `per100g` is per: 100 g, or 100 ml for a drink — never converted without a density (codex-review-n8 S2).
    enum Per100Unit: String, Sendable { case g, ml }

    /// N12 (D86): a macro its source leaves blank (kept as 0 in the numbers).
    enum Macro: String, Sendable, CaseIterable { case protein, carbs, fat }

    struct Nutrients: Equatable, Sendable {
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var saturatedFat: Double?
        var fiber: Double?
        var sugar: Double?
        var sodiumMg: Double?

        var nutrition: FoodNutrition {
            FoodNutrition(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat,
                          saturatedFatGrams: saturatedFat, fiberGrams: fiber, sugarGrams: sugar,
                          sodiumMilligrams: sodiumMg)
        }
    }

    struct Serving: Equatable, Sendable {
        var text: String
        var grams: Double?
        var nutrients: Nutrients
    }

    struct Measure: Equatable, Sendable {
        var text: String
        var grams: Double
    }

    /// `off:<code>`, `usda:<fdcId>`, `mfds:<식품코드>` or `foodqr:<code>` (`SavedFood.databaseID`).
    var id: String
    var source: Source
    var name: String
    var brand: String?
    var barcode: String?
    var per100g: Nutrients?
    var per100Unit: Per100Unit
    var serving: Serving?
    var measures: [Measure]
    /// N12: the macros the source leaves blank (the server's `notListed`); empty when it gives all three.
    var notListed: [Macro] = []

    /// ODbL asks for Open Food Facts to be credited wherever its data is shown; USDA's is public domain, and the Korean
    /// ministry's unrestricted (이용허락범위 제한 없음), both credited alike.
    var attribution: String { FoodDatabase.attribution(source) }

    // MARK: Checking the server's answer

    static let maxName = 200
    static let maxServingCalories = 10_000.0
    static let maxPer100gCalories = 900.0  // the server's bound (pure fat), codex-review-n8-b
    static let maxGrams = 100_000.0

    /// A food from the server's JSON, or nil when it is not one the app would log: no name, an unknown source or id,
    /// numbers that are not finite and within bounds, or neither per-100 g nor serving nutrition.
    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let sourceText = json["source"] as? String,
              let source = Source(rawValue: sourceText),
              id.hasPrefix(source.idPrefix), id.count <= 64,
              let name = Self.text(json["name"], max: Self.maxName) else { return nil }
        // A missing unit is grams (the server always sends one); an unknown one is not a food the app understands.
        guard let unit = json["per100Unit"] == nil ? .g : (json["per100Unit"] as? String).flatMap(Per100Unit.init) else {
            return nil
        }
        let per100g = (json["per100g"] as? [String: Any]).flatMap {
            Self.nutrients($0, basis: 100, unit: unit, maxCalories: Self.maxPer100gCalories)
        }
        var serving: Serving?
        if let raw = json["serving"] as? [String: Any], let text = Self.text(raw["text"], max: 120) {
            let grams = Self.number(raw["grams"]).flatMap { $0 > 0 && $0 <= Self.maxGrams ? $0 : nil }
            if let nutrients = (raw["nutrients"] as? [String: Any]).flatMap({
                Self.nutrients($0, basis: grams, unit: grams == nil ? .ml : .g, maxCalories: Self.maxServingCalories)
            }) {
                serving = Serving(text: text, grams: grams, nutrients: nutrients)
            }
        }
        guard per100g != nil || serving != nil else { return nil }
        let measures = (json["measures"] as? [[String: Any]] ?? []).compactMap { raw -> Measure? in
            guard let text = Self.text(raw["text"], max: 120), let grams = Self.number(raw["grams"]), grams > 0,
                  grams <= Self.maxGrams else { return nil }
            return Measure(text: text, grams: grams)
        }
        // Unknown names are ignored (a newer server may say more); each macro once, in a fixed order.
        let blank = Set((json["notListed"] as? [String] ?? []).compactMap(Macro.init(rawValue:)))
        self.init(id: id, source: source, name: name, brand: Self.text(json["brand"], max: 100),
                  barcode: (json["barcode"] as? String).flatMap { FoodBarcode.normalize($0) },
                  per100g: per100g, per100Unit: unit, serving: serving, measures: Array(measures.prefix(6)),
                  notListed: Macro.allCases.filter(blank.contains))
    }

    init(id: String, source: Source, name: String, brand: String? = nil, barcode: String? = nil,
         per100g: Nutrients? = nil, per100Unit: Per100Unit = .g, serving: Serving? = nil, measures: [Measure] = [],
         notListed: [Macro] = []) {
        self.id = id
        self.source = source
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.per100g = per100g
        self.per100Unit = per100Unit
        self.serving = serving
        self.measures = measures
        self.notListed = notListed
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }

    private static func text(_ value: Any?, max: Int) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              text.count <= max, !text.contains(where: { $0.isNewline }) else { return nil }
        return text
    }

    /// A serving of unknown weight is bounded loosely: no serving holds more than this of one nutrient.
    static let unknownServingGrams = 2_000.0

    /// The server's bounds, checked again (codex-review-n8 S5): every value finite and not negative; no nutrient — nor
    /// protein + carbs + fat together — weighing more than its basis (a millilitre may weigh up to 1.5 g), sodium
    /// likewise in mg, at most 9 kcal a gram. Any value out of bounds makes the set unusable.
    private static func nutrients(_ raw: [String: Any], basis: Double?, unit: Per100Unit, maxCalories: Double) -> Nutrients? {
        let limit = (basis ?? unknownServingGrams) * (unit == .ml ? 1.5 : 1.05)
        func grams(_ key: String, max: Double) -> Double?? {
            guard let value = raw[key], !(value is NSNull) else { return .some(nil) }
            guard let n = number(value), n >= 0, n <= max else { return nil }
            return .some(n)
        }
        guard let calories = number(raw["calories"]), calories >= 0, calories <= maxCalories,
              basis == nil || calories <= limit * 9,
              let protein = grams("protein", max: limit), let carbs = grams("carbs", max: limit),
              let fat = grams("fat", max: limit), let saturated = grams("saturatedFat", max: limit),
              let fiber = grams("fiber", max: limit), let sugar = grams("sugar", max: limit),
              let sodium = grams("sodiumMg", max: limit * 1000),
              (protein ?? 0) + (carbs ?? 0) + (fat ?? 0) <= limit else { return nil }
        return Nutrients(calories: calories, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0,
                         saturatedFat: saturated, fiber: fiber, sugar: sugar, sodiumMg: sodium)
    }
}

/// Why a lookup did not answer, in the words the app shows. Every case leaves Manual Add and the label scan open.
enum FoodDatabaseError: LocalizedError, Equatable {
    case signedOut
    case offline
    case timedOut
    /// 429 `food_limit`: today's lookups are used up.
    case limit
    /// 502 `food_unavailable` and other server failures: a database did not answer.
    case unavailable
    /// 503 `server_not_configured`: online search is not set up yet (no USDA key).
    case notConfigured
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in again, then try again."
        case .offline: "No connection. Try again."
        case .timedOut: "Took too long. Try again."
        case .limit: "Too many lookups today. Try again tomorrow."
        case .unavailable, .rejected: "The food database didn't answer. Try again."
        case .notConfigured: "Online search isn't available yet."
        }
    }
}

/// What a barcode lookup answers: the food, or — not found — what a source calls the product (N12: prefills the
/// "Is this it?" search; a Korean name when a Korean source has one).
struct BarcodeAnswer: Equatable, Sendable {
    var food: DatabaseFood?
    var name: String?
}

/// `GET /v1/food/barcode/:code` and `GET /v1/food/search?q=` with the session. Nothing here logs the token, the code
/// or the query.
struct FoodDatabaseClient: Sendable {
    let baseURL: URL
    let token: String
    var session: URLSession = .shared
    /// Called with the refused session on a 401, so the app signs out (as the AI client does).
    var onUnauthorized: @Sendable (String) -> Void = { _ in }
    /// Longer than the server's two 8 s upstream calls.
    static let timeout: TimeInterval = 25

    func request(path: String, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// The food for a normalised barcode; not found (no database has a usable one), the name a source gave, if any.
    func barcode(_ code: String) async throws -> BarcodeAnswer {
        let object = try await get(request(path: "v1/food/barcode/\(code)"))
        guard let found = object["found"] as? Bool else { throw FoodDatabaseError.unavailable }
        let name = (object["name"] as? String).flatMap(FoodDatabase.productName)
        guard found else { return BarcodeAnswer(name: name) }
        // Found, but not a food the app would log: as good as not found.
        return BarcodeAnswer(food: (object["food"] as? [String: Any]).flatMap(DatabaseFood.init(json:)), name: name)
    }

    /// Up to ten foods for `query`; the ones the app would not log are dropped.
    func search(_ query: String) async throws -> [DatabaseFood] {
        let object = try await get(request(path: "v1/food/search", query: [URLQueryItem(name: "q", value: query)]))
        guard let foods = object["foods"] as? [[String: Any]] else { throw FoodDatabaseError.unavailable }
        return foods.compactMap(DatabaseFood.init(json:))
    }

    private func get(_ request: URLRequest) async throws -> [String: Any] {
        try Task.checkCancellation()
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw FoodDatabaseError.timedOut
            default: throw FoodDatabaseError.offline
            }
        }
        try Task.checkCancellation()
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw FoodDatabaseError.unavailable }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if (200..<300).contains(status) {
            guard let object else { throw FoodDatabaseError.unavailable }
            return object
        }
        let code = object?["error"] as? String
        switch (status, code) {
        case (401, _):
            onUnauthorized(token)
            throw FoodDatabaseError.signedOut
        case (429, _): throw FoodDatabaseError.limit
        case (503, "server_not_configured"): throw FoodDatabaseError.notConfigured
        case (500..., _): throw FoodDatabaseError.unavailable
        default: throw FoodDatabaseError.rejected(code ?? "status_\(status)")
        }
    }
}

enum FoodDatabase {
    static func attribution(_ source: DatabaseFood.Source) -> String {
        switch source {
        case .openFoodFacts: "Food data from Open Food Facts"
        case .usda: "Food data from USDA FoodData Central"
        case .mfds, .foodQR: "Food data from Korea's Ministry of Food and Drug Safety"
        }
    }

    /// The credit for a saved food that came from a database (by its id's prefix), nil for the user's own.
    static func attribution(databaseID: String?) -> String? {
        guard let databaseID else { return nil }
        for source in [DatabaseFood.Source.openFoodFacts, .usda, .mfds, .foodQR] where databaseID.hasPrefix(source.idPrefix) {
            return attribution(source)
        }
        return nil
    }

    /// The credits for foods shown together: one line per database, in a stable order.
    static func attributions(_ foods: [DatabaseFood]) -> [String] {
        Set(foods.map { attribution($0.source) }).sorted()
    }

    /// N12 (D86): which macros a kept database food's source leaves blank, by its database id. Kept beside the store,
    /// not in it — a note for display, so `SavedFood` keeps its stored format (no migration); what the source says,
    /// never guessed from the numbers (codex-review-n12 R2). Written whenever a database food is saved.
    nonisolated(unsafe) static var notListedDefaults: UserDefaults = .standard
    static let notListedKey = "foodDatabaseNotListed"

    static func notListed(databaseID: String?) -> [DatabaseFood.Macro] {
        guard let databaseID,
              let names = (notListedDefaults.dictionary(forKey: notListedKey) as? [String: [String]])?[databaseID] else { return [] }
        let blank = Set(names.compactMap(DatabaseFood.Macro.init(rawValue:)))
        return DatabaseFood.Macro.allCases.filter(blank.contains)
    }

    static func setNotListed(_ macros: [DatabaseFood.Macro], databaseID: String) {
        var all = notListedDefaults.dictionary(forKey: notListedKey) as? [String: [String]] ?? [:]
        all[databaseID] = macros.isEmpty ? nil : macros.map(\.rawValue)
        notListedDefaults.set(all, forKey: notListedKey)
    }

    /// The note under a food's macros: "Fat isn't listed for this food; it counts as 0." — nil when nothing is blank.
    static func notListedNote(_ macros: [DatabaseFood.Macro]) -> String? {
        let names = macros.map { macro in
            switch macro {
            case .protein: "protein"
            case .carbs: "carbs"
            case .fat: "fat"
            }
        }
        guard let first = names.first else { return nil }
        let list = names.count == 1 ? first : names.dropLast().joined(separator: ", ") + " and " + names.last!
        let subject = list.prefix(1).uppercased() + list.dropFirst()
        // "Carbs" reads as plural; one other macro is singular.
        let plural = names.count > 1 || first == "carbs"
        return "\(subject) \(plural ? "aren't" : "isn't") listed for this food; \(plural ? "they count" : "it counts") as 0."
    }

    /// A product name the server sent for the "Is this it?" search: one line, 1–200 characters.
    static func productName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200, !name.contains(where: \.isNewline) else { return nil }
        return name
    }

    /// Whether a search is long enough to ask the server: two characters, or one in Korean (밥, 떡 — N12).
    static func searchable(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.count >= 2 || (query.count == 1 && containsHangul(query))
    }

    /// Hangul syllables or jamo: such a search goes to the Korean database (the server decides; the app only words it).
    static func containsHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x1100...0x11FF).contains($0.value) || (0x3130...0x318F).contains($0.value)
            || (0xAC00...0xD7AF).contains($0.value) }
    }

    /// The food already on the phone for a scanned code — so a food logged once scans offline: one of My foods first,
    /// then the most recently logged.
    static func local(barcode code: String, in foods: [SavedFood]) -> SavedFood? {
        foods.filter { $0.barcode.flatMap { FoodBarcode.normalize($0) } == code }
            .sorted { left, right in
                if left.createdByUser != right.createdByUser { return left.createdByUser }
                return (left.lastUsedAt ?? .distantPast) > (right.lastUsedAt ?? .distantPast)
            }
            .first
    }

    /// How a database food is kept: its main serving with that serving's nutrition, and the other portions it can be
    /// logged by (each with grams, so it scales). The main serving is the source's (the package's, or a household
    /// portion) when it has one, else 100 g.
    static func storedServing(_ food: DatabaseFood) -> (serving: ServingText, nutrition: FoodNutrition, options: [ServingOption]) {
        var options = food.measures.map { measure -> ServingOption in
            let parsed = ServingText.parse(measure.text)
            return ServingOption(value: parsed?.value ?? 1, unit: parsed?.unit ?? measure.text, grams: measure.grams)
        }
        if let serving = food.serving {
            let parsed = ServingText.parse(serving.text)
            // The source's grams, not any the words imply; a drink in millilitres has none.
            let main = ServingText(value: parsed?.value ?? 1, unit: parsed?.unit ?? serving.text, grams: serving.grams)
            if food.per100g != nil, food.per100Unit == .g, main.grams != nil, main.grams != 100 {
                options.append(ServingOption(value: 100, unit: "g", grams: 100))
            }
            return (main, serving.nutrients.nutrition, options)
        }
        // per100g is present whenever serving is not (DatabaseFood.init). A drink's is 100 ml, with no weight claimed —
        // so no other serving scales from it (codex-review-n8 S2).
        if food.per100Unit == .ml {
            return (ServingText(value: 100, unit: "ml", grams: nil), food.per100g!.nutrition, [])
        }
        return (ServingText(value: 100, unit: "g", grams: 100), food.per100g!.nutrition, options)
    }

    /// Keeps `food` on the phone (or refreshes the copy already kept, found by its database id): a `SavedFood` that is
    /// not one of My foods and is not in Recently logged until it is logged. Past entries keep their own snapshot.
    @discardableResult
    static func save(_ food: DatabaseFood, at date: Date = .now, in context: ModelContext) throws -> SavedFood {
        let id: String? = food.id
        let existing = try context.fetch(FetchDescriptor<SavedFood>(predicate: #Predicate { $0.databaseID == id }))
            .first { !$0.createdByUser }
        let stored = storedServing(food)
        let saved = existing ?? SavedFood(name: food.name, databaseID: food.id, calories: 0, createdAt: date)
        if existing == nil { context.insert(saved) }
        saved.name = food.name
        saved.brand = food.brand
        // A source without a barcode (a search result) keeps the one the user linked ("Is this it?", N12).
        saved.barcode = food.barcode ?? saved.barcode
        saved.servingValue = stored.serving.value
        saved.servingUnit = stored.serving.unit
        saved.servingGrams = stored.serving.grams
        let n = stored.nutrition
        saved.calories = n.calories
        saved.proteinGrams = n.proteinGrams
        saved.carbsGrams = n.carbsGrams
        saved.fatGrams = n.fatGrams
        saved.saturatedFatGrams = n.saturatedFatGrams
        saved.fiberGrams = n.fiberGrams
        saved.sugarGrams = n.sugarGrams
        saved.sodiumMilligrams = n.sodiumMilligrams
        saved.servingOptions = stored.options
        saved.updatedAt = date
        try context.save()
        setNotListed(food.notListed, databaseID: food.id)
        return saved
    }

    /// N12: the barcode a food was confirmed for ("Is this it?") — a scanned code links it, so the next scan opens it.
    static func link(_ food: SavedFood, barcode code: String, in context: ModelContext) throws {
        guard FoodBarcode.normalize(code) == code, food.barcode != code else { return }
        food.barcode = code
        food.updatedAt = .now
        try context.save()
    }
}
