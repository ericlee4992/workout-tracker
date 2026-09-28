import Foundation
import Testing
@testable import WorkoutTracker

// Floodlight ticket 09 — the per-device last-export record and the backup readouts.

struct ExportRecordTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    private let locale = Locale(identifier: "en_US")
    /// 2026-09-28 12:00 New York.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))! }

    private func day(_ offset: Int, hour: Int = 18) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: hour))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    @Test func neverExportedCountsEveryWorkout() {
        #expect(BackupStatus.pending(workoutDates: [day(-3), day(-2)], lastExport: nil) == 2)
        #expect(BackupStatus.pending(workoutDates: [], lastExport: nil) == 0)
    }

    @Test func pendingCountsWorkoutsStartedAfterTheExport() {
        let export = day(-2)
        // A workout started at the export instant was in that file.
        let dates = [day(-5), export, day(-1), day(0, hour: 9)]
        #expect(BackupStatus.pending(workoutDates: dates, lastExport: export) == 2)
    }

    @Test func theOnlyCopyNoticeRestsThreeDaysAfterAnExport() {
        #expect(BackupStatus.showsOnlyCopyNotice(lastExport: nil, now: now))
        #expect(!BackupStatus.showsOnlyCopyNotice(lastExport: now.addingTimeInterval(-3600), now: now))
        #expect(!BackupStatus.showsOnlyCopyNotice(lastExport: now.addingTimeInterval(-3 * 86_400), now: now))
        #expect(BackupStatus.showsOnlyCopyNotice(lastExport: now.addingTimeInterval(-3 * 86_400 - 1), now: now))
    }

    @Test func lastExportLineNamesTheDayAndFormat() {
        let today = ExportRecord(date: now.addingTimeInterval(-600), format: .csv)
        #expect(BackupStatus.lastExportLine(today, now: now, calendar: calendar, locale: locale) == "Last export Today · CSV")
        let old = ExportRecord(date: day(-16), format: nil)
        #expect(BackupStatus.lastExportLine(old, now: now, calendar: calendar, locale: locale) == "Last export Sep 12")
        let json = ExportRecord(date: day(-1), format: .json)
        #expect(BackupStatus.lastExportLine(json, now: now, calendar: calendar, locale: locale) == "Last export Yesterday · JSON")
    }

    @Test func tallyStacksSameDayWorkoutsAndSpansToToday() {
        let dates = [day(-10), day(-4, hour: 7), day(-4, hour: 19), day(-1)]
        let tally = BackupStatus.tally(workoutDates: dates.shuffled(), lastExport: day(-4, hour: 12), now: now,
                                       calendar: calendar)
        #expect(tally.span == 11)
        #expect(tally.marks.map(\.day) == [0, 6, 6, 9])
        #expect(tally.marks.map(\.stack) == [0, 0, 1, 0])
        #expect(tally.marks.map(\.exported) == [true, true, false, false])
        #expect(tally.exportDay == 6)
        #expect(tally.start == calendar.startOfDay(for: day(-10)))
    }

    @Test func tallyReportsTheBusiestDay() {
        let dates = [day(-3), day(-1, hour: 7), day(-1, hour: 12), day(-1, hour: 18), day(-1, hour: 21)]
        let tally = BackupStatus.tally(workoutDates: dates, lastExport: nil, now: now, calendar: calendar)
        #expect(tally.tallestStack == 4)
        #expect(tally.marks.filter { $0.day == 2 }.map(\.stack) == [0, 1, 2, 3])
        #expect(BackupStatus.tally(workoutDates: [], lastExport: nil, now: now, calendar: calendar).tallestStack == 1)
    }

    /// Success → failed replacement → leaving: every staged file is deleted (codex-review-09 #2).
    @Test func stagingDeletesReplacedAndReleasedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "ExportStagingTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        var staging = ExportStaging()
        let first = try ExportFileWriter.write(Data("a".utf8), format: .csv, in: root)
        staging.adopt(first)
        #expect(FileManager.default.fileExists(atPath: first.path))
        // A later write that fails leaves the first on disk (ExportFileWriter keeps it); the screen
        // then releases its handle.
        staging.release()
        #expect(!FileManager.default.fileExists(atPath: first.deletingLastPathComponent().path))
        #expect(staging.url == nil)
        // A newer file replaces the older one.
        let second = try ExportFileWriter.write(Data("b".utf8), format: .json, in: root)
        staging.adopt(second)
        let third = try ExportFileWriter.write(Data("c".utf8), format: .csv, in: root)
        staging.adopt(third)
        #expect(!FileManager.default.fileExists(atPath: second.path))
        #expect(FileManager.default.fileExists(atPath: third.path))
        staging.release()
        #expect(!FileManager.default.fileExists(atPath: third.path))
    }

    @Test func tallyWithoutHistoryOrExport() {
        let empty = BackupStatus.tally(workoutDates: [], lastExport: nil, now: now, calendar: calendar)
        #expect(empty.span == 1 && empty.marks.isEmpty && empty.exportDay == nil)
        // An export before the first workout (history restored later) has no place on the line.
        let before = BackupStatus.tally(workoutDates: [day(-2)], lastExport: day(-9), now: now, calendar: calendar)
        #expect(before.exportDay == nil)
        #expect(before.marks.map(\.exported) == [false])
    }

    @Test func recordRoundTripsThroughDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "ExportRecordTests-\(UUID())"))
        #expect(ExportRecord.read(defaults) == nil)
        let record = ExportRecord(date: now, format: .json)
        ExportRecord.write(record, defaults)
        #expect(ExportRecord.read(defaults) == record)
        ExportRecord.clear(defaults)
        #expect(ExportRecord.read(defaults) == nil)
    }

    @Test func keyHintShowsTheLastFourOnly() {
        #expect(AskAIKeyHint.masked("sk-proj-7Hq2c9Tza1b2") == "sk-…a1b2")
        #expect(AskAIKeyHint.masked("  abcdefgh1234\n") == "…1234")
        #expect(AskAIKeyHint.masked("short") == "…")
    }
}
