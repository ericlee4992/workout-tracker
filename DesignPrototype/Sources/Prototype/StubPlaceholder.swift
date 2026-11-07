import SwiftUI

/// PROTOTYPE — placeholder used by Stubs/ for areas not built yet in an isolated area build.
struct StubPlaceholder: View {
    let name: String
    init(_ name: String) { self.name = name }
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hammer")
            Text("\(name) — not in this build").font(.headline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
