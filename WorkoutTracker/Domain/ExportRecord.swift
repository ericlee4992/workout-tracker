import Foundation

// Floodlight ticket 09 — when this phone last handed an export to somewhere else, and the
// backup readouts built on it (Settings' export card, the Export screen's panel and tally strip).
//
// Per device, in UserDefaults (like Appearance), not in SwiftData: the fact is about THIS phone's
// copy ("This phone holds the only copy until you export."), it must not change the schema or the
// export format, and a restored store must not claim the old phone's backup. Recorded only when
// the share sheet reports a completed action — a cancelled share is not a backup (user decision 1).

struct ExportRecord: Equatable {
    static let dateKey = "exportLastAt"
    static let formatKey = "exportLastFormat"

    var date: Date
    var format: ExportFormat?

    /// Reads the stored record; nil when this phone has never completed an export.
    static func read(_ defaults: UserDefaults = .standard) -> ExportRecord? {
        guard let seconds = defaults.object(forKey: dateKey) as? Double else { return nil }
        return ExportRecord(date: Date(timeIntervalSinceReferenceDate: seconds),
                            format: defaults.string(forKey: formatKey).flatMap(ExportFormat.init(rawValue:)))
    }

    static func write(_ record: ExportRecord, _ defaults: UserDefaults = .standard) {
        defaults.set(record.date.timeIntervalSinceReferenceDate, forKey: dateKey)
        defaults.set(record.format?.rawValue, forKey: formatKey)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: formatKey)
    }
}

enum BackupStatus {
    /// "This phone holds the only copy until you export." rests for this long after an export, so
    /// it never sits under "Last export Today".
    static let noticeRest: TimeInterval = 3 * 24 * 3600

    /// Workouts started after the last export (every workout when there has been none). A workout
    /// started at the export instant was in that file.
    static func pending(workoutDates: [Date], lastExport: Date?) -> Int {
        guard let lastExport else { return workoutDates.count }
        return workoutDates.filter { $0 > lastExport }.count
    }

    static func showsOnlyCopyNotice(lastExport: Date?, now: Date) -> Bool {
        guard let lastExport else { return true }
        return now.timeIntervalSince(lastExport) > noticeRest
    }

    /// "Last export Today · CSV", "Last export Sep 12" (a record from before the format was kept).
    static func lastExportLine(_ record: ExportRecord, now: Date, calendar: Calendar = .current,
                               locale: Locale = .current) -> String {
        let day = ExerciseDates.relative(record.date, now: now, calendar: calendar, locale: locale)
        return "Last export \(day)" + (record.format.map { " · \($0.label)" } ?? "")
    }

    /// One tally mark per workout on a day line from the first workout's day to today.
    struct Mark: Equatable, Identifiable {
        var id: Int
        /// Days from the first workout's day.
        var day: Int
        /// 0 for the day's first workout; a second workout that day stacks above it.
        var stack: Int
        var date: Date
        /// In the last export (started at or before it).
        var exported: Bool
    }

    struct Tally: Equatable {
        var marks: [Mark]
        /// Days on the line (first workout's day through today), at least 1.
        var span: Int
        /// The export mark's day on the line; nil when never exported or before the first workout.
        var exportDay: Int?
        var start: Date
        var end: Date
        /// The most workouts on one day (the strip's height is sized from it).
        var tallestStack: Int { (marks.map(\.stack).max() ?? 0) + 1 }
    }

    static func tally(workoutDates: [Date], lastExport: Date?, now: Date, calendar: Calendar = .current) -> Tally {
        let sorted = workoutDates.sorted()
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: min(sorted.first ?? now, now))
        func day(_ date: Date) -> Int {
            calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        }
        var perDay: [Int: Int] = [:]
        let marks = sorted.enumerated().map { index, date in
            let d = day(date)
            let stack = perDay[d, default: 0]
            perDay[d] = stack + 1
            return Mark(id: index, day: d, stack: stack, date: date,
                        exported: lastExport.map { date <= $0 } ?? false)
        }
        let span = max(1, day(today) + 1, (marks.map(\.day).max() ?? 0) + 1)
        let exportDay = lastExport.flatMap { export -> Int? in
            let d = day(export)
            return d >= 0 ? min(d, span - 1) : nil
        }
        return Tally(marks: marks, span: span, exportDay: exportDay, start: start, end: today)
    }
}

/// The saved key as the Ask AI sheet shows it (ticket 09, user decision 3):
/// the last four characters only, never more.
enum AskAIKeyHint {
    static func masked(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return "…" }
        let tail = String(trimmed.suffix(4))
        return (trimmed.hasPrefix("sk-") ? "sk-…" : "…") + tail
    }
}
