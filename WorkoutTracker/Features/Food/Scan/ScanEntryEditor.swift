import SwiftData
import SwiftUI

// Nutrition N7 — a scanned meal or a description, opened from Today: the photo, its name and meal, the totals as the
// hero, then each item — editable (name, portion, weight, calories, macros) or removable — and Add item. Staged edits:
// Cancel and Save (D82: the review screen before Log became this edit screen; D78: plain numbers). Delete with Undo on
// Today, the photo and items coming back with it.

struct ScanEntryEditor: View {
    var entry: FoodEntry
    var onDelete: (DeletedEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.look) private var look
    @State private var name: String
    @State private var meal: MealSlot
    @State private var items: [FoodEstimate.Item]
    @State private var failure: String?
    /// N15: this meal (as on screen) is in My meals — re-read after the bookmark and when the draft changes.
    @State private var mealSaved = false
    /// Read once: after Delete the entry is gone while the sheet slides away, so the body never reads it.
    private let photo: UIImage?
    private let time: Date

    init(entry: FoodEntry, onDelete: @escaping (DeletedEntry) -> Void) {
        self.entry = entry
        self.onDelete = onDelete
        _name = State(initialValue: entry.name)
        _meal = State(initialValue: entry.meal)
        _items = State(initialValue: FoodScan.editable(entry))
        photo = entry.photoData.flatMap(UIImage.init(data:))
        time = entry.loggedAt
    }

    private var totals: Macros { items.reduce(Macros.zero) { $0 + $1.macros } }
    private var canSave: Bool { !items.isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    if let photo {
                        Color.black.overlay { Image(uiImage: photo).resizable().scaledToFill() }
                            .frame(height: 190)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Text(ScanCopy.time(time))
                                    .font(.system(.footnote, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 28)
                                    .background(.black.opacity(0.45), in: Capsule())
                                    .padding(12)
                            }
                            .accessibilityHidden(true)
                    }
                    LookList(separatorInset: 16) {
                        FoodFormField("Name", text: $name, prompt: "e.g. Poke bowl", identifier: "scanEntryName")
                    }
                    WrapLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(MealSlot.allCases) { slot in
                            Chip(slot.label, isSelected: meal == slot) { meal = slot }
                                .accessibilityIdentifier("scanEntryMeal.\(slot.rawValue)")
                        }
                    }
                    MacroSummary(macros: totals)
                    itemList
                    DestructiveRowButton("Delete Entry", action: delete)
                        .accessibilityIdentifier("scanEntryDelete")
                }
                .padding(.horizontal, look.space.margin)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .lookScreenBackground()
            .navigationTitle(name.isEmpty ? "Meal" : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                // N15 (D87): a meal photo saves as ONE meal in My meals, its items with it.
                ToolbarItem(placement: .topBarTrailing) {
                    SaveBookmark(isSaved: mealSaved, saveLabel: "Save to My meals",
                                 removeLabel: "Remove from My meals", identifier: "scanEntrySaveMeal",
                                 action: toggleMeal)
                        .disabled(!canSave && !mealSaved)
                }
                // Its own glass, apart from Save: the bookmark acts at once, Save commits the edits.
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("scanEntrySave")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let index = items.firstIndex(where: { $0.id == id }) {
                    ScanItemEditor(item: $items[index]) { items.removeAll { $0.id == id } }
                }
            }
            .task(id: mealIdentity) { refreshMealSaved() }
            .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private var itemList: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Items", trailing: "\(items.count)")
            LookList(separatorInset: 16) {
                ForEach(items) { item in
                    NavigationLink(value: item.id) { itemRow(item) }
                        .buttonStyle(.lookPressable)
                        .accessibilityIdentifier("scanItem.\(item.name)")
                }
                Button(action: addItem) {
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

    private func itemRow(_ item: FoodEstimate.Item) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name.isEmpty ? "New item" : item.name).font(.system(.body, weight: .semibold))
                    .foregroundStyle(item.name.isEmpty ? look.textSecondary : look.textPrimary)
                Text(itemLine(item)).font(look.font.footnote).foregroundStyle(look.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(TodayFoodCopy.calories(item.calories)) cal")
                .font(look.font.subhead.weight(.semibold)).monospacedDigit().foregroundStyle(look.textPrimary)
            Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// "1 cup · 150 g · P 26 · C 4 · F 4 g" — the portion and weight when known.
    private func itemLine(_ item: FoodEstimate.Item) -> String {
        let amount = [item.portion.isEmpty ? nil : item.portion, item.grams.map { "\(FoodNumber.text($0)) g" }]
            .compactMap(\.self)
        return (amount + [ScanCopy.detail(time: nil, item.macros)]).joined(separator: " · ")
    }

    private func addItem() {
        items.append(FoodEstimate.Item(name: "", portion: "", grams: nil, calories: 0, protein: 0, carbs: 0, fat: 0))
    }

    /// The meal as on screen: its name and its named items (a nameless new item is dropped, as Save drops it).
    private var keptItems: [FoodEstimate.Item] { items.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty } }

    /// What decides whether this meal is in My meals: the name and every item's content.
    private var mealIdentity: [String] {
        [name] + keptItems.map { "\($0.name)|\($0.portion)|\($0.grams ?? -1)|\($0.calories)|\($0.protein)|\($0.carbs)|\($0.fat)" }
    }

    private func refreshMealSaved() {
        mealSaved = FoodSaving.savedMeal(name: name, items: keptItems, in: context) != nil
    }

    private func toggleMeal() {
        do {
            try FoodSaving.toggleMeal(name: name.trimmingCharacters(in: .whitespacesAndNewlines), meal: meal,
                                      items: keptItems, in: context)
            refreshMealSaved()
        } catch {
            failure = error.localizedDescription
        }
    }

    private func save() {
        // A new item left without a name is dropped rather than saved nameless.
        let kept = keptItems
        do {
            try FoodScan.update(entry, name: name, meal: meal, items: kept, in: context)
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

/// One item: its name, portion and weight, then its calories and macros (blank macro = 0); Remove Item at the end.
/// Changes go into the entry's draft; the entry's Save keeps them.
struct ScanItemEditor: View {
    @Binding var item: FoodEstimate.Item
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
    /// The numbers as stored when the editor opened: an unchanged field keeps its exact value, not its rounded text
    /// (codex-review-n7 S3, as Edit entry does).
    @State private var stored: [EditableNumber] = []
    /// N15: this item (as on screen) is in Saved foods.
    @State private var saved = false
    @Environment(\.modelContext) private var context
    @State private var failure: String?

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
        // N15 (D87): each item of a meal photo can be saved on its own.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SaveBookmark(isSaved: saved, saveLabel: "Save to Saved foods", removeLabel: "Remove from Saved foods",
                             identifier: "scanItemSaveFood", action: toggleSaved)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty && !saved)
            }
        }
        .task(id: [name, portion, grams, calories, protein, carbs, fat]) {
            guard loaded else { return }
            saved = FoodSaving.isSaved(current, in: context)
        }
        .alert(FoodCopy.saveFailed, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = item.name
            portion = item.portion
            stored = [EditableNumber(item.grams), EditableNumber(item.calories), EditableNumber(item.protein),
                      EditableNumber(item.carbs), EditableNumber(item.fat)]
            grams = stored[0].text
            calories = stored[1].text
            protein = stored[2].text
            carbs = stored[3].text
            fat = stored[4].text
        }
        .onDisappear { if !removed { apply() } }
    }

    /// Back writes the fields into the draft: an unchanged field keeps its stored value exactly; a number that does not
    /// read keeps the item's value; a blank macro is 0, a blank weight none.
    private func apply() {
        guard stored.count == 5 else { return }
        item = current
    }

    /// The item as the fields read now, by `apply`'s rules — what Back keeps and what the bookmark saves.
    private var current: FoodEstimate.Item {
        guard stored.count == 5 else { return item }
        var out = item
        out.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        out.portion = portion.trimmingCharacters(in: .whitespacesAndNewlines)
        out.grams = ScanItemNumbers.optional(stored[0], grams, keeping: item.grams)
        out.calories = ScanItemNumbers.required(stored[1], calories, keeping: item.calories)
        out.protein = ScanItemNumbers.optional(stored[2], protein, keeping: item.protein) ?? 0
        out.carbs = ScanItemNumbers.optional(stored[3], carbs, keeping: item.carbs) ?? 0
        out.fat = ScanItemNumbers.optional(stored[4], fat, keeping: item.fat) ?? 0
        return out
    }

    private func toggleSaved() {
        do {
            try FoodSaving.toggle(current, in: context)
            saved = FoodSaving.isSaved(current, in: context)
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// The item editor's write-back rules, testable without a view (codex-review-n7 S3).
enum ScanItemNumbers {
    /// Unchanged → the stored value exactly; blank → nil; unreadable → `keeping`.
    static func optional(_ stored: EditableNumber, _ text: String, keeping: Double?) -> Double? {
        switch stored.resolve(text) {
        case .some(let value): value
        case .none: keeping
        }
    }

    /// As `optional`, but blank or unreadable keeps the value (calories are needed).
    static func required(_ stored: EditableNumber, _ text: String, keeping: Double) -> Double {
        optional(stored, text, keeping: keeping) ?? keeping
    }
}
