import SwiftData
import SwiftUI

/// Nutrition N9 — Profile → Goals & tracking → Body weight: the latest weight as the hero, Log weight, and every entry
/// (tap to change or delete). When the latest weight is more than about 2 kg from the one the nutrition goal was
/// calculated at, it offers Recalculate (the ticket) instead of moving the goal with every day's weigh-in.
///
/// The eye lands on the latest weight; Log weight is the one primary command.
struct BodyWeightView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.look) private var look
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var weights: [BodyWeightEntry]
    @Query private var goals: [NutritionGoal]
    @Query private var allPreferences: [AppPreferences]
    @State private var sheet: WeightSheet?
    @State private var failure: String?

    enum WeightSheet: Identifiable {
        case new
        case edit(BodyWeightEntry)
        var id: String {
            switch self {
            case .new: "new"
            case .edit(let entry): entry.id.uuidString
            }
        }
    }

    private var latestGoal: NutritionGoal? {
        goals.max { ($0.effectiveFrom, $0.createdAt, $0.id.uuidString) < ($1.effectiveFrom, $1.createdAt, $1.id.uuidString) }
    }

    /// New entries use the latest logged entry's unit, else the app's unit system (N9b: a weight read from Health is in
    /// the unit system, which says nothing about the user's own choice).
    private var unit: WeightUnit {
        weights.first(where: { $0.source == .app })?.unit
            ?? (AppUnitSystem.resolve(preference: AppPreferences.canonical(of: allPreferences)?.unitPreference) == .usCustomary
                ? .lb : .kg)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    LookNavTitle("Body weight")
                    latest
                    if BodyWeightLog.goalNeedsRecalculating(goal: latestGoal, latest: weights.first) { recalculate }
                    if !weights.isEmpty { history }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            PrimaryButton("Log weight") { sheet = .new }
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 10)
                .accessibilityIdentifier("bodyWeightLog")
        }
        .lookScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .new:
                LogWeightSheet(entry: nil, unit: unit, start: weights.first.map { $0.unit == unit ? $0.value : nil } ?? nil)
            case .edit(let entry):
                LogWeightSheet(entry: entry, unit: entry.unit, start: entry.value)
            }
        }
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    @ViewBuilder private var latest: some View {
        if let entry = weights.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.value.formatted(.number.precision(.fractionLength(0...1))))
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                    Text(entry.unit.rawValue).font(look.font.headline.weight(.medium)).foregroundStyle(look.textSecondary)
                }
                Text(entry.measuredAt.formatted(date: .abbreviated, time: .omitted))
                    .font(look.font.subhead).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(look.space.panelPadding)
            .lookSurface(.panel)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("bodyWeightLatest")
        } else {
            EmptyStateView(symbol: "scalemass", title: "No weight yet", message: "Log your weight to follow it over time.")
        }
    }

    /// "Your goals use 80 kg." with Recalculate (N3's calculation, from the latest weight).
    private var recalculate: some View {
        let goalKg = latestGoal?.weightKg ?? 0
        let shown = unit == .kg ? goalKg : WeightMath.convert(goalKg, from: .kg, to: .lb)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Your nutrition goals use \(shown.formatted(.number.precision(.fractionLength(0...1)))) \(unit.rawValue).")
                .font(look.font.subhead).foregroundStyle(look.textPrimary)
            Button("Recalculate goals") {
                do { try BodyWeightLog.recalculateGoal(in: context) } catch { failure = error.localizedDescription }
            }
            .buttonStyle(.lookSecondary)
            .accessibilityIdentifier("bodyWeightRecalculate")
        }
        .padding(look.space.panelPadding)
        .lookSurface(.panel)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("History")
            LookList(separatorInset: 16) {
                ForEach(weights) { entry in
                    // N9b: a weight read from Health is Health's — shown, not edited here (change it in Health), and
                    // read by VoiceOver as one line: time, "Apple Health", weight.
                    if entry.source == .health {
                        LookRow(entry.measuredAt.formatted(date: .abbreviated, time: .shortened), subtitle: "Apple Health",
                                value: DetailFormat.weight(entry), showsChevron: false, action: nil)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("bodyWeightEntry.\(DetailFormat.weight(entry))")
                    } else {
                        LookRow(entry.measuredAt.formatted(date: .abbreviated, time: .shortened),
                                value: DetailFormat.weight(entry)) { sheet = .edit(entry) }
                            .accessibilityIdentifier("bodyWeightEntry.\(DetailFormat.weight(entry))")
                    }
                }
            }
        }
    }
}

/// Log weight (the prototype's sheet): the figure big, ± steps in the entry's unit, the time, Save; editing adds
/// Delete. Staged: Cancel discards.
struct LogWeightSheet: View {
    var entry: BodyWeightEntry?
    var unit: WeightUnit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value: Double
    @State private var text: String
    @State private var date: Date
    @State private var failure: String?
    /// Read once: after Delete the entry is gone while the sheet slides away.
    private let isEditing: Bool
    /// The figure the sheet opened with: unchanged text saves it exactly — a time-only edit never rounds the stored
    /// weight (D52; codex-review-n9a).
    private let stored: EditableNumber

    init(entry: BodyWeightEntry?, unit: WeightUnit, start: Double?) {
        self.entry = entry
        self.unit = unit
        isEditing = entry != nil
        let initial = start ?? (unit == .kg ? 70 : 155)
        stored = EditableNumber(initial)
        _value = State(initialValue: initial)
        _text = State(initialValue: stored.text)
        _date = State(initialValue: entry?.measuredAt ?? .now)
    }

    private var typed: Double? {
        (stored.resolve(text) ?? nil).flatMap { BodyWeightLog.range(for: unit).contains($0) ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("Weight", text: $text)
                            .font(look.font.heroNumber)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .accessibilityIdentifier("logWeightValue")
                            .onChange(of: text) { _, new in if let number = stored.resolve(new) ?? nil { value = number } }
                        Text(unit.rawValue).font(look.font.headline.weight(.medium)).foregroundStyle(look.textSecondary)
                    }
                    .foregroundStyle(look.textPrimary)
                    .padding(.top, 12)
                    HStack(spacing: 16) {
                        step("minus", label: "Less") { change(by: -BodyWeightLog.step(for: unit)) }
                        step("plus", label: "More") { change(by: BodyWeightLog.step(for: unit)) }
                    }
                    LookList {
                        DatePicker("Time", selection: $date, in: ...Date.now)
                            .font(.system(.body, weight: .medium))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 50)
                    }
                    if isEditing {
                        DestructiveRowButton("Delete Weight", action: delete)
                            .accessibilityIdentifier("logWeightDelete")
                    }
                }
                .padding(.horizontal, look.space.margin)
            }
            .scrollDismissesKeyboard(.interactively)
            .lookScreenBackground()
            .navigationTitle(isEditing ? "Edit weight" : "Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(typed == nil)
                        .accessibilityIdentifier("logWeightSave")
                }
            }
            .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func change(by delta: Double) {
        let next = ((value + delta) * 10).rounded() / 10
        guard BodyWeightLog.range(for: unit).contains(next) else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            value = next
            text = FoodNumber.text(next)
        }
    }

    private func step(_ symbol: String, label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(.title3, weight: .semibold)).foregroundStyle(look.textPrimary)
                .frame(width: 64, height: 52)
                .background(look.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(look.hairline) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func save() {
        guard let typed else { return }
        do {
            if let entry {
                try BodyWeightLog.update(entry, value: typed, unit: unit, at: date, in: context)
            } else {
                try BodyWeightLog.log(value: typed, unit: unit, at: date, in: context)
            }
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }

    private func delete() {
        guard let entry else { return }
        do {
            try BodyWeightLog.delete(entry, in: context)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}
