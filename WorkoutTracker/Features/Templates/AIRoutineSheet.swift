import SwiftUI
import SwiftData

struct AIRoutineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    var gym: Gym?
    @AppStorage(TerraAccess.routineConsentKey) private var consent = false
    private enum InputFocus: Hashable { case goals, height, weight }
    @FocusState private var inputFocus: InputFocus?
    @State private var goals = ""
    @State private var experience = "Beginner"
    @State private var days = 3
    @State private var minutes = 45
    @State private var height = ""
    @State private var weight = ""
    @State private var extras: Set<RoutineEquipment> = []
    @State private var cardio: Set<CardioActivity> = []
    @State private var routine: AIRoutine?
    @State private var sentRequest: AIRoutineRequest?
    @State private var busy = false
    @State private var saved = false
    @State private var error: String?
    @State private var settings = false
    @State private var task: Task<Void, Never>?
    @State private var token: UUID?

    private var options: [RoutineExerciseOption] {
        RoutineAvailability.exercises(exercises, machines: gym?.archived == false ? gym?.activeMachines ?? [] : [], extras: extras)
    }
    var body: some View {
        NavigationStack {
            Group {
                if TerraAccess.client == nil && !TerraAccess.fixture {
                    Form {
                        Text("Add your OpenAI API key to create routines with Terra.")
                        Button("Open AI Settings") { settings = true }.accessibilityIdentifier("routineAISettings")
                    }
                } else if busy {
                    VStack(spacing: 20) {
                        ProgressView("Building your week…")
                        Button("Back to preferences") { cancel() }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if routine != nil {
                    preview
                } else { inputs }
            }
            .navigationTitle(routine == nil ? "Ask AI" : "Your week")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { inputFocus = nil }.accessibilityIdentifier("dismissRoutineKeyboard")
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel(); dismiss() } }
                if routine != nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Save templates") { save() }.disabled(saved).accessibilityIdentifier("saveAIRoutine") }
                }
            }
            .sheet(isPresented: $settings) { AskAISettingsSheet() }
            .onDisappear { cancel() }
            .onChange(of: consent) { _, permitted in if !permitted { cancel(); routine = nil } }
        }
    }
    private var inputs: some View {
        Form {
            Section("Goals") {
                TextField("What would you like to work toward?", text: $goals, axis: .vertical)
                    .lineLimit(3...6).focused($inputFocus, equals: .goals).accessibilityIdentifier("routineGoals")
                Picker("Experience", selection: $experience) { ForEach(["Beginner", "Intermediate", "Experienced"], id: \.self) { Text($0) } }
                Stepper("\(days) days per week", value: $days, in: 1...7)
                Stepper("\(minutes) minutes per session", value: $minutes, in: 15...120, step: 5)
            }
            Section("Optional profile") {
                TextField("Height (cm)", text: $height).keyboardType(.decimalPad).focused($inputFocus, equals: .height)
                TextField("Weight (kg)", text: $weight).keyboardType(.decimalPad).focused($inputFocus, equals: .weight)
            }
            Section(gym.map { "Equipment at \($0.name)" } ?? "Available equipment") {
                if let gym { Text("\(gym.activeMachines.count) saved machines").foregroundStyle(Theme.secondary) }
                ForEach(RoutineEquipment.allCases) { equipment in
                    Toggle(equipment.name, isOn: Binding(get: { extras.contains(equipment) }, set: { on in
                        if on { extras.insert(equipment) } else { extras.remove(equipment) }
                    })).accessibilityIdentifier("routineEquipment.\(equipment.rawValue)")
                }
            }
            Section("Available cardio") {
                ForEach(CardioActivity.allCases) { activity in
                    Toggle(activity.name, isOn: Binding(get: { cardio.contains(activity) }, set: { on in
                        if on { cardio.insert(activity) } else { cardio.remove(activity) }
                    })).accessibilityIdentifier("routineCardio.\(activity.rawValue)")
                }
            }
            Section {
                if !consent && !TerraAccess.bypassesConsent {
                    Toggle("Allow sending routine details to OpenAI", isOn: $consent).accessibilityIdentifier("allowAIRoutine")
                    Text("Sends these goals, experience, schedule, optional height/weight, and available exercise list to OpenAI. Your Health data and workout history are not sent. OpenAI’s API data policies apply.").font(.footnote)
                    Link("OpenAI data policies", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                }
                if let error { Text(error).foregroundStyle(Theme.secondary).accessibilityIdentifier("routineAIError") }
                Button("Generate week", systemImage: "sparkles") { generate() }
                    .disabled((!consent && !TerraAccess.bypassesConsent) || goals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (options.isEmpty && cardio.isEmpty))
                    .accessibilityIdentifier("generateAIRoutine")
            }
        }.scrollDismissesKeyboard(.interactively)
    }
    private var preview: some View {
        List {
            if let error { Text(error).foregroundStyle(Theme.secondary) }
            ForEach(routine?.sessions.indices ?? 0..<0, id: \.self) { index in
                NavigationLink {
                    AIRoutineDayEditor(day: Binding(get: { routine!.sessions[index] }, set: { routine!.sessions[index] = $0 }), options: sentRequest?.exercises ?? [], activities: sentRequest?.cardioActivities ?? [])
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine!.sessions[index].name).font(.headline)
                        Text("\(routine!.sessions[index].strength.count) exercises · \(routine!.sessions[index].cardio.count) cardio").font(.caption).foregroundStyle(Theme.secondary)
                    }
                }.accessibilityIdentifier("routineDay.\(index)")
            }
            Button("Change preferences") { routine = nil; error = nil }
        }
    }
    private func cancel() { task?.cancel(); task = nil; token = nil; busy = false }
    private func generate() {
        guard (consent || TerraAccess.bypassesConsent), !busy else { return }
        guard goals.count <= 1000,
              height.isEmpty || (Double(height).map { $0.isFinite && (50...250).contains($0) } ?? false),
              weight.isEmpty || (Double(weight).map { $0.isFinite && (20...400).contains($0) } ?? false) else {
            error = "Use a goal under 1,000 characters and valid optional height/weight."; return
        }
        let request = AIRoutineRequest(goals: goals, experience: experience, days: days, minutes: minutes,
            heightCm: Double(height), weightKg: Double(weight), exercises: options, cardioActivities: CardioActivity.allCases.filter { cardio.contains($0) })
        sentRequest = request; error = nil; busy = true
        let id = UUID(); token = id
        task = Task {
            do {
                let result: AIRoutine
                if TerraAccess.fixture {
                    try await TerraAccess.fixtureDelay()
                    result = AIRoutine(sessions: (1...request.days).map { day in
                        AIRoutineDay(name: "Day \(day) — Fitness", strength: request.exercises.first.map {
                            [AIRoutineStrength(exerciseID: $0.id, sets: 3, reps: 10, restSeconds: 60)]
                        } ?? [], cardio: request.cardioActivities.first.map { [AIRoutineCardio(activity: $0, minutes: 15)] } ?? [])
                    })
                } else {
                    guard let client = TerraAccess.client else { throw TerraError.message("Add an OpenAI key in Settings.") }
                    let data = try await client.complete(instructions: AIRoutine.instructions, input: AISchema.text(request), schema: AIRoutine.schema, name: "weekly_routine")
                    result = try JSONDecoder().decode(AIRoutine.self, from: data)
                }
                let valid = try result.validated(for: request)
                guard !Task.isCancelled, token == id else { return }
                routine = valid; busy = false
            } catch {
                guard !Task.isCancelled, token == id else { return }
                self.error = error.localizedDescription; busy = false
            }
        }
    }
    private func save() {
        guard !saved, let routine, let request = sentRequest else { return }
        saved = true
        do {
            try AIRoutinePersistence.save(routine, request: request, gymID: gym?.id, extras: extras, in: context.container)
            dismiss()
        } catch { saved = false; self.error = error.localizedDescription }
    }
}

private struct AIRoutineDayEditor: View {
    @Binding var day: AIRoutineDay
    var options: [RoutineExerciseOption]
    var activities: [CardioActivity]
    var body: some View {
        Form {
            TextField("Session name", text: $day.name)
            Section("Strength") {
                ForEach($day.strength) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Exercise", selection: $item.exerciseID) {
                            ForEach(options.filter { option in option.id == item.exerciseID || !day.strength.contains { $0.exerciseID == option.id } }) { Text($0.name).tag($0.id) }
                        }
                        Stepper("\(item.sets) sets", value: $item.sets, in: 1...10)
                        Stepper("\(item.reps) reps", value: $item.reps, in: 1...50)
                        Stepper("\(item.restSeconds)s rest", value: $item.restSeconds, in: 0...600, step: 15)
                        Button("Remove exercise", role: .destructive) { day.strength.removeAll { $0.id == item.id } }
                    }
                }.onMove { day.strength.move(fromOffsets: $0, toOffset: $1) }
                if let first = options.first(where: { option in !day.strength.contains { $0.exerciseID == option.id } }) {
                    Button("Add exercise") { day.strength.append(.init(exerciseID: first.id, sets: 3, reps: 10, restSeconds: 60)) }.disabled(day.strength.count >= 10)
                }
            }
            Section("Cardio") {
                ForEach($day.cardio) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Activity", selection: $item.activity) { ForEach(activities) { Text($0.name).tag($0) } }
                        Stepper("\(item.minutes) min", value: $item.minutes, in: 1...180)
                        Button("Remove cardio", role: .destructive) { day.cardio.removeAll { $0.id == item.id } }
                    }
                }
                if let first = activities.first {
                    Button("Add cardio") { day.cardio.append(.init(activity: first, minutes: 15)) }.disabled(day.cardio.count >= 3)
                }
            }
        }.navigationTitle("Edit session").toolbar { EditButton() }
    }
}
