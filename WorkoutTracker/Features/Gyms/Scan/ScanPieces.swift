import SwiftUI
import UIKit

// Floodlight redesign ticket 07 — the Scan sheets' shared pieces, ported from the prototype's
// Scan area (ScanSupport.swift): the framing corners, the identifying sweep, the sheet's top and
// bottom bars, the primary with its neutral disabled face, the outcome stamp, radio marks, the
// score meter, the photo tile and the scroll with a pinned bar. Used by the Scan Machine sheet
// (IdentifyEquipmentSheet), Read Label (ScanMachineLabelSheet) and Correct Model.

extension EnvironmentValues {
    /// True while scrolled content is hidden under the pinned bottom bar (the bar draws its
    /// hairline only then).
    @Entry var scanContentUnderBar = false
}

// MARK: - The photo

/// The photo just taken, shown back while it is identified and beside its answer. In memory
/// only — the app never writes it anywhere (D56). No photo (the consent step, before the
/// camera): a camera glyph on the same dark tile.
struct ScanPhotoTile: View {
    var image: UIImage?
    var cornerRadius: CGFloat
    var dimmed = false

    var body: some View {
        // The tile sets the size; the photo only fills it. An aspect-filled image as a sibling
        // would lay out at the photo's own width and push the whole column off the screen.
        Color(white: 0.1)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .saturation(dimmed ? 0 : 1)
                        .brightness(dimmed ? -0.12 : 0)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement()
        .accessibilityLabel(image == nil ? "Camera" : "The photo you took")
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Framing corners

/// Four rounded L corners: the framing brackets over the viewfinder and the photo.
struct ScanFrameCorners: Shape {
    var length: CGFloat = 30
    var radius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let l = min(length, rect.width / 3, rect.height / 3)
        let r = max(0, min(radius, l - 4))
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

/// A live beam sweeping the photo while it is identified. Reduce Motion: the beam rests across
/// the middle over a faint wash.
struct ScanSweep: View {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    beam.frame(width: geo.size.width).position(x: geo.size.width / 2, y: eased * geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var beam: some View {
        ZStack {
            LinearGradient(colors: [color.opacity(0), color.opacity(0.32), color.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 96)
            Rectangle().fill(color).frame(height: 2).shadow(color: color, radius: 6)
        }
    }
}

// MARK: - Sheet chrome

/// Cancel on glass, the title centred. At accessibility sizes the title leaves the bar and
/// the step puts `ScanInlineTitle` first in its content, so it scrolls away with it.
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
            if let title, !typeSize.isAccessibilitySize {
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
                    .accessibilityIdentifier("scanCancel")
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

/// The step title as the first line of the content at accessibility sizes (the bar's title
/// otherwise, so this draws nothing).
struct ScanInlineTitle: View {
    var title: String
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            Text(title)
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// The pinned action area at the sheet's foot: a solid bar of the sheet's ground, with a
/// hairline only while content is hidden under it.
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

/// The step's one filled command. Disabled it is a neutral capsule (the raised fill, a dim
/// label, no tint) — never a greyed violet that still reads as the call to action.
struct ScanPrimaryButton: View {
    var title: String
    var symbol: String
    var enabled = true
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 56

    init(_ title: String, symbol: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        if enabled {
            PrimaryButton(title, symbol: symbol, action: action)
        } else {
            Button(action: {}) {
                HStack(spacing: 10) {
                    Image(systemName: symbol).font(.body.weight(.semibold))
                    Text(title).font(look.font.button).multilineTextAlignment(.center)
                }
                .foregroundStyle(look.textTertiary)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: height)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(look.surfaceRaised, in: Capsule())
            .overlay { Capsule().strokeBorder(look.hairline, lineWidth: 1) }
            .disabled(true)
        }
    }
}

// MARK: - Outcome stamp

/// What the scan concluded, as a disc that stamps in like a completed set.
enum ScanOutcome: Equatable {
    case matched
    /// Several catalog rows share the name (D56: saved without a model).
    case several(Int)
    case newModel
    case generic
    case failed
}

/// Matched = the lit "done" disc; several = an open ring with the count; new model = the
/// dashed "make one" edge; generic = a hollow "?" ring; failed = a solid inverse "!". It stamps
/// in (1.55×, −14°) and lands upright; `ripple` adds the finish ring that runs out once.
/// Reduce Motion: it is simply there.
struct ScanOutcomeDisc: View {
    var outcome: ScanOutcome
    var size: CGFloat
    var delay: Double = 0
    var ripple = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var rippled = false

    var body: some View {
        face
            .frame(width: size, height: size)
            .background {
                if ripple && !reduceMotion {
                    Circle()
                        .strokeBorder(look.done, lineWidth: 2)
                        .scaleEffect(rippled ? 1.9 : 1)
                        .opacity(rippled ? 0 : 0.8)
                }
            }
            .scaleEffect(landed || reduceMotion ? 1 : look.motion.stampScale)
            .rotationEffect(.degrees(landed || reduceMotion ? 0 : look.motion.stampRotation))
            .opacity(landed || reduceMotion ? 1 : 0)
            .onAppear(perform: land)
            .onChange(of: outcome) { _, _ in
                guard !reduceMotion else { return }
                landed = false
                land()
            }
            .accessibilityHidden(true)
    }

    private func land() {
        guard !reduceMotion else { landed = true; return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.62).delay(delay)) { landed = true }
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
        case .several(let count):
            Text("\(count)")
                .font(.system(size: size * 0.44, weight: .heavy).width(.expanded))
                .foregroundStyle(look.textPrimary)
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(look.textPrimary, lineWidth: 2) }
        case .newModel:
            Image(systemName: "plus")
                .font(glyphFont)
                .foregroundStyle(look.textPrimary)
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [6, 4])) }
        case .generic:
            Image(systemName: "questionmark")
                .font(glyphFont)
                .foregroundStyle(look.textSecondary)
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(look.textTertiary, lineWidth: 2) }
        case .failed:
            Image(systemName: "exclamationmark")
                .font(glyphFont)
                .foregroundStyle(look.groundSheet)
                .frame(width: size, height: size)
                .background(look.textPrimary, in: Circle())
        }
    }
}

/// A flat glyph disc for things you cannot press.
struct ScanGlyphDisc: View {
    var symbol: String
    var size: CGFloat
    /// An SF Symbol drawn at this font instead of the body-sized `LookIcon`.
    var glyphFont: Font? = nil
    @Environment(\.look) private var look

    var body: some View {
        Group {
            if let glyphFont {
                Image(systemName: symbol).font(glyphFont)
            } else {
                LookIcon(symbol, style: .body, weight: .semibold)
            }
        }
        .foregroundStyle(look.textPrimary)
        .frame(width: size, height: size)
        .background(look.controlFill, in: Circle())
        .accessibilityHidden(true)
    }
}

/// A radio mark: an open ring, or the selection filled with a check.
struct ScanRadio: View {
    var selected: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 26

    var body: some View {
        ZStack {
            if selected {
                Circle().fill(look.selection)
                Image(systemName: "checkmark")
                    .font(.system(size: side * 0.46, weight: .heavy))
                    .foregroundStyle(look.onDone)
            } else {
                Circle().strokeBorder(look.textTertiary, lineWidth: 2)
            }
        }
        .frame(width: side, height: side)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selected)
        .accessibilityHidden(true)
    }
}

/// A 0…1 score as ten lit scoreboard cells and the plain percentage — the on-device matcher's
/// score (D33 shows it). Fills on appear; Reduce Motion: it is simply there.
struct ScanScoreMeter: View {
    var value: Double
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 8

    var body: some View {
        HStack(spacing: 10) {
            let lit = Int((shown * 10).rounded())
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < lit ? look.done : look.ringTrack)
                }
            }
            .frame(height: height + 2)
            .frame(maxWidth: .infinity)
            Text("\(Int((value * 100).rounded()))%")
                .font(look.font.fieldNumber)
                .monospacedDigit()
                .foregroundStyle(look.textPrimary)
                .fixedSize()
        }
        .onAppear {
            if reduceMotion { shown = value } else { withAnimation(.easeOut(duration: 0.7).delay(0.15)) { shown = value } }
        }
        .onChange(of: value) { _, new in shown = new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

/// "Identifying equipment…" with ten scoreboard cells and a lit window chasing along them. The
/// call's length is unknown, so nothing fills toward an end. Reduce Motion: the middle cells
/// hold lit.
struct ScanProgressInstrument: View {
    var title: String
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(look.font.title3)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let head = reduceMotion ? 4.5 : Self.pingPong(timeline.date, period: 1.6) * 9
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { i in
                        let distance = abs(Double(i) - head)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(look.ringTrack)
                            .overlay {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(look.live)
                                    .opacity(max(0, 1 - distance / 1.6))
                            }
                            .frame(height: 16)
                    }
                }
            }
        }
        .padding(look.space.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// 0 → 1 → 0 over `period`, eased at the ends.
    static func pingPong(_ date: Date, period: Double) -> Double {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        return (1 - cos(tri * .pi)) / 2
    }
}

// MARK: - Scroll with a pinned bar

/// Latest scroll measurements, kept out of view state so scrolling does not re-render.
private final class ScanScrollBox {
    var content: CGFloat = 0
    var visible: CGFloat = 0
}

/// A vertical scroll view with the step's pinned `bar` as a bottom inset (the last row always
/// scrolls clear of it; the bar shows its hairline only while content is under it).
/// - `centered` sits short content a little above the middle of the visible area.
/// - `focusID` + `focusTick`: each change of the tick scrolls that view into sight above the bar.
struct ScanPagedScroll<Content: View, Bar: View>: View {
    var centered = false
    var focusID: String?
    var focusTick = 0
    @ViewBuilder var content: Content
    @ViewBuilder var bar: Bar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var underBar = false
    @State private var visibleHeight: CGFloat = 0

    init(centered: Bool = false, focusID: String? = nil, focusTick: Int = 0,
         @ViewBuilder content: () -> Content, @ViewBuilder bar: () -> Bar = { EmptyView() }) {
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
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bar.environment(\.scanContentUnderBar, underBar)
            }
            .onScrollGeometryChange(for: [CGFloat].self) { geo in
                [geo.contentSize.height, geo.containerSize.height, geo.contentInsets.top, geo.contentInsets.bottom,
                 geo.contentOffset.y]
            } action: { _, m in
                let visible = max(0, m[1] - m[2] - m[3])
                if abs(visible - visibleHeight) > 1 { visibleHeight = visible }
                let hidden = m[0] - (m[4] + m[1] - m[3]) > 2
                if hidden != underBar { underBar = hidden }
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
}

/// The photo-led steps' body: the photo fills whatever height the sheet leaves above the pinned
/// bar. At accessibility sizes the column scrolls and the photo keeps at least 260 pt; `trailing`
/// then ends the scroll content (the secondary command leaves the pinned bar there).
struct ScanStepBody<Content: View, Bar: View, Trailing: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var bar: Bar
    @ViewBuilder var trailing: Trailing
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    init(@ViewBuilder content: () -> Content, @ViewBuilder bar: () -> Bar,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.content = content()
        self.bar = bar()
        self.trailing = trailing()
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            ScanPagedScroll {
                VStack(spacing: 18) {
                    content
                    trailing
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 24)
            } bar: {
                bar
            }
        } else {
            VStack(spacing: 0) {
                VStack(spacing: 18) { content }
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                bar
            }
        }
    }
}

/// The photo at full width with the framing corners; `scanning` adds the live sweep, `failed`
/// greys it under a stamped "!" disc. `height` nil fills what the column leaves (never under
/// 260 pt); at accessibility sizes the scroll gives it a fixed height.
struct ScanPhotoHero: View {
    var image: UIImage?
    var scanning: Bool
    var failed = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let radius = look.radius.panel
        ZStack {
            ScanPhotoTile(image: image, cornerRadius: radius, dimmed: failed)
            ScanFrameCorners(length: 28, radius: 16)
                .stroke(failed ? Color.white.opacity(0.45) : Color.white,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .padding(18)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            if scanning {
                ScanSweep(color: look.live)
                    .padding(18)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            if failed {
                // Stamped on the photo, which is dark in both appearances.
                ScanOutcomeDisc(outcome: .failed, size: 64)
                    .environment(\.look, look.darkCounterpart)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: typeSize.isAccessibilitySize ? 300 : nil)
        .frame(minHeight: typeSize.isAccessibilitySize ? nil : 260, maxHeight: typeSize.isAccessibilitySize ? nil : .infinity)
    }
}
