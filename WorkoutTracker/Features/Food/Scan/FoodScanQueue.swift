import Observation
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

// Nutrition N7 (D82, D83) — the meal photos and descriptions being estimated. A scan is logged the moment its estimate
// arrives (one entry named for the meal, its photo kept with it); until then, and when it fails, Today's log shows its
// card. In memory only: a scan still running when the app is quit is not resumed (its photo is not stored until it is
// logged). The request finishes in the background for as long as iOS allows, and a notification says it is done when
// the app is not in front (permission asked on the first scan, D83).

@MainActor @Observable
final class FoodScanQueue {
    static let shared = FoodScanQueue()

    enum Failure: Equatable {
        /// The estimate found no food or drink.
        case nothingFound
        /// Today's limit for this flow (D75): how many a day and when it resets.
        case limit(Int?, resetsAt: Date)
        case offline
        /// No session, or it expired during the request: sign in, then the same scan is sent again.
        case signedOut
        /// Any other failure (timeout, the server unavailable or paused, an invalid reply, iOS ending the app's
        /// background time): try again.
        case other
    }

    struct Pending: Identifiable {
        let id = UUID()
        /// The JPEG sent and, once logged, kept (nil for a description).
        let jpeg: Data?
        let preview: UIImage?
        let text: String?
        let meal: MealSlot
        let eatenAt: Date
        let startedAt: Date
        var failure: Failure?
        /// Logged to an earlier day (a library photo taken then, D83): Today does not list that day, so the card stays
        /// with Open until removed (codex-review-n7 S2). The entry's ID, resolved against the live entries each time —
        /// after Delete and Undo the entry is a new object with the same ID (codex-review-n7b R2-S1).
        var loggedEarlierID: UUID?
    }

    private(set) var pending: [Pending] = []
    /// Bumped on every change, so the observing view animates it (or not, under Reduce Motion — codex-review-n7 T2).
    private(set) var revision = 0
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private static let notificationsAskedKey = "foodScan.notificationsAsked"

    /// A meal photo: its card appears at once and the estimate is logged when it arrives.
    func startPhoto(jpeg: Data, meal: MealSlot, eatenAt: Date, client: AIServerClient?, context: ModelContext) {
        start(Pending(jpeg: jpeg, preview: UIImage(data: jpeg), text: nil, meal: meal, eatenAt: eatenAt,
                      startedAt: .now), client: client, context: context)
    }

    /// Describe what you ate: logged at once like a photo (D83), its card on Today meanwhile.
    func startDescribe(_ text: String, meal: MealSlot, client: AIServerClient?, context: ModelContext) {
        start(Pending(jpeg: nil, preview: nil, text: text, meal: meal, eatenAt: .now, startedAt: .now),
              client: client, context: context)
    }

    func retry(_ id: UUID, client: AIServerClient?, context: ModelContext) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let old = pending.remove(at: index)
        start(Pending(jpeg: old.jpeg, preview: old.preview, text: old.text, meal: old.meal, eatenAt: old.eatenAt,
                      startedAt: .now), client: client, context: context)
    }

    func dismiss(_ id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        pending.removeAll { $0.id == id }
        revision += 1
    }

    private func start(_ scan: Pending, client: AIServerClient?, context: ModelContext) {
        pending.insert(scan, at: 0)
        revision += 1
        askForNotificationsOnce()
        let id = scan.id
        // iOS gives a backgrounded app a little time to finish (the estimate usually takes 5–10 s). When that time runs
        // out the request is cancelled and the card offers Try again; the assertion ends exactly once either way
        // (codex-review-n7 S6).
        let assertion = BackgroundAssertion { [weak self] in self?.expire(id) }
        tasks[id] = Task { [weak self] in
            defer { assertion.end() }
            let outcome = await Self.estimate(scan, client: client)
            guard !Task.isCancelled else { return }
            self?.finish(id, outcome: outcome, context: context)
        }
    }

    private func expire(_ id: UUID) {
        tasks[id]?.cancel()
        tasks[id] = nil
        guard let index = pending.firstIndex(where: { $0.id == id }), pending[index].failure == nil else { return }
        pending[index].failure = .other
        revision += 1
    }

    private enum Outcome { case estimate(FoodEstimate), failure(Failure) }

    private static func estimate(_ scan: Pending, client: AIServerClient?) async -> Outcome {
        let flow: AIFlow = scan.text == nil ? .foodPhoto : .foodDescribe
        do {
            let data: Data
            if TerraAccess.fixture {
                data = try await FoodScanFixture.reply(flow)
            } else {
                guard let client else { throw AIServerError.signedOut }
                let body = scan.text.map(AIServerClient.foodDescribeBody(text:))
                    ?? AIServerClient.foodPhotoBody(jpeg: scan.jpeg ?? Data())
                data = try await client.complete(flow, json: body)
            }
            guard let estimate = FoodEstimate.parse(data) else { return .failure(.other) }
            return estimate.items.isEmpty ? .failure(.nothingFound) : .estimate(estimate)
        } catch let error as AIServerError {
            switch error {
            case .limit(_, let limit, let resetsAt): return .failure(.limit(limit, resetsAt: resetsAt))
            case .offline: return .failure(.offline)
            case .signedOut: return .failure(.signedOut)
            default: return .failure(.other)
            }
        } catch {
            return .failure(.other)
        }
    }

    private func finish(_ id: UUID, outcome: Outcome, context: ModelContext) {
        tasks[id] = nil
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let scan = pending[index]
        switch outcome {
        case .estimate(let estimate):
            do {
                let entry = try FoodScan.log(estimate, photo: scan.jpeg, source: scan.text == nil ? .photo : .describe,
                                             meal: scan.meal, at: scan.eatenAt, in: context)
                if Calendar.current.isDateInToday(entry.loggedAt) {
                    pending.remove(at: index)
                } else {
                    pending[index].loggedEarlierID = entry.id
                }
                revision += 1
                notify(title: FoodScanCopy.loggedTitle(entry.name),
                       body: FoodScanCopy.loggedBody(calories: NutritionMath.totals(of: entry).calories, meal: entry.meal))
            } catch {
                pending[index].failure = .other
                revision += 1
            }
        case .failure(let failure):
            pending[index].failure = failure
            revision += 1
            notify(title: FoodScanCopy.failureTitle(failure, describe: scan.text != nil),
                   body: FoodScanCopy.failureDetail(failure, describe: scan.text != nil))
        }
    }

    // MARK: Notification (D82, D83)

    private func askForNotificationsOnce() {
        // UI tests never see the system prompt (it would cover every later screen).
        guard !TerraAccess.fixture, !UserDefaults.standard.bool(forKey: Self.notificationsAskedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.notificationsAskedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Only when the app is not in front: in front, the card itself changes.
    private func notify(title: String, body: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content,
                                                                     trigger: nil))
    }
}

/// Scan Food's words (N7; each listed in the ticket for the user's OK). No "AI" in them (D83).
enum FoodScanCopy {
    static func loggedTitle(_ name: String) -> String { "\(name) logged" }

    static func loggedBody(calories: Double, meal: MealSlot) -> String { "\(FoodCopy.calories(calories)) · \(meal.label)" }

    static func failureTitle(_ failure: FoodScanQueue.Failure, describe: Bool) -> String {
        switch failure {
        case .nothingFound: "No food found"
        case .limit: "Daily limit reached"
        case .offline, .signedOut, .other: "Couldn't analyze"
        }
    }

    /// An entry logged to an earlier day: "Logged to Mon, Nov 9 · Lunch".
    static func loggedEarlier(_ entry: FoodEntry) -> String {
        "Logged to \(entry.loggedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(entry.meal.label)"
    }

    static func failureDetail(_ failure: FoodScanQueue.Failure, describe: Bool, zone: TimeZone = .current) -> String {
        switch failure {
        case .nothingFound:
            describe ? "Try naming the food and how much." : "Try a closer photo, or add it by hand."
        case .limit(let limit, let resetsAt):
            "\(limit ?? (describe ? 60 : 30)) \(describe ? "descriptions" : "meal photos") a day. "
                + "More at \(AIResetCopy.clock(resetsAt, zone: zone))."
        case .offline:
            describe ? "No connection. Try again." : "No connection. Your photo is kept until you try again."
        case .signedOut:
            "Sign in, then try again."
        case .other:
            "Something went wrong. Try again."
        }
    }
}

/// A UIKit background-time assertion that ends exactly once — by the work finishing, by Remove, or by iOS's
/// expiration handler (which must end it before returning).
@MainActor
private final class BackgroundAssertion {
    private var id: UIBackgroundTaskIdentifier = .invalid

    init(expired: @escaping @MainActor () -> Void) {
        id = UIApplication.shared.beginBackgroundTask(withName: "food-scan") { [weak self] in
            MainActor.assumeIsolated {
                expired()
                self?.end()
            }
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

// MARK: - The fixture (UI tests and the Simulator's captures, `-uiTestTerra`)

/// The server's answers for the UI tests: a poke bowl, eggs and toast, a granola label. `-uiTestFoodScanFail
/// nothing|limit|offline|other` fails instead; `-uiTestFoodScanHold` holds the card for the captures.
@MainActor
enum FoodScanFixture {
    private static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static func reply(_ flow: AIFlow) async throws -> Data {
        let hold = ProcessInfo.processInfo.arguments.contains("-uiTestFoodScanHold")
        try await Task.sleep(for: .seconds(hold ? 20 : 2))
        switch argument("-uiTestFoodScanFail") {
        case "nothing" where flow != .foodLabel:
            return try JSONSerialization.data(withJSONObject: ["mealName": "", "items": [] as [Any]])
        case "nothing":
            return try JSONSerialization.data(withJSONObject: ["found": false, "servingSize": ""])
        case "limit": throw AIServerError.limit(flow, flow == .foodDescribe ? 60 : 30, resetsAt: AIResetCopy.nextReset())
        case "offline": throw AIServerError.offline
        case "signedOut": throw AIServerError.signedOut
        case "other": throw AIServerError.timedOut
        default: break
        }
        let object: [String: Any]
        switch flow {
        case .foodLabel:
            object = ["found": true, "servingSize": "2/3 cup (55 g)", "servingGrams": 55, "servingsPerContainer": 8,
                      "calories": 230, "protein": 3, "carbs": 37, "fat": 8, "saturatedFat": 1, "fiber": 4, "sugar": 12,
                      "sodiumMg": 160]
        case .foodDescribe:
            object = ["mealName": "Eggs and toast", "items": [
                item("Scrambled eggs", "2 eggs", 120, 180, 13, 2, 13),
                item("Toast, buttered", "1 slice", 35, 120, 3, 14, 6)]]
        default:
            object = ["mealName": "Poke bowl", "items": [
                item("Tuna poke", "1 cup", 150, 160, 26, 4, 4),
                item("Sushi rice", "1 cup", 160, 210, 4, 46, 0.5),
                item("Avocado", "¼ fruit", 50, 80, 1, 4, 7),
                item("Mango", "½ cup", 80, 50, 0.5, 12, 0),
                item("Edamame", "¼ cup", 40, 50, 5, 4, 2)]]
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func item(_ name: String, _ portion: String, _ grams: Double, _ calories: Double, _ protein: Double,
                             _ carbs: Double, _ fat: Double) -> [String: Any] {
        ["name": name, "portion": portion, "grams": grams, "calories": calories, "protein": protein, "carbs": carbs,
         "fat": fat, "confidence": "high"]
    }
}
