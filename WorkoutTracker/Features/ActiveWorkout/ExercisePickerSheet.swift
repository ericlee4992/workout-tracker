import SwiftUI

struct ExercisePickerSheet: View {
    @EnvironmentObject private var store: SampleStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    var onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return store.exercises }
        return store.exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    ExerciseRow(exercise: exercise)
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ExerciseRow: View {
    var exercise: Exercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.body.weight(.medium))
                Text(exercise.tags.map(\.rawValue).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.loadType != .weighted {
                Text(exercise.loadType.badge)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
