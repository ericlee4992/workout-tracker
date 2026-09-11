import SwiftUI

/// Milestone 9, ticket 03 — when did I train? Month grids, a mark on every
/// day a finished workout STARTED (the day the rest of History files it
/// under), tap a marked day to open that session.
///
/// Presentation only: `WorkoutCalendar` decides what the cells are.
struct HistoryCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss

    let calendar: WorkoutCalendar
    /// Called with the tapped day's start; the presenter finds the session.
    let onPick: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                        ForEach(calendar.months) { month in
                            monthView(month)
                                .id(month.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(Theme.background)
                .onAppear {
                    // Most recent at the bottom, and that is where the user
                    // starts — the calendar is for "when did I last…", not
                    // for archaeology.
                    if let last = calendar.months.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                weekdayHeader
                    .background(Theme.background)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .accessibilityIdentifier("closeCalendar")
                }
            }
        }
        .accessibilityIdentifier("historyCalendarSheet")
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(calendar.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(Theme.label)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal)
    }

    private func monthView(_ month: WorkoutCalendar.Month) -> some View {
        // UI redesign ticket 06: one card per month.
        VStack(alignment: .leading, spacing: Theme.Space.medium) {
            Text(month.title)
                .font(Theme.cardTitle)
                .accessibilityIdentifier("calendarMonth")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(month.cells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(Theme.Space.inset)
        .card()
    }

    /// Everything a cell's look depends on, decided ONCE per combined state.
    /// codex-review 03b: fill, text and interactivity were three separate
    /// mappings, and the gap between them is exactly where a marked-future
    /// day fell through. UI redesign ticket 06: a workout day is an accent
    /// disc (the fill IS the mark — no check any more); today a ring; a
    /// workout dated in the future a hollow accent ring with full-contrast
    /// numerals (codex-review-06: a dimmed disc was 2:1 against the card).
    /// A ring stays INSIDE the 40 pt cell — the columns have no horizontal
    /// spacing, so anything painted outside would overlap its neighbour on a
    /// 375 pt phone (codex-review-06b); under a ring the disc is inset so the
    /// ring meets the card, never amber.
    private struct CellStyle {
        var fill: Color
        var ring: Color?
        var text: Color
        var weight: Font.Weight
        var isTappable: Bool
        var accessibilityLabel: String

        init(_ emphasis: WorkoutCalendar.Day.Emphasis, dayOfMonth: Int) {
            switch emphasis {
            case .plain:
                self.init(fill: .clear, ring: nil, text: Theme.text, weight: .regular,
                          tappable: false, label: "Day \(dayOfMonth)")
            case .future:
                self.init(fill: .clear, ring: nil, text: Theme.tertiary, weight: .regular,
                          tappable: false, label: "Day \(dayOfMonth)")
            case .today:
                self.init(fill: .clear, ring: Theme.secondary, text: Theme.text, weight: .semibold,
                          tappable: false, label: "Today")
            case .marked:
                self.init(fill: Theme.accent, ring: nil, text: Theme.onAccent, weight: .semibold,
                          tappable: true, label: "Workout on day \(dayOfMonth)")
            case .markedToday:
                self.init(fill: Theme.accent, ring: Theme.secondary, text: Theme.onAccent, weight: .bold,
                          tappable: true, label: "Workout today")
            case .markedFuture:
                // A real workout, so it keeps the mark and the tap — hollow,
                // so it is not mistaken for a day that has happened.
                self.init(fill: .clear, ring: Theme.accent, text: Theme.text,
                          weight: .semibold, tappable: true,
                          label: "Workout on day \(dayOfMonth), dated in the future")
            }
        }

        private init(fill: Color, ring: Color?, text: Color, weight: Font.Weight, tappable: Bool, label: String) {
            self.fill = fill; self.ring = ring; self.text = text; self.weight = weight
            self.isTappable = tappable; self.accessibilityLabel = label
        }
    }

    @ViewBuilder
    private func dayCell(_ day: WorkoutCalendar.Day) -> some View {
        let style = CellStyle(day.emphasis, dayOfMonth: day.dayOfMonth)
        let label = Text("\(day.dayOfMonth)")
            .font(.body.monospacedDigit())
            .fontWeight(style.weight)
            .frame(width: 40, height: 40)
            .background {
                // Under a ring the disc gives up 4 pt all round: a 2 pt gap
                // of card between amber and ring, and nothing painted beyond
                // the cell.
                Circle().fill(style.fill).padding(style.ring == nil ? 0 : 4)
            }
            .overlay {
                if let ring = style.ring {
                    Circle().strokeBorder(ring, lineWidth: 2)
                }
            }
            .foregroundStyle(style.text)
        if style.isTappable {
            Button { onPick(day.date) } label: { label }
                .buttonStyle(.plain)
                .accessibilityLabel(style.accessibilityLabel)
                .accessibilityIdentifier("calendarDay.\(Self.key(day.date))")
                .frame(maxWidth: .infinity)
        } else {
            label
                .frame(maxWidth: .infinity)
                .accessibilityLabel(style.accessibilityLabel)
                .accessibilityIdentifier("calendarDay.\(Self.key(day.date))")
        }
    }

    /// A stable per-day identifier for tests, independent of locale.
    static func key(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
