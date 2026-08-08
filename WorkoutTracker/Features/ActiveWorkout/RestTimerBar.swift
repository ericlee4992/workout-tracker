import SwiftUI

struct RestTimerBar: View {
    @Binding var restEnd: Date?
    var restTotal: Double

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        let remaining = max(0, restEnd?.timeIntervalSince(now) ?? 0)

        VStack(spacing: 8) {
            HStack {
                Label("Rest", systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(timeString(remaining))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Spacer()
                Button("+15s") {
                    restEnd = restEnd?.addingTimeInterval(15)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Skip") {
                    restEnd = nil
                }
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
            if let end = restEnd, end <= date {
                restEnd = nil
            }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
