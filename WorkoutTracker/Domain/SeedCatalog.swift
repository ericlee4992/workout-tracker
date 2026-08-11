import Foundation

// The bundled seed catalog (D24): a versioned JSON fixture carrying fixed
// catalog UUIDs for seeded exercises and equipment models. CatalogSeeder
// reconciles it into the SwiftData store on every launch.

/// 64-bit FNV-1a — a deterministic, process-independent hash (Swift's `Hasher`
/// is randomly seeded per process, so its values cannot be persisted).
struct FNV1a {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325
    private static let prime: UInt64 = 0x1000_0000_01b3

    /// Absorbs one field. A trailing separator byte keeps ("ab", "c") and
    /// ("a", "bc") distinct — otherwise a rename could hash to its neighbour.
    mutating func combine(_ field: String) {
        for byte in field.utf8 {
            value = (value ^ UInt64(byte)) &* Self.prime
        }
        endField()
    }

    /// UUIDs by their 16 raw bytes rather than their 36-character string: the
    /// catalog carries ~4000 of them and this runs on every launch.
    mutating func combine(_ field: UUID) {
        withUnsafeBytes(of: field.uuid) { bytes in
            for byte in bytes {
                value = (value ^ UInt64(byte)) &* Self.prime
            }
        }
        endField()
    }

    private mutating func endField() {
        value = (value ^ 0xff) &* Self.prime
    }
}

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

    /// Fingerprint of everything reconciliation writes: the version, every
    /// row's fixed UUID, and every allowlisted mutable field (D24). Two
    /// catalogs with the same fingerprint reconcile to the same store, so
    /// `CatalogSeeder` can skip the diff when the stored fingerprint matches —
    /// and, crucially, cannot skip it when the content changed without the
    /// version changing.
    ///
    /// FNV-1a rather than `Hasher`: the value is persisted across launches and
    /// Swift's `Hasher` is seeded per process, so its output is not stable.
    var fingerprint: String {
        var hash = FNV1a()
        hash.combine(String(version))
        for exercise in exercises {
            hash.combine(exercise.id)
            hash.combine(exercise.name)
            hash.combine(exercise.loadType.rawValue)
            for tag in exercise.equipmentTypeTags { hash.combine(tag.rawValue) }
            hash.combine(exercise.muscleGroup ?? "")
        }
        for model in equipmentModels {
            hash.combine(model.id)
            hash.combine(model.manufacturer)
            hash.combine(model.modelName)
            hash.combine(model.equipmentType?.rawValue ?? "")
            for id in model.exerciseIDs { hash.combine(id) }
        }
        return String(hash.value, radix: 16)
    }

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
