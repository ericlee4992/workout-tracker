import Combine
import SwiftData
import SwiftUI
import UIKit

// Soft redesign S2 (D68): the Today tab — the first tab: the week as day rings (a workout mark inside on days trained;
// N5: calories filling each ring toward that day's goal), the fuel card (N5), the Training card (Resume, or the
// template up next with Start — S5/D77: learned from the user's order or their split, with "Not today"; without
// templates the last workout with Repeat and Start workout; Start Lifting / Start Cardio live in Train only), and
// today's log — food by meal (N5; tap to edit or delete) and today's workouts — over the Log food pill (N4).
// Design: the approved prototype's Today (tag design/soft-approved-2026-11-07, Screens/Soft/SoftTodayScreen.swift
// and SoftTodayTop.swift, round 5's day rings).

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Gym> { !$0.archived }, sort: \Gym.name)
    private var gyms: [Gym]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query private var allPreferences: [AppPreferences]
    @Query(
        filter: #Predicate<Workout> { $0.finishedAt == nil },
        sort: [SortDescriptor(\Workout.startedAt, order: .reverse)])
    private var activeWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil },
           sort: [SortDescriptor(\Workout.startedAt, order: .reverse)])
    private var finishedWorkouts: [Workout]
    /// N5: the food log and the goals. Every entry is queried (the week's rings and today's log use a few); a date-bound
    /// query cannot follow `now` across midnight.
    @Query(sort: \FoodEntry.loggedAt) private var foodEntries: [FoodEntry]
    @Query private var nutritionGoals: [NutritionGoal]
    @State private var editingEntry: FoodEntry?
    /// N9b: Health's active energy as Burned (absent in previews and the tour's sample world).
    @Environment(HealthSync.self) private var health: HealthSync?
    /// The entry just deleted, for the Undo toast.
    @State private var deletedEntry: DeletedEntry?
    @State private var showGoals = false
    @State private var foodFailure: String?
    @State private var startRequest: WorkoutStartRequest?
    /// S5 (D77): the user's split and the day's "Not today" choice — view preferences, not workout data.
    @AppStorage(MySplitStore.key) private var splitData = Data()
    @AppStorage(UpNextOverride.key) private var overrideData = Data()
    @State private var titleInBar = false
    /// The screen's "now", one snapshot for the header, the week and the log. Refreshed at the local day boundary,
    /// on a clock or time-zone change and when the app becomes active, so Today never keeps showing yesterday on a
    /// screen left open past midnight (codex-review-s2 #2).
    @State private var now = Date.now

    /// Called with the workout to present — freshly started or resumed.
    var onWorkoutStarted: (Workout) -> Void
    /// Opens a finished workout in History.
    var onOpenWorkout: (Workout) -> Void
    /// Opens Train → Templates (no template yet).
    var onOpenTrain: () -> Void

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    /// The gym Train's picker remembered (D1); Today starts workouts there.
    private var selectedGym: Gym? {
        GymSelection.resolve(id: AppPreferences.canonical(of: allPreferences)?.selectedGymID, among: gyms)
    }

    @State private var showLogFood = false
    /// N7: the scan camera, the scans being estimated, and a scanned meal's items screen.
    @State private var showScan = false
    @State private var scans = FoodScanQueue.shared
    @State private var openScan: FoodEntry?
    @State private var manualFromScan = false
    /// A scan whose session expired: sign in, then it is sent again.
    @State private var signInFor: UUID?
    @State private var showSignIn = false
    @Environment(AccountStore.self) private var account

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Today", subtitle: WorkoutDates.homeSubtitle(now))
                    let summary = weekSummary
                    TodayWeekRings(summary: summary, food: weekFood(summary))
                    TodayFuelCard(day: todayFood) { showGoals = true }
                    trainingSection
                    todaysLog
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 2)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > (dynamicTypeSize.isAccessibilitySize ? 70 : 46)
            } action: { _, past in
                withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
            }
            // N4 (D68; built early by the user's choice, 2026-11-10): Log food above the tab bar, Today only.
            .safeAreaInset(edge: .bottom) { LogFoodPill(action: { showLogFood = true }, scan: { showScan = true }) }
            .navigationDestination(isPresented: $showLogFood) { LogFoodView() }
            .navigationDestination(isPresented: $manualFromScan) {
                ManualAddView(meal: MealSlot.forTime(.now)) { _ in manualFromScan = false }
            }
            .fullScreenCover(isPresented: $showScan) {
                FoodScanFlow(meal: nil, onDone: {}, onManualAdd: { manualFromScan = true })
            }
            .sheet(isPresented: $showSignIn, onDismiss: {
                // Signed in: the same scan is sent again; still signed out, its card stays.
                if let id = signInFor, TerraAccess.ready(account) {
                    scans.retry(id, client: TerraAccess.client(account), context: modelContext)
                }
                signInFor = nil
            }) { AccountSignInSheet() }
            // Completion, failure and Remove move the log; under Reduce Motion they simply appear (codex-review-n7 T2).
            .animation(reduceMotion ? nil : .snappy, value: scans.revision)
            .sheet(item: $openScan) { entry in
                ScanEntryEditor(entry: entry) { copy in
                    withAnimation(reduceMotion ? nil : .snappy) { deletedEntry = copy }
                }
            }
            .navigationDestination(isPresented: $showGoals) { NutritionGoalsView() }
            .sheet(item: $editingEntry) { entry in
                EditEntrySheet(entry: entry) { copy in
                    withAnimation(reduceMotion ? nil : .snappy) { deletedEntry = copy }
                }
            }
            .overlay(alignment: .bottom) { if let deletedEntry { deletedToast(deletedEntry) } }
            .task(id: deletedEntry?.id) {
                // The toast leaves after a few seconds; a newer delete cancels this wait (as Log food's, codex-review-n4).
                guard let shown = deletedEntry?.id else { return }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard deletedEntry?.id == shown else { return }
                withAnimation(reduceMotion ? nil : .snappy) { deletedEntry = nil }
            }
            .alert(FoodCopy.saveFailed, isPresented: Binding(get: { foodFailure != nil },
                                                             set: { if !$0 { foodFailure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(foodFailure ?? "")
            }
            .lookScreenBackground()
            .exercisesInlineTitle("Today", visible: titleInBar)
            .workoutStartFlow(request: $startRequest, gym: selectedGym, onWorkoutStarted: onWorkoutStarted)
            .refreshingNow($now)
            // N9b: Health's active energy for today, read again whenever `now` refreshes (on becoming active too).
            .task(id: BurnedRefresh(now: now, on: health?.isOn(.readBurned) == true)) { await health?.refreshBurned(on: now) }
        }
    }

    private var weekSummary: WeekSummary {
        WeekSummaryMath.summary(ofWorkouts: finishedWorkouts, now: now)
    }

    private func weekFood(_ summary: WeekSummary) -> [Date: FoodDay] {
        FoodDayMath.week(summary.days.filter { !$0.isFuture }.map(\.date), entries: foodEntries, goals: nutritionGoals,
                         workouts: finishedWorkouts)
    }

    private var todayFood: FoodDay {
        var day = FoodDayMath.day(now, entries: foodEntries, goals: nutritionGoals, workouts: finishedWorkouts)
        day.burned = FoodDayMath.burned(workouts: day.burned, health: health?.burned(on: now))
        return day
    }

    /// A workout belongs to the day it STARTED on (as in History), in the calendar's time zone.
    static func startedOnDay(_ startedAt: Date, of now: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(startedAt, inSameDayAs: now)
    }

    // MARK: Training

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Training")
            if let active = activeWorkouts.first, !active.isDeleted {
                WorkoutResumeCapsule(
                    symbol: active.unfinishedCardio?.activity.symbol ?? "figure.strengthtraining.traditional",
                    detail: StartWorkoutView.resumeDetail(active),
                    startedAt: active.startedAt,
                    elapsedAt: { active.isDeleted ? 0 : active.trainingSeconds(at: $0) },
                    action: resumeActive)
                    .accessibilityIdentifier("resumeWorkout")
            } else {
                upNextPart
            }
        }
    }

    // MARK: Up next (S5, D77)

    private var reading: UpNextReading {
        UpNextReading.make(templates: templates, finished: finishedWorkouts, splitData: splitData,
                           overrideData: overrideData, now: now)
    }

    @ViewBuilder private var upNextPart: some View {
        let reading = reading
        switch reading.suggestion {
        case .template:
            if let template = reading.template {
                TodayUpNextCard(
                    name: template.name,
                    families: MuscleFamily.families(of: WorkoutTemplateService.orderedItems(of: template)
                        .map { $0.exercise?.muscleGroup }),
                    caption: caption(reading),
                    start: { startRequest = WorkoutStartRequest(template: template) },
                    notToday: { notTodayItems(reading) })
            }
        case .restDay:
            TodayRestDayCard { notTodayItems(reading) }
        case .none:
            TodayNoTemplateCard(
                lastWorkout: finishedWorkouts.first { !$0.isDeleted && WorkoutTemplateService.canRepeat($0) },
                repeatLast: {
                    if let last = finishedWorkouts.first(where: { !$0.isDeleted && WorkoutTemplateService.canRepeat($0) }) {
                        startRequest = WorkoutStartRequest(template: nil, repeating: last)
                    }
                },
                startEmpty: { startRequest = WorkoutStartRequest(template: nil) },
                openTrain: onOpenTrain)
        }
    }

    private func caption(_ reading: UpNextReading) -> String {
        if reading.isOverridden { return "Chosen for today" }
        let last = reading.lastRun.map { "Last done " + $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "Not done yet"
        return reading.split == .off ? last : "My split · " + last
    }

    /// "Not today": skip to the next in the order (repeatable), pick any template, or go back to the plan. The choice
    /// lasts for the day and until a workout finishes (`UpNextOverride.isCurrent`).
    @ViewBuilder private func notTodayItems(_ reading: UpNextReading) -> some View {
        let current = reading.activeOverride
        Button("Next in order", systemImage: "forward") {
            // After "Choose template…", Next continues from the chosen template (codex-review-s5 #2).
            overrideData = UpNextOverride.encode(UpNextOverride(madeAt: .now, skip: (current?.skip ?? 0) + 1,
                                                                chosen: current?.chosen))
        }
        .accessibilityIdentifier("todayNextInOrder")
        Menu("Choose template…", systemImage: "list.bullet") {
            ForEach(templates) { template in
                Button(template.name) {
                    overrideData = UpNextOverride.encode(UpNextOverride(madeAt: .now, skip: 0, chosen: template.id))
                }
            }
        }
        .accessibilityIdentifier("todayChooseTemplate")
        if reading.isOverridden {
            Button("Back to plan", systemImage: "arrow.uturn.backward") { overrideData = Data() }
                .accessibilityIdentifier("todayBackToPlan")
        }
    }

    private func resumeActive() {
        if let workout = try? session.resumableWorkout() {
            onWorkoutStarted(workout)
        }
    }

    // MARK: Today's log

    private var todaysLog: some View {
        let today = finishedWorkouts.filter { Self.startedOnDay($0.startedAt, of: now) }
        // In the order eaten; same-minute entries by when they were logged, then by id (a stable order).
        let entries = NutritionMath.entries(foodEntries, on: now)
            .sorted { ($0.loggedAt, $0.createdAt, $0.id.uuidString) < ($1.loggedAt, $1.createdAt, $1.id.uuidString) }
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Today's log")
            // N7 (D82): a scan in flight or failed, first.
            ForEach(visibleScans) { scan in
                ScanPendingCard(scan: scan,
                                loggedEarlier: scan.loggedEarlierID.flatMap { id in foodEntries.first { $0.id == id } },
                                retake: { scans.dismiss(scan.id); showScan = true },
                                retry: { scans.retry(scan.id, client: TerraAccess.client(account), context: modelContext) },
                                manualAdd: { scans.dismiss(scan.id); manualFromScan = true },
                                signIn: { signInFor = scan.id; showSignIn = true },
                                open: { openScan = $0 })
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
            }
            if today.isEmpty && entries.isEmpty {
                if visibleScans.isEmpty {
                    Text("Nothing logged yet today.")
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(look.space.panelPadding)
                        .lookSurface(.panel)
                }
            } else {
                // N5: food by meal, in the day's order, then the day's workouts.
                ForEach(MealSlot.allCases) { meal in
                    let logged = entries.filter { $0.meal == meal }
                    if !logged.isEmpty {
                        TodayMealLog(meal: meal, entries: logged) { entry in
                            if entry.isScan { openScan = entry } else { editingEntry = entry }
                        }
                    }
                }
                if !today.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(today) { workout in
                            Button { onOpenWorkout(workout) } label: { TodayWorkoutRow(workout: workout) }
                                .buttonStyle(.lookPressable)
                                .accessibilityIdentifier("todayWorkout.\(workout.historyTitle)")
                            if workout.id != today.last?.id { Divider().overlay(look.hairline) }
                        }
                    }
                    .lookSurface(.panel)
                }
            }
        }
    }

    /// The scans Today shows: an earlier-day card only while its entry exists (deleted: hidden, back on Undo —
    /// codex-review-n7b R2-S1). The empty state uses the same list (codex-review-n7c).
    private var visibleScans: [FoodScanQueue.Pending] {
        scans.pending.filter { scan in
            scan.loggedEarlierID.map { id in foodEntries.contains { $0.id == id } } ?? true
        }
    }

    /// "Deleted Banana" with Undo (N5): puts the entry back as it was.
    private func deletedToast(_ copy: DeletedEntry) -> some View {
        FoodDeletedToast(copy: copy) {
            do {
                try FoodLog.restore(copy, in: modelContext)
                withAnimation(reduceMotion ? nil : .snappy) { deletedEntry = nil }
            } catch {
                foodFailure = error.localizedDescription
            }
        }
    }
}

/// When Today reads Health's active energy again: each refresh of its `now`, and when reading it is turned on.
private struct BurnedRefresh: Equatable {
    var now: Date
    var on: Bool
}
