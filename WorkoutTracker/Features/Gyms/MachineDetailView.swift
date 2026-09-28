import SwiftData
import SwiftUI

/// A machine's own page (Floodlight redesign ticket 06, G04 — new: the app edited machines only
/// through a context menu). Identity (equipment glyph, label, model, tags), its history here
/// (times used, last used, sets), the bests it holds per exercise / preset as the bold element
/// with the most-used one charted, then Setup (name, default unit, usual preset — each applies
/// immediately, D2), the exercises it serves, the model with Correct / Choose / Rename Model…,
/// and Delete Machine… (confirmed). Every best opens its progress chart on that exact variation.
struct MachineDetailView: View {
    var machine: MachineInstance
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allPreferences: [AppPreferences]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var finished: [Workout]
    @State private var use = MachineUse.unused
    @State private var sets: [RecordSetInput] = []
    @State private var nameDraft = ""
    @State private var titleInBar = false
    @State private var chartingBest: MachineBest?
    @State private var correcting = false
    @State private var deleting: MachineInstance?
    @State private var renamingModel: EquipmentModel?
    @State private var modelManufacturer = ""
    @State private var modelName = ""
    @State private var savedTick = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                hero
                if use.workouts > 0 {
                    GymStatStrip(stats: stats)
                }
                bests
                setup
                exercisesSection
                modelSection
                DestructiveRowButton("Delete Machine…") { deleting = machine }
                    .accessibilityIdentifier("machineDetail.delete")
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .lookScreenBackground()
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > 56
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .gymsInlineTitle(machine.label, visible: titleInBar)
        .onAppear(perform: rebuild)
        .onChange(of: historySignature) { _, _ in rebuild() }
        .onChange(of: machine.label, initial: true) { _, label in if !nameFocused { nameDraft = label } }
        .sensoryFeedback(.selection, trigger: savedTick)
        .deleteMachineConfirmation($deleting) { machine in
            do {
                try EquipmentLifecycle(context: modelContext).archive(machine)
                dismiss()
            } catch {
                assertionFailure("Failed to archive machine: \(error)")
            }
        }
        .sheet(item: $chartingBest) { best in
            NavigationStack {
                ExerciseProgressView(exerciseID: best.exerciseID, exerciseName: best.exerciseName,
                                     initialVariation: best.variation(on: machine.id))
            }
        }
        .sheet(isPresented: $correcting) {
            MachineModelCorrectionSheet(machine: machine)
        }
        .renameModelAlert($renamingModel, manufacturer: $modelManufacturer, modelName: $modelName)
    }

    // MARK: Hero

    private var hero: some View {
        let model = machine.model
        return HStack(alignment: .top, spacing: 14) {
            EquipmentTile(category: model?.equipmentType, size: typeSize.isAccessibilitySize ? 48 : 60)
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
                if model?.equipmentType != nil || model?.isSeeded == false || machine.defaultUnit != nil {
                    WrapLayout(spacing: 6, lineSpacing: 6) {
                        if let type = model?.equipmentType { GymTag(type.label, category: .some(type)) }
                        if let model, !model.isSeeded { GymTag("Custom") }
                        if let unit = machine.defaultUnit { GymTag(unit.rawValue) }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var stats: [GymStat] {
        var items = [GymStat.count(use.workouts, "Times used", "Times used")]
        if let last = use.lastUsed { items.append(.day(last, "Last used")) }
        items.append(.count(use.sets, "Set", "Sets"))
        return items
    }

    // MARK: Bests (the bold element)

    @ViewBuilder
    private var bests: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Bests")
            if use.bests.isEmpty {
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
                .dashedOutline(look.dash, radius: look.radius.panel)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(use.bests.enumerated()), id: \.element.id) { index, best in
                        if index > 0 { LookDivider().padding(.leading, 16) }
                        Group {
                            if index == 0 { topBest(best) } else { bestRow(best) }
                        }
                        .accessibilityIdentifier("machineDetail.best.\(index)")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
                .lookSurface(.panel)
            }
        }
    }

    /// The most-used scope: its name, the best as the page's one hero figure, how many workouts
    /// it spans, and its best set per day here with every new best labelled.
    private func topBest(_ best: MachineBest) -> some View {
        let series = GymOverviewMath.series(of: best, on: machine.id, in: sets)
        let text = bestText(best)
        return Button { chartingBest = best } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title(of: best))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if best.loadType == .assisted { GymTag("Assisted") }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                }
                GymBestValue(text: text, font: look.font.heroNumber)
                Text(workoutsText(best.workouts))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                if series.points.count >= 2 {
                    MachineBestChart(series: series, recordDays: ProgressSeriesMath.recordDays(series))
                        // Set labels and axis dates collide above xLarge; the figures above carry it.
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
        .buttonStyle(PanelRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title(of: best)), best \(text)\(best.loadType == .assisted ? ", Assisted" : ""), \(workoutsText(best.workouts))")
        .accessibilityAddTraits(.isButton)
    }

    private func bestRow(_ best: MachineBest) -> some View {
        let text = bestText(best)
        let ax = typeSize.isAccessibilitySize
        let layout = ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        return Button { chartingBest = best } label: {
            HStack(spacing: 10) {
                layout {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(of: best))
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if best.loadType == .assisted { GymTag("Assisted") }
                            Text(workoutsText(best.workouts))
                                .font(look.font.footnote)
                                .foregroundStyle(look.textSecondary)
                        }
                    }
                    if !ax { Spacer(minLength: 8) }
                    GymBestValue(text: text, font: look.font.fieldNumber, prominent: false)
                        .fixedSize()
                }
                if ax { Spacer(minLength: 0) }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PanelRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title(of: best)), best \(text)\(best.loadType == .assisted ? ", Assisted" : ""), \(workoutsText(best.workouts))")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Setup (D2: editable where shown, applied at once)

    private var setup: some View {
        let ax = typeSize.isAccessibilitySize
        let gymUnit = UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: machine.gym?.defaultUnit,
            appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
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
                            .onSubmit(commitName)
                            .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
                            .accessibilityIdentifier("machineDetail.name")
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
                    UnitChoice(options: ["Gym (\(gymUnit.rawValue))", "kg", "lb"], selection: unitBinding)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("machineDetail.unit")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let exercise = presetExercise {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Usually")
                        // D38: preselected when logging, never binding.
                        WrapLayout(spacing: 8, lineSpacing: 8) {
                            Chip("Ask each time", isSelected: machine.defaultPresetID == nil) { setPreset(nil) }
                            ForEach(orderedPresets(of: exercise)) { preset in
                                Chip(preset.name, isSelected: machine.defaultPresetID == preset.id) { setPreset(preset.id) }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("machineDetail.preset")
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

    private var unitBinding: Binding<Int> {
        Binding(get: { machine.defaultUnit.unitChoiceIndex }, set: { index in
            do {
                try EquipmentLifecycle(context: modelContext)
                    .update(machine, label: machine.label, defaultUnit: .fromUnitChoice(index))
                savedTick += 1
            } catch {
                assertionFailure("Failed to save the machine's unit: \(error)")
            }
        })
    }

    /// A blank name puts the old one back; an unchanged one saves nothing.
    private func commitName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { nameDraft = machine.label; return }
        guard trimmed != machine.label else { return }
        do {
            try EquipmentLifecycle(context: modelContext).rename(machine, to: trimmed)
            savedTick += 1
        } catch {
            nameDraft = machine.label
        }
    }

    private func setPreset(_ id: UUID?) {
        machine.defaultPresetID = id
        do {
            try modelContext.save()
            savedTick += 1
        } catch {
            assertionFailure("Failed to save the usual preset: \(error)")
        }
    }

    /// The machine form's rule: presets are offered only when the machine serves exactly one
    /// exercise that has them.
    private var presetExercise: Exercise? {
        let ids = machine.supportedExerciseIDs
        guard ids.count == 1, let exercise = exercises.first(where: { $0.id == ids[0] }),
              !(exercise.presets ?? []).isEmpty else { return nil }
        return exercise
    }

    private func orderedPresets(of exercise: Exercise) -> [ExercisePreset] {
        (exercise.presets ?? []).sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    // MARK: Exercises served

    @ViewBuilder
    private var exercisesSection: some View {
        let served = machine.supportedExerciseIDs.compactMap { id in exercises.first { $0.id == id } }
        if !served.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Exercises")
                LookList {
                    // Each opens the exercise's own page (Floodlight ticket 08, user decision 1).
                    ForEach(served) { exercise in
                        NavigationLink { ExerciseDetailView(exerciseID: exercise.id) } label: {
                            LookRow(exercise.name, subtitle: exercise.muscleGroup,
                                    value: exercise.loadType == .weighted ? nil : exercise.loadType.badge)
                        }
                        .buttonStyle(ExercisesRowPressStyle())
                        .accessibilityIdentifier("machineExercise.\(exercise.name)")
                    }
                }
            }
        }
    }

    // MARK: Model

    private var modelSection: some View {
        let model = machine.model
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
                    if let model, !model.isSeeded { GymTag("Custom") }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 60)
                .accessibilityElement(children: .combine)

                // D10: changing which model a machine is asks how far the change goes.
                LookRow(model == nil ? "Choose Model…" : "Correct Model…",
                        symbol: model == nil ? "magnifyingglass" : "arrow.triangle.2.circlepath") {
                    correcting = true
                }
                .accessibilityIdentifier("machineDetail.correctModel")
                if let model, !model.isSeeded {
                    LookRow("Rename Model…", symbol: "character.cursor.ibeam") {
                        modelManufacturer = model.manufacturer
                        modelName = model.modelName
                        renamingModel = model
                    }
                    .accessibilityIdentifier("machineDetail.renameModel")
                }
            }
        }
    }

    // MARK: Data

    /// The snapshot names the best was logged under (D23), never the live exercise or preset.
    private func title(of best: MachineBest) -> String { best.title }

    private func bestText(_ best: MachineBest) -> String {
        SetValue(best.best).map { LookFormat.set($0, loadType: best.loadType) } ?? ""
    }

    private func workoutsText(_ count: Int) -> String { "\(count) workout\(count == 1 ? "" : "s")" }

    private var historySignature: [String] {
        finished.map { "\($0.id)|\($0.historyEditedAt?.timeIntervalSince1970 ?? 0)" }
    }

    private func rebuild() {
        let entries = (try? SetBadgeMath.finishedEntries(in: modelContext)) ?? []
        let inputs = GymOverviewMath.machineSetInputs(finishedEntries: entries)
        use = GymOverviewMath.machineUse(inputs)[machine.id] ?? .unused
        sets = GymOverviewMath.recordInputs(of: machine.id, in: inputs)
    }
}

/// Rows inside a panel highlight with the pressed fill (no scale, so panels don't wobble).
struct PanelRowPressStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? look.pressedFill : .clear)
    }
}
