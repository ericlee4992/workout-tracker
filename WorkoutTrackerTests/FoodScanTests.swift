import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers

@testable import WorkoutTracker

/// Nutrition N7 (D82, D83): the server's food replies are checked as the server checks them; a meal photo or a
/// description is ONE entry named for the meal, its numbers the sum of its items, its photo kept with it; editing,
/// deleting (with its items) and Undo; a label logged as one of My foods or once; a library photo's own time.
@MainActor
struct FoodScanTests {
    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private let now = Date(timeIntervalSince1970: 1_794_300_000)

    private func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    private func item(_ name: String, cal: Double, p: Double = 1, c: Double = 2, f: Double = 3,
                      confidence: String = "high") -> [String: Any] {
        ["name": name, "portion": "1 cup", "grams": 150, "calories": cal, "protein": p, "carbs": c, "fat": f,
         "confidence": confidence]
    }

    private var pokeReply: [String: Any] {
        ["mealName": "Poke bowl", "items": [item("Tuna poke", cal: 160, p: 26, c: 4, f: 4),
                                            item("Sushi rice", cal: 210, p: 4, c: 46, f: 0.5)]]
    }

    // MARK: Replies

    @Test func aMealReplyReadsWithItsNameAndTotals() throws {
        let estimate = try #require(FoodEstimate.parse(try json(pokeReply)))
        #expect(estimate.entryName == "Poke bowl")
        #expect(estimate.items.map(\.name) == ["Tuna poke", "Sushi rice"])
        #expect(estimate.totals == Macros(calories: 370, proteinGrams: 30, carbsGrams: 50, fatGrams: 4.5))
    }

    @Test func aReplyWithoutAMealNameIsNamedForItsFirstItem() throws {
        let estimate = try #require(FoodEstimate.parse(try json(["items": [item("Banana", cal: 105)]])))
        #expect(estimate.entryName == "Banana")
    }

    @Test func noItemsIsAValidAnswerNothingRecognised() throws {
        let estimate = try #require(FoodEstimate.parse(try json(["mealName": "", "items": [] as [Any]])))
        #expect(estimate.items.isEmpty)
    }

    @Test(arguments: [
        ["mealName": "x", "items": [["name": "A", "portion": "", "grams": 1, "calories": -5, "protein": 0, "carbs": 0,
                                     "fat": 0, "confidence": "high"]]],
        ["mealName": "x", "items": [["name": " ", "portion": "", "grams": 1, "calories": 5, "protein": 0, "carbs": 0,
                                     "fat": 0, "confidence": "high"]]],
        ["mealName": "x", "items": [["name": "A", "portion": "", "grams": 1, "calories": 5, "protein": 0, "carbs": 0,
                                     "fat": 0, "confidence": "sure"]]],
        ["mealName": "x", "items": [["name": "A", "portion": "", "grams": 50_000, "calories": 5, "protein": 0,
                                     "carbs": 0, "fat": 0, "confidence": "low"]]],
        ["mealName": String(repeating: "x", count: 61), "items": [] as [Any]],
    ] as [[String: Any]])
    func aReplyOutsideAPlatesBoundsIsRefused(_ reply: [String: Any]) throws {
        #expect(FoodEstimate.parse(try json(reply)) == nil)
    }

    @Test func moreThanFifteenItemsIsRefused() throws {
        let reply: [String: Any] = ["mealName": "Buffet", "items": Array(repeating: item("A", cal: 1), count: 16)]
        #expect(FoodEstimate.parse(try json(reply)) == nil)
    }

    @Test func aLabelReadsAsPrintedAndBecomesADraft() throws {
        let reply: [String: Any] = [
            "found": true, "servingSize": "2/3 cup (55 g)", "servingGrams": 55, "servingsPerContainer": 8,
            "calories": 230, "protein": 3, "carbs": 37, "fat": 8, "saturatedFat": 1, "fiber": 4, "sugar": 12,
            "sodiumMg": 160,
        ]
        let label = try #require(FoodLabelReading.parse(try json(reply)))
        #expect(label.isUsable)
        #expect(label.serving.value == 2.0 / 3.0)
        #expect(label.serving.unit == "cup")
        #expect(label.serving.grams == 55)
        let draft = label.draft(name: "Granola", brand: nil)
        #expect(draft.servingsPerContainer == 8)
        #expect(draft.nutrition == FoodNutrition(calories: 230, proteinGrams: 3, carbsGrams: 37, fatGrams: 8,
                                                 saturatedFatGrams: 1, fiberGrams: 4, sugarGrams: 12,
                                                 sodiumMilligrams: 160))
    }

    @Test func aLabelWithoutCaloriesOrNotFoundIsNotUsable() throws {
        let missing: [String: Any] = ["found": true, "servingSize": "1 bar", "calories": NSNull()]
        #expect(try #require(FoodLabelReading.parse(try json(missing))).isUsable == false)
        let none: [String: Any] = ["found": false, "servingSize": ""]
        #expect(try #require(FoodLabelReading.parse(try json(none))).isUsable == false)
        let negative: [String: Any] = ["found": true, "servingSize": "1 bar", "calories": 100, "sodiumMg": -1]
        #expect(FoodLabelReading.parse(try json(negative)) == nil)
    }

    /// The live check's label (2026-11-10, the FDA example) printed "(55g)" with no space.
    @Test func aServingSizeWithoutASpaceBeforeGramsReads() throws {
        let reply: [String: Any] = ["found": true, "servingSize": "2/3 cup (55g)", "servingGrams": 55, "calories": 230]
        let label = try #require(FoodLabelReading.parse(try json(reply)))
        #expect(label.serving.unit == "cup")
        #expect(label.serving.grams == 55)
    }

    @Test func anUnparseableServingSizeIsOneServingWithThePrintedGrams() throws {
        let reply: [String: Any] = ["found": true, "servingSize": "", "servingGrams": 30, "calories": 120]
        let label = try #require(FoodLabelReading.parse(try json(reply)))
        #expect(label.serving == ServingText(value: 1, unit: ServingText.defaultUnit, grams: 30))
    }

    // MARK: Logging a meal

    @Test func aMealPhotoIsOneEntryWithItsItemsAndPhoto() throws {
        let context = try context()
        let estimate = try #require(FoodEstimate.parse(try json(pokeReply)))
        let photo = Data([0xFF, 0xD8, 0xFF])
        let entry = try FoodScan.log(estimate, photo: photo, source: .photo, meal: .lunch, at: now, in: context)
        let stored = try context.fetch(FetchDescriptor<FoodEntry>())
        #expect(stored.count == 1)
        #expect(entry.name == "Poke bowl")
        #expect(entry.source == .photo)
        #expect(entry.meal == .lunch)
        #expect(entry.loggedAt == now)
        #expect(entry.photo == photo)
        #expect(entry.servings == 1)
        #expect(NutritionMath.totals(of: entry) == estimate.totals)
        #expect(entry.orderedItems.map(\.name) == ["Tuna poke", "Sushi rice"])
        #expect(entry.orderedItems.map(\.order) == [0, 1])
        #expect(try context.fetch(FetchDescriptor<FoodEntryItem>()).count == 2)
    }

    @Test func editingReplacesTheItemsAndTheTotalsFollow() throws {
        let context = try context()
        let estimate = try #require(FoodEstimate.parse(try json(pokeReply)))
        let entry = try FoodScan.log(estimate, photo: nil, source: .describe, meal: .lunch, at: now, in: context)
        var items = FoodScan.editable(entry)
        items[0].calories = 200
        items.remove(at: 1)
        items.append(FoodEstimate.Item(name: "Miso soup", portion: "1 bowl", grams: nil, calories: 40, protein: 3,
                                       carbs: 5, fat: 1))
        try FoodScan.update(entry, name: " Lunch bowl ", meal: .dinner, items: items, at: now, in: context)
        #expect(entry.name == "Lunch bowl")
        #expect(entry.meal == .dinner)
        #expect(entry.orderedItems.map(\.name) == ["Tuna poke", "Miso soup"])
        #expect(entry.calories == 240)
        #expect(entry.proteinGrams == 29)
        // The removed and replaced rows are gone, not orphaned.
        #expect(try context.fetch(FetchDescriptor<FoodEntryItem>()).count == 2)
    }

    @Test func deletingTakesItsItemsAndUndoBringsBackPhotoAndItems() throws {
        let context = try context()
        let estimate = try #require(FoodEstimate.parse(try json(pokeReply)))
        let photo = Data([1, 2, 3])
        let entry = try FoodScan.log(estimate, photo: photo, source: .photo, meal: .lunch, at: now, in: context)
        let id = entry.id
        let copy = try FoodLog.delete(entry, in: context)
        #expect(try context.fetch(FetchDescriptor<FoodEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FoodEntryItem>()).isEmpty)
        let restored = try FoodLog.restore(copy, in: context)
        #expect(restored.id == id)
        #expect(restored.photo == photo)
        #expect(restored.orderedItems.map(\.name) == ["Tuna poke", "Sushi rice"])
        #expect(NutritionMath.totals(of: restored) == estimate.totals)
    }

    // MARK: A label

    private var granola: FoodDraft {
        FoodDraft(brand: "  ", name: " Maple granola ", serving: ServingText(value: 2.0 / 3.0, unit: "cup", grams: 55),
                  servingsPerContainer: 8, nutrition: FoodNutrition(calories: 230, proteinGrams: 3, carbsGrams: 37,
                                                                    fatGrams: 8, fiberGrams: 4))
    }

    @Test func aLabelSavedToMyFoodsLogsFromTheNewFood() throws {
        let context = try context()
        let receipt = try FoodScan.logLabel(granola, servings: 1.5, meal: .breakfast, saveToMyFoods: true, at: now,
                                            in: context)
        let food = try #require(try context.fetch(FetchDescriptor<SavedFood>()).first)
        #expect(food.name == "Maple granola")
        #expect(food.createdByUser)
        #expect(food.servingsPerContainer == 8)
        let entry = try #require(receipt.entries.first)
        #expect(entry.source == .label)
        #expect(entry.savedFood === food)
        #expect(entry.servings == 1.5)
        #expect(NutritionMath.totals(of: entry).calories == 345)
    }

    @Test func aLabelNotSavedLogsOnceAndCreatesNoFood() throws {
        let context = try context()
        let receipt = try FoodScan.logLabel(granola, servings: 1, meal: .snacks, saveToMyFoods: false, at: now,
                                            in: context)
        #expect(try context.fetch(FetchDescriptor<SavedFood>()).isEmpty)
        let entry = try #require(receipt.entries.first)
        #expect(entry.name == "Maple granola")
        #expect(entry.brand == nil)
        #expect(entry.source == .label)
        #expect(entry.servingGrams == 55)
        #expect(entry.fiberGrams == 4)
    }

    // MARK: When

    @Test func aLibraryPhotoIsLoggedWhenItWasTakenAndItsMealFollows() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let lunch = try #require(calendar.date(bySettingHour: 12, minute: 40, second: 0, of: now))
        let evening = try #require(calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now))
        let picked = FoodScan.when(photoTaken: lunch, now: evening)
        #expect(picked.date == lunch)
        #expect(picked.meal == .lunch)
        #expect(FoodScan.when(photoTaken: nil, now: evening) == (evening, .dinner))
        // A clock that ran ahead never logs into the future.
        #expect(FoodScan.when(photoTaken: evening.addingTimeInterval(3600), now: evening).date == evening)
    }

    @Test func theExifTimeReadsWithAndWithoutItsOffset() throws {
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        let withOffset = try #require(PhotoDate.parse("2026:11:10 12:40:05", offset: "-05:00", zone: .gmt))
        let local = try #require(PhotoDate.parse("2026:11:10 12:40:05", offset: nil, zone: zone))
        #expect(withOffset == local)
        #expect(withOffset == Date(timeIntervalSince1970: 1_794_332_405))
        #expect(PhotoDate.parse("not a date", offset: nil) == nil)
    }

    @Test func aJPEGsOwnMetadataGivesItsTakenTime() throws {
        let data = try jpeg(dateTimeOriginal: "2026:11:10 12:40:05", offset: "-05:00")
        #expect(PhotoDate.taken(in: data) == Date(timeIntervalSince1970: 1_794_332_405))
        #expect(PhotoDate.taken(in: try jpeg(dateTimeOriginal: nil, offset: nil)) == nil)
    }

    /// A 2 × 2 JPEG with (or without) EXIF dates.
    private func jpeg(dateTimeOriginal: String?, offset: String?) throws -> Data {
        let context = try #require(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        var exif: [CFString: Any] = [:]
        if let dateTimeOriginal { exif[kCGImagePropertyExifDateTimeOriginal] = dateTimeOriginal }
        if let offset { exif[kCGImagePropertyExifOffsetTimeOriginal] = offset }
        let properties: [CFString: Any] = exif.isEmpty ? [:] : [kCGImagePropertyExifDictionary: exif]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
