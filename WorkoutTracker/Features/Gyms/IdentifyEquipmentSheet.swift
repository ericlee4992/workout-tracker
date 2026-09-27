import SwiftUI
import SwiftData
import UIKit

/// One photograph, one Terra request, then an editable proposal (D56).
///
/// Floodlight redesign ticket 07: one "Scan Machine" sheet driven by its step — consent (before
/// the camera, user decision 2) → no key → camera → identifying → error / result → added. Two
/// ways in (user decision 1): **add** mode (the gym page's Scan Machine, AI routine setup) saves
/// the confirmed machine itself and shows the Added step; **fill-form** mode (the machine form's
/// "Scan equipment…") hands the confirmed proposal back to the form and saves nothing here.
struct IdentifyEquipmentSheet: View {
    enum Mode {
        case fillForm((EquipmentIdentification) -> Void)
        case add
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var models: [EquipmentModel]
    @AppStorage(TerraAccess.photoConsentKey) private var consent = false
    /// The gym the machine is for: add mode saves there; both modes check it for duplicates.
    var gym: Gym?
    var mode: Mode
    /// "Choose a catalog model" (no key, error): add mode hands over to the machine form.
    var onManual: (() -> Void)?

    @State private var showingSettings = false
    @State private var showingLibrary = false
    @State private var started = false
    @State private var captureID: UUID?
    @State private var work: Task<Void, Never>?
    @State private var requestID: UUID?
    @State private var busy = false
    /// Why the camera cannot take a photo (shown on the camera step).
    @State private var cameraNotice: String?
    /// Why identification failed (the error step, beside the photo).
    @State private var identifyError: String?
    @State private var photo: UIImage?
    @State private var proposal: EquipmentIdentification?
    /// The AI's own label, kept so an unedited name can follow the identity back and forth.
    @State private var aiLabel = ""
    /// "Use generic identity": the AI's answer stays in `proposal`, so this is reversible.
    @State private var genericChosen = false
    @State private var added: MachineInstance?
    @State private var saveFailure: String?
    @State private var torch = false
    @State private var path: [ScanPage] = []
    @State private var shutterTaps = 0
    @State private var picks = 0

    enum Field: Hashable { case label, manufacturer, model }
    @FocusState private var focusedField: Field?

    /// The form's scan button.
    init(gym: Gym? = nil, onIdentify: @escaping (EquipmentIdentification) -> Void) {
        self.gym = gym
        self.mode = .fillForm(onIdentify)
    }

    /// The gym page's Scan Machine and AI routine setup: Add saves the machine at `gym`.
    init(addingTo gym: Gym, onManual: (() -> Void)? = nil) {
        self.gym = gym
        self.mode = .add
        self.onManual = onManual
    }

    enum Step: Hashable { case consent, noKey, camera, identifying, error, result, added }

    private var step: Step {
        if !consent && !TerraAccess.bypassesConsent { return .consent }
        if TerraAccess.client == nil && !TerraAccess.fixture { return .noKey }
        if added != nil { return .added }
        if busy { return .identifying }
        if identifyError != nil { return .error }
        if proposal != nil { return .result }
        return .camera
    }

    private var isAddMode: Bool { if case .add = mode { true } else { false } }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                switch step {
                case .consent:
                    ScanConsentStep(onCancel: close) {
                        consent = true
                        start()
                    }
                    .transition(stepTransition)
                case .noKey:
                    ScanNoKeyStep(onCancel: close, onSettings: { showingSettings = true }, onManual: chooseManually)
                        .transition(stepTransition)
                case .camera:
                    ScanCameraStep(gymName: gym?.name, machineCount: machineCount, started: started,
                                   notice: cameraNotice, captureID: captureID, torch: $torch,
                                   onCancel: close, onShutter: shutter, onLibrary: { showingLibrary = true },
                                   onPhoto: { captured in
                                       guard captureID == captured.requestID else { return }
                                       captureID = nil; work?.cancel(); identify(captured.image)
                                   },
                                   onFailure: { id, message in
                                       // Camera teardown after a photo must not cancel the AI request or overwrite its result.
                                       guard !busy, proposal == nil else { return }
                                       if let id, id != captureID { return }
                                       captureID = nil; work?.cancel(); cameraNotice = message
                                   })
                    .transition(stepTransition)
                case .identifying:
                    ScanIdentifyingStep(photo: photo, onCancel: close, onRetake: reset)
                        .transition(stepTransition)
                case .error:
                    ScanErrorStep(photo: photo, message: identifyError ?? "", onCancel: close,
                                  onRetake: reset, onManual: chooseManually)
                        .transition(stepTransition)
                case .result:
                    if let proposal {
                        ScanResultStep(
                            proposal: Binding(get: { self.proposal ?? proposal }, set: { self.proposal = $0 }),
                            photo: photo, gym: gym, isAddMode: isAddMode, genericChosen: $genericChosen,
                            resolution: resolution, catalogMatches: catalogMatches, effectiveIDs: effectiveIDs,
                            exercises: exercises, saveFailure: saveFailure, focusedField: $focusedField,
                            onCancel: close, onRetake: reset, onCommit: commit,
                            onChangeExercises: { path.append(.exercises) })
                        .transition(stepTransition)
                    }
                case .added:
                    if let added {
                        ScanAddedStep(machine: added, photo: photo, gymName: gym?.name ?? "", machineCount: machineCount,
                                      exerciseNames: names(of: added.supportedExerciseIDs),
                                      onDone: { dismiss() }, onScanAnother: scanAnother)
                        .transition(stepTransition)
                    }
                }
            }
            .animation(stepAnimation, value: step)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("dismissEquipmentKeyboard")
                }
            }
            .navigationDestination(for: ScanPage.self) { _ in
                ScanExercisePicker(exercises: exercises, proposed: proposal?.exerciseIDs ?? [],
                                   selected: Binding(get: { proposal?.exerciseIDs ?? [] },
                                                     set: { proposal?.exerciseIDs = $0 }))
            }
        }
        .lookSheetGround()
        .presentationBackground(step == .camera ? Color.black : look.groundSheet)
        .interactiveDismissDisabled(step == .result || step == .identifying)
        .sheet(isPresented: $showingSettings, onDismiss: { start() }) { AskAISettingsSheet() }
        .sheet(isPresented: $showingLibrary) {
            ImagePicker(source: .photoLibrary) { image in
                showingLibrary = false
                if let image { identify(image) }
            }
        }
        .onAppear { if consent || TerraAccess.bypassesConsent { start() } }
        .onDisappear { cancel() }
        .onChange(of: consent) { _, allowed in if !allowed { cancel(); proposal = nil } }
        // Editing maker/model can move the answer to another catalog row (or none): the unedited
        // name follows it, so both modes save the name the result shows (codex-review-07).
        .onChange(of: catalogModelID) { _, _ in reconcileLabel() }
        .sensoryFeedback(.success, trigger: added?.id)
    }

    private var stepAnimation: Animation {
        UIAccessibility.isReduceMotionEnabled ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.86)
    }

    /// Out first, then in: the old step's pinned buttons never sit under the new step's.
    private var stepTransition: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled { return .opacity.animation(.easeInOut(duration: 0.18)) }
        return .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.3).delay(0.08)),
                           removal: .opacity.animation(.easeIn(duration: 0.1)))
    }

    private var machineCount: Int {
        (gym?.machines ?? []).filter { !$0.archived }.count
    }

    private func names(of ids: [UUID]) -> [String] {
        ids.compactMap { id in exercises.first { $0.id == id }?.name }
    }

    // MARK: Resolution

    private var seededNames: [String] { exercises.filter(\.isSeeded).map(\.name) }

    private var resolution: EquipmentIdentityResolution {
        proposal.map { EquipmentIdentityResolution.resolve($0, among: models, exerciseNames: seededNames) } ?? .generic
    }

    private var catalogModelID: UUID? {
        if case .catalog(let model) = resolution { return model.id }
        return nil
    }

    private func reconcileLabel() {
        guard var current = proposal else { return }
        var model: EquipmentModel?
        if case .catalog(let match) = resolution { model = match }
        let label = ScanMachine.reconciledLabel(current, aiLabel: aiLabel, catalogModelName: model?.modelName,
                                                modelExerciseNames: model.map { names(of: $0.exerciseIDs) } ?? [])
        guard label != current.label else { return }
        current.label = label
        proposal = current
    }

    private var catalogMatches: [EquipmentModel] {
        guard let proposal, case .ambiguous = resolution else { return [] }
        return EquipmentIdentityResolution.exactMatches(manufacturer: proposal.manufacturer,
                                                        modelName: proposal.modelName, among: models)
            .sorted { $0.displayName < $1.displayName }
    }

    /// The exercises Add would save: a catalog match's own, unless the answer is set aside.
    private var effectiveIDs: [UUID] {
        guard let proposal else { return [] }
        return ScanMachine.confirmed(proposal, resolution: resolution, genericChosen: genericChosen).exerciseIDs
    }

    // MARK: Actions

    private func close() {
        cancel()
        dismiss()
    }

    private func chooseManually() {
        cancel()
        dismiss()
        onManual?()
    }

    private func commit() {
        guard let proposal else { return }
        focusedField = nil
        let confirmed = ScanMachine.confirmed(proposal, resolution: resolution, genericChosen: genericChosen)
        switch mode {
        case .fillForm(let onIdentify):
            onIdentify(confirmed)
            dismiss()
        case .add:
            guard let gym else { return }
            do {
                let machine = try ScanMachine.add(confirmed, to: gym, context: modelContext)
                withAnimation(stepAnimation) { added = machine }
            } catch {
                saveFailure = error.localizedDescription
            }
        }
    }

    private func scanAnother() {
        withAnimation(stepAnimation) {
            added = nil
            reset()
        }
    }

    private func start() {
        started = true
        if !TerraAccess.fixture { cameraNotice = CaptureAvailability.resolve().reason }
    }
    private func cancel() { work?.cancel(); work = nil; requestID = nil; captureID = nil; busy = false }
    private func reset() {
        cancel(); proposal = nil; cameraNotice = nil; identifyError = nil; photo = nil
        genericChosen = false; saveFailure = nil; path = []
        start()
    }
    private func shutter() {
        shutterTaps += 1
        if TerraAccess.fixture { identify(ScanFixture.image()); return }
        let id = UUID(); captureID = id
        work = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, captureID == id else { return }
            captureID = nil; cameraNotice = "The camera did not return a photo. Try again."
        }
    }
    private func identify(_ image: UIImage) {
        guard consent || TerraAccess.bypassesConsent else { return }
        cancel(); busy = true; cameraNotice = nil; identifyError = nil
        photo = image
        let id = UUID(); requestID = id
        let jpeg = EquipmentPhoto.jpeg(image)
        let candidates = exercises.filter(\.isSeeded).map { "\($0.id.uuidString) | \($0.name) | \($0.loadType.rawValue)" }.joined(separator: "\n")
        let allowed = Set(exercises.filter(\.isSeeded).map(\.id))
        let fixtureID = exercises.first { $0.name == "Seated Chest Press" }?.id ?? exercises.first?.id
        work = Task {
            do {
                let answer: EquipmentIdentification
                if TerraAccess.fixture {
                    try await TerraAccess.fixtureDelay()
                    let flags = ProcessInfo.processInfo.arguments
                    if flags.contains("-uiTestTerraUncertain") {
                        answer = EquipmentIdentification(identity: "uncertain", label: "", manufacturer: "", modelName: "", visibleText: "", exerciseIDs: [])
                    } else if flags.contains("-uiTestTerraSpecific") || flags.contains("-uiTestTerraAmbiguous") {
                        answer = EquipmentIdentification(identity: "specific", label: "Chest press", manufacturer: "Life Fitness", modelName: "Insignia Series Chest Press", visibleText: "Life Fitness Insignia Series Chest Press", exerciseIDs: fixtureID.map { [$0] } ?? [])
                    } else if flags.contains("-uiTestTerraNewModel") {
                        answer = EquipmentIdentification(identity: "specific", label: "Chest press", manufacturer: "Fixture Brand", modelName: "Printed Test Press", visibleText: "Fixture Brand Printed Test Press", exerciseIDs: fixtureID.map { [$0] } ?? [])
                    } else {
                        answer = EquipmentIdentification(identity: "generic", label: "Chest press", manufacturer: "", modelName: "", visibleText: "", exerciseIDs: fixtureID.map { [$0] } ?? [])
                    }
                } else {
                    guard let client = TerraAccess.client, let jpeg else { throw TerraError.invalidResponse }
                    let data = try await client.complete(instructions: EquipmentIdentification.instructions, input: candidates,
                                                         schema: EquipmentIdentification.schema, name: "equipment_identity", jpeg: jpeg)
                    answer = try JSONDecoder().decode(EquipmentIdentification.self, from: data).validated(allowed: allowed)
                }
                guard !Task.isCancelled, requestID == id else { return }
                aiLabel = answer.label
                proposal = prefilled(answer); genericChosen = false; busy = false
            } catch {
                guard !Task.isCancelled, requestID == id else { return }
                identifyError = error.localizedDescription; busy = false
            }
        }
    }

    /// D3: an answer that matched a catalog model arrives named by its movement, as picking that
    /// model in the form names it — what the field shows is what Add saves.
    private func prefilled(_ answer: EquipmentIdentification) -> EquipmentIdentification {
        guard case .catalog(let model) = EquipmentIdentityResolution.resolve(answer, among: models, exerciseNames: seededNames)
        else { return answer }
        var result = answer
        result.label = ScanMachine.prefilledLabel(for: answer, catalogModelName: model.modelName,
                                                  modelExerciseNames: names(of: model.exerciseIDs))
        return result
    }
}

/// Pages pushed inside the scan sheet.
enum ScanPage: Hashable {
    case exercises
}

/// Upright pixel rendering deliberately strips the original EXIF/GPS metadata.
enum EquipmentPhoto {
    static func jpeg(_ image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, 1568 / max(image.size.width, image.size.height))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.85)
    }
}
