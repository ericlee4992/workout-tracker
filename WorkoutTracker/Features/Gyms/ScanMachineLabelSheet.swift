import AVFoundation
import SwiftData
import SwiftUI
import UIKit

/// Photo machine capture, ticket 02 — point the phone at a machine's name plate
/// and confirm which catalog model it is.
///
/// The sheet **proposes** (D33). It preselects a row only when the score, the
/// manufacturer and the margin over the runner-up all agree, shows the
/// alternatives with their scores, and always leaves "none of these" one tap
/// away — because D23 keys history, prefill and PRs on the model UUID, so a
/// wrong model silently accepted splits the user's own history.
///
/// Capture is **one deliberate frame** (scanner accuracy, ticket 03, at the
/// user's request): the camera opens as a viewfinder with a plate-shaped
/// framing box, nothing is read until the shutter, and then one still at the
/// camera's photo resolution is read once, inside the box only. The live
/// read-every-frame loop it replaces (ticket 02 revision, 2026-08-11) settled
/// on half-read plates while the camera was still moving and picked up the
/// neighbouring machine's plate; the user called it slow and inaccurate. The
/// system photo picker's shutter → review → "Use Photo" ceremony is still
/// avoided: the shutter here is one tap and there is nothing to review.
struct ScanMachineLabelSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The user accepted a catalog row.
    let onUseModel: (EquipmentModel) -> Void
    /// The user wants a new model, prefilled with (manufacturer, model name).
    let onCreateNew: (String, String) -> Void

    @State private var phase: Phase = .idle
    @State private var pickerRequest: PickerRequest?
    @State private var selectedID: UUID?
    /// Why the camera is not being used, when it is not. Shown, never silent.
    @State private var captureNotice: String?
    @State private var torchOn = false
    /// The shutter tap the camera should honour; a new id per tap, nil when
    /// none is pending (so a rebuilt camera never replays one).
    @State private var captureRequest: UUID?
    /// The shutter has been tapped and the photo is on its way. Gates the
    /// shutter AND the library fallback: one still, read once.
    @State private var capturing = false
    /// Fails the capture if the camera never calls back (codex-review-03).
    @State private var captureTimeout: Task<Void, Never>?
    @State private var index: CatalogMatchIndex?

    private enum Phase {
        case idle
        case scanning
        case reading
        case results(Results)
        case failed(String)
    }

    private struct Results {
        var reading: LabelReading
        var matches: [CatalogMatch]
        var manufacturerGuess: String
        var modelNameGuess: String
    }

    /// The source *and* the presentation as one value.
    ///
    /// Setting a `pickerSource` state and an `isPresented` flag in the same
    /// update let SwiftUI build the sheet from the previous source — which is
    /// why tapping "Scan label…" on a real phone opened the photo library when
    /// the code plainly asked for the camera. One value cannot go stale against
    /// itself.
    private struct PickerRequest: Identifiable {
        let id = UUID()
        let source: ImagePicker.Source
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scan Label")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    if case .scanning = phase, hasTorch {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                torchOn.toggle()
                            } label: {
                                Image(systemName: torchOn ? "bolt.fill" : "bolt.slash")
                            }
                            .accessibilityIdentifier("scanTorch")
                        }
                    }
                }
                .sheet(item: $pickerRequest) { request in
                    ImagePicker(source: request.source) { image in
                        pickerRequest = nil
                        guard let image else {
                            if case .idle = phase { cancelledWithoutPhoto() }
                            return
                        }
                        read(image)
                    }
                    .ignoresSafeArea()
                }
                .onAppear(perform: start)
                // The 8 s capture timeout must not outlive the sheet.
                .onDisappear(perform: abandonCapture)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            List {
                Label("Starting the camera…", systemImage: "camera")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("scanStatus")
            }
        case .scanning:
            scanningContent
        case .reading:
            List {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the label…")
                }
                .accessibilityIdentifier("scanStatus")
            }
        case .results(let results):
            List { resultsContent(results) }
        case .failed(let message):
            List { failureContent(message) }
        }
    }

    // MARK: - Viewfinder

    private var scanningContent: some View {
        ZStack(alignment: .bottom) {
            viewfinder
                .ignoresSafeArea(edges: .bottom)
                // The box the user frames the plate in: the SAME geometry the
                // camera turns into Vision's region of interest, so what is
                // drawn is what is read (LabelFramingBox).
                .overlay {
                    GeometryReader { geometry in
                        let box = LabelFramingBox.rect(in: geometry.size)
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.9), lineWidth: 2)
                            .frame(width: box.width, height: box.height)
                            .position(x: box.midX, y: box.midY)
                            .accessibilityIdentifier("scanFramingBox")
                    }
                    .allowsHitTesting(false)
                }

            VStack(spacing: 14) {
                Text(capturing ? "Reading…" : "Fit the name plate in the box")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("scanStatus")

                Button(action: shutter) {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 74, height: 74)
                        Circle().fill(.white).frame(width: 60, height: 60)
                        if capturing { ProgressView().tint(.black) }
                    }
                }
                .buttonStyle(.plain)
                .disabled(capturing)
                .accessibilityLabel("Take photo")
                .accessibilityIdentifier("scanShutter")

                Button("Choose a photo instead") {
                    pickerRequest = PickerRequest(source: .photoLibrary)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(capturing)
                .accessibilityIdentifier("scanChoosePhoto")
            }
            .padding(.bottom, 24)
        }
    }

    /// The camera, or — under `-uiTestScanFixture`, where the Simulator has no
    /// camera — a stand-in so the shutter and the box are still driven by the
    /// UI tests.
    @ViewBuilder
    private var viewfinder: some View {
        if ScanFixture.isEnabled {
            Rectangle().fill(.black)
                .overlay { Text("Fixture plate").foregroundStyle(.gray) }
                .accessibilityIdentifier("scanFixtureViewfinder")
        } else {
            LabelCameraView(
                captureRequest: captureRequest,
                onPhoto: { captured in
                    guard captureFinished(captured.requestID) else { return }
                    read(captured.image, regionOfInterest: captured.region)
                },
                onFailure: { request, message in
                    // A failure of the camera itself is not tied to a tap and
                    // always lands; a capture's failure lands only if that
                    // exact request is the one in flight (codex-review-03b).
                    if let request { guard captureFinished(request) else { return } }
                    phase = .failed(message)
                },
                torchOn: torchOn)
        }
    }

    /// The shutter: one still, read once, inside the box. Under the fixture
    /// the rendered plate is read whole — it IS the plate.
    private func shutter() {
        guard case .scanning = phase, !capturing else { return }
        capturing = true
        if ScanFixture.isEnabled {
            capturing = false
            read(ScanFixture.image())
            return
        }
        let request = UUID()
        captureRequest = request
        captureTimeout?.cancel()
        captureTimeout = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, captureFinished(request) else { return }
            phase = .failed("The camera did not respond. Try again, or choose a photo.")
        }
    }

    /// Ends the in-flight capture exactly once, and only for the request that
    /// is actually in flight: the first of its photo, its failure or its
    /// timeout wins; anything for an older request is ignored.
    private func captureFinished(_ request: UUID) -> Bool {
        guard capturing, captureRequest == request else { return false }
        abandonCapture()
        return true
    }

    // MARK: - Content

    @ViewBuilder
    private func resultsContent(_ results: Results) -> some View {
        if let captureNotice {
            Section {
                Label(captureNotice, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Text(results.reading.text)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("scanReadingText")
        } header: {
            Text("What the camera read")
        }

        // Below the create-new floor the catalog probably does not have this
        // machine, so the *action* leads, not just the wording. Above it, the
        // candidates lead and create-new waits below.
        let leadWithCreateNew = results.matches.isEmpty
            || CatalogMatcher.suggestsCreatingNew(results.matches)

        if leadWithCreateNew {
            Section {
                Button("Add this as a new model") {
                    createNew(results)
                }
                .accessibilityIdentifier("scanCreateNew")
            } footer: {
                Text(results.matches.isEmpty
                    ? "Nothing in the catalog looks like this label."
                    : "Nothing in the catalog is a close match for this label.")
            }
        }

        if !results.matches.isEmpty {
            Section {
                ForEach(results.matches, id: \.modelID) { match in
                    Button {
                        selectedID = match.modelID
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.modelName)
                                Text(match.manufacturer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(percentage(match.score))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            if selectedID == match.modelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("scanCandidate.\(match.modelName)")
                }
            } header: {
                Text(leadWithCreateNew ? "Weak alternatives" : "Catalog models")
            } footer: {
                Text(selectedID == nil
                    ? "Nothing is picked for you here — the reading was not clear enough to choose between these. Tap the machine you are standing at."
                    : "Check the machine in front of you before accepting — records are kept per model, so the wrong one splits your history.")
            }

            Section {
                Button("Use This") {
                    use(selectedID)
                }
                .disabled(selectedID == nil)
                .accessibilityIdentifier("scanUseCandidate")

                if !leadWithCreateNew {
                    Button("None of these — create new") {
                        createNew(results)
                    }
                    .accessibilityIdentifier("scanCreateNew")
                }

                rescanButton
            }
        } else {
            Section { rescanButton }
        }
    }

    @ViewBuilder
    private var rescanButton: some View {
        if CaptureAvailability.resolve().allowsCamera {
            Button("Scan again") { restartScanning() }
        } else {
            Button("Choose another photo") {
                pickerRequest = PickerRequest(source: .photoLibrary)
            }
        }
    }

    private func createNew(_ results: Results) {
        onCreateNew(results.manufacturerGuess, results.modelNameGuess)
        dismiss()
    }

    @ViewBuilder
    private func failureContent(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .accessibilityIdentifier("scanStatus")
        }
        Section {
            let availability = CaptureAvailability.resolve()
            if availability.settingsCanHelp,
               let settings = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settings)
            }
            Button("Choose from photos") {
                pickerRequest = PickerRequest(source: .photoLibrary)
            }
            // Labelled by what it actually opens: offering "try the camera"
            // when the camera cannot open is a lie the user pays for twice.
            if availability.allowsCamera {
                Button("Try the camera again") { restartScanning() }
            }
            Button("Enter it by hand") {
                onCreateNew("", "")
                dismiss()
            }
            .accessibilityIdentifier("scanCreateNew")
        }
    }

    private func percentage(_ score: Double) -> String {
        "\(Int((score * 100).rounded()))%"
    }

    private var hasTorch: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?
            .hasTorch ?? false
    }

    // MARK: - Flow

    private func start() {
        guard case .idle = phase else { return }
        if ScanFixture.isEnabled {
            // The fixture stands in for the camera, not for the shutter: the
            // viewfinder shows and the test taps `scanShutter` like a user.
            restartScanning()
            return
        }
        let availability = CaptureAvailability.resolve()
        captureNotice = availability.reason
        switch availability {
        case .camera:
            // `.notDetermined` is included here: starting the session is what
            // raises the system prompt, and answering it is the user's call.
            restartScanning()
        case .noCamera:
            pickerRequest = PickerRequest(source: .photoLibrary)
        case .cameraDenied, .cameraRestricted:
            phase = .failed(availability.reason ?? "The camera is unavailable.")
        }
    }

    private func restartScanning() {
        abandonCapture()
        selectedID = nil
        phase = .scanning
    }

    /// Drops whatever capture is in flight without reporting it — a rescan
    /// or the sheet going away.
    private func abandonCapture() {
        capturing = false
        captureRequest = nil
        captureTimeout?.cancel()
        captureTimeout = nil
    }

    /// The picker closed with no photo. Re-resolve, because the reason may have
    /// changed underneath (a `.notDetermined` prompt answered "Don't Allow"),
    /// and land on the explanation rather than silently closing.
    private func cancelledWithoutPhoto() {
        let availability = CaptureAvailability.resolve()
        captureNotice = availability.reason
        if let reason = availability.reason {
            phase = .failed(reason)
        } else {
            dismiss()
        }
    }

    /// A still photograph — the shutter's, the library fallback, or the test
    /// fixture. `regionOfInterest` is the framing box for the shutter's photo;
    /// a library photo or the fixture is read whole.
    private func read(_ image: UIImage, regionOfInterest: CGRect? = nil) {
        phase = .reading
        selectedID = nil
        Task {
            do {
                // Vision runs off the main actor and reads the photo in the
                // orientation it was taken; the image is not retained past this
                // call (D34).
                let reading = try await MachineLabelOCR.read(image, regionOfInterest: regionOfInterest)
                guard let index = catalogIndexIfLoaded() else {
                    phase = .failed("Could not read the equipment catalog.")
                    return
                }
                present(reading, in: index)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func present(_ reading: LabelReading, in index: CatalogMatchIndex) {
        let matches = CatalogMatcher.rank(reading, in: index)
        // The create-new guesses read the REPAIRED plate — `SCYBEX` proposes
        // `Cybex` — while `Results.reading`, what the sheet echoes back as
        // read, stays the raw reading (scanner accuracy, ticket 02).
        let repaired = index.repaired(reading)
        let manufacturer = MachineLabelText.guessManufacturer(
            in: repaired, knownManufacturers: index.manufacturers) ?? ""
        phase = .results(Results(
            reading: reading,
            matches: matches,
            manufacturerGuess: manufacturer,
            modelNameGuess: MachineLabelText.guessModelName(
                in: repaired, manufacturer: manufacturer)))
        // Preselected, never applied on its own (D33).
        selectedID = CatalogMatcher.preselection(from: matches)?.modelID
    }

    /// Built once per sheet and cached across rescans.
    private func catalogIndexIfLoaded() -> CatalogMatchIndex? {
        if let index { return index }
        guard let rows = try? modelContext.fetch(FetchDescriptor<EquipmentModel>()) else {
            return nil
        }
        let built = CatalogMatchIndex(
            models: rows.map { (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName) },
            // The reading repair's English-word test (scanner accuracy, ticket 02).
            isDictionaryWord: MachineLabelDictionary.closure)
        index = built
        return built
    }

    private func use(_ modelID: UUID?) {
        guard let modelID else { return }
        do {
            let matched = try modelContext.fetch(FetchDescriptor<EquipmentModel>(
                predicate: #Predicate { $0.id == modelID }))
            guard let model = matched.first else {
                phase = .failed("That model is no longer in the catalog.")
                return
            }
            onUseModel(model)
            dismiss()
        } catch {
            phase = .failed("Could not open that model: \(error.localizedDescription)")
        }
    }
}

/// Test-only camera stand-in, gated on a launch argument exactly like
/// `-uiTestReset`: the Simulator has no camera, so without this the scan flow
/// could not be driven end to end by `WorkoutTrackerUITests` at all.
enum ScanFixture {
    static let launchArgument = "-uiTestScanFixture"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// A rendered name plate for a model the seeded catalog really contains.
    static func image() -> UIImage {
        let size = CGSize(width: 1_600, height: 500)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw("LIFE FITNESS", in: size, y: 60, fontSize: 64)
            draw("Insignia Series Chest Press", in: size, y: 200, fontSize: 88)
            draw("MAX 300 LB", in: size, y: 380, fontSize: 40)
        }
    }

    private static func draw(_ text: String, in size: CGSize, y: CGFloat, fontSize: CGFloat) {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let string = NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: UIColor.black])
        string.draw(at: CGPoint(x: (size.width - string.size().width) / 2, y: y))
    }
}
