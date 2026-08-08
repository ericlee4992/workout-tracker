import Foundation

// Unit-default precedence (SPEC "Units", T7): machine → gym → app preference —
// most specific context wins. Pure logic, no UI imports.

enum UnitPrecedence {

    /// Resolves the default unit for a new set. Every level is optional and
    /// falls through: a machine or gym without a default, or no machine/gym
    /// at all. `appPreference` is nil only before first-launch resolution;
    /// the final fallback then derives from the locale's measurement system.
    static func defaultUnit(
        machineUnit: WeightUnit?,
        gymUnit: WeightUnit?,
        appPreference: WeightUnit?,
        locale: Locale = .current
    ) -> WeightUnit {
        machineUnit
            ?? gymUnit
            ?? appPreference
            ?? firstLaunchDefault(for: locale.measurementSystem)
    }

    /// Convenience over the model graph — handles the no-machine and no-gym
    /// cases directly (D2: machine and gym are both optional context).
    static func defaultUnit(
        machine: MachineInstance?,
        gym: Gym?,
        appPreference: WeightUnit?,
        locale: Locale = .current
    ) -> WeightUnit {
        defaultUnit(
            machineUnit: machine?.defaultUnit,
            gymUnit: gym?.defaultUnit,
            appPreference: appPreference,
            locale: locale)
    }

    /// First-launch app-preference default derived from the locale
    /// measurement system: US customary → lb, everything else → kg.
    static func firstLaunchDefault(for measurementSystem: Locale.MeasurementSystem) -> WeightUnit {
        measurementSystem == .us ? .lb : .kg
    }
}
