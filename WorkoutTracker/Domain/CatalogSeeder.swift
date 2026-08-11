import Foundation
import SwiftData

// Versioned, idempotent catalog seeding (D24). Runs on every launch:
// - inserts seeded rows missing from the store, keyed by fixed catalog UUID
//   (heals partial stores at any version, never duplicates);
// - when the bundled catalog version is newer than the last reconciled one,
//   rewrites the allowlisted seeded fields (name, links, metadata) of
//   existing seeded rows — seeded rows are not user-editable, so this is the
//   only writer;
// - never deletes seeded rows absent from the catalog (historical references
//   must keep resolving) and never touches user-created rows
//   (`isSeeded == false`).

enum CatalogSeeder {

    /// Reconciles `catalog` into the store behind `context`, saving only when
    /// something actually changed.
    static func reconcile(_ catalog: SeedCatalog, in context: ModelContext) throws {
        let preferences = try AppPreferences.canonical(in: context)
        let applyUpdates = catalog.version > preferences.seededCatalogVersion

        // Fast path (ticket 20: the catalog is ~2000 rows, and this runs on
        // every launch). With no update to apply, the only work left is
        // reinserting rows a damaged store is missing — and seeded rows are
        // only ever inserted from the catalog, keyed by unique catalog UUID, so
        // "as many seeded rows as the catalog has" means none are missing. A
        // count query beats materialising every row to diff it.
        if !applyUpdates, try isFullySeeded(catalog, in: context) {
            if context.hasChanges { try context.save() }
            return
        }

        try reconcileExercises(catalog.exercises, applyUpdates: applyUpdates, in: context)
        try reconcileEquipmentModels(catalog.equipmentModels, applyUpdates: applyUpdates, in: context)

        if applyUpdates {
            preferences.seededCatalogVersion = catalog.version
            preferences.updatedAt = .now
        }
        if context.hasChanges {
            try context.save()
        }
    }

    /// Whether the store already holds every seeded row the catalog defines.
    /// Deliberately a count comparison, not a per-row diff — see `reconcile`.
    /// A store seeded from a *newer* catalog than the bundle (an app downgrade)
    /// has more seeded rows than this catalog, which fails the check and falls
    /// through to the full pass; that pass then finds every row present and
    /// changes nothing.
    private static func isFullySeeded(_ catalog: SeedCatalog, in context: ModelContext) throws -> Bool {
        let seededExercises = try context.fetchCount(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.isSeeded }))
        guard seededExercises == catalog.exercises.count else { return false }
        let seededModels = try context.fetchCount(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.isSeeded }))
        return seededModels == catalog.equipmentModels.count
    }

    // MARK: Per-entity reconciliation

    private static func reconcileExercises(
        _ seeds: [SeedExercise], applyUpdates: Bool, in context: ModelContext
    ) throws {
        let existing = try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.isSeeded }))
        let byID = Dictionary(existing.map { ($0.id, $0) }) { first, _ in first }

        for seed in seeds {
            if let row = byID[seed.id] {
                guard applyUpdates else { continue }
                // Allowlisted seeded fields only (D24): name + metadata.
                setIfChanged(&row.name, seed.name)
                setIfChanged(&row.loadType, seed.loadType)
                setIfChanged(&row.equipmentTypeTags, seed.equipmentTypeTags)
                setIfChanged(&row.muscleGroup, seed.muscleGroup)
            } else {
                context.insert(Exercise(
                    id: seed.id,
                    name: seed.name,
                    loadType: seed.loadType,
                    equipmentTypeTags: seed.equipmentTypeTags,
                    muscleGroup: seed.muscleGroup,
                    isSeeded: true))
            }
        }
    }

    private static func reconcileEquipmentModels(
        _ seeds: [SeedEquipmentModel], applyUpdates: Bool, in context: ModelContext
    ) throws {
        let existing = try context.fetch(
            FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.isSeeded }))
        let byID = Dictionary(existing.map { ($0.id, $0) }) { first, _ in first }
        // Links the *user* added to a seeded model (ticket 19: an exercise
        // invented at a station) are user data living in an allowlisted
        // seeded field. They are re-merged below rather than overwritten —
        // D24 says reconciliation never touches user-created rows, and
        // silently unlinking one is touching it.
        let userExerciseIDs = applyUpdates ? try userCreatedExerciseIDs(in: context) : []

        for seed in seeds {
            if let row = byID[seed.id] {
                guard applyUpdates else { continue }
                // Allowlisted seeded fields only (D24): name + exercise links.
                setIfChanged(&row.manufacturer, seed.manufacturer)
                setIfChanged(&row.modelName, seed.modelName)
                setIfChanged(
                    &row.exerciseIDs,
                    merged(
                        seeded: seed.exerciseIDs, existing: row.exerciseIDs,
                        preserving: userExerciseIDs))
            } else {
                context.insert(EquipmentModel(
                    id: seed.id,
                    manufacturer: seed.manufacturer,
                    modelName: seed.modelName,
                    exerciseIDs: seed.exerciseIDs,
                    isSeeded: true))
            }
        }
    }

    /// The ids of user-created exercises (D24's user ID space).
    private static func userCreatedExerciseIDs(in context: ModelContext) throws -> Set<UUID> {
        Set(try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isSeeded })).map(\.id))
    }

    /// The catalog's links, in catalog order, followed by the user-added ones
    /// the store already had, in their existing order.
    private static func merged(
        seeded: [UUID], existing: [UUID], preserving userIDs: Set<UUID>
    ) -> [UUID] {
        let seededSet = Set(seeded)
        return seeded + existing.filter { userIDs.contains($0) && !seededSet.contains($0) }
    }

    /// Writes only on a real difference so an identical rerun leaves the
    /// context without changes (no save, no CloudKit churn).
    private static func setIfChanged<T: Equatable>(_ field: inout T, _ value: T) {
        if field != value { field = value }
    }
}
