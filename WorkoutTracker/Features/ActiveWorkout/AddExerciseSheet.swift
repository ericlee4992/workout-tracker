import SwiftUI

/// Public beta ticket 22 (the user, 2026-10-18: "is there a need for both add exercise and add machine button?
/// Can we maybe combine them into one button?"): the live workout's one Add Exercise. **Exercises** is the picker
/// (recent at this gym first, then body areas); **Machines** is machine-first logging (D7, unchanged: a one-exercise
/// machine fills itself in, a station asks which exercise, Add Machine…, delete). Opens on Exercises.
struct AddExerciseSheet: View {
    var workout: Workout
    var onSelect: (Exercise) -> Void
    @State private var mode = 0

    var body: some View {
        if mode == 0 {
            ExercisePickerSheet(gym: workout.isDeleted ? nil : workout.gym, mode: $mode, onSelect: onSelect)
        } else {
            AddByMachineSheet(workout: workout, mode: $mode)
        }
    }
}

/// The sheet's Exercises | Machines switch: the first row of either list.
struct AddExerciseModePicker: View {
    @Binding var selection: Int

    var body: some View {
        SegmentedPills(["Exercises", "Machines"], selection: $selection)
            .accessibilityIdentifier("addExerciseMode")
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
    }
}
