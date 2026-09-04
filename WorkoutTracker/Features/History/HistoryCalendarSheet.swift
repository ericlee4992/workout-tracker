import SwiftUI

/// Milestone 9, ticket 03 — when did I train? Month grids, a mark on every
/// day a workout finished, tap a marked day to open that session.
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
                    .background(.bar)
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal)
    }

    private func monthView(_ month: WorkoutCalendar.Month) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month.title)
                .font(.title3.weight(.semibold))
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
    }

    @ViewBuilder
    private func dayCell(_ day: WorkoutCalendar.Day) -> some View {
        let label = Text("\(day.dayOfMonth)")
            .font(.body.monospacedDigit())
            .frame(width: 40, height: 40)
        if day.isMarked {
            Button {
                onPick(day.date)
            } label: {
                label
                    .background(Circle().fill(Color(.secondarySystemFill)))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .offset(x: 4, y: -4)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workout on day \(day.dayOfMonth)")
            .accessibilityIdentifier("calendarDay.\(Self.key(day.date))")
            .frame(maxWidth: .infinity)
        } else {
            let text: Color = day.isToday
                ? Color(.systemBackground)
                : (day.isFuture ? Color.secondary.opacity(0.45) : Color.primary)
            label
                .background(Circle().fill(day.isToday ? Color.primary : Color.clear))
                .foregroundStyle(text)
                .frame(maxWidth: .infinity)
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
