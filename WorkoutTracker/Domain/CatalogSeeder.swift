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
        let fingerprint = catalog.fingerprint

        // What the store was last reconciled against. Equal fingerprints mean
        // the catalog's *content* is unchanged since that run — which the
        // version number alone cannot say, because a content edit that forgets
        // the bump (or a rebuilt bundle at the same version) looks identical.
        let contentAlreadyApplied =
            preferences.seededCatalogFingerprint == fingerprint
        let previousVersion = preferences.seededCatalogVersion
        let applyUpdates = catalog.version > previousVersion
            || (catalog.version == previousVersion && !contentAlreadyApplied)

        // Fast path (ticket 20: the catalog is ~1900 rows and this runs on every
        // launch). Skipping the diff is only sound when the store still holds
        // exactly the catalog's seeded rows, so that is what is checked — the
        // set of seeded ids, not their number. A count check passes a store that
        // lost one seeded row and gained an unrelated one, and would leave the
        // lost row missing forever (codex-review-4).
        if !applyUpdates, contentAlreadyApplied,
           try seededIdentitiesMatch(catalog, in: context) {
            if context.hasChanges { try context.save() }
            return
        }

        try reconcileExercises(catalog.exercises, applyUpdates: applyUpdates, in: context)
        try reconcileEquipmentModels(catalog.equipmentModels, applyUpdates: applyUpdates, in: context)

        // Milestone 9, ticket 04: crossing into catalog version 5 moves
        // dumbbell-tagged history onto the new dumbbell exercises, ONCE. Keyed
        // on the stored version, so a store already at 5 never re-runs it, and
        // a fresh store (0 → 5) runs it over nothing. Recorded so Settings can
        // say what happened — a silent rewrite of history is the thing this
        // app refuses (D23).
        if applyUpdates, previousVersion < 5, catalog.version >= 5 {
            let moved = try DumbbellHistoryMove.run(in: context)
            if moved.sets > 0 {
                preferences.dumbbellHistoryMovedSets = moved.sets
                preferences.dumbbellHistoryMovedAt = .now
            }
        }

        if applyUpdates {
            preferences.seededCatalogVersion = catalog.version
            preferences.seededCatalogFingerprint = fingerprint
            preferences.updatedAt = .now
        }
        if context.hasChanges {
            try context.save()
        }
    }

    /// Whether the store's seeded rows are exactly the catalog's rows.
    ///
    /// Two aggregate queries per entity, no rows materialised: how many seeded
    /// rows there are, and how many carry an id the catalog does not define.
    /// Both zero-difference ⇒ every catalog row is present. Fetching the ids
    /// themselves would be honest too, but materialises ~1950 SwiftData objects
    /// and costs ~85 ms — the pass this exists to avoid (measured: 0.2 ms for
    /// the counts, 5 ms for the two id-set queries, 63 ms for a plain fetch).
    ///
    /// Residual: a store holding *two* copies of one seeded row and missing
    /// another passes both checks. Nothing in the app can produce that — the
    /// reconciler inserts only by missing id — and it would take a CloudKit
    /// merge conflict (no unique constraints, T2). The old count-only check, by
    /// contrast, passed for any deletion balanced by any insertion, which is
    /// what a partially restored backup looks like (codex-review-4).
    ///
    /// A store seeded from a *newer* catalog than the bundle (an app downgrade)
    /// holds ids this catalog does not define, fails the check, and falls
    /// through to the full pass; that pass finds every row present and, since
    /// `applyUpdates` is false, changes nothing.
    private static func seededIdentitiesMatch(
        _ catalog: SeedCatalog, in context: ModelContext
    ) throws -> Bool {
        guard try context.fetchCount(
                FetchDescriptor<Exercise>(predicate: #Predicate { $0.isSeeded }))
                == catalog.exercises.count,
              try context.fetchCount(
                FetchDescriptor<EquipmentModel>(predicate: #Predicate { $0.isSeeded }))
                == catalog.equipmentModels.count
        else { return false }

        let exerciseIDs = Set(catalog.exercises.map(\.id))
        let modelIDs = Set(catalog.equipmentModels.map(\.id))
        return try context.fetchCount(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isSeeded && !exerciseIDs.contains($0.id) })) == 0
            && context.fetchCount(FetchDescriptor<EquipmentModel>(
                predicate: #Predicate { $0.isSeeded && !modelIDs.contains($0.id) })) == 0
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
                // Load type is the ONE allowlisted field a user can correct
                // (milestone 8, ticket 02). Overwriting a hand-fixed value here
                // would silently flip their records back at the next catalog
                // version, which is worse than never letting them fix it.
                if row.loadTypeUserOverridden != true {
                    setIfChanged(&row.loadType, seed.loadType)
                }
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
                // Allowlisted seeded fields only (D24): name + metadata +
                // exercise links.
                setIfChanged(&row.manufacturer, seed.manufacturer)
                setIfChanged(&row.modelName, seed.modelName)
                setIfChanged(&row.equipmentType, seed.equipmentType)
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
                    equipmentType: seed.equipmentType,
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
