import SwiftUI

// PROTOTYPE — Z02: the app icon in each look, drawn as vector art on a 1024 × 1024 canvas
// (the App Store master size) and scaled down, so every size is crisp. iOS 26 also asks for
// Dark, Clear and Tinted appearances; each look defines all four.
//
// A · Floodlight — "the lit stack": the app's machine glyph under a floodlight — a weight stack on
//     two guide rods, hanging from its cable, with the selector pin pulled out to the right. The
//     plates you lift are lit floodlight white; the pinned plate is Ultra ("now").
//     At 22 pt and below (the Live Activity header) it draws a simplified mark: three plates and
//     the pin, no rods and no light cone.
// B · Anatomy    — "the family ring": five round-capped arcs in the muscle-family colours
//     around a pearl dumbbell (the finish ring's language).
// C · Paper / Carbon — "the stamp": an ink rubber stamp (thick ring, dashed inner ring, −8°)
//     over ruled paper, holding a cobalt dumbbell that casts the one hard shadow. (No highlighter:
//     in C yellow means a new best, never decoration.)

enum SystemIconAppearance: String, CaseIterable, Identifiable {
    case standard, dark, clear, tinted
    var id: String { rawValue }

    /// iOS's own names for the four appearances.
    var label: String {
        switch self {
        case .standard: "Default"
        case .dark: "Dark"
        case .clear: "Clear"
        case .tinted: "Tinted"
        }
    }

    /// iOS dims the wallpaper behind Dark and Tinted icons.
    var dimsWallpaper: Bool { self == .dark || self == .tinted }
}

/// The app icon at any size, masked to the iOS squircle.
struct SystemAppIcon: View {
    var lookID: LookStyle
    var appearance: SystemIconAppearance = .standard
    var size: CGFloat
    var masked = true
    /// A Clear icon away from the Home Screen (the picker): the wallpaper shows through its glass,
    /// inside the icon's own shape.
    var showsWallpaperThrough = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: masked ? size * 0.2237 : 0, style: .continuous)
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 1024, y: canvasSize.height / 1024)
            SystemIconPainter(lookID: lookID, appearance: appearance, small: size <= 22).paint(context)
        }
        .frame(width: size, height: size)
        .background {
            if appearance == .clear {
                ZStack {
                    if showsWallpaperThrough { SystemWallpaper() }
                    Color.clear.glassEffect(.clear, in: shape)
                }
            }
        }
        .clipShape(shape)
        .overlay {
            // The system's hairline rim on glass icons.
            if appearance == .clear {
                shape.strokeBorder(Color.white.opacity(0.35), lineWidth: max(0.5, size / 90))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Painter (1024 space)

private struct SystemIconPainter {
    var lookID: LookStyle
    var appearance: SystemIconAppearance
    /// 22 pt and below: fewer, bolder parts that survive the size.
    var small = false

    private static let tint = Color(hex: 0xA9C8FF)
    private static let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)

    func paint(_ context: GraphicsContext) {
        switch lookID {
        case .floodlight: paintFloodlight(context)
        case .anatomy: paintAnatomy(context)
        case .paper: paintStamp(context, dark: appearance == .dark)
        case .carbon: paintStamp(context, dark: true)
        }
    }

    // MARK: A · the lit stack

    private struct FloodColors {
        var ground: Color?
        var glow: Color
        var lit: Color
        var now: Color
        var unlit: Color
        var rod: Color
        var slot: Color
    }

    private var floodColors: FloodColors {
        let t = Self.tint
        switch appearance {
        case .standard:
            return FloodColors(ground: Color(hex: 0x060708), glow: .white.opacity(0.13), lit: Color(hex: 0xF4F6F8),
                               now: Color(hex: 0xB25CFF), unlit: Color(hex: 0x2B2E34), rod: Color(hex: 0x3A3E45),
                               slot: Color(hex: 0x060708))
        case .dark:
            return FloodColors(ground: .black, glow: .white.opacity(0.07), lit: Color(hex: 0xE6E9EC),
                               now: Color(hex: 0xB25CFF), unlit: Color(hex: 0x24262B), rod: Color(hex: 0x303338),
                               slot: .black)
        case .tinted:
            return FloodColors(ground: .black, glow: t.opacity(0.08), lit: t, now: t.opacity(0.62),
                               unlit: t.opacity(0.18), rod: t.opacity(0.22), slot: .black)
        case .clear:
            return FloodColors(ground: nil, glow: .white.opacity(0.08), lit: .white.opacity(0.92),
                               now: .white.opacity(0.55), unlit: .white.opacity(0.2), rod: .white.opacity(0.24),
                               slot: .black.opacity(0.3))
        }
    }

    private func paintFloodlight(_ context: GraphicsContext) {
        let c = floodColors
        if let ground = c.ground { context.fill(Path(Self.full), with: .color(ground)) }
        if small {
            paintFloodlightSmall(context, c)
            return
        }
        // The stack sits left of centre so the selector pin can stick out to the right,
        // exactly as the app's machine glyph draws it.
        let stackX: CGFloat = 222, stackWidth: CGFloat = 468
        let midX = stackX + stackWidth / 2
        // The floodlight: a cone of light falling from the top edge onto the stack.
        var beam = Path()
        beam.move(to: CGPoint(x: midX - 70, y: -10))
        beam.addLine(to: CGPoint(x: midX + 70, y: -10))
        beam.addLine(to: CGPoint(x: midX + 360, y: 900))
        beam.addLine(to: CGPoint(x: midX - 360, y: 900))
        beam.closeSubpath()
        context.fill(beam, with: .linearGradient(Gradient(colors: [c.glow, .clear]),
                                                 startPoint: CGPoint(x: midX, y: 0), endPoint: CGPoint(x: midX, y: 860)))
        // Two guide rods rise above the stack and show through the gaps between plates.
        for x in [stackX + 64, stackX + stackWidth - 64 - 22] {
            context.fill(Path(roundedRect: CGRect(x: x, y: 132, width: 22, height: 700), cornerRadius: 11),
                         with: .color(c.rod))
        }
        // The cable, running in from the top edge to the top plate.
        context.fill(Path(roundedRect: CGRect(x: midX - 17, y: -30, width: 34, height: 300), cornerRadius: 17),
                     with: .color(c.lit))
        // The stack: three lit plates (done), the pinned plate in Ultra (now), one resting plate.
        let top: CGFloat = 262, height: CGFloat = 94, pitch: CGFloat = 112
        let pinned = 3
        for index in 0..<5 {
            let rect = CGRect(x: stackX, y: top + CGFloat(index) * pitch, width: stackWidth, height: height)
            let color = index < pinned ? c.lit : (index == pinned ? c.now : c.unlit)
            context.fill(Path(roundedRect: rect, cornerRadius: 18, style: .continuous), with: .color(color))
        }
        // The selector pin: through the pinned plate's centre and out past the stack, with its pull.
        let pinY = top + CGFloat(pinned) * pitch + height / 2
        context.fill(Path(roundedRect: CGRect(x: midX, y: pinY - 17, width: stackWidth / 2 + 118, height: 34), cornerRadius: 17),
                     with: .color(c.lit))
        let knob = CGPoint(x: midX + stackWidth / 2 + 126, y: pinY)
        context.fill(Path(ellipseIn: CGRect(x: knob.x - 50, y: knob.y - 50, width: 100, height: 100)), with: .color(c.lit))
        context.fill(Path(ellipseIn: CGRect(x: knob.x - 20, y: knob.y - 20, width: 40, height: 40)), with: .color(c.slot))
    }

    /// The small-size mark: a stack hanging from its cable — two lit plates, the pinned plate in
    /// Ultra — and the pin with its pull. Bold enough to read at 16–20 pt.
    private func paintFloodlightSmall(_ context: GraphicsContext, _ c: FloodColors) {
        let x: CGFloat = 150, width: CGFloat = 500, height: CGFloat = 164, pitch: CGFloat = 214
        let top: CGFloat = 250
        let midX = x + width / 2
        context.fill(Path(roundedRect: CGRect(x: midX - 44, y: 40, width: 88, height: top - 20), cornerRadius: 44),
                     with: .color(c.lit))
        for index in 0..<3 {
            let rect = CGRect(x: x, y: top + CGFloat(index) * pitch, width: width, height: height)
            context.fill(Path(roundedRect: rect, cornerRadius: 40, style: .continuous),
                         with: .color(index == 2 ? c.now : c.lit))
        }
        let pinY = top + 2 * pitch + height / 2
        context.fill(Path(roundedRect: CGRect(x: midX, y: pinY - 40, width: width / 2 + 120, height: 80), cornerRadius: 40),
                     with: .color(c.lit))
        context.fill(Path(ellipseIn: CGRect(x: x + width + 60, y: pinY - 100, width: 200, height: 200)), with: .color(c.lit))
        context.fill(Path(ellipseIn: CGRect(x: x + width + 120, y: pinY - 40, width: 80, height: 80)), with: .color(c.slot))
    }

    // MARK: B · the family ring

    private struct AnatomyColors {
        var ground: [Color]?
        var arcs: [Color]
        var track: Color
        var pearl: Color
    }

    private var anatomyColors: AnatomyColors {
        let families: [Color] = [0xEA43CE, 0x2C76F5, 0x2BDCC8, 0xB194FF, 0xB3EE77].map { Color(hex: $0) }
        let t = Self.tint
        switch appearance {
        case .standard:
            return AnatomyColors(ground: [Color(hex: 0x24252B), Color(hex: 0x0A0B0F)], arcs: families,
                                 track: .white.opacity(0.06), pearl: Color(hex: 0xF3F1EC))
        case .dark:
            return AnatomyColors(ground: [Color(hex: 0x141519), .black], arcs: families,
                                 track: .white.opacity(0.05), pearl: Color(hex: 0xE4E2DD))
        case .tinted:
            return AnatomyColors(ground: [Color(hex: 0x0E0F12), .black],
                                 arcs: [0.62, 0.42, 0.9, 0.72, 1.0].map { t.opacity($0) },
                                 track: t.opacity(0.08), pearl: t)
        case .clear:
            return AnatomyColors(ground: nil, arcs: [0.5, 0.36, 0.72, 0.6, 0.84].map { Color.white.opacity($0) },
                                 track: .white.opacity(0.08), pearl: .white.opacity(0.95))
        }
    }

    private func paintAnatomy(_ context: GraphicsContext) {
        let c = anatomyColors
        if let ground = c.ground {
            context.fill(Path(Self.full), with: .linearGradient(Gradient(colors: ground),
                                                                 startPoint: CGPoint(x: 512, y: 0), endPoint: CGPoint(x: 512, y: 1024)))
        }
        let center = CGPoint(x: 512, y: 512)
        let radius: CGFloat = 322
        let width: CGFloat = 100
        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(c.track), lineWidth: width)
        // Five arcs, head to toe, clockwise with chest at 12 o'clock. Each is drawn 42° long; its
        // round caps add ~9° per end, which leaves a clean ~12° gap between families.
        for (index, color) in c.arcs.enumerated() {
            let start = Double(index) * 72 - 90 - 21
            let end = start + 42
            var arc = Path()
            arc.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
            context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        // The pearl dumbbell, rounded (B is SF Rounded throughout).
        let dumbbell = Self.dumbbellPath(center: center, width: 404, roundness: 1)
        context.fill(dumbbell, with: .color(c.pearl))
    }

    // MARK: C · the stamp

    private struct StampColors {
        var ground: Color?
        var rule: Color
        var ink: Color
        var dashed: Color
        var fill: Color
        var outline: Color
        var shadow: Color
    }

    private func stampColors(dark: Bool) -> StampColors {
        let t = Self.tint
        switch appearance {
        case .tinted:
            return StampColors(ground: .black, rule: t.opacity(0.07), ink: t, dashed: t.opacity(0.6), fill: t.opacity(0.78), outline: t, shadow: t.opacity(0.22))
        case .clear:
            return StampColors(ground: nil, rule: .white.opacity(0.07), ink: .white.opacity(0.9), dashed: .white.opacity(0.55),
                               fill: .white.opacity(0.62), outline: .white.opacity(0.95),
                               shadow: .white.opacity(0.16))
        case .standard, .dark:
            if dark {
                return StampColors(ground: Color(hex: 0x15130F), rule: Color(hex: 0xEDE6D6).opacity(0.07),
                                   ink: Color(hex: 0xEDE6D6), dashed: Color(hex: 0xEDE6D6).opacity(0.7),
                                   fill: Color(hex: 0x2743F2),
                                   outline: Color(hex: 0xEDE6D6), shadow: Color(hex: 0x756D60))
            }
            return StampColors(ground: Color(hex: 0xF2ECDF), rule: Color(hex: 0x16140F).opacity(0.08),
                               ink: Color(hex: 0x16140F), dashed: Color(hex: 0x16140F).opacity(0.75),
                               fill: Color(hex: 0x2743F2),
                               outline: Color(hex: 0x16140F), shadow: Color(hex: 0x16140F))
        }
    }

    private func paintStamp(_ context: GraphicsContext, dark: Bool) {
        let c = stampColors(dark: dark)
        if let ground = c.ground { context.fill(Path(Self.full), with: .color(ground)) }
        // Ruled notebook paper.
        var y: CGFloat = 104
        while y < 1024 {
            context.fill(Path(CGRect(x: 0, y: y, width: 1024, height: 6)), with: .color(c.rule))
            y += 92
        }
        var stamp = context
        stamp.translateBy(x: 512, y: 512)
        stamp.rotate(by: .degrees(-8))
        stamp.translateBy(x: -512, y: -512)
        // The rubber stamp: a thick ink ring and a dashed ring just inside it.
        let outer: CGFloat = 364
        stamp.stroke(Path(ellipseIn: CGRect(x: 512 - outer, y: 512 - outer, width: outer * 2, height: outer * 2)),
                     with: .color(c.ink), lineWidth: 48)
        let inner: CGFloat = 300
        stamp.stroke(Path(ellipseIn: CGRect(x: 512 - inner, y: 512 - inner, width: inner * 2, height: inner * 2)),
                     with: .color(c.dashed), style: StrokeStyle(lineWidth: 12, dash: [30, 22]))
        // The cobalt dumbbell: outlined, and the only thing with a hard offset shadow.
        let dumbbell = Self.dumbbellPath(center: CGPoint(x: 500, y: 500), width: 420, roundness: 0.55)
        stamp.fill(dumbbell.offsetBy(dx: 22, dy: 22), with: .color(c.shadow))
        stamp.fill(dumbbell, with: .color(c.fill))
        stamp.stroke(dumbbell, with: .color(c.outline), style: StrokeStyle(lineWidth: 16, lineJoin: .round))
    }

    // MARK: Shared: a dumbbell as one outline

    /// A front-on dumbbell (end stubs, outer and inner plates, the bar) as a single unioned path.
    /// `roundness` 0…1 scales the corner radii.
    static func dumbbellPath(center: CGPoint, width w: CGFloat, roundness: CGFloat) -> Path {
        func part(_ x0: CGFloat, _ x1: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> Path {
            let rect = CGRect(x: center.x - w / 2 + x0 * w, y: center.y - height * w / 2,
                              width: (x1 - x0) * w, height: height * w)
            return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2 * radius, style: .continuous)
        }
        let r = roundness
        var shape = part(0.0, 0.07, 0.11, 0.9 * r + 0.1)
        shape = shape.union(part(0.058, 0.158, 0.40, 0.8 * r + 0.2))
        shape = shape.union(part(0.168, 0.285, 0.56, 0.7 * r + 0.2))
        shape = shape.union(part(0.27, 0.73, 0.085, 1))
        shape = shape.union(part(0.715, 0.832, 0.56, 0.7 * r + 0.2))
        shape = shape.union(part(0.842, 0.942, 0.40, 0.8 * r + 0.2))
        shape = shape.union(part(0.93, 1.0, 0.11, 0.9 * r + 0.1))
        return shape
    }
}

// MARK: - Z02 page

struct SystemAppIconPage: View {
    @Binding var appearance: SystemIconAppearance
    /// Default icons can sit on the light or the dark wallpaper; Dark / Tinted dim it, Clear is
    /// shown over the dark one.
    @Binding var lightWallpaper: Bool
    var viewport: CGFloat = 700
    var onLaunch: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesLight: Bool { lightWallpaper && appearance == .standard }

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, 8)
                .padding(.horizontal, look.space.margin)
            appearancePicker
                .padding(.top, 22)
                .padding(.horizontal, look.space.margin)
            SystemMinHeightLayout(minHeight: viewport) {
                VStack(spacing: 0) {
                    SystemSectionLabel("Home Screen")
                        .padding(.top, look.space.section)
                    SystemHomeScreen(lookID: look.id, appearance: appearance, light: usesLight, onLaunch: onLaunch)
                        .padding(.top, look.space.header)
                        .frame(maxHeight: .infinity)
                }
            }
            .id(SystemScrollAnchor.page2)
        }
    }

    // MARK: Hero: the icon at one size, on a panel of wallpaper

    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return ZStack {
            SystemWallpaper(dimmed: appearance.dimsWallpaper, light: usesLight)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: usesLight)
            VStack(spacing: 10) {
                SystemAppIcon(lookID: look.id, appearance: appearance, size: 156)
                    .shadow(color: .black.opacity(usesLight ? 0.18 : 0.4), radius: 18, x: 0, y: 10)
                    .id(appearance)
                    .transition(.opacity)
                Text("Workout")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(usesLight ? Color.black.opacity(0.82) : .white)
            }
            .dynamicTypeSize(.large) // the icon's label is Home Screen chrome
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipShape(shape)
        .overlay(alignment: .topTrailing) {
            if appearance == .standard {
                GlassIconButton(lightWallpaper ? "sun.max.fill" : "moon.fill",
                                accessibilityLabel: lightWallpaper ? "Light wallpaper" : "Dark wallpaper") {
                    if reduceMotion { lightWallpaper.toggle() } else {
                        withAnimation(.easeInOut(duration: 0.35)) { lightWallpaper.toggle() }
                    }
                }
                .padding(10)
                .transition(.opacity)
                .sensoryFeedback(.selection, trigger: lightWallpaper)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout app icon, \(appearance.label)")
    }

    // MARK: Picker: just the four icons, the chosen one ringed

    @ViewBuilder private var appearancePicker: some View {
        if typeSize.isAccessibilitySize {
            Grid(horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow { chip(.standard); chip(.dark) }
                GridRow { chip(.clear); chip(.tinted) }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                ForEach(SystemIconAppearance.allCases) { chip($0).frame(maxWidth: .infinity) }
            }
        }
    }

    private func chip(_ option: SystemIconAppearance) -> some View {
        let selected = option == appearance
        let iconSize: CGFloat = 58
        let ring = RoundedRectangle(cornerRadius: (iconSize + 12) * 0.2237, style: .continuous)
        return Button {
            if reduceMotion { appearance = option } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { appearance = option }
            }
        } label: {
            VStack(spacing: 8) {
                SystemAppIcon(lookID: look.id, appearance: option, size: iconSize, showsWallpaperThrough: true)
                    .overlay {
                        // Every icon keeps its edge on the sheet (a dark icon on a dark sheet, Paper's
                        // cream icon on the cream sheet) with a faint rim.
                        if option != .clear {
                            RoundedRectangle(cornerRadius: iconSize * 0.2237, style: .continuous)
                                .strokeBorder(look.hairline, lineWidth: 1)
                        }
                    }
                    .padding(6)
                    .overlay { ring.strokeBorder(selected ? look.selection : .clear, lineWidth: 2.5) }
                    .scaleEffect(selected && !reduceMotion ? 1 : 0.96)
                Text(option.label)
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default,
                                  weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? look.textPrimary : look.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("\(option.label) appearance")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected) { _, new in new }
    }
}

// MARK: - Home screen (system chrome around the icon)

/// A neighbouring app on the Home Screen: a plain name and its own colour, so the icon is judged
/// among real-looking neighbours (no borrowed artwork).
private struct SystemNeighbour {
    var name: String
    var symbol: String
    var colors: [UInt32]
    var glyph: UInt32 = 0xFFFFFF
}

struct SystemHomeScreen: View {
    var lookID: LookStyle
    var appearance: SystemIconAppearance
    var light = false
    var onLaunch: () -> Void

    private static let others: [SystemNeighbour] = [
        SystemNeighbour(name: "Calendar", symbol: "calendar", colors: [0xFFFFFF, 0xF2F2F2], glyph: 0xE8412F),
        SystemNeighbour(name: "Photos", symbol: "camera.macro", colors: [0xFFFFFF, 0xF4F1EC], glyph: 0xF29A2E),
        SystemNeighbour(name: "Camera", symbol: "camera.fill", colors: [0x9EA3AA, 0x5D6168]),
        SystemNeighbour(name: "Maps", symbol: "map.fill", colors: [0x7ED07A, 0x3E9E54]),
        SystemNeighbour(name: "Weather", symbol: "cloud.sun.fill", colors: [0x4BA3F2, 0x1D5FC4]),
        SystemNeighbour(name: "Music", symbol: "music.note", colors: [0xFF6179, 0xF02D4E]),
        SystemNeighbour(name: "Books", symbol: "book.fill", colors: [0xFFA23A, 0xF26B1D]),
        SystemNeighbour(name: "Mail", symbol: "envelope.fill", colors: [0x4FB2FF, 0x1C7CF0]),
        SystemNeighbour(name: "Notes", symbol: "note.text", colors: [0xFFE27A, 0xF7C843], glyph: 0x6B5314),
        SystemNeighbour(name: "Clock", symbol: "clock.fill", colors: [0x2A2A2C, 0x0B0B0C]),
        SystemNeighbour(name: "Wallet", symbol: "wallet.pass.fill", colors: [0x2A2A2C, 0x0B0B0C], glyph: 0xFFC53D),
        SystemNeighbour(name: "Games", symbol: "gamecontroller.fill", colors: [0xB36BFF, 0x6D3BE0]),
        SystemNeighbour(name: "Garden", symbol: "leaf.fill", colors: [0x5FD08E, 0x1E9A62]),
        SystemNeighbour(name: "Shop", symbol: "bag.fill", colors: [0x39C6E5, 0x1486C2]),
        SystemNeighbour(name: "Podcasts", symbol: "mic.fill", colors: [0xC77DFF, 0x8A3FD9]),
    ]
    private static let dock: [SystemNeighbour] = [
        SystemNeighbour(name: "Phone", symbol: "phone.fill", colors: [0x6BE07A, 0x2DB84A]),
        SystemNeighbour(name: "Messages", symbol: "message.fill", colors: [0x6BE07A, 0x2DB84A]),
        SystemNeighbour(name: "Browser", symbol: "globe", colors: [0xFFFFFF, 0xECEFF3], glyph: 0x1C7CF0),
        SystemNeighbour(name: "Settings", symbol: "gearshape.fill", colors: [0xA7ABB2, 0x6E727A]),
    ]
    /// Where Workout sits on the page (row 2, column 2).
    private static let workoutSlot = 5

    var body: some View {
        VStack(spacing: 0) {
            Grid(horizontalSpacing: 0, verticalSpacing: 22) {
                ForEach(0..<4, id: \.self) { row in
                    GridRow {
                        ForEach(0..<4, id: \.self) { column in
                            slot(row * 4 + column).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 52)
            Spacer(minLength: 24)
            searchPill
            dock
                .padding(.top, 14)
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        .background { SystemWallpaper(dimmed: appearance.dimsWallpaper, light: light) }
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .environment(\.colorScheme, light ? .light : .dark)
        .dynamicTypeSize(.large) // the home screen's labels do not follow Dynamic Type
        .animation(.easeInOut(duration: 0.35), value: light)
    }

    private var labelColor: Color { light ? Color.black.opacity(0.82) : .white }

    @ViewBuilder private func slot(_ index: Int) -> some View {
        if index == Self.workoutSlot {
            Button(action: onLaunch) {
                VStack(spacing: 6) {
                    SystemAppIcon(lookID: lookID, appearance: appearance, size: 64)
                        .shadow(color: .black.opacity(light ? 0.15 : 0.3), radius: 6, x: 0, y: 3)
                    label("Workout")
                }
            }
            .buttonStyle(SystemIconPressStyle())
            .accessibilityLabel("Workout")
            .accessibilityHint("Opens the app")
        } else {
            let app = Self.others[(index - (index > Self.workoutSlot ? 1 : 0)) % Self.others.count]
            VStack(spacing: 6) {
                SystemPlaceholderApp(app: app, appearance: appearance, size: 64)
                label(app.name)
            }
            .accessibilityHidden(true)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(labelColor)
            .shadow(color: .black.opacity(light ? 0 : 0.45), radius: 2, x: 0, y: 1)
            .lineLimit(1)
    }

    private var searchPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold))
            Text("Search").font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(labelColor.opacity(0.9))
        .padding(.horizontal, 14)
        .frame(height: 30)
        .glassEffect(.regular, in: Capsule())
        .accessibilityHidden(true)
    }

    private var dock: some View {
        HStack(spacing: 0) {
            ForEach(Self.dock, id: \.name) { app in
                SystemPlaceholderApp(app: app, appearance: appearance, size: 64).frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A neighbouring app's icon, following the chosen appearance.
private struct SystemPlaceholderApp: View {
    var app: SystemNeighbour
    var appearance: SystemIconAppearance
    var size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
        Image(systemName: app.symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(glyph)
            .frame(width: size, height: size)
            .background {
                switch appearance {
                case .standard:
                    shape.fill(LinearGradient(colors: app.colors.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom))
                case .dark: shape.fill(Color(hex: 0x1C1C1F).opacity(0.94))
                case .tinted: shape.fill(Color(hex: 0x111214).opacity(0.94))
                case .clear: Color.clear.glassEffect(.clear, in: shape)
                }
            }
    }

    private var glyph: Color {
        switch appearance {
        case .standard: Color(hex: app.glyph)
        case .dark:
            // Dark icons keep the app's colour on the glyph.
            Color(hex: app.glyph == 0xFFFFFF ? (app.colors.first ?? 0xFFFFFF) : app.glyph)
        case .tinted: Color(hex: 0xA9C8FF).opacity(0.8)
        case .clear: .white.opacity(0.85)
        }
    }
}

/// The home screen's press: icons dip, then launch.
private struct SystemIconPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
