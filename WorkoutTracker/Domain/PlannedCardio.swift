import Foundation

/// A prescription, never a measurement. Starting it links a real segment; targets never enter metrics.
struct PlannedCardio: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var activity: CardioActivity
    var minutes: Int
    var distance: Double?
    var unit: CardioDistanceUnit = .km
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

extension WorkoutTemplate {
    var plannedCardio: [PlannedCardio] {
        get { cardioPlanData.flatMap { try? JSONDecoder().decode([PlannedCardio].self, from: $0) } ?? [] }
        set { cardioPlanData = try? JSONEncoder().encode(newValue) }
    }
}
extension Workout {
    var plannedCardio: [PlannedCardio] {
        get { cardioPlanData.flatMap { try? JSONDecoder().decode([PlannedCardio].self, from: $0) } ?? [] }
        set { cardioPlanData = try? JSONEncoder().encode(newValue) }
    }
}
