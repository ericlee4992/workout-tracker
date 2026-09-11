import CoreGraphics

/// The stacked time-in-zones bar's arithmetic (UI redesign ticket 03), kept
/// pure so it can be pinned: the segment widths always sum to the width
/// minus the gaps, every visible segment keeps a minimum width, and the
/// space a minimum takes is paid by the largest segments — so a 1 s zone
/// beside an hour is a visible sliver and nothing spills past the card
/// (codex-review-03, P2).
enum ZoneBarLayout {
    /// Widths for `values` (positive durations, in display order) laid out in
    /// `width` with `gap` between neighbours. ALWAYS one width per value —
    /// zeros when there is no width (a zero-size geometry during layout), so
    /// a caller may index the result by position (codex-review-03b, P2).
    /// Widths sum to `width − gaps` whenever the gaps fit; when they do not,
    /// every width is zero.
    static func widths(
        values: [Int], width: CGFloat, gap: CGFloat = 2, minimum: CGFloat = 4
    ) -> [CGFloat] {
        let positive = values.map { CGFloat(max(0, $0)) }
        guard !positive.isEmpty else { return [] }
        guard width > 0 else { return positive.map { _ in 0 } }
        let available = max(0, width - gap * CGFloat(positive.count - 1))
        let total = positive.reduce(0, +)
        guard total > 0 else { return positive.map { _ in available / CGFloat(positive.count) } }
        // A minimum that cannot be afforded collapses to an even split.
        let floorEach = min(minimum, available / CGFloat(positive.count))
        var widths = positive.map { $0 / total * available }
        // Lift every sliver to the floor, and take the difference from the
        // largest segments, largest first, never below the floor themselves.
        var deficit: CGFloat = 0
        for index in widths.indices where widths[index] < floorEach {
            deficit += floorEach - widths[index]
            widths[index] = floorEach
        }
        for index in widths.indices.sorted(by: { widths[$0] > widths[$1] }) where deficit > 0 {
            let room = widths[index] - floorEach
            let take = min(room, deficit)
            widths[index] -= take
            deficit -= take
        }
        return widths
    }
}
