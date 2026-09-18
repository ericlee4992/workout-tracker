import Foundation
import SwiftData

// Milestone 3, ticket 01 — reads the store and produces an `ExportSnapshot`.
// The only export component that touches SwiftData; it imports no UI, and the
// renderers below it never see a `@Model` object.

struct ExportCollector {
    let dateFormat: ExportDateFormat
    let appVersion: String

    init(
        dateFormat: ExportDateFormat = ExportDateFormat(),
        appVersion: String = ExportCollector.bundleVersion()
    ) {
        self.dateFormat = dateFormat
        self.appVersion = appVersion
    }

    /// `1.0 (3)`, or empty when the bundle carries no version (test hosts).
    static func bundleVersion() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (short?, build?): return "\(short) (\(build))"
        case let (short?, nil): return short
        case let (nil, build?): return build
        case (nil, nil): return ""
        }
    }

    // MARK: - Collection

    func snapshot(from context: ModelContext, now: Date = .now) throws -> ExportSnapshot {
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        let machines = try context.fetch(FetchDescriptor<MachineInstance>())
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let presets = try context.fetch(FetchDescriptor<ExercisePreset>())
        let models = try context.fetch(FetchDescriptor<EquipmentModel>())
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let memories = try context.fetch(FetchDescriptor<GymExerciseMemory>())
        let overrides = try context.fetch(FetchDescriptor<ExerciseRestOverride>())
        let preferences = AppPreferences.canonical(
            of: try context.fetch(FetchDescriptor<AppPreferences>()))

        let modelsByID = Dictionary(models.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let exerciseNamesByID = Dictionary(
            exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        let exportedWorkouts = workouts
            .sorted(by: Self.workoutOrder)
            .map { workout(from: $0, modelsByID: modelsByID) }

        // D28 — which catalog rows the user's own data actually reaches. Not
        // transitive: a referenced model's `exerciseIDs` may name exercises
        // nothing else references, and following those links would drag in most
        // of a 1877-row catalog to describe links the app already ships.
        let referenced = referencedCatalogIDs(
            machines: machines, workouts: exportedWorkouts,
            templates: templates, memories: memories, overrides: overrides,
            presets: presets, models: models,
            userExerciseIDs: Set(exercises.lazy.filter { !$0.isSeeded }.map(\.id)))

        // A seeded row the user has CORRECTED is user-authored data, not
        // catalog filler, so it is exported even when nothing references it
        // (codex-review, critical). Dropping it means a restore reverts the
        // correction at the next reconciliation with no trace.
        let exportedExercises = exercises
            .filter {
                !$0.isSeeded
                    || $0.loadTypeUserOverridden == true
                    || referenced.exerciseIDs.contains($0.id)
            }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
            .map(exercise(from:))
        let exportedModels = models
            .filter { !$0.isSeeded || referenced.modelIDs.contains($0.id) }
            .sorted { ($0.displayName, $0.id.uuidString) < ($1.displayName, $1.id.uuidString) }
            .map(equipmentModel(from:))
        let exportedTemplates = templates
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
            .map { template(from: $0, exerciseNamesByID: exerciseNamesByID) }
        let exportedGyms = gyms
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
            .map(gym(from:))
        let exportedMachines = machines
            .sorted { ($0.label, $0.id.uuidString) < ($1.label, $1.id.uuidString) }
            .map(machine(from:))

        let entryCount = exportedWorkouts.reduce(0) { $0 + $1.entries.count }
        let allSets = exportedWorkouts.flatMap { $0.entries.flatMap(\.sets) }

        return ExportSnapshot(
            exportedAt: dateFormat.string(from: now),
            appVersion: appVersion,
            seededCatalogVersion: preferences?.seededCatalogVersion ?? 0,
            counts: ExportSnapshot.Counts(
                workouts: exportedWorkouts.count,
                entries: entryCount,
                sets: allSets.count,
                completedSets: allSets.filter { $0.completedAt != nil }.count,
                gyms: exportedGyms.count,
                machines: exportedMachines.count,
                exercises: exportedExercises.count,
                equipmentModels: exportedModels.count,
                templates: exportedTemplates.count,
                presets: presets.count,
                cardioSegments: workouts.reduce(0) { $0 + $1.orderedCardio.count }),
            preferences: preferences.map(self.preferences(from:)),
            gyms: exportedGyms,
            presets: presets
                .sorted {
                    ($0.exercise?.name ?? "", $0.order, $0.id.uuidString)
                        < ($1.exercise?.name ?? "", $1.order, $1.id.uuidString)
                }
                .map {
                    ExportSnapshot.Preset(
                        id: $0.id, name: $0.name, order: $0.order,
                        exerciseID: $0.exercise?.id)
                },
            machines: exportedMachines,
            exercises: exportedExercises,
            equipmentModels: exportedModels,
            templates: exportedTemplates,
            workouts: exportedWorkouts,
            gymExerciseMemory: memories
                .sorted { ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString) }
                .map(gymMemory(from:)),
            exerciseRestOverrides: overrides
                .sorted { ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString) }
                .map(restOverride(from:)))
    }

    /// Chronological, with a total tie-break so two exports of unchanged data
    /// are byte-identical.
    private static func workoutOrder(_ lhs: Workout, _ rhs: Workout) -> Bool {
        (lhs.startedAt, lhs.id.uuidString) < (rhs.startedAt, rhs.id.uuidString)
    }

    // MARK: - Referenced catalog rows (D28)

    private struct ReferencedCatalog {
        var exerciseIDs: Set<UUID> = []
        var modelIDs: Set<UUID> = []
    }

    private func referencedCatalogIDs(
        machines: [MachineInstance],
        workouts: [ExportSnapshot.Workout],
        templates: [WorkoutTemplate],
        memories: [GymExerciseMemory],
        overrides: [ExerciseRestOverride],
        presets: [ExercisePreset],
        models: [EquipmentModel],
        userExerciseIDs: Set<UUID>
    ) -> ReferencedCatalog {
        var referenced = ReferencedCatalog()
        for machine in machines {
            if let modelID = machine.model?.id { referenced.modelIDs.insert(modelID) }
        }
        // D27: the user may attach an exercise they invented to a *seeded*
        // model, and that edge is user data — reconciliation preserves it, so
        // an export must too. Without this, correcting the only machine that
        // named the model would leave the export unable to say which station
        // the movement belongs to (codex-review, finding 2). This is not
        // following shipped catalog links: only links to user-created
        // exercises count.
        for model in models where model.isSeeded {
            if model.exerciseIDs.contains(where: userExerciseIDs.contains) {
                referenced.modelIDs.insert(model.id)
            }
        }
        for workout in workouts {
            for entry in workout.entries {
                referenced.exerciseIDs.insert(entry.exerciseID)
                if let modelID = entry.modelID { referenced.modelIDs.insert(modelID) }
            }
        }
        for item in templates.flatMap({ $0.items ?? [] }) {
            if let exerciseID = item.exercise?.id { referenced.exerciseIDs.insert(exerciseID) }
        }
        // An exercise the user has given a preset is an exercise they have
        // touched, even if they have never logged it: the preset's owner has to
        // export with it or the restored preset points at nothing (D28).
        for preset in presets {
            if let exerciseID = preset.exercise?.id { referenced.exerciseIDs.insert(exerciseID) }
        }
        for memory in memories { referenced.exerciseIDs.insert(memory.exerciseID) }
        for override in overrides { referenced.exerciseIDs.insert(override.exerciseID) }
        return referenced
    }

    // MARK: - Row mapping

    private func gym(from gym: Gym) -> ExportSnapshot.Gym {
        ExportSnapshot.Gym(
            id: gym.id, name: gym.name, city: gym.city,
            defaultUnit: gym.defaultUnit, notes: gym.notes, archived: gym.archived)
    }

    private func machine(from machine: MachineInstance) -> ExportSnapshot.Machine {
        ExportSnapshot.Machine(
            id: machine.id, label: machine.label, gymID: machine.gym?.id,
            modelID: machine.model?.id, defaultUnit: machine.defaultUnit,
            defaultPresetID: machine.defaultPresetID,
            archived: machine.archived)
    }

    private func exercise(from exercise: Exercise) -> ExportSnapshot.Exercise {
        ExportSnapshot.Exercise(
            id: exercise.id, name: exercise.name, loadType: exercise.loadType,
            equipmentTypeTags: exercise.equipmentTypeTags,
            muscleGroup: exercise.muscleGroup, isSeeded: exercise.isSeeded,
            loadTypeUserOverridden: exercise.loadTypeUserOverridden)
    }

    private func equipmentModel(from model: EquipmentModel) -> ExportSnapshot.EquipmentModel {
        ExportSnapshot.EquipmentModel(
            id: model.id, manufacturer: model.manufacturer, modelName: model.modelName,
            exerciseIDs: model.exerciseIDs, equipmentType: model.equipmentType,
            isSeeded: model.isSeeded)
    }

    private func template(
        from template: WorkoutTemplate, exerciseNamesByID: [UUID: String]
    ) -> ExportSnapshot.Template {
        let items = (template.items ?? [])
            .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
            .map { item in
                ExportSnapshot.TemplateItem(
                    id: item.id, order: item.order,
                    exerciseID: item.exercise?.id,
                    exerciseName: item.exercise.map { exerciseNamesByID[$0.id] ?? $0.name },
                    targetSets: item.targetSets, targetReps: item.targetReps,
                    targetRepsBySet: item.targetRepsBySet,
                    supersetGroupID: item.supersetGroupID)
            }
        return ExportSnapshot.Template(id: template.id, name: template.name, items: items)
    }

    private func workout(
        from workout: Workout, modelsByID: [UUID: EquipmentModel]
    ) -> ExportSnapshot.Workout {
        let entries = (workout.entries ?? [])
            .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
            .map { entry(from: $0, modelsByID: modelsByID) }
        let range = HeartRateSeriesMath.exportableRange(
            mean: workout.heartRateSeries, low: workout.heartRateSeriesLow, high: workout.heartRateSeriesHigh)
        return ExportSnapshot.Workout(
            id: workout.id,
            startedAt: dateFormat.string(from: workout.startedAt),
            finishedAt: dateFormat.optionalString(from: workout.finishedAt),
            notes: workout.notes,
            historyEditedAt: dateFormat.optionalString(from: workout.historyEditedAt),
            sourceTemplateID: workout.sourceTemplateID,
            sourceTemplateName: workout.sourceTemplateName,
            name: workout.name,
            // The workout carries a snapshot *name* but no snapshot gym id
            // (D23 puts the ids on the entry). So the id is the live link —
            // nil once the gym is deleted — while the name is what the workout
            // was logged under. The CSV's gym columns come from the entry,
            // where both are snapshotted together.
            gymID: workout.gym?.id,
            gymName: workout.snapshotGymName,
            entries: entries,
            // D44: absent when no sensor ran. Nothing is derived here — these
            // are the values captured at finish, exactly as History reads them.
            averageHeartRate: workout.averageHeartRate,
            maxHeartRate: workout.maxHeartRate,
            activeEnergyKilocalories: workout.activeEnergyKilocalories,
            zoneSeconds: workout.zoneSeconds.isEmpty ? nil : workout.zoneSeconds,
            zonesFromEstimatedMax: workout.zonesFromEstimatedMax,
            heartRateSeries: workout.heartRateSeries.isEmpty ? nil : workout.heartRateSeries,
            heartRateSeriesIntervalSeconds: workout.heartRateSeries.isEmpty ? nil : workout.heartRateSeriesIntervalSeconds,
            // v9: the range pair is only meaningful beside the mean it
            // brackets, so it travels as a pair matching the mean's length or
            // not at all (codex-review 01). A lone or mismatched array in a
            // backup would be a range of nothing.
            heartRateSeriesLow: range?.low,
            heartRateSeriesHigh: range?.high,
            basalEnergyKilocalories: workout.basalEnergyKilocalories,
            cardioSegments: workout.orderedCardio.isEmpty ? nil : workout.orderedCardio.map(cardio(from:)),
            sensorCheckpoint: (workout.sensorSampleRows ?? []).isEmpty && workout.sensorActiveEnergyCheckpoint == nil && workout.sensorBasalEnergyCheckpoint == nil ? nil : .init(
                samples: workout.checkpointSamples.map { .init(id: $0.id, bpm: $0.bpm, date: dateFormat.string(from: $0.date), source: $0.source) },
                maximumHeartRateBpm: workout.sensorMaxHeartRateBpm,
                maximumHeartRateEstimated: workout.sensorMaxHeartRateEstimated,
                activeEnergyKilocalories: workout.sensorActiveEnergyCheckpoint,
                basalEnergyKilocalories: workout.sensorBasalEnergyCheckpoint))
    }

    private func cardio(from segment: CardioSegment) -> ExportSnapshot.Cardio {
        ExportSnapshot.Cardio(
            id: segment.id, order: segment.order, activity: segment.activityRawValue,
            startedAt: dateFormat.string(from: segment.startedAt), endedAt: dateFormat.optionalString(from: segment.endedAt),
            activeStartedAt: dateFormat.optionalString(from: segment.activeStartedAt),
            accumulatedActiveSeconds: segment.accumulatedActiveSeconds,
            lastCheckpointAt: dateFormat.string(from: segment.lastCheckpointAt), displayUnit: segment.displayUnitRawValue,
            automaticDistanceMeters: segment.automaticDistanceMeters, distanceSource: segment.distanceSourceRawValue,
            manualDistanceValue: segment.manualDistanceValue, manualDistanceUnit: segment.manualDistanceUnitRawValue,
            averageHeartRate: segment.averageHeartRate, maxHeartRate: segment.maxHeartRate,
            heartRateTotal: segment.heartRateTotal, heartRateCount: segment.heartRateCount,
            lastHeartRateSampleID: segment.lastHeartRateSampleID,
            activeEnergyKilocalories: segment.activeEnergyKilocalories, basalEnergyKilocalories: segment.basalEnergyKilocalories,
            intervals: segment.intervals.map { .init(start: dateFormat.string(from: $0.start), end: dateFormat.string(from: $0.end)) },
            distanceSpans: segment.distanceSpans.map { span in
                .init(start: dateFormat.string(from: span.start), readings: span.readings,
                      updatedAt: span.updatedAt.mapValues { dateFormat.string(from: $0) },
                      selectedSource: span.selectedSourceRawValue)
            },
            route: segment.route.map { .init(id: $0.id, latitude: $0.latitude, longitude: $0.longitude,
                date: dateFormat.string(from: $0.date), accuracy: $0.accuracy, portion: $0.portion) })
    }

    private func entry(
        from entry: ExerciseEntry, modelsByID: [UUID: EquipmentModel]
    ) -> ExportSnapshot.Entry {
        let sets = (entry.sets ?? [])
            .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
            .map(setRow(from:))
        let context = self.context(of: entry)
        return ExportSnapshot.Entry(
            id: entry.id,
            order: entry.order,
            snapshotCapturedAt: dateFormat.optionalString(from: entry.snapshotCapturedAt),
            exerciseID: context.exerciseID,
            exerciseName: context.exerciseName,
            loadType: context.loadType,
            freeWeightTag: context.freeWeightTag,
            supersetGroupID: entry.supersetGroupID,
            machineID: context.machineID,
            machineLabel: context.machineLabel,
            modelID: context.modelID,
            modelDisplayName: context.modelDisplayName,
            // The one live lookup on either path: neither the snapshot nor the
            // entry stores a manufacturer on its own. Absent when the model no
            // longer exists — never invented.
            modelManufacturer: context.modelID.flatMap { modelsByID[$0]?.manufacturer },
            gymID: context.gymID,
            gymName: context.gymName,
            presetID: context.presetID,
            presetName: context.presetName,
            reclassifiedAt: dateFormat.optionalString(from: entry.reclassifiedAt),
            reclassifiedFromExerciseName: entry.reclassifiedFromExerciseName,
            sets: sets)
    }

    /// Equipment context for one entry.
    ///
    /// Frozen entries (D19: a set has completed) read their D23 snapshot, which
    /// is the whole point of having one. Draft entries have no snapshot yet —
    /// `addEntry` fills in only the provisional exercise fields and
    /// `chooseEquipment` writes the machine to the live relationship — so
    /// reading snapshot fields there would export "no machine, no gym" for an
    /// entry the user just assigned to a machine at a gym (codex-review,
    /// finding 1). For a draft, live *is* the truth.
    private struct EntryContext {
        var exerciseID: UUID
        var exerciseName: String
        var loadType: LoadType
        var freeWeightTag: EquipmentTag?
        var machineID: UUID?
        var machineLabel: String?
        var modelID: UUID?
        var modelDisplayName: String?
        var gymID: UUID?
        var gymName: String?
        var presetID: UUID?
        var presetName: String?
    }

    private func context(of entry: ExerciseEntry) -> EntryContext {
        guard entry.snapshotCapturedAt == nil else {
            return EntryContext(
                exerciseID: entry.snapshotExerciseID,
                exerciseName: entry.snapshotExerciseName,
                loadType: entry.snapshotLoadType,
                freeWeightTag: entry.snapshotFreeWeightTag,
                machineID: entry.snapshotMachineID,
                machineLabel: entry.snapshotMachineLabel,
                modelID: entry.snapshotModelID,
                modelDisplayName: entry.snapshotModelName,
                gymID: entry.snapshotGymID,
                gymName: entry.snapshotGymName,
                presetID: entry.snapshotPresetID,
                presetName: entry.snapshotPresetName)
        }
        let machine = entry.machine
        return EntryContext(
            exerciseID: entry.exercise?.id ?? entry.snapshotExerciseID,
            exerciseName: entry.exercise?.name ?? entry.snapshotExerciseName,
            loadType: entry.exercise?.loadType ?? entry.snapshotLoadType,
            freeWeightTag: entry.freeWeightTag,
            machineID: machine?.id,
            machineLabel: machine?.label,
            modelID: machine?.model?.id,
            modelDisplayName: machine?.model?.displayName,
            gymID: entry.workout?.gym?.id,
            gymName: entry.workout?.gym?.name,
            presetID: entry.preset?.id,
            presetName: entry.preset?.name)
    }

    private func setRow(from set: SetRecord) -> ExportSnapshot.SetRow {
        ExportSnapshot.SetRow(
            id: set.id, order: set.order, type: set.type, reps: set.reps,
            weight: set.weightValue, unit: set.weightUnit, weightKg: set.normalizedKg,
            barWeight: set.barWeightValue,
            // New rows persist the full D25 triple. The fallback keeps exports
            // faithful for the brief pre-review schema, whose bar value shared
            // the row unit but did not yet persist its normalization.
            barWeightKg: set.barNormalizedKg ?? set.resolvedBarWeight?.normalizedKg,
            completedAt: dateFormat.optionalString(from: set.completedAt))
    }

    private func gymMemory(from memory: GymExerciseMemory) -> ExportSnapshot.GymMemory {
        ExportSnapshot.GymMemory(
            id: memory.id, gymID: memory.gymID, exerciseID: memory.exerciseID,
            machineID: memory.machineID,
            updatedAt: dateFormat.string(from: memory.updatedAt))
    }

    private func restOverride(from override: ExerciseRestOverride) -> ExportSnapshot.RestOverride {
        ExportSnapshot.RestOverride(
            id: override.id,
            restMode: override.restMode,
            heartRateThresholdBpm: override.heartRateThresholdBpm,
            heartRateCapSeconds: override.heartRateCapSeconds,
            exerciseID: override.exerciseID,
            workingRestSeconds: override.workingRestSeconds,
            warmupRestSeconds: override.warmupRestSeconds,
            updatedAt: dateFormat.string(from: override.updatedAt))
    }

    private func preferences(from preferences: AppPreferences) -> ExportSnapshot.Preferences {
        ExportSnapshot.Preferences(
            unitPreference: preferences.unitPreference,
            driftPromptSuppressed: preferences.driftPromptSuppressed,
            globalWorkingRestSeconds: preferences.globalWorkingRestSeconds,
            globalWarmupRestSeconds: preferences.globalWarmupRestSeconds,
            seededCatalogVersion: preferences.seededCatalogVersion,
            notificationPermissionRequested: preferences.notificationPermissionRequested,
            selectedGymID: preferences.selectedGymID,
            measuredMaxHeartRate: preferences.measuredMaxHeartRate,
            birthDate: dateFormat.optionalString(from: preferences.birthDate),
            updatedAt: dateFormat.string(from: preferences.updatedAt),
            dumbbellHistoryMovedSets: preferences.dumbbellHistoryMovedSets,
            dumbbellHistoryMovedAt: dateFormat.optionalString(from: preferences.dumbbellHistoryMovedAt),
            dumbbellHistoryCheckedAt: dateFormat.optionalString(from: preferences.dumbbellHistoryCheckedAt))
    }
}
