import SwiftData
import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
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
    /// Kept on the coordinator (the workout's runtime) since ticket 11, so it survives minimise
    /// and lock-screen commands read it too.
    private var degradedRestSetID: UUID? {
        get { heartRateCoordinator.degradedRestSetID }
        nonmutating set { heartRateCoordinator.degradedRestSetID = newValue }
    }
    /// How the last rest ended (Z03): recovered, or run out. Shown on the Lock Screen card until
    /// the next set is logged. On the coordinator for the same reason.
    private var lastRestResult: WorkoutActivityAttributes.RestResult? {
        get { heartRateCoordinator.lastRestResult }
        nonmutating set { heartRateCoordinator.lastRestResult = newValue }
    }
    /// The slow part of the card's content (next set, previous, new-best, rest kind: history
    /// queries), rebuilt only when its inputs change — the liveness tick pushes every 2 s.
    @State private var activityBase: (key: Int, state: WorkoutActivityAttributes.ContentState)?
    /// Drives `refreshLiveness`, so a sensor that goes quiet stops being
    /// reported as live rather than freezing on its last reading.
    private let livenessTick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    // The rest alarm is deliberately NOT here. It lives on
    // `WorkoutHeartRateCoordinator`, because C1's minimise dismisses this screen
    // while the workout keeps running — a screen-owned alarm goes silent the
    // moment the user leaves the app, which is most of every rest.


    private func startPlannedCardio(_ target: PlannedCardio) {
        guard workout.canStart(target) else { return }
        heartRateCoordinator.cardio.start(target.activity, plannedTargetID: target.id)
        guard workout.unfinishedCardio != nil else { return }
        cardioFocus = true
        refreshRest()
        heartRateCoordinator.broadcastRest(endsAt: nil)
    }

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

    @Environment(\.look) private var appLook
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// New best / First time marks, per set (recomputed when their inputs change, not per frame).
    @State private var badges: [UUID: SetBadge] = [:]
    /// L03: the new best the user just logged, on the rest slab for a few seconds.
    @State private var freshBest: LiveFreshBest?

    /// The lifting workout is drawn in the Paper-structure live look (ticket 01's chosen design);
    /// cardio focus stays plain Floodlight.
    private var screenLook: Look {
        cardioFocus ? appLook : Look.live(dark: appLook.isDark)
    }

    var body: some View {
        NavigationStack {
            // A List, not a ScrollView, SO THAT EXERCISES CAN BE DRAGGED
            // (requested 2026-08-29). `.onMove` is List-only; every row is
            // stripped back to nothing and the cards draw their own surface.
            List {
                header
                    .liveRow(top: 4, bottom: 6)

                vitals
                    .liveRow(top: 6, bottom: 8)

                if workout.hasUnknownCardioTargets {
                    Text("Some cardio targets are unavailable in this version.")
                        .font(screenLook.font.footnote).foregroundStyle(screenLook.textSecondary)
                        .liveRow(top: 2, bottom: 6)
                }
                if !workout.plannedCardio.isEmpty {
                    plannedCardio.liveRow(top: 6, bottom: 8)
                }
                if !workout.orderedCardio.isEmpty || cardioFocus {
                    Picker("Activity", selection: $cardioFocus) {
                        Text("Lifting").tag(false)
                        Text("Cardio").tag(true)
                    }
                    .pickerStyle(.segmented).accessibilityIdentifier("workoutActivityFocus")
                    .liveRow(top: 4, bottom: 6)
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
                            }
                            .font(screenLook.font.subhead).frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(screenLook.textSecondary)
                        .liveRow(top: 2, bottom: 8)
                    }

                    let nextID = WorkoutSession.nextSet(in: workout)?.id
                    ForEach(entries) { entry in
                        ExerciseEntryCard(
                            entry: entry,
                            showMachinePicker: { machinePickerEntry = entry },
                            showPerformance: { performanceEntry = entry },
                            completionChanged: { set, completed in
                                updateRest(for: set, isCompleted: completed)
                                celebrateIfNewBest(set, completed: completed)
                            },
                            nextSetID: nextID,
                            isResting: restEnd != nil,
                            badges: badges
                        )
                        .liveRow(top: 6, bottom: 6)
                    }
                    .onMove(perform: moveEntries)

                    if entries.isEmpty, let gym = workout.isDeleted ? nil : workout.gym {
                        let recent = LiveRecentSection.exercises(at: gym, in: modelContext)
                        if !recent.isEmpty {
                            LiveRecentSection(gymName: gym.name, exercises: recent) { addEntry(for: $0) }
                                .liveRow(top: 10, bottom: 8)
                        }
                    }
                }

                LiveAddBlock(
                    hasGym: hasGym, isResting: restEnd != nil, cardioFocus: cardioFocus,
                    addExercise: {
                        cardioFocus = false
                        showExercisePicker = true
                    },
                    addByMachine: {
                        // Machine-first path (D7).
                        cardioFocus = false
                        showMachinePicker = true
                    },
                    addCardio: { showCardioPicker = true })
                .liveRow(top: entries.isEmpty ? 10 : 18, bottom: 8)

                // Discarding lives at the end of the list (the chosen live design), confirmed.
                DestructiveRowButton("Discard Workout…") { confirmingCancel = true }
                    .accessibilityIdentifier("discardWorkout")
                    .liveRow(top: 14, bottom: 28)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            .background(screenLook.ground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if cardioFocus, let segment = workout.unfinishedCardio {
                    CardioControls(segment: segment, recorder: heartRateCoordinator.cardio)
                } else if restEnd != nil || freshBest != nil {
                    LiveRestSlab(
                        restEnd: restEnd,
                        restTotal: restTotal,
                        next: nextLabel,
                        best: freshBest,
                        addFifteen: addFifteen,
                        skip: skipRest,
                        expired: {
                            restExpiryCount += 1
                            refreshRest()
                        },
                        openBest: {
                            performanceEntry = freshBest.flatMap { best in entries.first { $0.id == best.entryID } }
                        })
                    .transition(RestBar.transition(reduceMotion: reduceMotion))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86), value: restEnd == nil && freshBest == nil)
            // L03: the band stays for its few seconds, then the slab is the rest alone (or goes).
            .task(id: freshBest?.setID) {
                guard freshBest != nil else { return }
                try? await Task.sleep(for: LiveFreshBest.window)
                if !Task.isCancelled { freshBest = nil }
            }
            // Inside the list and the rest slab only: the sheets over the cover stay Floodlight.
            .environment(\.look, screenLook)
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
                        HStack(spacing: 6) {
                            Text(workout.isDeleted ? "Workout" : workout.historyTitle)
                                .font(screenLook.font.navTitle)
                                .foregroundStyle(screenLook.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "pencil")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(screenLook.textSecondary)
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
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(screenLook.textPrimary)
                    }
                    .accessibilityIdentifier("minimizeWorkout")
                    .accessibilityLabel("Minimize workout")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finishTapped() }
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(screenLook.textPrimary)
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
                ExercisePickerSheet(gym: workout.isDeleted ? nil : workout.gym) { exercise in
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
            .onAppear(perform: refreshRest)
            .onAppear(perform: refreshBadges)
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
            // +15s / Skip / Pause pressed on the Lock Screen or the island (ticket 11): the
            // command already changed the store; read the rest back from it.
            .onReceive(NotificationCenter.default.publisher(for: WorkoutActivityCommands.didApply)) { note in
                guard (note.object as? UUID) == workout.id else { return }
                if workout.restEndsAt == nil { lastRestResult = nil }
                refreshRest()
                pushActivityState()
            }
            .onChange(of: entries.count) { _, _ in
                heartRateCoordinator.cardio.sync()
            }
            // Every input of the marks — completion, set type, value, deletion, equipment or
            // variation — changes this, so a sticker can never outlive the data behind it.
            .onChange(of: badgeInputs) { _, _ in refreshBadges() }
        }
    }

    /// Ticket 16 (the user, 2026-09-17: "keep the current design, but move the timer next to
    /// the gym name, with seconds, and make the sets-completed indicator like Codex A's"): one
    /// status line — the gym, the running clock, and a small ring with "N/M sets".
    private var header: some View {
        let sets = entries.flatMap { WorkoutSession.orderedSets(of: $0) }
        let completed = sets.filter { $0.completedAt != nil }.count
        return LiveHeaderLine(
            gym: workout.isDeleted ? "" : (workout.gym?.name ?? "No gym"),
            startedAt: workout.isDeleted ? .now : workout.startedAt,
            done: completed, total: sets.count, showsSets: !cardioFocus)
    }

    /// D41: live heart rate beside the workout's calories and volume, above the exercises —
    /// the numbers that change while you are not touching the screen.
    private var vitals: some View {
        LiveVitalsStrip(
            monitor: heartRate,
            recordsHeartRate: !workout.isDeleted && workout.sensorConfiguration.recordsActivity,
            volume: WeightMath.convert(volumeKg, from: .kg, to: displayUnit),
            unit: displayUnit,
            editMaxHeartRate: { showMaxHeartRateSheet = true })
    }

    /// Σ(normalizedKg × reps) of this workout's completed weighted sets (D21, `RecordsMath`).
    private var volumeKg: Double {
        let inputs = entries.flatMap { entry in
            WorkoutSession.orderedSets(of: entry).map { set in
                RecordSetInput(
                    loadType: entry.effectiveLoadType, exerciseID: entry.snapshotExerciseID, gymID: nil,
                    machineID: nil, modelID: nil, freeWeightTag: nil, presetID: nil, setType: set.type,
                    reps: set.reps, weightValue: set.weightValue, weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg, completedAt: set.completedAt)
            }
        }
        return RecordsMath.totalVolumeKg(among: inputs)
    }

    /// The gym's unit, else the app preference (T7), for the derived volume figure.
    private var displayUnit: WeightUnit {
        let rows = (try? modelContext.fetch(FetchDescriptor<AppPreferences>())) ?? []
        return UnitPrecedence.defaultUnit(
            machineUnit: nil,
            gymUnit: workout.isDeleted ? nil : workout.gym?.defaultUnit,
            appPreference: AppPreferences.canonical(of: rows)?.unitPreference)
    }

    /// Template cardio targets (D57): a prescription with an explicit Start, never automatic.
    private var plannedCardio: some View {
        VStack(alignment: .leading, spacing: screenLook.space.header) {
            SectionHeader("Cardio targets")
            LookList {
                ForEach(workout.plannedCardio) { target in
                    LookRow(target.activity.name, subtitle: target.summary, symbol: target.activity.symbol,
                            showsChevron: false) {
                        if workout.canStart(target) {
                            Button("Start") { startPlannedCardio(target) }
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(screenLook.actionText)
                                .frame(minHeight: 44)
                                .disabled(workout.unfinishedCardio != nil || heartRate == nil)
                                .accessibilityIdentifier("startPlannedCardio")
                        } else {
                            Text("Started").font(screenLook.font.caption).foregroundStyle(screenLook.textSecondary)
                        }
                    }
                }
            }
        }
    }

    /// The rest slab's next line: "Next · Set 3 · 110 × 8" in the same exercise, else
    /// "Next · <exercise>" (rest comes after the last superset member, D48).
    private var nextLabel: String? {
        guard !workout.isDeleted, let next = WorkoutSession.nextSet(in: workout), let entry = next.entry else { return nil }
        let startingEntryID = workout.restStartedBySetID.flatMap { restStartingSet($0) }?.entry?.id
        guard startingEntryID == entry.id else {
            return screenLook.nextExerciseLabel(entry.exercise?.name ?? entry.snapshotExerciseName)
        }
        let sets = WorkoutSession.orderedSets(of: entry)
        let number = sets.prefix { $0.id != next.id }.filter { $0.type != .warmup }.count + 1
        let loadType = entry.effectiveLoadType
        var value: SetValue?
        if let reps = next.reps, !loadType.takesWeight || next.weightValue != nil {
            value = SetValue(weight: next.weightValue, unit: next.weightUnit, reps: reps)
        }
        if next.type == .warmup {
            return "Next · Warmup" + (value.map { " · \(screenLook.previousLabel($0, rowUnit: next.weightUnit, loadType: loadType))" } ?? "")
        }
        return screenLook.nextSetLabel(number: number, value: value, rowUnit: next.weightUnit, loadType: loadType)
    }

    /// What `SetBadgeMath` reads from this workout, hashed: the workout's start, each entry's
    /// scope (live exercise / machine / tag / preset and the frozen snapshot of each), its load
    /// type, and each set's identity, type, completion and value. Read in `body`, so SwiftData
    /// observation re-renders on any change to it and `refreshBadges` runs only then. Finished
    /// history is not in it: history cannot change while this screen is up (it is edited from
    /// History, and returning here refreshes on appear).
    private var badgeInputs: Int {
        guard !workout.isDeleted else { return 0 }
        var hasher = Hasher()
        hasher.combine(workout.startedAt)
        for entry in entries where !entry.isDeleted {
            hasher.combine(entry.id)
            hasher.combine(entry.exercise?.id)
            hasher.combine(entry.machine?.id)
            hasher.combine(entry.freeWeightTag)
            hasher.combine(entry.preset?.id)
            hasher.combine(entry.effectiveLoadType)
            hasher.combine(entry.snapshotCapturedAt)
            hasher.combine(entry.snapshotExerciseID)
            hasher.combine(entry.snapshotMachineID)
            hasher.combine(entry.snapshotFreeWeightTag)
            hasher.combine(entry.snapshotPresetID)
            for set in entry.sets ?? [] where !set.isDeleted {
                hasher.combine(set.id)
                hasher.combine(set.type)
                hasher.combine(set.completedAt)
                hasher.combine(set.reps)
                hasher.combine(set.weightValue)
                hasher.combine(set.weightUnit)
                hasher.combine(set.normalizedKg)
            }
        }
        return hasher.finalize()
    }

    /// L03: completing a set that sets a new best docks the band on the slab; un-completing it
    /// takes the band away. Only a deliberate completion celebrates — never a refresh or appear.
    private func celebrateIfNewBest(_ set: SetRecord, completed: Bool) {
        guard completed else {
            if freshBest?.setID == set.id { freshBest = nil }
            return
        }
        if let best = freshBest(for: set) { freshBest = best }
    }

    /// The band's content for `set`, or nil when it is not (or no longer) a new best in its scope.
    private func freshBest(for set: SetRecord) -> LiveFreshBest? {
        guard !set.isDeleted, set.completedAt != nil, let entry = set.entry, !entry.isDeleted,
              let outcome = try? SetBadgeMath.outcomes(for: entry, in: modelContext)[set.id],
              outcome.badge == .newBest, let reps = set.reps else { return nil }
        return LiveFreshBest(
            setID: set.id, entryID: entry.id,
            exerciseName: entry.exercise?.name ?? entry.snapshotExerciseName,
            value: SetValue(weight: set.weightValue, unit: set.weightUnit, reps: reps),
            previous: outcome.previous.flatMap { previous in
                previous.reps.map { SetValue(weight: previous.weightValue, unit: previous.weightUnit, reps: $0) }
            },
            loadType: entry.effectiveLoadType)
    }

    /// Codex review 03b: the band follows its set like the stickers do. A set made a warmup,
    /// deleted, un-logged or corrected below the record takes the band away; a correction that
    /// keeps the record updates its numbers. Same set id, so the original 4 s expiry stands.
    private func reconcileFreshBest() {
        guard let current = freshBest else { return }
        let set = entries.lazy.flatMap { $0.sets ?? [] }.first { $0.id == current.setID }
        let updated = set.flatMap(freshBest(for:))
        if updated != current { freshBest = updated }
    }

    /// Recomputes the New best / First time marks (`SetBadgeMath`) and reconciles the fresh
    /// band. Called on appear and when `badgeInputs` changes — not per frame: it reads the
    /// scope's whole history.
    private func refreshBadges() {
        guard !workout.isDeleted else { badges = [:]; freshBest = nil; return }
        var result: [UUID: SetBadge] = [:]
        for entry in entries {
            if let marks = try? SetBadgeMath.badges(for: entry, in: modelContext) {
                result.merge(marks) { first, _ in first }
            }
        }
        if result != badges {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6)) { badges = result }
        }
        reconcileFreshBest()
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
                lastRestResult = .recovered(bpm: bpm, targetBpm: rule.thresholdBpm)
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
            state: activityState())
    }

    /// What the Lock Screen card shows now (ticket 11): the slow part from `activityBase`, the
    /// heart reading and the cardio figures fresh.
    private func activityState() -> WorkoutActivityAttributes.ContentState {
        let heart = WorkoutActivityContent.Heart(
            bpm: heartRate?.isStale == true ? nil : heartRate?.current?.bpm, zone: heartRate?.currentZone)
        var hasher = Hasher()
        hasher.combine(badgeInputs)
        hasher.combine(workout.restEndsAt)
        hasher.combine(workout.restStartedBySetID)
        hasher.combine(degradedRestSetID)
        hasher.combine(lastRestResult)
        hasher.combine(workout.unfinishedCardio?.id)
        hasher.combine(workout.historyTitle)
        // The next set follows superset grouping (D48), which `badgeInputs` does not read
        // (codex-review-11 #2).
        for entry in entries where !entry.isDeleted {
            hasher.combine(entry.id)
            hasher.combine(entry.supersetGroupID)
        }
        let key = hasher.finalize()
        var state: WorkoutActivityAttributes.ContentState
        if let base = activityBase, base.key == key {
            state = base.state
        } else {
            state = WorkoutActivityContent.make(for: workout, in: modelContext, heart: heart,
                                                restResult: lastRestResult, degradedRestSetID: degradedRestSetID)
            activityBase = (key, state)
        }
        state.heartRateBpm = heart.bpm
        state.zoneLabel = heart.bpm == nil ? nil : heart.zone?.label
        state.zoneLevel = heart.bpm == nil ? nil : heart.zone?.rawValue
        state.cardio = workout.unfinishedCardio.map { WorkoutActivityContent.cardio($0, in: workout, now: .now) }
        return state
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
        MaxHeartRateResolver.current(in: modelContext)
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
        lastRestResult = nil
        defer {
            // The fallback belongs to its rest: keep it while that rest runs (a drop set or an
            // unrelated un-completion leaves it running, D26), drop it once another rest replaces it
            // or none runs (codex-review-11b #2).
            if let degraded = degradedRestSetID, workout.restEndsAt == nil || workout.restStartedBySetID != degraded {
                degradedRestSetID = nil
            }
        }
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
        lastRestResult = nil
        do {
            try restTimer.skip(workout)
            restEnd = nil
        } catch {
            assertionFailure("Failed to skip rest timer: \(error)")
        }
    }

    /// Every path that can clear an expired rest comes through here (appear, foreground, the
    /// slab's expiry, a lock-screen command): say how it ended BEFORE `currentState` clears the
    /// facts it is read from (codex-review-11 #4).
    private func refreshRest() {
        if !workout.isDeleted { heartRateCoordinator.noteRestFacts(for: workout.id) }
        if let end = workout.restEndsAt, end <= .now {
            lastRestResult = activityState().shownResult(at: .now, isStale: true)
        }
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

private extension View {
    /// A bare list row: no separator, no background, the 20 pt margin.
    func liveRow(top: CGFloat, bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
