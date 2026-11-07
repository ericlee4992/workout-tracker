import Combine
import SwiftData
import SwiftUI
import UIKit

// Soft redesign S2 (D68): the Today tab — the first tab. Phase 1 shows its training parts: the week as day
// rings (a workout mark inside on days trained), the Training card (Resume, or the template up next with Start,
// and Start Lifting / Start Cardio), and today's workouts. The food parts — calories filling the rings, the fuel
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
    @State private var showingCardioPicker = false
    @State private var titleInBar = false
    /// The screen's "now", one snapshot for the header, the week and the log. Refreshed at the local day boundary,
    /// on a clock or time-zone change and when the app becomes active, so Today never keeps showing yesterday on a
    /// screen left open past midnight (codex-review-s2 #2).
    @State private var now = Date.now
    @Environment(\.scenePhase) private var scenePhase

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
            .onReceive(Self.clockChanges) { _ in now = .now }
            .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
            .sheet(isPresented: $showingCardioPicker) {
                CardioActivityPicker { choice in
                    showingCardioPicker = false
                    startRequest = WorkoutStartRequest(template: nil, cardioActivity: choice.activity)
                }
            }
        }
    }

    private var weekSummary: WeekSummary {
        WeekSummaryMath.summary(of: finishedWorkouts.compactMap(WeekSummaryInput.init(workout:)), now: now)
    }

    /// The day boundary (`NSCalendarDayChanged`), a clock change and a time-zone change, on the main run loop.
    private static var clockChanges: AnyPublisher<Notification, Never> {
        let center = NotificationCenter.default
        return Publishers.MergeMany(
            center.publisher(for: .NSCalendarDayChanged),
            center.publisher(for: UIApplication.significantTimeChangeNotification),
            center.publisher(for: .NSSystemTimeZoneDidChange))
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
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
                if let next = upNext {
                    TodayUpNextCard(name: next.template.name,
                                    families: MuscleFamily.families(of: WorkoutTemplateService.orderedItems(of: next.template)
                                        .map { $0.exercise?.muscleGroup }),
                                    lastRun: next.lastRun,
                                    start: { startRequest = WorkoutStartRequest(template: next.template) })
                } else {
                    TodayNoTemplateRow(action: onOpenTrain)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { startCapsules }
                    VStack(spacing: 12) { startCapsules }
                }
            }
        }
    }

    @ViewBuilder private var startCapsules: some View {
        StartCapsule(title: "Start Lifting", symbol: "figure.strengthtraining.traditional") {
            startRequest = WorkoutStartRequest(template: nil)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.workoutStart, trigger: activeWorkouts.count)
        .accessibilityIdentifier("startEmptyWorkout")
        StartCapsule(title: "Start Cardio", symbol: "figure.run") { showingCardioPicker = true }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("startCardio")
    }

    /// The template done longest ago leads (a never-run template counts as longest ago; ties by name).
    private var upNext: (template: WorkoutTemplate, lastRun: Date?)? {
        let stats = TemplateStats.byTemplate(finishedWorkouts)
        return templates
            .map { (template: $0, lastRun: stats[$0.id]?.lastRun) }
            .min { lhs, rhs in
                switch (lhs.lastRun, rhs.lastRun) {
                case (nil, nil): lhs.template.name < rhs.template.name
                case (nil, _): true
                case (_, nil): false
                case let (l?, r?): l < r
                }
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
