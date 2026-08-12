import SwiftData
import SwiftUI
import UIKit

/// Photo machine capture, ticket 02 — photograph a machine's name plate, and
/// let the user confirm which catalog model it is.
///
/// The sheet **proposes** (D33). It preselects the top hit when the match is
/// strong, shows the alternatives with their scores, and always leaves "none of
/// these" one tap away — because D23 keys history, prefill and PRs on the model
/// UUID, so a wrong model silently accepted splits the user's own history.
struct ScanMachineLabelSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The user accepted a catalog row.
    let onUseModel: (EquipmentModel) -> Void
    /// The user wants a new model, prefilled with (manufacturer, model name).
    let onCreateNew: (String, String) -> Void

    @State private var phase: Phase = .idle
    @State private var showingPicker = false
    @State private var pickerSource: ImagePicker.Source = .photoLibrary
    @State private var selectedID: UUID?
    /// Why the camera is not being used, when it is not. Shown, never silent.
    @State private var captureNotice: String?

    private enum Phase {
        case idle
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

    var body: some View {
        NavigationStack {
            List {
                switch phase {
                case .idle:
                    Label("Opening the camera…", systemImage: "camera")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("scanStatus")
                case .reading:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading the label…")
                    }
                    .accessibilityIdentifier("scanStatus")
                case .results(let results):
                    resultsContent(results)
                case .failed(let message):
                    failureContent(message)
                }
            }
            .navigationTitle("Scan Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ImagePicker(source: pickerSource) { image in
                    showingPicker = false
                    guard let image else {
                        // Backed out without taking anything. Do not dismiss the
                        // scanner: permission may have just been denied behind
                        // the picker, and the user needs to see why and what
                        // else they can do (codex-review-2, finding 6).
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
        // machine, so the *action* leads, not just the wording (codex-review,
        // finding 8). Above it, the candidates lead and create-new waits below.
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

                Button("Retake photo") { retake() }
            }
        } else {
            Section {
                Button("Retake photo") { retake() }
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
            Button("Choose from photos") { present(.photoLibrary) }
            // Labelled by what it actually opens: offering "try the camera"
            // when the camera cannot open is a lie the user pays for twice.
            if availability.allowsCamera {
                Button("Try the camera again") { present(.camera) }
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
            present(.camera)
        case .noCamera:
            // Straight to the library, with the reason on screen behind it.
            present(.photoLibrary)
        case .cameraDenied, .cameraRestricted:
            // Nothing is presented over the top: the user needs to read this
            // and choose, not have another picker appear.
            phase = .failed(availability.reason ?? "The camera is unavailable.")
        }
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

    private func present(_ source: ImagePicker.Source) {
        pickerSource = source
        showingPicker = true
    }

    private func retake() {
        let availability = CaptureAvailability.resolve()
        captureNotice = availability.reason
        present(ImagePicker.Source.preferred(given: availability))
    }

    private func read(_ image: UIImage) {
        phase = .reading
        selectedID = nil
        Task {
            do {
                // Vision runs off the main actor and reads the photo in the
                // orientation it was taken; the image is not retained past this
                // call (D34).
                let reading = try await MachineLabelOCR.read(image)
                let index = try catalogIndex()
                let matches = CatalogMatcher.rank(reading, in: index)
                let manufacturer = MachineLabelText.guessManufacturer(
                    in: reading, knownManufacturers: index.manufacturers) ?? ""
                phase = .results(Results(
                    reading: reading,
                    matches: matches,
                    manufacturerGuess: manufacturer,
                    modelNameGuess: MachineLabelText.guessModelName(
                        in: reading, manufacturer: manufacturer)))
                // Preselected only when the match is strong, the plate names
                // this manufacturer, and the runner-up is not breathing down
                // its neck. Never applied on its own (D33).
                selectedID = CatalogMatcher.preselection(from: matches)?.modelID
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// Built per scan from the store's own models, so a model the user added
    /// five minutes ago is matchable too. Measured over the full 1877-row
    /// catalog in `MachineLabelOCRTests`; the slow part of a scan is Vision,
    /// which already runs off the main actor.
    private func catalogIndex() throws -> CatalogMatchIndex {
        CatalogMatchIndex(models: try modelContext
            .fetch(FetchDescriptor<EquipmentModel>())
            .map { (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName) })
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
