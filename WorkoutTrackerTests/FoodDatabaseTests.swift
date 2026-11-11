import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N8 (D72): barcodes as the server's key, the app's own check of a database answer, how a database food is
/// kept (and refreshed) on the phone, the offline match for a code logged before, other servings by weight, and the
/// client's requests and errors.
@MainActor
@Suite(.serialized)
struct FoodDatabaseTests {
    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private let now = Date(timeIntervalSince1970: 1_794_300_000)

    // MARK: Barcodes

    @Test func barcodesBecomeOneGTINWhicheverWayTheyWereRead() {
        #expect(FoodBarcode.normalize("3017620422003") == "3017620422003")
        // UPC-A reads as itself or as EAN-13 with a leading 0: one key.
        #expect(FoodBarcode.normalize("049000028911") == "0049000028911")
        #expect(FoodBarcode.normalize("0049000028911") == "0049000028911")
        #expect(FoodBarcode.normalize("00049000028911") == "0049000028911")
        #expect(FoodBarcode.normalize("96385074") == "96385074")
        // A wrong check digit, the wrong length, not digits, all zeros: not a product code.
        for bad in ["3017620422004", "12345", "30176204220a3", "", "00000000", "301762042200312"] {
            #expect(FoodBarcode.normalize(bad) == nil, "\(bad)")
        }
    }

    @Test func upcEExpandsToItsUPCA() {
        // Standard examples: 0 425261 4 → 0 42100 00526 4; the four suppression patterns.
        #expect(FoodBarcode.expandUPCE("04252614") == "042100005264")
        #expect(FoodBarcode.normalize("04252614", upcE: true) == "0042100005264")
        #expect(FoodBarcode.expandUPCE("01234505") == "012000003455")
        #expect(FoodBarcode.expandUPCE("01234531") == "012300000451")
        #expect(FoodBarcode.expandUPCE("01234546") == "012340000056")
        #expect(FoodBarcode.expandUPCE("01234558") == "012345000058")
        #expect(FoodBarcode.expandUPCE("21234505") == nil)  // number system 2 is not UPC-E
        #expect(FoodBarcode.normalize("04252615", upcE: true) == nil)  // its check digit is wrong
    }

    // MARK: The app's own check

    private func json(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var food: [String: Any] = [
            "id": "off:3017620422003", "source": "openFoodFacts", "name": "Hazelnut spread", "brand": "Sample",
            "barcode": "3017620422003",
            "per100g": ["calories": 539, "protein": 6.3, "carbs": 57.5, "fat": 30.9, "saturatedFat": 10.6,
                        "fiber": NSNull(), "sugar": 56.3, "sodiumMg": 42.8],
            "serving": ["text": "15 g", "grams": 15,
                        "nutrients": ["calories": 81, "protein": 0.9, "carbs": 8.6, "fat": 4.6, "saturatedFat": NSNull(),
                                      "fiber": NSNull(), "sugar": NSNull(), "sodiumMg": NSNull()]],
            "measures": [] as [Any],
        ]
        overrides.forEach { food[$0.key] = $0.value }
        return food
    }

    @Test func aServerAnswerIsCheckedAgain() throws {
        let food = try #require(DatabaseFood(json: json()))
        #expect(food.name == "Hazelnut spread")
        #expect(food.serving?.nutrients.calories == 81)
        #expect(food.per100g?.fiber == nil)
        #expect(food.attribution == "Food data from Open Food Facts")
        // Refused: an unknown source, an id that is not the source's, no name, a name over two lines, no nutrition.
        #expect(DatabaseFood(json: json(["source": "other"])) == nil)
        #expect(DatabaseFood(json: json(["id": "usda:1"])) == nil)
        #expect(DatabaseFood(json: json(["name": "  "])) == nil)
        #expect(DatabaseFood(json: json(["name": "a\nb"])) == nil)
        #expect(DatabaseFood(json: json(["per100g": NSNull(), "serving": NSNull()])) == nil)
        // Impossible numbers drop that part (here the 100 g; the serving still stands), never logged as given.
        let tooRich = try #require(DatabaseFood(json: json(["per100g": ["calories": 5000, "protein": 1, "carbs": 1, "fat": 1]])))
        #expect(tooRich.per100g == nil)
        let negative = DatabaseFood(json: json(["per100g": NSNull(),
            "serving": ["text": "1", "nutrients": ["calories": 10, "protein": -1, "carbs": 0, "fat": 0]]]))
        #expect(negative == nil)
        // A boolean is not a number.
        #expect(DatabaseFood(json: json(["per100g": NSNull(),
            "serving": ["text": "1", "nutrients": ["calories": true, "protein": 0, "carbs": 0, "fat": 0]]])) == nil)
    }

    @Test func impossibleNutritionIsRefusedNotZeroed() throws {
        // codex-review-n8 S5: the server's bounds, checked again — per 100 g nothing weighs more than 100 g (with slack).
        let per100 = { (overrides: [String: Any]) -> [String: Any] in
            var n: [String: Any] = ["calories": 100, "protein": 1, "carbs": 1, "fat": 1]
            overrides.forEach { n[$0.key] = $0.value }
            return self.json(["per100g": n, "serving": NSNull()])
        }
        #expect(DatabaseFood(json: per100([:])) != nil)
        #expect(DatabaseFood(json: per100(["protein": 10_000])) == nil)
        #expect(DatabaseFood(json: per100(["protein": 40, "carbs": 40, "fat": 40])) == nil)
        #expect(DatabaseFood(json: per100(["sodiumMg": 150_000])) == nil)
        #expect(DatabaseFood(json: per100(["fiber": -1])) == nil)
        // A serving of known weight: bounded by it, and by 9 kcal a gram.
        let serving = { (grams: Any, nutrients: [String: Any]) -> [String: Any] in
            self.json(["per100g": NSNull(), "serving": ["text": "1 bar", "grams": grams, "nutrients": nutrients]])
        }
        #expect(DatabaseFood(json: serving(40, ["calories": 200, "protein": 5, "carbs": 20, "fat": 10])) != nil)
        #expect(DatabaseFood(json: serving(40, ["calories": 200, "protein": 0, "carbs": 0, "fat": 50])) == nil)
        #expect(DatabaseFood(json: serving(10, ["calories": 500, "protein": 0, "carbs": 0, "fat": 0])) == nil)
        // A drink per 100 ml may weigh more than 100 g (a syrup), within 1.5 g a millilitre.
        let syrup = self.json(["per100Unit": "ml", "serving": NSNull(),
                               "per100g": ["calories": 400, "protein": 0, "carbs": 110, "fat": 0, "sugar": 110]])
        #expect(DatabaseFood(json: syrup)?.per100Unit == .ml)
        #expect(DatabaseFood(json: self.json(["per100Unit": "cup"])) == nil)
    }

    // MARK: Kept on the phone

    @Test func aDrinkPer100mlIsKeptAs100mlWithNoWeight() throws {
        // codex-review-n8 S2: no package serving, numbers per 100 ml — 100 ml, never 100 g.
        let juice = try #require(DatabaseFood(json: json([
            "per100Unit": "ml", "serving": NSNull(),
            "per100g": ["calories": 45, "protein": 0.7, "carbs": 10.4, "fat": 0.2],
        ])))
        let stored = FoodDatabase.storedServing(juice)
        #expect(stored.serving == ServingText(value: 100, unit: "ml", grams: nil))
        #expect(stored.nutrition.calories == 45)
        #expect(stored.options.isEmpty)
        // With a serving in ml: that serving, and no "100 g" beside it.
        let can = try #require(DatabaseFood(json: json([
            "per100Unit": "ml",
            "per100g": ["calories": 42, "protein": 0, "carbs": 10.6, "fat": 0],
            "serving": ["text": "1 can (355 mL)", "grams": NSNull(),
                        "nutrients": ["calories": 149, "protein": 0, "carbs": 37.6, "fat": 0]],
        ])))
        #expect(FoodDatabase.storedServing(can).options.isEmpty)
        let context = try context()
        let saved = try FoodDatabase.save(juice, in: context)
        #expect(saved.servingUnit == "ml" && saved.servingValue == 100 && saved.servingGrams == nil)
        #expect(FoodLog.servingChoices(saved).count == 1)
    }

    @Test func aDatabaseFoodIsKeptWithItsServingAndOtherServings() throws {
        let generic = DatabaseFood(
            id: "usda:173944", source: .usda, name: "Bananas, raw",
            per100g: .init(calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3, fiber: 2.6),
            serving: .init(text: "1 medium", grams: 118, nutrients: .init(calories: 105, protein: 1.3, carbs: 26.9, fat: 0.4)),
            measures: [.init(text: "1 cup, sliced", grams: 150)])
        let stored = FoodDatabase.storedServing(generic)
        #expect(stored.serving == ServingText(value: 1, unit: "medium", grams: 118))
        #expect(stored.nutrition.calories == 105)
        #expect(stored.options == [ServingOption(value: 1, unit: "cup, sliced", grams: 150),
                                   ServingOption(value: 100, unit: "g", grams: 100)])
        // Per 100 g only: 100 g is the serving.
        let plain = DatabaseFood(id: "usda:1", source: .usda, name: "Rice",
                                 per100g: .init(calories: 130, protein: 2.7, carbs: 28, fat: 0.3))
        #expect(FoodDatabase.storedServing(plain).serving == ServingText(value: 100, unit: "g", grams: 100))
        // A drink in millilitres: no grams, so no other servings by weight.
        let drink = DatabaseFood(id: "off:0049000028911", source: .openFoodFacts, name: "Cola",
                                 per100g: .init(calories: 42, protein: 0, carbs: 10.6, fat: 0),
                                 serving: .init(text: "1 can (355 mL)", grams: nil,
                                                nutrients: .init(calories: 149, protein: 0, carbs: 37.6, fat: 0)))
        let can = FoodDatabase.storedServing(drink)
        #expect(can.serving == ServingText(value: 1, unit: "can (355 mL)", grams: nil))
        #expect(can.options.isEmpty)
    }

    @Test func savingTwiceRefreshesOneFoodThatIsNotMineAndNotRecentUntilLogged() throws {
        let context = try context()
        let food = try #require(DatabaseFood(json: json()))
        let saved = try FoodDatabase.save(food, at: now, in: context)
        #expect(saved.databaseID == "off:3017620422003")
        #expect(saved.barcode == "3017620422003")
        #expect(!saved.createdByUser && !saved.isSaved && saved.lastUsedAt == nil)
        #expect(saved.isCachedLookup)
        // Only opened: not among the user's foods (search on All, Create meal) nor Recently logged.
        let all = try context.fetch(FetchDescriptor<SavedFood>())
        #expect(FoodLog.all(all).isEmpty)
        #expect(FoodLog.recent(all).isEmpty)
        // Logged: Recently logged, and searchable.
        let receipt = try FoodLog.log(saved, meal: .lunch, at: now, source: .barcode, in: context)
        #expect(receipt.entries.first?.source == .barcode)
        #expect(receipt.entries.first?.barcode == "3017620422003")
        #expect(FoodLog.recent(try context.fetch(FetchDescriptor<SavedFood>())) == [saved])
        // The database changed its numbers: the same food is refreshed; the entry keeps what was eaten.
        var changed = food
        changed.serving?.nutrients.calories = 90
        let again = try FoodDatabase.save(changed, at: now, in: context)
        #expect(again === saved)
        #expect(try context.fetch(FetchDescriptor<SavedFood>()).count == 1)
        #expect(saved.calories == 90)
        #expect(receipt.entries.first?.calories == 81)
        // Undo of a first log puts it back to only opened.
        let other = try FoodDatabase.save(DatabaseFood(id: "usda:9", source: .usda, name: "Rice",
                                                       per100g: .init(calories: 130, protein: 2.7, carbs: 28, fat: 0.3)),
                                          in: context)
        try FoodLog.undo(try FoodLog.log(other, meal: .lunch, in: context), in: context)
        #expect(other.isCachedLookup)
    }

    @Test func aCodeOnThePhoneMatchesOfflineMyFoodFirst() throws {
        let context = try context()
        let cached = try FoodDatabase.save(try #require(DatabaseFood(json: json())), in: context)
        cached.lastUsedAt = now
        let foods = { try context.fetch(FetchDescriptor<SavedFood>()) }
        #expect(FoodDatabase.local(barcode: "3017620422003", in: try foods()) === cached)
        #expect(FoodDatabase.local(barcode: "0049000028911", in: try foods()) == nil)
        // The user's own food with that code (typed as the 12-digit UPC) wins.
        let mine = SavedFood(name: "My cola", barcode: "049000028911", calories: 140, createdByUser: true)
        context.insert(mine)
        let cola = try FoodDatabase.save(DatabaseFood(id: "off:0049000028911", source: .openFoodFacts, name: "Cola",
                                                      barcode: "0049000028911",
                                                      per100g: .init(calories: 42, protein: 0, carbs: 10.6, fat: 0)),
                                         in: context)
        cola.lastUsedAt = now
        #expect(FoodDatabase.local(barcode: "0049000028911", in: try foods()) === mine)
    }

    // MARK: Other servings

    @Test func anotherServingLogsByWeightAndKeepsItsOwnServing() throws {
        let context = try context()
        let banana = try FoodDatabase.save(DatabaseFood(
            id: "usda:173944", source: .usda, name: "Bananas, raw",
            per100g: .init(calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3, fiber: 2.6, sodiumMg: 1),
            serving: .init(text: "1 medium", grams: 118,
                           nutrients: .init(calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1, sodiumMg: 1.2)),
            measures: [.init(text: "1 cup, sliced", grams: 150)]), in: context)
        let choices = FoodLog.servingChoices(banana)
        #expect(choices.map(\.unit) == ["medium", "cup, sliced", "g"])
        let cup = choices[1]
        let receipt = try FoodLog.log(banana, servings: 2, option: cup, meal: .breakfast, at: now, source: .search,
                                      in: context)
        let entry = try #require(receipt.entries.first)
        #expect(entry.servingUnit == "cup, sliced" && entry.servingGrams == 150 && entry.servings == 2)
        #expect(abs(entry.calories - 105 * 150 / 118) < 0.0001)
        #expect(abs((entry.fiberGrams ?? 0) - 3.1 * 150 / 118) < 0.0001)
        #expect(entry.saturatedFatGrams == nil)
        #expect(abs(receipt.calories - 2 * 105 * 150 / 118) < 0.0001)
        // A food without a serving weight offers only its own serving.
        let jar = SavedFood(name: "Jam", servingValue: 1, servingUnit: "jar", calories: 50)
        jar.servingOptions = [ServingOption(value: 1, unit: "tbsp", grams: 20)]
        #expect(FoodLog.servingChoices(jar).count == 1)
    }

    // MARK: The client

    private func client(_ onUnauthorized: @escaping @Sendable (String) -> Void = { _ in }) -> FoodDatabaseClient {
        FoodDatabaseClient(baseURL: URL(string: "https://server.test")!, token: "tok-1", session: FoodDBStub.session(),
                           onUnauthorized: onUnauthorized)
    }

    private static func data(_ object: Any) -> Data { try! JSONSerialization.data(withJSONObject: object) }

    @Test func theClientAsksWithTheSessionAndChecksTheAnswer() async throws {
        let seen = FoodDBSeen()
        FoodDBStub.respond = { request in
            seen.append("\(request.httpMethod ?? "") \(request.url!.path)?\(request.url!.query ?? "") \(request.value(forHTTPHeaderField: "Authorization") ?? "")")
            if request.url!.path.hasSuffix("search") {
                return (200, Self.data(["foods": [self.json(["id": "usda:1", "source": "usda"]), ["id": "bad"]]]))
            }
            return (200, Self.data(["found": true, "food": self.json()]))
        }
        defer { FoodDBStub.respond = nil }
        #expect(try await client().barcode("3017620422003")?.name == "Hazelnut spread")
        let foods = try await client().search("chicken & rice")
        #expect(foods.map(\.id) == ["usda:1"])  // the unusable one is dropped
        #expect(seen.values == ["GET /v1/food/barcode/3017620422003? Bearer tok-1",
                                "GET /v1/food/search?q=chicken%20%26%20rice Bearer tok-1"])
    }

    @Test func notFoundAndEveryErrorReadAsTheAppSaysThem() async throws {
        defer { FoodDBStub.respond = nil }
        FoodDBStub.respond = { _ in (200, Self.data(["found": false])) }
        #expect(try await client().barcode("3017620422003") == nil)
        // Found, but nothing the app would log: as not found.
        FoodDBStub.respond = { _ in (200, Self.data(["found": true, "food": ["id": "x"]])) }
        #expect(try await client().barcode("3017620422003") == nil)
        let cases: [(Int, String, FoodDatabaseError)] = [
            (429, "food_limit", .limit), (502, "food_unavailable", .unavailable),
            (503, "server_not_configured", .notConfigured), (500, "server_error", .unavailable),
            (400, "invalid_barcode", .rejected("invalid_barcode")),
        ]
        for (status, code, expected) in cases {
            FoodDBStub.respond = { _ in (status, Self.data(["error": code])) }
            await #expect(throws: expected) { try await client().barcode("3017620422003") }
        }
        let refused = FoodDBSeen()
        FoodDBStub.respond = { _ in (401, Self.data(["error": "unauthorized"])) }
        await #expect(throws: FoodDatabaseError.signedOut) { try await client({ refused.append($0) }).search("rice") }
        #expect(refused.values == ["tok-1"])
        FoodDBStub.respond = nil  // the stub fails the load as no connection
        await #expect(throws: FoodDatabaseError.offline) { try await client().search("rice") }
    }
}

private final class FoodDBSeen: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [String] = []
    var values: [String] { lock.withLock { _values } }
    func append(_ value: String) { lock.withLock { _values.append(value) } }
}

private final class FoodDBStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: ((URLRequest) -> (Int, Data))?

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FoodDBStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let respond = Self.respond else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let (status, body) = respond(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
