import Foundation
import Testing
@testable import WorkoutTracker

// Soft redesign S3 (Direction A): the finish screen compares with the template's last run only like for like.
struct FinishComparisonRuleTests {
    private func comparison(last: Double, today: Double) -> FinishReceipt.Comparison {
        FinishReceipt.Comparison(templateName: "Push Day", lastDate: Date(), lastVolumeKg: last, volumeKg: today)
    }

    @Test func aGainOrASmallDropIsShown() {
        #expect(comparison(last: 1000, today: 1200).isShownAtFinish)
        #expect(comparison(last: 1000, today: 1000).isShownAtFinish)
        #expect(comparison(last: 1000, today: 750).isShownAtFinish)   // exactly −25 %
    }

    @Test func aDropOfMoreThanAQuarterIsHidden() {
        #expect(!comparison(last: 1000, today: 749).isShownAtFinish)
        #expect(!comparison(last: 1000, today: 200).isShownAtFinish)
    }

    @Test func aRunWithoutVolumeIsNeverCompared() {
        #expect(!comparison(last: 0, today: 500).isShownAtFinish)
        #expect(!comparison(last: 800, today: 0).isShownAtFinish)
    }
}
