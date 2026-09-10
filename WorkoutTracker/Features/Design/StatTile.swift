import SwiftUI

struct StatTile: View {
    var value: String
    var label: String
    var symbol: String
    var tint: Color = Theme.accent
    var identifier: String
    var accessibilityText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(Theme.stat).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.inset)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(identifier)
    }
}
