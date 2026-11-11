import PhotosUI
import SwiftData
import SwiftUI
import UIKit

// Nutrition N7 — Scan Food, a full-screen cover from Today (the camera beside Log food) or Log food's bar: sign in (AI
// needs an account, D60) → the camera (no photo consent screen, D83) with Scan food | Barcode | Food label and a
// photo-library pick. A meal photo closes the camera at once: its progress card is in Today's log and it is logged when
// the estimate arrives (D82). A label is cropped to the box (D53), read here, and opens the food prefilled. Barcode is
// N8's. In UI tests (`-uiTestTerra`) and on the Simulator the drawn sample stands in for the camera.

/// One photo from the shutter or the library, ready to send.
struct FoodScanShot {
    var image: UIImage
    var jpeg: Data
    var mode: FoodScanMode
    /// A library photo's own time (nil from the camera: now).
    var taken: Date?
    var fromLibrary: Bool
}

struct FoodScanFlow: View {
    /// The meal a camera photo goes to: Log food's chosen meal, or nil from Today (by the time of day).
    var meal: MealSlot?
    /// A meal photo or a label was handled: the caller shows Today (the card, or the logged label).
    var onDone: () -> Void
    var onManualAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AccountStore.self) private var account
    @State private var path: [Step] = []
    @State private var signingIn = false
    @State private var label: LabelState?

    enum Step: Hashable { case readingLabel, labelFood }

    /// The label being read: its crop, then the reading or why there is none.
    struct LabelState {
        var shot: FoodScanShot
        var reading: FoodLabelReading?
        var failure: (title: String, detail: String)?
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !TerraAccess.ready(account) {
                    FoodScanSignIn(onCancel: { dismiss() }, onSignIn: { signingIn = true }, onManual: manual)
                } else {
                    FoodScanCamera(onCancel: { dismiss() }, onShot: shot)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .readingLabel:
                    // A binding, not values: the destination is built once, and the reply arrives later.
                    FoodScanReadingLabel(label: $label, onCancel: { dismiss() }, onRetake: retake, onManual: manual)
                        .toolbar(.hidden, for: .navigationBar)
                case .labelFood:
                    LabelFoodStep(label: $label, meal: meal, onRetake: retake, onLogged: done)
                }
            }
        }
        .lookScreenBackground()
        .sheet(isPresented: $signingIn) { AccountSignInSheet() }
    }

    private func shot(_ shot: FoodScanShot) {
        switch shot.mode {
        case .meal:
            // A library photo is logged when it was taken, in that time's meal (D83); a camera photo now, in the meal
            // Log food chose or the time's.
            let when = FoodScan.when(photoTaken: shot.taken)
            let meal = shot.fromLibrary && shot.taken != nil ? when.meal : (meal ?? when.meal)
            FoodScanQueue.shared.startPhoto(jpeg: shot.jpeg, meal: meal, eatenAt: when.date,
                                            client: TerraAccess.client(account), context: context)
            done()
        case .label:
            label = LabelState(shot: shot)
            path.append(.readingLabel)
            read(shot)
        case .barcode:
            break
        }
    }

    /// A label is short work: the camera's sheet waits for it on the reading screen.
    private func read(_ shot: FoodScanShot) {
        let client = TerraAccess.client(account)
        Task {
            let failure: (String, String)?
            do {
                let data: Data
                if TerraAccess.fixture {
                    data = try await FoodScanFixture.reply(.foodLabel)
                } else {
                    guard let client else { throw AIServerError.signedOut }
                    data = try await client.complete(.foodLabel, json: AIServerClient.foodPhotoBody(jpeg: shot.jpeg))
                }
                if let reading = FoodLabelReading.parse(data), reading.isUsable {
                    guard label?.shot.jpeg == shot.jpeg else { return }
                    label?.reading = reading
                    path = [.readingLabel, .labelFood]
                    return
                }
                failure = FoodScanReadingLabel.notFound
            } catch let error as AIServerError {
                switch error {
                case .limit(_, let limit, let resetsAt):
                    failure = ("Daily limit reached",
                               "\(limit ?? 30) labels a day. More at \(AIResetCopy.clock(resetsAt, zone: .current)).")
                case .offline: failure = ("Couldn't read the label", "No connection. Try again.")
                case .signedOut: failure = ("Couldn't read the label", "Sign in again, then try again.")
                default: failure = ("Couldn't read the label", "Something went wrong. Try again.")
                }
            } catch {
                failure = ("Couldn't read the label", "Something went wrong. Try again.")
            }
            guard label?.shot.jpeg == shot.jpeg else { return }
            label?.failure = failure.map { (title: $0.0, detail: $0.1) }
        }
    }

    private func retake() {
        label = nil
        path.removeAll()
    }

    private func done() {
        dismiss()
        onDone()
    }

    private func manual() {
        dismiss()
        onManualAdd()
    }
}

// MARK: - Camera

struct FoodScanCamera: View {
    var onCancel: () -> Void
    var onShot: (FoodScanShot) -> Void
    @Environment(\.look) private var look

    var body: some View {
        FoodScanCameraContent(camera: self)
            .environment(\.look, look.darkCounterpart)
            .environment(\.colorScheme, .dark)
    }
}

private struct FoodScanCameraContent: View {
    var camera: FoodScanCamera
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: FoodScanMode = .meal
    @State private var torch = false
    @State private var flash = 0.0
    @State private var shutterTaps = 0
    @State private var captureID: UUID?
    @State private var notice: String?
    @State private var picking = false
    @State private var picked: PhotosPickerItem?
    /// The view's size and the box at the shutter, so the crop is the box the user saw.
    @State private var geometry: (size: CGSize, frame: CGRect) = (.zero, .zero)

    private var availability: CaptureAvailability { CaptureAvailability.resolve() }
    private var fixture: Bool { TerraAccess.fixture }
    /// UI tests reach the camera-off screen with `-uiTestFoodScanNoCamera`.
    private var cameraUsable: Bool {
        fixture ? !ProcessInfo.processInfo.arguments.contains("-uiTestFoodScanNoCamera") : availability.allowsCamera
    }

    var body: some View {
        GeometryReader { geo in
            let frame = framingRect(in: geo.size)
            ZStack {
                if cameraUsable {
                    viewfinder(frame: frame, size: geo.size)
                } else {
                    cameraOff
                }
                Color.white.opacity(flash).allowsHitTesting(false).ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    if cameraUsable {
                        if let notice { glassLine(notice).padding(.bottom, 10) }
                        glassLine(hint).padding(.bottom, 16)
                        modes.padding(.horizontal, look.space.margin).padding(.bottom, 14)
                        controls.padding(.horizontal, 30).padding(.bottom, 10)
                    } else {
                        cameraOffActions.padding(.horizontal, look.space.margin).padding(.bottom, 10)
                    }
                }
            }
            .onAppear { geometry = (geo.size, frame) }
            .onChange(of: geo.size) { _, size in geometry = (size, framingRect(in: size)) }
            .onChange(of: mode) { _, _ in geometry = (geo.size, framingRect(in: geo.size)) }
        }
        .background(Color.black.ignoresSafeArea())
        .photosPicker(isPresented: $picking, selection: $picked, matching: .images)
        .onChange(of: picked) { _, item in if let item { load(item) } }
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterTaps)
        .sensoryFeedback(.selection, trigger: mode)
    }

    private var hint: String {
        switch mode {
        case .meal: "Fit your meal in the frame"
        case .barcode: "Point at a barcode"
        case .label: "Fit the Nutrition Facts in the box"
        }
    }

    // MARK: Viewfinder

    @ViewBuilder private func viewfinder(frame: CGRect, size: CGSize) -> some View {
        ZStack {
            if fixture {
                // The Simulator and UI tests: a drawn meal, label or barcode where the camera would be.
                Group {
                    if mode == .meal {
                        Color.black.overlay { Image(uiImage: FoodScanArt.meal).resizable().scaledToFill().scaleEffect(0.95) }
                    } else {
                        Color(hex: 0xC9B48F).overlay {
                            Image(uiImage: mode == .label ? FoodScanArt.label : FoodScanArt.barcode)
                                .resizable()
                                .scaledToFit()
                                .frame(width: frame.width * (mode == .label ? 0.9 : 1.06))
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .clipped()
                .accessibilityIdentifier("scanFoodViewfinder")
            } else {
                // The same coordinates as the box: the preview fills exactly this view (aspect-filled), which is what
                // `LabelFramingBox.visionRegion` assumes.
                LabelCameraView(captureRequest: captureID, onPhoto: photo, onFailure: failed, torchOn: torch)
            }
            // The label's box is a crop (D53): outside it is dimmed harder, since only the box is sent.
            Path { p in
                p.addRect(CGRect(x: -10, y: -200, width: size.width + 20, height: size.height + 400))
                p.addRoundedRect(in: frame, cornerSize: CGSize(width: 22, height: 22), style: .continuous)
            }
            .fill(Color.black.opacity(mode == .meal ? 0.3 : 0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            ScanFrameCorners(length: 34, radius: 3)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .miter))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: mode)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Meal: a large square; label: a tall box (the crop); barcode: a wide, short band.
    private func framingRect(in size: CGSize) -> CGRect {
        let width: CGFloat
        let height: CGFloat
        switch mode {
        case .meal: width = min(size.width - 48, 380); height = width
        case .label: width = min(size.width - 110, 300); height = min(width * 1.45, size.height * 0.5)
        case .barcode: width = min(size.width - 70, 340); height = width * 0.5
        }
        return CGRect(x: (size.width - width) / 2, y: size.height * 0.4 - height / 2, width: width, height: height)
    }

    private func glassLine(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.onSlab)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .glassEffect(.regular.tint(.black.opacity(0.35)), in: Capsule())
            .padding(.horizontal, 24)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .accessibilityIdentifier("scanFoodHint")
    }

    // MARK: Modes and controls

    /// Three equal tiles (the prototype's): the chosen one filled white. A mode, not a command.
    private var modes: some View {
        HStack(spacing: 8) {
            ForEach(FoodScanMode.allCases) { item in
                Button { withAnimation(reduceMotion ? nil : .snappy) { mode = item } } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.symbol).font(.system(.title3, weight: .semibold))
                        Text(item.title).font(.system(.footnote, weight: .semibold))
                            .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(mode == item ? Color.black : Color.white)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .padding(.vertical, 4)
                    .background(mode == item ? Color.white : Color.white.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == item ? .isSelected : [])
                .accessibilityIdentifier("scanFoodMode.\(item.rawValue)")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var controls: some View {
        HStack {
            side(symbol: "photo.on.rectangle", lit: false) { library() }
                .disabled(mode == .barcode)
                .opacity(mode == .barcode ? 0.4 : 1)
                .accessibilityLabel("Choose a photo")
                .accessibilityIdentifier("scanFoodLibrary")
            Spacer()
            if mode == .barcode {
                // A barcode is read as soon as it is in the band (N8): no shutter.
                Color.clear.frame(width: 88, height: 88)
            } else {
                Button(action: shoot) { EmptyView() }
                    .buttonStyle(ScanShutterStyle())
                    .disabled(captureID != nil)
                    .accessibilityLabel("Take photo")
                    .accessibilityIdentifier("scanFoodShutter")
            }
            Spacer()
            side(symbol: torch ? "bolt.fill" : "bolt.slash", lit: torch) { torch.toggle() }
                .disabled(fixture)
                .accessibilityLabel("Flash")
                .accessibilityValue(torch ? "On" : "Off")
        }
    }

    private func side(symbol: String, lit: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(lit ? Color.black : look.onSlab)
                .frame(width: 54, height: 54)
                .background(lit ? look.onSlab : Color.clear, in: Circle())
                .glassEffect(.regular.interactive(), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }

    // MARK: Taking a photo

    private func shoot() {
        shutterTaps += 1
        notice = nil
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.07)) { flash = 0.85 }
            withAnimation(.easeIn(duration: 0.35).delay(0.08)) { flash = 0 }
        }
        if fixture {
            let art = mode == .meal ? FoodScanArt.meal : FoodScanArt.label
            send(art, region: nil, taken: nil, fromLibrary: false)
        } else {
            captureID = UUID()
        }
    }

    private func photo(_ captured: CapturedLabel) {
        guard captured.requestID == captureID else { return }
        captureID = nil
        // The label's crop is OUR box (taller than Scan Machine's), mapped into the photo as the preview showed it.
        let region = LabelFramingBox.visionRegion(box: geometry.frame, viewSize: geometry.size,
                                                  imageSize: captured.image.size)
        send(captured.image, region: region, taken: nil, fromLibrary: false)
    }

    private func failed(_ request: UUID?, _ message: String) {
        if request == nil || request == captureID { captureID = nil }
        notice = message
    }

    private func library() {
        notice = nil
        if fixture {
            // The fixture's "library": the drawn meal, taken at 12:40 today (a picked photo's own time, D83).
            let taken = Calendar.current.date(bySettingHour: 12, minute: 40, second: 0, of: .now)
            send(mode == .meal ? FoodScanArt.meal : FoodScanArt.label, region: nil, taken: taken, fromLibrary: true)
        } else {
            picking = true
        }
    }

    private func load(_ item: PhotosPickerItem) {
        let shotMode = mode
        Task {
            defer { picked = nil }
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                notice = "That photo couldn't be opened."
                return
            }
            mode = shotMode
            send(image, region: nil, taken: PhotoDate.taken(in: data), fromLibrary: true)
        }
    }

    /// The JPEG that leaves the phone: a meal photo whole (≤ 1568 px, as Scan Machine sends); a label from the camera
    /// only its box (D53); a picked label photo whole (the user chose that picture).
    private func send(_ image: UIImage, region: CGRect?, taken: Date?, fromLibrary: Bool) {
        let jpeg: Data?
        if mode == .label, let region {
            jpeg = LabelCrop.jpeg(image, region: region)
        } else {
            jpeg = EquipmentPhoto.jpeg(image)
        }
        guard let jpeg else {
            notice = "That photo couldn't be used. Try again."
            return
        }
        camera.onShot(FoodScanShot(image: UIImage(data: jpeg) ?? image, jpeg: jpeg, mode: mode, taken: taken,
                                   fromLibrary: fromLibrary))
    }

    private var topBar: some View {
        HStack {
            GlassCapsuleButton("Cancel", action: camera.onCancel).accessibilityIdentifier("scanFoodCancel")
            Spacer()
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 14)
    }

    // MARK: Camera off

    private var cameraOff: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(look.onSlab)
                .frame(width: 88, height: 88)
                .background(look.onSlab.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(availability == .noCamera ? "No camera" : "Camera access is off")
                .font(look.font.title2)
                .foregroundStyle(look.onSlab)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(availability.settingsCanHelp ? "Allow the camera in Settings, or choose a photo of your meal."
                                              : "Choose a photo of your meal instead.")
                .font(look.font.subhead)
                .foregroundStyle(look.onSlabSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -40)
        .accessibilityIdentifier("scanFoodCameraOff")
    }

    private var cameraOffActions: some View {
        VStack(spacing: 10) {
            ScanPrimaryButton("Choose a photo", symbol: "photo.on.rectangle") { picking = true }
                .accessibilityIdentifier("scanFoodLibrary")
            if availability.settingsCanHelp, let settings = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settings).buttonStyle(.lookSecondary)
            }
        }
    }
}

// MARK: - Sign in

private struct FoodScanSignIn: View {
    var onCancel: () -> Void
    var onSignIn: () -> Void
    var onManual: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Food", onCancel: onCancel)
            ScanPagedScroll(centered: true) {
                VStack(spacing: 22) {
                    ScanGlyphDisc(symbol: "person.crop.circle", size: typeSize.isAccessibilitySize ? 88 : 108,
                                  glyphFont: .system(size: typeSize.isAccessibilitySize ? 34 : 42, weight: .semibold))
                    Text("Sign in to scan food.")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, look.space.margin + 8)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Sign In", symbol: "person.crop.circle", action: onSignIn)
                        .accessibilityIdentifier("scanFoodSignIn")
                    Button("Manual Add", action: onManual)
                        .buttonStyle(.lookSecondary)
                        .accessibilityIdentifier("scanFoodManual")
                }
            }
        }
        .lookScreenBackground()
    }
}

// MARK: - Reading a label

/// The cropped label is the hero while it is read; a label not found or a failure says so, with Take another photo and
/// Manual Add.
private struct FoodScanReadingLabel: View {
    @Binding var label: FoodScanFlow.LabelState?
    var onCancel: () -> Void
    var onRetake: () -> Void
    var onManual: () -> Void
    @Environment(\.look) private var look

    static let notFound = ("No label found", "Fit the whole Nutrition Facts panel in the box.")

    private var image: UIImage? { label?.shot.image }
    private var failure: (title: String, detail: String)? { label?.failure }

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Food label", onCancel: onCancel)
            ScanStepBody {
                ScanInlineTitle(title: "Food label")
                ScanPhotoHero(image: image, scanning: failure == nil, failed: failure != nil)
                if let failure {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(failure.title).font(look.font.title3).foregroundStyle(look.textPrimary)
                        Text(failure.detail).font(look.font.subhead).foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(look.space.panelPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lookSurface(.panel)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("scanFoodLabelFailure")
                } else {
                    ScanProgressInstrument(title: "Reading the label…")
                }
            } bar: {
                ScanBottomBar {
                    if failure != nil {
                        ScanPrimaryButton("Take another photo", symbol: "camera", action: onRetake)
                            .accessibilityIdentifier("scanFoodRetake")
                        Button("Manual Add", action: onManual)
                            .buttonStyle(.lookSecondary)
                            .accessibilityIdentifier("scanFoodManual")
                    } else {
                        Button("Take another photo", action: onRetake)
                            .buttonStyle(.lookSecondary)
                            .accessibilityIdentifier("scanFoodRetake")
                    }
                }
            }
        }
        .lookScreenBackground()
    }
}

// MARK: - The label's food

/// The label's food once read — through a binding, so the step shows the reading that arrived after it was pushed.
private struct LabelFoodStep: View {
    @Binding var label: FoodScanFlow.LabelState?
    var meal: MealSlot?
    var onRetake: () -> Void
    var onLogged: () -> Void

    var body: some View {
        if let label, let reading = label.reading {
            // A picked photo's time decides its meal (D83); a camera label: Log food's meal or the time's.
            LabelFoodView(reading: reading, image: label.shot.image,
                          meal: label.shot.taken.map { FoodScan.when(photoTaken: $0).meal } ?? meal ?? MealSlot.forTime(.now),
                          eatenAt: FoodScan.when(photoTaken: label.shot.taken).date,
                          onRetake: onRetake, onLogged: onLogged)
        }
    }
}

/// The Selected food screen (N4) prefilled from the label: the serving and every number as printed; the name is the
/// user's (a label has none). Log is the one primary; "Save to My foods" is on, so the next time it is one tap.
struct LabelFoodView: View {
    var reading: FoodLabelReading
    var image: UIImage?
    var meal: MealSlot
    var eatenAt: Date
    var onRetake: () -> Void
    var onLogged: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var brand = ""
    @State private var servings = 1.0
    @State private var saveToMyFoods = true
    @State private var failure: String?

    private var named: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var perServing: Macros {
        let n = reading.nutrition
        return Macros(calories: n.calories, proteinGrams: n.proteinGrams, carbsGrams: n.carbsGrams, fatGrams: n.fatGrams)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    header
                    LookList(separatorInset: 16) {
                        FoodFormField("Name", text: $name, prompt: "e.g. Granola", identifier: "labelFoodName")
                        FoodFormField("Brand", text: $brand, prompt: "Optional", identifier: "labelFoodBrand")
                    }
                    amount
                    MacroSummary(macros: perServing.scaled(by: servings))
                    otherFacts
                    LookList(separatorInset: 16) {
                        LookToggleRow("Save to My foods", isOn: $saveToMyFoods)
                            .accessibilityIdentifier("labelFoodSave")
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            PrimaryButton("Log to \(meal.label)", action: log)
                .disabled(!named)
                .opacity(named ? 1 : 0.4)
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("labelFoodLog")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Retake", action: onRetake).accessibilityIdentifier("labelFoodRetake")
            }
        }
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func log() {
        let draft = reading.draft(name: name, brand: brand)
        do {
            try FoodScan.logLabel(draft, servings: servings, meal: meal, saveToMyFoods: saveToMyFoods, at: eatenAt,
                                  in: context)
            onLogged()
        } catch {
            failure = error.localizedDescription
        }
    }

    /// The label as read, small, beside the title: what the numbers came from.
    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 56, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("From the label").font(look.font.largeTitle).foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Check the numbers, name it, log it.").font(look.font.subhead).foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var amount: some View {
        LookList(separatorInset: 54) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Servings").font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
                    stepper
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LookRow("Servings", symbol: "number", showsChevron: false) { stepper }
            }
            // As printed ("2/3 cup (55g)"); what is stored is the parsed serving.
            let serving = reading.serving
            LookRow("Serving", symbol: "scalemass",
                    value: reading.servingSize.isEmpty
                        ? ServingText.format(value: serving.value, unit: serving.unit, grams: serving.grams)
                        : reading.servingSize,
                    showsChevron: false)
            if let perContainer = reading.servingsPerContainer {
                LookRow("Servings per container", symbol: "shippingbox", value: FoodNumber.text(perContainer),
                        showsChevron: false)
            }
        }
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            step("minus", label: "Fewer servings", enabled: servings > 0.5) { servings = max(0.5, servings - 0.5) }
            Text(servings.formatted(.number.precision(.fractionLength(0...2))))
                .font(look.font.statNumber).monospacedDigit().frame(minWidth: 44)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: servings))
                .accessibilityIdentifier("labelFoodServings")
            step("plus", label: "More servings", enabled: true) { servings += 0.5 }
        }
    }

    private func step(_ symbol: String, label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(reduceMotion ? nil : .snappy) { action() } } label: {
            Image(systemName: symbol).font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: 44, height: 44)
                .background(look.ground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }

    /// Shown open: the label printed them, so they are part of what to check. Not printed: "–".
    private var otherFacts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other nutrition facts").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
            fact("Saturated fat", reading.saturatedFat, "g")
            fact("Fiber", reading.fiber, "g")
            fact("Sugar", reading.sugar, "g")
            fact("Sodium", reading.sodiumMg, "mg")
        }
        .padding(16)
        .lookSurface(.panel)
    }

    private func fact(_ title: String, _ value: Double?, _ unit: String) -> some View {
        HStack {
            Text(title).foregroundStyle(look.textSecondary)
            Spacer()
            Text(value.map { "\(($0 * servings).formatted(.number.precision(.fractionLength(0...1)))) \(unit)" } ?? "–")
                .monospacedDigit().foregroundStyle(look.textPrimary)
        }
        .font(look.font.subhead)
    }
}
