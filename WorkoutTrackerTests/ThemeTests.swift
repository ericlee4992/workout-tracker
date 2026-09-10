import Testing
import UIKit
@testable import WorkoutTracker

struct ThemeTests {
    @Test @MainActor func everyCatalogMuscleGroupHasAResolvableSymbol() throws {
        let groups = Set(try SeedCatalog.bundled().exercises.compactMap(\.muscleGroup))
        #expect(groups.count == 14)
        for group in groups {
            let style = try #require(MuscleGroupStyle.styles[group], "Missing muscle style: \(group)")
            #expect(UIImage(systemName: style.symbol) != nil, "Missing symbol: \(style.symbol)")
        }
        #expect(UIImage(systemName: MuscleGroupStyle.fallback.symbol) != nil)
    }
}
