import SwiftUI

// PROTOTYPE — L09 Bar for a bar-mode entry. The top card is the plate math for the set you
// opened it from, drawn plainly: the bar with its plates, then "bar + per side × 2 = total".
// Picking a bar is staged (Done commits) so the math answers each tap: the total you typed is
// kept and the per-side number and plates move (a 35 lb bar turns 45 + 45 × 2 = 135 into
// 35 + 50 × 2 = 135). Bars are tiles, number big and name small, the entry's unit first;
// then a custom bar and No bar. The bar sets the row's unit (D40). The plates are sized and
// toned by weight, with the per-side plates listed under the diagram. The other unit's bars
// fold behind their header until opened (open when one of them is in use).
// Variants: "womens" (35 lb bar staged), "nobar", "custom" (a typed 30 lb bar, field focused).

enum LiveSheetsBarChoice: Hashable {
    case none
    case preset(Double, WeightUnit)
    case custom
}

struct BarPickerSheet: View {
    let entryID: UUID
    let setID: UUID?

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var environmentTypeSize
    /// The sheet root sits outside its own `.dynamicTypeSize` override, so it resolves the
    /// prototype override itself (children read the environment as usual).
    private var typeSize: DynamicTypeSize { router.dynamicTypeOverride ?? environmentTypeSize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var choice: LiveSheetsBarChoice = .none
    @State private var customText = ""
    @State private var customUnit: WeightUnit = .lb
    @State private var loaded = false
    @State private var page: Int?
    @State private var showsOtherUnit = false
    @FocusState private var customFocused: Bool

    private var entry: LiveEntry? { store.liveEntry(entryID) }
    private var exercise: Exercise? { store.exercise(entry?.exerciseID) }
    /// The set the math is shown for: the one tapped, else the next unfinished one.
    private var targetSet: LiveSet? {
        guard let entry else { return nil }
        return entry.sets.first { $0.id == setID } ?? entry.sets.first { !$0.isCompleted } ?? entry.sets.last
    }
    private var rowUnit: WeightUnit { targetSet?.unit ?? entry?.sets.first?.unit ?? store.displayUnit }

    /// The staged bar (nil = No bar) and the unit it sets.
    private var draft: (bar: Double?, unit: WeightUnit) {
        switch choice {
        case .none: return (nil, rowUnit)
        case .preset(let w, let u): return (w, u)
        case .custom:
            let value = Double(customText.replacingOccurrences(of: ",", with: "."))
            return ((value ?? 0) > 0 ? value : nil, customUnit)
        }
    }
    private var customIsValid: Bool { choice != .custom || draft.bar != nil }

    /// The set's total: kept through a bar change (only the per-side field moves).
    private var total: Double? {
        guard let entry, let targetSet, targetSet.weight != nil else { return nil }
        return entry.total(of: targetSet)
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveSheetsHeader(title: "Bar", subtitle: exercise?.name,
                             leading: .cancel { router.dismissSheet() },
                             trailing: .commit("Done", enabled: customIsValid, action: commit))
            LiveSheetsScroll(page: page) {
                VStack(alignment: .leading, spacing: 22) {
                    mathCard
                    barGroup(rowUnit)
                    customBar
                    LookList {
                        LiveSheetsOptionRow(glyph: .symbol("scalemass"), title: "No bar", subtitle: "Enter the total weight",
                                            isSelected: choice == .none) { pick(.none) }
                    }
                    barGroup(rowUnit.toggled)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 48)
            }
        }
        .liveSheetsPresentation(look)
        .presentationDetents([.large])
        .sensoryFeedback(.selection, trigger: choice)
        .onAppear(perform: load)
    }


    // MARK: Plate math card (the bold element)

    private var mathCard: some View {
        let bar = draft.bar
        let unit = bar == nil ? rowUnit : draft.unit
        let perSide: Double? = {
            guard let bar, let total else { return nil }
            return max(0, (total - bar) / 2)
        }()
        return VStack(alignment: .leading, spacing: 14) {
            if let targetSet {
                Text(store.liveSheetsSetLabel(entryID: entryID, setID: targetSet.id))
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
            }
            if bar != nil {
                VStack(spacing: 10) {
                    LiveSheetsBarbellDiagram(perSide: perSide ?? 0, unit: unit, hasBar: true, height: 96)
                        .padding(.horizontal, -4)
                    let plates = LiveSheetsPlates.perSide(perSide ?? 0, unit: unit)
                    if !plates.isEmpty {
                        LiveSheetsPlateList(plates: plates, unit: unit)
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
            equation(bar: bar, perSide: perSide, unit: unit)
        }
        .padding(look.space.panelPadding + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: choice)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func equation(bar: Double?, perSide: Double?, unit: WeightUnit) -> some View {
        if let bar {
            let parts = HStack(alignment: .firstTextBaseline, spacing: 8) {
                term(Format.weight(bar), label: "Bar", value: bar)
                op("+")
                term(perSide.map(Format.weight) ?? "—", label: "Per side", value: perSide ?? 0)
                op("× 2")
                op("=")
                term(total.map(Format.weight) ?? "—", unit: unit.label, label: "Total", value: total ?? 0, isResult: true)
            }
            let stacked = VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    term(Format.weight(bar), label: "Bar", value: bar)
                    op("+")
                    term(perSide.map(Format.weight) ?? "—", label: "Per side", value: perSide ?? 0)
                    op("× 2")
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    op("=")
                    term(total.map(Format.weight) ?? "—", unit: unit.label, label: "Total", value: total ?? 0, isResult: true)
                }
            }
            if typeSize.isAccessibilitySize {
                stacked
            } else {
                ViewThatFits(in: .horizontal) { parts; stacked }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                term(total.map(Format.weight) ?? "—", unit: rowUnit.label, label: "Total", value: total ?? 0, isResult: true)
            }
        }
    }

    private func term(_ text: String, unit: String? = nil, label: String, value: Double, isResult: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(text)
                    .font(isResult ? look.font.heroNumber : look.font.statNumber)
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: value))
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
            }
            // The label may run past its number ("Per side" under "45") without pushing the
            // next operator away, so the equation keeps tight, even spacing.
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 0, alignment: .leading)
        }
        .fixedSize()
    }

    private func op(_ text: String) -> some View {
        Text(text)
            .font(.system(.title3, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
            .foregroundStyle(look.textTertiary)
            .fixedSize()
            .accessibilityHidden(true)
    }

    // MARK: Bar tiles

    private func barGroup(_ unit: WeightUnit) -> some View {
        let bars = SampleData.bars.filter { $0.unit == unit }
        let folds = unit != rowUnit
        let open = !folds || showsOtherUnit
        let title = unit == .lb ? "Pound bars" : "Kilogram bars"
        return VStack(alignment: .leading, spacing: 8) {
            if folds {
                Button {
                    if reduceMotion { showsOtherUnit.toggle() } else { withAnimation(.snappy(duration: 0.3)) { showsOtherUnit.toggle() } }
                } label: {
                    HStack(spacing: 6) {
                        Text(title)
                        Image(systemName: "chevron.right")
                            .font(.system(.caption, weight: .bold))
                            .rotationEffect(.degrees(open ? 90 : 0))
                        Spacer(minLength: 0)
                    }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .padding(.leading, 4)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue(open ? "Expanded" : "Collapsed")
            } else {
                Text(title)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            if open {
                Group {
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 10) { ForEach(bars, id: \.weight) { bar in barTile(bar) } }
                    } else {
                        HStack(alignment: .top, spacing: 10) { ForEach(bars, id: \.weight) { bar in barTile(bar) } }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func barTile(_ bar: (title: String, weight: Double, unit: WeightUnit)) -> some View {
        let selected = choice == .preset(bar.weight, bar.unit)
        return Button { pick(.preset(bar.weight, bar.unit)) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Format.weight(bar.weight))
                        .font(look.font.bigNumber)
                        .foregroundStyle(look.liveSheetsChoiceText(selected))
                    Text(bar.unit.label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.liveSheetsChoiceSecondary(selected))
                }
                Text(bar.title)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(look.liveSheetsChoiceSecondary(selected))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? nil : 100, alignment: .topLeading)
            .liveSheetsChoiceSurface(isSelected: selected, radius: look.radius.tile)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("\(bar.title), \(Format.weight(bar.weight, bar.unit))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Custom bar

    private var customBar: some View {
        let selected = choice == .custom
        return VStack(alignment: .leading, spacing: 8) {
            Text("Custom bar")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                TextField("Weight", text: $customText,
                          prompt: Text("Weight").font(.system(.body, weight: .regular)).foregroundStyle(look.textTertiary))
                    .keyboardType(.decimalPad)
                    .focused($customFocused)
                    .font(look.font.fieldNumber)
                    .foregroundStyle(look.textPrimary)
                    .tint(look.actionText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .lookSurface(.field)
                    .overlay {
                        // The bar in use: A / B a lit edge; C swaps its dashed well edge for the
                        // cobalt rule of a selected choice.
                        if selected {
                            RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                                .strokeBorder(look.id.isPaperClub ? look.actionText : look.textPrimary,
                                              lineWidth: look.id.isPaperClub ? 2.5 : 1.5)
                        }
                    }
                    .onChange(of: customText) { _, text in
                        if !text.isEmpty { pick(.custom) }
                    }
                    .accessibilityLabel("Custom bar weight")
                SegmentedPills(["kg", "lb"], selection: Binding(
                    get: { customUnit == .kg ? 0 : 1 },
                    set: { customUnit = $0 == 0 ? .kg : .lb; if !customText.isEmpty { pick(.custom) } }))
                    .frame(width: 128)
            }
        }
    }

    // MARK: Actions

    private func pick(_ next: LiveSheetsBarChoice) {
        if next != .custom { customFocused = false }
        guard next != choice else { return }
        if reduceMotion { choice = next } else { withAnimation(.snappy(duration: 0.3)) { choice = next } }
    }

    private func commit() {
        guard let entry else { router.dismissSheet(); return }
        let staged = draft
        if staged.bar != entry.barWeight || (staged.bar != nil && staged.unit != rowUnit) {
            store.setBar(staged.bar, unit: staged.bar == nil ? nil : staged.unit, entryID: entryID)
        }
        router.dismissSheet()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let variant = LiveSheetsVariant.consume([.l09], store: store, router: router)
        page = LiveSheetsVariant.page(variant)
        customUnit = rowUnit
        if let bar = entry?.barWeight {
            if SampleData.bars.contains(where: { $0.weight == bar && $0.unit == rowUnit }) {
                choice = .preset(bar, rowUnit)
            } else {
                customText = Format.weight(bar)
                choice = .custom
            }
        } else {
            choice = .none
        }
        if LiveSheetsVariant.has(variant, "womens") { choice = .preset(35, .lb) }
        if LiveSheetsVariant.has(variant, "nobar") { choice = .none }
        if LiveSheetsVariant.has(variant, "custom") {
            customUnit = rowUnit
            customText = "30"
            choice = .custom
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { customFocused = true }
        }
        if case .preset(_, let u) = choice, u != rowUnit { showsOtherUnit = true }
    }
}
