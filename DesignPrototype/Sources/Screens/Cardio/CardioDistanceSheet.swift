import SwiftUI

// C05 — Distance: the manual distance for a cardio segment (live or finished; a finished one
// is stamped Edited by the Store). A medium-detent sheet so the ended segment's card stays in
// view above it. One big number to type (the machine's display), the unit (km | mi — relabels,
// never converts what was typed), the resulting average pace updating as you type, and the
// measured distance as the choice a blank field falls back to (a blank field shows "—"; the
// Measured row carries the number and its check). Save is the one filled command, a capsule
// like Cancel in every look, always ready (saving the measured value confirms it) unless the
// typed value is invalid.
// View-level variants: "typed" (2.4 typed, keyboard up), "invalid" (a lone "."), "km".

struct CardioDistanceSheet: View {
    let segmentID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text = ""
    @State private var unit: DistanceUnit = .mi
    @State private var loaded = false
    @State private var saves = 0
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 54

    var body: some View {
        let snap = store.cardioSegmentSnapshot(segmentID)
        VStack(spacing: 0) {
            CardioSheetHeader(title: "Distance", commitEnabled: canSave, cancel: { router.dismissSheet() }, commit: save)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let snap {
                        context(snap)
                        entry(snap)
                        SegmentedPills(DistanceUnit.allCases.map(\.label), selection: unitIndex)
                            .accessibilityLabel("Unit")
                        if isInvalid {
                            Label("Enter a distance of zero or more.", systemImage: "exclamationmark.circle.fill")
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(look.id == .floodlight ? look.destructive : look.textPrimary)
                        }
                        readouts(snap)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .lookSheetGround()
        .modifier(CardioTypeOverride(size: router.dynamicTypeOverride))
        .presentationDetents([.medium, .large])
        .presentationBackground(look.groundSheet)
        .sensoryFeedback(.success, trigger: saves)
        .onAppear { load(snap) }
    }

    // MARK: Parts

    /// Which segment this is: its figure, name and active time.
    private func context(_ snap: CardioSegmentSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: snap.activity.symbol).font(.system(.subheadline, weight: .semibold))
            Text("\(snap.activity.name) · \(Format.elapsed(snap.activeSeconds))")
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(look.textSecondary)
        .accessibilityElement(children: .combine)
    }

    /// The number to type. Blank shows "—": the Measured row below says what a blank saves.
    private func entry(_ snap: CardioSegmentSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            TextField("Distance", text: $text,
                      prompt: Text("—").foregroundStyle(look.textTertiary))
                .font(look.cardioHeroFont(size: numberSize))
                .foregroundStyle(look.textPrimary)
                .keyboardType(.decimalPad)
                .focused($focused)
                .lineLimit(1)
                .fixedSize()
                .tint(look.actionText)
                .accessibilityLabel("Distance")
                .onChange(of: text) { _, new in
                    let clean = CardioFormat.sanitize(new)
                    if clean != new { text = clean }
                }
            Text(unit.label)
                .font(.system(.title2, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                .foregroundStyle(look.textSecondary)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .snappy, value: unit)
            Spacer(minLength: 0)
            if focused {
                Button {
                    focused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide keyboard")
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.field, radius: look.radius.panel)
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
                    .strokeBorder(look.id.isPaperClub ? look.actionText : look.textPrimary.opacity(0.5), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: focused)
    }

    /// What the distance makes of the run (updates as you type), and the measured distance.
    private func readouts(_ snap: CardioSegmentSnapshot) -> some View {
        let meters = effectiveMeters(snap)
        let usesSpeed = snap.activity.usesSpeed
        let seconds = Double(snap.activeSeconds)
        let rateValue: String
        let rateUnit: String
        if usesSpeed {
            let perHour = meters.map { ($0 / unit.metersPerUnit) / max(1, seconds) * 3600 }
            rateValue = CardioFormat.speed(perHour)
            rateUnit = CardioFormat.speedUnit(unit)
        } else {
            let pace = meters.flatMap { $0 > 0 ? seconds / ($0 / unit.metersPerUnit) : nil }
            rateValue = CardioFormat.pace(pace)
            rateUnit = CardioFormat.paceUnit(unit)
        }
        let usingMeasured = text.trimmingCharacters(in: .whitespaces).isEmpty
        return LookList {
            LookRow(usesSpeed ? "Average speed" : "Average pace", symbol: "stopwatch", showsChevron: false) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(rateValue)
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: rateValue)
                    if rateValue != "—" {
                        Text(rateUnit).font(look.cardioUnitFont).foregroundStyle(look.textSecondary)
                    }
                }
            }
            if let measured = measuredValue(snap) {
                LookRow("Measured", symbol: CardioStat.distanceSymbol, showsChevron: false, action: {
                    text = ""
                    focused = false
                }) {
                    HStack(spacing: 10) {
                        Text("\(CardioFormat.distanceValue(measured)) \(unit.label)")
                            .font(look.font.subhead)
                            .monospacedDigit()
                            .foregroundStyle(look.textSecondary)
                        Image(systemName: usingMeasured ? "checkmark.circle.fill" : "circle")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(usingMeasured ? look.selection : look.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .accessibilityHint("Uses the measured distance")
            }
        }
    }

    // MARK: Values

    private var unitIndex: Binding<Int> {
        Binding(get: { DistanceUnit.allCases.firstIndex(of: unit) ?? 0 },
                set: { unit = DistanceUnit.allCases[$0] })
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }

    private var isInvalid: Bool {
        guard !trimmed.isEmpty else { return false }
        guard let v = CardioFormat.parse(trimmed) else { return true }
        return v < 0 || !v.isFinite
    }

    /// Save is ready whenever the entry is valid: a blank saves the measured distance.
    private var canSave: Bool { !isInvalid }

    /// The measured distance in the chosen unit.
    private func measuredValue(_ snap: CardioSegmentSnapshot) -> Double? {
        snap.measuredMeters.map { $0 / unit.metersPerUnit }
    }

    /// What Save would record: the typed value in the chosen unit, else the measured distance.
    private func effectiveMeters(_ snap: CardioSegmentSnapshot) -> Double? {
        if !trimmed.isEmpty {
            guard let v = CardioFormat.parse(trimmed), v >= 0 else { return nil }
            return v * unit.metersPerUnit
        }
        return snap.measuredMeters
    }

    private func load(_ snap: CardioSegmentSnapshot?) {
        guard !loaded, let snap else { return }
        loaded = true
        text = snap.manualDistance.map { Format.number($0) } ?? ""
        unit = snap.unit
        let t = CardioVariants.tokens(router.variant)
        if t.contains("km") { unit = .km }
        if t.contains("typed") { text = "2.4" }
        if t.contains("invalid") { text = "." }
        if t.contains("typed") || t.contains("invalid") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
        }
    }

    private func save() {
        guard canSave else { return }
        let value = trimmed.isEmpty ? nil : CardioFormat.parse(trimmed)
        focused = false
        saves += 1
        store.setManualDistance(value, unit: unit, segmentID: segmentID)
        router.dismissSheet()
    }
}
