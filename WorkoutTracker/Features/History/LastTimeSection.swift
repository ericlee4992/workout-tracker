import SwiftData
import SwiftUI

/// Live-workout 03 (D87): "Last time" at the top of the chart opened from a live exercise — the sets of the latest
/// finished session in the context the user is logging now, so the chart replaces Previous performance without
/// losing what it showed first. The layers are `PerformanceHistory`'s (D1/D11/D23): this machine (or this free-weight
/// tag) first; with none, the same model at another gym; then the exercise on any equipment. Each fallback says
/// which it is, because only the first is the same thing done before — and the only one that prefills.
///
/// It follows the entry, not the chart's machine selector: the selector picks what to chart, "Last time" answers
/// what this exercise, as set up now, did last.
///
/// The caller loads the layer (`load(for:in:)`) and owns it: a `.task` on this view would never run while it is
/// empty, which is exactly when it has to load.
struct LastTimeSection: View {
    let entry: ExerciseEntry
    let layer: PerformanceLayerResult
    let snapshot: PreviousPerformanceSnapshot
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    /// nil when the layer has nothing to show.
    init?(entry: ExerciseEntry, layer: PerformanceLayerResult?) {
        guard let layer, let snapshot = layer.snapshot else { return nil }
        self.entry = entry
        self.layer = layer
        self.snapshot = snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Last time", trailing: HistoryFormat.shortDayTitle(snapshot.workoutDate))
            panel(snapshot, kind: layer.kind)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lastTime")
    }

    private func panel(_ snapshot: PreviousPerformanceSnapshot, kind: PerformanceLayerKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text([snapshot.shortEquipmentLabel, snapshot.gymName].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = fallbackNote(kind) {
                    Text(note)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("lastTimeFallback")
                }
            }
            // Two columns of sets at the default size keep the section short; one at accessibility sizes.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading),
                                     count: typeSize.isAccessibilitySize ? 1 : 2),
                      alignment: .leading, spacing: 8) {
                ForEach(numbered(snapshot.sets), id: \.set.id) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.marker)
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(look.textTertiary)
                            .frame(minWidth: 18, alignment: .leading)
                        Text(item.set.displayLabel)
                            .font(look.historyRowNumber)
                            .foregroundStyle(look.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(item))
                    .accessibilityIdentifier("lastTimeSet")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    /// Working sets numbered among themselves (1, 2, 3); a warmup, failure or drop set wears its letter.
    private func numbered(_ sets: [PreviousSetValue]) -> [(marker: String, set: PreviousSetValue)] {
        var working = 0
        return sets.map { set in
            if let marker = set.type.marker { return (marker, set) }
            working += 1
            return ("\(working)", set)
        }
    }

    private func accessibilityLabel(_ item: (marker: String, set: PreviousSetValue)) -> String {
        let kind = item.set.type == .working ? "Set \(item.marker)" : item.set.type.displayName
        return "\(kind), \(item.set.displayLabel)"
    }

    /// Nil for this machine (the real "last time"); otherwise which history it is.
    private func fallbackNote(_ kind: PerformanceLayerKind) -> String? {
        switch kind {
        case .thisEquipment: nil
        case .sameModelElsewhere: "Same model at another gym"
        case .anyEquipment: entry.machine != nil ? "Not on this machine" : "Other equipment"
        }
    }

    /// The most specific layer with a session, or nil.
    static func load(for entry: ExerciseEntry, in context: ModelContext) -> PerformanceLayerResult? {
        guard !entry.isDeleted else { return nil }
        do {
            return try PerformanceHistory(context: context).layers(for: entry).first { $0.snapshot != nil }
        } catch {
            assertionFailure("Failed to load last time: \(error)")
            return nil
        }
    }
}
