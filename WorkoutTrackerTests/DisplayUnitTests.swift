import Foundation
import Testing

@testable import WorkoutTracker

/// Gym feedback, 2026-08-26: "in workout summary total volume appears as kg
/// even when workout was recorded as lb" and "chart should just plot in
/// whatever the app's default unit is set to".
///
/// Storage stays canonical kg (D25) so mixed-unit sessions share one axis and
/// one total. What was wrong is that the DISPLAY did not follow the unit the
/// user thinks in — the same complaint D9 exists to prevent, one surface over.
struct DisplayUnitTests {

    /// 100 kg is about 220.46 lb. A user logging in lb should see that, not
    /// "100 kg" for a session where they never typed a kilogram.
    @Test func aVolumeInKgConvertsForALbUser() {
        let lb = WeightMath.convert(100, from: .kg, to: .lb)
        #expect(abs(lb - 220.46) < 0.01, "got \(lb)")
    }

    @Test func conversionIsIdentityWhenTheUnitsAlreadyMatch() {
        #expect(WeightMath.convert(100, from: .kg, to: .kg) == 100)
        #expect(WeightMath.convert(135, from: .lb, to: .lb) == 135)
    }

    /// D9/D25: a converted number is approximate and must say so. A volume is
    /// approximate twice over — it is a sum, then converted.
    @Test func aConvertedDisplayIsMarkedApproximate() {
        let stored = StoredWeight(value: 60, unit: .kg)!
        let sameUnit = WeightMath.displayLabel(for: stored, in: .kg)
        let converted = WeightMath.displayLabel(for: stored, in: .lb)
        #expect(!sameUnit.contains("≈"), "an as-entered value is exact")
        #expect(converted.contains("≈"), "a converted value must be marked")
    }

    /// The app-level default is what these surfaces follow: no machine and no
    /// gym context, so precedence falls straight through to the preference
    /// (T7).
    @Test func theAppPreferenceDecidesWhenThereIsNoMachineOrGym() {
        #expect(
            UnitPrecedence.defaultUnit(
                machineUnit: nil, gymUnit: nil, appPreference: .lb) == .lb)
        #expect(
            UnitPrecedence.defaultUnit(
                machineUnit: nil, gymUnit: nil, appPreference: .kg) == .kg)
    }

    /// Round-tripping must not drift, or a chart replotted in the user's unit
    /// would disagree with the total on the summary screen.
    @Test func convertingAndBackIsStable() {
        let original = 137.5
        let there = WeightMath.convert(original, from: .kg, to: .lb)
        let back = WeightMath.convert(there, from: .lb, to: .kg)
        #expect(abs(back - original) < 0.000_001, "got \(back)")
    }

    /// Reps are not a weight. A plain-bodyweight chart plots reps, and
    /// converting them would be nonsense.
    @Test func bodyweightPlotsRepsWhichHaveNoUnit() {
        let series = ProgressSeriesMath.series(
            for: [
                RecordSetInput(
                    loadType: .bodyweight, exerciseID: UUID(), setType: .working,
                    reps: 20, weightValue: nil, weightUnit: .kg,
                    normalizedKg: nil, completedAt: Date(timeIntervalSince1970: 86_400)),
            ],
            variation: ProgressVariationKey(loadType: .bodyweight, equipment: .unrecorded, presetID: nil))
        #expect(
            series.points.first?.bestKg == 20,
            "a bodyweight point carries reps, and 20 reps is 20 reps in any unit")
    }
}
