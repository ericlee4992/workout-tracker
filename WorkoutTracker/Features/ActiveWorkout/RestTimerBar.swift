import SwiftData
import SwiftUI

struct RestTimerBar: View {
    var restEnd: Date
    var restTotal: Double
    var addFifteen: () -> Void
    var skip: () -> Void
    var expired: () -> Void

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        let remaining = max(0, restEnd.timeIntervalSince(now))

        VStack(spacing: 8) {
            HStack {
                Label("Rest", systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(timeString(remaining))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Spacer()
                Button("+15s", action: addFifteen)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Skip", action: skip)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            ProgressView(value: restTotal > 0 ? remaining / restTotal : 0)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .onReceive(tick) { date in
            now = date
            if restEnd <= date { expired() }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Per-exercise override editor (D22). nil means follow the editable global
/// default; values are stored independently for warmup and working/failure.
struct ExerciseRestSettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var exercise: Exercise
    @Query private var allOverrides: [ExerciseRestOverride]
    @State private var warmupUsesGlobal = true
    @State private var workingUsesGlobal = true
    @State private var warmupSeconds = 60
    @State private var workingSeconds = 120

    var body: some View {
        NavigationStack {
            Form {
                durationSection(
                    title: "Warmup sets",
                    usesGlobal: $warmupUsesGlobal,
                    seconds: $warmupSeconds)
                durationSection(
                    title: "Working & failure sets",
                    usesGlobal: $workingUsesGlobal,
                    seconds: $workingSeconds)
            }
            .navigationTitle("Rest Durations")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func durationSection(
        title: String,
        usesGlobal: Binding<Bool>,
        seconds: Binding<Int>
    ) -> some View {
        Section(title) {
            Toggle("Use global default", isOn: usesGlobal)
            if !usesGlobal.wrappedValue {
                Stepper(
                    "\(seconds.wrappedValue / 60):\(String(format: "%02d", seconds.wrappedValue % 60))",
                    value: seconds,
                    in: 0...600,
                    step: 15)
            }
        }
    }

    private func load() {
        let rows = allOverrides.filter { $0.exerciseID == exercise.id }
        let row = rows.max {
            ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString)
        }
        if let value = row?.warmupRestSeconds {
            warmupUsesGlobal = false
            warmupSeconds = value
        }
        if let value = row?.workingRestSeconds {
            workingUsesGlobal = false
            workingSeconds = value
        }
    }

    private func save() {
        do {
            try RestTimerService(context: modelContext).setOverride(
                for: exercise,
                warmupSeconds: warmupUsesGlobal ? nil : warmupSeconds,
                workingSeconds: workingUsesGlobal ? nil : workingSeconds)
            dismiss()
        } catch {
            assertionFailure("Failed to save rest override: \(error)")
        }
    }
}
