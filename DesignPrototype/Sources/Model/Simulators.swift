import Foundation

// Simulated sensors and services. No HealthKit, GPS, camera, network or AI: the
// Store's 1 Hz tick reads these, and the AI / scan delays run as cancellable tasks.

// MARK: - Heart rate

enum HRScript {
    /// The real app's test script (HeartRateMonitor.swift). The prototype holds each value
    /// for `secondsPerStep` and eases toward it, so a reading never jumps 92 → 153 → 99.
    static let sequence = [92, 104, 118, 131, 142, 148, 151, 146, 138, 129, 121, 114, 108, 103, 99,
                           112, 127, 139, 147, 153, 149, 141, 132, 123, 115, 109, 104, 100]
    /// Index of 127, so a fresh session reads near 128 bpm.
    static let startStep = 16
    /// One script value every 6 s (a 168 s effort/recovery cycle).
    static let secondsPerStep: TimeInterval = 6
    /// Exponential easing time constant for the displayed reading.
    static let smoothingSeconds: TimeInterval = 6

    /// Eases `current` toward `target` over `dt` seconds.
    static func eased(_ current: Double, toward target: Double, dt: TimeInterval) -> Double {
        current + (target - current) * (1 - exp(-max(0, dt) / smoothingSeconds))
    }

    static func bpm(step: Int) -> Int {
        let n = sequence.count
        return sequence[((step % n) + n) % n]
    }
}

// MARK: - Cardio

enum CardioSimulator {
    /// Outdoor activities wait this long for GPS before recording distance.
    static let gpsWaitSeconds: TimeInterval = 6
    /// A route point is recorded every 10 s (outdoor only; never shown live).
    static let routeInterval: TimeInterval = 10
    /// Where a live outdoor route starts (Seoul Forest).
    static let origin = (latitude: 37.5443, longitude: 127.0374)

    /// Simulated speed in m/s after `t` active seconds. Runs wander between
    /// 5:10 and 5:40 /km (3.23–2.94 m/s).
    static func speed(for activity: CardioActivity, at t: TimeInterval) -> Double {
        let wobble = 0.6 * sin(t / 37) + 0.4 * sin(t / 11)  // −1…1
        switch activity {
        case .indoorRun, .outdoorRun: return 3.085 + 0.145 * wobble
        case .indoorWalk, .outdoorWalk: return 1.45 + 0.08 * wobble
        case .indoorCycle, .outdoorCycle: return 8.2 + 0.7 * wobble
        case .elliptical: return 2.4 + 0.2 * wobble
        case .rowing: return 3.9 + 0.2 * wobble
        case .stairStepper: return 0.7 + 0.05 * wobble
        }
    }

    /// Active calories per second at a heart rate (the prototype's stand-in for HealthKit).
    static func caloriesPerSecond(bpm: Int?) -> Double {
        guard let bpm else { return 0 }
        return Double(bpm) / 1500
    }

    /// The next live route point: an ellipse around `origin`, one lap ≈ 3.4 km.
    static func routePoint(at t: TimeInterval, portion: Int) -> RoutePoint {
        let lap = 3400 / 3.085
        let a = 2 * Double.pi * t / lap
        return RoutePoint(latitude: origin.latitude + 0.0045 * sin(a), longitude: origin.longitude + 0.0065 * cos(a),
                          offset: t, portion: portion)
    }
}

// MARK: - Ask AI (routine generation)

enum AISimulator {
    /// ≈ 3 s. The first stage is the real app's copy; the later stage lines are
    /// PROPOSED (new strings for the user to approve).
    static let duration: TimeInterval = 3
    static func stages(gymName: String?) -> [(at: TimeInterval, progress: Double, text: String)] {
        [(0, 0.08, "Building your week…"),
         (0.8, 0.35, gymName.map { "Checking equipment at \($0)…" } ?? "Checking your equipment…"),
         (1.7, 0.65, "Balancing muscle families…"),
         (2.5, 0.9, "Fitting sessions to your time…")]
    }
    /// Real-app error copy (TerraError) used when a simulated AI call fails.
    static let failureMessage = "Could not reach OpenAI. Check your connection or continue manually."

    /// Runs the staged delay, reporting each stage; throws `CancellationError` when cancelled.
    static func run(gymName: String?, from startProgress: Double = 0,
                    onStage: (Double, String) -> Void) async throws {
        var elapsed: TimeInterval = 0
        for stage in stages(gymName: gymName) where stage.progress >= startProgress {
            if stage.at > elapsed {
                try await Task.sleep(for: .seconds(stage.at - elapsed))
                elapsed = stage.at
            }
            onStage(stage.progress, stage.text)
        }
        try await Task.sleep(for: .seconds(max(0.1, duration - elapsed)))
    }
}

// MARK: - Equipment identification (scan)

enum ScanSimulator {
    /// ≈ 2.5 s.
    static let duration: TimeInterval = 2.5

    /// The captured photo has no image asset (Assets.xcassets ships only MuscleMaps). Where
    /// the real app shows the photo (S03 thumbnail, S04–S06 photo), draw a placeholder tile:
    /// a dark look-surface rectangle with this SF Symbol centred and `photoCaption` under it.
    static let photoSymbol = "figure.strengthtraining.functional"
    static let photoCaption = "Hack squat · Iron Temple"
    /// Real-app error copy for a failed identification (`ScanFlow.simulateFailure`).
    static let failureMessage = AISimulator.failureMessage

    static func run(from startProgress: Double = 0, onProgress: (Double) -> Void) async throws {
        let steps = 10
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            guard progress > startProgress else { continue }
            try await Task.sleep(for: .seconds(duration / Double(steps)))
            onProgress(progress)
        }
    }

    /// The simulated AI answer for a photo of the hack squat at Iron Temple.
    static func result(kind: ScanKind) -> ScanResult {
        let hack = [SampleData.exerciseID("Hack Squat")]
        func candidate(_ maker: String, _ model: String, _ confidence: Double, catalog: Bool = true) -> ScanCandidate {
            ScanCandidate(id: .stable("scan.\(maker) \(model)"), manufacturer: maker, modelName: model,
                          category: .plateLoaded, exerciseIDs: hack, confidence: confidence,
                          catalogModelID: catalog ? SampleData.modelID("\(maker) \(model)") : nil)
        }
        switch kind {
        case .specific:
            let match = candidate("Matrix", "MG-PL71 Hack Squat", 0.93)
            return ScanResult(kind: .specific, label: "Hack Squat", candidates: [match], selectedCandidateID: match.id,
                              exerciseIDs: hack, visibleText: "MATRIX  MG-PL71")
        case .ambiguous:
            let options = [candidate("Watson", "PL Hack Squat", 0.46),
                           candidate("Watson", "PL Linear Hack Squat", 0.41),
                           candidate("Watson", "PL 30 Degree Hack Squat", 0.33)]
            return ScanResult(kind: .ambiguous, label: "Hack Squat", candidates: options, selectedCandidateID: nil,
                              exerciseIDs: hack, visibleText: "WATSON")
        case .newModel:
            let fresh = candidate("Rogue", "Monster Hack Squat", 0.81, catalog: false)
            return ScanResult(kind: .newModel, label: "Hack Squat", candidates: [fresh], selectedCandidateID: fresh.id,
                              exerciseIDs: hack, visibleText: "ROGUE  MONSTER")
        case .generic:
            return ScanResult(kind: .generic, label: "Hack Squat", candidates: [], selectedCandidateID: nil,
                              exerciseIDs: hack + [SampleData.exerciseID("Calf Raise")], visibleText: nil)
        }
    }

    /// The resolution line under the result (real-app copy).
    static func resolutionLine(_ result: ScanResult) -> String {
        switch result.kind {
        case .specific:
            return "Matches catalog: \(result.selectedCandidate?.displayName ?? "")"
        case .newModel:
            return "Will add new model: \(result.selectedCandidate?.displayName ?? "")"
        case .ambiguous:
            if let chosen = result.selectedCandidate { return "Matches catalog: \(chosen.displayName)" }
            return "Multiple catalog identities match. This will be saved without a model; you can choose one later."
        case .generic:
            return "Saved as this gym’s machine, with no model claimed."
        }
    }
    /// Shown above an uncertain result (real-app copy).
    static let uncertainLine = "AI could not identify this equipment. Try a clearer angle or choose its exercises below."
}

// MARK: - New Model: "Suggest exercises with AI"

enum ModelSuggestSimulator {
    /// ≈ 1.5 s of "Asking AI…".
    static let duration: TimeInterval = 1.5
    /// Real-app copy when nothing matched.
    static let emptyMessage = "AI could not tell which exercises this machine serves."

    /// Machine exercises whose every name word appears in the manufacturer/model text (≤ 6),
    /// e.g. "Rogue Monster Hack Squat" → Hack Squat. The reason line is PROPOSED copy.
    static func suggest(manufacturer: String, modelName: String, exercises: [Exercise]) -> [ModelExerciseSuggestion] {
        func words(_ text: String) -> [String] {
            text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }
        let typed = Set(words("\(manufacturer) \(modelName)"))
        return exercises
            .filter { ex in
                ex.isSeeded && (ex.tags.contains(.machine) || ex.tags.contains(.cable) || ex.tags.contains(.smith))
                    && Set(words(ex.name)).isSubset(of: typed)
            }
            .sorted { $0.name < $1.name }
            .prefix(6)
            .map { ModelExerciseSuggestion(exerciseID: $0.id, reason: "“\($0.name)” is in the model name.") }
    }
}

// MARK: - Export

enum ExportSimulator {
    /// ≈ 0.8 s.
    static let duration: TimeInterval = 0.8
    /// The system error description a failed write would carry (shown after "Export failed: ").
    static func failureDescription(fileName: String) -> String { "The file “\(fileName)” couldn’t be saved." }
}
