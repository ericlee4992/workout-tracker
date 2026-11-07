import SwiftUI

// PROTOTYPE — Settings area support: capture helpers (variants, p2 / p3 paging), the inline
// title, sheet presentation, and the small pieces the three Settings screens share (choice
// tiles, the zone ladder, the stat strip, notice lines, the export file). Area-prefixed so
// the folder builds on its own. Integrator: the paging / inline-title helpers duplicate the
// Exercises ones on purpose (each area must compile with the other stubbed).

// MARK: - Capture variants

enum SettingsVariant {
    /// The view-level variant for `screen`, read once, then cleared.
    static func consume(_ screen: ScreenID, store: Store, router: Router) -> String? {
        guard store.currentScreen == screen, let variant = router.variant else { return nil }
        router.variant = nil
        return variant
    }

    static func page(_ variant: String?) -> Int {
        guard let variant else { return 0 }
        if variant.contains("p3") { return 2 }
        if variant.contains("p2") { return 1 }
        return 0
    }

    static func has(_ variant: String?, _ flag: String) -> Bool {
        variant?.localizedCaseInsensitiveContains(flag) ?? false
    }
}

// MARK: - Paging (p2 / p3)

struct SettingsPaging: ViewModifier {
    var page: Int
    @Binding var position: ScrollPosition
    @State private var metrics = Metrics()

    struct Metrics: Equatable {
        var viewport: CGFloat = 0
        var content: CGFloat = 0
        var insetTop: CGFloat = 0
        var insetBottom: CGFloat = 0
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Metrics.self) { geo in
                Metrics(viewport: geo.containerSize.height, content: geo.contentSize.height,
                        insetTop: geo.contentInsets.top, insetBottom: geo.contentInsets.bottom)
            } action: { _, new in
                metrics = new
            }
            .task(id: page) {
                guard page > 0 else { return }
                var last = Metrics()
                for _ in 0..<40 {
                    try? await Task.sleep(for: .milliseconds(120))
                    if metrics.viewport > 0, metrics.content > 0, metrics == last { break }
                    last = metrics
                }
                try? await Task.sleep(for: .milliseconds(150))
                let visible = metrics.viewport - metrics.insetTop - metrics.insetBottom
                let step = max(200, visible - 60)
                let maxOffset = max(0, metrics.content - metrics.viewport + metrics.insetBottom)
                let target: CGFloat = page >= 2 ? maxOffset
                    : (maxOffset > 2 * step ? maxOffset / 2 : min(step - metrics.insetTop, maxOffset))
                position.scrollTo(y: target)
            }
    }
}

extension View {
    func settingsPaging(_ page: Int, position: Binding<ScrollPosition>) -> some View {
        modifier(SettingsPaging(page: page, position: position))
    }

    /// The pushed screen's inline title, faded in once the content title has scrolled away.
    func settingsInlineTitle(_ title: String, visible: Bool) -> some View {
        modifier(SettingsInlineTitle(title: title, visible: visible))
    }

    func settingsScrolledPast(_ threshold: CGFloat, into flag: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > threshold
        } action: { _, past in
            if flag.wrappedValue != past { withAnimation(.easeOut(duration: 0.18)) { flag.wrappedValue = past } }
        }
    }

    /// A sheet's root: ground, radius, drag indicator, and the prototype's Dynamic Type override.
    /// `fitted` (the measured content height) opens the sheet at exactly that height, drag up for
    /// full height; accessibility sizes and content taller than the screen open full height.
    func settingsSheetPresentation(_ look: Look, fitted: CGFloat? = nil) -> some View {
        modifier(SettingsSheetChrome(look: look, fitted: fitted))
    }

    func settingsMeasureHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { new in
            if abs(height.wrappedValue - new) > 0.5 { height.wrappedValue = new }
        }
    }

    func settingsMeasureContent(_ height: Binding<CGFloat>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, new in
            if abs(height.wrappedValue - new) > 0.5 { height.wrappedValue = new }
        }
    }

    func settingsChoiceSurface(isSelected: Bool, radius: CGFloat? = nil) -> some View {
        modifier(SettingsChoiceSurface(isSelected: isSelected, radius: radius))
    }
}

private struct SettingsSheetChrome: ViewModifier {
    var look: Look
    var fitted: CGFloat?
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var expanded = false

    func body(content: Content) -> some View {
        let ax = (router.dynamicTypeOverride ?? typeSize).isAccessibilitySize
        let height = fitted.map { ($0 + 12).rounded(.up) }
        let short: PresentationDetent? = (!ax && (height ?? 0) > 120 && (height ?? 0) < 780) ? .height(height!) : nil
        content
            .lookSheetGround()
            .modifier(SettingsTypeOverride())
            .presentationBackground(look.groundSheet)
            .presentationCornerRadius(look.radius.sheet)
            .presentationDragIndicator(.visible)
            .presentationDetents(short.map { [$0, .large] } ?? [.large],
                                 selection: Binding(get: { expanded || short == nil ? .large : short! },
                                                    set: { expanded = ($0 == .large) }))
    }
}

private struct SettingsInlineTitle: ViewModifier {
    var title: String
    var visible: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .opacity(visible ? 1 : 0)
                        .accessibilityHidden(!visible)
                }
            }
    }
}

struct SettingsTypeOverride: ViewModifier {
    @Environment(Router.self) private var router
    func body(content: Content) -> some View {
        if let size = router.dynamicTypeOverride { content.dynamicTypeSize(size) } else { content }
    }
}

// MARK: - Dates

enum SettingsDates {
    private static let weekdayF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Format.locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    /// One date rule for every look (the Exercises area uses the same): "Today", "Yesterday",
    /// the weekday within the last 6 days, otherwise "Sep 12".
    static func relative(_ date: Date, now: Date) -> String {
        let cal = Calendar.app
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return weekdayF.string(from: date)
        default: return Format.shortDate(date)
        }
    }

    /// "This phone holds the only copy until you export." rests for 3 days after an export, so
    /// it never sits under "Last export Today".
    static func showsOnlyCopyNotice(lastExport: Date?, now: Date) -> Bool {
        guard let lastExport else { return true }
        return now.timeIntervalSince(lastExport) > 3 * 24 * 3600
    }
}

// MARK: - Toggle

/// Settings switches are state, not action. A draws ON as a flood (white) track with an ink
/// knob — the same "lit" meaning as a selected unit tile or tab — so Ultra stays on the one
/// command (Save key, Export CSV). B and C keep the look's switch.
struct SettingsToggleStyle: ToggleStyle {
    @Environment(\.look) private var look

    func makeBody(configuration: Configuration) -> some View {
        if look.id == .floodlight {
            SettingsFloodSwitch(configuration: configuration)
        } else {
            Toggle(configuration).toggleStyle(.look)
        }
    }
}

extension ToggleStyle where Self == SettingsToggleStyle {
    static var settings: SettingsToggleStyle { SettingsToggleStyle() }
}

private struct SettingsFloodSwitch: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let on = configuration.isOn
        Button {
            if reduceMotion { configuration.isOn.toggle() } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { configuration.isOn.toggle() }
            }
        } label: {
            Capsule()
                .fill(on ? look.textPrimary : look.surfaceRaised)
                .overlay { if !on { Capsule().strokeBorder(look.hairline, lineWidth: 1) } }
                .frame(width: 51, height: 31)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle()
                        .fill(on ? look.ground : look.textSecondary)
                        .frame(width: 25, height: 25)
                        .padding(3)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

// MARK: - Look helpers

extension Look {
    var settingsRowTitle: Font {
        switch id {
        case .floodlight: .system(.body, weight: .semibold)
        case .anatomy: .system(.body, design: .rounded, weight: .semibold)
        case .paper, .carbon: .system(.body, weight: .medium)
        }
    }

    /// A stat that is a word ("Sep 12", "12 days ago").
    var settingsStatWord: Font {
        switch id {
        case .anatomy: .system(.title3, design: .rounded, weight: .heavy)
        case .floodlight, .paper, .carbon: Font.system(.title3, weight: .heavy).width(.expanded)
        }
    }

    var settingsGlyphTint: Color { id.isPaperClub ? textPrimary : textSecondary }

    func settingsChoiceText(_ selected: Bool) -> Color { id.isPaperClub && selected ? onAction : textPrimary }
    func settingsChoiceSecondary(_ selected: Bool) -> Color { id.isPaperClub && selected ? onAction.opacity(0.86) : textSecondary }
}

// MARK: - Choice surface

/// A selectable tile: A a flood outline on a lifted fill, B a pearl outline, C fills cobalt.
struct SettingsChoiceSurface: ViewModifier {
    var isSelected: Bool
    var radius: CGFloat?
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius ?? look.radius.tile, style: .continuous)
        let base = onSheet ? look.surfaceSheet : look.surface
        switch look.id {
        case .floodlight:
            content
                .background(isSelected ? look.surfaceRaised : base, in: shape)
                .overlay { shape.strokeBorder(isSelected ? look.textPrimary : look.hairline, lineWidth: isSelected ? 2 : 1) }
        case .anatomy:
            content
                .background(base, in: shape)
                .background { if isSelected { shape.fill(look.selectionFill) } }
                .overlay { shape.strokeBorder(isSelected ? look.textPrimary : look.hairline, lineWidth: isSelected ? 1.5 : 1) }
        case .paper, .carbon:
            content
                .background(isSelected ? look.action : base, in: shape)
                .overlay { shape.strokeBorder(look.outline, lineWidth: isSelected ? look.stroke.primary : look.stroke.pressable) }
        }
    }
}

// MARK: - Notice

/// One short consequence line with its glyph.
struct SettingsNotice: View {
    var symbol: String
    var text: String
    var emphasized = false
    var tint: Color?
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.system(.footnote, weight: .bold))
            Text(text)
                .font(.system(.footnote, weight: emphasized ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint ?? (emphasized ? look.textPrimary : look.textSecondary))
        .padding(.horizontal, 4)
    }
}

// MARK: - Row

/// A settings row: glyph · title (and subtitle) · trailing view · chevron when it opens something.
/// Title and trailing stack at accessibility sizes instead of squeezing.
struct SettingsRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var symbol: String
    var showsChevron: Bool
    /// Keep the trailing control on the trailing edge at accessibility sizes (a switch), aligned
    /// to the title's first line, while the title and subtitle wrap beside it.
    var trailingStaysInline: Bool
    var action: (() -> Void)?
    @ViewBuilder var trailing: Trailing
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    init(_ title: String, subtitle: String? = nil, symbol: String, showsChevron: Bool = true,
         trailingStaysInline: Bool = false, action: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.showsChevron = showsChevron
        self.trailingStaysInline = trailingStaysInline
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        if let action {
            Button(action: action) { row }.buttonStyle(SettingsRowPressStyle())
        } else {
            row
        }
    }

    private var row: some View {
        let ax = typeSize.isAccessibilitySize
        return HStack(alignment: ax ? .top : .center, spacing: 12) {
            LookIcon(symbol, style: .body)
                .foregroundStyle(look.settingsGlyphTint)
                .frame(width: glyphColumn)
            if ax && trailingStaysInline {
                titles.frame(maxWidth: .infinity, alignment: .leading)
                trailing
            } else if ax {
                VStack(alignment: .leading, spacing: 8) {
                    titles
                    trailing
                }
            } else {
                titles
                Spacer(minLength: 8)
                trailing
            }
            if showsChevron {
                if ax { Spacer(minLength: 0) }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 52 : 62, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(look.settingsRowTitle)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? look.pressedFill : .clear)
            .contentShape(Rectangle())
    }
}

// MARK: - Zone ladder

/// The five training zones as a ramp of lit segments with each zone's lower bound under it
/// (Warm-up sits below Zone 1 and is left out). Plain numbers; VoiceOver reads the zones.
struct SettingsZoneLadder: View {
    var rows: [ZoneRow]
    @Environment(\.look) private var look

    var body: some View {
        let zones = rows.filter { $0.zone != .warm }
        HStack(alignment: .top, spacing: 4) {
            ForEach(zones) { row in
                VStack(alignment: .leading, spacing: 5) {
                    Capsule()
                        .fill(look.zone(row.zone))
                        .frame(height: 8)
                    Text("\(row.lowerBound)")
                        .font(.system(.caption2, weight: .semibold).monospacedDigit())
                        .foregroundStyle(look.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(zones.map { "\($0.zone.label) from \($0.lowerBound)" }.joined(separator: ", "))
    }
}

// MARK: - Stat strip

struct SettingsStat: Identifiable {
    var id: String { label }
    var value: String
    var label: String
    var isWord = false
}

/// Big numbers, small labels (A one panel with rules, B tiles, C one ticket); rows at AX.
struct SettingsStatStrip: View {
    var stats: [SettingsStat]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 { LookDivider() }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        value(stat)
                        Spacer(minLength: 8)
                        label(stat).multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .lookSurface(.stat)
        } else if look.id == .anatomy {
            HStack(spacing: 10) {
                ForEach(stats) { stat in
                    cell(stat)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lookSurface(.stat)
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 { LookDivider(vertical: true) }
                    cell(stat)
                        .padding(.leading, 14)
                        .padding(.trailing, 8)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .lookSurface(.stat)
        }
    }

    private func cell(_ stat: SettingsStat) -> some View {
        VStack(alignment: .leading, spacing: look.id == .floodlight ? 3 : 2) {
            value(stat)
            label(stat)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.label) \(stat.value)")
    }

    private func value(_ stat: SettingsStat) -> some View {
        Group {
            if stat.isWord {
                Text(stat.value).font(look.settingsStatWord)
            } else if let number = Double(stat.value.replacingOccurrences(of: ",", with: "")) {
                CountUpText(number, duration: 0.7, countsFromZero: false) { Format.grouped($0) }
                    .font(look.font.statNumber)
            } else {
                Text(stat.value).font(look.font.statNumber)
            }
        }
        .foregroundStyle(look.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func label(_ stat: SettingsStat) -> some View {
        Text(look.id.isPaperClub ? stat.label.lowercased() : stat.label)
            .font(.system(.footnote, weight: look.id == .floodlight ? .regular : .semibold))
            .foregroundStyle(look.textSecondary)
            .lineLimit(1)
    }
}

// MARK: - Export file

enum SettingsExportFile {
    /// Writes a small real file for the share sheet (the prototype's stand-in for the export).
    static func write(_ fileName: String, format: ExportFormat, workouts: [Workout]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var text: String
        switch format {
        case .csv:
            var lines = ["date,workout,exercise,type,weight,unit,reps"]
            for workout in workouts.sorted(by: { $0.startedAt < $1.startedAt }) {
                for entry in workout.entries {
                    for set in entry.sets {
                        lines.append([Format.mediumDate(workout.startedAt).replacingOccurrences(of: ",", with: ""),
                                      workout.title, entry.exerciseName, set.type.displayName,
                                      set.weight.map(Format.number) ?? "", set.unit.label, set.reps.map(String.init) ?? ""]
                            .joined(separator: ","))
                    }
                }
            }
            text = lines.joined(separator: "\n")
        case .json:
            let items = workouts.sorted(by: { $0.startedAt < $1.startedAt }).map { workout in
                "  {\"workout\": \"\(workout.title)\", \"date\": \"\(Format.mediumDate(workout.startedAt))\", \"sets\": \(workout.setCount)}"
            }
            text = "[\n" + items.joined(separator: ",\n") + "\n]"
        }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Ask AI permissions

extension AIConsent {
    /// The permission's glyph (the feature it feeds).
    var settingsSymbol: String {
        switch self {
        case .photos: "camera.viewfinder"
        case .routine: "calendar"
        case .modelDetails: "tag"
        }
    }

    /// The row label under the "Send to OpenAI" header (PROPOSED: replaces the three
    /// "Send … to OpenAI" labels that repeated the same words).
    var settingsShortLabel: String {
        switch self {
        case .photos: "Equipment photos"
        case .routine: "Routine details"
        case .modelDetails: "Model details"
        }
    }

    /// The feature that uses it (existing feature names).
    var settingsFeature: String {
        switch self {
        case .photos: "Scan Machine"
        case .routine: "Ask AI for Templates"
        case .modelDetails: "Suggest exercises with AI"
        }
    }
}
