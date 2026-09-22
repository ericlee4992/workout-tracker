import SwiftUI
import SwiftData
import UIKit

/// One photograph, one Terra request, then an editable proposal. Nothing is saved here.
struct IdentifyEquipmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var models: [EquipmentModel]
    @AppStorage(TerraAccess.photoConsentKey) private var consent = false
    var onIdentify: (EquipmentIdentification) -> Void
    @State private var showingSettings = false
    @State private var showingLibrary = false
    @State private var started = false
    @State private var captureID: UUID?
    @State private var work: Task<Void, Never>?
    @State private var requestID: UUID?
    @State private var busy = false
    @State private var error: String?
    @State private var proposal: EquipmentIdentification?
    @State private var torch = false
    private enum Field: Hashable { case label, manufacturer, model }
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Group {
                if !consent && !TerraAccess.bypassesConsent {
                    Form {
                        Section {
                            Text("Send equipment photos to OpenAI?").font(.headline)
                            Text("Each scan sends the full photo, including any people or screens in frame, and the exercise catalog to OpenAI for identification. The app does not save the photo. OpenAI’s API data policies apply.")
                            Link("OpenAI data policies", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                            Button("Allow photos and continue") { consent = true; start() }
                                .accessibilityIdentifier("allowAIPhotos")
                        }
                    }
                } else if TerraAccess.client == nil && !TerraAccess.fixture {
                    Form {
                        Text("Add your OpenAI API key to identify equipment with Terra.")
                        Button("Open AI Settings") { showingSettings = true }.accessibilityIdentifier("scannerAISettings")
                        Text("You can also cancel and choose a catalog model manually.").foregroundStyle(.secondary)
                    }
                } else if busy {
                    VStack(spacing: 20) {
                        ProgressView("Identifying equipment…")
                        Button("Take another photo") { reset() }.accessibilityIdentifier("scanRescan")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if proposal != nil {
                    result
                } else {
                    capture
                }
            }
            .navigationTitle(proposal == nil ? "Scan Equipment" : "AI Proposal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel(); dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("dismissEquipmentKeyboard")
                }
            }
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
        }
    }

    private var capture: some View {
        VStack(spacing: 12) {
            if let error { Text(error).foregroundStyle(Theme.secondary).padding().accessibilityIdentifier("scanAIError") }
            if started && CaptureAvailability.resolve() == .camera && !TerraAccess.fixture {
                LabelCameraView(captureRequest: captureID, onPhoto: { photo in
                    guard captureID == photo.requestID else { return }
                    captureID = nil; work?.cancel(); identify(photo.image)
                }, onFailure: { id, message in
                    // Camera teardown after a photo must not cancel the AI request or overwrite its result.
                    guard !busy, proposal == nil else { return }
                    if let id, id != captureID { return }
                    captureID = nil; work?.cancel(); error = message
                }, torchOn: torch)
            } else {
                Image(systemName: "camera.viewfinder").font(.largeTitle).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text("Scan a machine or its label").font(.callout)
            HStack {
                Button("Take photo", systemImage: "camera") { shutter() }
                    .disabled(captureID != nil || (!TerraAccess.fixture && CaptureAvailability.resolve() != .camera))
                    .accessibilityIdentifier("scanShutter")
                Button("Flash", systemImage: "bolt") { torch.toggle() }.disabled(TerraAccess.fixture)
            }.buttonStyle(.bordered)
            Button("Choose a photo instead") { showingLibrary = true }.accessibilityIdentifier("scanChoosePhoto")
        }.padding(.bottom)
    }

    private var resolution: EquipmentIdentityResolution { proposal.map { EquipmentIdentityResolution.resolve($0, among: models, exerciseNames: exercises.filter(\.isSeeded).map(\.name)) } ?? .generic }
    private var catalogMatch: EquipmentModel? {
        if case .catalog(let model) = resolution { return model }
        return nil
    }
    private var effectiveIDs: [UUID] { catalogMatch?.exerciseIDs.isEmpty == false ? catalogMatch!.exerciseIDs : proposal?.exerciseIDs ?? [] }

    private var result: some View {
        Form {
            if proposal?.identity == "uncertain" {
                Text("AI could not identify this equipment. Try a clearer angle or choose its exercises below.")
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.caption).foregroundStyle(Theme.secondary)
                    TextField("Machine name", text: Binding(get: { proposal?.label ?? "" }, set: { proposal?.label = $0; proposal?.labelWasEdited = true }), axis: .vertical)
                        .focused($focusedField, equals: .label)
                        .accessibilityIdentifier("identifiedMachineLabel")
                }
                if proposal?.identity == "specific" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manufacturer").font(.caption).foregroundStyle(Theme.secondary)
                        TextField("Manufacturer", text: Binding(get: { proposal?.manufacturer ?? "" }, set: { proposal?.manufacturer = $0 }), axis: .vertical).focused($focusedField, equals: .manufacturer)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model").font(.caption).foregroundStyle(Theme.secondary)
                        TextField("Model", text: Binding(get: { proposal?.modelName ?? "" }, set: { proposal?.modelName = $0 }), axis: .vertical).focused($focusedField, equals: .model)
                    }
                    if let text = proposal?.visibleText, !text.isEmpty { Text(text).font(.caption).foregroundStyle(Theme.secondary) }
                    Button("Use generic identity") { proposal?.identity = "generic"; proposal?.manufacturer = ""; proposal?.modelName = "" }
                }
            } header: { Text("Equipment") } footer: {
                switch resolution {
                case .catalog(let model): Text("Matches catalog: \(model.displayName)")
                case .newModel(let manufacturer, let name): Text("Will add new model: \(manufacturer) \(name)")
                case .ambiguous: Text("Multiple catalog identities match. This will be saved without a model; you can choose one later.")
                case .generic: Text("Saved as this gym’s machine, with no model claimed.")
                }
            }
            Section("Exercises") {
                ForEach(exercises.filter { effectiveIDs.contains($0.id) }) { exercise in Text(exercise.name) }
                if catalogMatch?.exerciseIDs.isEmpty != false { NavigationLink("Change exercises") {
                    AIExerciseSelection(exercises: exercises, selected: Binding(get: { Set(proposal?.exerciseIDs ?? []) }, set: { proposal?.exerciseIDs = $0.sorted { $0.uuidString < $1.uuidString } }))
                } }
            }
            Section {
                Button("Use this equipment") {
                    guard var proposal else { return }
                    proposal.exerciseIDs = effectiveIDs
                    proposal.label = proposal.label.trimmingCharacters(in: .whitespacesAndNewlines)
                    if case .ambiguous = resolution { proposal.identity = "generic" }
                    if case .generic = resolution { proposal.identity = "generic" }
                    onIdentify(proposal); dismiss()
                }.disabled(proposal?.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false || effectiveIDs.isEmpty)
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("scanUseCandidate")
                Button("Take another photo") { reset() }.accessibilityIdentifier("scanRescan")
            }
        }.scrollDismissesKeyboard(.interactively)
    }

    private func start() {
        started = true
        if !TerraAccess.fixture { error = CaptureAvailability.resolve().reason }
    }
    private func cancel() { work?.cancel(); work = nil; requestID = nil; captureID = nil; busy = false }
    private func reset() { cancel(); proposal = nil; error = nil; start() }
    private func shutter() {
        if TerraAccess.fixture { identify(ScanFixture.image()); return }
        let id = UUID(); captureID = id
        work = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, captureID == id else { return }
            captureID = nil; error = "The camera did not return a photo. Try again."
        }
    }
    private func identify(_ image: UIImage) {
        guard consent || TerraAccess.bypassesConsent else { return }
        cancel(); busy = true; error = nil
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
                proposal = answer; busy = false
            } catch {
                guard !Task.isCancelled, requestID == id else { return }
                self.error = error.localizedDescription; busy = false
            }
        }
    }
}

struct AIExerciseSelection: View {
    var exercises: [Exercise]
    @Binding var selected: Set<UUID>
    @State private var query = ""
    var body: some View {
        List(exercises.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { exercise in
            Button {
                if selected.contains(exercise.id) { selected.remove(exercise.id) }
                else if selected.count < 6 { selected.insert(exercise.id) }
            } label: {
                HStack { Text(exercise.name); Spacer(); if selected.contains(exercise.id) { Image(systemName: "checkmark") } }
            }.foregroundStyle(Theme.text)
        }.searchable(text: $query).navigationTitle("Exercises")
    }
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
