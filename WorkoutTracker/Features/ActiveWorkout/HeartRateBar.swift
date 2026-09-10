import SwiftUI

// Milestone 7, ticket 05 — heart rate on the workout screen (D41, D44, D45).
//
// Every state this bar can be in renders as something a user can act on. A
// state that renders as blank space is a state the user reads as a bug, and the
// three quiet failures here — no permission, no sensor, a sensor that went
// quiet — are exactly the ones a live-data feature spends its life in.

struct HeartRateBar: View {
    var monitor: HeartRateMonitor
    /// Opens the place where a measured maximum can be entered (D45).
    var editMaxHeartRate: () -> Void

    var body: some View {
        // Idle renders NOTHING — not an empty card. The container carries
        // padding and a background, so an `EmptyView` inside it leaves a blank
        // rounded rectangle floating above the exercises.
        if case .idle = monitor.state {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch monitor.state {
            case .idle:
                EmptyView()
            case .needsAuthorization:
                message("Heart rate needs permission in Health", systemImage: "heart.text.square")
            case .denied:
                message(
                    "Heart rate is off. Turn it on in Settings › Health › Data Access.",
                    systemImage: "heart.slash")
            case .unavailable:
                message("This device can't measure heart rate", systemImage: "heart.slash")
            case .waitingForSensor, .live:
                liveContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .padding(.horizontal)
        // NO identifier on this container. In SwiftUI an accessibility
        // identifier applied to a container propagates to every descendant and
        // OVERRIDES theirs — every element inside reported `hrBar`, and
        // `hrBpm`/`hrSource`/`hrCalories` became unqueryable. The bar's presence
        // is asserted through its contents instead.
    }

    // MARK: Live

    @ViewBuilder
    private var liveContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                // Not animated when stale: a pulsing heart beside a number that
                // stopped updating is the app performing liveness it does not
                // have.
                .foregroundStyle(monitor.isStale ? Color.secondary : Theme.danger)
                .symbolEffect(.pulse, isActive: !monitor.isStale && monitor.current != nil)

            bpmText

            if let zone = monitor.currentZone {
                zoneChip(zone)
            }

            Spacer(minLength: 0)

            if let calories = monitor.activeEnergyKilocalories {
                Text("\(Int(calories.rounded())) cal")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .accessibilityIdentifier("hrCalories")
                    .accessibilityLabel("\(Int(calories.rounded())) active calories")
            }
        }

        HStack(spacing: 6) {
            Text(sourceLabel)
                .accessibilityIdentifier("hrSource")
            if monitor.isStale, let current = monitor.current {
                // The age, not just the word: "12s ago" tells the user whether
                // to wait or to reseat an earbud.
                Text("· \(Int(current.age(asOf: .now)))s ago")
            }
            if monitor.maxHeartRate == nil {
                // No measured max and no date of birth, so D45 forbids showing
                // a zone at all. Say that, rather than rendering nothing: the
                // absent chip is indistinguishable from a broken one, and the
                // screen that fixes it used to be reachable ONLY from the
                // "edit zones" button below — which needs a zone to exist.
                // A user who never set a maximum could therefore never set one.
                Button(action: editMaxHeartRate) {
                    Text("· set up zones")
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hrZoneSetup")
            } else if monitor.maxHeartRate?.isEstimated == true, monitor.currentZone != nil {
                Button(action: editMaxHeartRate) {
                    // The zone is from 220−age; the tap goes straight to the
                    // field that replaces the formula with a measured maximum.
                    // It used to say "· zone estimated" — D52 keeps the way in
                    // and drops the word.
                    Text("· edit zones")
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hrZoneEdit")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var bpmText: some View {
        Group {
            if let current = monitor.current {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(current.bpm)")
                        .font(Theme.stat)
                        .monospacedDigit()
                    Text("bpm").font(.caption)
                }
                .foregroundStyle(monitor.isStale ? Color.secondary : Theme.danger)
            } else {
                Text("Looking for a sensor…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        // Combined into one element: the number and its unit are two Texts, and
        // a bare identifier on the container is not queryable — VoiceOver and
        // XCUITest both need a single element with a label.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hrBpm")
        .accessibilityLabel(bpmAccessibilityLabel)
    }

    private var bpmAccessibilityLabel: String {
        guard let current = monitor.current else { return "Looking for a sensor" }
        return monitor.isStale
            ? "\(current.bpm) beats per minute, \(Int(current.age(asOf: .now))) seconds ago"
            : "\(current.bpm) beats per minute"
    }

    /// Zone as a label *and* a meter. Colour alone would fail for a colour-blind
    /// user and in bright gym light, so the number and the word carry it too.
    private func zoneChip(_ zone: HeartRateZone) -> some View {
        Chip(tint: zoneColor(zone)) {
            HStack(spacing: 5) {
                Text(zone.label)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { step in
                        Capsule()
                            .fill(step <= zone.rawValue ? zoneColor(zone) : Theme.fill)
                            .frame(width: 4, height: step <= zone.rawValue ? 11 : 7)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hrZone")
        .accessibilityLabel("\(zone.label), \(zone.descriptionText)")
    }

    private func zoneColor(_ zone: HeartRateZone) -> Color {
        switch zone {
        case .warm: .secondary
        case .one: .blue
        case .two: .teal
        case .three: .green
        case .four: .orange
        case .five: .red
        }
    }

    /// The source of the number actually on screen — read from `current`, not
    /// from the feed state, so the label can never name a different sensor than
    /// the reading beside it (codex-review 3.3).
    private var sourceLabel: String {
        if let source = monitor.current?.source, !monitor.isStale {
            return source.label
        }
        if case .waitingForSensor = monitor.state {
            return monitor.current == nil ? "No sensor reporting" : "Not reporting"
        }
        return monitor.current?.source.label ?? ""
    }

    private func message(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("hrMessage")
    }
}

#Preview {
    let monitor = HeartRateMonitor(provider: FixtureHeartRateProvider())
    monitor.maxHeartRate = MaxHeartRate(bpm: 184, isEstimated: true)
    return VStack {
        HeartRateBar(monitor: monitor, editMaxHeartRate: {})
        Spacer()
    }
    .task { await monitor.start() }
    .background(Color(.systemGroupedBackground))
}
