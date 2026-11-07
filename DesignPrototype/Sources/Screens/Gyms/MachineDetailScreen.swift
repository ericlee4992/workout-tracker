import SwiftUI

// G04 Machine Detail — the machine's own page (the real app had none). Identity (equipment
// glyph, movement label, model, type), its history here (times used, last used, sets), the
// bests it holds per exercise/preset as the bold element with the top one charted (every new
// best labelled with its set), then Setup (name, default unit, usual preset), the exercises it
// serves, the model with Correct / Choose / Rename Model…, and Delete Machine… (confirmed).
// One header style (SectionHeader) for every section. Every best opens its progress chart.
//
// Capture variants (G04): "unused" (Smith Machine), "nomodel" (Biceps Curl), "assisted"
// (Assist Dip/Chin), "usual" (Seated Row, usual preset), "custom" (a user-made model),
// "rename" (its Rename Model alert), "p2", "p3".

struct MachineDetailScreen: View {
    let machineID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var titleVisible = false
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var nameDraft = ""
    @State private var confirmDelete = false
    @State private var renameShown = false
    @State private var renameMaker = ""
    @State private var renameModel = ""
    @State private var savedTick = 0
    @State private var captureMachineID: UUID?
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    private var shownID: UUID { captureMachineID ?? machineID }

    var body: some View {
        Group {
            if let machine = store.machine(shownID) {
                content(machine)
            } else {
                Color.clear.lookScreenBackground()
            }
        }
        .onAppear(perform: appear)
    }

    private func content(_ machine: Machine) -> some View {
        let stats = store.machineStats(machine.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                hero(machine)
                if stats.timesUsed > 0 {
                    GymsStatStrip(stats: statItems(stats))
                }
                bests(machine, stats: stats)
                setup(machine)
                exercises(machine)
                modelSection(machine)
                DestructiveRowButton("Delete Machine…") { confirmDelete = true }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollPosition($scroll)
        .gymsCapturePaging(GymsCapture.variant(.g04, store: store, router: router), position: $scroll)
        .gymsScrolledPast(56, into: $titleVisible)
        .scrollDismissesKeyboard(.interactively)
        .lookScreenBackground()
        .gymsInlineTitle(machine.label, visible: titleVisible)
        .onChange(of: machine.id, initial: true) { _, _ in nameDraft = machine.label }
        .alert("Delete \(machine.label)?", isPresented: $confirmDelete) {
            Button("Delete Machine", role: .destructive) {
                store.deleteMachine(machine.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It disappears from this gym. Workouts you already logged with it keep it.")
        }
        .alert("Rename Model", isPresented: $renameShown) {
            TextField("Manufacturer", text: $renameMaker)
            TextField("Model", text: $renameModel)
            Button("Save") {
                if let id = machine.modelID, store.renameModel(id, manufacturer: renameMaker, modelName: renameModel) {
                    savedTick += 1
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("History keeps the captured name.")
        }
        .sensoryFeedback(.selection, trigger: savedTick)
    }

    // MARK: Hero

    private func hero(_ machine: Machine) -> some View {
        let model = store.model(machine.modelID)
        let category = store.gymsCategory(of: machine)
        return HStack(alignment: .top, spacing: 14) {
            GymsEquipmentDisc(category: category, size: typeSize.isAccessibilitySize ? 48 : 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(machine.label)
                    .font(look.font.title)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(model?.displayName ?? "No model")
                    .font(look.font.subhead)
                    .foregroundStyle(model == nil ? look.textTertiary : look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if category != nil || model?.isSeeded == false || machine.defaultUnit != nil {
                    GymsFlow(spacing: 6) {
                        if let category { GymsTag(category.label, category: .some(category)) }
                        if let model, !model.isSeeded { GymsTag("Custom") }
                        if let unit = machine.defaultUnit { GymsTag(unit.label) }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func statItems(_ stats: MachineStats) -> [GymsStat] {
        var items = [GymsStat.count(stats.timesUsed, "Times used")]
        if let last = stats.lastUsed {
            items.append(GymsStat(value: GymsDate.label(last, now: store.now), label: "Last used", isWord: true))
        }
        items.append(GymsStat.count(stats.setCount, stats.setCount == 1 ? "Set" : "Sets"))
        return items
    }

    // MARK: Bests (the bold element)

    @ViewBuilder
    private func bests(_ machine: Machine, stats: MachineStats) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Bests")
            if stats.bests.isEmpty {
                // Not yet: the dashed "not yet" edge, no invented numbers.
                HStack(spacing: 12) {
                    Image(systemName: look.previousPerformanceSymbol)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    Text("Not used yet")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 64)
                .dashedOutline(look.id.isPaperClub ? look.textSecondary : look.dash, radius: look.radius.panel,
                               lineWidth: look.id.isPaperClub ? 2 : 1.5)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(stats.bests.enumerated()), id: \.element.id) { index, best in
                        if index > 0 { LookDivider().padding(.leading, 16) }
                        if index == 0 {
                            GymsTopBest(machineID: machine.id, best: best) { open(best, machine) }
                        } else {
                            GymsBestRow(best: best) { open(best, machine) }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
                .lookSurface(.panel)
            }
        }
    }

    private func open(_ best: MachineBest, _ machine: Machine) {
        router.push(.progress(exerciseID: best.exerciseID, variationID: store.gymsVariationID(machineID: machine.id, best: best)))
    }

    // MARK: Setup (D2: editable where shown)

    private func setup(_ machine: Machine) -> some View {
        let exerciseIDs = store.exerciseIDs(of: machine)
        let presetExercise = exerciseIDs.count == 1 ? store.exercise(exerciseIDs.first) : nil
        let ax = typeSize.isAccessibilitySize
        let gymUnit = store.gymsGymUnit(machine.gymID).label
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Setup")
            LookList {
                let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    fieldLabel("Name")
                    HStack(spacing: 8) {
                        TextField("Name", text: $nameDraft)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .multilineTextAlignment(ax ? .leading : .trailing)
                            .tint(look.actionText)
                            .submitLabel(.done)
                            .focused($nameFocused)
                            .onSubmit { commitName(machine) }
                            .onChange(of: nameFocused) { _, focused in if !focused { commitName(machine) } }
                        Image(systemName: "pencil")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(look.textTertiary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, ax ? 10 : 0)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { nameFocused = true }

                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("Default unit")
                    GymsUnitChoice(options: ["Gym (\(gymUnit))", "kg", "lb"],
                                   selection: Binding(get: { machine.defaultUnit.gymsSegment }, set: { index in
                                       var m = machine
                                       m.defaultUnit = WeightUnit?.gymsFromSegment(index)
                                       store.updateMachine(m)
                                       savedTick += 1
                                   }))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let exercise = presetExercise, !exercise.presets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Usually")
                        GymsFlow(spacing: 8) {
                            Chip("Ask each time", isSelected: machine.defaultPresetID == nil) { setPreset(nil, machine) }
                            ForEach(exercise.presets) { preset in
                                Chip(preset.name, isSelected: machine.defaultPresetID == preset.id) { setPreset(preset.id, machine) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, weight: .medium))
            .foregroundStyle(look.textSecondary)
    }

    private func commitName(_ machine: Machine) {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { nameDraft = machine.label; return }
        guard trimmed != machine.label else { return }
        var m = machine
        m.label = trimmed
        store.updateMachine(m)
        savedTick += 1
    }

    private func setPreset(_ id: UUID?, _ machine: Machine) {
        var m = machine
        m.defaultPresetID = id
        store.updateMachine(m)
        savedTick += 1
    }

    // MARK: Exercises served

    @ViewBuilder
    private func exercises(_ machine: Machine) -> some View {
        let list = store.exerciseIDs(of: machine).compactMap { store.exercise($0) }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Exercises")
                LookList {
                    ForEach(list) { exercise in
                        LookRow(exercise.name, subtitle: exercise.muscleGroup?.label,
                                value: exercise.loadType == .weighted ? nil : exercise.loadType.badge) {
                            router.push(.exerciseDetail(exerciseID: exercise.id))
                        }
                    }
                }
            }
        }
    }

    // MARK: Model

    private func modelSection(_ machine: Machine) -> some View {
        let model = store.model(machine.modelID)
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Model")
            LookList {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model?.modelName ?? "No model")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(model == nil ? look.textSecondary : look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let model {
                            Text(model.manufacturer)
                                .font(look.font.footnote)
                                .foregroundStyle(look.textSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if let model, !model.isSeeded { GymsTag("Custom") }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 60)

                if model == nil {
                    LookRow("Choose Model…", symbol: "magnifyingglass") {
                        GymsPickerContext.gymID = machine.gymID
                        router.present(.modelPicker(machineID: machine.id))
                    }
                } else {
                    LookRow("Correct Model…", symbol: "arrow.triangle.2.circlepath") {
                        router.present(.modelCorrection(machineID: machine.id))
                    }
                }
                if let model, !model.isSeeded {
                    LookRow("Rename Model…", symbol: "character.cursor.ibeam") { beginRename(model) }
                }
            }
        }
    }

    private func beginRename(_ model: EquipmentModel) {
        renameMaker = model.manufacturer
        renameModel = model.modelName
        renameShown = true
    }

    // MARK: Capture variants

    private func appear() {
        guard !appeared else { return }
        appeared = true
        guard machineID == store.screenTarget.machineID,
              let variant = GymsCapture.take(.g04, store: store, router: router),
              let id = GymsCapture.machineOverride(variant, store: store) else { return }
        captureMachineID = id
        if variant == "rename", let model = store.model(store.machine(id)?.modelID) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { beginRename(model) }
        }
    }
}

// MARK: - Best card pieces

/// The machine's most-used record: the exercise, the best set in the look's best vocabulary,
/// how many workouts it spans, and its best set per session here, each new best labelled.
private struct GymsTopBest: View {
    var machineID: UUID
    var best: MachineBest
    var action: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look

    var body: some View {
        let points = store.gymsSeries(machineID: machineID, best: best)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(best.label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if best.loadType == .assisted { GymsTag(best.loadType.badge) }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                }
                GymsBestValue(text: Format.set(best.value, loadType: best.loadType), font: look.font.heroNumber)
                Text(Format.count(best.timesUsed, "workout"))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                if points.count >= 2 {
                    GymsBestChart(points: points, loadType: best.loadType, unit: best.value.unit, height: 168)
                        // Set labels and axis dates collide above xLarge; the figures above carry the value.
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(GymsRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(points))
        .accessibilityAddTraits(.isButton)
    }

    private func accessibilityText(_ points: [ProgressPoint]) -> String {
        var parts = [best.label, "best \(Format.set(best.value, loadType: best.loadType))"]
        if best.loadType == .assisted { parts.append(best.loadType.badge) }
        parts.append(Format.count(best.timesUsed, "workout"))
        let records = points.filter(\.isRecord).map { Format.setShort($0.best, loadType: best.loadType) }
        if !records.isEmpty { parts.append("New bests: \(records.joined(separator: ", "))") }
        return parts.joined(separator: ", ")
    }
}

private struct GymsBestRow: View {
    var best: MachineBest
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
            HStack(spacing: 10) {
                layout {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(best.label)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if best.loadType == .assisted { GymsTag(best.loadType.badge) }
                            Text(Format.count(best.timesUsed, "workout"))
                                .font(look.font.footnote)
                                .foregroundStyle(look.textSecondary)
                        }
                    }
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    GymsBestValue(text: Format.set(best.value, loadType: best.loadType), font: look.font.fieldNumber, prominent: false)
                        .fixedSize()
                }
                if typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(GymsRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(best.label), best \(Format.set(best.value, loadType: best.loadType)), \(Format.count(best.timesUsed, "workout"))")
        .accessibilityAddTraits(.isButton)
    }
}
