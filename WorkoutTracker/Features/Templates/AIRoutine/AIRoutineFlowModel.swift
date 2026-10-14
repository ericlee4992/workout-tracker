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

    // The request. Every change the tester makes is recorded (ticket 05, codex-review-05d F3/F4): a training profile
    // prefills only an untouched form, and a measurement keeps its stored value and unit only if it was prefilled and
    // never changed — decided by what happened, not by comparing numbers.
    var goals = "" { didSet { noteEdit() } }
    var experience = "Beginner" { didSet { noteEdit() } }
    var days = 3 { didSet { noteEdit() } }
    var minutes = 45 { didSet { noteEdit() } }
    var heightCm: Double? { didSet { noteEdit(); if !prefilling { heightEdited = true } } }
    var weightKg: Double? { didSet { noteEdit(); if !prefilling { weightEdited = true } } }
    /// The tester has changed the form (typing then clearing counts).
    private(set) var edited = false
    /// The training profile the form was filled in from; nil when it was not prefilled.
    private(set) var prefilledFrom: TrainingProfile?
    /// "Save to my training profile" failed for the last request; the week still arrives (Your week says so).
    var profileSaveFailed = false
    private var prefilling = false
    private var heightEdited = false
    private var weightEdited = false

    private func noteEdit() { if !prefilling { edited = true } }
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
    /// The session the server refused on the last generation, if it is still current (the sheet signs it out).
    private(set) var refusedSession: String?
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
    /// `client` is the signed-in session's (nil signed out: the request fails with "Sign in to use AI."); `session`
    /// binds the reply to that session — one that ended or was replaced meanwhile drops it.
    func generate(options: [RoutineExerciseOption], gymName: String?, permitted: Bool, client: AIServerClient?,
                  session: AISessionBinding = .unbound) {
        guard permitted, hasGoals, !options.isEmpty || !cardio.isEmpty else { return }
        cancelTasks()
        let request = AIRoutineRequest(goals: goals, experience: experience, days: days, minutes: minutes,
                                       heightCm: heightCm, weightKg: weightKg, exercises: options,
                                       cardioActivities: CardioActivity.allCases.filter { cardio.contains($0) })
        sentRequest = request
        routine = nil
        error = nil
        refusedSession = nil
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
                let result = try await Self.requestRoutine(request, client: client)
                let valid = try result.validated(for: request)
                guard let self, !Task.isCancelled, self.token == id, session.isCurrent() else { return }
                self.stageTask?.cancel()
                self.progress = 1
                self.routine = valid
                self.forward = true
                self.step = .preview
            } catch {
                guard let self, !Task.isCancelled, self.token == id, session.isCurrent() else { return }
                self.stageTask?.cancel()
                self.error = error.localizedDescription
                if case AIServerError.signedOut = error { self.refusedSession = session.token }
                self.forward = true
                self.step = .error
            }
        }
    }

    /// Ticket 05: Ask AI opens filled in from the signed-in tester's training profile — once, on the Goals step, and
    /// only before the tester's first change (a profile that loads late never overwrites what they did).
    @discardableResult
    func prefill(from training: TrainingProfile) -> Bool {
        guard !edited, prefilledFrom == nil, step == .goals else { return false }
        prefilling = true
        defer { prefilling = false }
        goals = training.goals
        experience = training.experience
        days = training.days
        minutes = training.minutes
        heightCm = training.height?.centimetres
        weightKg = training.weight?.kilograms
        prefilledFrom = training
        heightEdited = false
        weightEdited = false
        return true
    }

    /// The training profile this form describes (`TrainingProfile.fromAskAI`): a measurement prefilled and never
    /// changed is the stored one, exactly; any other is as typed.
    func trainingProfile(usCustomary: Bool) -> TrainingProfile {
        .fromAskAI(goals: goals, experience: experience, days: days, minutes: minutes, heightCm: heightCm,
                   weightKg: weightKg,
                   keptHeight: prefilledFrom.flatMap { heightEdited ? nil : .some($0.height) },
                   keptWeight: prefilledFrom.flatMap { weightEdited ? nil : .some($0.weight) },
                   usCustomary: usCustomary)
    }

    /// Returns once the generation in flight (if any) has landed or been dropped — for tests that order a reply
    /// against a session change.
    func generationFinished() async { await task?.value }

    /// The server call (or the UI-test fixture's stand-in).
    private static func requestRoutine(_ request: AIRoutineRequest, client: AIServerClient?) async throws -> AIRoutine {
        if TerraAccess.fixture {
            try await TerraAccess.fixtureDelay()
            let full = WorkoutTrackerStore.fixtureIsEnabled("-uiTestTerraFullRoutine")
            return AIRoutine(sessions: (1...request.days).map { day in
                AIRoutineDay(name: "Day \(day) — Fitness", strength: request.exercises.prefix(full ? 6 : 1).map {
                    AIRoutineStrength(exerciseID: $0.id, sets: 3, reps: 10, restSeconds: 60)
                }, cardio: request.cardioActivities.first.map { [AIRoutineCardio(activity: $0, minutes: 15)] } ?? [])
            })
        }
        guard let client else { throw AIServerError.signedOut }
        let data = try await client.complete(.routineWeek, encodable: request)
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
