import Testing
import UIKit
@testable import WorkoutTracker

struct ThemeTests {
    /// Every family has a style whose two map layers are in the asset
    /// catalog (ticket 12: muscle maps, body + muscle, template images).
    @Test @MainActor func everyMuscleFamilyHasBothMapLayers() throws {
        let bundle = Bundle(for: AppPreferences.self)
        for family in MuscleFamily.allCases {
            let style = try #require(MuscleGroupStyle.styles[family], "Missing muscle style: \(family)")
            for name in [style.bodyImage, style.muscleImage] {
                let image = try #require(UIImage(named: name, in: bundle, with: nil), "Missing asset: \(name)")
                #expect(image.renderingMode == .alwaysTemplate, "\(name) must be a template image")
            }
        }
        #expect(UIColor(named: "MuscleBody", in: bundle, compatibleWith: nil) != nil)
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
