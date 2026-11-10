import SwiftUI

// Nutrition N7 (MOCK) — a logged photo entry, opened from Today: the photo, its name (option A) and meal, the totals as
// the hero, then each item — editable (name, portion, grams, calories, macros) or removable — and Add item. Staged
// edits: Cancel and Save (D82: the review screen before Log became this edit screen; D78: plain numbers).

struct ScanEntryEditor: View {
    var onDelete: (ScanMockEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var draft: ScanMockEntry
    @State private var mock = FoodScanMock.shared
    private let original: ScanMockEntry

    init(entry: ScanMockEntry, onDelete: @escaping (ScanMockEntry) -> Void) {
        original = entry
        _draft = State(initialValue: entry)
        self.onDelete = onDelete
    }

    private var oneEntry: Bool { mock.grouping == .oneEntry || draft.origin != .photo }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    if let image = draft.image {
                        Color.black.overlay { Image(uiImage: image).resizable().scaledToFill() }
                            .frame(height: 190)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Text(ScanCopy.time(draft.time))
                                    .font(.system(.footnote, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 28)
                                    .background(.black.opacity(0.45), in: Capsule())
                                    .padding(12)
                            }
                            .accessibilityHidden(true)
                    }
                    if oneEntry {
                        LookList(separatorInset: 16) {
                            FoodFormField("Name", text: $draft.name, prompt: "e.g. Poke bowl", identifier: "scanEntryName")
                        }
                    }
                    WrapLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(MealSlot.allCases) { slot in
                            Chip(slot.label, isSelected: draft.meal == slot) { draft.meal = slot }
                                .accessibilityIdentifier("scanEntryMeal.\(slot.rawValue)")
                        }
                    }
                    MacroSummary(macros: draft.totals)
                    items
                    DestructiveRowButton(oneEntry ? "Delete Entry" : "Delete Photo and Items") {
                        mock.delete(original)
                        dismiss()
                        onDelete(original)
                    }
                    .accessibilityIdentifier("scanEntryDelete")
                }
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .lookScreenBackground()
            .navigationTitle(oneEntry ? draft.name : "Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        mock.update(draft)
                        dismiss()
                    }
                    .disabled(draft.items.isEmpty)
                    .accessibilityIdentifier("scanEntrySave")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let index = draft.items.firstIndex(where: { $0.id == id }) {
                    ScanItemEditor(item: $draft.items[index]) {
                        draft.items.remove(at: index)
                    }
                }
            }
        }
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Items", trailing: "\(draft.items.count)")
            LookList(separatorInset: 16) {
                ForEach(draft.items) { item in
                    NavigationLink(value: item.id) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                                Text("\(item.portion) · \(FoodNumber.text(item.grams)) g · \(ScanCopy.detail(time: nil, item.macros))")
                                    .font(look.font.footnote).foregroundStyle(look.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(TodayFoodCopy.calories(item.calories)) cal")
                                .font(look.font.subhead.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(look.textPrimary)
                            Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(look.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.lookPressable)
                    .accessibilityIdentifier("scanItem.\(item.name)")
                }
                Button {
                    let item = ScanMockItem(name: "", portion: "1 serving", grams: 0, calories: 0, protein: 0, carbs: 0, fat: 0)
                    draft.items.append(item)
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.lookPressable)
                .accessibilityIdentifier("scanAddItem")
            }
        }
    }
}

/// One item: its name, portion and grams, then its calories and macros (blank macro = 0); Remove Item at the end.
/// Changes go into the entry's draft; the entry's Save keeps them.
struct ScanItemEditor: View {
    @Binding var item: ScanMockItem
    var onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @State private var name = ""
    @State private var portion = ""
    @State private var grams = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var loaded = false
    /// Removed: the binding's row is gone, so nothing is written back.
    @State private var removed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookList(separatorInset: 16) {
                    FoodFormField("Name", text: $name, prompt: "e.g. Rice", identifier: "scanItemName")
                    FoodFormField("Portion", text: $portion, prompt: "e.g. 1 cup", identifier: "scanItemPortion")
                    FoodFormField("Weight", text: $grams, prompt: "Optional", unit: "g", number: true,
                                  identifier: "scanItemGrams")
                }
                MacroFields(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat, identifier: "scanItem")
                DestructiveRowButton("Remove Item", symbol: "minus.circle") {
                    removed = true
                    dismiss()
                    onRemove()
                }
                .accessibilityIdentifier("scanItemRemove")
            }
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .lookScreenBackground()
        .navigationTitle(name.isEmpty ? "Item" : name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = item.name
            portion = item.portion
            grams = item.grams > 0 ? FoodNumber.text(item.grams) : ""
            calories = FoodNumber.text(item.calories)
            protein = FoodNumber.text(item.protein)
            carbs = FoodNumber.text(item.carbs)
            fat = FoodNumber.text(item.fat)
        }
        .onDisappear { if !removed { apply() } }
    }

    private func apply() {
        item.name = name
        item.portion = portion
        item.grams = FoodNumber.parse(grams) ?? 0
        item.calories = FoodNumber.parse(calories) ?? item.calories
        item.protein = FoodNumber.parse(protein) ?? 0
        item.carbs = FoodNumber.parse(carbs) ?? 0
        item.fat = FoodNumber.parse(fat) ?? 0
    }
}

/// Option B: an item entry opened from Today on its own (it is its own entry): the item editor with Cancel and Save.
struct ScanItemEntrySheet: View {
    var entry: ScanMockEntry
    var itemID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ScanMockEntry

    init(entry: ScanMockEntry, itemID: UUID) {
        self.entry = entry
        self.itemID = itemID
        _draft = State(initialValue: entry)
    }

    var body: some View {
        NavigationStack {
            if let index = draft.items.firstIndex(where: { $0.id == itemID }) {
                ScanItemEditor(item: $draft.items[index]) {
                    draft.items.remove(at: index)
                    FoodScanMock.shared.update(draft)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            // The editor writes into the draft as it disappears; read it on the next turn.
                            dismiss()
                            Task { @MainActor in FoodScanMock.shared.update(draft) }
                        }
                    }
                }
            }
        }
    }
}
