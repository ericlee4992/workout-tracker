import Foundation
import SwiftData
import Testing
import UIKit
import ImageIO
@testable import WorkoutTracker

@MainActor
struct AIGymTests {
    private func context() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
    @Test func exportWireFixturesForLiveSmoke() throws {
        let dir = URL(fileURLWithPath: "/tmp/wt-ai-wire-fixtures")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let exercises = try SeedCatalog.bundled().exercises
        let all = exercises.map { "\($0.id.uuidString) | \($0.name)" }.joined(separator: "\n")
        let photoRequest = try TerraClient(key: "fixture-only").request(instructions: EquipmentIdentification.instructions, input: all, schema: EquipmentIdentification.schema, name: "equipment_identity", jpeg: Data())
        try photoRequest.httpBody!.write(to: dir.appendingPathComponent("equipment.json"))
        let eligible = exercises.filter { $0.equipmentTypeTags.contains(.dumbbell) }.map {
            RoutineExerciseOption(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup ?? "", equipment: .dumbbell)
        }
        let input = AIRoutineRequest(goals: "Build strength and general endurance", experience: "Beginner", days: 3, minutes: 45, exercises: eligible, cardioActivities: [.outdoorWalk])
        let routineRequest = try TerraClient(key: "fixture-only").request(instructions: AIRoutine.instructions, input: AISchema.text(input), schema: AIRoutine.schema, name: "weekly_routine")
        try routineRequest.httpBody!.write(to: dir.appendingPathComponent("routine.json"))
    }
    @Test func uploadedPhotoIsBoundedAndHasNoLocationMetadata() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1800)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))
        }
        let data = try #require(EquipmentPhoto.jpeg(image))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let info = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        #expect(info[kCGImagePropertyGPSDictionary as String] == nil)
        #expect((info[kCGImagePropertyPixelWidth as String] as? Int ?? 0) <= 1568)
        #expect((info[kCGImagePropertyPixelHeight as String] as? Int ?? 0) <= 1568)
    }
    private final class BundleMarker {}
    @Test func installedCardioSchemaMigratesWithoutLosingHistoryOrTemplates() throws {
        let source = try #require(Bundle(for: BundleMarker.self).url(forResource: "PostCardio", withExtension: "store"))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ai-migration-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("copy.store")
        try FileManager.default.copyItem(at: source, to: url)
        let container = try WorkoutTrackerStore.makeContainer(url: url)
        let context = ModelContext(container)
        let machine = try #require(context.fetch(FetchDescriptor<MachineInstance>()).first)
        #expect(machine.model == nil && machine.recognizedExerciseIDs.isEmpty)
        let template = try #require(context.fetch(FetchDescriptor<WorkoutTemplate>()).first)
        let items = WorkoutTemplateService.orderedItems(of: template)
        #expect(items.map(\.targetRepsBySet) == [[10,8],[12]])
        #expect(items[0].supersetGroupID != nil && items[0].supersetGroupID == items[1].supersetGroupID)
        #expect(template.plannedCardio.isEmpty && items.allSatisfy { $0.plannedRestSeconds == nil })
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 2)
        let finished = try #require(workouts.first { $0.finishedAt != nil })
        #expect(finished.completedSets.first?.weightValue == 70)
        #expect(finished.completedSets.first?.reps == 8)
        let cardio = try #require(finished.orderedCardio.first)
        #expect(cardio.manualDistanceValue == 1.2 && cardio.manualDistanceUnitRawValue == "mi")
        #expect(cardio.activeDuration() == 600)
        #expect(workouts.first { $0.finishedAt == nil }?.unfinishedCardio?.isRunning == false)
        let started = try WorkoutTemplateService(context: context).start(template, at: machine.gym)
        #expect(WorkoutSession.orderedEntries(of: started).map { WorkoutSession.orderedSets(of: $0).count } == [2,1])
    }
    @Test func terraRequestDoesNotStoreOrExposeCredentialsInBody() throws {
        let request = try TerraClient(key: "test-only-secret").request(instructions: "Identify", input: "Catalog", schema: EquipmentIdentification.schema, name: "equipment", jpeg: Data([1, 2]))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only-secret")
        let data = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["model"] as? String == "gpt-5.6-terra")
        #expect(json["store"] as? Bool == false)
        #expect(!String(decoding: data, as: UTF8.self).contains("test-only-secret"))
        #expect(request.timeoutInterval == 60)
    }
    @Test func incompleteAndRefusedResponsesCannotProduceProposals() throws {
        for response: [String: Any] in [
            ["status": "incomplete", "output": []],
            ["status": "completed", "output": [["content": [["type": "refusal", "refusal": "no"]]]]],
            ["status": "completed", "output": []]
        ] {
            let data = try JSONSerialization.data(withJSONObject: response)
            #expect(throws: (any Error).self) { try TerraClient.output(from: data) }
        }
        let valid = try JSONSerialization.data(withJSONObject: ["status": "completed", "output": [["content": [["type": "output_text", "text": "{}"]]]]])
        #expect(try TerraClient.output(from: valid) == Data("{}".utf8))
    }
    @Test func identityRejectsUnknownExercisesAndDropsUnsupportedModelClaims() throws {
        let id = UUID()
        let guess = EquipmentIdentification(identity: "specific", label: "Chest press", manufacturer: "Brand", modelName: "Model", visibleText: "", exerciseIDs: [id])
        let generic = try guess.validated(allowed: [id])
        #expect(generic.identity == "generic" && generic.modelName.isEmpty)
        #expect(throws: (any Error).self) { try guess.validated(allowed: []) }
    }
    @Test func genericMachinesResolveAndExportWithoutInventingAModel() throws {
        let context = try context()
        let exercise = Exercise(name: "Chest press", isSeeded: true)
        let gym = Gym(name: "Gym")
        let first = MachineInstance(label: "Press 1", gym: gym)
        let second = MachineInstance(label: "Press 2", gym: gym)
        first.recognizedExerciseIDs = [exercise.id]; second.recognizedExerciseIDs = [exercise.id]
        context.insert(exercise); context.insert(gym); context.insert(first); context.insert(second); try context.save()
        #expect(try WorkoutSession(context: context).exercisesFor(machine: first).map(\.id) == [exercise.id])
        #expect(first.id != second.id && first.model == nil && second.model == nil)
        let exported = try ExportCollector().snapshot(from: context)
        #expect(exported.equipmentModels.isEmpty)
        #expect(exported.exercises.map(\.id).contains(exercise.id))
        #expect(exported.machines.allSatisfy { $0.modelID == nil && $0.recognizedExerciseIDs == [exercise.id] })
    }
    @Test func mixedTemplateStartsWithTargetsButNoPerformedCardioOrWeights() throws {
        let context = try context(); let exercise = Exercise(name: "Press"); context.insert(exercise)
        let service = WorkoutTemplateService(context: context)
        let template = try service.create(name: "Mixed", items: [.init(exercise: exercise, targetRepsBySet: [10,10], plannedRestSeconds: 75)], cardio: [.init(activity: .outdoorRun, minutes: 20)])
        let workout = try service.start(template, at: nil)
        #expect(workout.orderedCardio.isEmpty)
        #expect(workout.plannedCardio.count == 1 && workout.plannedCardio[0].segmentID == nil)
        let entry = try #require(workout.entries?.first)
        #expect(entry.plannedRestSeconds == 75 && entry.plannedRepsBySet == [10,10])
        #expect(entry.sets?.allSatisfy { $0.weightValue == nil && $0.reps == nil && $0.completedAt == nil } == true)
        template.plannedCardio = []
        #expect(workout.plannedCardio.count == 1)
        #expect(try WorkoutSession(context: context).finish(workout) == .discardedEmpty)
    }
    @Test func cardioOnlyTemplateCanBeCreatedEditedStartedAndExported() throws {
        let context = try context(); let service = WorkoutTemplateService(context: context)
        let target = PlannedCardio(activity: .indoorCycle, minutes: 25, distance: 8, unit: .km)
        let template = try service.create(name: "Bike", items: [], cardio: [target])
        try service.update(template, name: "Bike day", items: [], cardio: [target])
        let workout = try service.start(template, at: nil)
        #expect(workout.entries?.isEmpty != false && workout.orderedCardio.isEmpty)
        #expect(workout.sensorConfiguration == .idle)
        let export = try ExportCollector().snapshot(from: context)
        #expect(export.templates.first?.plannedCardio == [target])
        #expect(export.workouts.first?.cardioSegments == nil)
        #expect(export.workouts.first?.plannedCardio?.first?.minutes == 25)
        #expect(try JSONDecoder().decode(ExportSnapshot.self, from: JSONEncoder().encode(export)) == export)
    }
    @Test(arguments: TemplateDriftResolution.allCases) func driftPreservesCardioAndRestTargets(_ resolution: TemplateDriftResolution) throws {
        let context = try context(); let exercise = Exercise(name: "Press"); context.insert(exercise)
        let service = WorkoutTemplateService(context: context)
        let template = try service.create(name: "Mixed", items: [.init(exercise: exercise, targetRepsBySet: [10], plannedRestSeconds: 75)], cardio: [.init(activity: .outdoorWalk, minutes: 15)])
        let workout = try service.start(template, at: nil)
        let set = try #require(workout.entries?.first?.sets?.first)
        let session = WorkoutSession(context: context)
        try session.commitWeight("20", for: set); try session.commitReps("8", for: set); try session.toggleCompletion(of: set)
        try TemplateDriftService(context: context).apply(resolution, workout: workout, to: template)
        #expect(template.plannedCardio.first?.minutes == 15)
        #expect(WorkoutTemplateService.orderedItems(of: template).first?.plannedRestSeconds == 75)
    }
    @Test func routineRejectsUnknownOrUnavailableActivitiesAndExcessiveVolume() throws {
        let id = UUID()
        let request = AIRoutineRequest(goals: "Fitness", experience: "Beginner", days: 1, minutes: 45,
            exercises: [.init(id: id, name: "Press", muscleGroup: "Chest", equipment: nil)], cardioActivities: [.outdoorWalk])
        let good = AIRoutine(sessions: [.init(name: "Day 1", strength: [.init(exerciseID: id, sets: 3, reps: 10, restSeconds: 60)], cardio: [.init(activity: .outdoorWalk, minutes: 15)])])
        #expect(try good.validated(for: request) == good)
        var wrong = good; wrong.sessions[0].strength[0].exerciseID = UUID()
        #expect(throws: (any Error).self) { try wrong.validated(for: request) }
        wrong = good; wrong.sessions[0].cardio[0].activity = .indoorCycle
        #expect(throws: (any Error).self) { try wrong.validated(for: request) }
        wrong = good; wrong.sessions[0].strength[0].sets = 100
        #expect(throws: (any Error).self) { try wrong.validated(for: request) }
    }
    @Test func routineSaveIsAtomicWhenLaterExerciseDisappears() throws {
        let context = try context(); let exercise = Exercise(name: "Press"); context.insert(exercise); try context.save()
        let missing = UUID()
        let request = AIRoutineRequest(goals: "Fitness", experience: "Beginner", days: 2, minutes: 45,
            exercises: [.init(id: exercise.id, name: "Press", muscleGroup: "Chest", equipment: nil), .init(id: missing, name: "Gone", muscleGroup: "", equipment: nil)], cardioActivities: [])
        let routine = AIRoutine(sessions: [exercise.id, missing].enumerated().map { index,id in
            .init(name: "Day \(index)", strength: [.init(exerciseID: id, sets: 3, reps: 10, restSeconds: 60)], cardio: [])
        })
        #expect(throws: (any Error).self) { try AIRoutinePersistence.save(routine, request: request, gymID: nil, extras: [], in: context.container) }
        #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 0)
    }
    @Test func genericMachineHistoryDoesNotPrefillAnotherGenericMachine() throws {
        let context = try context(); let exercise = Exercise(name: "Press")
        let gym = Gym(name: "Gym"); let a = MachineInstance(label: "A", gym: gym); let b = MachineInstance(label: "B", gym: gym)
        a.recognizedExerciseIDs = [exercise.id]; b.recognizedExerciseIDs = [exercise.id]
        for object: any PersistentModel in [exercise,gym,a,b] { context.insert(object) }
        let session = WorkoutSession(context: context)
        let old = try session.startWorkout(at: gym)
        let entry = try session.addEntry(for: exercise, to: old, machine: a)
        let set = try #require(entry.sets?.first)
        try session.commitWeight("50", for: set); try session.commitReps("10", for: set); try session.toggleCompletion(of: set)
        _ = try session.finish(old)
        let next = try session.startWorkout(at: gym)
        let other = try session.addEntry(for: exercise, to: next, machine: b)
        let blank = try #require(other.sets?.first)
        #expect(try PerformanceHistory(context: context).prefill(for: blank) == nil)
        let layers = try PerformanceHistory(context: context).layers(for: other)
        #expect(layers.first { $0.kind == .sameModelElsewhere }?.snapshot == nil)
    }

    @Test func equipmentChecklistDoesNotInventSpecialtyStations() {
        let ghd = Exercise(name: "Glute-Ham Raise", equipmentTypeTags: [.bodyweight], isSeeded: true)
        let curl = Exercise(name: "Dumbbell Curl", equipmentTypeTags: [.dumbbell], isSeeded: true)
        let bench = Exercise(name: "Dumbbell Bench Press", equipmentTypeTags: [.dumbbell], isSeeded: true)
        let picks = RoutineAvailability.exercises([ghd,curl,bench], machines: [], extras: [.dumbbells])
        #expect(picks.map(\.id) == [curl.id])
    }
}
