import SwiftUI

// Nutrition N3: the small editors behind Personal details and Nutrition goals (the user chose "tap a number to edit",
// 2026-11-09). Each is one task with staged edits: Cancel and Save.

/// One number: a weight, a height in cm, the calories or a macro's grams.
struct NumberEditorSheet: View {
    var title: String
    var unit: String
    var initial: Double?
    var fractionDigits = 0
    var range: ClosedRange<Double>
    var fieldID: String
    var onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var shown = ""
    @FocusState private var focused: Bool

    private var value: Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")).flatMap { range.contains($0) ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(title, text: $text)
                            .keyboardType(fractionDigits > 0 ? .decimalPad : .numberPad)
                            .focused($focused)
                            .accessibilityIdentifier(fieldID)
                        Text(unit).foregroundStyle(.secondary)
                    }
                }
            }
            .lookGroupedList()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Unchanged: nothing to save (no duplicate weight entry, no typed-over goal).
                        if text != shown, let value { onSave(value) }
                        dismiss()
                    }
                    .disabled(value == nil)
                    .accessibilityIdentifier("detailEditorSave")
                }
            }
            .onAppear {
                text = initial.map { $0.formatted(.number.precision(.fractionLength(0...max(fractionDigits, 2))).grouping(.never)) } ?? ""
                shown = text
                focused = true
            }
        }
        .presentationDetents([.medium])
    }
}

/// Height: centimetres, or feet and inches. Edits a stored height in the unit it was entered in, at full precision; a new
/// one in the app's units. An unchanged Save changes nothing (D52: entered values are never rewritten —
/// codex-review-n3).
struct HeightEditorSheet: View {
    var initialValue: Double?
    var initialUnit: HeightUnit?
    var usCustomary: Bool
    var onSave: (Double, HeightUnit) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cm = ""
    @State private var feet = ""
    @State private var inches = ""
    @State private var shown: [String] = []

    private var unit: HeightUnit { HeightFields.unit(stored: initialUnit, usCustomary: usCustomary) }
    private var result: (Double, HeightUnit)? {
        HeightFields.parse(cm: cm, feet: feet, inches: inches, unit: unit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if unit == .inches {
                        // One row per field: side by side, each field stretched and its unit landed mid-row.
                        HStack {
                            TextField("Feet", text: $feet).keyboardType(.numberPad).accessibilityIdentifier("heightFeet")
                            Text("ft").foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField("Inches", text: $inches).keyboardType(.decimalPad).accessibilityIdentifier("heightInches")
                            Text("in").foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            TextField("Height", text: $cm).keyboardType(.decimalPad).accessibilityIdentifier("heightCm")
                            Text("cm").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .lookGroupedList()
            .navigationTitle("Height")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let result, let save = HeightFields.toSave(fields: [cm, feet, inches], shown: shown,
                                                                     parsed: result) {
                            onSave(save.0, save.1)
                        }
                        dismiss()
                    }
                    .disabled(result == nil)
                    .accessibilityIdentifier("detailEditorSave")
                }
            }
            .onAppear {
                if let initialValue {
                    (cm, feet, inches) = HeightFields.fields(value: initialValue, unit: unit)
                }
                shown = [cm, feet, inches]
            }
        }
        .presentationDetents([.medium])
    }
}

/// The height editor's arithmetic, pure so it is unit-tested (codex-review-n3 #3): a stored height is edited in its own
/// unit at full precision, and an unchanged Save writes nothing.
enum HeightFields {
    /// A stored height keeps its unit whatever the app's units are now; a new one takes the app's units.
    static func unit(stored: HeightUnit?, usCustomary: Bool) -> HeightUnit {
        stored ?? (usCustomary ? .inches : .cm)
    }

    static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }

    /// The fields as shown for a stored value: (cm, feet, inches).
    static func fields(value: Double, unit: HeightUnit) -> (String, String, String) {
        switch unit {
        case .cm: return (text(value), "", "")
        case .inches:
            let ft = (value / 12).rounded(.down)
            return ("", text(ft), text(value - ft * 12))
        }
    }

    static func parse(cm: String, feet: String, inches: String, unit: HeightUnit) -> (Double, HeightUnit)? {
        let number = { (text: String) in Double(text.replacingOccurrences(of: ",", with: ".")) }
        switch unit {
        case .inches:
            guard let ft = number(feet), let inch = number(inches.isEmpty ? "0" : inches),
                  ft >= 0, inch >= 0, inch < 12 else { return nil }
            let total = ft * 12 + inch
            return (40...100).contains(total) ? (total, .inches) : nil
        case .cm:
            guard let value = number(cm), (100...250).contains(value) else { return nil }
            return (value, .cm)
        }
    }

    /// What Save writes: nothing when the fields are as shown.
    static func toSave(fields: [String], shown: [String], parsed: (Double, HeightUnit)) -> (Double, HeightUnit)? {
        fields == shown ? nil : parsed
    }
}

struct BirthDateEditorSheet: View {
    var initial: Date?
    var onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date of birth", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("birthDatePicker")
            }
            .lookGroupedList()
            .navigationTitle("Date of birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(date); dismiss() }.accessibilityIdentifier("detailEditorSave")
                }
            }
            .onAppear { if let initial { date = initial } }
        }
        .presentationDetents([.medium, .large])
    }
}

extension BiologicalSex {
    /// Personal details' names (approved 2026-11-09).
    var label: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .unspecified: "Prefer not to say"
        }
    }
}

extension ActivityLevel {
    var label: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Light"
        case .moderate: "Moderate"
        case .veryActive: "Very active"
        case .extraActive: "Extra active"
        }
    }
}

extension WeightGoal {
    var label: String {
        switch self {
        case .lose: "Lose weight"
        case .maintain: "Maintain"
        case .gain: "Gain weight"
        }
    }
}

/// How Personal details write the user's display of a height and weight (as entered, D52).
enum DetailFormat {
    static func weight(_ entry: BodyWeightEntry) -> String {
        "\(entry.value.formatted(.number.precision(.fractionLength(0...1)))) \(entry.unit.rawValue)"
    }

    static func height(value: Double, unit: HeightUnit) -> String {
        switch unit {
        case .cm:
            return "\(value.formatted(.number.precision(.fractionLength(0...1)))) cm"
        case .inches:
            let total = Int(value.rounded())
            return "\(total / 12) ft \(total % 12) in"
        }
    }
}
