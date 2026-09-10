import SwiftUI

struct Chip<Content: View>: View {
    var tint: Color = Theme.secondary
    var selected = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? Theme.onAccent : tint)
            .background(selected ? Theme.accent : tint.opacity(0.12), in: Capsule())
    }
}

struct UnitChip: View {
    var unit: WeightUnit

    var body: some View {
        Chip(tint: unit == .kg ? Theme.unitKg : Theme.unitLb) {
            Text(unit.rawValue)
        }
    }
}
