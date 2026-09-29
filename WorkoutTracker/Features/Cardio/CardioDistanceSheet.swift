import SwiftUI

/// C05 — Distance (Floodlight ticket 12): the manual distance for a cardio segment, live or
/// finished (a finished one is stamped edited by `CardioSession.enterDistance`, D47). A medium-detent
/// sheet so the segment's card stays in view. One big number to type (the machine's display), the
/// unit (km | mi — relabels, never converts what was typed), the average pace or speed the value
/// makes, and — when something measured the segment — Measured as the choice a blank field saves.
/// Save stays off until the value or unit changes (an unchanged save has nothing to record).
struct CardioDistanceSheet: View {
    var segment: CardioSegment
    @Environment(\.look) private var look
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text = ""
    @State private var unit: CardioDistanceUnit = .km
    @State private var initialText = ""
    @State private var initialUnit: CardioDistanceUnit = .km
    @State private var error: String?
    @State private var saves = 0
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 54
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26
    @Environment(\.dynamicTypeSize) private var typeSize

    private var seconds: Double { segment.activeDuration(at: segment.endedAt ?? .now) }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// The whole entry is checked as the domain will read it; nothing typed is filtered out
    /// (a pasted "-1" is refused, not turned into "1").
    private var isInvalid: Bool { CardioFormat.isInvalidEntry(text, unit: unit) }
    private var canSave: Bool { !isInvalid && (text != initialText || unit != initialUnit) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(cancel: { dismiss() }, title: "Distance", commit: save,
                        commitEnabled: canSave, commitIdentifier: "saveCardioDistance")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    context_
                    entry
                    SegmentedPills(CardioDistanceUnit.allCases.map(\.rawValue), selection: unitIndex)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Unit")
                        .accessibilityIdentifier("cardioDistanceUnit")
                    if isInvalid || error != nil {
                        Label(error ?? CardioSessionError.invalidDistance.localizedDescription,
                              systemImage: "exclamationmark.circle.fill")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(look.destructive)
                    }
                    readouts
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .lookSheetGround()
        .presentationDetents([.medium, .large])
        .presentationBackground(look.groundSheet)
        .sensoryFeedback(.success, trigger: saves)
        .onAppear {
            unit = segment.manualDistanceUnitRawValue.flatMap(CardioDistanceUnit.init(rawValue:)) ?? segment.unit
            text = segment.manualDistanceValue.map(String.init(describing:)) ?? ""
            initialText = text
            initialUnit = unit
        }
    }

    /// Which segment this is: its figure, name and active time.
    private var context_: some View {
        HStack(spacing: 8) {
            Image(systemName: segment.activity.symbol).font(.system(.subheadline, weight: .semibold))
            Text("\(segment.activity.name) · \(Format.elapsed(seconds: Int(seconds)))")
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(look.textSecondary)
        .accessibilityElement(children: .combine)
    }

    /// The number to type. Blank shows "—": the Measured row says what a blank saves.
    private var entry: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            TextField("Distance", text: $text, prompt: Text("—").foregroundStyle(look.textTertiary))
                .font(look.cardioHeroFont(size: numberSize))
                .foregroundStyle(look.textPrimary)
                .keyboardType(.decimalPad)
                .focused($focused)
                .lineLimit(1)
                .fixedSize()
                .tint(look.actionText)
                .accessibilityLabel("Distance")
                .accessibilityIdentifier("cardioDistanceField")
                .onChange(of: text) { _, new in
                    error = nil
                    // The big field has room for about seven characters. Only what the user types
                    // is capped — the value loaded from the segment is never rewritten (it would
                    // enable Save and restate a stored distance nobody touched).
                    if focused, new.count > Self.maxTyped { text = String(new.prefix(Self.maxTyped)) }
                }
            Text(unit.rawValue)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(look.textSecondary)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .snappy, value: unit)
            Spacer(minLength: 0)
            if focused {
                Button { focused = false } label: {
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
                    .strokeBorder(look.textPrimary.opacity(0.5), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: focused)
    }

    private static let maxTyped = 7

    /// What Save would record: the typed value in the chosen unit, else the measured distance.
    private var effectiveMeters: Double? {
        if !trimmed.isEmpty {
            guard !isInvalid, let value = CardioFormat.parse(trimmed) else { return nil }
            return value * unit.metersPerUnit
        }
        return segment.automaticDistanceMeters
    }

    private var readouts: some View {
        let usesSpeed = segment.activity.usesSpeed
        let rateValue = usesSpeed
            ? CardioFormat.speed(meters: effectiveMeters, seconds: seconds, unit: unit)
            : CardioFormat.pace(meters: effectiveMeters, seconds: seconds, unit: unit)
        let rateUnit = usesSpeed ? CardioFormat.speedUnit(unit) : CardioFormat.paceUnit(unit)
        let usingMeasured = trimmed.isEmpty
        return LookList {
            rateRow(title: usesSpeed ? "Average speed" : "Average pace", value: rateValue, unit: rateUnit)
            if let measured = segment.automaticDistanceMeters {
                LookRow("Measured", symbol: CardioFormat.distanceSymbol, showsChevron: false, action: {
                    text = ""
                    focused = false
                }) {
                    HStack(spacing: 10) {
                        Text("\(CardioFormat.distance(measured, unit)) \(unit.rawValue)")
                            .font(look.font.subhead)
                            .monospacedDigit()
                            .foregroundStyle(look.textSecondary)
                        Image(systemName: usingMeasured ? "checkmark.circle.fill" : "circle")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(usingMeasured ? look.selection : look.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint("Uses the measured distance")
                .accessibilityAddTraits(usingMeasured ? .isSelected : [])
                .accessibilityIdentifier("cardioMeasuredDistance")
            }
        }
    }

    /// What the distance makes of the segment: a row like the list's, its figure never broken — at
    /// accessibility sizes the title goes over the figure rather than breaking mid-word beside it.
    private func rateRow(title: String, value: String, unit: String) -> some View {
        let figure = HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(look.font.smallNumber)
                .foregroundStyle(value == "—" ? look.textTertiary : look.textPrimary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: value)
            if value != "—" { Text(unit).font(look.cardioUnitFont).foregroundStyle(look.textSecondary) }
        }
        .fixedSize()
        let label = Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
        return HStack(spacing: 12) {
            LookIcon("stopwatch", style: .body).foregroundStyle(look.textSecondary).frame(width: glyphColumn)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { label; figure }
                Spacer(minLength: 0)
            } else {
                label
                Spacer(minLength: 8)
                figure
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value == "—" ? "\(title), none" : "\(title), \(value) \(unit)")
    }

    private var unitIndex: Binding<Int> {
        Binding(get: { CardioDistanceUnit.allCases.firstIndex(of: unit) ?? 0 },
                set: { unit = CardioDistanceUnit.allCases[$0] })
    }

    private func save() {
        guard canSave else { return }
        do {
            try CardioSession(context: context).enterDistance(text, unit: unit, for: segment)
            focused = false
            saves += 1
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
