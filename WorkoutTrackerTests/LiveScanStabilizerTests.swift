import Foundation
import Testing

@testable import WorkoutTracker

// Live scanning — when the scanner is allowed to stop.
//
// The camera cannot be driven in a test, but this is the part that decides
// whether the app commits to an answer, and getting it wrong is felt
// immediately: settle too eagerly and one blurred frame picks the machine;
// settle too slowly and the user stands there waving their phone.

struct LiveScanStabilizerTests {

    private func reading(_ text: String) -> LabelReading {
        LabelReading.lines(text.components(separatedBy: " / "))
    }

    @Test func agreeingFramesSettle() throws {
        var stabilizer = LiveScanStabilizer()
        let key = "model-a"
        #expect(stabilizer.observe(reading("LIFE FITNESS / CHEST PRESS"), key: key) == nil,
                "one frame is not agreement")
        // Assigned first: `#require` captures its expression in a closure,
        // where a mutating call on a local `var` is not allowed.
        let second = stabilizer.observe(reading("LIFE FITNESS / CHEST PRESS"), key: key)
        let settled = try #require(second)
        #expect(settled.text.contains("CHEST PRESS"))
    }

    /// Frames disagree in what they *missed*, so the fullest reading of the
    /// agreeing run is the one to keep — not simply the last one in.
    @Test func theRichestAgreeingFrameWins() throws {
        var stabilizer = LiveScanStabilizer()
        _ = stabilizer.observe(reading("CHEST PRESS"), key: "model-a")
        let richer = stabilizer.observe(
            reading("LIFE FITNESS / INSIGNIA SERIES / CHEST PRESS"), key: "model-a")
        let settled = try #require(richer)
        #expect(settled.text.contains("INSIGNIA"), "kept the thinner frame")
    }

    @Test func theRichestFrameWinsEvenWhenItArrivesFirst() throws {
        var stabilizer = LiveScanStabilizer()
        _ = stabilizer.observe(reading("LIFE FITNESS / INSIGNIA SERIES / CHEST PRESS"),
                               key: "model-a")
        let thinner = stabilizer.observe(reading("CHEST PRESS"), key: "model-a")
        let settled = try #require(thinner)
        #expect(settled.text.contains("INSIGNIA"))
    }

    /// Moving the phone to another machine must not inherit the previous
    /// streak — that is how a scanner picks the machine you walked past.
    @Test func aDifferentAnswerRestartsTheStreak() {
        var stabilizer = LiveScanStabilizer()
        _ = stabilizer.observe(reading("CHEST PRESS"), key: "model-a")
        #expect(stabilizer.observe(reading("SHOULDER PRESS"), key: "model-b") == nil)
        #expect(stabilizer.observe(reading("LEG PRESS"), key: "model-c") == nil)
    }

    /// A frame that reads nothing usable is not a disagreement — it is a blur
    /// between two good frames, and it must not reset a healthy streak.
    @Test func anEmptyFrameDoesNotBreakAStreak() throws {
        var stabilizer = LiveScanStabilizer()
        _ = stabilizer.observe(reading("CHEST PRESS"), key: "model-a")
        #expect(stabilizer.observe(LabelReading(), key: "") == nil)
        #expect(stabilizer.observe(reading(""), key: "model-a") == nil,
                "an empty reading carries no tokens")
        let resumed = stabilizer.observe(reading("CHEST PRESS"), key: "model-a")
        let settled = try #require(resumed)
        #expect(settled.text.contains("CHEST"))
    }

    @Test func resetForgetsEverything() {
        var stabilizer = LiveScanStabilizer()
        _ = stabilizer.observe(reading("CHEST PRESS"), key: "model-a")
        stabilizer.reset()
        #expect(stabilizer.observe(reading("CHEST PRESS"), key: "model-a") == nil,
                "after a reset the next frame is the first frame again")
    }

    /// A stricter caller can demand more agreement; the default of two settles
    /// in well under a second at the ~3 readings/second the camera produces.
    @Test func theAgreementCountIsConfigurable() throws {
        var stabilizer = LiveScanStabilizer(agreementsNeeded: 3)
        #expect(stabilizer.observe(reading("CHEST PRESS"), key: "a") == nil)
        #expect(stabilizer.observe(reading("CHEST PRESS"), key: "a") == nil)
        #expect(stabilizer.observe(reading("CHEST PRESS"), key: "a") != nil)
    }
}
