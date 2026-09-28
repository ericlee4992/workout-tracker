import Foundation
import SwiftData

/// The Ask AI flow's state (Floodlight ticket 10): goals → equipment → generating (or error) →
/// your week (→ the day editor) → saved. The views read and edit it; the request, the Terra call,
/// validation and the atomic save are the same as the old single-form sheet's.
@MainActor @Observable
final class AIRoutineFlowModel {
    enum Step: Int, Comparable {
        case goals, equipment, generating, error, preview, saved
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
        /// The step indicator's position: 0 Goals, 1 Equipment, 2 Your week.
        var indicator: Int? {
            switch self {
            case .goals: 0
            case .equipment: 1
            case .generating, .error, .preview: 2
            case .saved: nil
            }
        }
    }

    static let experiences = ["Beginner", "Intermediate", "Experienced"]

    var step: Step = .goals
    /// Forward steps slide in from the trailing edge, back steps from the leading edge.
    var forward = true

    // The request
    var goals = ""
    var experience = "Beginner"
    var days = 3
    var minutes = 45
    var heightCm: Double?
    var weightKg: Double?
    var extras: Set<RoutineEquipment> = []
    var cardio: Set<CardioActivity> = []

    // The result
    var routine: AIRoutine?
    private(set) var sentRequest: AIRoutineRequest?
    /// A generated week not yet saved (leaving it asks first — ticket 10, decision 3).
    var hasUnsavedWeek: Bool { routine != nil && step != .saved }
    private(set) var savedTemplateIDs: [UUID] = []

    // Generating
    private(set) var progress: Double = 0
    private(set) var progressText = ""
    /// The generation's failure (the error step) or a save's (Your week).
    var error: String?
    /// Goals step: the request's limits, checked at Next.
    var inputError: String?
    private(set) var saving = false

    private var task: Task<Void, Never>?
    private var stageTask: Task<Void, Never>?
    private var token: UUID?

    var hasGoals: Bool { !goals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: Steps

    /// Goals → Equipment, once the request's limits hold.
    func next() {
        guard step == .goals, hasGoals else { return }
        guard goals.count <= 1000,
              heightCm.map({ $0.isFinite && (50...250).contains($0) }) ?? true,
              weightKg.map({ $0.isFinite && (20...400).contains($0) }) ?? true else {
            inputError = "Use a goal under 1,000 characters and valid optional height/weight."
            return
        }
        inputError = nil
        forward = true
        step = .equipment
    }

    /// Back one step. From Your week or the error step this returns to Equipment and drops the
    /// week (the caller asks first when there is one).
    func back() {
        forward = false
        switch step {
        case .equipment: step = .goals
        case .generating: cancelGeneration()
        case .error, .preview:
            discardWeek()
            step = .equipment
        default: break
        }
    }

    /// "Change preferences": drop the week and start again from Goals, inputs kept.
    func changePreferences() {
        forward = false
        discardWeek()
        step = .goals
    }

    private func discardWeek() {
        routine = nil
        sentRequest = nil
        error = nil
    }

    // MARK: Generate

    /// Sends the request (options = what the AI may use at this gym). The wait shows timed stages
    /// (decision 1); the week appears as soon as the reply arrives.
    func generate(options: [RoutineExerciseOption], gymName: String?, permitted: Bool) {
        guard permitted, hasGoals, !options.isEmpty || !cardio.isEmpty else { return }
        cancelTasks()
        let request = AIRoutineRequest(goals: goals, experience: experience, days: days, minutes: minutes,
                                       heightCm: heightCm, weightKg: weightKg, exercises: options,
                                       cardioActivities: CardioActivity.allCases.filter { cardio.contains($0) })
        sentRequest = request
        routine = nil
        error = nil
        forward = true
        step = .generating
        let first = AIRoutineStages.stage(at: 0, gymName: gymName)
        progress = first.progress
        progressText = first.text
        let id = UUID()
        token = id
        stageTask = Task { [weak self] in
            var elapsed: TimeInterval = 0
            for stage in AIRoutineStages.stages(gymName: gymName).dropFirst() {
                try? await Task.sleep(for: .seconds(stage.at - elapsed))
                elapsed = stage.at
                guard let self, !Task.isCancelled, self.token == id, self.step == .generating else { return }
                self.progress = stage.progress
                self.progressText = stage.text
            }
        }
        task = Task { [weak self] in
            do {
                let result = try await Self.requestRoutine(request)
                let valid = try result.validated(for: request)
                guard let self, !Task.isCancelled, self.token == id else { return }
                self.stageTask?.cancel()
                self.progress = 1
                self.routine = valid
                self.forward = true
                self.step = .preview
            } catch {
                guard let self, !Task.isCancelled, self.token == id else { return }
                self.stageTask?.cancel()
                self.error = error.localizedDescription
                self.forward = true
                self.step = .error
            }
        }
    }

    /// The Terra call (or the UI-test fixture's stand-in).
    private static func requestRoutine(_ request: AIRoutineRequest) async throws -> AIRoutine {
        if TerraAccess.fixture {
            try await TerraAccess.fixtureDelay()
            let full = WorkoutTrackerStore.fixtureIsEnabled("-uiTestTerraFullRoutine")
            return AIRoutine(sessions: (1...request.days).map { day in
                AIRoutineDay(name: "Day \(day) — Fitness", strength: request.exercises.prefix(full ? 6 : 1).map {
                    AIRoutineStrength(exerciseID: $0.id, sets: 3, reps: 10, restSeconds: 60)
                }, cardio: request.cardioActivities.first.map { [AIRoutineCardio(activity: $0, minutes: 15)] } ?? [])
            })
        }
        guard let client = TerraAccess.client else { throw TerraError.message("Add an OpenAI key in Settings.") }
        let data = try await client.complete(instructions: AIRoutine.instructions, input: AISchema.text(request),
                                             schema: AIRoutine.schema, name: "weekly_routine")
        return try JSONDecoder().decode(AIRoutine.self, from: data)
    }

    /// Back to preferences / Cancel while generating: the reply, if it still comes, is dropped.
    func cancelGeneration() {
        cancelTasks()
        if step == .generating {
            forward = false
            step = .equipment
        }
        progress = 0
    }

    func cancelTasks() {
        task?.cancel()
        stageTask?.cancel()
        task = nil
        stageTask = nil
        token = nil
    }

    // MARK: Edit

    func update(_ day: AIRoutineDay) {
        guard let index = routine?.sessions.firstIndex(where: { $0.id == day.id }) else { return }
        routine?.sessions[index] = day
    }

    func day(_ id: UUID) -> AIRoutineDay? { routine?.sessions.first { $0.id == id } }

    // MARK: Save

    /// Saves every session as a template at once (atomic), then the Saved step. Twice-tapped Save
    /// saves once (`saving`, then the step changes).
    func save(gymID: UUID?, container: ModelContainer) {
        guard !saving, step == .preview, let routine, let request = sentRequest else { return }
        saving = true
        defer { saving = false }
        do {
            savedTemplateIDs = try AIRoutinePersistence.save(routine, request: request, gymID: gymID, extras: extras,
                                                             in: container)
            error = nil
            forward = true
            step = .saved
        } catch {
            self.error = error.localizedDescription
        }
    }
}
