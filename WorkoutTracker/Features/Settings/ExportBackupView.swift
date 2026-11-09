import SwiftData
import SwiftUI

/// Soft redesign S6: Profile → Export & backup. Today's Export card (what there is to export, the last export) and the
/// only-copy notice, moved from the old one-page Settings, with N1's Safety copy under it.
struct ExportBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(ExportRecord.dateKey) private var lastExportSeconds: Double?
    @AppStorage(ExportRecord.formatKey) private var lastExportFormat: String?
    @State private var showExport = false
    @State private var counts: ExportCounts?
    @State private var countFailure: String?
    @State private var titleVisible = false

    static let pageTitle = "Export & backup"

    private var lastExport: ExportRecord? {
        lastExportSeconds.map {
            ExportRecord(date: Date(timeIntervalSinceReferenceDate: $0), format: lastExportFormat.flatMap(ExportFormat.init(rawValue:)))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle(Self.pageTitle)
                export
                SafetyCopySection()
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 90 : 52)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleVisible = past }
        }
        .lookScreenBackground()
        .exercisesInlineTitle(Self.pageTitle, visible: titleVisible)
        // Counted afresh on every visit (and after an export, on the way back), which is every
        // moment the number is looked at; logging happens in a full-screen cover.
        .task(id: showExport) { if !showExport { refreshCounts() } }
        .navigationDestination(isPresented: $showExport) { ExportView() }
    }

    private var export: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Export")
            SettingsCardButton { showExport = true } label: {
                SettingsRow(counts?.summary ?? " ",
                            subtitle: countFailure ?? lastExport.map { BackupStatus.lastExportLine($0, now: .now) },
                            symbol: "square.and.arrow.up", showsChevron: true)
            }
            // One element whose label starts with the count ("0 workouts · 0 sets"), so it
            // says the export is not empty before the tap.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("exportSettings")
            if BackupStatus.showsOnlyCopyNotice(lastExport: lastExport?.date, now: .now) {
                // The one line this screen must keep saying (codex-review 06).
                SettingsNotice(symbol: "iphone", text: "This phone holds the only copy until you export.")
                    .padding(.top, 2)
            }
        }
    }

    private func refreshCounts() {
        do {
            counts = try ExportCounts.fetch(from: modelContext)
            countFailure = nil
        } catch {
            countFailure = "Could not count what there is to export: \(error.localizedDescription)"
        }
    }
}
