import SwiftUI

/// Time in zones as one stacked bar — each zone's share of the workout in its
/// colour — with the durations beneath. The finish sheet's card since
/// milestone 9; shared with History's workout detail from ticket 14 (the
/// user: "in history I also want to be able to see time spent in hr zone").
/// The record still knows whether these came from 220−age
/// (`zonesFromEstimatedMax`); the screen no longer says so (D52).
struct ZoneTimeCard: View {
    let seconds: [Int]

    private var present: [HeartRateZone] {
        HeartRateZone.allCases.filter { zone in
            zone.rawValue < seconds.count && seconds[zone.rawValue] > 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text("Time in zones")
                .font(Theme.cardTitle)
            GeometryReader { geometry in
                let widths = ZoneBarLayout.widths(
                    values: present.map { seconds[$0.rawValue] }, width: geometry.size.width, gap: 2)
                HStack(spacing: 2) {
                    ForEach(Array(present.enumerated()), id: \.element) { index, zone in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zone.color)
                            // One width per zone by contract; the guard is
                            // belt and braces against a trap during layout.
                            .frame(width: index < widths.count ? widths[index] : 0)
                    }
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)
            VStack(spacing: 6) {
                ForEach(present, id: \.self) { zone in
                    HStack(spacing: 8) {
                        Circle().fill(zone.color).frame(width: 8, height: 8)
                        Text(zone.label).font(.caption)
                        Spacer()
                        Text(Format.duration(seconds: seconds[zone.rawValue]))
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(Theme.Space.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
