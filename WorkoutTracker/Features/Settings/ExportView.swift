import SwiftData
import SwiftUI

/// X03 Export, pushed from Settings (Floodlight ticket 09). The bold element is the backup panel:
/// how many workouts were started since this phone's last completed export, with every workout a
/// tally mark on a date line — solid up to the export mark, faint after it. Then what the file
/// holds (workouts, sets), the one line that must keep being said, **Export CSV** (the one filled
/// command) and Export JSON.
///
/// A tap builds the file and presents the share sheet at once (as before); the file card then
/// stays with **Share**, so the same file can be sent again (user decision 2). Only a share that
/// completes records the export (decision 1). Never a silent no-op: an export that quietly fails is
/// how a person finds out there was no backup when they needed one.
struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ExportRecord.dateKey) private var lastExportSeconds: Double?
    @AppStorage(ExportRecord.formatKey) private var lastExportFormat: String?

    @State private var counts: ExportCounts?
    @State private var building: ExportFormat?
    @State private var file: ExportedFile?
    /// Owns the staged file on disk: replaced by the next export, deleted on a failed replacement
    /// or when the screen goes away (codex-review-09 #1–2).
    @State private var staging = ExportStaging()
    /// The export in flight, cancelled when the screen goes away so it cannot publish a file after
    /// the cleanup has run.
    @State private var exportTask: Task<Void, Never>?
    /// The file handed to the share sheet (identity per presentation, so sharing the same file
    /// twice still presents).
    @State private var sharing: SharePresentation?
    @State private var failure: String?
    @State private var titleVisible = false
    @State private var doneTick = 0
    @State private var failTick = 0
    @State private var scroll = ScrollPosition(edge: .top)

    /// A written file and what it holds.
    struct ExportedFile: Equatable {
        var url: URL
        var format: ExportFormat
        /// Taken before the store was read: every workout started by then is in the file.
        var builtAt: Date
        var workouts: Int
        var sets: Int
    }

    private struct SharePresentation: Identifiable {
        let id = UUID()
        let file: ExportedFile
    }

    private var lastExport: ExportRecord? {
        lastExportSeconds.map {
            ExportRecord(date: Date(timeIntervalSinceReferenceDate: $0), format: lastExportFormat.flatMap(ExportFormat.init(rawValue:)))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Export")
                summary
                actions
                result
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.84), value: file)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.84), value: failure)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scroll)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 90 : 52)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleVisible = past }
        }
        .lookScreenBackground()
        .exercisesInlineTitle("Export", visible: titleVisible)
        .sensoryFeedback(.success, trigger: doneTick)
        .sensoryFeedback(.error, trigger: failTick)
        .task { refreshCounts() }
        .sheet(item: $sharing) { presentation in
            ShareSheet(url: presentation.file.url) { completed in
                if completed { record(presentation.file) }
            }
        }
        // The staged file lives while this screen is on screen, for the card's Share. Leaving —
        // including to another tab, which keeps this screen's state — deletes it AND drops the card,
        // so Share never offers a deleted file (codex-review-09 #1).
        .onDisappear(perform: dropFile)
    }

    // MARK: Summary (the bold element)

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExportBackupPanel(workoutDates: counts?.workoutDates ?? [], lastExport: lastExport, building: building != nil)
            if let counts {
                SettingsStatStrip(stats: stats(counts))
            }
            if BackupStatus.showsOnlyCopyNotice(lastExport: lastExport?.date, now: .now) {
                // The one line this screen must keep saying (codex-review 06).
                SettingsNotice(symbol: "iphone", text: "This phone holds the only copy until you export.", emphasized: true)
                    .transition(.opacity)
            }
        }
    }

    private func stats(_ counts: ExportCounts) -> [SettingsStat] {
        var stats = [SettingsStat(value: counts.workouts, label: counts.workouts == 1 ? "Workout" : "Workouts"),
                     SettingsStat(value: counts.sets, label: counts.sets == 1 ? "Set" : "Sets")]
        if counts.completedSets != counts.sets {
            stats.append(SettingsStat(value: counts.completedSets, label: "Completed"))
        }
        return stats
    }

    // MARK: Actions

    /// Export CSV is the filled command until a file is ready; then the card's Share takes the fill
    /// (one filled command per state) and both formats are secondary.
    private var actions: some View {
        VStack(spacing: 12) {
            if file == nil {
                Button { export(.csv) } label: { buttonLabel(.csv, symbol: "tablecells") }
                    .buttonStyle(.lookPrimary)
                    .accessibilityIdentifier("exportCSV")
            } else {
                Button { export(.csv) } label: { buttonLabel(.csv, symbol: "tablecells") }
                    .buttonStyle(.lookSecondary)
                    .accessibilityIdentifier("exportCSV")
            }
            Button { export(.json) } label: { buttonLabel(.json, symbol: "curlybraces") }
                .buttonStyle(.lookSecondary)
                .accessibilityIdentifier("exportJSON")
        }
        .disabled(building != nil)
    }

    private func buttonLabel(_ format: ExportFormat, symbol: String) -> some View {
        let title = "Export \(format.label)"
        let busy = building == format
        return HStack(spacing: 10) {
            ZStack {
                Image(systemName: symbol).font(.body.weight(.semibold)).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(file == nil && format == .csv ? look.onAction : look.textPrimary) }
            }
            Text(title)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(busy ? "\(title), exporting" : title)
    }

    // MARK: Result

    @ViewBuilder private var result: some View {
        if let failure {
            failurePanel(failure)
                .transition(.opacity)
        } else if let file {
            fileCard(file)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func fileCard(_ file: ExportedFile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: file.format == .json ? "curlybraces" : "tablecells")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark")
                            .font(.system(.caption2, weight: .heavy))
                            .foregroundStyle(look.onDone)
                            .frame(width: 20, height: 20)
                            .background(look.done, in: Circle())
                            .offset(x: 4, y: 4)
                            .celebrate(file.url)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.url.lastPathComponent)
                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ExportCounts(workouts: file.workouts, sets: file.sets, completedSets: file.sets, workoutDates: []).summary)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Button { sharing = SharePresentation(file: file) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.lookPrimary)
            .accessibilityIdentifier("exportShare")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exportFileCard")
    }

    /// The failure in the warning treatment (a failure must never read like a notice): the
    /// headline says what happened; the system's reason sits under it on its own line, so a long
    /// file name in it can wrap without breaking the headline.
    private func failurePanel(_ reason: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(look.destructive)
            VStack(alignment: .leading, spacing: 4) {
                Text("Export failed: couldn’t save the file.")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(look.destructive)
                Text(reason)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.destructive.opacity(0.10), in: shape)
        .overlay { shape.strokeBorder(look.destructive.opacity(0.55), lineWidth: 1.5) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exportFailure")
    }

    // MARK: Work

    private func export(_ format: ExportFormat) {
        failure = nil
        building = format
        exportTask = Task { @MainActor in
            // One frame for the busy state before the store is read on this actor.
            try? await Task.sleep(for: .milliseconds(60))
            defer { building = nil }
            // Left the screen meanwhile: build nothing (the rest runs without a suspension point).
            guard !Task.isCancelled else { return }
            let builtAt = Date.now
            do {
                if WorkoutTrackerStore.fixtureIsEnabled(Self.failureFixture) {
                    throw CocoaError(.fileWriteOutOfSpace)
                }
                let snapshot = try ExportCollector().snapshot(from: modelContext)
                let data =
                    switch format {
                    case .csv: ExportCSV.data(snapshot)
                    case .json: try ExportJSON.data(snapshot)
                    }
                let url = try ExportFileWriter.write(data, format: format)
                staging.adopt(url)
                let written = ExportedFile(url: url, format: format, builtAt: builtAt,
                                           workouts: snapshot.counts.workouts, sets: snapshot.counts.sets)
                file = written
                sharing = SharePresentation(file: written)
                doneTick += 1
                refreshCounts()
            } catch {
                // The previous file (kept on disk by a failed write) goes with its card.
                staging.release()
                file = nil
                failure = error.localizedDescription
                failTick += 1
            }
            revealResult()
        }
    }

    private func dropFile() {
        exportTask?.cancel()
        exportTask = nil
        building = nil
        staging.release()
        file = nil
    }

    /// A completed share is the backup (decision 1): the mark moves to when the file was built.
    private func record(_ file: ExportedFile) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
            lastExportSeconds = file.builtAt.timeIntervalSinceReferenceDate
            lastExportFormat = file.format.rawValue
        }
    }

    /// The card (or the failure) lands under the buttons; bring it into view when the page is
    /// taller than the screen (accessibility sizes).
    private func revealResult() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            if reduceMotion { scroll.scrollTo(edge: .bottom) } else {
                withAnimation(.easeInOut(duration: 0.4)) { scroll.scrollTo(edge: .bottom) }
            }
        }
    }

    private func refreshCounts() {
        do {
            counts = try ExportCounts.fetch(from: modelContext)
        } catch {
            failure = "Could not count what there is to export: \(error.localizedDescription)"
        }
    }

    /// UI tests: the file write fails (the failure state).
    static let failureFixture = "-uiTestExportFails"
}

extension ExportCounts {
    /// Counts straight from the store — cheaper than materialising every set row into a `@Query`.
    @MainActor static func fetch(from context: ModelContext) throws -> ExportCounts {
        let completed = FetchDescriptor<SetRecord>(predicate: #Predicate { $0.completedAt != nil })
        var starts = FetchDescriptor<Workout>()
        starts.propertiesToFetch = [\.startedAt]
        return ExportCounts(
            workouts: try context.fetchCount(FetchDescriptor<Workout>()),
            sets: try context.fetchCount(FetchDescriptor<SetRecord>()),
            completedSets: try context.fetchCount(completed),
            workoutDates: try context.fetch(starts).map(\.startedAt))
    }
}

// MARK: - Backup panel

/// How many workouts are not in an export yet, over the tally strip. The count moves (counts
/// down) when an export completes; Reduce Motion changes it at once.
struct ExportBackupPanel: View {
    var workoutDates: [Date]
    var lastExport: ExportRecord?
    var building = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let pending = BackupStatus.pending(workoutDates: workoutDates, lastExport: lastExport?.date)
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        VStack(alignment: .leading, spacing: 18) {
            layout {
                CountUpText(Double(pending), duration: 0.8, countsFromZero: false) { Int($0).formatted() }
                    .font(look.font.heroNumber)
                    .foregroundStyle(look.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pending == 1 ? "workout since last export" : "workouts since last export")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let lastExport {
                        Text(BackupStatus.lastExportLine(lastExport, now: .now))
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pending) \(pending == 1 ? "workout" : "workouts") since last export"
                + (lastExport.map { ". " + BackupStatus.lastExportLine($0, now: .now) } ?? ""))
            .accessibilityIdentifier("exportPending")
            if !workoutDates.isEmpty {
                ExportTallyStrip(tally: BackupStatus.tally(workoutDates: workoutDates, lastExport: lastExport?.date, now: .now),
                                 building: building)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }
}

/// Every workout as a tally mark on a date line from the first workout to today: solid (the done
/// colour) up to the export mark, faint after it. While a file is built the faint marks pulse
/// (Reduce Motion: they hold at half strength). Decorative: the panel's count says it in words.
private struct ExportTallyStrip: View {
    var tally: BackupStatus.Tally
    var building: Bool
    @State private var pulse = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let mark: CGFloat = 15
    /// Rows of marks the strip makes room for: at least two, sized from the busiest day, capped so a
    /// very busy day cannot push the strip into the panel's count (codex-review-09 #3). Workouts
    /// beyond the cap share the top row; the count above says the number in words.
    private var rows: Int { min(max(2, tally.tallestStack), 4) }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let perDay = geo.size.width / CGFloat(tally.span)
                let x: (Int) -> CGFloat = { (CGFloat($0) + 0.5) * perDay }
                ZStack(alignment: .topLeading) {
                    Capsule().fill(look.hairline)
                        .frame(width: geo.size.width, height: 1.5)
                        .offset(y: geo.size.height - 1)
                    if let exportDay = tally.exportDay {
                        let mx = min(geo.size.width - 1, max(1, x(exportDay) + perDay / 2))
                        Rectangle().fill(look.textSecondary)
                            .frame(width: 1.5, height: geo.size.height - 14)
                            .offset(x: mx - 0.75, y: 14)
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(look.textSecondary)
                            .position(x: mx, y: 6)
                    }
                    ForEach(tally.marks) { item in
                        Capsule()
                            .fill(item.exported ? look.done
                                  : (building ? look.textPrimary.opacity(reduceMotion ? 0.6 : (pulse ? 0.85 : 0.35))
                                              : look.textSecondary.opacity(0.38)))
                            .frame(width: min(5.5, max(3, perDay - 2)), height: mark)
                            .position(x: x(item.day),
                                      y: geo.size.height - 4 - mark / 2 - CGFloat(min(item.stack, rows - 1)) * (mark + 3))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.25).delay(Double(item.day) * 0.012),
                                       value: item.exported)
                    }
                }
            }
            .frame(height: 16 + CGFloat(rows) * mark + CGFloat(rows - 1) * 3)
            .onChange(of: building, initial: true) { _, on in
                guard on, !reduceMotion else { pulse = false; return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
            }
            HStack {
                Text(tally.start.formatted(.dateTime.month(.abbreviated).day()))
                Spacer(minLength: 8)
                Text(tally.end.formatted(.dateTime.month(.abbreviated).day()))
            }
            .font(look.font.caption)
            .foregroundStyle(look.textTertiary)
        }
        .accessibilityHidden(true)
    }
}
