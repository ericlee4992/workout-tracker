import SwiftUI
import UIKit

// Nutrition N7 (MOCK) — Scan Food, a full-screen cover from Today (the camera beside Log food) or Log food's bar:
// sign in (AI needs an account, D60) → the camera (no photo consent screen: the user, 2026-11-10, D83)
// with Scan food | Barcode | Food label and a photo-library pick. A meal photo closes the camera at once:
// the progress card is in Today's log (D82). A label is cropped to the box (D53), read, and opens the food prefilled.
// The Simulator has no camera: the drawn sample stands in for the viewfinder.

struct FoodScanFlow: View {
    var meal: MealSlot
    /// A meal photo was taken: the caller closes the camera and shows Today.
    var onMealPhoto: () -> Void
    var onManualAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var mock = FoodScanMock.shared
    @State private var path: [Step] = []

    enum Step: Hashable { case readingLabel, labelFood }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !mock.signedIn {
                    FoodScanSignIn(onCancel: { dismiss() }, onSignIn: { mock.signedIn = true }, onManual: manual)
                } else {
                    FoodScanCamera(initialMode: mock.initialMode, cameraAllowed: mock.cameraAllowed,
                                   onCancel: { dismiss() }, onShot: shot)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .readingLabel:
                    FoodScanReadingLabel(onCancel: { dismiss() }, onRetake: { path.removeAll() }) {
                        path.append(.labelFood)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                case .labelFood:
                    LabelFoodView(meal: meal, onRetake: { path.removeAll() }) { dismiss() }
                }
            }
        }
        .lookScreenBackground()
    }

    private func shot(_ mode: FoodScanMode) {
        switch mode {
        case .meal:
            mock.startPhoto(meal: meal)
            onMealPhoto()
        case .label: path.append(.readingLabel)
        case .barcode: break
        }
    }

    private func manual() {
        dismiss()
        onManualAdd()
    }
}

// MARK: - Camera

struct FoodScanCamera: View {
    var initialMode: FoodScanMode
    var cameraAllowed: Bool
    var onCancel: () -> Void
    var onShot: (FoodScanMode) -> Void
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: FoodScanMode = .meal
    @State private var torch = false
    @State private var flash = 0.0
    @State private var shutterTaps = 0

    var body: some View {
        GeometryReader { geo in
            let frame = framingRect(in: geo.size)
            ZStack {
                if camera.cameraAllowed {
                    viewfinder(frame: frame, size: geo.size)
                } else {
                    cameraOff
                }
                Color.white.opacity(flash).allowsHitTesting(false).ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    if camera.cameraAllowed {
                        glassLine(hint).padding(.bottom, 16)
                        modes.padding(.horizontal, look.space.margin).padding(.bottom, 14)
                        controls.padding(.horizontal, 30).padding(.bottom, 10)
                    } else {
                        cameraOffActions.padding(.horizontal, look.space.margin).padding(.bottom, 10)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { mode = camera.initialMode }
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

    // MARK: Viewfinder (the drawn sample stands in for the camera)

    private func viewfinder(frame: CGRect, size: CGSize) -> some View {
        ZStack {
            // The feed fills the screen without taking part in the layout (an image's own size would push the
            // controls off the screen).
            Group {
                if mode == .meal {
                    Color.black.overlay { Image(uiImage: FoodScanArt.meal).resizable().scaledToFill().scaleEffect(0.95) }
                } else {
                    // A package on the counter: the label (or its barcode) sits where the box is.
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
            .ignoresSafeArea()
            .accessibilityIdentifier("scanFoodViewfinder")
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
            side(symbol: "photo.on.rectangle", lit: false) { camera.onShot(mode) }
                .accessibilityLabel("Choose a photo")
                .accessibilityIdentifier("scanFoodLibrary")
            Spacer()
            if mode == .barcode {
                // A barcode is read as soon as it is in the band (N8): no shutter.
                Color.clear.frame(width: 88, height: 88)
            } else {
                Button(action: shoot) { EmptyView() }
                    .buttonStyle(ScanShutterStyle())
                    .accessibilityLabel("Take photo")
                    .accessibilityIdentifier("scanFoodShutter")
            }
            Spacer()
            side(symbol: torch ? "bolt.fill" : "bolt.slash", lit: torch) { torch.toggle() }
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

    private func shoot() {
        shutterTaps += 1
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.07)) { flash = 0.85 }
            withAnimation(.easeIn(duration: 0.35).delay(0.08)) { flash = 0 }
        }
        let shotMode = mode
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 250))
            camera.onShot(shotMode)
        }
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
            Text("Camera access is off")
                .font(look.font.title2)
                .foregroundStyle(look.onSlab)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Allow the camera in Settings, or choose a photo of your meal.")
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
            ScanPrimaryButton("Choose a photo", symbol: "photo.on.rectangle") { camera.onShot(.meal) }
                .accessibilityIdentifier("scanFoodLibrary")
            if let settings = URL(string: UIApplication.openSettingsURLString) {
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

/// The cropped label is the hero while it is read (a label is short work, so the camera's sheet waits for it here,
/// unlike a meal photo).
private struct FoodScanReadingLabel: View {
    var onCancel: () -> Void
    var onRetake: () -> Void
    var onRead: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Food label", onCancel: onCancel)
            ScanStepBody {
                ScanInlineTitle(title: "Food label")
                ScanPhotoHero(image: FoodScanArt.label, scanning: true)
                ScanProgressInstrument(title: "Reading the label…")
            } bar: {
                ScanBottomBar {
                    Button("Take another photo", action: onRetake)
                        .buttonStyle(.lookSecondary)
                        .accessibilityIdentifier("scanFoodRetake")
                }
            }
        }
        .lookScreenBackground()
        .task {
            // The mock's reply: the label in ~2.5 s (frozen for captures).
            guard !ProcessInfo.processInfo.arguments.contains("-scanFoodMockHoldLabel") else { return }
            try? await Task.sleep(for: .seconds(2.5))
            onRead()
        }
    }
}

// MARK: - The label's food

/// The Selected food screen (N4) prefilled from the label: the serving and every number as printed; the name is the
/// user's (a label has none). Log is the one primary; "Save to My foods" is on, so the next time it is one tap.
struct LabelFoodView: View {
    var meal: MealSlot
    var onRetake: () -> Void
    var onLogged: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var name = ProcessInfo.processInfo.arguments.contains("-scanFoodMockNamed") ? "Maple granola" : ""
    @State private var brand = ""
    @State private var servings = 1.0
    @State private var saveToMyFoods = true

    private let perServing = Macros(calories: 230, proteinGrams: 3, carbsGrams: 37, fatGrams: 8)
    private var named: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

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
            PrimaryButton("Log to \(meal.label)") {
                FoodScanMock.shared.logLabel(
                    name: name,
                    item: ScanMockItem(name: name, portion: "2/3 cup", grams: 55 * servings,
                                       calories: 230 * servings, protein: 3 * servings, carbs: 37 * servings,
                                       fat: 8 * servings),
                    meal: meal)
                onLogged()
            }
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
                Button("Retake", action: onRetake)
                    .accessibilityIdentifier("labelFoodRetake")
            }
        }
    }

    /// The label as read, small, beside the title: what the numbers came from.
    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(uiImage: FoodScanArt.label).resizable().scaledToFill()
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
                .accessibilityHidden(true)
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
            LookRow("Serving", symbol: "scalemass", value: "2/3 cup (55 g)", showsChevron: false)
            LookRow("Servings per container", symbol: "shippingbox", value: "8", showsChevron: false)
        }
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            step("minus", label: "Fewer servings", enabled: servings > 0.5) { servings = max(0.5, servings - 0.5) }
            Text(servings.formatted(.number.precision(.fractionLength(0...2))))
                .font(look.font.statNumber).monospacedDigit().frame(minWidth: 44)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: servings))
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

    /// Shown open: the label printed them, so they are part of what to check.
    private var otherFacts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other nutrition facts").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
            fact("Saturated fat", 1, "g")
            fact("Fiber", 4, "g")
            fact("Sugar", 12, "g")
            fact("Sodium", 160, "mg")
        }
        .padding(16)
        .lookSurface(.panel)
    }

    private func fact(_ title: String, _ value: Double, _ unit: String) -> some View {
        HStack {
            Text(title).foregroundStyle(look.textSecondary)
            Spacer()
            Text("\((value * servings).formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                .monospacedDigit().foregroundStyle(look.textPrimary)
        }
        .font(look.font.subhead)
    }
}
