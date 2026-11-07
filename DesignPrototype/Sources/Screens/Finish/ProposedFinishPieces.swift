import SwiftUI

// PROPOSAL (2026-11) — the receipt leads with what was won.

/// The first new best, big: the exercise, the new figure, and what it beat. Any others follow
/// as one line each.
struct ProposedBestsHero: View {
    let bests: [FinishBestRowData]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = bests.first { lead(first) }
            ForEach(bests.dropFirst()) { best in
                LookDivider().padding(.vertical, 12)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "burst.fill").font(.system(.footnote, weight: .bold))
                    Text(best.name).font(.system(.subheadline, weight: .semibold))
                    Spacer(minLength: 6)
                    Text(Format.set(best.value, loadType: best.loadType))
                        .font(look.font.smallNumber).monospacedDigit()
                }
                .foregroundStyle(look.textPrimary)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .onAppear {
            if reduceMotion { shown = true } else { withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.35)) { shown = true } }
        }
    }

    private func lead(_ best: FinishBestRowData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "burst.fill")
                Text(bests.count == 1 ? "New best" : "\(bests.count) new bests")
            }
            .font(.system(.subheadline, weight: .bold))
            .foregroundStyle(look.textPrimary)
            Text(best.name)
                .font(look.font.cardTitle)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(Format.set(best.value, loadType: best.loadType))
                .font(look.font.heroNumber)
                .foregroundStyle(look.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .scaleEffect(shown ? 1 : 0.82, anchor: .leading)
                .opacity(shown ? 1 : 0)
            HStack(spacing: 6) {
                if let previous = best.previous {
                    Text("was \(Format.set(previous, loadType: best.loadType))")
                }
                if let equipment = best.equipment {
                    Text("· \(equipment)")
                }
            }
            .font(look.font.subhead)
            .foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The six tiles as one line: time · volume · average heart rate (calories are in History).
struct ProposedStatLine: View {
    let tiles: [FinishTile]
    @Environment(\.look) private var look

    var body: some View {
        let picks: [FinishTileKind] = [.workoutTime, .totalVolume, .averageHeartRate]
        let parts = picks.compactMap { kind in tiles.first { $0.kind == kind } }
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.element.id) { index, tile in
                if index > 0 {
                    Text("  ·  ").foregroundStyle(look.textTertiary)
                }
                Text(tile.value).font(look.font.smallNumber).foregroundStyle(look.textPrimary)
                if !tile.unit.isEmpty {
                    Text(" \(tile.kind == .averageHeartRate ? "bpm avg" : tile.unit)")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }
}
