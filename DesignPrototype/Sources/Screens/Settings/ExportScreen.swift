import SwiftUI

// PROTOTYPE — X03 Export (pushed from Settings). The bold element is the backup strip: how
// many workouts were logged since the last export, with every workout as a tally mark on a
// date line — inked up to the export mark, faint after it. Exporting inks the faint marks left
// to right, moves the mark to today and counts the number down to 0. Then what the file holds
// (workouts, sets), the one line that must keep being said, Export CSV (the one filled
// command) and Export JSON. Done shows the file with Share (now the filled command; the real
// share sheet, with a small real file); a failure takes the look's warning treatment with
// "Export failed: couldn’t save the file." (variant "failure"; the system error's file name
// broke mid-token at large sizes). "This phone holds the only copy…" rests for 3 days after an
// export. Variant "exporting" holds the in-progress state for captures.

struct ExportScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var titleVisible = false
    @State private var shareURL: URL?
    @State private var doneTick = 0
    @State private var failTick = 0
    @State private var scroll = ScrollPosition(edge: .top)
    /// Capture variant "exporting": the in-progress state, held (the real one lasts ≈0.8 s).
    @State private var heldExporting: ExportFormat?

    private var isDone: Bool {
        if case .done = store.exportState { return true }
        return false
    }

    private var exporting: ExportFormat? {
        if case .exporting(let format) = store.exportState { return format }
        return heldExporting
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
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.84), value: store.exportState)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scroll)
        .settingsScrolledPast(52, into: $titleVisible)
        .lookScreenBackground()
        .settingsInlineTitle("Export", visible: titleVisible)
        .sensoryFeedback(.success, trigger: doneTick)
        .sensoryFeedback(.error, trigger: failTick)
        .onChange(of: store.exportState) { _, state in
            switch state {
            case .done(let fileName):
                shareURL = SettingsExportFile.write(fileName, format: store.settings.lastExportFormat ?? .csv,
                                                    workouts: store.workouts)
                doneTick += 1
                revealResult()
            case .failed:
                failTick += 1
                revealResult()
            default:
                break
            }
        }
        .onAppear(perform: applyVariant)
        .onDisappear { if exporting == nil { store.resetExportState() } }
    }

    // MARK: Summary

    private var summary: some View {
        let counts = store.exportCounts
        let stats = [SettingsStat(value: Format.grouped(counts.workouts), label: counts.workouts == 1 ? "Workout" : "Workouts"),
                     SettingsStat(value: Format.grouped(counts.sets), label: counts.sets == 1 ? "Set" : "Sets")]
        return VStack(alignment: .leading, spacing: 12) {
            SettingsBackupPanel(workouts: store.workouts, lastExport: store.settings.lastExportAt,
                                lastFormat: store.settings.lastExportFormat, now: store.now,
                                exporting: exporting != nil)
            SettingsStatStrip(stats: stats)
            if SettingsDates.showsOnlyCopyNotice(lastExport: store.settings.lastExportAt, now: store.now) {
                SettingsNotice(symbol: "iphone", text: "This phone holds the only copy until you export.", emphasized: true)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Actions

    /// Export CSV is the filled command until a file is ready; then Share takes the fill (one
    /// filled command per state) and both formats step down to secondary.
    private var actions: some View {
        VStack(spacing: 12) {
            if isDone {
                Button { run(.csv) } label: {
                    buttonLabel("Export CSV", symbol: "tablecells", busy: false)
                }
                .buttonStyle(.lookSecondary)
            } else {
                Button { run(.csv) } label: {
                    buttonLabel("Export CSV", symbol: "tablecells", busy: exporting == .csv)
                }
                .buttonStyle(.lookPrimary)
                .disabled(exporting != nil)
            }
            Button { run(.json) } label: {
                buttonLabel("Export JSON", symbol: "curlybraces", busy: exporting == .json)
            }
            .buttonStyle(.lookSecondary)
            .disabled(exporting != nil)
        }
    }

    private func buttonLabel(_ title: String, symbol: String, busy: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Image(systemName: symbol).font(.body.weight(.semibold)).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(look.id == .anatomy || look.id == .floodlight ? look.onAction : look.onAction) }
            }
            Text(title)
        }
        .accessibilityLabel(busy ? "\(title), exporting" : title)
    }

    /// The file card (or the failure line) lands under the buttons; bring it into view when the
    /// page is taller than the screen (accessibility sizes).
    private func revealResult() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if reduceMotion { scroll.scrollTo(edge: .bottom) } else {
                withAnimation(.easeInOut(duration: 0.4)) { scroll.scrollTo(edge: .bottom) }
            }
        }
    }

    private func run(_ format: ExportFormat) {
        shareURL = nil
        store.export(format)
    }

    // MARK: Result

    @ViewBuilder private var result: some View {
        switch store.exportState {
        case .done(let fileName):
            fileCard(fileName)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        case .failed:
            failureRow("Export failed: couldn’t save the file.")
                .transition(.opacity)
        case .idle, .exporting:
            EmptyView()
        }
    }

    private func fileCard(_ fileName: String) -> some View {
        let json = fileName.hasSuffix(".json")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: json ? "curlybraces" : "tablecells")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .frame(width: 48, height: 48)
                    .background {
                        switch look.id {
                        case .floodlight: RoundedRectangle(cornerRadius: 12, style: .continuous).fill(look.surfaceRaised)
                        case .anatomy: Circle().fill(look.controlFill)
                        case .paper, .carbon: Circle().strokeBorder(look.outline, lineWidth: 1.5)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark")
                            .font(.system(.caption2, weight: .heavy))
                            .foregroundStyle(look.onDone)
                            .frame(width: 20, height: 20)
                            .background(look.done, in: Circle())
                            .offset(x: 4, y: 4)
                            .celebrate(fileName)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(fileName)
                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(Format.count(store.exportCounts.workouts, "workout")) · \(Format.count(store.exportCounts.sets, "set"))")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 0)
            }
            if let shareURL {
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.lookPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    /// The failure, in the look's warning treatment (failure must never read like a notice):
    /// A danger red-orange on a danger-tinted panel. B has no hue for errors (red is heart
    /// rate): a raised surface with a pearl edge and a filled pearl mark. C: the heavy 2 pt ink
    /// rule and an ink-filled "!" disc.
    private func failureRow(_ line: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
        return HStack(alignment: .center, spacing: 12) {
            Group {
                switch look.id {
                case .floodlight:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(look.destructive)
                case .anatomy:
                    Image(systemName: "exclamationmark")
                        .font(.system(.body, weight: .heavy))
                        .foregroundStyle(look.ground)
                        .frame(width: 30, height: 30)
                        .background(look.textPrimary, in: Circle())
                case .paper, .carbon:
                    Image(systemName: "exclamationmark")
                        .font(.system(.body, weight: .heavy))
                        .foregroundStyle(look.surface)
                        .frame(width: 30, height: 30)
                        .background(look.textPrimary, in: Circle())
                }
            }
            .frame(minWidth: 30)
            Text(line)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(look.id == .floodlight ? look.destructive : look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            switch look.id {
            case .floodlight:
                shape.fill(look.destructive.opacity(0.10)).overlay { shape.strokeBorder(look.destructive.opacity(0.55), lineWidth: 1.5) }
            case .anatomy:
                shape.fill(look.surfaceRaised).overlay { shape.strokeBorder(look.textPrimary.opacity(0.85), lineWidth: 1.5) }
            case .paper, .carbon:
                shape.fill(look.surface).overlay { shape.strokeBorder(look.outline, lineWidth: 2.5) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Variants

    private func applyVariant() {
        guard let variant = SettingsVariant.consume(.x03, store: store, router: router) else { return }
        if SettingsVariant.has(variant, "failure") || SettingsVariant.has(variant, "done") {
            store.export(.csv)
        }
        if SettingsVariant.has(variant, "exporting") {
            heldExporting = .csv
        }
    }
}


// MARK: - Backup strip (the bold element)

/// How many workouts are not in an export yet, and every workout as a tally mark on a date
/// line from the first workout to today: inked up to the last export, faint after it. A mark with
/// the share glyph stands at the export date. When an export lands, the open dots ink left
/// to right and the number counts down (Reduce Motion: they change at once).
struct SettingsBackupPanel: View {
    var workouts: [Workout]
    var lastExport: Date?
    var lastFormat: ExportFormat?
    var now: Date
    var exporting = false
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private var pending: Int {
        guard let lastExport else { return workouts.count }
        return workouts.filter { $0.startedAt > lastExport }.count
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        VStack(alignment: .leading, spacing: 18) {
            layout {
                CountUpText(Double(pending), duration: 0.8, countsFromZero: false) { Format.grouped($0) }
                    .font(look.font.heroNumber)
                    .foregroundStyle(look.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pending == 1 ? "workout since last export" : "workouts since last export")
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let lastExport {
                        Text("Last export \(SettingsDates.relative(lastExport, now: now))" + (lastFormat.map { " · \($0.label)" } ?? ""))
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pending) \(pending == 1 ? "workout" : "workouts") since last export")
            SettingsBackupStrip(dates: workouts.map(\.startedAt), lastExport: lastExport, now: now, exporting: exporting)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }
}

private struct SettingsBackupStrip: View {
    var dates: [Date]
    var lastExport: Date?
    var now: Date
    /// While a file is being written the not-yet-exported marks pulse (Reduce Motion: they hold
    /// at half strength), answering the tap before the result lands.
    var exporting = false
    @State private var pulse = false
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// One workout = one tally mark; a second workout that day stacks above it.
    private let tally: CGFloat = 15

    private struct Mark: Identifiable {
        var id: Int
        var day: Int
        var stack: Int
        var date: Date
    }

    var body: some View {
        let cal = Calendar.app
        let start = cal.startOfDay(for: dates.min() ?? now)
        let today = cal.startOfDay(for: now)
        let span = max(1, (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
        let marks = makeMarks(start: start)
        let exportDay = lastExport.map { cal.dateComponents([.day], from: start, to: cal.startOfDay(for: $0)).day ?? 0 }
        VStack(spacing: 6) {
            GeometryReader { geo in
                let perDay = geo.size.width / CGFloat(span)
                let x: (Int) -> CGFloat = { (CGFloat($0) + 0.5) * perDay }
                ZStack(alignment: .topLeading) {
                    Capsule().fill(look.hairline)
                        .frame(width: geo.size.width, height: 1.5)
                        .offset(y: geo.size.height - 1)
                    if let exportDay {
                        let mx = min(geo.size.width - 1, max(1, x(exportDay) + perDay / 2))
                        Rectangle().fill(look.textSecondary)
                            .frame(width: 1.5, height: geo.size.height - 14)
                            .offset(x: mx - 0.75, y: 14)
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(look.textSecondary)
                            .position(x: mx, y: 6)
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: exportDay)
                    }
                    ForEach(marks) { mark in
                        let exported = lastExport.map { mark.date <= $0 } ?? false
                        let width = min(5.5, max(3, perDay - 2))
                        let shape = Capsule()
                        // Not yet exported: a faint mark (an outlined capsule this narrow reads as "0").
                        shape
                            .fill(exported ? look.done
                                  : (exporting ? look.textPrimary.opacity(reduceMotion ? 0.6 : (pulse ? 0.85 : 0.35))
                                               : look.textSecondary.opacity(0.38)))
                            .frame(width: width, height: tally)
                            .position(x: x(mark.day),
                                      y: geo.size.height - 4 - tally / 2 - CGFloat(mark.stack) * (tally + 3))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.25).delay(Double(mark.day) * 0.012),
                                       value: exported)
                    }
                }
            }
            .frame(height: 16 + 2 * tally + 3)
            .onChange(of: exporting, initial: true) { _, on in
                guard on, !reduceMotion else { pulse = false; return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
            }
            HStack {
                Text(Format.shortDate(start))
                Spacer(minLength: 8)
                Text(Format.shortDate(today))
            }
            .font(look.font.caption)
            .foregroundStyle(look.textTertiary)
        }
        .accessibilityHidden(true)
    }

    private func makeMarks(start: Date) -> [Mark] {
        let cal = Calendar.app
        var perDay: [Int: Int] = [:]
        return dates.sorted().enumerated().map { index, date in
            let day = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: date)).day ?? 0
            let stack = perDay[day, default: 0]
            perDay[day] = stack + 1
            return Mark(id: index, day: day, stack: stack, date: date)
        }
    }
}
