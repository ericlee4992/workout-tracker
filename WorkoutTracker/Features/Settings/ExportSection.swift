import SwiftData
import SwiftUI

/// Milestone 3, ticket 02 — the export block, rendered as one `Section` on the
/// Gyms screen beside `AppSettingsSection` (where app-level settings already
/// live). Tapping a format builds the file on the spot and hands it to the
/// system share sheet; "Save to Files → iCloud Drive" is the backup this
/// milestone exists for.
struct ExportSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var pendingFile: PendingExport?
    @State private var failure: String?
    @State private var summary: Summary?

    /// The written file awaiting its share sheet. Identity is per-export, not
    /// per-URL, so exporting the same minute twice still presents.
    private struct PendingExport: Identifiable {
        let id = UUID()
        let url: URL
    }

    private struct Summary {
        var workouts: Int
        var sets: Int
        var completedSets: Int

        /// "87 workouts · 1,234 sets logged" — enough to see at a glance that
        /// the export is not empty before sharing it.
        var text: String {
            let workoutLabel = workouts == 1 ? "workout" : "workouts"
            let setLabel = sets == 1 ? "set" : "sets"
            return "\(workouts.formatted()) \(workoutLabel) · \(sets.formatted()) \(setLabel)"
                + (completedSets == sets ? "" : " (\(completedSets.formatted()) completed)")
        }
    }

    var body: some View {
        Section {
            Text(summary?.text ?? "Counting…")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("exportSummary")
                .task { refreshSummary() }
                // Presentation hangs off a row, not off the `Section`: a
                // `.sheet` attached to a Section inside a List never fires
                // (verified — the file was written and nothing appeared).
                .sheet(item: $pendingFile) { pending in
                    ShareSheet(
                        url: pending.url,
                        onFinish: { ExportFileWriter.discard(at: pending.url) })
                }

            ForEach(ExportFormat.allCases) { format in
                Button {
                    export(format)
                } label: {
                    Label("Export \(format.label)", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("export\(format.label)")
            }

            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("exportFailure")
            }
        } header: {
            Text("Export")
        } footer: {
            // The one line this section must keep saying (codex-review 06).
            Text("This phone holds the only copy until you export.")
        }
    }

    // MARK: - Actions

    private func export(_ format: ExportFormat) {
        failure = nil
        do {
            let snapshot = try ExportCollector().snapshot(from: modelContext)
            let data =
                switch format {
                case .csv: ExportCSV.data(snapshot)
                case .json: try ExportJSON.data(snapshot)
                }
            pendingFile = PendingExport(
                url: try ExportFileWriter.write(data, format: format))
            summary = Summary(
                workouts: snapshot.counts.workouts,
                sets: snapshot.counts.sets,
                completedSets: snapshot.counts.completedSets)
        } catch {
            // Never a silent no-op: an export that quietly fails is how a
            // person finds out there was no backup when they needed one.
            failure = "Export failed: \(error.localizedDescription)"
        }
    }

    /// Counts straight from the store — cheaper than materialising every set
    /// row into a `@Query` on a screen that is mostly about gyms. Re-runs each
    /// time the Gyms tab is selected (SwiftUI restarts `.task` on reappearance)
    /// and again after an export, which is every moment the number is looked at;
    /// logging happens in a full-screen cover, so it cannot go stale on screen.
    private func refreshSummary() {
        do {
            let completed = FetchDescriptor<SetRecord>(
                predicate: #Predicate { $0.completedAt != nil })
            summary = Summary(
                workouts: try modelContext.fetchCount(FetchDescriptor<Workout>()),
                sets: try modelContext.fetchCount(FetchDescriptor<SetRecord>()),
                completedSets: try modelContext.fetchCount(completed))
        } catch {
            failure = "Could not count what there is to export: \(error.localizedDescription)"
        }
    }
}
