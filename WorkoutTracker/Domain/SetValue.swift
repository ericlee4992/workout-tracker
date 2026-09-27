import Foundation

/// A set as the screens display it: the as-entered weight and unit (D25), reps, and the bar when
/// it was logged in bar mode (same unit).
struct SetValue: Hashable, Sendable {
    var weight: Double?
    var unit: WeightUnit
    var reps: Int
    var bar: Double? = nil
}

extension SetValue {
    /// The as-entered value of a record input (nil reps = not a displayable set).
    init?(_ input: RecordSetInput) {
        guard let reps = input.reps else { return nil }
        self.init(weight: input.weightValue, unit: input.weightUnit, reps: reps, bar: input.barWeightValue)
    }
}
