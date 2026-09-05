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
/// Capture is a **live** camera read (ticket 02 revision, 2026-08-11, at the
/// user's request): scanning starts the moment the sheet opens and settles by
/// itself. Taking a photograph, reviewing it and tapping "Use Photo" was three
/// taps of ceremony before the app had read a single word.
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
    @State private var liveText = ""
    @State private var stabilizer = LiveScanStabilizer()
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

    // MARK: - Live scanning

    private var scanningContent: some View {
        ZStack(alignment: .bottom) {
            LiveLabelScannerView(
                onReading: consider,
                onFailure: { phase = .failed($0) },
                torchOn: torchOn)
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 12) {
                Text(liveText.isEmpty ? "Point at the machine's name plate" : liveText)
                    .font(liveText.isEmpty ? .callout : .callout.monospaced())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("scanLiveText")

                Button("Choose a photo instead") {
                    pickerRequest = PickerRequest(source: .photoLibrary)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("scanChoosePhoto")
            }
            .padding(.bottom, 28)
        }
    }

    /// One live reading. Scanning stops as soon as consecutive frames agree on
    /// the same answer, so the user never has to decide when it has "got it".
    private func consider(_ reading: LabelReading) {
        guard case .scanning = phase else { return }
        liveText = reading.text
        guard let index = catalogIndexIfLoaded() else { return }
        let matches = CatalogMatcher.rank(reading, in: index)
        // Settle on the *decision*, not on identical pixels: two frames that
        // read slightly differently but point at the same catalog row are
        // agreement, and two frames that read the same unlisted plate are too.
        let key = matches.first?.modelID.uuidString
            ?? MachineLabelText.normalized(reading.text)
        guard let settled = stabilizer.observe(reading, key: key) else { return }
        present(settled, in: index)
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
            read(ScanFixture.image())
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
        stabilizer.reset()
        liveText = ""
        selectedID = nil
        phase = .scanning
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

    /// A still photograph — the library fallback, and the test fixture.
    private func read(_ image: UIImage) {
        phase = .reading
        selectedID = nil
        Task {
            do {
                // Vision runs off the main actor and reads the photo in the
                // orientation it was taken; the image is not retained past this
                // call (D34).
                let reading = try await MachineLabelOCR.read(image)
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

    /// Built once per sheet and cached: live scanning ranks several times a
    /// second, and rebuilding a 1877-row index per frame would be the one
    /// expensive thing in the loop.
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
