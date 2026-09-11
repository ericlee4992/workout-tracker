import Testing
import UIKit
@testable import WorkoutTracker

struct ThemeTests {
    /// Every family has a style whose symbol exists (ticket 11: five
    /// families, not the 14 seeded groups — the mapping is `MuscleFamily`).
    @Test @MainActor func everyMuscleFamilyHasAResolvableSymbol() throws {
        for family in MuscleFamily.allCases {
            let style = try #require(MuscleGroupStyle.styles[family], "Missing muscle style: \(family)")
            #expect(UIImage(systemName: style.symbol) != nil, "Missing symbol: \(style.symbol)")
        }
        #expect(UIImage(systemName: MuscleGroupStyle.fallback.symbol) != nil)
    }

    /// The seeded vocabulary is still 14 groups; each is a family or one of
    /// the three the user did not name (Core, Neck, Full Body).
    @Test @MainActor func everyCatalogMuscleGroupIsAFamilyOrAKnownException() throws {
        let groups = Set(try SeedCatalog.bundled().exercises.compactMap(\.muscleGroup))
        #expect(groups.count == 14)
        let exceptions: Set<String> = ["Core", "Neck", "Full Body"]
        for group in groups where MuscleFamily(muscleGroup: group) == nil {
            #expect(exceptions.contains(group), "Unmapped group: \(group)")
        }
    }
}
