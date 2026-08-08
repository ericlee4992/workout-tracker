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
        let preferences = try resolvePreferences(in: context)
        let applyUpdates = catalog.version > preferences.seededCatalogVersion

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

        for seed in seeds {
            if let row = byID[seed.id] {
                guard applyUpdates else { continue }
                // Allowlisted seeded fields only (D24): name + exercise links.
                setIfChanged(&row.manufacturer, seed.manufacturer)
                setIfChanged(&row.modelName, seed.modelName)
                setIfChanged(&row.exerciseIDs, seed.exerciseIDs)
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

    /// Writes only on a real difference so an identical rerun leaves the
    /// context without changes (no save, no CloudKit churn).
    private static func setIfChanged<T: Equatable>(_ field: inout T, _ value: T) {
        if field != value { field = value }
    }

    // MARK: Preferences

    /// Canonical AppPreferences row (app-side upsert: latest `updatedAt`,
    /// ties broken by `id` — no unique constraints under CloudKit). Creates
    /// the row on first launch.
    private static func resolvePreferences(in context: ModelContext) throws -> AppPreferences {
        let all = try context.fetch(FetchDescriptor<AppPreferences>())
        if let canonical = all.max(by: {
            ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString)
        }) {
            return canonical
        }
        let fresh = AppPreferences()
        context.insert(fresh)
        return fresh
    }
}
