import SwiftUI

// PROTOTYPE — X01 Settings (pushed from the Workout tab's gear). The real screen was one
// headerless stock list of six unrelated rows; here it is grouped and graphic. The bold
// element is Units: two tiles showing the units you'll see ("lb · mi"), with one line saying
// logged sets keep theirs. Workout groups the m:ss rest steppers with the template prompt
// switch (renamed from "Suppress template update prompts", inverted). Heart-rate zones show the
// zone ramp with each lower bound and open the zones sheet (L12's sheet). Ask AI (the stale
// "Ask AI about plates" label, renamed — a user decision) shows one status, On or Off, and
// opens its sheet. Export is one pressable card: what there is to export and when it last
// happened. The one-time history-update note sits in its own group at the end.

struct SettingsScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(LookModel.self) private var lookModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var titleVisible = false
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var page = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Settings")
                units
                appearance
                rest
                VStack(spacing: look.space.group) {
                    heartRate
                    general
                }
                export
                historyUpdate
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scroll)
        .settingsPaging(page, position: $scroll)
        .settingsScrolledPast(52, into: $titleVisible)
        .lookScreenBackground()
        .proposalScreen("settings")
        .settingsInlineTitle("Settings", visible: titleVisible)
        .sensoryFeedback(.selection, trigger: store.settings.unitSystem)
        .onAppear {
            if let variant = SettingsVariant.consume(.x01, store: store, router: router) {
                page = SettingsVariant.page(variant)
                if SettingsVariant.has(variant, "metric") { store.settings.unitSystem = .metric }
            }
        }
    }

    // MARK: Units (the bold element)

    private var units: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Units")
            layout {
                unitTile(.metric)
                unitTile(.usCustomary)
            }
            SettingsNotice(symbol: "scalemass", text: "Logged sets keep the unit they were entered in.")
                .padding(.top, 2)
        }
    }

    private func unitTile(_ system: UnitSystem) -> some View {
        let selected = store.settings.unitSystem == system
        return Button {
            if reduceMotion { store.settings.unitSystem = system } else {
                withAnimation(.snappy(duration: 0.25)) { store.settings.unitSystem = system }
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(system.label)
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(look.settingsChoiceSecondary(selected))
                    Spacer(minLength: 6)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(look.settingsChoiceText(true))
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(system.weight.label)
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.settingsChoiceText(selected))
                    Text(system.distance.label)
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.settingsChoiceSecondary(selected))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .settingsChoiceSurface(isSelected: selected)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("\(system.label), \(system.weight.label) and \(system.distance.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Appearance

    /// System / Light / Dark: the app's colour scheme (the final look's light or dark token
    /// set). The study looks keep their one finish, so the control says so there.
    private var appearance: some View {
        let options = Appearance.allCases
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Appearance")
            SegmentedPills(options.map(\.label), selection: Binding(
                get: { options.firstIndex(of: lookModel.appearance) ?? 0 },
                set: { lookModel.appearance = options[$0] }))
                .accessibilityLabel("Appearance")
            if !lookModel.id.followsAppearance {
                SettingsNotice(symbol: "circle.lefthalf.filled", text: "This study look keeps its own finish.")
                    .padding(.top, 2)
            }
        }
        .sensoryFeedback(.selection, trigger: lookModel.appearance)
    }

    // MARK: Workout (rest defaults and the template prompt)

    private var rest: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Workout")
            LookList(separatorInset: 54) {
                SettingsRow("Working rest", symbol: "hourglass", showsChevron: false) {
                    NumberStepperPill(value: restBinding(\.workingRestSeconds), range: 0...600, step: 15) { Format.rest($0) }
                        .accessibilityLabel("Working rest")
                }
                SettingsRow("Warmup rest", symbol: "hourglass.bottomhalf.filled", showsChevron: false) {
                    NumberStepperPill(value: restBinding(\.warmupRestSeconds), range: 0...600, step: 15) { Format.rest($0) }
                        .accessibilityLabel("Warmup rest")
                }
                SettingsRow("Ask to update templates", symbol: "square.on.square", showsChevron: false,
                            trailingStaysInline: true) {
                    Toggle(isOn: Binding(get: { !store.settings.suppressTemplatePrompts },
                                         set: { store.settings.suppressTemplatePrompts = !$0 })) { EmptyView() }
                        .toggleStyle(.settings)
                        .fixedSize()
                        .accessibilityLabel("Ask to update templates")
                }
            }
        }
    }

    private func restBinding(_ key: WritableKeyPath<AppSettings, Int>) -> Binding<Int> {
        Binding(get: { store.settings[keyPath: key] }, set: { store.settings[keyPath: key] = $0 })
    }

    // MARK: Heart rate

    private var heartRate: some View {
        let max = store.maxHeartRate
        return Button { router.present(.maxHeartRate) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.heartRate)
                        .frame(width: 26)
                    Text("Heart rate zones")
                        .font(look.settingsRowTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let max {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(max)").font(look.font.statNumber).foregroundStyle(look.textPrimary)
                            Text("bpm").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                        }
                        .fixedSize()
                    } else {
                        Text("Not set").font(look.font.subhead).foregroundStyle(look.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                }
                if max != nil {
                    SettingsZoneLadder(rows: store.zoneRows)
                        .padding(.leading, 38)
                } else {
                    SettingsNotice(symbol: "plus.circle", text: "Set up zones").padding(.leading, 34)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(max.map { "Heart rate zones, maximum \($0) beats per minute" } ?? "Heart rate zones, Not set")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Ask AI

    /// "Ask AI" (was "Ask AI about plates": the sheet now covers scanning, routines and model
    /// suggestions — the rename is a user decision). One status value; the key and the three
    /// permissions live in the sheet.
    private var general: some View {
        let on = store.settings.aiKeySaved
        return Button { router.present(.aiSettings) } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.settingsGlyphTint)
                    .frame(width: 26)
                Text("Ask AI")
                    .font(look.settingsRowTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(on ? "On" : "Off")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .lookSurface(.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(on ? "Ask AI, On" : "Ask AI, Off")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Export

    /// One pressable card (C: the 2 pt pressable outline, like Heart rate zones and Ask AI).
    private var export: some View {
        let counts = store.exportCounts
        let summary = "\(Format.count(counts.workouts, "workout")) · \(Format.count(counts.sets, "set"))"
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Export")
            Button { router.push(.export) } label: {
                SettingsRow(summary, subtitle: lastExportLine, symbol: "square.and.arrow.up", showsChevron: true) { EmptyView() }
                    .lookSurface(.tile)
                    .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
            }
            .buttonStyle(.lookPressable)
            if SettingsDates.showsOnlyCopyNotice(lastExport: store.settings.lastExportAt, now: store.now) {
                SettingsNotice(symbol: "iphone", text: "This phone holds the only copy until you export.")
                    .padding(.top, 2)
            }
        }
    }

    /// The one-time D51 note, in its own group at the end (it is not part of Export).
    @ViewBuilder private var historyUpdate: some View {
        if let note = store.settings.historyUpdate {
            LookList(separatorInset: 54) {
                SettingsRow("History update",
                            subtitle: "\(Format.count(note.setCount, "set")) moved to dumbbell exercises",
                            symbol: "arrow.triangle.2.circlepath", showsChevron: false) {
                    Text(Format.shortDate(note.date))
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .accessibilityLabel(Format.mediumDate(note.date))
                }
            }
        }
    }

    private var lastExportLine: String? {
        guard let date = store.settings.lastExportAt else { return nil }
        let format = store.settings.lastExportFormat.map { " · \($0.label)" } ?? ""
        return "Last export \(SettingsDates.relative(date, now: store.now))\(format)"
    }
}
