import Foundation

/// Nutrition N8: the barcode lookup and the online search, through the server — or, in UI tests (`-uiTestTerra`), the
/// fixture below, which stands in for the server (no network). Flags: `-uiTestBarcodeNotFound` (neither database has
/// it), `-uiTestTerraOffline` (no connection), `-uiTestFoodSearchOff` (search not set up on the server).
enum FoodDatabaseAccess {
    /// The server client for this session; nil signed out. A 401 signs the phone out, as the AI client does.
    @MainActor static func client(_ account: AccountStore) -> FoodDatabaseClient? {
        guard let baseURL = account.client?.baseURL, let token = account.token else { return nil }
        return FoodDatabaseClient(baseURL: baseURL, token: token, onUnauthorized: { [weak account] refused in
            Task { @MainActor in account?.invalidate(token: refused) }
        })
    }

    static func barcode(_ code: String, client: FoodDatabaseClient?) async throws -> DatabaseFood? {
        if TerraAccess.fixture { return try await FoodDatabaseFixture.barcode(code) }
        guard let client else { throw FoodDatabaseError.signedOut }
        return try await client.barcode(code)
    }

    static func search(_ query: String, client: FoodDatabaseClient?) async throws -> [DatabaseFood] {
        if TerraAccess.fixture { return try await FoodDatabaseFixture.search(query) }
        guard let client else { throw FoodDatabaseError.signedOut }
        return try await client.search(query)
    }
}

/// The UI tests' food databases: one packaged food for any barcode, and a few generic foods by name. Shaped as the
/// server answers, through the same checks (`DatabaseFood(json:)`).
enum FoodDatabaseFixture {
    /// The code the fixture camera "reads" in Barcode mode (a valid EAN-13).
    static let barcode = "3017620422003"

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    private static func wait() async throws {
        try await Task.sleep(for: .milliseconds(arguments.contains("-uiTestTerraSlow") ? 4000 : 400))
        if arguments.contains("-uiTestTerraOffline") { throw FoodDatabaseError.offline }
    }

    static func barcode(_ code: String) async throws -> DatabaseFood? {
        try await wait()
        if arguments.contains("-uiTestBarcodeNotFound") { return nil }
        return DatabaseFood(json: [
            "id": "off:\(code)", "source": "openFoodFacts", "name": "Hazelnut spread", "brand": "Sample Pantry",
            "barcode": code,
            "per100g": nutrients(539, 6.3, 57.5, 30.9, saturatedFat: 10.6, fiber: 0, sugar: 56.3, sodiumMg: 42.8),
            "serving": ["text": "15 g", "grams": 15,
                        "nutrients": nutrients(81, 0.9, 8.6, 4.6, saturatedFat: 1.6, fiber: 0, sugar: 8.4, sodiumMg: 6.4)],
            "measures": [] as [Any],
        ])
    }

    static func search(_ query: String) async throws -> [DatabaseFood] {
        try await wait()
        if arguments.contains("-uiTestFoodSearchOff") { throw FoodDatabaseError.notConfigured }
        let q = query.lowercased()
        var foods: [[String: Any]] = []
        if q.contains("banana") {
            foods = [
                generic(173_944, "Bananas, raw", nutrients(89, 1.1, 22.8, 0.3, fiber: 2.6, sugar: 12.2, sodiumMg: 1),
                        measures: [("1 medium", 118), ("1 cup, sliced", 150)]),
                generic(2_709_226, "Banana chips", nutrients(519, 2.3, 58.4, 33.6, fiber: 7.7, sugar: 35.3, sodiumMg: 6),
                        measures: [("1 oz", 28.35)]),
            ]
        } else if q.contains("chicken") {
            foods = [generic(171_077, "Chicken, breast, boneless, skinless, raw",
                             nutrients(120, 22.5, 0, 2.6, sodiumMg: 45), measures: [])]
        }
        return foods.compactMap(DatabaseFood.init(json:))
    }

    private static func generic(_ fdcId: Int, _ name: String, _ per100g: [String: Any],
                                measures: [(String, Double)]) -> [String: Any] {
        var food: [String: Any] = ["id": "usda:\(fdcId)", "source": "usda", "name": name, "per100g": per100g,
                                   "measures": measures.dropFirst().map { ["text": $0.0, "grams": $0.1] }]
        if let first = measures.first {
            let f = first.1 / 100
            let scaled = per100g.mapValues { ($0 as? Double).map { $0 * f } ?? $0 }
            food["serving"] = ["text": first.0, "grams": first.1, "nutrients": scaled]
        }
        return food
    }

    private static func nutrients(_ calories: Double, _ protein: Double, _ carbs: Double, _ fat: Double,
                                  saturatedFat: Double? = nil, fiber: Double? = nil, sugar: Double? = nil,
                                  sodiumMg: Double? = nil) -> [String: Any] {
        ["calories": calories, "protein": protein, "carbs": carbs, "fat": fat,
         "saturatedFat": saturatedFat ?? NSNull(), "fiber": fiber ?? NSNull(), "sugar": sugar ?? NSNull(),
         "sodiumMg": sodiumMg ?? NSNull()]
    }
}
