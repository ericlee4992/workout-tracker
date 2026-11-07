import SwiftUI

// S03 — identifying: the photo just taken is the hero (it fills the height the sheet leaves,
// at every text size), a live beam sweeps it, and the look's live instrument says "working"
// without pretending to know how far along a network call is: A a lit window chasing along the
// scoreboard cells, B a pearl ring that breathes, C a cobalt segment sweeping the ink slab.
// Reduce Motion: the beam rests across the frame and the instruments hold still.
// S03 failure: the same photo, stilled and greyed under a stamped "!", the real error in a
// dashed card (it reads as a problem in every palette), "Take another photo" the one filled
// command.

struct ScanIdentifyingStep: View {
    var photoSpace: Namespace.ID
    var onCancel: () -> Void
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanStepBody(page: router.scanCapturePage) { heroHeight in
                ScanInlineTitle(title: "Scan Machine")
                ScanPhotoHero(photoSpace: photoSpace, scanning: true, height: heroHeight)
                ScanProgressInstrument()
            } bar: {
                ScanBottomBar {
                    Button("Take another photo") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { store.scanRetake() }
                    }
                    .buttonStyle(.lookSecondary)
                }
            } trailing: {
                EmptyView()
            }
        }
    }
}

struct ScanErrorStep: View {
    var photoSpace: Namespace.ID
    var onCancel: () -> Void
    var onManual: () -> Void
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var failures = 0

    /// The real error copy, its last clause matched to the button beside it.
    private var message: String {
        (store.scan.error ?? ScanSimulator.failureMessage)
            .replacingOccurrences(of: "continue manually", with: "choose a catalog model")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanStepBody(page: router.scanCapturePage) { heroHeight in
                ScanInlineTitle(title: "Scan Machine")
                ScanPhotoHero(photoSpace: photoSpace, scanning: false, failed: true, height: heroHeight)
                errorCard
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Take another photo", symbol: "camera") {
                        store.scanSetSimulateFailure(false)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { store.scanRetake() }
                    }
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
    }

    private var errorCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "wifi.slash")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(look.id == .carbon ? look.ground : look.groundSheet)
                .frame(width: 46, height: 46)
                .background(look.textPrimary, in: Circle())
                .accessibilityHidden(true)
            Text(message)
                .font(.system(.body, weight: .semibold))
                .fontDesign(look.id == .anatomy ? .rounded : nil)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(look.space.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.surfaceSheet, in: RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .dashedOutline(look.id.isPaperClub ? look.outline : look.textSecondary, radius: look.radius.panel,
                       lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [6, 4])
        .accessibilityElement(children: .combine)
    }
}

/// The photo-led steps' body: the photo fills whatever height the sheet leaves (so the step
/// never ends in a void) above the pinned bar. At accessibility sizes the column scrolls, and
/// the photo still takes the free height (never less than 260 pt); `trailing` then ends the
/// scroll content (the secondary command leaves the pinned bar there).
struct ScanStepBody<Content: View, Bar: View, Trailing: View>: View {
    var page: Int?
    @ViewBuilder var content: (_ heroHeight: CGFloat?) -> Content
    @ViewBuilder var bar: () -> Bar
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var available: CGFloat = 0
    @State private var barHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var heroShown: CGFloat = 300

    private let minHero: CGFloat = 260

    var body: some View {
        if typeSize.isAccessibilitySize {
            ScanPagedScroll(page: page) {
                VStack(spacing: 18) {
                    VStack(spacing: 18) { content(heroShown) }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0; fit() }
                    trailing()
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 24)
            } bar: {
                bar()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0; fit() }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { available = $0; fit() }
        } else {
            VStack(spacing: 0) {
                VStack(spacing: 18) { content(nil) }
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                bar()
            }
        }
    }

    /// The photo takes what the first viewport has left after the rest of the content.
    private func fit() {
        guard available > 0, contentHeight > 0 else { return }
        let rest = contentHeight - heroShown
        let free = available - barHeight - rest - 6 - 18
        let target = max(minHero, free.rounded(.down))
        if abs(target - heroShown) > 1 { heroShown = target }
    }
}

extension ScanStepBody where Trailing == EmptyView {
    init(page: Int?, @ViewBuilder content: @escaping (_ heroHeight: CGFloat?) -> Content,
         @ViewBuilder bar: @escaping () -> Bar) {
        self.init(page: page, content: content, bar: bar, trailing: { EmptyView() })
    }
}

// MARK: - The photo hero

/// The captured photo at full width with the framing corners; scanning adds the live beam,
/// failure stills and greys it under a stamped "!" disc.
struct ScanPhotoHero: View {
    var photoSpace: Namespace.ID
    var scanning: Bool
    var failed = false
    /// nil = fill the height the column leaves.
    var height: CGFloat?
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        let radius = look.radius.panel
        ZStack {
            ScanPhotoTile(plateText: store.scan.demoKind.scanPlateText, cornerRadius: radius, dimmed: failed)
                .matchedGeometryEffect(id: "scanPhoto", in: photoSpace)
            ScanFrameCorners(length: 28, radius: 16)
                .stroke(failed ? look.onSlab.opacity(0.45) : look.onSlab,
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
                // Stamped on the photo, which is dark in every look: Paper stamps in its dark
                // finish so the disc stays light on the picture.
                ScanOutcomeDisc(outcome: .failed, size: 64)
                    .environment(\.look, look.darkCounterpart)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .frame(minHeight: height == nil ? 260 : nil, maxHeight: height == nil ? .infinity : nil)
    }
}

// MARK: - Progress instrument

/// "Identifying equipment…" with the look's live instrument. The call's length is unknown, so
/// nothing fills toward an end.
struct ScanProgressInstrument: View {
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion

    private let title = "Identifying equipment…"

    var body: some View {
        Group {
            switch look.id {
            case .floodlight: floodlight
            case .anatomy: anatomy
            case .paper, .carbon: slab
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var titleText: some View {
        Text(title)
            .font(look.font.title3)
            .foregroundStyle(look.id.isPaperClub ? look.onSlab : look.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A: ten scoreboard cells; a three-cell Ultra window chases along them and back.
    /// Reduce Motion: the middle cells hold lit.
    private var floodlight: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleText
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
    }

    /// B: a pearl ring breathing a halo (the spec's 2.4 s next-up breath). Reduce Motion: a
    /// still ring.
    private var anatomy: some View {
        HStack(spacing: 16) {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 2.4) / 2.4
                let breath = (1 - cos(t * 2 * .pi)) / 2
                ZStack {
                    Circle()
                        .fill(look.live.opacity(0.22 * (1 - breath)))
                        .scaleEffect(1 + 0.45 * breath)
                    Circle()
                        .strokeBorder(look.live, lineWidth: 4)
                    Circle()
                        .fill(look.live)
                        .frame(width: 12 + 6 * breath, height: 12 + 6 * breath)
                }
            }
            .frame(width: 44, height: 44)
            .padding(4)
            titleText
            Spacer(minLength: 0)
        }
        .padding(look.space.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    /// C: the ink slab, a cobalt segment sweeping across its track. Reduce Motion: the segment
    /// rests in the middle.
    private var slab: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleText
            GeometryReader { geo in
                TimelineView(.animation(paused: reduceMotion)) { timeline in
                    let w = geo.size.width
                    let seg = w * 0.32
                    let phase = reduceMotion ? 0.5 : timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.5) / 1.5
                    let x = -seg + (w + seg) * phase
                    ZStack(alignment: .leading) {
                        Capsule().fill(look.onSlab.opacity(0.16))
                        Capsule().fill(look.live).frame(width: seg).offset(x: x)
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.slab, in: RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous).strokeBorder(look.slabEdge, lineWidth: 1) }
        .environment(\.lookOnSlab, true)
    }

    /// 0 → 1 → 0 over `period`, eased at the ends.
    static func pingPong(_ date: Date, period: Double) -> Double {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        return (1 - cos(tri * .pi)) / 2
    }
}
