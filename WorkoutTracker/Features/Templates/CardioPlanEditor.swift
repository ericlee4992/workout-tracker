import SwiftUI

struct CardioPlanEditor: View {
    @Binding var targets: [PlannedCardio]
    var allowed: [CardioActivity] = CardioActivity.allCases
    var body: some View {
        Section("Cardio targets") {
            ForEach($targets) { $target in
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Activity", selection: $target.activity) {
                        ForEach(allowed) { Text($0.name).tag($0) }
                    }
                    Stepper("\(target.minutes) min", value: $target.minutes, in: 1...180)
                    Toggle("Distance target", isOn: Binding(get: { target.distance != nil }, set: { target.distance = $0 ? 1 : nil }))
                    if target.distance != nil {
                        HStack {
                            TextField("Distance", value: $target.distance, format: .number).keyboardType(.decimalPad)
                            Picker("Unit", selection: $target.unit) {
                                ForEach(CardioDistanceUnit.allCases) { Text($0.rawValue).tag($0) }
                            }
                        }
                    }
                    Button("Remove cardio", role: .destructive) { targets.removeAll { $0.id == target.id } }
                }
            }
            if let first = allowed.first {
                Button("Add cardio target", systemImage: "plus") { targets.append(PlannedCardio(activity: first, minutes: 15)) }
                    .disabled(targets.count >= 3)
            }
        }
    }
}
