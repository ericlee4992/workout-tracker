import SwiftUI

/// The whole watch UI: what your heart is doing, and how long until your next
/// set. Nothing else — the phone is where a workout is logged (ticket 04).
struct WatchRootView: View {
    @State private var model = WatchWorkoutModel()

    var body: some View {
        VStack(spacing: 6) {
            switch model.state {
            case .idle, .starting:
                waiting
            case .running:
                reading
            case .denied:
                message("Heart rate needs permission in the Health app.")
            case .unavailable:
                message("This watch can't measure heart rate.")
            }
        }
        .padding()
    }

    private var waiting: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart")
                .font(.title2)
                .foregroundStyle(.red)
            Text("Not connected")
                .font(.headline)
            Text("Start a workout on your iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var reading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundStyle(model.isStale ? Color.secondary : Color.red)
                .symbolEffect(.pulse, isActive: !model.isStale && model.latestBpm != nil)
            if let bpm = model.latestBpm {
                Text("\(bpm)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    // Stale is greyed rather than hidden: a number that stopped
                    // updating is still the last thing known, but it must not
                    // look current (the phone's rule, on the wrist).
                    .foregroundStyle(model.isStale ? Color.secondary : Color.primary)
                Text("bpm").font(.caption2)
            } else {
                Text("—").font(.system(size: 44, weight: .semibold, design: .rounded))
            }
        }

        if let restEndsAt = model.restEndsAt, restEndsAt > .now {
            // Mirrored from the phone, which owns when a rest ends (D43).
            Text(timerInterval: Date.now...restEndsAt, countsDown: true)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.tint)
        } else if model.isStale {
            Text("No reading")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    WatchRootView()
}
