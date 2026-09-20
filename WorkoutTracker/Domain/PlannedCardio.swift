import Foundation

/// A prescription, never a measurement. Starting it links a real segment; targets never enter metrics.
struct PlannedCardio: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var activity: CardioActivity
    var minutes: Int
    var distance: Double?
    var unit: CardioDistanceUnit = .localeDefault
    var segmentID: UUID?
    var summary: String {
        let duration = "\(minutes) min"
        guard let distance else { return duration }
        return "\(duration) · \(distance.formatted()) \(unit.rawValue)"
    }
    var isValid: Bool {
        (1...180).contains(minutes) && (distance == nil || (distance!.isFinite && distance! > 0 && distance! <= 200))
    }
}

/// Preserve unknown future rows byte-for-byte in the backing JSON when known rows are updated.
/// Dropping an unreadable activity would silently erase a user's plan on the next save.
enum CardioPlanStorage {
    static func rows(_ data: Data?) -> [Any]? {
        guard let data else { return [] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [Any]
    }
    static func target(_ row: Any) -> PlannedCardio? {
        guard JSONSerialization.isValidJSONObject(row), let data = try? JSONSerialization.data(withJSONObject: row) else { return nil }
        return try? JSONDecoder().decode(PlannedCardio.self, from: data)
    }
    static func read(_ data: Data?) -> [PlannedCardio] { rows(data)?.compactMap(target) ?? [] }
    static func hasUnknown(_ data: Data?) -> Bool {
        guard let rows = rows(data) else { return true }
        return rows.contains { target($0) == nil }
    }
    static func replacing(_ data: Data?, with values: [PlannedCardio]) -> Data? {
        guard let rows = rows(data), let encoded = try? JSONEncoder().encode(values),
              let known = try? JSONSerialization.jsonObject(with: encoded) as? [Any] else { return data }
        let unknown = rows.filter { target($0) == nil }
        return (try? JSONSerialization.data(withJSONObject: known + unknown, options: [.sortedKeys])) ?? data
    }
}
extension WorkoutTemplate {
    var hasUnknownCardioTargets: Bool { CardioPlanStorage.hasUnknown(cardioPlanData) }
    var plannedCardio: [PlannedCardio] {
        get { CardioPlanStorage.read(cardioPlanData) }
        set { cardioPlanData = CardioPlanStorage.replacing(cardioPlanData, with: newValue) }
    }
}
extension Workout {
    var hasUnknownCardioTargets: Bool { CardioPlanStorage.hasUnknown(cardioPlanData) }
    var plannedCardio: [PlannedCardio] {
        get { CardioPlanStorage.read(cardioPlanData) }
        set { cardioPlanData = CardioPlanStorage.replacing(cardioPlanData, with: newValue) }
    }
    func canStart(_ target: PlannedCardio) -> Bool {
        guard unfinishedCardio == nil else { return false }
        guard let id = target.segmentID, let segment = orderedCardio.first(where: { $0.id == id }) else { return true }
        return segment.endedAt != nil && !segment.hasRecordedActivity
    }
}
