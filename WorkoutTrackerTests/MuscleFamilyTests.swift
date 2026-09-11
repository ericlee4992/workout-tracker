import Foundation
import Testing
@testable import WorkoutTracker

// UI redesign ticket 11 — the template tile's icons are muscle FAMILIES
// (chest, back, shoulders, arms, legs), one each, head to toe. Pure logic,
// so this is the specification the tile renders.

struct MuscleFamilyTests {

    @Test func everySeededGroupMapsAsTheUserAsked() {
        #expect(MuscleFamily(muscleGroup: "Chest") == .chest)
        #expect(MuscleFamily(muscleGroup: "Back") == .back)
        #expect(MuscleFamily(muscleGroup: "Shoulders") == .shoulders)
        for arm in ["Biceps", "Triceps", "Forearms"] {
            #expect(MuscleFamily(muscleGroup: arm) == .arms, "\(arm)")
        }
        for leg in ["Quads", "Hamstrings", "Glutes", "Hips", "Calves"] {
            #expect(MuscleFamily(muscleGroup: leg) == .legs, "\(leg)")
        }
    }

    @Test func groupsOutsideTheFiveFamiliesHaveNoIcon() {
        for group in ["Core", "Neck", "Full Body", "Obliques", ""] {
            #expect(MuscleFamily(muscleGroup: group) == nil, "\(group)")
        }
        #expect(MuscleFamily(muscleGroup: nil) == nil)
    }

    /// The mapping covers the whole seeded vocabulary: a group is either a
    /// family or one of the three deliberate exceptions, never a typo.
    @Test func theSeededVocabularyIsFullyAccountedFor() {
        let exceptions: Set<String> = ["Core", "Neck", "Full Body"]
        for group in BodyArea.order {
            let mapped = MuscleFamily(muscleGroup: group) != nil
            #expect(mapped || exceptions.contains(group), "\(group)")
        }
    }

    @Test func familiesAreDeduplicatedAndOrderedHeadToToe() {
        let groups: [String?] = ["Calves", "Triceps", "Chest", nil, "Biceps", "Core", "Quads", "Chest"]
        #expect(MuscleFamily.families(of: groups) == [.chest, .arms, .legs])
        #expect(MuscleFamily.families(of: []) == [])
        #expect(MuscleFamily.families(of: ["Core", nil]) == [])
    }

    @Test func aFiveFamilyTemplateShowsFiveIconsAtMost() {
        let groups: [String?] = BodyArea.order
        #expect(MuscleFamily.families(of: groups) == MuscleFamily.allCases)
    }

    // MARK: Superset labels for template rows (the detail screen)

    @Test func templateMemberLabelsFollowTheWorkoutRule() {
        let a = UUID(), b = UUID()
        // Adjacent members of one group are A, B…; a standalone is nil; a
        // group interrupted by an unrelated exercise is two runs.
        #expect(Supersets.memberLabels(groupIDs: [a, a, nil, b, b, b]) == ["A", "B", nil, "A", "B", "C"])
        #expect(Supersets.memberLabels(groupIDs: [a, nil, a]) == [nil, nil, nil])
        #expect(Supersets.memberLabels(groupIDs: [nil]) == [nil])
        #expect(Supersets.memberLabels(groupIDs: []) == [])
    }
}

// The template detail row's caption (ticket 11).
struct TemplateTargetsSummaryTests {
    @Test func summaryReadsSetsThenReps() {
        #expect(TemplateTargets(repsBySet: [10, 10, 8]).summary == "3 sets · 10, 10, 8 reps")
        #expect(TemplateTargets(repsBySet: [12]).summary == "1 set · 12 reps")
        #expect(TemplateTargets(repsBySet: [10, nil, 8]).summary == "3 sets · 10, —, 8 reps")
        #expect(TemplateTargets(repsBySet: [nil, nil]).summary == "2 sets")
        #expect(TemplateTargets(repsBySet: []).summary == "No sets")
    }
}
