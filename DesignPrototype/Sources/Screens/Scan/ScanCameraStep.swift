import SwiftUI

// S01 — the viewfinder. A viewfinder is always dark, so Paper borrows its own dark finish
// (Carbon copy) here; A, B and Carbon use their own tokens. The one bold element is the
// shutter (A Ultra, B pearl, C cobalt with its hard shadow). The framing box is the look's own
// mark: A square flood-white brackets, B soft pearl corners with a glow, C cobalt corners.
// The gym chip carries the gym's machine count, so the scan's target is visible before Add.
// Tap the image to focus; the torch lights the machine; the shutter flashes and hands the
// frame to the next step. The photo-library button is simulated: it sends the same photo.
// Camera access off: the viewfinder is replaced by the stated reason, the shutter is gone and
// "Choose a photo instead" becomes the filled command.

struct ScanCameraStep: View {
    var gymName: String
    var machineCount: Int
    var photoSpace: Namespace.ID
    @Binding var cameraOff: Bool
    var onCancel: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        ScanCameraContent(gymName: gymName, machineCount: machineCount, photoSpace: photoSpace,
                          cameraOff: $cameraOff, onCancel: onCancel)
            .environment(\.look, look.darkCounterpart)
            .environment(\.colorScheme, .dark)
    }
}

private struct ScanCameraContent: View {
    var gymName: String
    var machineCount: Int
    var photoSpace: Namespace.ID
    @Binding var cameraOff: Bool
    var onCancel: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScanReduceMotion private var reduceMotion
    @State private var flash = 0.0
    @State private var focus: CGPoint?
    @State private var focusTick = 0
    @State private var framed = false
    @State private var shutterTaps = 0
    @State private var focusTaps = 0

    var body: some View {
        GeometryReader { geo in
            let frame = framingRect(in: geo.size)
            ZStack {
                if cameraOff {
                    cameraOffView
                        .transition(.opacity)
                } else {
                    viewfinder(frame: frame, size: geo.size)
                        .transition(.opacity)
                }

                Color.white.opacity(flash).allowsHitTesting(false).ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    if !cameraOff {
                        Text("Scan a machine or its label")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(look.onSlab)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .glassEffect(.regular.tint(.black.opacity(0.35)), in: Capsule())
                            .padding(.horizontal, 24)
                            .padding(.bottom, 18)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: cameraOff)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { framed = true; return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.15)) { framed = true }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterTaps)
        .sensoryFeedback(.selection, trigger: focusTaps)
        .sensoryFeedback(.selection, trigger: store.scan.torchOn)
    }

    // MARK: Viewfinder

    @ViewBuilder
    private func viewfinder(frame: CGRect, size: CGSize) -> some View {
        ZStack {
            ScanScene(torchOn: store.scan.torchOn, plateText: store.scan.demoKind.scanPlateText,
                      subject: subjectRect(in: frame))
                .matchedGeometryEffect(id: "scanPhoto", in: photoSpace)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in focusAt(location) }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: store.scan.torchOn)
                .ignoresSafeArea(edges: .bottom)
                .accessibilityElement()
                .accessibilityLabel("Viewfinder")
                .accessibilityHint("Double-tap to focus")

            // Dim outside the framing box, then the box itself.
            Path { p in
                p.addRect(CGRect(x: 0, y: 0, width: size.width, height: size.height + 120))
                p.addRoundedRect(in: frame, cornerSize: CGSize(width: 22, height: 22), style: .continuous)
            }
            .fill(Color.black.opacity(0.34), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)

            framingBox
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .scaleEffect(framed || reduceMotion ? 1 : 1.1, anchor: UnitPoint(x: frame.midX / max(1, size.width),
                                                                                y: frame.midY / max(1, size.height)))
                .opacity(framed || reduceMotion ? 1 : 0.35)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if let focus {
                ScanFocusSquare(tick: focusTick)
                    .position(focus)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The look's framing mark.
    @ViewBuilder private var framingBox: some View {
        switch look.id {
        case .floodlight:
            // Scoreboard brackets: square, flood white, heavy.
            ScanFrameCorners(length: 38, radius: 3)
                .stroke(look.done, style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .miter))
        case .anatomy:
            // Soft pearl corners with a glow.
            ScanFrameCorners(length: 30, radius: 24)
                .stroke(look.live, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .shadow(color: look.live.opacity(0.7), radius: 8)
        case .paper, .carbon:
            // Cobalt corners over a thin ink edge.
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(look.onSlab.opacity(0.28), lineWidth: 1)
                ScanFrameCorners(length: 34, radius: 22)
                    .stroke(look.actionText, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// The machine fills the framing box: a square, visually centred (its drawing starts 12 %
    /// down its box, so the box sits a little high).
    private func subjectRect(in frame: CGRect) -> CGRect {
        let side = min(frame.width, frame.height) * 0.92
        return CGRect(x: frame.midX - side / 2, y: frame.midY - side / 2 - side * 0.05, width: side, height: side)
    }

    private func framingRect(in size: CGSize) -> CGRect {
        let width = min(size.width - 64, 380)
        let height = min(width * 1.22, size.height * 0.56)
        return CGRect(x: (size.width - width) / 2, y: size.height * 0.45 - height / 2, width: width, height: height)
    }

    // MARK: Camera access off

    private var cameraOffView: some View {
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
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -40)
    }

    private var cameraOffActions: some View {
        VStack(spacing: 10) {
            ScanPrimaryButton("Choose a photo instead", symbol: "photo.on.rectangle") { chooseFromLibrary() }
            Button("Open Settings") { cameraOff = false }
                .buttonStyle(.lookSecondary)
        }
    }

    // MARK: Chrome

    /// The gym chip sits centred between Cancel and the trailing slot; at accessibility sizes
    /// it takes its own line under them, so the gym name never truncates.
    @ViewBuilder private var topBar: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    GlassCapsuleButton("Cancel", action: onCancel)
                    Spacer(minLength: 4)
                    ScanDemoMenu(cameraOff: $cameraOff)
                }
                gymChip
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
        } else {
            ZStack {
                gymChip.padding(.horizontal, 104)
                HStack(spacing: 10) {
                    GlassCapsuleButton("Cancel", action: onCancel)
                    Spacer(minLength: 4)
                    ScanDemoMenu(cameraOff: $cameraOff)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
        }
    }

    private var gymChip: some View {
            HStack(spacing: 6) {
                Image(systemName: look.gymSymbol).font(.system(.footnote, weight: .semibold))
                Text(gymName).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                Text("·").font(.system(.subheadline, weight: .semibold)).opacity(0.6)
                Text("\(machineCount)")
                    .font(.system(.subheadline, weight: .heavy).width(look.id == .anatomy ? .standard : .expanded))
                    .fontDesign(look.id == .anatomy ? .rounded : .default)
                    .monospacedDigit()
            }
            .foregroundStyle(look.onSlab)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .glassEffect(.regular.tint(.black.opacity(0.3)), in: Capsule())
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(gymName), \(machineCount) machines")
    }

    private var controls: some View {
        HStack {
            ScanCameraSideButton(symbol: "photo.on.rectangle", lit: false, action: chooseFromLibrary)
                .accessibilityLabel("Choose a photo instead")

            Spacer()

            Button(action: shoot) { EmptyView() }
                .buttonStyle(ScanShutterStyle())
                .accessibilityLabel("Take photo")

            Spacer()

            ScanCameraSideButton(symbol: store.scan.torchOn ? "bolt.fill" : "bolt.slash",
                                 lit: store.scan.torchOn) { store.scanToggleTorch() }
                .accessibilityLabel("Flash")
                .accessibilityValue(store.scan.torchOn ? "On" : "Off")
        }
    }

    // MARK: Actions

    private func shoot() {
        shutterTaps += 1
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { store.scanShutter() }
            return
        }
        withAnimation(.easeOut(duration: 0.07)) { flash = 0.85 }
        withAnimation(.easeIn(duration: 0.35).delay(0.08)) { flash = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { store.scanShutter() }
        }
    }

    /// PROTOTYPE: the system photo library is simulated; the picked photo is the same machine.
    private func chooseFromLibrary() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { store.scanShutter() }
    }

    private func focusAt(_ point: CGPoint) {
        focus = point
        focusTick += 1
        focusTaps += 1
    }
}

/// The two side controls share one shape: a 54 pt glass circle. Lit (the torch on) fills it
/// with the viewfinder's ink.
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

/// The tap-to-focus square: it lands from 1.4× and fades after a beat. Reduce Motion: it
/// appears and fades without scaling.
private struct ScanFocusSquare: View {
    var tick: Int
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(look.live, lineWidth: 1.5)
            .frame(width: 76, height: 76)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear(perform: play)
            .onChange(of: tick) { _, _ in play() }
            .accessibilityHidden(true)
    }

    private func play() {
        scale = reduceMotion ? 1 : 1.4
        opacity = 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { scale = 1 }
        withAnimation(.easeOut(duration: 0.4).delay(1.0)) { opacity = 0 }
    }
}

/// The shutter: a ring around the look's filled command. A/B press in (0.9); C's cobalt disc
/// sinks into its hard offset shadow. Reduce Motion: an opacity dip.
private struct ScanShutterStyle: ButtonStyle {
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let isC = look.id.isPaperClub
        ZStack {
            Circle()
                .strokeBorder(look.onSlab, lineWidth: 4)
                .frame(width: 82, height: 82)
            ZStack {
                if isC {
                    Circle().fill(look.shadowInk).offset(x: 4, y: 4)
                }
                Circle()
                    .fill(look.action)
                    .overlay { if isC { Circle().strokeBorder(look.outline, lineWidth: 2.5) } }
                    .offset(x: isC && pressed && !reduceMotion ? 4 : 0, y: isC && pressed && !reduceMotion ? 4 : 0)
            }
            .frame(width: 64, height: 64)
            .scaleEffect(!isC && pressed && !reduceMotion ? 0.88 : 1)
            .opacity(reduceMotion && pressed ? 0.7 : 1)
        }
        .frame(width: 88, height: 88)
        .contentShape(Circle())
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}
