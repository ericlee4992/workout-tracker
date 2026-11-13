import Foundation

/// Nutrition N8: the barcode lookup and the online search, through the server — or, in UI tests (`-uiTestTerra`), the
/// fixture below, which stands in for the server (no network). Flags: `-uiTestBarcodeNotFound` (neither database has
/// it), `-uiTestTerraOffline` (no connection), `-uiTestFoodDatabaseOfflineAfterOne` (the connection goes after the
/// first answer), `-uiTestFoodSearchOff` (search not set up on the server), `-uiTestBarcodeNoRead` (the fixture camera
/// reads nothing, for captures of Barcode mode itself), `-uiTestBarcodeKorean` (N12: not found, with a Korean name for
/// the "Is this it?" search; `-uiTestBarcodeKoreanNoMatch`: a name nothing matches).
enum FoodDatabaseAccess {
    /// The server client for this session; nil signed out. A 401 signs the phone out, as the AI client does.
    @MainActor static func client(_ account: AccountStore) -> FoodDatabaseClient? {
        guard let baseURL = account.client?.baseURL, let token = account.token else { return nil }
        return FoodDatabaseClient(baseURL: baseURL, token: token, onUnauthorized: { [weak account] refused in
            Task { @MainActor in account?.invalidate(token: refused) }
        })
    }

    static func barcode(_ code: String, client: FoodDatabaseClient?) async throws -> BarcodeAnswer {
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

/// The UI tests' food databases: one packaged food for any barcode, a few generic foods by name, and (N12) Korean foods
/// for a search in Korean. Shaped as the server answers, through the same checks (`DatabaseFood(json:)`).
enum FoodDatabaseFixture {
    /// The code the fixture camera "reads" in Barcode mode (a valid EAN-13).
    static let barcode = "3017620422003"

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    nonisolated(unsafe) private static var answered = 0

    private static func wait() async throws {
        try await Task.sleep(for: .milliseconds(arguments.contains("-uiTestTerraSlow") ? 4000 : 400))
        if arguments.contains("-uiTestTerraOffline") { throw FoodDatabaseError.offline }
        if arguments.contains("-uiTestFoodDatabaseOfflineAfterOne"), answered > 0 { throw FoodDatabaseError.offline }
        answered += 1
    }

    static func barcode(_ code: String) async throws -> BarcodeAnswer {
        try await wait()
        if arguments.contains("-uiTestBarcodeKoreanNoMatch") { return BarcodeAnswer(name: "샘표고등어") }
        if arguments.contains("-uiTestBarcodeKorean") { return BarcodeAnswer(name: "양파링 오리지널") }
        if arguments.contains("-uiTestBarcodeNotFound") { return BarcodeAnswer() }
        return BarcodeAnswer(food: DatabaseFood(json: [
            "id": "off:\(code)", "source": "openFoodFacts", "name": "Hazelnut spread", "brand": "Sample Pantry",
            "barcode": code,
            "per100g": nutrients(539, 6.3, 57.5, 30.9, saturatedFat: 10.6, fiber: 0, sugar: 56.3, sodiumMg: 42.8),
            "serving": ["text": "15 g", "grams": 15,
                        "nutrients": nutrients(81, 0.9, 8.6, 4.6, saturatedFat: 1.6, fiber: 0, sugar: 8.4, sodiumMg: 6.4)],
            "measures": [] as [Any],
        ]))
    }

    static func search(_ query: String) async throws -> [DatabaseFood] {
        try await wait()
        if arguments.contains("-uiTestFoodSearchOff") { throw FoodDatabaseError.notConfigured }
        let q = query.lowercased()
        var foods: [[String: Any]] = []
        if FoodDatabase.containsHangul(q) {
            foods = korean.filter { ($0["name"] as? String)?.replacingOccurrences(of: " ", with: "")
                .contains(q.replacingOccurrences(of: " ", with: "")) ?? false }
        } else if q.contains("banana") {
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

    /// N12: 식품영양성분DB as the server normalises it — a product with its package, a dish with its portion, and a
    /// restaurant dish that lists no fat or carbs (kept as 0).
    private static let korean: [[String: Any]] = [
        ["id": "mfds:P-ONION-1", "source": "mfds", "name": "양파링 오리지널", "brand": "(주)농심",
         "per100g": nutrients(469, 6.25, 63.75, 21.25, saturatedFat: 7.5, sugar: 5, sodiumMg: 525),
         "serving": ["text": "1 package (84 g)", "grams": 84,
                     "nutrients": nutrients(394, 5.25, 53.55, 17.85, saturatedFat: 6.3, sugar: 4.2, sodiumMg: 441)],
         "measures": [] as [Any]],
        ["id": "mfds:P-ONION-2", "source": "mfds", "name": "양파링 매콤한맛", "brand": "(주)농심",
         "per100g": nutrients(472, 6.1, 63.1, 22, sodiumMg: 610),
         "serving": ["text": "1 package (80 g)", "grams": 80, "nutrients": nutrients(378, 4.9, 50.5, 17.6, sodiumMg: 488)],
         "measures": [] as [Any]],
        ["id": "mfds:D-KIMCHI", "source": "mfds", "name": "김치찌개",
         "per100g": nutrients(61, 3.77, 2.98, 3.75, saturatedFat: 0.69, fiber: 2.1, sugar: 0.76, sodiumMg: 491),
         "serving": ["text": "1 serving (400 g)", "grams": 400,
                     "nutrients": nutrients(244, 15.08, 11.92, 15, saturatedFat: 2.76, fiber: 8.4, sugar: 3.04, sodiumMg: 1964)],
         "measures": [] as [Any]],
        ["id": "mfds:D-ROSE", "source": "mfds", "name": "떡볶이, 로제떡볶이", "brand": "치킨플러스",
         "per100g": nutrients(187, 5.03, 0, 0, sodiumMg: 436),
         "serving": ["text": "1 serving (100 g)", "grams": 100, "nutrients": nutrients(187, 5.03, 0, 0, sodiumMg: 436)],
         "measures": [] as [Any], "notListed": ["carbs", "fat"]],
    ]

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
