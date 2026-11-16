import SwiftUI

// Machine settings 01 (D91, proposed): "My settings" — one free-text note per gym machine × exercise ("Seat 4 ·
// chest pad 3 · hurt my elbow at 4"). Current, not history: never in the D23 snapshot, History, an AI prompt or the
// Lock Screen.
//
// These views take the note and closures and store nothing themselves. Today the only caller is the throwaway
// prototype (`MySettingsPrototype.swift`, in-memory notes); if the user approves the design, the real build keeps
// these views and points them at the stored note.

enum MySettingsCopy {
    /// The sheet's title.
    static let title = "My Settings"
    /// The card's "⋯" menu item.
    static let menuItem = "My Settings…"
    /// The row label on the machine page (sentence case, like "Default unit").
    static let label = "My settings"
    /// The first-use chip on the card.
    static let addHint = "Add My Settings"
    /// The machine page's empty row.
    static let addRow = "Add…"
    /// Teaches the format: short settings joined by " · ", and room for a warning.
    static let placeholder = "Seat 4 · pad 2 · elbow hurt at 4"
    static let footer = "Kept for this machine and this exercise only. It isn't part of your workout history."
}

/// The live card's line, right under the machine: the note in full (wraps at every text size, never truncated),
/// aligned with the machine row's glyph. Tapping edits it. Shown only when a note exists.
struct MySettingsCardLine: View {
    var note: String
    var action: () -> Void
    @Environment(\.look) private var look
    /// The machine row's glyph column (`EquipmentRow`), so the two glyphs line up.
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .frame(width: glyphColumn)
                Text(note)
                    .font(look.font.subhead)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "pencil")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MySettingsCopy.label)
        .accessibilityValue(note)
        .accessibilityHint("Edits your settings for this machine")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("mySettings.cardLine")
    }
}

/// The first-use hint: the first time this machine is used for this exercise, a small chip offers to note the
/// setup. Gone once a note exists, or after that first workout.
struct MySettingsAddChip: View {
    var action: () -> Void

    var body: some View {
        HStack {
            Chip(MySettingsCopy.addHint, symbol: "plus", action: action)
                .accessibilityIdentifier("mySettings.addChip")
                .accessibilityHint("Notes your seat, pins and pads for this machine")
            Spacer(minLength: 0)
        }
    }
}

/// The machine page's row for one exercise: "My settings" (with the exercise's name on a station, which keeps one
/// note per exercise), the note in full, or "Add…".
struct MySettingsMachineRow: View {
    /// nil on a machine that serves one exercise.
    var exerciseName: String?
    var note: String?
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exerciseName.map { "\(MySettingsCopy.label) · \($0)" } ?? MySettingsCopy.label)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(note ?? MySettingsCopy.addRow)
                        .font(.system(.body, weight: note == nil ? .semibold : .regular))
                        .foregroundStyle(note == nil ? look.actionText : look.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PanelRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exerciseName.map { "\(MySettingsCopy.label), \($0)" } ?? MySettingsCopy.label)
        .accessibilityValue(note ?? "None")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("mySettings.machineRow.\(exerciseName ?? "single")")
    }
}

/// The editor: one text field. Cancel (or a swipe down) discards the edit; Save keeps it; saving a blank note
/// removes it.
struct MySettingsSheet: View {
    var machineLabel: String
    var exerciseName: String
    var initialNote: String
    var onSave: (String) -> Void
    @State private var draft: String
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    init(machineLabel: String, exerciseName: String, initialNote: String, onSave: @escaping (String) -> Void) {
        self.machineLabel = machineLabel
        self.exerciseName = exerciseName
        self.initialNote = initialNote
        self.onSave = onSave
        _draft = State(initialValue: initialNote)
    }

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(MySettingsCopy.placeholder, text: $draft, axis: .vertical)
                        .lineLimit(2...8)
                        .focused($focused)
                        .accessibilityLabel(MySettingsCopy.title)
                        .accessibilityIdentifier("mySettings.field")
                } header: {
                    Text("\(machineLabel) · \(exerciseName)")
                } footer: {
                    Text(MySettingsCopy.footer)
                }
            }
            .lookGroupedList()
            .navigationTitle(MySettingsCopy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("mySettings.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmed)
                        dismiss()
                    }
                    .disabled(trimmed == initialNote.trimmingCharacters(in: .whitespacesAndNewlines))
                    .accessibilityIdentifier("mySettings.save")
                }
            }
            .onAppear { focused = true }
        }
    }
}
