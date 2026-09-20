import Foundation

/// One app default for lifting and cardio, backed by the existing kg/lb preference.
/// Reusing that stored value preserves existing choices without a schema migration.
enum AppUnitSystem: String, CaseIterable, Identifiable, Sendable {
    case metric, usCustomary
    var id: String { rawValue }
    var title: String { self == .metric ? "Metric" : "U.S. customary" }
    var weightUnit: WeightUnit { self == .metric ? .kg : .lb }
    var distanceUnit: CardioDistanceUnit { self == .metric ? .km : .mi }

    static func resolve(preference: WeightUnit?,
                        measurementSystem: Locale.MeasurementSystem = Locale.current.measurementSystem) -> Self {
        if let preference { return preference == .kg ? .metric : .usCustomary }
        return measurementSystem == .us ? .usCustomary : .metric
    }
}
