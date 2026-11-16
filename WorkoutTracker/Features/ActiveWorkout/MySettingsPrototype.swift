import SwiftData
import SwiftUI

// PROTOTYPE (machine-settings 01, throwaway): "My settings" — a note per gym machine × exercise — on sample data, for
// the user to try before anything is built for real (D91, proposed). The notes live in memory only: nothing is saved,
// no schema changes. Shown only under `-uiTestReset -mySettingsPrototype` with the design sample's live workout and
// gyms (`-uiTestDesignSample -uiTestDesignLive -uiTestDesignGyms`). Removed once the user has decided; the approved
// views in `MySettingsViews.swift` are then wired to the stored note.
//
// Sample world (Iron Temple): Chest Press 2 has a note for the chest press; the Cable Station (five exercises) has
// notes for the pushdown and the crossover; a Shoulder Press machine is new (first use → the "Add My Settings" chip);
// the Incline Press has history and no note (nothing shown). An orange switcher over the live workout opens each
// machine's page and flips light/dark.
//
// Capture arguments: `-mySettingsPrototypeFirst <exercise>` puts that card first; `-mySettingsPrototypePage <machine
// label>` opens a machine page; `-mySettingsPrototypeEditor <exercise>` opens that card's editor;
// `-mySettingsPrototypeScroll <points>` scrolls the machine page; `-mySettingsPrototypeCapture` hides the switcher.

@Observable
@MainActor
final class MySettingsPrototype {
    static let shared = MySettingsPrototype()
    static let launchArgument = "-mySettingsPrototype"
    static var isEnabled: Bool { WorkoutTrackerStore.fixtureIsEnabled(launchArgument) }
    static var hidesSwitcher: Bool { ProcessInfo.processInfo.arguments.contains("-mySettingsPrototypeCapture") }

    struct Key: Hashable {
        var machineID: UUID
        var exerciseID: UUID
    }

    /// An open editor on the machine page.
    struct Target: Identifiable {
        var key: Key
        var machineLabel: String
        var exerciseName: String
        var id: Key { key }
    }

    enum Slot { case note(String), hint, none }

    /// The notes, in memory only.
    var notes: [Key: String] = [:]
    /// Machine × exercise pairs with a finished workout at launch: no first-use hint there.
    var usedBefore: Set<Key> = []
    /// The card whose editor is open.
    var cardEditingEntryID: UUID?
    /// The machine page's open editor.
    var pageEditing: Target?
    /// The machine page opened from the switcher.
    var pageMachineID: UUID?
    /// Machines the switcher offers, in order: (label, id).
    var machines: [(label: String, id: UUID)] = []

    private var sampleNotes: [Key: String] = [:]
    private var pendingPageMachineID: UUID?
    private var pendingEditorEntryID: UUID?

    func note(machine: MachineInstance?, exercise: Exercise?) -> String? {
        guard let machine, let exercise else { return nil }
        return notes[Key(machineID: machine.id, exerciseID: exercise.id)]
    }

    /// A blank note removes it.
    func setNote(_ text: String, for key: Key) {
        notes[key] = text.isEmpty ? nil : text
    }

    func slot(for entry: ExerciseEntry) -> Slot {
        guard !entry.isDeleted, let machine = entry.machine, let exercise = entry.exercise else { return .none }
        let key = Key(machineID: machine.id, exerciseID: exercise.id)
        if let note = notes[key] { return .note(note) }
        return usedBefore.contains(key) ? .none : .hint
    }

    func resetNotes() { notes = sampleNotes }

    /// Opens what the capture arguments asked for, once the live workout is on screen.
    func applyPending() {
        if let id = pendingPageMachineID { pageMachineID = id }
        if let id = pendingEditorEntryID { cardEditingEntryID = id }
        pendingPageMachineID = nil
        pendingEditorEntryID = nil
    }

    /// After the design sample: the new Shoulder Press machine on the live workout, the cards reordered so the cases
    /// sit together, the sample notes and the first-use pairs.
    func seed(in context: ModelContext) throws {
        let arguments = ProcessInfo.processInfo.arguments
        func argument(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        // Light/dark comes from the device (the switcher can override it until the next launch).
        UserDefaults.standard.set(Appearance.system.rawValue, forKey: AppearanceSetting.key)

        guard let gym = try context.fetch(FetchDescriptor<Gym>()).first(where: { $0.name == DesignSampleFixture.gymName })
        else { return }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        func exercise(_ name: String) -> Exercise? { exercises.first { $0.name == name } }
        let gymMachines = try context.fetch(FetchDescriptor<MachineInstance>())
            .filter { $0.gym?.id == gym.id && !$0.archived }
        func machine(_ label: String) -> MachineInstance? { gymMachines.first { $0.label == label } }

        let models = try context.fetch(FetchDescriptor<EquipmentModel>())
        let shoulder = MachineInstance(
            label: "Shoulder Press", gym: gym,
            model: models.first { $0.manufacturer == "Life Fitness" && $0.modelName == "Insignia Series Shoulder Press" })
        context.insert(shoulder)

        // Finished history, before the live workout changes anything.
        let finished = try context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil }))
        usedBefore = Set(finished.flatMap { workout in
            (workout.entries ?? []).compactMap { entry -> Key? in
                guard let machineID = entry.snapshotMachineID else { return nil }
                return Key(machineID: machineID, exerciseID: entry.snapshotExerciseID)
            }
        })

        if let live = try context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt == nil })).first {
            let session = WorkoutSession(context: context)
            var entries = WorkoutSession.orderedEntries(of: live)
            if let entry = entries.first(where: { $0.exercise?.name == "Machine Shoulder Press" }) {
                try session.chooseEquipment(for: entry, machine: shoulder, freeWeightTag: nil)
            }
            var order = ["Seated Chest Press", "Machine Shoulder Press", "Triceps Pushdown", "Incline Chest Press",
                         "Lateral Raise"]
            if let first = argument("-mySettingsPrototypeFirst"), let index = order.firstIndex(of: first) {
                order.insert(order.remove(at: index), at: 0)
            }
            entries.sort { (order.firstIndex(of: $0.exercise?.name ?? "") ?? 99) < (order.firstIndex(of: $1.exercise?.name ?? "") ?? 99) }
            for (index, entry) in entries.enumerated() { entry.order = index }
            if let name = argument("-mySettingsPrototypeEditor") {
                pendingEditorEntryID = entries.first { $0.exercise?.name == name }?.id
            }
        }
        try context.save()

        var sample: [Key: String] = [:]
        func add(_ label: String, _ exerciseName: String, _ text: String) {
            guard let machine = machine(label) ?? (label == shoulder.label ? shoulder : nil),
                  let exercise = exercise(exerciseName) else { return }
            sample[Key(machineID: machine.id, exerciseID: exercise.id)] = text
        }
        add("Chest Press 2", "Seated Chest Press", "Seat 4 · back pad 2 · handles at the second notch")
        add("Cable Station", "Triceps Pushdown", "Rope · pulley at the top · hurt my elbow at 4, stay at 3")
        add("Cable Station", "Cable Crossover", "Both pulleys at 6 · one step forward")
        sampleNotes = sample
        notes = sample

        let offered = ["Chest Press 2", "Cable Station", "Shoulder Press", "Incline Press"]
        machines = offered.compactMap { label in
            (machine(label) ?? (label == shoulder.label ? shoulder : nil)).map { (label, $0.id) }
        }
        if let label = argument("-mySettingsPrototypePage") {
            pendingPageMachineID = machines.first { $0.label == label }?.id
        }
    }
}

// MARK: - The live card

extension ExerciseEntryCard {
    /// Under the machine: the note, the first-use chip, or nothing.
    @ViewBuilder
    var mySettingsPrototypeSlot: some View {
        switch MySettingsPrototype.shared.slot(for: entry) {
        case .note(let note):
            MySettingsCardLine(note: note) { MySettingsPrototype.shared.cardEditingEntryID = entry.id }
        case .hint:
            MySettingsAddChip { MySettingsPrototype.shared.cardEditingEntryID = entry.id }
        case .none:
            EmptyView()
        }
    }
}

private struct MySettingsPrototypeCardSheet: ViewModifier {
    var entry: ExerciseEntry
    @State private var state = MySettingsPrototype.shared
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(
            get: { state.cardEditingEntryID == entry.id },
            set: { if !$0 { state.cardEditingEntryID = nil } })) {
            if let machine = entry.machine, let exercise = entry.exercise {
                let key = MySettingsPrototype.Key(machineID: machine.id, exerciseID: exercise.id)
                MySettingsSheet(machineLabel: machine.label, exerciseName: exercise.name,
                                initialNote: state.notes[key] ?? "") { state.setNote($0, for: key) }
                    .presentationDetents([.medium, .large])
                    .floodlightSheet(from: look)
            }
        }
    }
}

// MARK: - The machine page

/// One row per exercise the machine serves (one on a single-exercise machine, several on a station).
struct MySettingsPrototypeRows: View {
    var machine: MachineInstance
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var state = MySettingsPrototype.shared

    var body: some View {
        let served = machine.supportedExerciseIDs.compactMap { id in exercises.first { $0.id == id } }
        ForEach(served) { exercise in
            let key = MySettingsPrototype.Key(machineID: machine.id, exerciseID: exercise.id)
            MySettingsMachineRow(exerciseName: served.count > 1 ? exercise.name : nil, note: state.notes[key]) {
                state.pageEditing = .init(key: key, machineLabel: machine.label, exerciseName: exercise.name)
            }
        }
    }
}

private struct MySettingsPrototypePageSheet: ViewModifier {
    @State private var state = MySettingsPrototype.shared

    func body(content: Content) -> some View {
        content.sheet(item: $state.pageEditing) { target in
            MySettingsSheet(machineLabel: target.machineLabel, exerciseName: target.exerciseName,
                            initialNote: state.notes[target.key] ?? "") { state.setNote($0, for: target.key) }
                .presentationDetents([.medium, .large])
        }
    }
}

/// Captures only: `-mySettingsPrototypeScroll <points>` scrolls the machine page down that far (to reach Setup).
private struct MySettingsPrototypeCaptureScroll: ViewModifier {
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        if let y = Self.offset {
            content
                .scrollPosition($position)
                .task {
                    try? await Task.sleep(for: .milliseconds(300))
                    position.scrollTo(y: y)
                }
        } else {
            content
        }
    }

    private static var offset: CGFloat? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-mySettingsPrototypeScroll"), index + 1 < arguments.count,
              let y = Double(arguments[index + 1]) else { return nil }
        return CGFloat(y)
    }
}

// MARK: - The switcher (over the live workout)

private struct MySettingsPrototypeSwitcher: ViewModifier {
    @State private var state = MySettingsPrototype.shared
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if !MySettingsPrototype.hidesSwitcher { MySettingsPrototypeMenu() }
            }
            .sheet(isPresented: Binding(get: { state.pageMachineID != nil }, set: { if !$0 { state.pageMachineID = nil } })) {
                MySettingsPrototypePage()
            }
            .task {
                try? await Task.sleep(for: .milliseconds(1200))
                state.applyPending()
            }
    }
}

/// A machine page from the switcher, with the switcher on top to go to another page or back to the workout.
private struct MySettingsPrototypePage: View {
    @State private var state = MySettingsPrototype.shared
    @Query private var machines: [MachineInstance]

    var body: some View {
        NavigationStack {
            if let machine = machines.first(where: { $0.id == state.pageMachineID }) {
                MachineDetailView(machine: machine)
                    .id(machine.id)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { state.pageMachineID = nil }
                        }
                    }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !MySettingsPrototype.hidesSwitcher { MySettingsPrototypeMenu() }
        }
    }
}

private struct MySettingsPrototypeMenu: View {
    @State private var state = MySettingsPrototype.shared
    @AppStorage(AppearanceSetting.key) private var appearanceRaw = Appearance.system.rawValue

    var body: some View {
        Menu {
            Button("Live Workout", systemImage: "figure.strengthtraining.traditional") { state.pageMachineID = nil }
            Section("Machine page") {
                ForEach(state.machines, id: \.id) { machine in
                    Button(machine.label) {
                        state.pageMachineID = machine.id
                    }
                }
            }
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Button("Reset Sample Notes", systemImage: "arrow.counterclockwise") { state.resetNotes() }
        } label: {
            Text("Prototype · \(title)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.orange, in: Capsule())
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("mySettingsPrototypeSwitcher")
    }

    private var title: String {
        guard let id = state.pageMachineID else { return "Live workout" }
        return state.machines.first { $0.id == id }?.label ?? "Machine"
    }
}

extension View {
    /// On the live workout screen.
    @ViewBuilder func mySettingsPrototypeSwitcher() -> some View {
        if MySettingsPrototype.isEnabled { modifier(MySettingsPrototypeSwitcher()) } else { self }
    }

    /// On each live card.
    @ViewBuilder func mySettingsPrototypeCardSheet(_ entry: ExerciseEntry) -> some View {
        if MySettingsPrototype.isEnabled { modifier(MySettingsPrototypeCardSheet(entry: entry)) } else { self }
    }

    /// On the machine page's scroll view (captures).
    @ViewBuilder func mySettingsPrototypeCaptureScroll() -> some View {
        if MySettingsPrototype.isEnabled { modifier(MySettingsPrototypeCaptureScroll()) } else { self }
    }

    /// On the machine page.
    @ViewBuilder func mySettingsPrototypePageSheet() -> some View {
        if MySettingsPrototype.isEnabled { modifier(MySettingsPrototypePageSheet()) } else { self }
    }
}
