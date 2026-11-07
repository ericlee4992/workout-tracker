import SwiftUI

// The simulated camera image. The simulator has no camera and no photo asset ships, so the
// viewfinder and the captured photo are one drawing: a plate-loaded hack squat on a gym floor,
// side on. Its colours are image pixels (identical in every look), not UI tokens — a photo does
// not change with the theme. Drawn with plain fills and gradients only (no blur layers), so it
// costs little to redraw while a sheet presents or the photo morphs between steps.

struct ScanScene: View {
    var torchOn = false
    /// Text on the machine's name plate (what the simulated AI reads). nil = a blank plate.
    var plateText: String?
    /// Outlines the name plate: "this is what was read".
    var plateHighlight: Color?
    /// Where the machine stands, in this view's coordinates. nil = centred in the view.
    var subject: CGRect?

    var body: some View {
        Canvas { context, size in
            ScanSceneRenderer.draw(in: &context, size: size,
                                   subject: subject ?? ScanSceneRenderer.defaultSubject(in: size),
                                   torchOn: torchOn, plateText: plateText, plateHighlight: plateHighlight)
        }
        .accessibilityHidden(true)
    }
}

/// Draws the scene. The machine lives in a 100 × 100 unit box whose bottom edge is the floor
/// under its feet; the wall meets the floor behind it, higher up, which gives the photo depth.
enum ScanSceneRenderer {
    // Image pixels: a cool, evenly lit gym (wall, rubber floor, graphite frame, black pads).
    private static let wallTop = Color(red: 0.205, green: 0.215, blue: 0.235)
    private static let wallLow = Color(red: 0.125, green: 0.132, blue: 0.147)
    private static let floorTop = Color(red: 0.088, green: 0.092, blue: 0.102)
    private static let floorLow = Color(red: 0.035, green: 0.037, blue: 0.042)
    private static let prop = Color(red: 0.245, green: 0.255, blue: 0.28)
    private static let propDark = Color(red: 0.165, green: 0.172, blue: 0.19)
    private static let metalHi = Color(red: 0.52, green: 0.55, blue: 0.60)
    private static let metal = Color(red: 0.33, green: 0.35, blue: 0.39)
    private static let metalLo = Color(red: 0.19, green: 0.20, blue: 0.23)
    private static let chrome = Color(red: 0.78, green: 0.80, blue: 0.84)
    private static let pad = Color(red: 0.075, green: 0.078, blue: 0.088)
    private static let padSheen = Color(red: 0.30, green: 0.31, blue: 0.34)
    private static let rubber = Color(red: 0.095, green: 0.1, blue: 0.112)
    private static let rubberRim = Color(red: 0.36, green: 0.38, blue: 0.42)
    private static let nameplate = Color(red: 0.86, green: 0.87, blue: 0.89)
    private static let nameplateInk = Color(red: 0.07, green: 0.08, blue: 0.09)

    /// The machine's box when a caller does not place it. Landscape photos: standing near the
    /// bottom. Portrait photos: a square visually centred (as in the viewfinder, so the photo
    /// keeps its framing when it moves from the camera into a tall tile).
    static func defaultSubject(in size: CGSize) -> CGRect {
        if size.height > size.width * 1.05 {
            let side = min(size.width * 0.86, size.height * 0.8)
            return CGRect(x: (size.width - side) / 2, y: size.height / 2 - side * 0.55, width: side, height: side)
        }
        let w = size.width * 0.86, h = size.height * 0.8
        return CGRect(x: (size.width - w) / 2, y: size.height * 0.93 - h, width: w, height: h)
    }

    /// Unit box → image: fitted into `subject`, standing on its bottom edge.
    static func transform(subject: CGRect) -> (scale: CGFloat, origin: CGPoint) {
        let s = max(0.01, min(subject.width / 100, subject.height / 100))
        return (s, CGPoint(x: subject.midX - 50 * s, y: subject.maxY - 100 * s))
    }

    /// The name plate on the base frame, in image coordinates.
    static func plateRect(subject: CGRect) -> CGRect {
        let t = transform(subject: subject)
        return CGRect(x: t.origin.x + 36 * t.scale, y: t.origin.y + 93.7 * t.scale,
                      width: 28 * t.scale, height: 4.6 * t.scale)
    }

    static func draw(in ctx: inout GraphicsContext, size: CGSize, subject: CGRect, torchOn: Bool,
                     plateText: String?, plateHighlight: Color?) {
        let rect = CGRect(origin: .zero, size: size)
        let t = transform(subject: subject)
        let s = t.scale
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: t.origin.x + x * s, y: t.origin.y + y * s) }
        func bar(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, cap: CGLineCap = .round) -> Path {
            Path { $0.move(to: a); $0.addLine(to: b) }
                .strokedPath(StrokeStyle(lineWidth: w * s, lineCap: cap, lineJoin: .round))
        }
        let horizon = min(size.height - 2, p(0, 82).y)   // wall meets floor behind the machine

        // MARK: Wall and room
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [wallTop, wallLow]),
                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
        // Ceiling lights washing down the wall.
        for cx in [0.2, 0.8] {
            let c = CGPoint(x: size.width * cx, y: 0)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [.white.opacity(0.13), .white.opacity(0.04), .clear]),
                                                       center: c, startRadius: 0, endRadius: max(size.width, horizon) * 0.55))
        }
        // Mirror panels with a diagonal sheen.
        for (x0, x1) in [(0.03, 0.35), (0.65, 0.97)] {
            let panel = CGRect(x: size.width * x0, y: horizon * 0.12, width: size.width * (x1 - x0), height: horizon * 0.84)
            ctx.fill(Path(panel), with: .linearGradient(Gradient(colors: [.white.opacity(0.055), .white.opacity(0.015)]),
                                                        startPoint: CGPoint(x: panel.minX, y: panel.minY),
                                                        endPoint: CGPoint(x: panel.maxX, y: panel.maxY)))
            ctx.stroke(Path(panel), with: .color(.white.opacity(0.05)), lineWidth: 1)
        }
        // Background props, low contrast (out of focus): a dumbbell rack left, a cable tower right.
        let unit = max(1, s)
        let rackTop = horizon - 30 * unit, rackW = size.width * 0.24
        var rack = Path()
        rack.addRect(CGRect(x: -4, y: rackTop, width: rackW, height: 3 * unit))
        rack.addRect(CGRect(x: -4, y: rackTop + 14 * unit, width: rackW, height: 3 * unit))
        rack.addRect(CGRect(x: rackW - 7, y: rackTop, width: 3 * unit, height: horizon - rackTop))
        ctx.fill(rack, with: .color(prop))
        var bells = Path()
        let bellR = 4.2 * unit
        var bx = 4.0 * unit
        while bx < rackW - 10 {
            for tier in [rackTop - bellR * 0.9, rackTop + 14 * unit - bellR * 0.9] {
                bells.addEllipse(in: CGRect(x: bx - bellR, y: tier - bellR, width: bellR * 2, height: bellR * 2))
            }
            bx += bellR * 2.6
        }
        ctx.fill(bells, with: .color(propDark))
        ctx.stroke(bells, with: .color(prop), lineWidth: max(1, 0.6 * unit))
        let tower = CGRect(x: size.width * 0.86, y: horizon * 0.2, width: size.width * 0.12, height: horizon * 0.8)
        var towerPath = Path()
        towerPath.addRect(CGRect(x: tower.minX, y: tower.minY, width: 3 * unit, height: tower.height))
        towerPath.addRect(CGRect(x: tower.maxX - 3 * unit, y: tower.minY, width: 3 * unit, height: tower.height))
        towerPath.addRect(CGRect(x: tower.minX, y: tower.minY, width: tower.width, height: 3 * unit))
        ctx.fill(towerPath, with: .color(prop))
        ctx.stroke(Path(ellipseIn: CGRect(x: tower.midX - 4 * unit, y: tower.minY + 6 * unit, width: 8 * unit, height: 8 * unit)),
                   with: .color(prop), lineWidth: max(1, 1.2 * unit))
        ctx.fill(Path(CGRect(x: tower.midX - 0.4 * unit, y: tower.minY + 14 * unit, width: 0.8 * unit, height: tower.height * 0.45)),
                 with: .color(prop))

        // MARK: Floor
        let floor = CGRect(x: 0, y: horizon, width: size.width, height: max(0, size.height - horizon))
        ctx.fill(Path(floor), with: .linearGradient(Gradient(colors: [floorTop, floorLow]),
                                                     startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)))
        var seams = Path()
        let vanish = CGPoint(x: size.width / 2, y: horizon - size.height * 0.6)
        for i in -5...5 {
            let bottom = CGPoint(x: size.width / 2 + CGFloat(i) * size.width * 0.3, y: size.height)
            let k = (horizon - vanish.y) / max(1, bottom.y - vanish.y)
            seams.move(to: CGPoint(x: vanish.x + (bottom.x - vanish.x) * k, y: horizon))
            seams.addLine(to: bottom)
        }
        for f in [0.3, 0.75] {
            let y = horizon + floor.height * f * f
            seams.move(to: CGPoint(x: 0, y: y)); seams.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(seams, with: .color(.white.opacity(0.04)), lineWidth: 1)
        ctx.fill(Path(CGRect(x: 0, y: horizon - 2, width: size.width, height: 2)), with: .color(.white.opacity(0.07)))

        // Soft contact shadow (a squashed radial gradient, no blur).
        var shadow = ctx
        let foot = p(50, 99.5)
        shadow.translateBy(x: foot.x, y: foot.y)
        shadow.scaleBy(x: 1, y: 0.09)
        shadow.fill(Path(ellipseIn: CGRect(x: -56 * s, y: -56 * s, width: 112 * s, height: 112 * s)),
                    with: .radialGradient(Gradient(colors: [.black.opacity(0.85), .black.opacity(0.5), .clear]),
                                          center: .zero, startRadius: 0, endRadius: 56 * s))

        // MARK: The machine, back to front
        let frameShade = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [metalHi, metal, metalLo]), startPoint: p(0, 10), endPoint: p(0, 100))
        // Rail geometry: bottom R0 → top R1; d along the rail, n toward the lifter.
        let r0 = CGPoint(x: 24, y: 86), r1 = CGPoint(x: 78, y: 14)
        let len: CGFloat = 90
        let d = CGVector(dx: (r1.x - r0.x) / len, dy: (r1.y - r0.y) / len)
        let n = CGVector(dx: d.dy, dy: -d.dx)            // (-0.8, -0.6): up and to the left
        func r(_ f: CGFloat, _ off: CGFloat = 0) -> CGPoint {
            p(r0.x + d.dx * len * f + n.dx * off, r0.y + d.dy * len * f + n.dy * off)
        }

        ctx.fill(bar(p(86, 54), p(63, 93), 3.2), with: .color(metalLo))            // brace
        ctx.fill(bar(p(79, 15), p(90, 93), 5.5), with: frameShade)                 // rear strut
        ctx.fill(bar(p(r0.x + 3.5, r0.y + 1.5), p(r1.x + 3.5, r1.y + 1.5), 4.5), with: .color(metalLo)) // far rail
        ctx.fill(bar(p(r0.x, r0.y), p(r1.x, r1.y), 5.5), with: frameShade)          // near rail
        ctx.stroke(Path { $0.move(to: r(0.02, 1.8)); $0.addLine(to: r(0.98, 1.8)) },
                   with: .color(metalHi.opacity(0.8)), lineWidth: max(0.6, 0.7 * s))
        ctx.fill(Path(ellipseIn: CGRect(x: p(79, 15).x - 3.6 * s, y: p(79, 15).y - 3.6 * s, width: 7.2 * s, height: 7.2 * s)),
                 with: .color(metal))                                              // top joint
        ctx.fill(bar(p(24, 86), p(23, 93), 4.5), with: .color(metal))              // front support
        // Base frame and feet.
        ctx.fill(Path(roundedRect: CGRect(x: p(4, 93).x, y: p(4, 93).y, width: 92 * s, height: 6 * s), cornerRadius: 1.4 * s),
                 with: frameShade)
        ctx.fill(Path(CGRect(x: p(4, 93).x, y: p(4, 93).y, width: 92 * s, height: max(0.8, 0.8 * s))),
                 with: .color(metalHi.opacity(0.9)))
        for x in [CGFloat(3), 88] {
            ctx.fill(Path(roundedRect: CGRect(x: p(x, 98.4).x, y: p(x, 98.4).y, width: 9 * s, height: 1.8 * s), cornerRadius: 0.6 * s),
                     with: .color(rubber))
        }
        // Footplate: tilted toward the lifter, on a strut.
        ctx.fill(bar(p(14, 84), p(13, 93), 4), with: .color(metal))
        var footplate = Path()
        footplate.addLines([p(2, 76.5), p(28, 84.5), p(27.4, 89), p(1.6, 81)])
        footplate.closeSubpath()
        ctx.fill(footplate, with: .linearGradient(Gradient(colors: [metalHi, metalLo]), startPoint: p(14, 77), endPoint: p(14, 89)))
        ctx.stroke(Path { $0.move(to: p(2, 76.5)); $0.addLine(to: p(28, 84.5)) },
                   with: .color(chrome.opacity(0.85)), lineWidth: max(0.8, 0.9 * s))

        // Carriage on the rail, then the back pad and the shoulder pad.
        ctx.fill(bar(r(0.26, 3), r(0.84, 3), 5), with: .color(metal))
        ctx.fill(bar(r(0.3, 8.5), r(0.8, 8.5), 9.5), with: .color(pad))            // back pad
        ctx.stroke(Path { $0.move(to: r(0.3, 12.6)); $0.addLine(to: r(0.8, 12.6)) },
                   with: .color(padSheen), style: StrokeStyle(lineWidth: max(0.8, 1.1 * s), lineCap: .round))
        let shoulderBase = r(0.84, 7)
        let shoulderTip = CGPoint(x: shoulderBase.x + n.dx * 11 * s - d.dx * 2 * s,
                                  y: shoulderBase.y + n.dy * 11 * s - d.dy * 2 * s)
        ctx.fill(bar(shoulderBase, shoulderTip, 7.5), with: .color(pad))            // shoulder pad
        ctx.stroke(bar(shoulderBase, shoulderTip, 7.5), with: .color(padSheen.opacity(0.7)), lineWidth: max(0.6, 0.7 * s))
        let grip = CGPoint(x: shoulderTip.x - d.dx * 6 * s, y: shoulderTip.y - d.dy * 6 * s)
        ctx.fill(bar(CGPoint(x: shoulderTip.x - d.dx * 2 * s, y: shoulderTip.y - d.dy * 2 * s), grip, 2.2), with: .color(chrome))

        // Loaded plate on the near horn (a 45 lb bumper faces the camera).
        let hub = r(0.25, -4.5)
        for (radius, fill) in [(CGFloat(15.5), rubber), (11.5, Color(red: 0.13, green: 0.135, blue: 0.15))] {
            let disc = CGRect(x: hub.x - radius * s, y: hub.y - radius * s, width: 2 * radius * s, height: 2 * radius * s)
            ctx.fill(Path(ellipseIn: disc), with: .color(fill))
            ctx.stroke(Path(ellipseIn: disc), with: .color(rubberRim), lineWidth: max(0.7, 0.9 * s))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: hub.x - 4 * s, y: hub.y - 4 * s, width: 8 * s, height: 8 * s)), with: .color(chrome))
        ctx.fill(Path(ellipseIn: CGRect(x: hub.x - 2 * s, y: hub.y - 2 * s, width: 4 * s, height: 4 * s)), with: .color(metalLo))
        // Specular arc on the plate rim.
        ctx.stroke(Path { $0.addArc(center: hub, radius: 14.2 * s, startAngle: .degrees(200), endAngle: .degrees(260), clockwise: false) },
                   with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: max(0.8, 1.1 * s), lineCap: .round))

        // Name plate on the base frame.
        let plateBox = plateRect(subject: subject)
        ctx.fill(Path(roundedRect: plateBox, cornerRadius: 0.9 * s), with: .color(nameplate))
        if let plateText, plateBox.height > 3 {
            // Fit the whole plate text (maker and model) across the plate.
            let chars = CGFloat(max(1, plateText.count))
            let size = max(2.5, min(plateBox.height * 0.6, plateBox.width * 0.9 / (chars * 0.7)))
            let text = Text(plateText)
                .font(.system(size: size, weight: .heavy))
                .tracking(max(0.1, size * 0.06))
                .foregroundStyle(nameplateInk)
            ctx.draw(ctx.resolve(text), at: CGPoint(x: plateBox.midX, y: plateBox.midY), anchor: .center)
        }

        // Torch: a hard pool of light on the machine.
        if torchOn {
            let center = p(52, 58)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [.white.opacity(0.3), .white.opacity(0.08), .clear]),
                                                        center: center, startRadius: 0, endRadius: 80 * s))
        }

        // Lens vignette.
        ctx.fill(Path(rect), with: .radialGradient(Gradient(colors: [.clear, .clear, .black.opacity(0.55)]),
                                                    center: CGPoint(x: size.width / 2, y: size.height * 0.46),
                                                    startRadius: 0, endRadius: max(size.width, size.height) * 0.75))

        if let plateHighlight {
            ctx.stroke(Path(roundedRect: highlightRect(subject: subject), cornerRadius: 2 * s),
                       with: .color(plateHighlight), lineWidth: max(1.5, 0.9 * s))
        }
    }

    /// The outline drawn around the name plate when it was read.
    static func highlightRect(subject: CGRect) -> CGRect {
        let s = transform(subject: subject).scale
        return plateRect(subject: subject).insetBy(dx: -3 * s, dy: -2.4 * s)
    }

    /// Plate pixels, shared with the loupe (a zoomed copy of the plate is still the photo).
    static var plateFill: Color { nameplate }
    static var plateInk: Color { nameplateInk }
}

/// What the AI read, lifted out of the photo: a zoomed copy of the name plate at the photo's
/// top-leading corner, joined to the outlined plate by a leader line. It lands once when the
/// answer arrives (the line draws, the plate scales out of it); Reduce Motion: it is there.
struct ScanPlateLoupe: View {
    var text: String
    var highlight: Color
    /// The scene's subject rect (nil = the scene's default placement).
    var subject: CGRect?
    @ScanReduceMotion private var reduceMotion
    @State private var labelFrame: CGRect = .zero
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let target = ScanSceneRenderer.highlightRect(subject: subject ?? ScanSceneRenderer.defaultSubject(in: geo.size))
            // An elbow leader: straight down the photo's left side (clear of the machine and its
            // weight plate), then across to the outlined name plate.
            let start = CGPoint(x: labelFrame.minX + 22, y: labelFrame.maxY + 4)
            let elbow = CGPoint(x: start.x, y: target.midY)
            let end = CGPoint(x: target.minX, y: target.midY)
            ZStack(alignment: .topLeading) {
                if labelFrame != .zero {
                    Path { p in
                        p.move(to: start)
                        if start.x < target.minX - 8 {
                            p.addLine(to: elbow)
                            p.addLine(to: end)
                        } else {
                            p.addLine(to: CGPoint(x: target.midX, y: target.minY))
                        }
                    }
                    .trim(from: 0, to: shown || reduceMotion ? 1 : 0)
                    .stroke(highlight.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
                label
                    .scaleEffect(shown || reduceMotion ? 1 : 0.6, anchor: .bottom)
                    .opacity(shown || reduceMotion ? 1 : 0)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("scanLoupe")) } action: { labelFrame = $0 }
                    .padding(.leading, 16)
                    .padding(.top, 16)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .coordinateSpace(.named("scanLoupe"))
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { shown = true; return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.3)) { shown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Read on the machine: \(text)")
    }

    private var label: some View {
        Text(text.replacingOccurrences(of: "  ", with: " "))
            .font(.system(.footnote, weight: .heavy))
            .tracking(1.6)
            .foregroundStyle(ScanSceneRenderer.plateInk)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(ScanSceneRenderer.plateFill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .padding(4)
            .overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(highlight, lineWidth: 2) }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
