import Combine
import SwiftUI
import UIKit

// A screen's "now" that stays current: a screen left open past midnight (or across the week's first day) must not
// keep calling yesterday "Today" or last week "This week". Reading `Date.now` while rendering is not enough — nothing
// re-renders when only the clock moves (codex-review-s2 #2, codex-review-s4 #2).

extension View {
    /// Sets `now` to the current time at the local day boundary (`NSCalendarDayChanged`), on a clock change, on a
    /// time-zone change and whenever the app becomes active.
    func refreshingNow(_ now: Binding<Date>) -> some View {
        modifier(RefreshingNow(now: now))
    }
}

private struct RefreshingNow: ViewModifier {
    @Binding var now: Date
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onReceive(Self.clockChanges) { _ in now = .now }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
    }

    /// The day boundary, a clock change and a time-zone change, on the main run loop.
    private static var clockChanges: AnyPublisher<Notification, Never> {
        let center = NotificationCenter.default
        return Publishers.MergeMany(
            center.publisher(for: .NSCalendarDayChanged),
            center.publisher(for: UIApplication.significantTimeChangeNotification),
            center.publisher(for: .NSSystemTimeZoneDidChange))
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
