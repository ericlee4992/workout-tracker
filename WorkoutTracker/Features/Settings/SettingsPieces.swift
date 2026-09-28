import SwiftUI

// Floodlight ticket 09 — the pieces the three Settings screens share: the settings row, the
// consequence notice, the choice tile surface, the neutral flood switch, the zone ramp, the stat
// strip and the pressable card. Ported from the prototype's `SettingsSupport.swift` (Floodlight only).

// MARK: - Row

/// A settings row: glyph · title (and subtitle) · trailing view · chevron when it opens something.
/// At accessibility sizes the trailing view goes under the titles, except a switch
/// (`trailingStaysInline`), which keeps the trailing edge while the titles wrap beside it.
struct SettingsRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var symbol: String
    var symbolTint: Color?
    var showsChevron: Bool
    var trailingStaysInline: Bool
    @ViewBuilder var trailing: Trailing
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    init(_ title: String, subtitle: String? = nil, symbol: String, symbolTint: Color? = nil, showsChevron: Bool = false,
         trailingStaysInline: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.symbolTint = symbolTint
        self.showsChevron = showsChevron
        self.trailingStaysInline = trailingStaysInline
        self.trailing = trailing()
    }

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        HStack(alignment: ax ? .top : .center, spacing: 12) {
            LookIcon(symbol, style: .body)
                .foregroundStyle(symbolTint ?? look.textSecondary)
                .frame(width: glyphColumn)
            if ax && trailingStaysInline {
                titles.frame(maxWidth: .infinity, alignment: .leading)
                trailing
            } else if ax {
                VStack(alignment: .leading, spacing: 8) {
                    titles
                    trailing
                }
                Spacer(minLength: 0)
            } else {
                titles
                Spacer(minLength: 8)
                trailing
            }
            if showsChevron {
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
                .font(.system(.body, weight: .semibold))
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

extension SettingsRow where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, symbol: String, symbolTint: Color? = nil, showsChevron: Bool = false) {
        self.init(title, subtitle: subtitle, symbol: symbol, symbolTint: symbolTint, showsChevron: showsChevron) { EmptyView() }
    }
}

/// A destination card (Heart rate zones, Ask AI, Export): one pressable tile.
struct SettingsCardButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: Label
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .lookSurface(.tile)
                .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
    }
}

// MARK: - Notice

/// One short consequence line with its glyph.
struct SettingsNotice: View {
    var symbol: String
    var text: String
    var emphasized = false
    @Environment(\.look) private var look

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.system(.footnote, weight: .bold))
            Text(text)
                .font(.system(.footnote, weight: emphasized ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(emphasized ? look.textPrimary : look.textSecondary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Choice surface

extension View {
    /// A selectable tile: a flood (text-colour) outline on a lifted fill when selected, a
    /// hairline otherwise. Selection is a state, so it never takes the action colour.
    func settingsChoiceSurface(isSelected: Bool) -> some View {
        modifier(SettingsChoiceSurface(isSelected: isSelected))
    }
}

private struct SettingsChoiceSurface: ViewModifier {
    var isSelected: Bool
    @Environment(\.look) private var look
    @Environment(\.lookOnSheet) private var onSheet

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous)
        content
            .background(isSelected ? look.surfaceRaised : (onSheet ? look.surfaceSheet : look.surface), in: shape)
            .overlay { shape.strokeBorder(isSelected ? look.textPrimary : look.hairline, lineWidth: isSelected ? 2 : 1) }
    }
}

// MARK: - Switch

/// Settings switches are state, not action: ON is a flood (text-colour) track with a ground knob —
/// the same "lit" meaning as a selected unit tile — so violet stays on the one command (Save key,
/// Export CSV). VoiceOver and UI tests see a standard switch.
struct SettingsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        SettingsFloodSwitch(configuration: configuration)
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

// MARK: - Zone ramp

/// The five training zones as a ramp of lit segments, each zone's lower bound under it (Warm-up
/// sits below Zone 1 and is left out). Plain numbers (D52); VoiceOver reads the zones.
struct SettingsZoneLadder: View {
    var maxBpm: Int
    @Environment(\.look) private var look

    var body: some View {
        let zones = HeartRateZone.allCases.filter { $0 != .warm }
        HStack(alignment: .top, spacing: 4) {
            ForEach(zones, id: \.self) { zone in
                VStack(alignment: .leading, spacing: 5) {
                    Capsule()
                        .fill(look.zone(zone))
                        .frame(height: 8)
                    Text("\(HeartRateZones.lowerBound(of: zone, max: maxBpm))")
                        .font(.system(.caption2, weight: .semibold).monospacedDigit())
                        .foregroundStyle(look.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(zones.map { "\($0.label) from \(HeartRateZones.lowerBound(of: $0, max: maxBpm))" }
            .joined(separator: ", "))
    }
}

// MARK: - Stat strip

struct SettingsStat: Identifiable {
    var id: String { label }
    var value: Int
    var label: String
}

/// Big numbers, small labels: one panel with rules between the cells; rows at accessibility sizes.
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stat.label) \(stat.value)")
                }
            }
            .lookSurface(.stat)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 { LookDivider(vertical: true) }
                    VStack(alignment: .leading, spacing: 3) {
                        value(stat)
                        label(stat)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stat.label) \(stat.value)")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .lookSurface(.stat)
        }
    }

    private func value(_ stat: SettingsStat) -> some View {
        CountUpText(Double(stat.value), duration: 0.7, countsFromZero: false) { Int($0).formatted() }
            .font(look.font.statNumber)
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func label(_ stat: SettingsStat) -> some View {
        Text(stat.label)
            .font(look.font.footnote)
            .foregroundStyle(look.textSecondary)
            .lineLimit(1)
    }
}

// MARK: - Export counts

/// What the store holds for export: the one count both Settings' card and the Export screen show.
struct ExportCounts: Equatable {
    var workouts: Int
    var sets: Int
    var completedSets: Int
    /// Every workout's start, for the backup panel.
    var workoutDates: [Date]

    /// "87 workouts · 1,234 sets" — plus "(1,200 completed)" when some sets were never completed,
    /// as the old export footnote said.
    var summary: String {
        let workoutLabel = workouts == 1 ? "workout" : "workouts"
        let setLabel = sets == 1 ? "set" : "sets"
        return "\(workouts.formatted()) \(workoutLabel) · \(sets.formatted()) \(setLabel)"
            + (completedSets == sets ? "" : " (\(completedSets.formatted()) completed)")
    }
}
