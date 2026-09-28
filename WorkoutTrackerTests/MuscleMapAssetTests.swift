import Testing
import UIKit
@testable import WorkoutTracker

struct MuscleMapAssetTests {
    /// Every family's two map layers are in the asset catalog (ticket 12: muscle maps, body +
    /// muscle, template images), and every family has its own colour in both Floodlight palettes.
    @Test @MainActor func everyMuscleFamilyHasBothMapLayers() throws {
        let bundle = Bundle(for: AppPreferences.self)
        for family in MuscleFamily.allCases {
            for look in [Look.floodlight, Look.floodlightLight] {
                #expect(look.familyColors[family] != nil, "No \(family) colour")
            }
            for name in [family.bodyAsset, family.muscleAsset] {
                let image = try #require(UIImage(named: name, in: bundle, with: nil), "Missing asset: \(name)")
                #expect(image.renderingMode == .alwaysTemplate, "\(name) must be a template image")
            }
        }
        // The body colour is a design token now (`Look.mapBody`, light and dark), not an asset.
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
