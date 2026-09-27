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
    /// The user wants a new model, prefilled with (manufacturer, model name)
    /// and carrying the plate's lines as read — camera or AI — so the New
    /// Model sheet can ask which exercises the machine serves (ticket 06).
    let onCreateNew: (String, String, [String]) -> Void

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
    /// An ask is in flight (ticket 05). Gates the button; one ask at a time.
    @State private var asking = false
    /// The ask itself, so a rescan or the sheet going away CANCELS the
    /// request rather than letting it land later (codex-review-05, high),
    /// and its identity, so only the ask still in flight may touch the sheet.
    @State private var askTask: Task<Void, Never>?
    @State private var askRequest: UUID?

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
        /// Who read the plate — the camera (Vision) or, after Ask AI, Claude.
        var source: ReadingSource = .camera
        /// What D33 preselected when these results were presented, as
        /// distinct from what the user has since tapped: the Ask AI button
        /// keys on this, so tapping a candidate does not hide it.
        var preselectedID: UUID?
        /// The box crop an ask would send (ticket 05, D53) — kept in memory
        /// only while these results are on screen, and only when an ask is
        /// possible at all. Never written anywhere.
        var crop: Data?
        /// Why the last ask produced nothing, shown under the button.
        var askNote: String?
    }

    enum ReadingSource {
        case camera
        case ai
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

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var shutterTaps = 0

    var body: some View {
        NavigationStack {
            // Floodlight redesign ticket 07: the Scan sheets' chrome (glass Cancel, the title in
            // the bar, the pinned commands) over the same phases and the same capture code.
            VStack(spacing: 0) {
                if case .scanning = phase {
                    scanningContent
                        .environment(\.look, look.darkCounterpart)
                        .environment(\.colorScheme, .dark)
                } else {
                    ScanTopBar(title: "Read Label", onCancel: { dismiss() })
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
            // Neither the 8 s capture timeout nor an ask outlives the sheet.
            .onDisappear {
                abandonCapture()
                abandonAsk()
            }
        }
        .lookSheetGround()
        .presentationBackground(isScanning ? Color.black : look.groundSheet)
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterTaps)
    }

    private var isScanning: Bool {
        if case .scanning = phase { true } else { false }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            ScanPagedScroll(centered: true) {
                VStack(spacing: 18) {
                    ScanGlyphDisc(symbol: "camera", size: 88, glyphFont: .system(size: 32, weight: .semibold))
                    Text("Starting the camera…")
                        .font(look.font.title3)
                        .foregroundStyle(look.textSecondary)
                        .accessibilityIdentifier("scanStatus")
                }
            }
        case .scanning:
            EmptyView()
        case .reading:
            ScanPagedScroll(centered: true) {
                ScanProgressInstrument(title: "Reading the label…")
                    .accessibilityIdentifier("scanStatus")
                    .padding(.horizontal, look.space.margin)
            }
        case .results(let results):
            resultsContent(results)
        case .failed(let message):
            failureContent(message)
        }
    }

    // MARK: - Viewfinder

    /// Always dark: the camera edge to edge, the plate-shaped box as flood-white brackets over a
    /// scrim, the status in a glass capsule and the control row (photo · shutter · torch).
    private var scanningContent: some View {
        ZStack(alignment: .bottom) {
            viewfinder
                .ignoresSafeArea(edges: .bottom)
                // The box the user frames the plate in: the SAME geometry the camera turns into
                // Vision's region of interest, so what is drawn is what is read (LabelFramingBox).
                .overlay {
                    GeometryReader { geometry in
                        let box = LabelFramingBox.rect(in: geometry.size)
                        Path { p in
                            p.addRect(CGRect(origin: .zero, size: geometry.size))
                            p.addRoundedRect(in: box, cornerSize: CGSize(width: 10, height: 10), style: .continuous)
                        }
                        .fill(Color.black.opacity(0.34), style: FillStyle(eoFill: true))
                        ScanFrameCorners(length: 30, radius: 3)
                            .stroke(look.done, style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .miter))
                            .frame(width: box.width, height: box.height)
                            .position(x: box.midX, y: box.midY)
                            .accessibilityElement()
                            .accessibilityLabel("Framing box")
                            .accessibilityIdentifier("scanFramingBox")
                    }
                    .allowsHitTesting(false)
                }

            VStack(spacing: 0) {
                HStack {
                    GlassCapsuleButton("Cancel") { dismiss() }
                        .accessibilityIdentifier("scanCancel")
                    Spacer()
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 14)
                Spacer(minLength: 0)
                Text(capturing ? "Reading…" : "Fit the name plate in the box")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.onSlab)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassEffect(.regular.tint(.black.opacity(0.35)), in: Capsule())
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .accessibilityIdentifier("scanStatus")
                    .padding(.bottom, 18)
                HStack {
                    circleButton(symbol: "photo.on.rectangle", lit: false) {
                        pickerRequest = PickerRequest(source: .photoLibrary)
                    }
                    .disabled(capturing)
                    .accessibilityLabel("Choose a photo instead")
                    .accessibilityIdentifier("scanChoosePhoto")
                    Spacer()
                    Button {
                        shutterTaps += 1
                        shutter()
                    } label: {
                        EmptyView()
                    }
                    .buttonStyle(ScanShutterStyle())
                    .overlay { if capturing { ProgressView().tint(.white).allowsHitTesting(false) } }
                    .disabled(capturing)
                    .accessibilityLabel("Take photo")
                    .accessibilityIdentifier("scanShutter")
                    Spacer()
                    if hasTorch {
                        circleButton(symbol: torchOn ? "bolt.fill" : "bolt.slash", lit: torchOn) { torchOn.toggle() }
                            .accessibilityLabel("Flash")
                            .accessibilityValue(torchOn ? "On" : "Off")
                            .accessibilityIdentifier("scanTorch")
                    } else {
                        Color.clear.frame(width: 54, height: 54)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 14)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func circleButton(symbol: String, lit: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(lit ? Color.black : look.onSlab)
                .frame(width: 54, height: 54)
                .background(lit ? look.onSlab : Color.clear, in: Circle())
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
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
    /// the rendered plate is read whole — it IS the plate — so its box is
    /// the plate's own edges, and the crop path runs for real.
    private func shutter() {
        guard case .scanning = phase, !capturing else { return }
        capturing = true
        if ScanFixture.isEnabled {
            capturing = false
            read(ScanFixture.image(), regionOfInterest: ScanFixture.plateRegion)
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

    /// Results: what was read (the plate's text as read), the candidates as radio rows with the
    /// matcher's score as a ten-cell meter (D33 shows scores), "Use This" the one filled command.
    /// Below D33's create-new floor the create-new action leads instead.
    @ViewBuilder
    private func resultsContent(_ results: Results) -> some View {
        // Below the create-new floor the catalog probably does not have this
        // machine, so the *action* leads, not just the wording. Above it, the
        // candidates lead and create-new waits below.
        let leadWithCreateNew = results.matches.isEmpty
            || CatalogMatcher.suggestsCreatingNew(results.matches)
        ScanPagedScroll {
            VStack(alignment: .leading, spacing: 22) {
                ScanInlineTitle(title: "Read Label")
                if let captureNotice {
                    Label(captureNotice, systemImage: "info.circle")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                readingCard(results)
                askSection(results)
                if leadWithCreateNew && !results.matches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        MakeRow(title: "Add this as a new model") { createNew(results) }
                            .accessibilityIdentifier("scanCreateNew")
                        footnote("Nothing in the catalog is a close match for this label.")
                    }
                } else if results.matches.isEmpty {
                    footnote("Nothing in the catalog looks like this label.")
                }
                if !results.matches.isEmpty {
                    candidates(results, leadWithCreateNew: leadWithCreateNew)
                }
                if typeSize.isAccessibilitySize { rescanButton }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 6)
            .padding(.bottom, 24)
        } bar: {
            ScanBottomBar {
                if results.matches.isEmpty {
                    ScanPrimaryButton("Add this as a new model", symbol: "plus") { createNew(results) }
                        .accessibilityIdentifier("scanCreateNew")
                } else {
                    ScanPrimaryButton("Use This", symbol: "checkmark", enabled: selectedID != nil) { use(selectedID) }
                        .accessibilityIdentifier("scanUseCandidate")
                }
                if !typeSize.isAccessibilitySize { rescanButton }
            }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(look.font.footnote)
            .foregroundStyle(look.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private func readingCard(_ results: Results) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(results.source == .ai ? "What AI read" : "What the camera read")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            Text(results.reading.text)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(look.space.panelPadding)
                .lookSurface(.panel)
                .accessibilityIdentifier("scanReadingText")
            // The counting client the ticket asks for: under the fixture the
            // stubs count every call and the sheet shows the tally, so a UI
            // test can assert "none" or "one" (codex-review-05b).
            if AskAI.fixtureIsEnabled {
                footnote("AI calls: \(AskAIFixtureLedger.calls)")
                    .accessibilityIdentifier("scanAskAICalls")
            }
        }
    }

    // Ticket 05 (D53): only when the phone could not place the plate,
    // only on a tap, only the box crop. A camera reading that preselected
    // never shows this; an AI reading is not asked about again.
    @ViewBuilder
    private func askSection(_ results: Results) -> some View {
        if results.source == .camera, results.preselectedID == nil, results.crop != nil,
           AskAI.transcriber != nil {
            VStack(alignment: .leading, spacing: 8) {
                if asking {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Asking AI…").font(look.font.body).foregroundStyle(look.textPrimary)
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("scanAskAIStatus")
                } else {
                    Button("Ask AI about this plate") { ask(results) }
                        .buttonStyle(.lookSecondary)
                        .accessibilityIdentifier("scanAskAI")
                }
                if let note = results.askNote {
                    footnote(note).accessibilityIdentifier("scanAskAINote")
                } else {
                    footnote("Sends the plate inside the box (plus a small margin around it) to Claude, with your key, and ranks what it reads here.")
                }
            }
        }
    }

    private func candidates(_ results: Results, leadWithCreateNew: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(leadWithCreateNew ? "Weak alternatives" : "Catalog models")
                .font(look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(results.matches.enumerated()), id: \.element.modelID) { index, match in
                    if index > 0 { LookDivider().padding(.leading, 56) }
                    candidateRow(match)
                }
                if !leadWithCreateNew {
                    LookDivider().padding(.leading, 56)
                    Button { createNew(results) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.system(.body, weight: .bold))
                                .foregroundStyle(look.textSecondary)
                                .frame(width: 26)
                            Text("None of these — create new")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(look.textPrimary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.lookPressable)
                    .accessibilityIdentifier("scanCreateNew")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
            .lookSurface(.panel)
            footnote(selectedID == nil
                ? "Nothing is picked for you here — the reading was not clear enough to choose between these. Tap the machine you are standing at."
                : "Check the machine in front of you before accepting — records are kept per model, so the wrong one splits your history.")
        }
    }

    private func candidateRow(_ match: CatalogMatch) -> some View {
        let selected = selectedID == match.modelID
        return Button {
            selectedID = match.modelID
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ScanRadio(selected: selected).padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(match.manufacturer)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                        Text(match.modelName)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ScanScoreMeter(value: match.score)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selected ? look.selectionFill : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(match.manufacturer) \(match.modelName), \(percentage(match.score))")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("scanCandidate.\(match.modelName)")
    }

    @ViewBuilder
    private var rescanButton: some View {
        if CaptureAvailability.resolve().allowsCamera || ScanFixture.isEnabled {
            Button("Scan again") { restartScanning() }
                .buttonStyle(.lookSecondary)
        } else {
            Button("Choose another photo") {
                pickerRequest = PickerRequest(source: .photoLibrary)
            }
            .buttonStyle(.lookSecondary)
        }
    }

    private func createNew(_ results: Results) {
        onCreateNew(results.manufacturerGuess, results.modelNameGuess, results.reading.lines.map(\.text))
        dismiss()
    }

    /// The camera failed or cannot open: the stated reason, then what can still work. Labelled
    /// by what each actually opens: offering "try the camera" when the camera cannot open is a
    /// lie the user pays for twice.
    private func failureContent(_ message: String) -> some View {
        let availability = CaptureAvailability.resolve()
        return ScanPagedScroll(centered: true) {
            VStack(spacing: 18) {
                ScanOutcomeDisc(outcome: .failed, size: 64)
                Text(message)
                    .font(look.font.title3)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("scanStatus")
                if availability.settingsCanHelp,
                   let settings = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: settings)
                        .buttonStyle(.lookSecondary)
                }
            }
            .padding(.horizontal, look.space.margin + 8)
        } bar: {
            ScanBottomBar {
                if availability.allowsCamera {
                    ScanPrimaryButton("Try the camera again", symbol: "camera") { restartScanning() }
                    Button("Choose from photos") { pickerRequest = PickerRequest(source: .photoLibrary) }
                        .buttonStyle(.lookSecondary)
                } else {
                    ScanPrimaryButton("Choose from photos", symbol: "photo.on.rectangle") {
                        pickerRequest = PickerRequest(source: .photoLibrary)
                    }
                }
                Button("Enter it by hand") {
                    onCreateNew("", "", [])
                    dismiss()
                }
                .buttonStyle(.lookSecondary)
                .accessibilityIdentifier("scanCreateNew")
            }
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
        abandonAsk()
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
        abandonAsk()
        Task {
            do {
                // Vision runs off the main actor and reads the photo in the
                // orientation it was taken; the image is not retained past this
                // call (D34) — only, when an ask is possible, the box crop it
                // would send (D53), and only while the results are up. No box
                // (the library photo) means no crop and no ask: the whole
                // photo never leaves the phone (codex-review-05).
                let reading = try await MachineLabelOCR.read(image, regionOfInterest: regionOfInterest)
                let crop: Data? = if let regionOfInterest, AskAI.transcriber != nil {
                    await Task.detached(priority: .userInitiated) {
                        LabelCrop.jpeg(image, region: regionOfInterest)
                    }.value
                } else {
                    nil
                }
                guard let index = catalogIndexIfLoaded() else {
                    phase = .failed("Could not read the equipment catalog.")
                    return
                }
                present(reading, in: index, source: .camera, crop: crop)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func present(
        _ reading: LabelReading, in index: CatalogMatchIndex, source: ReadingSource, crop: Data?
    ) {
        let matches = CatalogMatcher.rank(reading, in: index)
        // The create-new guesses read the REPAIRED plate — `SCYBEX` proposes
        // `Cybex` — while `Results.reading`, what the sheet echoes back as
        // read, stays the raw reading (scanner accuracy, ticket 02).
        let repaired = index.repaired(reading)
        let manufacturer = MachineLabelText.guessManufacturer(
            in: repaired, knownManufacturers: index.manufacturers) ?? ""
        // Preselected, never applied on its own (D33) — whoever read the plate.
        let preselected = CatalogMatcher.preselection(from: matches)?.modelID
        phase = .results(Results(
            reading: reading,
            matches: matches,
            manufacturerGuess: manufacturer,
            modelNameGuess: MachineLabelText.guessModelName(
                in: repaired, manufacturer: manufacturer),
            source: source,
            preselectedID: preselected,
            crop: crop))
        selectedID = preselected
    }

    /// Ask AI (ticket 05, D53): one call with the box crop; the reply is
    /// ranked by the same matcher and presented as a fresh reading. Any
    /// failure leaves these results exactly as they are, with a note; nothing
    /// is retried on its own. One ask at a time, by identity: a rescan, a
    /// new photo or the sheet going away cancels it, and a reply that is not
    /// the in-flight request's is dropped (codex-review-05).
    private func ask(_ results: Results) {
        guard askTask == nil, case .results = phase, let crop = results.crop,
              let transcriber = AskAI.transcriber, let index = catalogIndexIfLoaded()
        else { return }
        let request = UUID()
        askRequest = request
        asking = true
        askTask = Task {
            let outcome: Result<PlateTranscription, Error>
            do {
                outcome = .success(try await transcriber.transcribe(jpeg: crop))
            } catch {
                outcome = .failure(error)
            }
            // Only the request still in flight may touch the sheet. `asking`
            // and the task handle are released by their owner only.
            guard !Task.isCancelled, askRequest == request, case .results(let current) = phase else { return }
            askTask = nil
            askRequest = nil
            asking = false
            switch outcome {
            case .success(let transcription):
                let reading = transcription.labelReading
                if reading.isEmpty {
                    var noted = current
                    noted.askNote = "AI could not find a name plate in the box."
                    phase = .results(noted)
                } else {
                    present(reading, in: index, source: .ai, crop: nil)
                }
            case .failure(let error):
                var noted = current
                noted.askNote = error.localizedDescription
                phase = .results(noted)
            }
        }
    }

    /// Cancels the ask in flight, if any, without reporting it.
    private func abandonAsk() {
        askTask?.cancel()
        askTask = nil
        askRequest = nil
        asking = false
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

/// Test-only camera stand-in: the Simulator has no camera, so without this
/// the scan flow could not be driven end to end by `WorkoutTrackerUITests`
/// at all. Obeys the one fixture rule — its flag counts only beside
/// `-uiTestReset` (`WorkoutTrackerStore.fixtureIsEnabled`; codex-review-05).
enum ScanFixture {
    static let launchArgument = "-uiTestScanFixture"
    /// With the fixture: a plate that names NO brand (the corpus's Cybex
    /// placard `g022`, whose brand is a logo), so nothing preselects and the
    /// Ask AI path (ticket 05) can be driven.
    static let noBrandArgument = "-uiTestScanFixtureNoBrand"

    static var isEnabled: Bool {
        WorkoutTrackerStore.fixtureIsEnabled(launchArgument)
    }

    static var plateNamesNoBrand: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains(noBrandArgument)
    }

    /// The rendered plate's own edges as a framing box (Vision region,
    /// bottom-left origin): `plate` above, normalised on the canvas.
    static let plateRegion = CGRect(x: 0.1, y: 0.1875, width: 0.8, height: 0.625)

    /// A rendered name plate for a model the seeded catalog really contains,
    /// on a dark canvas around it — so the plate's box is a BOX: inset enough
    /// that the crop's margin still leaves canvas out (codex-review-05b).
    static func image() -> UIImage {
        let canvas = CGSize(width: 2_000, height: 800)
        let plate = CGRect(x: 200, y: 150, width: 1_600, height: 500)
        return UIGraphicsImageRenderer(size: canvas).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            UIColor.white.setFill()
            context.fill(plate)
            if plateNamesNoBrand {
                draw("CONVERGING PLATE LOADED", in: canvas, y: plate.minY + 80, fontSize: 80)
                draw("OVERHEAD PRESS", in: canvas, y: plate.minY + 230, fontSize: 88)
                draw("MAX 300 LB", in: canvas, y: plate.minY + 380, fontSize: 40)
            } else {
                draw("LIFE FITNESS", in: canvas, y: plate.minY + 60, fontSize: 64)
                draw("Insignia Series Chest Press", in: canvas, y: plate.minY + 200, fontSize: 88)
                draw("MAX 300 LB", in: canvas, y: plate.minY + 380, fontSize: 40)
            }
        }
    }

    private static func draw(_ text: String, in size: CGSize, y: CGFloat, fontSize: CGFloat) {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let string = NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: UIColor.black])
        string.draw(at: CGPoint(x: (size.width - string.size().width) / 2, y: y))
    }
}
