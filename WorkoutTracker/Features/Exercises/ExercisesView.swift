import SwiftUI

struct ExercisesView: View {
    @EnvironmentObject private var store: SampleStore
    @State private var searchText = ""

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return store.exercises }
        return store.exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { exercise in
                        ExerciseRow(exercise: exercise)
                    }
                } footer: {
                    Text("Picking a machine during a workout selects its exercise automatically — this list is for browsing and free-weight logging.")
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
        }
    }
}

#Preview {
    ExercisesView()
        .environmentObject(SampleStore())
}
