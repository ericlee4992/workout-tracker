import Foundation
import Testing
@testable import WorkoutTracker

// Soft redesign S2/S3: the template "up next" on Today and leading Train.
struct TemplateDueNextTests {
    private let a = UUID(), b = UUID(), c = UUID()
    private let day: TimeInterval = 86_400

    @Test func theTemplateDoneLongestAgoLeads() {
        let now = Date()
        let id = TemplateStats.dueNext([(a, "Push"), (b, "Pull"), (c, "Legs")],
                                       lastRun: [a: now, b: now - 5 * day, c: now - 2 * day])
        #expect(id == b)
    }

    @Test func aNeverRunTemplateCountsAsLongestAgo() {
        let id = TemplateStats.dueNext([(a, "Push"), (b, "Pull")], lastRun: [a: Date() - 30 * day])
        #expect(id == b)
    }

    @Test func tiesGoToTheNameSoTheChoiceIsStable() {
        #expect(TemplateStats.dueNext([(a, "Push"), (b, "Legs"), (c, "Pull")], lastRun: [:]) == b)
        let same = Date()
        #expect(TemplateStats.dueNext([(a, "Push"), (b, "Arms")], lastRun: [a: same, b: same]) == b)
    }

    @Test func noTemplatesMeansNothingIsDue() {
        #expect(TemplateStats.dueNext([], lastRun: [:]) == nil)
    }
}
