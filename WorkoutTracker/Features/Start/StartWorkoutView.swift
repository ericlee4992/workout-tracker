import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    // Templates render from sample data until ticket 15 lands template CRUD.
    @EnvironmentObject private var store: SampleStore
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name)
    private var gyms: [Gym]
    @Query private var allPreferences: [AppPreferences]
    @State private var selectedGym: Gym?
    @State private var showingResumeDialog = false
    /// Called with the workout to present — freshly started or resumed.
    var onWorkoutStarted: (Workout) -> Void

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    gymPicker
                } footer: {
                    Text("Sets default to \(currentUnit.rawValue) here. You can switch units on any set.")
                }

                Section {
                    Button(action: startTapped) {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }

                Section("Templates") {
                    ForEach(store.templates) { template in
                        TemplateRow(
                            template: template,
                            gymName: selectedGym?.name ?? "your gym",
                            start: startTapped)
                    }
                }
            }
            .navigationTitle("Workout")
            .confirmationDialog(
                "A workout is already in progress",
                isPresented: $showingResumeDialog,
                titleVisibility: .visible
            ) {
                Button("Resume Workout") { resumeActive() }
                Button("Finish It & Start New") { startNew() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Resume it, or finish it and start a new one — only its completed sets are kept.")
            }
        }
    }

    // MARK: Start flow

    /// Start-while-active offers Resume or Finish-and-start-new.
    private func startTapped() {
        if (try? session.resumableWorkout()) != nil {
            showingResumeDialog = true
        } else {
            startNew()
        }
    }

    private func startNew() {
        do {
            // The service finishes any lingering active workout first.
            onWorkoutStarted(try session.startWorkout(at: selectedGym))
        } catch {
            assertionFailure("Failed to start workout: \(error)")
        }
    }

    private func resumeActive() {
        if let workout = try? session.resumableWorkout() {
            onWorkoutStarted(workout)
        }
    }

    // MARK: Gym & units

    /// Gym-level unit for the currently picked gym, falling through to the
    /// app preference (T7; no machine context here).
    private var currentUnit: WeightUnit {
        UnitPrecedence.defaultUnit(
            machineUnit: nil,
            gymUnit: selectedGym?.defaultUnit,
            appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
    }

    private var gymPicker: some View {
        Menu {
            Button {
                selectedGym = nil
            } label: {
                if selectedGym == nil {
                    Label("No gym", systemImage: "checkmark")
                } else {
                    Text("No gym")
                }
            }
            ForEach(gyms) { gym in
                Button {
                    selectedGym = gym
                } label: {
                    let title = gym.city.map { "\(gym.name) · \($0)" } ?? gym.name
                    if gym.id == selectedGym?.id {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedGym?.name ?? "No gym")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(selectedGym.map { $0.city ?? "" } ?? "Home / no location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UnitBadge(unit: currentUnit)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TemplateRow: View {
    var template: SampleWorkoutTemplate
    var gymName: String
    var start: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                Text(template.exerciseNames.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Machines resolve to your last-used at \(gymName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Start", action: start)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

struct UnitBadge: View {
    var unit: WeightUnit

    var body: some View {
        Text(unit.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(unit == .kg ? Color.blue.opacity(0.15) : Color.orange.opacity(0.18))
            .foregroundStyle(unit == .kg ? Color.blue : Color.orange)
            .clipShape(Capsule())
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    container.mainContext.insert(Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg))
    return StartWorkoutView(onWorkoutStarted: { _ in })
        .environmentObject(SampleStore())
        .modelContainer(container)
}
