import SwiftUI
import UIKit

// Floodlight redesign ticket 07 — the Scan Machine sheet's steps other than the result:
// consent (S02, before the camera — user decision 2), no key, camera (S01), identifying (S03),
// error (S03 failure) and Added. The sheet (IdentifyEquipmentSheet) owns every piece of state;
// these only draw it and call back.

// MARK: - Consent (S02)

/// What leaves the phone: the photo you are about to take (a camera glyph — nothing is taken
/// yet) with the exercise catalog clipped to it, drawn travelling to OpenAI; four parallel
/// facts, split by their glyphs into what is sent (a filled disc with an up-arrow badge) and what
/// is not kept or is yours (an open disc); the policy link last. "Allow photos and continue" is
/// the one filled command.
struct ScanConsentStep: View {
    var onCancel: () -> Void
    var onAllow: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var allowTaps = 0

    private static let policyURL = URL(string: "https://developers.openai.com/api/docs/guides/your-data")!

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanPagedScroll(centered: !typeSize.isAccessibilitySize) {
                VStack(alignment: .leading, spacing: 20) {
                    ScanInlineTitle(title: "Scan Machine")
                    dataPath.padding(.top, 4)
                    Text("Send equipment photos to OpenAI?")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    facts
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 20)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Allow photos and continue", symbol: "checkmark") {
                        allowTaps += 1
                        onAllow()
                    }
                    .accessibilityIdentifier("allowAIPhotos")
                }
            }
        }
        .sensoryFeedback(.success, trigger: allowTaps)
    }

    private var dataPath: some View {
        HStack(alignment: .center, spacing: 0) {
            ScanPhotoTile(image: nil, cornerRadius: look.radius.tile)
                .frame(width: photoWidth, height: photoWidth * 1.22)
                .overlay(alignment: .bottomTrailing) {
                    // The exercise catalog travels with the photo: a flat badge, cut out of the
                    // tile by a ring of the sheet's ground.
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(look.surfaceRaised))
                        .overlay { Circle().strokeBorder(look.groundSheet, lineWidth: 3) }
                        .offset(x: 14, y: 12)
                }
            ScanFlowConnector()
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.leading, 24)
                .padding(.trailing, 10)
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: discSide * 0.36, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .frame(width: discSide, height: discSide)
                    .background(look.surfaceRaised, in: Circle())
                Text("OpenAI")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
            }
            .padding(.top, 26)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Each photo and the exercise catalog are sent to OpenAI")
    }

    private var photoWidth: CGFloat { typeSize.isAccessibilitySize ? 96 : 128 }
    private var discSide: CGFloat { typeSize.isAccessibilitySize ? 76 : 100 }

    private var facts: some View {
        VStack(spacing: 0) {
            ScanFactRow(symbol: "photo", sent: true, text: "The full photo, including any people or screens in frame")
            LookDivider().padding(.leading, 62)
            ScanFactRow(symbol: "list.bullet.rectangle", sent: true, text: "The exercise catalog")
            LookDivider().padding(.leading, 62)
            ScanFactRow(symbol: "square.and.arrow.down.badge.xmark", sent: false, text: "Photo not saved by the app")
            LookDivider().padding(.leading, 62)
            ScanFactRow(symbol: "key", sent: false, text: "Billed to your OpenAI API key")
            LookDivider()
            Link(destination: Self.policyURL) {
                HStack(spacing: 6) {
                    Text("OpenAI data policies")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right").font(.system(.footnote, weight: .bold))
                }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
    }
}

/// One fact. Sent: a filled disc with a small up-arrow badge. Not sent / yours: an open disc.
private struct ScanFactRow: View {
    var symbol: String
    var sent: Bool
    var text: String
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 32

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            glyph.alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
            Text(text)
                .font(look.font.body)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sent ? "Sent: \(text)" : text)
    }

    private var glyph: some View {
        Image(systemName: symbol)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(sent ? look.surfaceSheet : look.textSecondary)
            .frame(width: disc, height: disc)
            .background {
                if sent { Circle().fill(look.textPrimary) } else { Circle().strokeBorder(look.hairline, lineWidth: 1.2) }
            }
            .overlay(alignment: .topTrailing) {
                if sent {
                    Image(systemName: "arrow.up")
                        .font(.system(size: disc * 0.28, weight: .heavy))
                        .foregroundStyle(look.textPrimary)
                        .frame(width: disc * 0.46, height: disc * 0.46)
                        .background(look.surfaceSheet, in: Circle())
                        .overlay { Circle().strokeBorder(look.surfaceSheet, lineWidth: 2) }
                        .offset(x: disc * 0.14, y: -disc * 0.12)
                }
            }
            .padding(.trailing, 2)
            .accessibilityHidden(true)
    }
}

/// A dashed arrow from the photo to OpenAI. When the step appears a dot runs along it twice to
/// show where the photo would go, then rests. Reduce Motion: no dot.
private struct ScanFlowConnector: View {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travel: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let y = geo.size.height / 2
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width - 8, y: y))
                }
                .stroke(look.textTertiary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 6]))
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .heavy))
                    .foregroundStyle(look.textSecondary)
                    .position(x: geo.size.width - 5, y: y)
                if !reduceMotion {
                    Circle()
                        .fill(look.live)
                        .frame(width: 9, height: 9)
                        .position(x: travel * (geo.size.width - 14), y: y)
                        .opacity(1 - Double(travel))
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatCount(2, autoreverses: false).delay(0.4)) { travel = 1 }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - No key

/// Without a key nothing can be identified: the key is the step's subject, "Open AI Settings"
/// the one filled command, the catalog the way out.
struct ScanNoKeyStep: View {
    var onCancel: () -> Void
    var onSettings: () -> Void
    var onManual: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanPagedScroll(centered: true) {
                VStack(spacing: 22) {
                    ScanGlyphDisc(symbol: "key.fill", size: typeSize.isAccessibilitySize ? 88 : 108,
                                  glyphFont: .system(size: typeSize.isAccessibilitySize ? 34 : 42, weight: .semibold))
                    Text("Add your OpenAI API key to identify equipment with Terra.")
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, look.space.margin + 8)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Open AI Settings", symbol: "key", action: onSettings)
                        .accessibilityIdentifier("scannerAISettings")
                    Button("Choose a catalog model", action: onManual)
                        .buttonStyle(.lookSecondary)
                        .accessibilityIdentifier("scanManual")
                }
            }
        }
    }
}

// MARK: - Camera (S01)

/// The viewfinder, always dark. The one bold element is the violet shutter; the framing brackets
/// are a guide only — the whole photo is sent (D56), unlike Read Label's plate box. The gym chip
/// carries the gym's machine count, so the scan's target is visible before Add. Camera
/// unavailable: the stated reason, and "Choose a photo instead" becomes the filled command.
struct ScanCameraStep: View {
    var gymName: String?
    var machineCount: Int
    var started: Bool
    var notice: String?
    var captureID: UUID?
    @Binding var torch: Bool
    var onCancel: () -> Void
    var onShutter: () -> Void
    var onLibrary: () -> Void
    var onPhoto: (CapturedLabel) -> Void
    var onFailure: (UUID?, String) -> Void
    @Environment(\.look) private var look

    var body: some View {
        ScanCameraContent(step: self)
            .environment(\.look, look.darkCounterpart)
            .environment(\.colorScheme, .dark)
    }
}

private struct ScanCameraContent: View {
    var step: ScanCameraStep
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = 0.0
    @State private var framed = false
    @State private var shutterTaps = 0

    private var availability: CaptureAvailability { CaptureAvailability.resolve() }
    private var cameraUsable: Bool { TerraAccess.fixture || availability == .camera }

    var body: some View {
        GeometryReader { geo in
            let frame = framingRect(in: geo.size)
            ZStack {
                if cameraUsable {
                    viewfinder(frame: frame, size: geo.size)
                } else {
                    cameraOffView
                }
                Color.white.opacity(flash).allowsHitTesting(false).ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    if cameraUsable {
                        if let notice = step.notice {
                            glassLine(notice).padding(.bottom, 10)
                                .accessibilityIdentifier("scanCameraNotice")
                        }
                        glassLine("Scan a machine or its label").padding(.bottom, 18)
                        controls
                            .padding(.horizontal, 30)
                            .padding(.bottom, 14)
                    } else {
                        cameraOffActions
                            .padding(.horizontal, look.space.margin)
                            .padding(.bottom, 10)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { framed = true; return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.15)) { framed = true }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterTaps)
        .sensoryFeedback(.selection, trigger: step.torch)
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
    }

    // MARK: Viewfinder

    @ViewBuilder
    private func viewfinder(frame: CGRect, size: CGSize) -> some View {
        ZStack {
            if TerraAccess.fixture {
                // The Simulator has no camera: the fixture's rendered plate stands in for it.
                Image(uiImage: ScanFixture.image())
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.8)
                    .accessibilityIdentifier("scanFixtureCamera")
            } else if step.started {
                LabelCameraView(captureRequest: step.captureID, onPhoto: step.onPhoto,
                                onFailure: step.onFailure, torchOn: step.torch)
                    .ignoresSafeArea(edges: .bottom)
            }
            // Dim outside the brackets, then the brackets.
            Path { p in
                p.addRect(CGRect(x: 0, y: 0, width: size.width, height: size.height + 120))
                p.addRoundedRect(in: frame, cornerSize: CGSize(width: 22, height: 22), style: .continuous)
            }
            .fill(Color.black.opacity(0.34), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)
            ScanFrameCorners(length: 38, radius: 3)
                .stroke(look.done, style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .miter))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .scaleEffect(framed || reduceMotion ? 1 : 1.1,
                             anchor: UnitPoint(x: frame.midX / max(1, size.width), y: frame.midY / max(1, size.height)))
                .opacity(framed || reduceMotion ? 1 : 0.35)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func framingRect(in size: CGSize) -> CGRect {
        let width = min(size.width - 64, 380)
        let height = min(width * 1.22, size.height * 0.5)
        return CGRect(x: (size.width - width) / 2, y: size.height * 0.43 - height / 2, width: width, height: height)
    }

    // MARK: Camera unavailable

    private var cameraOffView: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(look.onSlab)
                .frame(width: 88, height: 88)
                .background(look.onSlab.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(availability == .cameraDenied ? "Camera access is off" : "No camera")
                .font(look.font.title2)
                .foregroundStyle(look.onSlab)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let reason = step.notice ?? availability.reason {
                Text(reason)
                    .font(look.font.subhead)
                    .foregroundStyle(look.onSlabSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("scanCameraNotice")
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -40)
    }

    private var cameraOffActions: some View {
        VStack(spacing: 10) {
            ScanPrimaryButton("Choose a photo instead", symbol: "photo.on.rectangle", action: step.onLibrary)
                .accessibilityIdentifier("scanChoosePhoto")
            if availability.settingsCanHelp, let settings = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settings)
                    .buttonStyle(.lookSecondary)
            }
        }
    }

    // MARK: Chrome

    /// The gym chip sits centred between Cancel and the trailing edge; at accessibility sizes it
    /// takes its own line under Cancel, so the gym's name never truncates.
    @ViewBuilder private var topBar: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                GlassCapsuleButton("Cancel", action: step.onCancel).accessibilityIdentifier("scanCancel")
                gymChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
        } else {
            ZStack {
                gymChip.padding(.horizontal, 104)
                HStack {
                    GlassCapsuleButton("Cancel", action: step.onCancel).accessibilityIdentifier("scanCancel")
                    Spacer()
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
        }
    }

    @ViewBuilder private var gymChip: some View {
        if let gymName = step.gymName {
            HStack(spacing: 6) {
                Image(systemName: look.gymSymbol).font(.system(.footnote, weight: .semibold))
                Text(gymName).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                Text("·").font(.system(.subheadline, weight: .semibold)).opacity(0.6)
                Text("\(step.machineCount)")
                    .font(.system(.subheadline, weight: .heavy).width(.expanded))
                    .monospacedDigit()
            }
            .foregroundStyle(look.onSlab)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .glassEffect(.regular.tint(.black.opacity(0.3)), in: Capsule())
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(gymName), \(step.machineCount) \(step.machineCount == 1 ? "machine" : "machines")")
        }
    }

    private var controls: some View {
        HStack {
            ScanCameraSideButton(symbol: "photo.on.rectangle", lit: false, action: step.onLibrary)
                .accessibilityLabel("Choose a photo instead")
                .accessibilityIdentifier("scanChoosePhoto")
            Spacer()
            Button(action: shoot) { EmptyView() }
                .buttonStyle(ScanShutterStyle())
                .disabled(step.captureID != nil)
                .accessibilityLabel("Take photo")
                .accessibilityIdentifier("scanShutter")
            Spacer()
            ScanCameraSideButton(symbol: step.torch ? "bolt.fill" : "bolt.slash", lit: step.torch) { step.torch.toggle() }
                .disabled(TerraAccess.fixture)
                .accessibilityLabel("Flash")
                .accessibilityValue(step.torch ? "On" : "Off")
        }
    }

    private func shoot() {
        shutterTaps += 1
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.07)) { flash = 0.85 }
            withAnimation(.easeIn(duration: 0.35).delay(0.08)) { flash = 0 }
        }
        step.onShutter()
    }
}

/// The two side controls share one shape: a 54 pt glass circle. Lit (the torch on) fills it.
private struct ScanCameraSideButton: View {
    var symbol: String
    var lit: Bool
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
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
}

/// The shutter: a white ring around the violet disc, which presses in. Reduce Motion: an
/// opacity dip.
struct ScanShutterStyle: ButtonStyle {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        ZStack {
            Circle().strokeBorder(look.onSlab, lineWidth: 4).frame(width: 82, height: 82)
            Circle()
                .fill(look.action)
                .frame(width: 64, height: 64)
                .scaleEffect(pressed && !reduceMotion ? 0.88 : 1)
                .opacity(reduceMotion && pressed ? 0.7 : (isEnabled ? 1 : 0.45))
        }
        .frame(width: 88, height: 88)
        .contentShape(Circle())
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}

// MARK: - Identifying (S03)

/// The photo just taken is the hero, a live beam sweeps it, and the instrument says "working"
/// without pretending to know how far along a network call is.
struct ScanIdentifyingStep: View {
    var photo: UIImage?
    var onCancel: () -> Void
    var onRetake: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanStepBody {
                ScanInlineTitle(title: "Scan Machine")
                ScanPhotoHero(image: photo, scanning: true)
                ScanProgressInstrument(title: "Identifying equipment…")
            } bar: {
                ScanBottomBar {
                    Button("Take another photo", action: onRetake)
                        .buttonStyle(.lookSecondary)
                        .accessibilityIdentifier("scanRescan")
                }
            }
        }
    }
}

// MARK: - Error (S03 failure)

/// The same photo, stilled and greyed under a stamped "!", the real error in a dashed card,
/// "Take another photo" the one filled command.
struct ScanErrorStep: View {
    var photo: UIImage?
    var message: String
    var onCancel: () -> Void
    var onRetake: () -> Void
    var onManual: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var failures = 0

    /// The error copy, its last clause matched to the button beside it.
    private var shownMessage: String {
        message.replacingOccurrences(of: "continue manually", with: "choose a catalog model")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanStepBody {
                ScanInlineTitle(title: "Scan Machine")
                ScanPhotoHero(image: photo, scanning: false, failed: true)
                errorCard
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Take another photo", symbol: "camera", action: onRetake)
                        .accessibilityIdentifier("scanRescan")
                    if !typeSize.isAccessibilitySize { manualButton }
                }
            } trailing: {
                // At accessibility sizes only the primary stays pinned.
                if typeSize.isAccessibilitySize { manualButton }
            }
        }
        .onAppear { failures += 1 }
        .sensoryFeedback(.error, trigger: failures)
    }

    private var manualButton: some View {
        Button("Choose a catalog model", action: onManual)
            .buttonStyle(.lookSecondary)
            .accessibilityIdentifier("scanManual")
    }

    private var errorCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(look.groundSheet)
                .frame(width: 46, height: 46)
                .background(look.textPrimary, in: Circle())
                .accessibilityHidden(true)
            Text(shownMessage)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("scanAIError")
            Spacer(minLength: 0)
        }
        .padding(look.space.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.surfaceSheet, in: RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .dashedOutline(look.textSecondary, radius: look.radius.panel, lineWidth: 1.5, dash: [6, 4])
    }
}

// MARK: - Added

/// The machine was added: the check stamps in (its ring runs out once), the new machine is shown
/// as a card with the photo it came from, and the gym's machine count ticks up, so the scan
/// visibly changed something. Reduce Motion: all of it is simply there.
struct ScanAddedStep: View {
    var machine: MachineInstance
    var photo: UIImage?
    var gymName: String
    var machineCount: Int
    var exerciseNames: [String]
    var onDone: () -> Void
    var onScanAnother: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var countShown: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScanPagedScroll(centered: true) {
                VStack(spacing: 18) {
                    ScanOutcomeDisc(outcome: .matched, size: typeSize.isAccessibilitySize ? 72 : 88, delay: 0.1, ripple: true)
                    Text("Added to \(gymName)")
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    card.padding(.top, 6)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        CountUpText(Double(countShown ?? machineCount), duration: 0.5, countsFromZero: false) {
                            "\(Int($0.rounded()))"
                        }
                        .font(look.font.bigNumber)
                        .monospacedDigit()
                        .foregroundStyle(look.textPrimary)
                        Text(machineCount == 1 ? "machine" : "machines")
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(machineCount) \(machineCount == 1 ? "machine" : "machines") at \(gymName)")
                    .onAppear {
                        guard !reduceMotion, machineCount > 0 else { return }
                        countShown = machineCount - 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { countShown = machineCount }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 12)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Done", symbol: "checkmark", action: onDone)
                        .accessibilityIdentifier("scanDone")
                    Button("Scan another machine", action: onScanAnother)
                        .buttonStyle(.lookSecondary)
                        .accessibilityIdentifier("scanAnother")
                }
            }
        }
        .padding(.top, 10)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScanPhotoTile(image: photo, cornerRadius: 0)
                .frame(height: typeSize.isAccessibilitySize ? 150 : 176)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    LookIcon(LookIcon.machine, style: .headline)
                        .foregroundStyle(look.textSecondary)
                    Text(machine.label)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(machine.model?.displayName ?? "No model")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !exerciseNames.isEmpty {
                    Text(exerciseNames.joined(separator: ", "))
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(look.space.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
    }
}
