import SwiftUI

// Surfaces by role. A: raised "stand" panels separated by a hairline (flat, no shadow).
// B: solid cards with a 1 pt hairline and a faint top highlight (never glass).
// C: information = sheet + 1.5 pt soft rule; pressable = sheet + 2 pt ink outline.
// Only floating chrome (tab bar, toolbar buttons, rest bar) is glass.

enum SurfaceRole: Hashable {
    /// A group of information (week card, live strip, finish panels, exercise cards).
    case panel
    /// Alias of panel for single content cards.
    case card
    /// A pressable content tile (template tiles, gym picker).
    case tile
    /// Stat tiles / tickets.
    case stat
    /// Raised inner surface (machine row, cells, secondary fills).
    case raised
    /// The ground of a sheet.
    case sheet
    /// An editable field (draft weight / reps).
    case field
    /// Floating chrome: Liquid Glass.
    case glassChrome
}

struct LookSurface: ViewModifier {
    var role: SurfaceRole
    var radius: CGFloat?
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet

    private var cornerRadius: CGFloat {
        if let radius { return radius }
        switch role {
        case .panel, .card: return look.radius.panel
        case .tile: return look.radius.tile
        case .stat: return look.radius.stat
        case .raised: return look.radius.row
        case .sheet: return look.radius.sheet
        case .field: return look.radius.field
        case .glassChrome: return 999
        }
    }

    private var contentFill: Color { onSheet ? look.surfaceSheet : look.surface }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch role {
        case .glassChrome:
            content.glassEffect(.regular, in: Capsule())
        case .sheet:
            content.background(look.groundSheet, in: UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous))
        case .panel, .card, .stat:
            content
                .background(contentFill, in: shape)
                .overlay { infoEdge(shape) }
        case .tile:
            content
                .background(contentFill, in: shape)
                .overlay {
                    if look.id.isPaperClub {
                        shape.strokeBorder(look.outline, lineWidth: look.stroke.pressable)
                    } else {
                        infoEdge(shape)
                    }
                }
        case .raised:
            switch look.id {
            case .floodlight:
                content.background(look.surfaceRaised, in: shape)
            case .paper, .carbon:
                content
                    .background(look.surfaceRaised, in: shape)
                    .overlay { shape.strokeBorder(look.outline, lineWidth: 1.5) }
            }
        case .field:
            switch look.id {
            case .floodlight:
                content.background(look.field, in: shape)
            case .paper, .carbon:
                content
                    .background(look.field, in: shape)
                    .overlay { shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
            }
        }
    }

    @ViewBuilder
    private func infoEdge(_ shape: RoundedRectangle) -> some View {
        switch look.id {
        case .floodlight:
            shape.strokeBorder(look.hairline, lineWidth: look.stroke.hairline)
        case .paper, .carbon:
            shape.strokeBorder(look.hairline, lineWidth: look.stroke.hairline)
        }
    }
}

extension View {
    /// Draws the look's surface for a role behind this view (and its edge on top).
    func lookSurface(_ role: SurfaceRole, radius: CGFloat? = nil) -> some View {
        modifier(LookSurface(role: role, radius: radius))
    }

    /// Screen ground, edge to edge.
    func lookScreenBackground() -> some View {
        modifier(ScreenGround())
    }

    /// Marks content as living on a sheet: content surfaces switch to `surfaceSheet`
    /// (B's lighter sheet card). Environment only — it paints nothing.
    func lookSheetContext() -> some View {
        environment(\.lookOnSheet, true)
    }

    /// A sheet's root: paints the sheet ground edge to edge AND sets the sheet context.
    /// Use once on the sheet's outermost view (never on a card).
    func lookSheetGround() -> some View {
        modifier(SheetGround())
    }

    /// A dashed rounded outline ("make one", Add Set, today's cell).
    func dashedOutline(_ color: Color, radius: CGFloat, lineWidth: CGFloat = 1.5, dash: [CGFloat] = [5, 4]) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
        }
    }
}

private struct ScreenGround: ViewModifier {
    @Environment(\.look) private var look
    func body(content: Content) -> some View {
        content.background(look.ground.ignoresSafeArea())
    }
}

private struct SheetGround: ViewModifier {
    @Environment(\.look) private var look
    func body(content: Content) -> some View {
        content
            .environment(\.lookOnSheet, true)
            .background(look.groundSheet.ignoresSafeArea())
    }
}

/// A padded panel container: `LookPanel { … }`.
struct LookPanel<Content: View>: View {
    var role: SurfaceRole = .panel
    var padding: CGFloat?
    @ViewBuilder var content: Content
    @Environment(\.look) private var look

    var body: some View {
        content
            .padding(padding ?? look.space.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(role)
    }
}

/// A hairline separator in the look's rule colour.
struct LookDivider: View {
    var vertical = false
    @Environment(\.look) private var look
    @Environment(\.lookOnSlab) private var onSlab

    var body: some View {
        let color = onSlab ? look.onSlab.opacity(0.16) : look.hairline
        if vertical {
            Rectangle().fill(color).frame(width: look.stroke.hairline)
        } else {
            Rectangle().fill(color).frame(height: look.stroke.hairline)
        }
    }
}
