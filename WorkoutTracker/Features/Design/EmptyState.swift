import SwiftUI

/// An illustration built from system symbols; callers supply existing copy.
struct EmptyState: View {
    var title: String
    var symbol: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Theme.accent.opacity(0.12), lineWidth: 1)
                    .frame(width: 128, height: 128)
                Circle().fill(Theme.accent.opacity(0.08))
                    .frame(width: 96, height: 96)
                Image(systemName: symbol)
                    .font(.largeTitle).foregroundStyle(Theme.accent)
                Image(systemName: "sparkle")
                    .font(.title3).foregroundStyle(Theme.accent)
                    .offset(x: 46, y: -42)
            }
            .accessibilityHidden(true)
            Text(title).font(Theme.cardTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.large)
    }
}
