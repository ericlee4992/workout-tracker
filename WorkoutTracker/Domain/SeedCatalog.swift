import Foundation

// The bundled seed catalog (D24): a versioned JSON fixture carrying fixed
// catalog UUIDs for seeded exercises and equipment models. CatalogSeeder
// reconciles it into the SwiftData store on every launch.

struct SeedCatalog: Codable {
    /// Monotonically increasing catalog version. Reconciliation updates
    /// allowlisted fields of existing seeded rows only when this exceeds
    /// `AppPreferences.seededCatalogVersion`; missing rows are inserted
    /// regardless (partial stores heal at any version).
    var version: Int
    var exercises: [SeedExercise]
    var equipmentModels: [SeedEquipmentModel]
}

struct SeedExercise: Codable {
    /// Fixed catalog UUID — stable across catalog versions and app releases.
    var id: UUID
    var name: String
    var loadType: LoadType
    var equipmentTypeTags: [EquipmentTag]
    var muscleGroup: String?
}

struct SeedEquipmentModel: Codable {
    /// Fixed catalog UUID — stable across catalog versions and app releases.
    var id: UUID
    var manufacturer: String
    var modelName: String
    /// How the model is loaded (ticket 21). nil where the research did not
    /// establish it — guessing would put a machine in a group it isn't in.
    /// Absent from a catalog written before ticket 21 decodes as nil.
    var equipmentType: EquipmentCategory? = nil
    /// Catalog UUIDs of the exercises this model serves (≥1; multi-exercise
    /// stations list several).
    var exerciseIDs: [UUID]
}

extension SeedCatalog {
    enum LoadError: Error {
        case resourceMissing
    }

    /// Loads the catalog shipped in the app bundle (Resources/SeedCatalog.json).
    /// Resolved via a class in the app binary so it also works from the
    /// app-hosted unit-test bundle.
    static func bundled() throws -> SeedCatalog {
        guard let url = Bundle(for: AppPreferences.self)
            .url(forResource: "SeedCatalog", withExtension: "json")
        else {
            throw LoadError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SeedCatalog.self, from: data)
    }
}
