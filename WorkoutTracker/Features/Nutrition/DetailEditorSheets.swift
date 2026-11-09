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
                        if let value { onSave(value); dismiss() }
                    }
                    .disabled(value == nil)
                    .accessibilityIdentifier("detailEditorSave")
                }
            }
            .onAppear {
                text = initial.map { $0.formatted(.number.precision(.fractionLength(0...fractionDigits)).grouping(.never)) } ?? ""
                focused = true
            }
        }
        .presentationDetents([.medium])
    }
}

/// Height: centimetres, or feet and inches (by the app's unit setting).
struct HeightEditorSheet: View {
    var usCustomary: Bool
    var initialCm: Double?
    var onSave: (Double, HeightUnit) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cm = ""
    @State private var feet = ""
    @State private var inches = ""

    private var result: (Double, HeightUnit)? {
        if usCustomary {
            guard let ft = Double(feet), let inch = Double(inches.isEmpty ? "0" : inches), ft >= 0, inch >= 0, inch < 12
            else { return nil }
            let total = ft * 12 + inch
            return (40...100).contains(total) ? (total, .inches) : nil
        }
        guard let value = Double(cm.replacingOccurrences(of: ",", with: ".")), (100...250).contains(value) else { return nil }
        return (value, .cm)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if usCustomary {
                        HStack {
                            TextField("Feet", text: $feet).keyboardType(.numberPad).accessibilityIdentifier("heightFeet")
                            Text("ft").foregroundStyle(.secondary)
                            TextField("Inches", text: $inches).keyboardType(.numberPad).accessibilityIdentifier("heightInches")
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
                    Button("Save") { if let result { onSave(result.0, result.1); dismiss() } }
                        .disabled(result == nil)
                        .accessibilityIdentifier("detailEditorSave")
                }
            }
            .onAppear {
                guard let initialCm else { return }
                if usCustomary {
                    let total = (initialCm / 2.54).rounded()
                    feet = "\(Int(total) / 12)"
                    inches = "\(Int(total) % 12)"
                } else {
                    cm = initialCm.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
                }
            }
        }
        .presentationDetents([.medium])
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
