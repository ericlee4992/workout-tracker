import SwiftData
import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var workout: Workout
    /// C1: dismisses the cover while the workout keeps running — the Workout
    /// tab then shows a resume affordance. Defaults to a plain dismiss.
    var onMinimize: (() -> Void)?
    /// C2/A2: hands the finish result back so the presenter can confirm it.
    /// The finished workout when something was logged; `nil` when nothing
    /// survived cleanup and the workout was discarded instead (A2) — that
    /// outcome must be *said*, not silently vanish behind a "saved" sheet.
    var onFinished: ((Workout?) -> Void)?

    @State private var restEnd: Date?
    @State private var restTotal: Double = 120
    @State private var restExpiryCount = 0
    @State private var keyboardVisible = false
    @State private var machinePickerEntry: ExerciseEntry?
    @State private var performanceEntry: ExerciseEntry?
    @State private var showExercisePicker = false
    @State private var showCardioPicker = false
    @State private var cardioFocus = false
    @State private var showMachinePicker = false
    @State private var confirmingCancel = false
    /// Naming the workout mid-session (milestone 9, ticket 02).
    @State private var renamingWorkout = false
    @State private var renameText = ""
    /// The live rename was refused because the workout had already finished
    /// under this screen (a stale or racing view). Say so rather than closing
    /// the alert as if the name had been saved (codex-review 02b).
    @State private var renameRefused = false
    @State private var driftTemplate: WorkoutTemplate?
    @State private var choosingDriftResolution = false
    /// Owned by `RootView`, not by this screen (codex-review-2 #2): minimise
    /// dismisses this view while the workout keeps running, so a screen-owned
    /// session would either be orphaned or silently ended mid-workout.
    @Environment(WorkoutHeartRateCoordinator.self) private var heartRateCoordinator
    /// Owned by `RootView` for the same reason the heart-rate session is.
    @Environment(WorkoutActivityController.self) private var workoutActivity
    @State private var showMaxHeartRateSheet = false
    /// The rest that has already degraded to the standard timer. Once a rest
    /// falls back, a late sample must not turn it back into a heart-rate rest
    /// and fire a "recovered" alarm over the fallback one (codex-review-2 #4).
    @State private var degradedRestSetID: UUID?
    /// Drives `refreshLiveness`, so a sensor that goes quiet stops being
    /// reported as live rather than freezing on its last reading.
    private let livenessTick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    // The rest alarm is deliberately NOT here. It lives on
    // `WorkoutHeartRateCoordinator`, because C1's minimise dismisses this screen
    // while the workout keeps running — a screen-owned alarm goes silent the
    // moment the user leaves the app, which is most of every rest.


    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    /// The live feed for this workout, resolved once in `.task`.
    ///
    /// NOT a computed property that asks the coordinator: `monitor(for:)`
    /// mutates observable state, and doing that during body evaluation loops
    /// the renderer and freezes every control on the screen. The coordinator
    /// keeps it across a minimise/resume cycle, so one workout stays one
    /// session with one continuous set of samples.
    @State private var heartRate: HeartRateMonitor?

    private var entries: [ExerciseEntry] {
        workout.isDeleted ? [] : WorkoutSession.orderedEntries(of: workout)
    }

    /// Whether the machine-first path has anything to offer (D1).
    private var hasGym: Bool {
        !workout.isDeleted && workout.gym != nil
    }

    var body: some View {
        NavigationStack {
            // A List, not a ScrollView, SO THAT EXERCISES CAN BE DRAGGED
            // (requested 2026-08-29). `.onMove` is List-only; the cards keep
            // their own background, corner radius and horizontal padding, so
            // every row is stripped back to nothing and the layout is
            // unchanged from the ScrollView it replaces.
            List {
                header
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 7, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if !workout.orderedCardio.isEmpty || cardioFocus {
                Picker("Activity", selection: $cardioFocus) {
                    Text("Lifting").tag(false)
                    Text("Cardio").tag(true)
                }
                .pickerStyle(.segmented).accessibilityIdentifier("workoutActivityFocus")
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }

                if cardioFocus {
                    CardioWorkoutSection(workout: workout, recorder: heartRateCoordinator.cardio, monitor: heartRate)
                } else {
                if let cardio = workout.unfinishedCardio {
                    Button { cardioFocus = true } label: {
                        HStack {
                            Label(cardio.activity.name, systemImage: cardio.activity.symbol)
                            Spacer()
                            Text(cardio.isRunning ? "Recording" : "Paused")
                        }.font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(Theme.secondary)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                // D41: live heart rate, above the exercises because it is
                // the one number that changes while you are not touching
                // the screen.
                if let heartRate {
                    HeartRateBar(
                        monitor: heartRate,
                        editMaxHeartRate: { showMaxHeartRateSheet = true })
                        .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                ForEach(entries) { entry in
                    ExerciseEntryCard(
                        entry: entry,
                        showMachinePicker: { machinePickerEntry = entry },
                        showPerformance: { performanceEntry = entry },
                        completionChanged: { set, completed in
                            updateRest(for: set, isCompleted: completed)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: moveEntries)

                }

                VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            addExerciseButton
                            // Machine-first path (D7). D1 (ticket 17): a no-gym
                            // workout has no machines to list, but hiding the
                            // button hid the whole equipment-aware
                            // differentiator with no explanation — so it stays
                            // visible, disabled, and says why below.
                            Button {
                                cardioFocus = false
                                showMachinePicker = true
                            } label: {
                                Label("Add by Machine", systemImage: "figure.strengthtraining.traditional")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.secondary)
                            .disabled(!hasGym)
                            .accessibilityIdentifier("addByMachine")
                        }
                        Button { showCardioPicker = true } label: {
                            Label("Add Cardio", systemImage: "plus").frame(maxWidth: .infinity)
                        }.buttonStyle(.secondary).accessibilityIdentifier("addCardio")
                        if !hasGym {
                            Text("Pick a gym to log by machine")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .accessibilityIdentifier("addByMachineUnavailable")
                        }
                    }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                if let restEnd {
                    RestTimerBar(
                        restEnd: restEnd,
                        restTotal: restTotal,
                        addFifteen: addFifteen,
                        skip: skipRest,
                        expired: {
                            restExpiryCount += 1
                            refreshRest()
                        })
                }
            }
            .sensoryFeedback(.restDone, trigger: restExpiryCount)
            .navigationTitle(workout.isDeleted ? "Workout" : workout.historyTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The title is the name, and tapping it edits the name. A
                // principal item replaces the bar's own title; the pencil says
                // it is tappable, because an inline title never looks like a
                // control on its own.
                ToolbarItem(placement: .principal) {
                    Button {
                        renameText = workout.isDeleted ? "" : (workout.name ?? "")
                        renamingWorkout = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(workout.isDeleted ? "Workout" : workout.historyTitle)
                                .font(.headline)
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workoutTitle")
                    // The visible title IS the label; the hint says it edits.
                    .accessibilityHint("Edits the workout name")
                }
                // C1: leaving an active workout no longer means finishing or
                // discarding it — minimise keeps it running behind the tabs.
                ToolbarItem(placement: .topBarLeading) {
                    Button { minimize() } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityIdentifier("minimizeWorkout")
                    .accessibilityLabel("Minimize workout")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { confirmingCancel = true }
                        .tint(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finishTapped() }
                        .font(.headline)
                        .accessibilityIdentifier("finishWorkout")
                }
            }
            .alert("Workout Name", isPresented: $renamingWorkout) {
                TextField(workout.isDeleted ? "Workout" : workout.derivedTitle, text: $renameText)
                    .accessibilityIdentifier("workoutNameField")
                Button("Save") {
                    do {
                        // false means the Domain refused: the workout is no
                        // longer running, so the live path must not name it.
                        if try !session.rename(workout, to: renameText),
                           !workout.isDeleted, workout.finishedAt != nil,
                           Workout.normalizedName(renameText) != workout.name {
                            renameRefused = true
                        }
                    } catch {
                        assertionFailure("Failed to rename workout: \(error)")
                    }
                }
                .accessibilityIdentifier("saveWorkoutName")
                Button("Cancel", role: .cancel) {}
            }
            .alert("This workout has finished", isPresented: $renameRefused) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It was not renamed. Rename it from History, where the change is recorded as an edit.")
            }
            .confirmationDialog(
                "Cancel this workout?",
                isPresented: $confirmingCancel,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive) { cancelWorkout() }
                Button("Keep Logging", role: .cancel) {}
            } message: {
                Text("The workout and everything logged in it will be deleted.")
            }
            .templateDriftDialog(
                isPresented: $choosingDriftResolution,
                message: "This workout's completed exercises, set counts, or target reps differ from the template.",
                cancelLabel: "Keep Logging",
                resolve: finishTemplatedWorkout)
            .sheet(item: $machinePickerEntry) { entry in
                MachinePickerSheet(entry: entry)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $performanceEntry) { entry in
                PreviousPerformanceSheet(entry: entry)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCardioPicker) {
                CardioActivityPicker(endsCurrentSegment: workout.unfinishedCardio != nil) { activity in
                    heartRateCoordinator.cardio.start(activity)
                    cardioFocus = true
                    refreshRest()
                    heartRateCoordinator.broadcastRest(endsAt: nil)
                }
            }
            .alert("Cardio could not be saved", isPresented: Binding(
                get: { heartRateCoordinator.cardio.errorMessage != nil },
                set: { if !$0 { heartRateCoordinator.cardio.errorMessage = nil } })) {
                    Button("OK", role: .cancel) { heartRateCoordinator.cardio.errorMessage = nil }
            } message: { Text(heartRateCoordinator.cardio.errorMessage ?? "") }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercise in
                    addEntry(for: exercise)
                }
            }
            .sheet(isPresented: $showMachinePicker) {
                AddByMachineSheet(workout: workout)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showMaxHeartRateSheet) {
                // Re-resolve on dismiss. `resolvedMaxHeartRate()` is otherwise
                // read only in `.task`, which runs once per appearance — so a
                // maximum entered mid-workout left the monitor's `maxHeartRate`
                // nil and the zone chip absent for the REST OF THE WORKOUT,
                // which reads as the setting having done nothing.
                heartRate?.maxHeartRate = resolvedMaxHeartRate()
            } content: {
                MaxHeartRateSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
            .onAppear(perform: refreshRest)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshRest() }
            }
            // The session starts with the workout screen and ends when the
            // workout does — `finish`/`cancel` both route through `endWorkout`.
            .task {
                let monitor = heartRateCoordinator.monitor(
                    for: workout, maxHeartRate: resolvedMaxHeartRate())
                // D43 is evaluated on sample arrival, not on a UI tick: samples
                // keep coming with the screen off, a SwiftUI timer does not
                // (codex-review 2.2). Re-attached on every appearance, so a
                // resumed workout keeps evaluating its rests.
                // The coordinator owns the sample tick and forwards it here.
                // The alarm hangs off its end, not this one, so it survives
                // this screen being dismissed.
                heartRateCoordinator.onSample = { evaluateHeartRateRest() }
                pushActivityState()
                heartRate = monitor
                cardioFocus = workout.unfinishedCardio != nil || (!workout.orderedCardio.isEmpty && workout.entries?.isEmpty != false)
            }
            // Every path that changes the rest — starting one, +15s, skipping,
            // recovering, degrading, un-completing — moves `restEnd`. Mirroring
            // from here rather than from each of them is why the watch cannot
            // fall out of step with the phone.
            .onChange(of: restEnd) { _, newValue in
                // Also arms the audible alarm for this rest — the coordinator
                // needs the end date anyway to mirror it to the watch.
                heartRateCoordinator.broadcastRest(endsAt: newValue)
            }
            .onReceive(livenessTick) { _ in
                heartRate?.refreshLiveness()
                evaluateHeartRateRest()
                pushActivityState()
            }
            .onChange(of: restEnd) { _, _ in pushActivityState() }
            .onChange(of: entries.count) { _, _ in heartRateCoordinator.cardio.sync() }
        }
    }

    /// Ticket 16 (the user, 2026-09-17: "keep the current design, but move the
    /// timer next to the gym name, with seconds, and make the sets-completed
    /// indicator like Codex A's"): one status line — the gym chip, the running
    /// clock in `stat`, and a small neutral ring with "N/M sets". The Large
    /// Title hero and the amber count chip are gone; nothing here competes
    /// with the set being logged. The line stays under the keyboard's
    /// accessory too — it is short enough — so the fields keep their room.
    @ViewBuilder
    private var addExerciseButton: some View {
        let button = Button {
            cardioFocus = false
            showExercisePicker = true
        } label: {
            Label("Add Exercise", systemImage: "plus").frame(maxWidth: .infinity)
        }.accessibilityIdentifier("addExercise")
        if cardioFocus { button.buttonStyle(.secondary) }
        else { button.buttonStyle(.primary) }
    }

    private var header: some View {
        let sets = entries.flatMap { WorkoutSession.orderedSets(of: $0) }
        let completed = sets.filter { $0.completedAt != nil }.count
        return HStack(alignment: .center, spacing: Theme.Space.medium) {
            Chip(tint: Theme.secondary) {
                Label(workout.isDeleted ? "" : (workout.gym?.name ?? "No gym"),
                      systemImage: "mappin.and.ellipse")
            }
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(Format.elapsed(seconds: elapsedSeconds(at: timeline.date)))
                    .font(Theme.stat)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .accessibilityLabel("Elapsed \(Format.spokenElapsed(seconds: elapsedSeconds(at: timeline.date)))")
            }
            Spacer(minLength: 0)
            if !cardioFocus {
            HStack(spacing: 6) {
                ProgressRing(progress: sets.isEmpty ? 0 : Double(completed) / Double(sets.count),
                             tint: Theme.secondary, lineWidth: 3)
                    .frame(width: 22, height: 22)
                Text("\(completed)/\(sets.count) sets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(completed) completed sets, \(sets.count) total")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, keyboardVisible ? 0 : 4)
        .padding(.bottom, keyboardVisible ? 0 : 8)
    }

    private func elapsedSeconds(at date: Date) -> Int {
        workout.isDeleted ? 0 : Int(date.timeIntervalSince(workout.startedAt))
    }

    private func elapsedMinutes(at date: Date) -> Int {
        guard !workout.isDeleted else { return 0 }
        return max(0, Int(date.timeIntervalSince(workout.startedAt) / 60))
    }

    // MARK: Actions

    private func minimize() {
        // Deliberately nothing here: the workout is still running, so its
        // heart-rate session is too. `RootView` owns it (codex-review-2 #2).
        if let onMinimize {
            onMinimize()
        } else {
            dismiss()
        }
    }

    /// B2: Finish finishes. A from-scratch workout gets no pre-finish
    /// interrogation — save-as-template moved to the post-finish confirmation
    /// (C2), where it is offered once the workout is safely stored. The
    /// template-drift prompt (D18) survives, but only for workouts that
    /// actually came from a template.
    /// Ends the heart-rate session. Called on BOTH ways out of a workout: a
    /// session left running keeps the sensor powered and the battery draining
    /// for a workout that is over. The rest timer had this exact bug shape —
    /// correct only because every call site happened to tear down first.
    /// Ends the session and banks what it measured. Called on every path that
    /// ends the workout; minimise deliberately does NOT call it, because the
    /// workout is still running and so is its heart rate.
    private func stopHeartRate() {
        heartRateCoordinator.end(workout)
        // Ends the lock-screen card on the SAME path the sensor session ends
        // on. Hanging it here rather than on each finish/cancel/discard call
        // site is what stops one of them being forgotten — an activity that
        // outlives its workout shows a heart rate for a session nobody is
        // doing, the same defect as an orphaned sensor session.
        if !workout.isDeleted { workoutActivity.end(workoutID: workout.id) }
        else { workoutActivity.endAny() }
    }

    /// D43: while a heart-rate rest is running, the threshold can end it before
    /// its cap does. The cap itself is the persisted `restEndsAt`, so it still
    /// fires through the ordinary path — including after a relaunch, and while
    /// the app is backgrounded. This only ever ends a rest EARLY.
    private func evaluateHeartRateRest() {
        guard !workout.isDeleted,
              let start = workout.restStartedAt,
              workout.restEndsAt != nil,
              let setID = workout.restStartedBySetID,
              let set = restStartingSet(setID),
              let plan = try? restTimer.restPlan(for: set),
              let rule = plan.rule,
              degradedRestSetID != setID
        else { return }

        guard let heartRate else { return }
        let state = rule.evaluate(
            samples: heartRate.samplesFromCurrentSource, start: start, asOf: .now)
        switch state {
        case .finished(.recovered(_, let bpm)):
            do {
                try restTimer.finishRecovered(workout, bpm: bpm)
                // `finishRecovered` clears `restEndsAt`, so the cap alarm can
                // no longer fire for this rest — the two endings cannot both
                // sound.
                heartRateCoordinator.soundRecovered()
                refreshRest()
            } catch {
                assertionFailure("Failed to finish recovered rest: \(error)")
            }
        case .degraded:
            // codex-review 2.1 (critical): this used to do nothing, on the
            // false claim that the cap WAS the standard timer. The cap is four
            // minutes; the user's standard rest is one or two.
            do {
                degradedRestSetID = setID
                if let state = try restTimer.degradeToStandard(workout, set: set) {
                    restEnd = state.end
                    restTotal = state.total
                } else {
                    refreshRest()
                }
            } catch {
                assertionFailure("Failed to degrade rest: \(error)")
            }
        case .resting, .finished(.cap):
            break
        }
    }

    /// Pushes the current state to the lock screen.
    ///
    /// D46: the app pushes, the SYSTEM renders and counts down. The rest
    /// countdown is a `timerInterval` ticked by the system, so a suspended app
    /// still shows a correct one — the trap that cost four attempts on the rest
    /// alarm does not apply here as long as nothing tries to tick it.
    private func pushActivityState() {
        guard !workout.isDeleted, workout.finishedAt == nil else { return }
        workoutActivity.show(
            workoutID: workout.id,
            startedAt: workout.startedAt,
            gymName: workout.gym?.name,
            state: WorkoutActivityAttributes.ContentState(
                heartRateBpm: heartRate?.isStale == true ? nil : heartRate?.current?.bpm,
                zoneLabel: heartRate?.currentZone?.label,
                restEndsAt: restEnd,
                completedSets: completedSetCount,
                currentExercise: currentExerciseName))
    }

    private var completedSetCount: Int {
        entries.reduce(0) { total, entry in
            total + WorkoutSession.orderedSets(of: entry)
                .filter { $0.completedAt != nil }.count
        }
    }

    /// The last exercise with a completed set — what the user is working on.
    private var currentExerciseName: String? {
        if let cardio = workout.unfinishedCardio { return cardio.activity.name }
        return entries.last { entry in
            WorkoutSession.orderedSets(of: entry).contains { $0.completedAt != nil }
        }?.snapshotExerciseName ?? entries.last?.exercise?.name
    }

    /// Drag-to-reorder. SwiftUI's own `IndexSet`/destination semantics go
    /// straight to the session, which owns the renumbering and the superset
    /// repair — translating them here is where an off-by-one would live.
    private func moveEntries(from source: IndexSet, to destination: Int) {
        guard !workout.isDeleted else { return }
        do {
            try session.moveEntries(
                of: workout, fromOffsets: source, toOffset: destination)
        } catch {
            assertionFailure("Failed to reorder exercises: \(error)")
        }
    }

    private func restStartingSet(_ id: UUID) -> SetRecord? {
        for entry in entries {
            if let match = WorkoutSession.orderedSets(of: entry).first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
    }

    /// The ceiling zones are computed against (D45): the user's measured
    /// maximum if they have entered one, otherwise 220−age flagged as an
    /// estimate, otherwise nothing at all.
    private func resolvedMaxHeartRate() -> MaxHeartRate? {
        let rows = (try? modelContext.fetch(FetchDescriptor<AppPreferences>())) ?? []
        guard let preferences = AppPreferences.canonical(of: rows) else { return nil }
        return MaxHeartRateResolver.resolve(
            measured: preferences.measuredMaxHeartRate,
            birthDate: preferences.birthDate,
            at: .now)
    }

    private func finishTapped() {
        if workout.sourceTemplateID == nil {
            finishWorkout()
            return
        }
        do {
            let drift = TemplateDriftService(context: modelContext)
            if let template = try drift.sourceTemplate(for: workout),
               try drift.shouldPrompt(for: workout, template: template) {
                driftTemplate = template
                choosingDriftResolution = true
            } else {
                finishWorkout()
            }
        } catch {
            assertionFailure("Failed to inspect template drift: \(error)")
        }
    }

    // `session.finish` / `session.cancel` end the rest timer (state and
    // pending notification) themselves — call sites no longer skip first.
    private func finishWorkout() {
        var outcome = WorkoutFinishOutcome.discardedEmpty
        do {
            stopHeartRate()
            outcome = try session.finish(workout)
        } catch {
            assertionFailure("Failed to finish workout: \(error)")
        }
        reportFinished(outcome)
    }

    private func finishTemplatedWorkout(using resolution: TemplateDriftResolution) {
        var outcome = WorkoutFinishOutcome.discardedEmpty
        do {
            stopHeartRate()
            if let driftTemplate {
                outcome = try TemplateDriftService(context: modelContext).resolve(
                    resolution, workout: workout, to: driftTemplate)
            } else {
                outcome = try session.finish(workout)
            }
        } catch {
            assertionFailure("Failed to finish templated workout: \(error)")
        }
        driftTemplate = nil
        reportFinished(outcome)
    }

    /// C2/A2: hand the outcome to the presenter. A saved workout goes back so
    /// the confirmation can show what was logged; a discarded one goes back as
    /// `nil` so the same sheet can say that nothing was saved instead.
    private func reportFinished(_ outcome: WorkoutFinishOutcome) {
        guard let onFinished else {
            dismiss()
            return
        }
        let saved = outcome == .saved && !workout.isDeleted
            && workout.finishedAt != nil
        onFinished(saved ? workout : nil)
    }

    private func cancelWorkout() {
        stopHeartRate()
        do {
            try session.cancel(workout)
        } catch {
            assertionFailure("Failed to cancel workout: \(error)")
        }
        dismiss()
    }

    private func addEntry(for exercise: Exercise) {
        do {
            try session.addEntry(
                for: exercise,
                to: workout,
                freeWeightTag: exercise.equipmentTypeTags.first { $0 != .machine })
        } catch {
            assertionFailure("Failed to add entry: \(error)")
        }
    }

    private var restTimer: RestTimerService {
        RestTimerService(context: modelContext)
    }

    private func updateRest(for set: SetRecord, isCompleted: Bool) {
        // D48: inside a superset, no rest until the LAST member. Moving
        // straight from A to B with no rest is the entire point of the
        // technique, so a timer firing between members would be telling the
        // user to do the opposite of what they chose.
        //
        // Only completion is gated. UN-completing must still reach the timer,
        // or a mistaken tap would leave a rest running with nothing behind it.
        if isCompleted, let entry = set.entry, !entry.isDeleted,
           !Supersets.shouldRest(afterCompletingSetIn: entry, in: workout) {
            // SKIP a rest already running, do not merely decline to start one.
            //
            // codex-review 2 (high): returning early left an earlier member's
            // rest scheduled. Complete B1 (rest starts), then A2 before it
            // expires, and that rest sat there between A2 and B2 — precisely
            // where D48 says there is none, with its notification still armed.
            if restEnd != nil {
                do {
                    try restTimer.skip(workout)
                    restEnd = nil
                } catch {
                    assertionFailure("Failed to clear rest between superset members: \(error)")
                }
            }
            return
        }
        do {
            showRestTimer(try restTimer.handleCompletionChange(
                of: set, isCompleted: isCompleted))
        } catch {
            assertionFailure("Failed to update rest timer: \(error)")
        }
    }

    private func addFifteen() {
        do { showRestTimer(try restTimer.add(seconds: 15, to: workout)) }
        catch { assertionFailure("Failed to extend rest timer: \(error)") }
    }

    private func skipRest() {
        do {
            try restTimer.skip(workout)
            restEnd = nil
        } catch {
            assertionFailure("Failed to skip rest timer: \(error)")
        }
    }

    private func refreshRest() {
        do { showRestTimer(try restTimer.currentState(for: workout)) }
        catch { assertionFailure("Failed to restore rest timer: \(error)") }
    }

    /// Drives the rest bar from a timer state. The progress denominator is the
    /// state's *total* duration — using the remaining time would make a bar
    /// restored mid-rest jump straight back to full.
    private func showRestTimer(_ state: RestTimerState?) {
        restEnd = state?.end
        if let state { restTotal = max(1, state.total) }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let context = container.mainContext
    let gym = Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg)
    context.insert(gym)
    let workout = Workout(gym: gym)
    context.insert(workout)
    let exercise = Exercise(name: "Seated Chest Press")
    context.insert(exercise)
    try? WorkoutSession(context: context).addEntry(for: exercise, to: workout)
    return ActiveWorkoutView(workout: workout)
        .modelContainer(container)
        .environment(WorkoutHeartRateCoordinator())
}
