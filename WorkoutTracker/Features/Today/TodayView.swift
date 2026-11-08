import Combine
import SwiftData
import SwiftUI
import UIKit

// Soft redesign S2 (D68): the Today tab — the first tab. Phase 1 shows its training parts: the week as day
// rings (a workout mark inside on days trained), the Training card (Resume, or the template up next with Start —
// S5/D77: learned from the user's order or their split, with "Not today"; without templates the last workout with
// Repeat and Start workout; Start Lifting / Start Cardio live in Train only), and today's workouts. The food parts — calories filling the rings, the fuel
// card, the food log and the Log food pill — arrive with nutrition N5; nothing ships to testers before then (D76).
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Today", subtitle: WorkoutDates.homeSubtitle(now))
                    TodayWeekRings(summary: weekSummary)
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
            .lookScreenBackground()
            .exercisesInlineTitle("Today", visible: titleInBar)
            .workoutStartFlow(request: $startRequest, gym: selectedGym, onWorkoutStarted: onWorkoutStarted)
            .refreshingNow($now)
        }
    }

    private var weekSummary: WeekSummary {
        WeekSummaryMath.summary(of: finishedWorkouts.compactMap(WeekSummaryInput.init(workout:)), now: now)
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
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Today's log")
            if today.isEmpty {
                Text("Nothing logged yet today.")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(look.space.panelPadding)
                    .lookSurface(.panel)
            } else {
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
