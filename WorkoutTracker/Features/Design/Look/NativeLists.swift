import SwiftUI

// Floodlight on native lists: sheets that keep the system List / Form (search fields, swipe
// actions, pickers and toggles the UI tests and VoiceOver rely on) draw with the look's tokens.

extension View {
    /// On a `List` / `Form`: the look's sheet ground behind grouped rows, the action tint.
    func lookGroupedList() -> some View {
        modifier(LookGroupedList())
    }

    /// On a `Section` or row: the look's row surface and hairline separators.
    func lookListRows() -> some View {
        modifier(LookListRows())
    }
}

private struct LookGroupedList: ViewModifier {
    @Environment(\.look) private var look
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(look.groundSheet.ignoresSafeArea())
            .tint(look.actionText)
            .environment(\.lookOnSheet, true)
    }
}

private struct LookListRows: ViewModifier {
    @Environment(\.look) private var look
    func body(content: Content) -> some View {
        content
            .listRowBackground(look.surfaceSheet)
            .listRowSeparatorTint(look.hairline)
    }
}

/// A list section header in the look: a family's colour mark (never one per row), the title.
struct LookSectionLabel: View {
    var title: String
    var family: MuscleFamily?
    var symbol: String?
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 8) {
            if let family {
                Capsule().fill(look.family(family)).frame(width: 4, height: 16)
            } else if let symbol {
                Image(systemName: symbol).font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
            }
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .textCase(nil)
        }
        .accessibilityAddTraits(.isHeader)
    }
}
