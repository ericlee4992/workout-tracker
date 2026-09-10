import SwiftUI

enum CardLevel { case standard, elevated }

private struct CardStyle: ViewModifier {
    var level: CardLevel

    func body(content: Content) -> some View {
        content
            .background(level == .elevated ? Theme.elevated : Theme.card,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func card(_ level: CardLevel = .standard) -> some View {
        modifier(CardStyle(level: level))
    }
}
