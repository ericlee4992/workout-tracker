import SwiftData
import SwiftUI

// Milestone 7, ticket 05 — where an estimated maximum heart rate becomes a
// measured one (D45).
//
// The screen exists because the app marks estimated zones as estimated, and a
// mark the user cannot act on is just nagging. Tapping "zone estimated" on the
// heart-rate bar lands here.

struct MaxHeartRateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var measuredText = ""
    @State private var birthDate = Date(timeIntervalSince1970: 0)
    @State private var hasBirthDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Maximum heart rate", text: $measuredText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("maxHeartRateField")
                } header: {
                    Text("Measured maximum")
                }

                Section {
                    Toggle("Use my date of birth", isOn: $hasBirthDate)
                        .accessibilityIdentifier("useBirthDate")
                    if hasBirthDate {
                        DatePicker(
                            "Date of birth", selection: $birthDate,
                            displayedComponents: .date)
                    }
                } header: {
                    Text("Estimate")
                }

                if let preview = resolvedPreview {
                    Section("Zones would use") {
                        LabeledContent("Maximum") {
                            Text("\(preview.bpm) bpm\(preview.isEstimated ? " (estimated)" : "")")
                        }
                        ForEach([HeartRateZone.one, .two, .three, .four, .five], id: \.self) { zone in
                            LabeledContent(zone.label) {
                                Text("\(HeartRateZones.lowerBound(of: zone, max: preview.bpm))+ bpm")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Heart Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("saveMaxHeartRate")
                }
            }
            .onAppear(perform: load)
        }
    }

    private var resolvedPreview: MaxHeartRate? {
        MaxHeartRateResolver.resolve(
            measured: Int(measuredText.trimmingCharacters(in: .whitespaces)),
            birthDate: hasBirthDate ? birthDate : nil,
            at: .now)
    }

    private func load() {
        guard let preferences = try? AppPreferences.canonical(in: modelContext) else { return }
        measuredText = preferences.measuredMaxHeartRate.map(String.init) ?? ""
        if let stored = preferences.birthDate {
            birthDate = stored
            hasBirthDate = true
        }
    }

    private func save() {
        do {
            let preferences = try AppPreferences.canonical(in: modelContext)
            // An unparseable or non-positive entry clears the measured value
            // rather than storing a number the zones would then trust.
            let measured = Int(measuredText.trimmingCharacters(in: .whitespaces))
            preferences.measuredMaxHeartRate = (measured ?? 0) > 0 ? measured : nil
            preferences.birthDate = hasBirthDate ? birthDate : nil
            preferences.updatedAt = .now
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save heart-rate settings: \(error)")
        }
        dismiss()
    }
}

#Preview {
    MaxHeartRateSheet()
        .modelContainer(for: WorkoutTrackerStore.modelTypes, inMemory: true)
}
