import SwiftUI

// Scan area helpers (area-prefixed; candidates for promotion to Look/ or Model/): the captured
// photo tile and its plate loupe, the framing box, the sheet's top and bottom bars, the primary
// with its neutral disabled face, the outcome stamp, the confidence meter, the p2/p3 capture
// scroll and a Reduce Motion override for capture variants. The drawing itself is ScanScene.swift.

// MARK: - Environment

extension EnvironmentValues {
    /// True while scrolled content is hidden under the pinned bottom bar (the bar draws its
    /// hairline only then).
    @Entry var scanContentUnderBar = false
    /// PROTOTYPE: the "rm" capture variant renders the Reduce Motion stills without changing
    /// the simulator's settings.
    @Entry var scanForcedReduceMotion = false
}

/// Reduce Motion as the scan screens read it: the system setting, or the "rm" capture variant.
@propertyWrapper
struct ScanReduceMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.scanForcedReduceMotion) private var forced
    init() {}
    var wrappedValue: Bool { system || forced }
}

// MARK: - The captured photo

/// The captured photo, shown back in the sheet (consent, identifying, result, confirmed).
/// With `loupeText` the name plate the AI read is outlined and lifted out as a zoomed label.
struct ScanPhotoTile: View {
    var plateText: String?
    var plateHighlight: Color?
    var loupeText: String? = nil
    var cornerRadius: CGFloat
    var dimmed = false

    var body: some View {
        ScanScene(torchOn: false, plateText: plateText, plateHighlight: loupeText == nil ? nil : plateHighlight)
            .overlay {
                if let loupeText, let plateHighlight {
                    ScanPlateLoupe(text: loupeText, highlight: plateHighlight)
                }
            }
            .saturation(dimmed ? 0 : 1)
            .brightness(dimmed ? -0.12 : 0)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isImage)
    }

    private var accessibilityText: String {
        guard let loupeText else { return ScanSimulator.photoCaption }
        return "\(ScanSimulator.photoCaption). Read on the machine: \(loupeText.replacingOccurrences(of: "  ", with: " "))"
    }
}

extension ScanKind {
    /// The name-plate text drawn on the simulated machine for this demo answer: the same words
    /// the loupe lifts out, so the zoom is honest.
    var scanPlateText: String? {
        switch self {
        case .specific: "MATRIX MG-PL71"
        case .ambiguous: "WATSON"
        case .newModel: "ROGUE MONSTER"
        case .generic: nil
        }
    }
}

// MARK: - Framing box

/// Four rounded L corners: the framing box over the viewfinder and the captured photo.
struct ScanFrameCorners: Shape {
    var length: CGFloat = 30
    var radius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let l = min(length, rect.width / 3, rect.height / 3)
        let r = min(radius, l - 4)
        var p = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1), (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1), (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, sx, sy) in corners {
            p.move(to: CGPoint(x: corner.x, y: corner.y + sy * l))
            p.addLine(to: CGPoint(x: corner.x, y: corner.y + sy * r))
            p.addQuadCurve(to: CGPoint(x: corner.x + sx * r, y: corner.y), control: corner)
            p.addLine(to: CGPoint(x: corner.x + sx * l, y: corner.y))
        }
        return p
    }
}

/// A live scan beam sweeping over a frame (identifying). Reduce Motion: a still beam resting
/// across the middle of the frame over a faint wash (what was being read, without movement).
struct ScanSweep: View {
    var color: Color
    @ScanReduceMotion private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                ZStack {
                    color.opacity(0.07)
                    beam.frame(width: geo.size.width).position(x: geo.size.width / 2, y: geo.size.height * 0.5)
                }
            } else {
                TimelineView(.animation) { timeline in
                    let period = 2.4
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    let tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2
                    let eased = (1 - cos(tri * .pi)) / 2
                    beam
                        .frame(width: geo.size.width)
                        .position(x: geo.size.width / 2, y: eased * geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var beam: some View {
        ZStack {
            LinearGradient(colors: [color.opacity(0), color.opacity(0.32), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 96)
            Rectangle().fill(color).frame(height: 2).shadow(color: color, radius: 6)
        }
    }
}

// MARK: - Sheet chrome

/// Cancel on glass, the title centred. The trailing slot is optional (torch, demo menu).
/// At accessibility sizes A and C take the title out of the bar (look API §5): the step puts
/// `ScanInlineTitle` first in its scroll content, so the title scrolls away with it instead of
/// staying as fixed chrome. B keeps it in the bar and lets it shrink first.
struct ScanTopBar<Trailing: View>: View {
    var title: String?
    var cancelTitle = "Cancel"
    var onCancel: () -> Void
    @ViewBuilder var trailing: Trailing
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Keeps the centred title clear of the Cancel capsule, which grows up to xxxLarge.
    @ScaledMetric(relativeTo: .headline) private var sideInset: CGFloat = 104

    init(title: String?, cancelTitle: String = "Cancel", onCancel: @escaping () -> Void,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            if let title, !ScanInlineTitle.isInline(look: look, typeSize: typeSize) {
                Text(title)
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, min(sideInset, 138))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityAddTraits(.isHeader)
            }
            HStack {
                GlassCapsuleButton(cancelTitle, action: onCancel)
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

/// The step title as the first line of the scroll content, at accessibility sizes in A and C
/// only (elsewhere the title is in the bar, so this draws nothing).
struct ScanInlineTitle: View {
    var title: String
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    static func isInline(look: Look, typeSize: DynamicTypeSize) -> Bool {
        typeSize.isAccessibilitySize && look.id != .anatomy
    }

    var body: some View {
        if Self.isInline(look: look, typeSize: typeSize) {
            Text(title)
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// The pinned action area at the sheet's foot: a solid bar of the sheet's ground (nothing
/// half-shows through it), with a hairline only while content is hidden under it.
struct ScanBottomBar<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.look) private var look
    @Environment(\.scanContentUnderBar) private var underBar

    var body: some View {
        VStack(spacing: 10) { content }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background {
                look.groundSheet
                    .padding(.bottom, -80)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                LookDivider()
                    .opacity(underBar ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: underBar)
            }
    }
}

/// The step's one filled command. Enabled it is the look's `PrimaryButton`, except C at
/// accessibility sizes, where the icon disc would squeeze the label onto two lines: there the
/// glyph sits inline beside the label on the same capsule. Disabled it is a neutral capsule
/// (the raised cell fill, a dim label, no disc, no tint and no hard shadow) in every look.
struct ScanPrimaryButton: View {
    var title: String
    var symbol: String
    var enabled = true
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56

    init(_ title: String, symbol: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        if !enabled {
            Button(action: {}) { face(color: look.textTertiary) }
                .buttonStyle(.plain)
                .background(disabledFill, in: Capsule())
                .overlay { Capsule().strokeBorder(look.hairline, lineWidth: look.id.isPaperClub ? 1.5 : 1) }
                .disabled(true)
                .transition(.opacity)
        } else if look.id.isPaperClub && typeSize.isAccessibilitySize {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: symbol).font(.body.weight(.bold))
                    Text(title).multilineTextAlignment(.center)
                }
            }
            .buttonStyle(.lookPrimary)
        } else {
            PrimaryButton(title, symbol: symbol, action: action)
        }
    }

    private var disabledFill: Color {
        look.id.isPaperClub ? look.pressedFill : look.surfaceRaised
    }

    private func face(color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.body.weight(.semibold))
            Text(title).font(look.font.button).multilineTextAlignment(.center)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: look.id.isPaperClub ? height + 6 : height)
        .contentShape(Capsule())
    }
}

// MARK: - Outcome stamp

/// What the scan concluded, as a disc that stamps in like a completed set.
enum ScanOutcome: Equatable {
    case matched
    case choose(Int)
    /// The user picked one of several candidates: the count stays (it was ambiguous) and a small
    /// check lands on it, so a picked answer never looks like a confident match.
    case picked(Int)
    case newModel
    case generic
    case failed
}

/// Matched = lit / inked (the "done" fill); choose = an open ring with the count; picked = that
/// ring with a check badge; new model = the dashed "make one" edge; generic = a hollow ring;
/// failed = a solid inverse disc. Entry: A stamps (1.55×, −14°), B pops (0.55 → 1), C thunks
/// (1.7×, −16°); every look lands upright. `ripple` adds the finish ring that runs out once.
/// Reduce Motion: it is simply there.
struct ScanOutcomeDisc: View {
    var outcome: ScanOutcome
    var size: CGFloat
    var delay: Double = 0
    var ripple = false
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @State private var landed = false
    @State private var rippled = false
    @State private var badgeIn = false

    var body: some View {
        face
            .frame(width: size, height: size)
            .background {
                if ripple && !reduceMotion {
                    Circle()
                        .strokeBorder(look.id.isPaperClub ? look.textPrimary : look.done, lineWidth: 2)
                        .scaleEffect(rippled ? 1.9 : 1)
                        .opacity(rippled ? 0 : 0.8)
                }
            }
            .scaleEffect(landed || reduceMotion ? 1 : look.motion.stampScale)
            .rotationEffect(.degrees(landed || reduceMotion ? 0 : look.motion.stampRotation))
            .opacity(landed || reduceMotion ? 1 : 0)
            .onAppear { land() }
            .onChange(of: outcome) { old, new in
                guard !reduceMotion else { return }
                // Picking a candidate only lands the badge; the count disc stays put.
                if case .choose = old, case .picked = new { return }
                if case .picked = old, case .choose = new { return }
                landed = false
                land()
            }
            .accessibilityHidden(true)
    }

    private func land() {
        guard !reduceMotion else { landed = true; badgeIn = true; return }
        let spring: Animation = look.id == .anatomy ? .spring(response: 0.42, dampingFraction: 0.55)
                                                    : .spring(response: 0.34, dampingFraction: 0.62)
        withAnimation(spring.delay(delay)) { landed = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55).delay(delay + 0.12)) { badgeIn = true }
        if ripple {
            rippled = false
            withAnimation(.easeOut(duration: 0.6).delay(delay + 0.18)) { rippled = true }
        }
    }

    @ViewBuilder private var face: some View {
        let glyphFont = Font.system(size: size * 0.42, weight: .heavy)
        switch outcome {
        case .matched:
            Image(systemName: "checkmark")
                .font(glyphFont)
                .foregroundStyle(look.onDone)
                .frame(width: size, height: size)
                .background(look.done, in: Circle())
        case .choose(let count):
            countRing(count)
        case .picked(let count):
            countRing(count)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.2, weight: .heavy))
                        .foregroundStyle(look.onDone)
                        .frame(width: size * 0.4, height: size * 0.4)
                        .background(look.done, in: Circle())
                        .overlay { Circle().strokeBorder(look.surfaceSheet, lineWidth: 3) }
                        .offset(x: size * 0.06, y: size * 0.06)
                        .scaleEffect(badgeIn || reduceMotion ? 1 : 0.2)
                        .opacity(badgeIn || reduceMotion ? 1 : 0)
                        .onAppear {
                            guard !reduceMotion else { return }
                            badgeIn = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.05)) { badgeIn = true }
                        }
                }
        case .newModel:
            Image(systemName: "plus")
                .font(glyphFont)
                .foregroundStyle(look.textPrimary)
                .frame(width: size, height: size)
                .overlay {
                    Circle().strokeBorder(look.id.isPaperClub ? look.outline : look.textSecondary,
                                          style: StrokeStyle(lineWidth: look.id.isPaperClub ? 2.5 : 2, dash: [6, 4]))
                }
        case .generic:
            Image(systemName: "questionmark")
                .font(glyphFont)
                .foregroundStyle(look.textSecondary)
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(look.textTertiary, lineWidth: 2) }
        case .failed:
            Image(systemName: "exclamationmark")
                .font(glyphFont)
                .foregroundStyle(look.id == .carbon ? look.ground : look.groundSheet)
                .frame(width: size, height: size)
                .background(look.textPrimary, in: Circle())
        }
    }

    private func countRing(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: size * 0.44, weight: .heavy).width(look.id == .anatomy ? .standard : .expanded))
            .fontDesign(look.id == .anatomy ? .rounded : .default)
            .foregroundStyle(look.textPrimary)
            .frame(width: size, height: size)
            .background(look.id == .anatomy ? look.controlFill : Color.clear, in: Circle())
            .overlay { Circle().strokeBorder(look.textPrimary, lineWidth: look.id.isPaperClub ? 2.5 : 2) }
    }
}

/// A flat glyph disc for things you cannot press (C's 2 pt ink outline is reserved for
/// pressable things): a quiet fill, no outline, in every look.
struct ScanGlyphDisc: View {
    var symbol: String
    var size: CGFloat
    /// An SF Symbol drawn at this font instead of the body-sized `LookIcon`.
    var glyphFont: Font? = nil
    @Environment(\.look) private var look

    var body: some View {
        glyph
            .foregroundStyle(look.textPrimary)
            .frame(width: size, height: size)
            .background(look.id.isPaperClub ? look.pressedFill : look.controlFill, in: Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder private var glyph: some View {
        if let glyphFont {
            Image(systemName: symbol).font(glyphFont)
        } else {
            LookIcon(symbol, style: .body, weight: .semibold)
        }
    }
}

// MARK: - Duplicates

/// Whether the scanned model is already a machine at this gym (the audit's missing duplicate
/// warning), and the "duplicate" capture variant's seed.
enum ScanDuplicate {
    static func existing(store: Store, gymID: UUID, modelID: UUID) -> Machine? {
        store.machines.first { $0.gymID == gymID && $0.modelID == modelID && !$0.isDeleted }
    }

    /// PROTOTYPE: puts a Matrix MG-PL71 hack squat at the gym so S04 shows the warning.
    static func seed(store: Store, gymID: UUID) {
        let modelID = SampleData.modelID("Matrix MG-PL71 Hack Squat")
        guard existing(store: store, gymID: gymID, modelID: modelID) == nil else { return }
        store.addMachine(gymID: gymID, label: "Hack Squat", modelID: modelID)
    }
}

// MARK: - Confidence

/// Confidence as a visual state: A a row of lit scoreboard cells, B a pearl bar, C an inked
/// bar in an outlined well. The number beside it is plain ("93%"). Fills on appear.
struct ScanConfidenceMeter: View {
    var value: Double
    var showsNumber = true
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @State private var shown: Double = 0
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 8

    var body: some View {
        HStack(spacing: 10) {
            meter
                .frame(height: look.id == .floodlight ? height + 2 : height)
                .frame(maxWidth: .infinity)
            if showsNumber {
                Text("\(Int((value * 100).rounded()))%")
                    .font(look.font.fieldNumber)
                    .monospacedDigit()
                    .foregroundStyle(look.textPrimary)
                    .fixedSize()
            }
        }
        .onAppear {
            if reduceMotion { shown = value } else { withAnimation(.easeOut(duration: 0.7).delay(0.15)) { shown = value } }
        }
        .onChange(of: value) { _, new in
            if reduceMotion { shown = new } else { withAnimation(.easeOut(duration: 0.4)) { shown = new } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }

    @ViewBuilder private var meter: some View {
        switch look.id {
        case .floodlight:
            let lit = Int((shown * 10).rounded())
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < lit ? look.done : look.ringTrack)
                }
            }
        case .anatomy:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(look.ringTrack)
                    Capsule().fill(look.done).frame(width: max(height, geo.size.width * shown))
                }
            }
        case .paper, .carbon:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(look.field)
                    RoundedRectangle(cornerRadius: 3).fill(look.done).frame(width: geo.size.width * shown)
                }
                .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(look.hairline, lineWidth: look.stroke.hairline) }
            }
        }
    }
}

// MARK: - Scroll with a pinned bar (and p2 / p3 capture pages)

/// Latest scroll measurements, kept out of view state so scrolling does not re-render.
private final class ScanScrollBox {
    var content: CGFloat = 0
    var visible: CGFloat = 0
    var scheduled = false
}

/// A vertical scroll view with the step's pinned `bar` as a bottom inset (the last row always
/// scrolls clear of it; the bar shows its hairline only while content is under it).
/// - `page` 2 / 3 (the "p2" / "p3" capture variants) opens on that viewport once layout has
///   settled, measured from the latest geometry (not the first, partial one).
/// - `centered` sits short content a little above the middle of the visible area.
/// - `focusID` + `focusTick`: each change of the tick scrolls that view into sight above the bar.
struct ScanPagedScroll<Content: View, Bar: View>: View {
    var page: Int?
    var centered = false
    var focusID: String?
    var focusTick = 0
    @ViewBuilder var content: Content
    @ViewBuilder var bar: Bar
    @ScanReduceMotion private var reduceMotion
    @State private var position = ScrollPosition(edge: .top)
    @State private var box = ScanScrollBox()
    @State private var underBar = false
    @State private var scrollTop: CGFloat?
    @State private var scrollBottom: CGFloat?
    @State private var barTop: CGFloat?

    /// The height from the scroll's top to the pinned bar's top, in global space.
    private var visibleHeight: CGFloat {
        guard let scrollTop, let bottom = barTop ?? scrollBottom else { return 0 }
        return max(0, min(bottom, scrollBottom ?? bottom) - scrollTop)
    }

    init(page: Int?, centered: Bool = false, focusID: String? = nil, focusTick: Int = 0,
         @ViewBuilder content: () -> Content, @ViewBuilder bar: () -> Bar = { EmptyView() }) {
        self.page = page
        self.centered = centered
        self.focusID = focusID
        self.focusTick = focusTick
        self.content = content()
        self.bar = bar()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .padding(.bottom, centered ? 36 : 0)
                    .frame(minHeight: centered && visibleHeight > 0 ? visibleHeight : nil, alignment: .center)
            }
            .scrollPosition($position)
            .scrollDismissesKeyboard(.interactively)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { scrollTop = $0.minY; scrollBottom = $0.maxY }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bar
                    .environment(\.scanContentUnderBar, underBar)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { barTop = $0 }
            }
            .onScrollGeometryChange(for: [CGFloat].self) { geo in
                [geo.contentSize.height, geo.containerSize.height, geo.contentInsets.top, geo.contentInsets.bottom,
                 geo.contentOffset.y]
            } action: { _, m in
                let visible = m[1] - m[2] - m[3]
                box.content = m[0]
                box.visible = visible
                let hidden = m[0] - (m[4] + m[1] - m[3]) > 2
                if hidden != underBar { underBar = hidden }
                schedulePage()
            }
            .onChange(of: focusTick) { _, _ in
                guard let focusID else { return }
                // Let the new content lay out, then bring the target up above the bar.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)) {
                        proxy.scrollTo(focusID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func schedulePage() {
        guard let page, page > 1, !box.scheduled, box.content > 0, box.visible > 0 else { return }
        box.scheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            let maxOffset = max(0, box.content - box.visible)
            let target = min(maxOffset, CGFloat(page - 1) * box.visible * 0.88)
            position.scrollTo(y: target)
        }
    }
}

extension View {
    /// Sheets do not inherit the root's AccessibilityL override (`-axl YES`, ScreenIndex's
    /// "Large text"), so each Scan sheet applies it at its root.
    @ViewBuilder
    func scanTypeOverride(_ size: DynamicTypeSize?) -> some View {
        if let size { dynamicTypeSize(size) } else { self }
    }
}

extension Router {
    /// The capture variant split into tokens: "picked-p2" → ["picked", "p2"].
    var scanVariantTokens: Set<String> {
        guard let variant else { return [] }
        return Set(variant.split(separator: "-").map(String.init))
    }
    func scanVariant(_ token: String) -> Bool { scanVariantTokens.contains(token) }

    /// The "p2" / "p3" capture variant as a viewport number (nil otherwise). A state variant
    /// can combine with it: "picked-p2".
    var scanCapturePage: Int? {
        if scanVariant("p2") { return 2 }
        if scanVariant("p3") { return 3 }
        return nil
    }
}

// MARK: - Prototype chrome

/// PROTOTYPE ONLY — not part of the design. Chooses what the simulated AI answers next, in the
/// switcher's own style (system material, SF Mono), so it never reads as app UI. Hidden in
/// captures (`-hideSwitcher YES`).
struct ScanDemoMenu: View {
    var cameraOff: Binding<Bool>?
    @Environment(Store.self) private var store

    var body: some View {
        if !UserDefaults.standard.bool(forKey: "hideSwitcher") {
            Menu {
                Picker("Next result", selection: Binding(get: { store.scan.demoKind },
                                                        set: { store.scanSetDemoKind($0) })) {
                    ForEach(ScanKind.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Fail next scan", isOn: Binding(get: { store.scan.simulateFailure },
                                                       set: { store.scanSetSimulateFailure($0) }))
                if let cameraOff {
                    Toggle("Camera access off", isOn: cameraOff)
                }
                Toggle("No API key", isOn: Binding(get: { !store.settings.aiKeySaved },
                                                   set: { $0 ? store.removeAIKey() : store.saveAIKey("sk-demo-a1b2") }))
            } label: {
                Text("demo · \(store.scan.simulateFailure ? "Fail" : store.scan.demoKind.label)")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.vertical, 6)
                    .contentShape(Capsule())
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityLabel("Prototype: next scan result")
        }
    }
}
