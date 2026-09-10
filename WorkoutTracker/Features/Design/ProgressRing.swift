import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var tint: Color = Theme.accent
    var lineWidth: CGFloat = 5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(reduceMotion ? nil : .linear(duration: 0.5), value: progress)
        .accessibilityHidden(true)
    }
}
