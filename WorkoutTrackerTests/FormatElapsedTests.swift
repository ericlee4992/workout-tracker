import Testing
@testable import WorkoutTracker

// Ticket 16 — the active workout's running clock shows seconds.
struct FormatElapsedTests {
    @Test func underAnHourIsMinutesAndSeconds() {
        #expect(Format.elapsed(seconds: 0) == "0:00")
        #expect(Format.elapsed(seconds: 59) == "0:59")
        #expect(Format.elapsed(seconds: 754) == "12:34")
        #expect(Format.elapsed(seconds: 3599) == "59:59")
    }

    @Test func fromAnHourOnAddsHours() {
        #expect(Format.elapsed(seconds: 3600) == "1:00:00")
        #expect(Format.elapsed(seconds: 3723) == "1:02:03")
    }

    @Test func negativeIsZero() {
        #expect(Format.elapsed(seconds: -5) == "0:00")
    }
}
