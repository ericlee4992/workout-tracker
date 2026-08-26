import SwiftData
import SwiftUI

struct TemplateEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var template: WorkoutTemplate?
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var name = ""
    @State private var items: [EditorItem] = []
    @State private var loaded = false

    struct EditorItem: Identifiable {
        var id = UUID()
        var exerciseID: UUID
        /// 0 means no target for that slot.
        var repsBySet: [Int]
        /// Superset membership (D48), carried through the editor so an
        /// ordinary edit does not silently ungroup the template.
        var supersetGroupID: UUID?
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Template name", text: $name)
                }

                Section("Exercises") {
                    ForEach(items.indices, id: \.self) { index in
                        itemEditor(at: index)
                    }
                    .onMove { source, destination in
                        items.move(fromOffsets: source, toOffset: destination)
                    }
                    if items.isEmpty {
                        Text("Add at least one exercise below.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Add Exercise") {
                    ForEach(exercises) { exercise in
                        Button {
                            items.append(EditorItem(
                                exerciseID: exercise.id,
                                repsBySet: [10, 10, 10]))
                        } label: {
                            Label(exercise.name, systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty || items.isEmpty)
                }
            }
        }
    }

    private func itemEditor(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exerciseName(items[index].exerciseID))
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    items.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
            }
            Stepper(
                "\(items[index].repsBySet.count) sets",
                value: setCountBinding(at: index),
                in: 1...12)
            ForEach(items[index].repsBySet.indices, id: \.self) { setIndex in
                Stepper(
                    slotLabel(itemIndex: index, setIndex: setIndex),
                    value: repsBinding(itemIndex: index, setIndex: setIndex),
                    in: 0...100)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func setCountBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: { items[index].repsBySet.count },
            set: { count in
                while items[index].repsBySet.count < count {
                    items[index].repsBySet.append(items[index].repsBySet.last ?? 10)
                }
                if items[index].repsBySet.count > count {
                    items[index].repsBySet.removeLast(items[index].repsBySet.count - count)
                }
            })
    }

    private func repsBinding(itemIndex: Int, setIndex: Int) -> Binding<Int> {
        Binding(
            get: { items[itemIndex].repsBySet[setIndex] },
            set: { items[itemIndex].repsBySet[setIndex] = $0 })
    }

    private func slotLabel(itemIndex: Int, setIndex: Int) -> String {
        let reps = items[itemIndex].repsBySet[setIndex]
        return "Set \(setIndex + 1) target · \(reps == 0 ? "—" : "\(reps) reps")"
    }

    private func exerciseName(_ id: UUID) -> String {
        exercises.first { $0.id == id }?.name ?? "Missing exercise"
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let template else { return }
        name = template.name
        items = WorkoutTemplateService.orderedItems(of: template).compactMap { item in
            guard let exercise = item.exercise else { return nil }
            // 0 is the editor's "no target" value for a slot.
            return EditorItem(
                exerciseID: exercise.id,
                repsBySet: item.editableTargets.repsBySet.map { $0 ?? 0 },
                supersetGroupID: item.supersetGroupID)
        }
    }

    private func save() {
        let drafts = items.compactMap { item -> TemplateItemDraft? in
            guard let exercise = exercises.first(where: { $0.id == item.exerciseID }) else {
                return nil
            }
            return TemplateItemDraft(
                exercise: exercise,
                targetRepsBySet: item.repsBySet.map { $0 == 0 ? nil : $0 },
                // codex-review 2 (critical): omitted here, so ANY ordinary edit
                // of a template silently ungrouped its supersets.
                supersetGroupID: item.supersetGroupID)
        }
        do {
            let service = WorkoutTemplateService(context: modelContext)
            if let template {
                try service.update(template, name: trimmedName, items: drafts)
            } else {
                try service.create(name: trimmedName, items: drafts)
            }
            dismiss()
        } catch {
            assertionFailure("Failed to save template: \(error)")
        }
    }
}
