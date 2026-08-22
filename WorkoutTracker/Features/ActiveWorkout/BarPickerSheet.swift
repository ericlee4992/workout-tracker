import SwiftUI

// Barbell ticket 03 — picking the bar an entry is loaded on (D39–D40).
//
// The list is grouped by unit and the two groups are *different bars*, not the
// same bar shown twice: a 20 kg bar is not a 45 lb bar (20 kg is 44.09 lb), and
// picking one sets the row's unit rather than converting anything. That is the
// whole reason the kg/lb badge is disabled while a bar is chosen — switching
// unit means picking up a different bar, which is what happens in a gym.

struct BarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The bar currently on the entry's draft rows, in `unit`. nil = no bar,
    /// the weight field is the total.
    var barWeight: Double?
    var unit: WeightUnit
    /// nil clears bar mode.
    var onSelect: (Double?, WeightUnit) -> Void

    @State private var customValue = ""
    @State private var customUnit: WeightUnit = .kg

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(nil, unit)
                        dismiss()
                    } label: {
                        row(title: "No bar", detail: "Enter the total weight",
                            isSelected: barWeight == nil)
                    }
                    .accessibilityIdentifier("barOption.none")
                }

                ForEach(WeightUnit.allCases) { listUnit in
                    presetSection(for: listUnit)
                }

                Section {
                    HStack {
                        TextField("Weight", text: $customValue)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("barCustomValue")
                        Picker("Unit", selection: $customUnit) {
                            ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 110)
                        .accessibilityIdentifier("barCustomUnit")
                    }
                    Button("Use this bar") {
                        if let value = WorkoutSession.weightValue(from: customValue),
                           BarbellMath.isValidBarWeight(value) {
                            onSelect(value, customUnit)
                            dismiss()
                        }
                    }
                    .disabled(!isCustomValid)
                    .accessibilityIdentifier("barCustomApply")
                } header: {
                    Text("Custom bar")
                } footer: {
                    Text("A Smith machine's carriage weighs whatever it weighs — anywhere from 6 to 32 lb. Weigh it once and enter it here.")
                }
            }
            .navigationTitle("Bar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                customUnit = unit
                if let barWeight, !BarbellMath.presets.contains(where: {
                    $0.value == barWeight && $0.unit == unit
                }) {
                    customValue = WeightMath.displayNumber(barWeight)
                }
            }
        }
    }

    /// The bars stocked in one unit. Its own function because the nested
    /// ForEach/Section/Button chain, written inline, exceeded the type
    /// checker's budget.
    private func presetSection(for listUnit: WeightUnit) -> some View {
        let title: String = listUnit == .kg ? "Kilogram bars" : "Pound bars"
        return Section(title) {
            ForEach(BarbellMath.presets(in: listUnit)) { preset in
                let identifier: String = "barOption." + preset.id
                Button {
                    onSelect(preset.value, preset.unit)
                    dismiss()
                } label: {
                    row(
                        title: preset.name,
                        detail: detail(for: preset),
                        isSelected: isSelected(preset))
                }
                .accessibilityIdentifier(identifier)
            }
        }
    }

    private var isCustomValid: Bool {
        WorkoutSession.weightValue(from: customValue)
            .map(BarbellMath.isValidBarWeight) ?? false
    }

    /// D4: a bar whose weight is not standardised across makers must not be
    /// presented as a fact the user can rely on.
    private func detail(for preset: BarPreset) -> String {
        let label = preset.weightLabel()
        guard !preset.isStandard else { return label }
        return "\(label) — varies by maker, check yours"
    }

    private func isSelected(_ preset: BarPreset) -> Bool {
        barWeight == preset.value && unit == preset.unit
    }

    private func row(title: String, detail: String, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }
}
