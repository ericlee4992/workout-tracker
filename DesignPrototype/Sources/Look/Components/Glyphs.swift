import SwiftUI

// Custom glyphs that SF Symbols lacks. Until the proposed custom SF Symbol exists, the
// machine glyph is drawn as a Shape and scaled with Dynamic Type like a symbol would be.

/// A weight stack: a cable pin on top of stacked plates, drawn on a 24-unit grid.
/// Every SPEC reserves `dumbbell` for free weights; machines use this.
struct WeightStackGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.midX - 12 * s, oy = rect.midY - 12 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        // Cable and its pin cap.
        p.move(to: pt(12, 1.5)); p.addLine(to: pt(12, 6))
        p.move(to: pt(9.5, 1.5)); p.addLine(to: pt(14.5, 1.5))
        // The stack: an outer plate block with three plate divisions.
        p.addRoundedRect(in: CGRect(origin: pt(5.5, 6), size: CGSize(width: 13 * s, height: 16.5 * s)),
                         cornerSize: CGSize(width: 2 * s, height: 2 * s))
        for y in [10.1, 14.2, 18.3] as [CGFloat] {
            p.move(to: pt(5.5, y)); p.addLine(to: pt(18.5, y))
        }
        // The selector pin through the second plate.
        p.move(to: pt(12, 12.1)); p.addLine(to: pt(15.5, 12.1))
        return p
    }
}

/// An SF Symbol name, or `LookIcon.machine` for the custom weight-stack glyph.
/// Components that take `symbol: String` (EquipmentRow, LookRow, Chip, IconDisc) render
/// through this, so screens can pass `LookIcon.machine` anywhere a symbol goes.
struct LookIcon: View {
    /// Pass as a symbol name to draw the machine (weight-stack) glyph.
    static let machine = "lookicon.machine"

    var name: String
    /// The glyph's text style (the machine glyph scales with it like a symbol).
    var style: Font.TextStyle
    var weight: Font.Weight

    @ScaledMetric private var side: CGFloat

    init(_ name: String, style: Font.TextStyle = .body, weight: Font.Weight = .semibold) {
        self.name = name
        self.style = style
        self.weight = weight
        _side = ScaledMetric(wrappedValue: LookIcon.baseSize(style), relativeTo: style)
    }

    var body: some View {
        if name == Self.machine {
            WeightStackGlyph()
                .stroke(style: StrokeStyle(lineWidth: max(1.4, side * (weight == .bold || weight == .heavy ? 0.1 : 0.085)),
                                           lineCap: .round, lineJoin: .round))
                .frame(width: side, height: side)
                .accessibilityHidden(true)
        } else {
            Image(systemName: name).font(.system(style, weight: weight))
        }
    }

    /// Point size a symbol of this text style draws at (≈ the style's size + 1).
    private static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 36
        case .title: 30
        case .title2: 24
        case .title3: 22
        case .headline, .body: 19
        case .callout: 18
        case .subheadline: 17
        case .footnote: 15
        case .caption: 14
        case .caption2: 13
        @unknown default: 19
        }
    }
}
