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

        VStack(spacing: 8) {
            HStack {
                Label("Rest", systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Format.duration(seconds: Int(remaining.rounded())))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Spacer()
                Button("+15s", action: addFifteen)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Skip", action: skip)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            ProgressView(value: restTotal > 0 ? remaining / restTotal : 0)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .onReceive(tick) { date in
            now = date
            if restEnd <= date { expired() }
        }
    }
}
