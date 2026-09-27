import SwiftData
import SwiftUI

/// D10's explicit model-correction prompt. Merely renaming a model never
/// rewrites history; changing which model a machine is attaches the selected
/// scope to the save operation.
///
/// Floodlight redesign ticket 07 (S07): what the model should be, then how far back it reaches.
/// The header names the machine; once a different model is picked it becomes the before → after
/// (the old model struck through). The model list: the current model, the likely corrections
/// (`ModelCorrection.suggestions`), a model picked from the catalog, None, and Catalog Model (the
/// full picker). The two scope tiles are the bold element, each with its timeline — one dot per
/// past workout on this machine, a "Today" tick, workouts to come — lit where the new model will
/// show; the past tile states what it rewrites. "Correct Model" is a neutral disabled capsule until
/// the model changes; with past workouts to rewrite it asks once before rewriting them.
struct MachineModelCorrectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var models: [EquipmentModel]
    var machine: MachineInstance
    /// The model the machine would have after the correction; nil = no model.
    @State private var model: EquipmentModel?
    @State private var loaded = false
    @State private var scope: ModelCorrectionScope = .futureOnly
    @State private var impact = ModelCorrection.Impact(workouts: 0, sets: 0)
    @State private var suggestionIDs: [UUID] = []
    @State private var showingCatalog = false
    @State private var confirmingPast = false
    @State private var failure: String?
    @State private var picks = 0
    @State private var commits = 0
    @State private var scopeFocus = 0

    private var currentModel: EquipmentModel? { machine.model }
    private var changes: Bool { loaded && model?.id != currentModel?.id }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScanTopBar(title: "Correct Model", onCancel: { dismiss() })
                ScanPagedScroll(focusID: "correctionScope", focusTick: scopeFocus) {
                    VStack(alignment: .leading, spacing: 22) {
                        ScanInlineTitle(title: "Correct Model")
                        header
                        modelList
                        scopeTiles.id("correctionScope")
                        if let failure {
                            Text(failure).font(look.font.subhead).foregroundStyle(look.destructive)
                        }
                    }
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                } bar: {
                    ScanBottomBar {
                        ScanPrimaryButton("Correct Model", symbol: "checkmark", enabled: changes, action: commit)
                            .accessibilityIdentifier("correctModel.commit")
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingCatalog) {
                ModelPickerView(selection: Binding(get: { model }, set: { picked in
                    pick(picked)
                }), gym: machine.gym)
                .toolbar(.visible, for: .navigationBar)
            }
        }
        .lookSheetGround()
        .onAppear(perform: load)
        .confirmationDialog(pastQuestion, isPresented: $confirmingPast, titleVisibility: .visible) {
            Button("Apply to Past Workouts Too") { apply() }
            Button("Cancel", role: .cancel) {}
        }
        .sensoryFeedback(.selection, trigger: picks)
        .sensoryFeedback(.success, trigger: commits)
    }

    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8) }

    private var pastQuestion: String {
        "Change the model in \(impact.workouts) past \(impact.workouts == 1 ? "workout" : "workouts")?"
    }

    private func load() {
        guard !loaded else { return }
        model = machine.model
        impact = (try? ModelCorrection.impact(of: machine, context: modelContext)) ?? impact
        suggestionIDs = ModelCorrection.suggestions(
            machineLabel: machine.label, exerciseIDs: machine.supportedExerciseIDs,
            currentModelID: machine.model?.id,
            among: models.map { .init(id: $0.id, modelName: $0.modelName, displayName: $0.displayName, exerciseIDs: $0.exerciseIDs) })
        loaded = true
    }

    private func pick(_ picked: EquipmentModel?) {
        picks += 1
        withAnimation(motion) { model = picked }
        // The next decision is how far back it reaches: bring the tiles up above the button.
        if changes { scopeFocus += 1 }
    }

    private func commit() {
        guard changes else { return }
        if scope == .applyToPast && impact.workouts > 0 {
            confirmingPast = true
        } else {
            apply()
        }
    }

    private func apply() {
        guard changes else { return }
        do {
            try EquipmentLifecycle(context: modelContext).correctModel(of: machine, to: model, scope: scope)
            commits += 1
            dismiss()
        } catch {
            failure = "Could not correct the model: \(error.localizedDescription)"
        }
    }

    // MARK: Header: the machine, and its model before → after

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                EquipmentTile(category: currentModel?.equipmentType, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.label)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let gym = machine.gym {
                        Text(gym.name).font(look.font.subhead).foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if changes {
                LookDivider()
                VStack(alignment: .leading, spacing: 6) {
                    modelLine(currentModel?.displayName, struck: true)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(look.selection)
                            .accessibilityHidden(true)
                        modelLine(model?.displayName, struck: false, emphasised: true)
                    }
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(look.space.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    private func modelLine(_ name: String?, struck: Bool, emphasised: Bool = false) -> some View {
        Text(name ?? "None")
            .font(emphasised ? .system(.title3, weight: .heavy) : .system(.body, weight: .semibold))
            .foregroundStyle(struck ? look.textTertiary : look.textPrimary)
            .strikethrough(struck, color: look.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Models

    private var listedModels: [EquipmentModel] {
        var rows: [EquipmentModel] = []
        if let currentModel { rows.append(currentModel) }
        rows += suggestionIDs.compactMap { id in models.first { $0.id == id } }
        // A model the catalog picker chose that is not among these.
        if let model, !rows.contains(where: { $0.id == model.id }) { rows.append(model) }
        return rows
    }

    private var modelList: some View {
        VStack(spacing: 0) {
            ForEach(listedModels, id: \.id) { row in
                modelRow(row, isCurrent: row.id == currentModel?.id)
                LookDivider().padding(.leading, 56)
            }
            Button { pick(nil) } label: {
                HStack(spacing: 14) {
                    ScanRadio(selected: loaded && model == nil)
                    Text("None")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
            .accessibilityAddTraits(model == nil ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("correctModel.none")
            LookDivider().padding(.leading, 56)
            LookRow("Catalog Model", symbol: "magnifyingglass", value: "\(models.count)") { showingCatalog = true }
                .accessibilityIdentifier("correctModel.catalog")
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
    }

    private func modelRow(_ row: EquipmentModel, isCurrent: Bool) -> some View {
        let selected = model?.id == row.id
        return Button { pick(row) } label: {
            HStack(spacing: 14) {
                ScanRadio(selected: selected)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.manufacturer)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    Text(row.modelName)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // At accessibility sizes the tag drops under the name instead of squeezing it.
                    if isCurrent && typeSize.isAccessibilitySize { currentTag.padding(.top, 4) }
                }
                Spacer(minLength: 8)
                if isCurrent && !typeSize.isAccessibilitySize { currentTag }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("correctModel.option.\(row.displayName)")
    }

    private var currentTag: some View {
        Text("Current")
            .font(look.font.badge)
            .foregroundStyle(look.textSecondary)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .overlay { Capsule().strokeBorder(look.hairline, lineWidth: 1) }
    }

    // MARK: Scope (the bold element)

    private var scopeTiles: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10))
                                                  : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            scopeTile(.futureOnly)
            scopeTile(.applyToPast)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func scopeTile(_ option: ModelCorrectionScope) -> some View {
        CorrectionScopeTile(option: option, pastCount: impact.workouts, setCount: impact.sets,
                            selected: scope == option) {
            picks += 1
            withAnimation(motion) { scope = option }
        }
    }
}

private extension ModelCorrectionScope {
    var title: String {
        switch self {
        case .futureOnly: "Future Workouts Only"
        case .applyToPast: "Apply to Past Workouts Too"
        }
    }
    var identifier: String {
        switch self {
        case .futureOnly: "futureOnly"
        case .applyToPast: "applyToPast"
        }
    }
}

/// A scope choice: glyph, radio and title over its own timeline. The selected tile takes a
/// flood-white edge on the raised fill and its dots light; the other's stay dim.
private struct CorrectionScopeTile: View {
    var option: ModelCorrectionScope
    var pastCount: Int
    var setCount: Int
    var selected: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: option == .futureOnly ? "arrow.right.circle" : "clock.arrow.circlepath")
                        .font(.system(.title3, weight: .semibold))
                        .accessibilityHidden(true)
                    Spacer()
                    ScanRadio(selected: selected)
                }
                // Side by side, both titles hold two lines so the two timelines line up.
                Text(option.title)
                    .font(.system(.subheadline, weight: .bold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(typeSize.isAccessibilitySize ? 6 : 2, reservesSpace: !typeSize.isAccessibilitySize)
                    .fixedSize(horizontal: false, vertical: true)
                CorrectionTimeline(pastCount: pastCount, includesPast: option == .applyToPast, lit: selected)
                if option == .applyToPast {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(pastCount)").font(look.font.smallNumber)
                        Text(pastCount == 1 ? "workout" : "workouts").font(look.font.caption).foregroundStyle(look.textSecondary)
                        Text("·").font(look.font.caption).foregroundStyle(look.textSecondary)
                        Text("\(setCount)").font(look.font.smallNumber)
                        Text(setCount == 1 ? "set" : "sets").font(look.font.caption).foregroundStyle(look.textSecondary)
                    }
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(look.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(selected ? look.surfaceRaised : look.surfaceSheet,
                        in: RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous)
                    .strokeBorder(selected ? look.done : look.hairline, lineWidth: selected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityValue(option == .applyToPast
                            ? "Rewrites \(pastCount) past \(pastCount == 1 ? "workout" : "workouts"), \(setCount) \(setCount == 1 ? "set" : "sets")"
                            : "Past workouts keep the old model")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("correctModel.scope.\(option.identifier)")
    }
}

/// One dot per past workout on this machine (at most ten), a "Today" tick, then three workouts
/// to come. Dots the new model reaches are filled — in the selection colour when the tile is
/// chosen, dim otherwise; dots it leaves alone are open rings. The past dots light right to left
/// (most recent first). Reduce Motion: they switch at once.
private struct CorrectionTimeline: View {
    var pastCount: Int
    var includesPast: Bool
    var lit: Bool
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var todayWidth: CGFloat = 0

    private let dot: CGFloat = 9
    private let futureCount = 3

    var body: some View {
        let shown = min(pastCount, 10)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(0..<shown, id: \.self) { i in
                        let delay = reduceMotion ? 0 : Double(shown - 1 - i) * 0.04
                        dotView(filled: includesPast)
                            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6).delay(delay), value: lit)
                    }
                }
                Rectangle()
                    .fill(look.textPrimary)
                    .frame(width: 2, height: dot + 8)
                    .padding(.horizontal, 6)
                HStack(spacing: 4) {
                    ForEach(0..<futureCount, id: \.self) { _ in dotView(filled: true) }
                }
                Spacer(minLength: 0)
            }
            // Centred under the tick, whose x is COMPUTED from the dots: measuring the tick and
            // moving the label by it fed back at AX sizes (a label wider than the dots before the
            // tick widened the stack, which moved the tick, which moved the label — a layout loop
            // that never let the app go idle). Only the label's own width is measured.
            Text("Today")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(look.textSecondary)
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { todayWidth = $0 }
                .padding(.leading, max(0, tickCentre(shown: shown) - todayWidth / 2))
        }
        .accessibilityHidden(true)
    }

    /// The tick's centre from the timeline's leading edge: the past dots, then the tick's padding.
    private func tickCentre(shown: Int) -> CGFloat {
        CGFloat(shown) * dot + CGFloat(max(0, shown - 1)) * 4 + 6 + 1
    }

    @ViewBuilder private func dotView(filled: Bool) -> some View {
        if filled {
            Circle()
                .fill(lit ? look.selection : look.textTertiary.opacity(0.55))
                .frame(width: dot, height: dot)
                .scaleEffect(lit || reduceMotion ? 1 : 0.85)
        } else {
            Circle()
                .strokeBorder(look.textTertiary.opacity(0.7), lineWidth: 1.5)
                .frame(width: dot, height: dot)
        }
    }
}
