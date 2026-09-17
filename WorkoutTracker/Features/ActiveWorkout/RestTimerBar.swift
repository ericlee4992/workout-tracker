import SwiftUI

struct RestTimerBar: View {
    var restEnd: Date
    var restTotal: Double
    var addFifteen: () -> Void
    var skip: () -> Void
    var expired: () -> Void

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var now = Date()
    /// Ticket 16: at accessibility sizes "+15s" and "Skip" broke mid-word beside
    /// the timer ("+15 / s", "Ski / p" — seen in ticket 11's captures). They
    /// take a row of their own under it there, equal widths; the default layout
    /// is untouched.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let remaining = max(0, restEnd.timeIntervalSince(now))
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: restTotal > 0 ? remaining / restTotal : 0)
                    Image(systemName: "hourglass").foregroundStyle(Theme.accent)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest").font(.caption).foregroundStyle(Theme.secondary)
                    Text(Format.duration(seconds: Int(remaining.rounded())))
                        .font(Theme.stat)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Button("+15s", action: addFifteen).buttonStyle(.secondary)
                    .frame(maxWidth: stacked ? .infinity : nil)
                Button("Skip", action: skip).buttonStyle(.primary)
                    .frame(maxWidth: stacked ? .infinity : nil)
            }
        }
        .padding(16)
        .card(.elevated)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onReceive(tick) { date in
            now = date
            if restEnd <= date { expired() }
        }
    }
}
