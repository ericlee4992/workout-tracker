import SwiftUI

struct StatTile: View {
    var value: String
    var label: String
    var symbol: String
    var tint: Color = Theme.accent
    var identifier: String
    var accessibilityText: String

    var body: some View {
        // Symbol and label share a line so a grid of tiles stays short
        // enough that what follows it (the heart-rate chart) is not pushed
        // a screen down (D54 ticket 03).
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.caption.weight(.semibold)).foregroundStyle(tint)
                Text(label).font(.caption).foregroundStyle(Theme.secondary).lineLimit(1).minimumScaleFactor(0.85)
            }
            Text(value).font(Theme.stat).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.inset)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(identifier)
    }
}
