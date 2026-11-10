import Observation
import SwiftUI
import UIKit

// Nutrition N7 — MOCK ONLY (the user, 2026-11-10: mocks first, wired after approval). Nothing here is stored or sent:
// the scan's results, the progress card and the logged photo entries live in memory for the session. The sample
// "photos" are drawn in code (no personal photos in the repo). Replaced by the real flow when N7 is wired.

/// One estimated item of a meal photo or a description (the server's `food_items` shape, N6).
struct ScanMockItem: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var portion: String
    var grams: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    var macros: Macros { Macros(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat) }
}

/// A logged scan: the photo (nil for a description or a label), its name, when, which meal, its items.
struct ScanMockEntry: Identifiable, Hashable {
    enum Origin: Hashable { case photo, describe, label }
    var id = UUID()
    var origin: Origin
    var image: UIImage?
    var name: String
    var time: Date
    var meal: MealSlot
    var items: [ScanMockItem]

    var totals: Macros { items.reduce(Macros.zero) { $0 + $1.macros } }
}

/// What a scan in flight looks like on Today: analysing (the percent rises over the typical ~5 s) or failed.
struct ScanMockPending: Identifiable {
    enum State: Equatable { case analyzing, failed(ScanMockFailure) }
    var id = UUID()
    var image: UIImage?
    /// A description instead of a photo.
    var text: String?
    var meal: MealSlot
    var startedAt: Date
    var state: State
    /// Captures: the ring stays at this percent and the scan never completes.
    var frozenPercent: Int?
}

enum ScanMockFailure: String, CaseIterable, Identifiable, Equatable {
    case nothingFound, dailyLimit, offline
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nothingFound: "Nothing recognised"
        case .dailyLimit: "Daily limit reached"
        case .offline: "Offline / server error"
        }
    }
}

/// The two options the user asked to see for a meal photo's entries (N7, open).
enum ScanMockGrouping: String, CaseIterable, Identifiable {
    case oneEntry, perItem
    var id: String { rawValue }
    var label: String { self == .oneEntry ? "One entry" : "One per item" }
}

@MainActor @Observable
final class FoodScanMock {
    static let shared = FoodScanMock()

    /// The mock is on for this launch: `-scanFoodMock` (the interactive prototype and the capture tests).
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-scanFoodMock") }

    private static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    var pending: [ScanMockPending] = []
    var entries: [ScanMockEntry] = []
    var grouping: ScanMockGrouping = .oneEntry
    /// The next scan fails this way (nil: it succeeds).
    var nextFailure: ScanMockFailure?
    var signedIn = true
    var cameraAllowed = true
    var consentGiven = true
    /// The open camera's mode; captures pick it with `-scanFoodMockMode`.
    var initialMode: FoodScanMode = .meal

    private init() {
        let args = ProcessInfo.processInfo.arguments
        if let grouping = Self.argument("-scanFoodMockGrouping").flatMap(ScanMockGrouping.init) { self.grouping = grouping }
        nextFailure = Self.argument("-scanFoodMockFail").flatMap(ScanMockFailure.init)
        signedIn = !args.contains("-scanFoodMockSignedOut")
        cameraAllowed = !args.contains("-scanFoodMockNoCamera")
        consentGiven = !args.contains("-scanFoodMockConsent")
        if let mode = Self.argument("-scanFoodMockMode").flatMap(FoodScanMode.init) { initialMode = mode }
        // Outside the mock launch Today stays as it was: no sample scans.
        if Self.enabled { seed(Self.argument("-scanFoodMockSample") ?? "done") }
    }

    /// The Today states on record: "analyzing" (a card at 9 % over a logged photo), "done", "failures", "none".
    private func seed(_ sample: String) {
        let lunch = Calendar.current.date(bySettingHour: 12, minute: 40, second: 0, of: .now) ?? .now
        switch sample {
        case "none": break
        case "failures":
            pending = [
                ScanMockPending(image: FoodScanArt.meal, meal: .lunch, startedAt: lunch, state: .failed(.nothingFound)),
                ScanMockPending(image: FoodScanArt.meal, meal: .lunch, startedAt: lunch, state: .failed(.dailyLimit)),
                ScanMockPending(image: FoodScanArt.meal, meal: .lunch, startedAt: lunch, state: .failed(.offline)),
            ]
        case "analyzing":
            entries = [Self.pokeBowl(at: lunch)]
            pending = [ScanMockPending(image: FoodScanArt.meal, meal: .lunch, startedAt: .now, state: .analyzing,
                                       frozenPercent: 9)]
        default:
            entries = [Self.pokeBowl(at: lunch)]
        }
    }

    static let pokeItems = [
        ScanMockItem(name: "Tuna poke", portion: "1 cup", grams: 150, calories: 160, protein: 26, carbs: 4, fat: 4),
        ScanMockItem(name: "Sushi rice", portion: "1 cup", grams: 160, calories: 210, protein: 4, carbs: 46, fat: 0.5),
        ScanMockItem(name: "Avocado", portion: "¼ fruit", grams: 50, calories: 80, protein: 1, carbs: 4, fat: 7),
        ScanMockItem(name: "Mango", portion: "½ cup", grams: 80, calories: 50, protein: 0.5, carbs: 12, fat: 0),
        ScanMockItem(name: "Edamame", portion: "¼ cup", grams: 40, calories: 50, protein: 5, carbs: 4, fat: 2),
    ]

    static func pokeBowl(at time: Date) -> ScanMockEntry {
        ScanMockEntry(origin: .photo, image: FoodScanArt.meal, name: "Poke bowl", time: time, meal: .lunch,
                      items: pokeItems)
    }

    static let describeItems = [
        ScanMockItem(name: "Scrambled eggs", portion: "2 eggs", grams: 120, calories: 180, protein: 13, carbs: 2, fat: 13),
        ScanMockItem(name: "Toast, buttered", portion: "1 slice", grams: 35, calories: 120, protein: 3, carbs: 14, fat: 6),
    ]

    // MARK: Actions

    /// A meal photo was taken or picked: the card appears in Today's log at once and the estimate arrives ~5 s later
    /// (or the chosen failure).
    func startPhoto(meal: MealSlot) { start(ScanMockPending(image: FoodScanArt.meal, meal: meal, startedAt: .now,
                                                            state: .analyzing)) }

    func startDescribe(_ text: String, meal: MealSlot) {
        start(ScanMockPending(image: nil, text: text, meal: meal, startedAt: .now, state: .analyzing))
    }

    private func start(_ scan: ScanMockPending) {
        pending.insert(scan, at: 0)
        let id = scan.id
        let failure = nextFailure
        Task { @MainActor in
            // Captures: `-scanFoodMockSlow` holds the card long enough to scroll to it at large text sizes.
            let slow = ProcessInfo.processInfo.arguments.contains("-scanFoodMockSlow")
            try? await Task.sleep(for: .seconds(slow ? 14 : failure == nil ? 5.2 : 2.5))
            self.finish(id, failure: failure)
        }
    }

    private func finish(_ id: UUID, failure: ScanMockFailure?) {
        guard let index = pending.firstIndex(where: { $0.id == id }), pending[index].frozenPercent == nil else { return }
        let scan = pending[index]
        if let failure {
            withAnimation(.snappy) { pending[index].state = .failed(failure) }
            return
        }
        let entry = scan.text == nil
            ? ScanMockEntry(origin: .photo, image: scan.image, name: "Poke bowl", time: .now, meal: scan.meal,
                            items: Self.pokeItems)
            : ScanMockEntry(origin: .describe, image: nil, name: "Eggs and toast", time: .now, meal: scan.meal,
                            items: Self.describeItems)
        withAnimation(.snappy) {
            pending.remove(at: index)
            entries.append(entry)
        }
    }

    func retry(_ id: UUID) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let scan = pending.remove(at: index)
        nextFailure = nil
        start(ScanMockPending(image: scan.image, text: scan.text, meal: scan.meal, startedAt: .now, state: .analyzing))
    }

    func dismiss(_ id: UUID) { withAnimation(.snappy) { pending.removeAll { $0.id == id } } }

    func logLabel(name: String, item: ScanMockItem, meal: MealSlot) {
        withAnimation(.snappy) {
            entries.append(ScanMockEntry(origin: .label, image: nil, name: name, time: .now, meal: meal, items: [item]))
        }
    }

    func update(_ entry: ScanMockEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
    }

    func delete(_ entry: ScanMockEntry) { withAnimation(.snappy) { entries.removeAll { $0.id == entry.id } } }

    func restore(_ entry: ScanMockEntry) { withAnimation(.snappy) { entries.append(entry) } }

    /// The logged scans as unsaved entries, so the fuel card and the day rings count them like the real ones will.
    var asFoodEntries: [FoodEntry] {
        entries.map { scan in
            let totals = scan.totals
            return FoodEntry(loggedAt: scan.time, meal: scan.meal, name: scan.name, calories: totals.calories,
                             proteinGrams: totals.proteinGrams, carbsGrams: totals.carbsGrams, fatGrams: totals.fatGrams,
                             source: scan.origin == .label ? .label : scan.origin == .photo ? .photo : .describe)
        }
    }

    func entries(for meal: MealSlot) -> [ScanMockEntry] { entries.filter { $0.meal == meal }.sorted { $0.time < $1.time } }
}

/// The camera's three modes (the approved prototype's `SoftScanFoodScreen`): Barcode is wired in N8.
enum FoodScanMode: String, CaseIterable, Identifiable {
    case meal, barcode, label
    var id: String { rawValue }
    var title: String {
        switch self {
        case .meal: "Scan food"
        case .barcode: "Barcode"
        case .label: "Food label"
        }
    }
    var symbol: String {
        switch self {
        case .meal: "camera.viewfinder"
        case .barcode: "barcode.viewfinder"
        case .label: "list.bullet.rectangle.portrait"
        }
    }
}

// MARK: - Sample art (drawn, not photographed)

@MainActor
enum FoodScanArt {
    static let meal: UIImage = render(MockMealPhoto(), size: CGSize(width: 360, height: 360))
    static let label: UIImage = render(MockNutritionLabel(), size: CGSize(width: 300, height: 440))
    static let barcode: UIImage = render(MockBarcode(), size: CGSize(width: 320, height: 160))

    private static func render(_ view: some View, size: CGSize) -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }
}

/// A bowl on a table, from above: rice, tuna cubes, mango, avocado, edamame.
private struct MockMealPhoto: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x6E5A48), Color(hex: 0x3B2F26)], startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            Circle().fill(Color(hex: 0xF4F1EA)).frame(width: 300, height: 300)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
            Circle().fill(Color(hex: 0xE9E4DA)).frame(width: 262, height: 262)
            // Rice.
            Circle().fill(Color(hex: 0xFBF8F0)).frame(width: 236, height: 236)
            ForEach(0..<46, id: \.self) { i in
                Capsule().fill(Color(hex: 0xEDE6D6)).frame(width: 9, height: 4)
                    .rotationEffect(.degrees(Double(i * 37)))
                    .offset(x: CGFloat((i * 53) % 190) - 95, y: CGFloat((i * 89) % 190) - 95)
            }
            // Tuna.
            ForEach(0..<9, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: i % 2 == 0 ? 0xC8384B : 0xB22C40))
                    .frame(width: 30, height: 28)
                    .rotationEffect(.degrees(Double(i * 23)))
                    .offset(x: -52 + CGFloat(i % 3) * 30, y: -58 + CGFloat(i / 3) * 30)
            }
            // Mango.
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xF4A72C)).frame(width: 24, height: 24)
                    .rotationEffect(.degrees(Double(i * 31)))
                    .offset(x: 46 + CGFloat(i % 2) * 26, y: -44 + CGFloat(i / 2) * 26)
            }
            // Avocado.
            ForEach(0..<4, id: \.self) { i in
                Ellipse().fill(LinearGradient(colors: [Color(hex: 0xC9DB7A), Color(hex: 0x6E9A3A)],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: 70, height: 22)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -38 + CGFloat(i) * 12, y: 52 + CGFloat(i) * 16)
            }
            // Edamame.
            ForEach(0..<10, id: \.self) { i in
                Circle().fill(Color(hex: 0x8DBF4E)).frame(width: 16, height: 16)
                    .offset(x: 50 + CGFloat(i % 3) * 16, y: 44 + CGFloat(i / 3) * 15)
            }
            // Sesame.
            ForEach(0..<24, id: \.self) { i in
                Capsule().fill(i % 3 == 0 ? Color.black.opacity(0.8) : Color(hex: 0xF5EBD3)).frame(width: 4, height: 2.5)
                    .offset(x: CGFloat((i * 71) % 170) - 85, y: CGFloat((i * 43) % 150) - 75)
            }
        }
    }
}

/// A UPC sticker, the barcode mode's subject.
private struct MockBarcode: View {
    private let widths: [CGFloat] = [2, 1, 3, 1, 1, 2, 4, 1, 2, 1, 3, 2, 1, 1, 4, 2, 1, 3, 1, 2, 2, 1, 3, 1, 1, 2, 4, 1,
                                     2, 1, 1, 3, 2, 1, 2, 4, 1, 1, 3, 1, 2, 1]
    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 2) {
                ForEach(widths.indices, id: \.self) { i in
                    Rectangle().fill(i % 2 == 0 ? Color.black : Color.clear).frame(width: widths[i] * 2.4)
                }
            }
            .frame(height: 100)
            Text("0  12345  67890  5").font(.system(size: 18, weight: .medium, design: .monospaced)).foregroundStyle(.black)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// A nutrition facts panel (US layout), the label mode's subject.
private struct MockNutritionLabel: View {
    var body: some View {
        ZStack {
            Color(hex: 0xD9CBB0)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nutrition Facts").font(.system(size: 30, weight: .black)).kerning(-0.5)
                Rectangle().frame(height: 1)
                Text("8 servings per container").font(.system(size: 13))
                HStack {
                    Text("Serving size").font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("2/3 cup (55g)").font(.system(size: 15, weight: .bold))
                }
                Rectangle().frame(height: 8)
                Text("Amount per serving").font(.system(size: 11, weight: .bold))
                HStack(alignment: .lastTextBaseline) {
                    Text("Calories").font(.system(size: 26, weight: .black))
                    Spacer()
                    Text("230").font(.system(size: 34, weight: .black))
                }
                Rectangle().frame(height: 4)
                row("Total Fat 8g", "10%", bold: true)
                row("   Saturated Fat 1g", "5%")
                row("Sodium 160mg", "7%", bold: true)
                row("Total Carbohydrate 37g", "13%", bold: true)
                row("   Dietary Fiber 4g", "14%")
                row("   Total Sugars 12g", "")
                row("Protein 3g", "", bold: true)
                Rectangle().frame(height: 8)
            }
            .foregroundStyle(.black)
            .padding(12)
            .background(Color.white)
            .border(Color.black, width: 2)
            .padding(18)
            .rotationEffect(.degrees(-1.5))
        }
    }

    private func row(_ title: String, _ percent: String, bold: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.system(size: 13, weight: bold ? .bold : .regular))
                Spacer()
                Text(percent).font(.system(size: 13, weight: .bold))
            }
            Rectangle().frame(height: 0.8)
        }
    }
}
