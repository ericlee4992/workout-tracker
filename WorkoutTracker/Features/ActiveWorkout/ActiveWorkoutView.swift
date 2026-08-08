import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: SampleStore
    @Environment(\.dismiss) private var dismiss

    @State private var restEnd: Date?
    @State private var restTotal: Double = 120
    @State private var machinePickerEntryID: UUID?
    @State private var performanceEntryID: UUID?
    @State private var showExercisePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    ForEach($store.activeWorkout.entries) { $entry in
                        ExerciseEntryCard(
                            entry: $entry,
                            showMachinePicker: { machinePickerEntryID = entry.id },
                            showPerformance: { performanceEntryID = entry.id },
                            setCompleted: { setType in startRest(for: entry, setType: setType) }
                        )
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if restEnd != nil {
                    RestTimerBar(restEnd: $restEnd, restTotal: restTotal)
                }
            }
            .navigationTitle(store.activeWorkout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .tint(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { dismiss() }
                        .font(.headline)
                }
            }
            .sheet(item: machinePickerEntry) { entry in
                MachinePickerSheet(entryID: entry.id)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: performanceEntry) { entry in
                PreviousPerformanceSheet(entry: entry)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercise in
                    addEntry(for: exercise)
                }
            }
            .onAppear(perform: applyLaunchOverride)
        }
    }

    // Screenshot deep-links (milestone 1 only): SIMCTL_CHILD_PROTO_SHEET=machines|previous
    private func applyLaunchOverride() {
        switch ProcessInfo.processInfo.environment["PROTO_SHEET"] {
        case "machines":
            machinePickerEntryID = store.activeWorkout.entries.first?.id
        case "previous":
            performanceEntryID = store.activeWorkout.entries.first?.id
        default:
            break
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.tint)
            Text(store.activeWorkout.gym?.name ?? "No gym")
                .font(.subheadline.weight(.medium))
            Spacer()
            Label("\(store.activeWorkout.durationMinutes) min", systemImage: "timer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var machinePickerEntry: Binding<WorkoutEntry?> {
        entryBinding(id: machinePickerEntryID) { machinePickerEntryID = nil }
    }

    private var performanceEntry: Binding<WorkoutEntry?> {
        entryBinding(id: performanceEntryID) { performanceEntryID = nil }
    }

    private func entryBinding(id: UUID?, clear: @escaping () -> Void) -> Binding<WorkoutEntry?> {
        Binding(
            get: {
                guard let id else { return nil }
                return store.activeWorkout.entries.first { $0.id == id }
            },
            set: { newValue in
                if newValue == nil { clear() }
            }
        )
    }

    private func startRest(for entry: WorkoutEntry, setType: SetType) {
        let seconds = setType == .warmup ? entry.warmupRest : entry.workingRest
        restTotal = Double(seconds)
        restEnd = Date().addingTimeInterval(Double(seconds))
    }

    private func addEntry(for exercise: SampleExercise) {
        var set = LoggedSet()
        set.unit = store.activeWorkout.gym?.defaultUnit ?? .kg
        let entry = WorkoutEntry(
            exercise: exercise,
            machine: nil,
            freeWeightTag: exercise.tags.first { $0 != .machine },
            sets: [set]
        )
        store.activeWorkout.entries.append(entry)
    }
}

#Preview {
    ActiveWorkoutView()
        .environmentObject(SampleStore())
}
