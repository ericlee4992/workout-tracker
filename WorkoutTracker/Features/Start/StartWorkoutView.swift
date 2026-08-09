import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name)
    private var gyms: [Gym]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query private var allPreferences: [AppPreferences]
    @State private var selectedGym: Gym?
    @State private var showingResumeDialog = false
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showingTemplateEditor = false
    @State private var replacementWorkout: Workout?
    @State private var replacementSourceTemplate: WorkoutTemplate?
    @State private var showingReplacementDrift = false
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
                    Button { startTapped(template: nil) } label: {
                        Label("Start Empty Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }

                Section("Templates") {
                    ForEach(templates) { template in
                        TemplateRow(
                            template: template,
                            gymName: selectedGym?.name ?? "your gym",
                            start: { startTapped(template: template) })
                        .contextMenu {
                            Button("Edit…") {
                                editingTemplate = template
                                showingTemplateEditor = true
                            }
                            Button("Delete", role: .destructive) {
                                delete(template)
                            }
                        }
                    }
                    Button("New Template…", systemImage: "plus") {
                        editingTemplate = nil
                        showingTemplateEditor = true
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
                Button("Finish It & Start New") { finishActiveThenStartTapped() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Resume it, or finish it and start a new one — only its completed sets are kept.")
            }
            .templateDriftDialog(
                isPresented: $showingReplacementDrift,
                message: "The active workout differs from the template it started from. Choose how to save that template before starting the next workout.",
                cancelLabel: "Keep Current Workout",
                resolve: resolveReplacementDrift)
            .sheet(isPresented: $showingTemplateEditor) {
                TemplateEditorSheet(template: editingTemplate)
            }
        }
    }

    // MARK: Start flow

    /// Start-while-active offers Resume or Finish-and-start-new.
    private func startTapped(template: WorkoutTemplate?) {
        pendingTemplate = template
        if (try? session.resumableWorkout()) != nil {
            showingResumeDialog = true
        } else {
            startNew()
        }
    }

    private func startNew() {
        do {
            // Any still-active workout is auto-finished by `startWorkout`,
            // which ends its rest timer and pending notification.
            let workout: Workout
            if let template = pendingTemplate {
                workout = try WorkoutTemplateService(context: modelContext)
                    .start(template, at: selectedGym)
            } else {
                workout = try session.startWorkout(at: selectedGym)
            }
            pendingTemplate = nil
            onWorkoutStarted(workout)
        } catch {
            assertionFailure("Failed to start workout: \(error)")
        }
    }

    private func finishActiveThenStartTapped() {
        do {
            guard let active = try session.resumableWorkout() else {
                startNew()
                return
            }
            let drift = TemplateDriftService(context: modelContext)
            if let template = try drift.sourceTemplate(for: active),
               try drift.shouldPrompt(for: active, template: template) {
                replacementWorkout = active
                replacementSourceTemplate = template
                showingReplacementDrift = true
            } else {
                startNew()
            }
        } catch {
            assertionFailure("Failed to inspect active workout drift: \(error)")
        }
    }

    private func resolveReplacementDrift(_ resolution: TemplateDriftResolution) {
        do {
            if let workout = replacementWorkout,
               let template = replacementSourceTemplate {
                try TemplateDriftService(context: modelContext).resolve(
                    resolution, workout: workout, to: template)
            }
            replacementWorkout = nil
            replacementSourceTemplate = nil
            startNew()
        } catch {
            assertionFailure("Failed to resolve template before starting: \(error)")
        }
    }

    private func resumeActive() {
        pendingTemplate = nil
        if let workout = try? session.resumableWorkout() {
            onWorkoutStarted(workout)
        }
    }

    private func delete(_ template: WorkoutTemplate) {
        do { try WorkoutTemplateService(context: modelContext).delete(template) }
        catch { assertionFailure("Failed to delete template: \(error)") }
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
    var template: WorkoutTemplate
    var gymName: String
    var start: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                Text(WorkoutTemplateService.orderedItems(of: template)
                    .compactMap { $0.exercise?.name }
                    .joined(separator: " · "))
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
        .modelContainer(container)
}
