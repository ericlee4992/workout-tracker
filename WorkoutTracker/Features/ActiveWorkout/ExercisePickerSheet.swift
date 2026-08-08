import SwiftData
import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    var onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter {
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
    var name: String
    var loadType: LoadType
    var tags: [EquipmentTag]

    init(name: String, loadType: LoadType, tags: [EquipmentTag]) {
        self.name = name
        self.loadType = loadType
        self.tags = tags
    }

    init(exercise: Exercise) {
        self.init(
            name: exercise.name, loadType: exercise.loadType,
            tags: exercise.equipmentTypeTags)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.body.weight(.medium))
                Text(tags.map(\.label).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if loadType != .weighted {
                Text(loadType.badge)
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
