import Foundation

// Last surviving piece of the milestone-1 sample data: the Start screen's
// template list stays on these stand-ins until ticket 15 lands template CRUD,
// then this file gets deleted.

struct SampleWorkoutTemplate: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var exerciseNames: [String]

    static let samples: [SampleWorkoutTemplate] = [
        SampleWorkoutTemplate(
            name: "Push Day",
            exerciseNames: [
                "Seated Chest Press", "Bench Press", "Machine Shoulder Press",
                "Triceps Pushdown",
            ]),
        SampleWorkoutTemplate(
            name: "Pull Day",
            exerciseNames: [
                "Lat Pulldown", "Seated Row", "Assisted Pull-Up", "Dumbbell Curl",
            ]),
        SampleWorkoutTemplate(
            name: "Leg Day",
            exerciseNames: ["Squat", "Leg Press"]),
    ]
}
