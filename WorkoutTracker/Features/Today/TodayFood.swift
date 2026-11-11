import SwiftData
import SwiftUI

// Nutrition N5: Today's food parts — the fuel card, the food in the day rings, the day's log by meal, and editing or
// deleting a logged entry. Design: the approved prototype (tag design/soft-approved-2026-11-07,
// Screens/Soft/SoftTodayTop.swift — `SoftFuelCard`, `DayRing`; SoftTodayScreen.swift — today's log).

extension FoodDay.Macro {
    var kind: MacroKind {
        switch self {
        case .protein: .protein
        case .carbs: .carbs
        case .fat: .fat
        }
    }
}

enum TodayFoodCopy {
    static func calories(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    static func grams(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    /// A logged entry's name; a Manual Add without one reads as the button that made it.
    static func name(of entry: FoodEntry) -> String { entry.name.isEmpty ? "Manual Add" : entry.name }
}

// MARK: - Fuel card

/// The day's food against its goal (D71). What's left is the headline (over the goal: how much over); Eaten and Burned
/// sit beside it; one bar fills toward the goal in the macros' calorie shares; protein — the lifter's macro — leads
/// with grams to go, carbs and fat compact. Burned is shown and never changes the goal or what is left. Without a goal
/// the card shows what was eaten and asks to set goals (N3; the user, 2026-11-09).
///
/// The eye lands on the left/over figure (the screen's one hero number).
struct TodayFuelCard: View {
    var day: FoodDay
    /// N10: a past day (the day's food page) says "cal under … of 2,288 goal" — nothing is left of a day gone by.
    var isToday = true
    var setGoals: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let goal = day.goal {
                headline(goal: goal)
                FuelBar(day: day)
                VStack(spacing: 12) {
                    protein(goal: goal)
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))
                    layout {
                        compact(.carbs, goal: goal)
                        compact(.fat, goal: goal)
                    }
                }
            } else {
                noGoal
            }
        }
        .padding(look.space.panelPadding)
        .lookSurface(.panel)
    }

    private func headline(goal: DayGoal) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TodayFoodCopy.calories(day.isOver ? day.over ?? 0 : day.left ?? 0))
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText())
                    Text(day.isOver ? "cal over" : (isToday ? "cal left" : "cal under"))
                        .font(look.font.headline.weight(.medium))
                        .foregroundStyle(look.textSecondary)
                }
                Text("of \(TodayFoodCopy.calories(goal.calories)) \(isToday ? "today" : "goal")")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
            }
            .accessibilityElement(children: .combine)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                stat("Eaten", day.eaten.calories, id: "todayEaten")
                stat("Burned", day.burned, id: "todayBurned")
            }
        }
    }

    /// Without a goal: what was eaten, and Burned beside it (D71 — burned is shown whether or not there is a goal;
    /// codex-review-n5), then the invitation.
    private var noGoal: some View {
        VStack(alignment: .leading, spacing: 14) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TodayFoodCopy.calories(day.eaten.calories))
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                    Text("cal eaten").font(look.font.headline.weight(.medium)).foregroundStyle(look.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("todayEaten")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                stat("Burned", day.burned, id: "todayBurned")
            }
            Button("Set your goals", action: setGoals)
                .buttonStyle(.lookSecondary)
                .accessibilityIdentifier("todaySetGoals")
        }
    }

    private func stat(_ label: String, _ value: Double, id: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(look.font.footnote).foregroundStyle(look.textSecondary)
            Text(TodayFoodCopy.calories(value))
                .font(look.font.subhead.weight(.semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    /// Protein leads: the figure, the goal, and how far to go.
    private func protein(goal: DayGoal) -> some View {
        let eaten = day.eatenGrams(.protein), target = goal.proteinGrams, toGo = day.toGo(.protein) ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                MacroName(macro: .protein)
                Spacer(minLength: 8)
                Text(TodayFoodCopy.grams(eaten)).font(look.font.headline).monospacedDigit()
                    .foregroundStyle(look.textPrimary)
                Text("/ \(TodayFoodCopy.grams(target)) g").font(look.font.subhead).foregroundStyle(look.textSecondary)
            }
            ProgressLine(progress: target > 0 ? eaten / target : 0, tint: MacroKind.protein.color, height: 6)
            Text(toGo < 0.5 ? "Goal reached" : "\(TodayFoodCopy.grams(toGo)) g to go")
                .font(look.font.footnote.weight(.medium)).foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func compact(_ macro: FoodDay.Macro, goal: DayGoal) -> some View {
        let eaten = day.eatenGrams(macro), target = goal.grams(macro)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                MacroName(macro: macro.kind, compact: true)
                Spacer(minLength: 4)
                Text(TodayFoodCopy.grams(eaten)).font(look.font.subhead.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(look.textPrimary)
                Text("/\(TodayFoodCopy.grams(target)) g").font(look.font.caption).foregroundStyle(look.textSecondary)
            }
            ProgressLine(progress: target > 0 ? eaten / target : 0, tint: macro.kind.color, height: 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A macro's name with its glyph in its hue (the hue on the icon only, never the text — D67).
private struct MacroName: View {
    var macro: MacroKind
    var compact = false
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: macro.symbol).font(look.font.caption.weight(.bold)).foregroundStyle(macro.color)
            Text(macro.name)
                .font((compact ? look.font.footnote : look.font.subhead).weight(.semibold))
                .foregroundStyle(look.textPrimary)
        }
    }
}

/// One bar toward the goal, in the three macros' calorie shares of what was eaten (neutral when only calories were
/// logged).
private struct FuelBar: View {
    var day: FoodDay
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shares = day.macroShares
        let parts: [(Double, Color)] = shares.protein + shares.carbs + shares.fat > 0
            ? [(shares.protein, MacroKind.protein.color), (shares.carbs, MacroKind.carbs.color), (shares.fat, MacroKind.fat.color)]
            : [(1, look.textSecondary)]
        GeometryReader { geo in
            let filled = geo.size.width * day.fill
            HStack(spacing: 0) {
                ForEach(parts.indices, id: \.self) { index in
                    Rectangle().fill(parts[index].1).frame(width: max(0, filled * parts[index].0))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(look.ringTrack)
            .clipShape(Capsule())
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: day.fill)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

private struct ProgressLine: View {
    var progress: Double
    var tint: Color
    var height: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(look.ringTrack)
                if progress > 0 {
                    Capsule().fill(tint).frame(width: max(height, geo.size.width * min(1, progress)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - The day ring's food

/// The calorie arc of a day ring: fills toward the day's goal in the protein · carbs · fat shares of what was eaten
/// (real per-entry macros); neutral when only calories were logged.
struct DayRingFood: View {
    var day: FoodDay
    var width: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        let shares = day.macroShares
        let fill = day.fill
        ZStack {
            if shares.protein + shares.carbs + shares.fat > 0 {
                arc(0, fill * shares.protein, MacroKind.protein.color)
                arc(fill * shares.protein, fill * (shares.protein + shares.carbs), MacroKind.carbs.color)
                arc(fill * (shares.protein + shares.carbs), fill, MacroKind.fat.color)
            } else {
                arc(0, fill, look.textSecondary)
            }
        }
    }

    private func arc(_ from: Double, _ to: Double, _ color: Color) -> some View {
        Circle()
            .trim(from: from, to: max(from, to))
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}

// MARK: - Today's log

/// One meal of today's log: its name and calories, then each entry (tap to edit).
struct TodayMealLog: View {
    var meal: MealSlot
    var entries: [FoodEntry]
    var edit: (FoodEntry) -> Void
    @Environment(\.look) private var look

    var body: some View {
        let total = entries.reduce(Macros.zero) { $0 + NutritionMath.totals(of: $1) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(meal.label).font(look.font.headline).foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                Text("\(TodayFoodCopy.calories(total.calories)) cal")
                    .font(look.font.subhead).monospacedDigit().foregroundStyle(look.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            // On the header, not the panel: a container's identifier would hide its rows' (`todayEntry.…`).
            .accessibilityIdentifier("todayMeal.\(meal.rawValue)")
            ForEach(entries) { entry in
                Divider().overlay(look.hairline).padding(.leading, 16)
                // N7: a scanned meal or a description shows its photo and opens on its items.
                Button { edit(entry) } label: {
                    if entry.isScan { ScanEntryRow(entry: entry) } else { TodayEntryRow(entry: entry) }
                }
                .buttonStyle(.lookPressable)
                .accessibilityIdentifier("todayEntry.\(TodayFoodCopy.name(of: entry))")
            }
        }
        .lookSurface(.panel)
    }
}

/// An entry: its name, how much and its macros; its calories trailing.
struct TodayEntryRow: View {
    var entry: FoodEntry
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let totals = NutritionMath.totals(of: entry)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(TodayFoodCopy.name(of: entry)).font(look.font.body.weight(.semibold))
                    .foregroundStyle(look.textPrimary)
                Text(detail(totals)).font(look.font.footnote).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(TodayFoodCopy.calories(totals.calories)) cal")
                .font(look.font.subhead.weight(.semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    /// "1.5 × 1 jar · P 33 · C 78 · F 14 g"; a calories-only entry shows only its amount.
    private func detail(_ totals: Macros) -> String {
        let serving = ServingText.format(value: entry.servingValue, unit: entry.servingUnit, grams: entry.servingGrams)
        let amount = entry.servings == 1 ? serving : "\(FoodNumber.text(entry.servings)) × \(serving)"
        guard totals.proteinGrams + totals.carbsGrams + totals.fatGrams > 0 else { return amount }
        let grams = { TodayFoodCopy.grams($0) }
        return "\(amount) · P \(grams(totals.proteinGrams)) · C \(grams(totals.carbsGrams)) · F \(grams(totals.fatGrams)) g"
    }
}

// MARK: - Edit a logged entry

/// N5 (moved from N4, the user 2026-11-10): change a logged entry's servings, meal or numbers per serving, or delete it
/// (with Undo on Today). Staged edits: Cancel and Save. An unchanged number keeps its stored value exactly
/// (`EditableNumber`, codex-review-n4).
struct EditEntrySheet: View {
    var entry: FoodEntry
    var onDelete: (DeletedEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var meal: MealSlot
    @State private var servings: Double
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var failure: String?
    private let stored: [EditableNumber]
    /// Read once: after Delete the entry is gone while the sheet slides away, so the body never reads it.
    private let title: String
    private let servingText: String

    init(entry: FoodEntry, onDelete: @escaping (DeletedEntry) -> Void) {
        self.entry = entry
        self.onDelete = onDelete
        title = TodayFoodCopy.name(of: entry)
        servingText = ServingText.format(value: entry.servingValue, unit: entry.servingUnit, grams: entry.servingGrams)
        let stored = [EditableNumber(entry.calories), EditableNumber(entry.proteinGrams),
                      EditableNumber(entry.carbsGrams), EditableNumber(entry.fatGrams)]
        self.stored = stored
        _meal = State(initialValue: entry.meal)
        _servings = State(initialValue: entry.servings)
        _calories = State(initialValue: stored[0].text)
        _protein = State(initialValue: stored[1].text)
        _carbs = State(initialValue: stored[2].text)
        _fat = State(initialValue: stored[3].text)
    }

    /// Calories are needed; a blank macro is 0 (as Manual Add stores it).
    private var numbers: (Double, Double, Double, Double)? {
        guard let calories = stored[0].resolve(calories) ?? nil, let protein = stored[1].resolve(protein),
              let carbs = stored[2].resolve(carbs), let fat = stored[3].resolve(fat) else { return nil }
        return (calories, protein ?? 0, carbs ?? 0, fat ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    WrapLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(MealSlot.allCases) { slot in
                            Chip(slot.label, isSelected: meal == slot) { meal = slot }
                                .accessibilityIdentifier("editEntryMeal.\(slot.rawValue)")
                        }
                    }
                    LookList(separatorInset: 16) {
                        servingsRow
                        LookRow("Serving", value: servingText, showsChevron: false)
                    }
                    VStack(alignment: .leading, spacing: look.space.header) {
                        SectionHeader("Per serving")
                        MacroFields(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat,
                                    identifier: "editEntry")
                    }
                    DestructiveRowButton("Delete Entry", action: delete)
                        .accessibilityIdentifier("editEntryDelete")
                }
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .lookScreenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(numbers == nil)
                        .accessibilityIdentifier("editEntrySave")
                }
            }
            .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    @ViewBuilder private var servingsRow: some View {
        let stepper = HStack(spacing: 10) {
            step("minus", label: "Fewer servings", enabled: servings > 0.5) { servings = max(0.5, servings - 0.5) }
            Text(FoodNumber.text(servings)).font(look.font.statNumber).monospacedDigit().frame(minWidth: 44)
                .accessibilityIdentifier("editEntryServings")
            step("plus", label: "More servings", enabled: true) { servings += 0.5 }
        }
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text("Servings").font(.system(.body, weight: .medium)).foregroundStyle(look.textPrimary)
                stepper
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LookRow("Servings", showsChevron: false) { stepper }
        }
    }

    private func step(_ symbol: String, label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(width: 44, height: 44)
                .background(look.ground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }

    private func save() {
        guard let numbers else { return }
        do {
            try FoodLog.update(entry, servings: servings, meal: meal, calories: numbers.0, proteinGrams: numbers.1,
                               carbsGrams: numbers.2, fatGrams: numbers.3, in: context)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }

    private func delete() {
        do {
            let copy = try FoodLog.delete(entry, in: context)
            dismiss()
            onDelete(copy)
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// "Deleted Banana" with Undo (N5), over the bottom of Today and of a day's food page (N10).
struct FoodDeletedToast: View {
    var copy: DeletedEntry
    var undo: () -> Void
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Text("Deleted \(copy.name.isEmpty ? "Manual Add" : copy.name)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.onAction)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("todayDeletedToast")
            Button("Undo", action: undo)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(look.onAction)
                .frame(minHeight: 44)
                .accessibilityIdentifier("todayUndoDelete")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
        .background(look.action, in: Capsule())
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, 72)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
}
