import SwiftData
import SwiftUI

/// Nutrition N10 (the user's choice, 2026-11-11): a day's food page, opened from History's food line (and a food chart's
/// day). That day's fuel card — against the goal in force that day, Burned from its workouts — then its food by meal;
/// each entry opens as on Today (edit, or delete with Undo). In this state the screen exists so the user can see what
/// they ate that day and correct an entry in one tap; the eye lands on the fuel card's figure.
struct DayFoodView: View {
    let day: Date
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Today's page shows Health's Burned as Today does (codex-review-n10 S1); a past day's is its workouts'.
    @Environment(HealthSync.self) private var health: HealthSync?
    @Query(sort: \FoodEntry.loggedAt) private var foodEntries: [FoodEntry]
    @Query private var goals: [NutritionGoal]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var workouts: [Workout]
    @State private var editingEntry: FoodEntry?
    @State private var openScan: FoodEntry?
    @State private var deletedEntry: DeletedEntry?
    @State private var showGoals = false
    @State private var failure: String?
    @State private var now = Date.now

    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: now) }

    /// The day's food; today's Burned as Today shows it (Health's active energy when read).
    private var dayFood: FoodDay {
        var food = FoodDayMath.day(day, entries: foodEntries, goals: goals, workouts: workouts)
        if isToday { food.burned = FoodDayMath.burned(workouts: food.burned, health: health?.burned(on: day)) }
        return food
    }

    var body: some View {
        let food = dayFood
        // In the order eaten, as Today's log.
        let entries = NutritionMath.entries(foodEntries, on: day)
            .sorted { ($0.loggedAt, $0.createdAt, $0.id.uuidString) < ($1.loggedAt, $1.createdAt, $1.id.uuidString) }
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                TodayFuelCard(day: food, isToday: isToday) { showGoals = true }
                if entries.isEmpty {
                    Text("No food logged.")
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(look.space.panelPadding)
                        .lookSurface(.panel)
                } else {
                    ForEach(MealSlot.allCases) { meal in
                        let logged = entries.filter { $0.meal == meal }
                        if !logged.isEmpty {
                            TodayMealLog(meal: meal, entries: logged) { entry in
                                if entry.isScan { openScan = entry } else { editingEntry = entry }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showGoals) { NutritionGoalsView() }
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry) { copy in withAnimation(reduceMotion ? nil : .snappy) { deletedEntry = copy } }
        }
        .sheet(item: $openScan) { entry in
            ScanEntryEditor(entry: entry) { copy in withAnimation(reduceMotion ? nil : .snappy) { deletedEntry = copy } }
        }
        .overlay(alignment: .bottom) {
            if let deletedEntry {
                FoodDeletedToast(copy: deletedEntry) {
                    do {
                        try FoodLog.restore(deletedEntry, in: modelContext)
                        withAnimation(reduceMotion ? nil : .snappy) { self.deletedEntry = nil }
                    } catch {
                        failure = error.localizedDescription
                    }
                }
            }
        }
        .task(id: deletedEntry?.id) {
            // As Today's: the toast leaves after a few seconds; a newer delete cancels this wait.
            guard let shown = deletedEntry?.id else { return }
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard deletedEntry?.id == shown else { return }
            withAnimation(reduceMotion ? nil : .snappy) { deletedEntry = nil }
        }
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .refreshingNow($now)
        // Read again with each refresh of `now` (becoming active, the clock, the time zone), as Today does.
        .task(id: "\(isToday) \(health?.isOn(.readBurned) == true) \(now.timeIntervalSinceReferenceDate)") {
            if isToday { await health?.refreshBurned(on: now) }
        }
    }
}
