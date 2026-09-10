import SwiftUI

struct RestTimerBar: View {
    var restEnd: Date
    var restTotal: Double
    var addFifteen: () -> Void
    var skip: () -> Void
    var expired: () -> Void

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        let remaining = max(0, restEnd.timeIntervalSince(now))

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
            Button("+15s", action: addFifteen).buttonStyle(.secondary)
            Button("Skip", action: skip).buttonStyle(.primary)
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
