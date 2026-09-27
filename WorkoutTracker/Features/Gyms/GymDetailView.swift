import SwiftData
import SwiftUI

/// A gym's page (Floodlight redesign ticket 06, G03). A place, not a settings form: identity, its
/// use (visits, last visit, machines), Scan Machine as the one filled command, then the machines
/// grouped by body area / exercise / A–Z, each with its equipment glyph, its best and its last
/// use. A row opens the machine's page; swipe or long-press to delete. Add Machine… and Deleted
/// machines close the list; Edit Gym… is the pencil in the bar.
///
/// A native `List` (panel rows drawn like History's) so machine rows keep the system swipe
/// action, the context menu and VoiceOver's actions.
struct GymDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    var gym: Gym
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allPreferences: [AppPreferences]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var finished: [Workout]
    @State private var showingAddMachine = false
    @State private var showingScanner = false
    @State private var editingGym = false
    @State private var editingMachine: MachineInstance?
    @State private var correctingMachine: MachineInstance?
    /// The machine a swipe or long-press asked to delete; the dialog decides.
    @State private var deletingMachine: MachineInstance?
    @State private var renamingModel: EquipmentModel?
    @State private var modelManufacturer = ""
    @State private var modelName = ""
    @State private var openMachineID: UUID?
    @State private var showingDeleted = false
    @State private var titleInBar = false
    /// Each machine's use, rebuilt from history when it changes (not per frame).
    @State private var use: [UUID: MachineUse] = [:]

    var body: some View {
        List {
            hero
            machinesHeader
            if gym.activeMachines.isEmpty {
                EmptyStateView(symbol: LookIcon.machine, title: "No machines yet")
                    .historyPageRow(top: 0, bottom: 0)
            }
            // Ticket 21: a 30-machine gym is only scannable grouped, and a 3-machine gym does not
            // want headers at all — hence A–Z as a first-class mode, remembered between visits.
            ForEach(machineSections) { section in
                if let title = section.title {
                    GymGroupHeader(title: title, family: family(of: title),
                                   showsSwatch: machineGrouping == .bodyArea, count: section.rows.count)
                        .historyPageRow(top: 18, bottom: 10)
                }
                let rows = section.rows.compactMap { machinesByID[$0.id] }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, machine in
                    machineRow(machine, exercises: exerciseIDs(of: section))
                        .historyPanelRow(first: index == 0, last: index == rows.count - 1,
                                         separatorInset: typeSize.isAccessibilitySize ? 16 : 66)
                }
            }
            MakeRow(title: "Add Machine…") { showingAddMachine = true }
                .accessibilityIdentifier("addMachine")
                .historyPageRow(top: 22, bottom: 0)
            // Deleted = archived (D10): one tap from coming back.
            if !gym.archivedMachines.isEmpty {
                LookList {
                    LookRow("Deleted machines", symbol: "trash", value: "\(gym.archivedMachines.count)") {
                        showingDeleted = true
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("deletedMachines")
                .historyPageRow(top: 12, bottom: 0)
            }
            Color.clear.frame(height: 24).historyPageRow()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .lookScreenBackground()
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 90 : 64)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .gymsInlineTitle(gym.name, visible: titleInBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit Gym…", systemImage: "pencil") { editingGym = true }
                    .tint(look.textPrimary)
                    .accessibilityIdentifier("editGym")
            }
        }
        .onAppear(perform: rebuildUse)
        // Delete Gym… (in Edit Gym) archives it: its page has nothing left to show.
        .onChange(of: gym.archived) { _, archived in if archived { dismiss() } }
        .onChange(of: historySignature) { _, _ in rebuildUse() }
        .navigationDestination(item: $openMachineID) { id in
            if let machine = gym.activeMachines.first(where: { $0.id == id }) {
                MachineDetailView(machine: machine)
            }
        }
        .navigationDestination(isPresented: $showingDeleted) {
            DeletedMachinesView(gym: gym)
        }
        .deleteMachineConfirmation($deletingMachine) { archive($0) }
        .sheet(isPresented: $showingAddMachine) {
            MachineEditorSheet(gym: gym)
        }
        .sheet(isPresented: $showingScanner) {
            MachineEditorSheet(gym: gym, startsWithScanner: true)
        }
        .sheet(isPresented: $editingGym) {
            GymEditorSheet(gym: gym)
        }
        .sheet(item: $editingMachine) { machine in
            MachineEditorSheet(gym: gym, machine: machine)
        }
        .sheet(item: $correctingMachine) { machine in
            MachineModelCorrectionSheet(machine: machine)
        }
        .renameModelAlert($renamingModel, manufacturer: $modelManufacturer, modelName: $modelName)
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            GymMonogram(name: gym.name, size: typeSize.isAccessibilitySize ? 48 : 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(gym.name)
                    .font(look.font.title)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let place = gym.placeLine {
                    Text(place)
                        .font(.subheadline)
                        .foregroundStyle(look.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .historyPageRow(top: 4, bottom: 18)
        GymStatStrip(stats: stats)
            .historyPageRow(top: 0, bottom: 18)
        StartCapsule(title: "Scan Machine", symbol: "camera.viewfinder") { showingScanner = true }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("scanMachine")
            .historyPageRow(top: 0, bottom: 0)
    }

    private var stats: [GymStat] {
        let visits = GymOverviewMath.visits(of: gym.id, in: GymOverviewMath.visitInputs(finished), now: .now)
        var items = [GymStat.count(visits.visits, "Visit", "Visits")]
        if let last = visits.lastVisit { items.append(.day(last, "Last visit")) }
        let machines = gym.activeMachines.count
        items.append(.count(machines, "Machine", "Machines"))
        return items
    }

    // MARK: Machines

    /// "Machines"; the grouping as pills (a compact menu at AX sizes, where three pills truncate).
    private var machinesHeader: some View {
        let showsGrouping = gym.activeMachines.count > 1
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Machines", level: .page)
            if showsGrouping {
                if typeSize.isAccessibilitySize {
                    GroupingMenu(options: MachineGrouping.displayOrder, title: \.label,
                                 identifier: { "machineGrouping.\($0.rawValue)" },
                                 selection: groupingBinding, accessibilityName: "Group Machines By")
                } else {
                    GroupingPills(options: MachineGrouping.displayOrder, title: \.label,
                                  identifier: { "machineGrouping.\($0.rawValue)" }, selection: groupingBinding)
                }
            }
        }
        .historyPageRow(top: look.space.section, bottom: 4)
    }

    /// The machine row: equipment glyph · label (+ unit tag) over the model without its maker;
    /// trailing, its best over its last use. In an exercise's or a body area's group the numbers
    /// are that group's exercises' on this machine. Never used: no numbers (missing is not zero). AX: the names
    /// wrap and the numbers drop under them.
    private func machineRow(_ machine: MachineInstance, exercises: Set<UUID>?) -> some View {
        let facts = use[machine.id] ?? .unused
        let best = facts.best(among: exercises)
        let last = facts.lastUsed(among: exercises)
        let ax = typeSize.isAccessibilitySize
        return HStack(alignment: ax ? .top : .center, spacing: 12) {
            EquipmentTile(category: machine.model?.equipmentType, size: 40)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(machine.label)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .lineLimit(ax ? nil : 1)
                        if let unit = machine.defaultUnit { GymTag(unit.rawValue) }
                    }
                    Text(machine.model?.modelName ?? "No model")
                        .font(look.font.footnote)
                        .foregroundStyle(machine.model == nil ? look.textTertiary : look.textSecondary)
                        .lineLimit(ax ? nil : 1)
                }
                if ax { numbers(best: best, last: last, alignment: .leading) }
            }
            Spacer(minLength: 8)
            if !ax { numbers(best: best, last: last, alignment: .trailing) }
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { openMachineID = machine.id }
        // The row carries the id and stays a container, so its texts stay reachable (tests and
        // VoiceOver read the label) and a swipe on it is long enough to reveal Delete.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("machineRow.\(machine.label)")
        .accessibilityAction(named: "Open") { openMachineID = machine.id }
        .machineDeleteActions(machine) { deletingMachine = $0 }
        .contextMenu {
            // D2: label *and* default unit, not rename alone.
            Button("Edit Machine…") { editingMachine = machine }
            Button("Correct Model…") { correctingMachine = machine }
            if let model = machine.model, !model.isSeeded {
                Button("Rename Model…") {
                    modelManufacturer = model.manufacturer
                    modelName = model.modelName
                    renamingModel = model
                }
            }
            // The user's word (2026-09-10); archival underneath, D10.
            DeleteMachineMenuItem(machine: machine) { deletingMachine = $0 }
        }
    }

    @ViewBuilder
    private func numbers(best: MachineBest?, last: Date?, alignment: HorizontalAlignment) -> some View {
        if best != nil || last != nil {
            VStack(alignment: alignment, spacing: 3) {
                if let best, let value = SetValue(best.best) {
                    GymBestValue(text: LookFormat.set(value, loadType: best.loadType),
                                 font: Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit(),
                                 prominent: false)
                        .accessibilityLabel("Best \(LookFormat.set(value, loadType: best.loadType))")
                }
                HStack(spacing: 6) {
                    if best?.loadType == .assisted { GymTag("Assisted") }
                    if let last { GymLastUsed(date: last) }
                }
            }
            .fixedSize()
        }
    }

    // MARK: Data

    /// The gym's machines, grouped the way this user last asked for. Pure display state (D23).
    private var machineSections: [CatalogSection<MachineBrowseRow>] {
        let exercisesByID = Dictionary(exercises.map { ($0.id, $0) }) { first, _ in first }
        let rows = gym.activeMachines.map { MachineBrowseRow($0, exercisesByID: exercisesByID) }
        return CatalogBrowsing.machineSections(rows, by: machineGrouping)
    }

    private var machinesByID: [UUID: MachineInstance] {
        Dictionary(gym.activeMachines.map { ($0.id, $0) }) { first, _ in first }
    }

    /// The exercises a section is about, whose numbers its rows show: one exercise under Exercise
    /// grouping, the body area's exercises under Body area (a station serving several areas is
    /// listed under each, D23 display rule). nil (A–Z, Uncategorized): the machine's own best.
    private func exerciseIDs(of section: CatalogSection<MachineBrowseRow>) -> Set<UUID>? {
        guard let title = section.title else { return nil }
        let matching: [Exercise]
        switch machineGrouping {
        case .exercise: matching = exercises.filter { $0.name == title }
        case .bodyArea: matching = exercises.filter { $0.muscleGroup == title }
        case .alphabetical: return nil
        }
        return matching.isEmpty ? nil : Set(matching.map(\.id))
    }

    private func family(of bodyArea: String) -> MuscleFamily? {
        machineGrouping == .bodyArea ? MuscleFamily(muscleGroup: bodyArea) : nil
    }

    private var machineGrouping: MachineGrouping {
        AppPreferences.canonical(of: allPreferences)?.machineBrowseGrouping ?? .alphabetical
    }

    private var groupingBinding: Binding<MachineGrouping> {
        Binding(get: { machineGrouping }, set: setMachineGrouping)
    }

    private func setMachineGrouping(_ mode: MachineGrouping) {
        do {
            let preferences = try AppPreferences.canonical(in: modelContext)
            preferences.machineBrowseGrouping = mode
            preferences.updatedAt = .now
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save machine grouping: \(error)")
        }
    }

    private var historySignature: [String] {
        finished.map { "\($0.id)|\($0.historyEditedAt?.timeIntervalSince1970 ?? 0)" }
    }

    private func rebuildUse() {
        let entries = (try? SetBadgeMath.finishedEntries(in: modelContext)) ?? []
        use = GymOverviewMath.machineUse(GymOverviewMath.machineSetInputs(finishedEntries: entries))
    }

    private func archive(_ machine: MachineInstance) {
        do { try EquipmentLifecycle(context: modelContext).archive(machine) }
        catch { assertionFailure("Failed to archive machine: \(error)") }
    }
}

extension MachineGrouping {
    /// The pills' order: the prototype's (Body area · Exercise · A–Z).
    static let displayOrder: [MachineGrouping] = [.bodyArea, .exercise, .alphabetical]
}

/// Segmented pills over a list of options, each pill a button with its own identifier.
struct GroupingPills<Option: Hashable>: View {
    var options: [Option]
    var title: (Option) -> String
    var identifier: (Option) -> String
    @Binding var selection: Option
    @Namespace private var namespace
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 38

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    if reduceMotion { selection = option } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = option }
                    }
                } label: {
                    Text(title(option))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(selected ? look.selection : look.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background {
                            if selected {
                                Capsule().fill(look.segmentFill)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        // The track's 3 pt inset belongs to each pill's hit region, and 44 pt is a
                        // floor at every text size: the scaled pill shrinks below 38 at Small
                        // (Codex review 06, 06b).
                        .padding(.vertical, 3)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(identifier(option))
            }
        }
        .padding(.horizontal, 3)
        .background(look.surface, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension View {
    /// Rename a user-made model (D24): the captured history keeps the old name.
    func renameModelAlert(_ model: Binding<EquipmentModel?>, manufacturer: Binding<String>,
                          modelName: Binding<String>) -> some View {
        modifier(RenameModelAlert(model: model, manufacturer: manufacturer, modelName: modelName))
    }
}

private struct RenameModelAlert: ViewModifier {
    @Binding var model: EquipmentModel?
    @Binding var manufacturer: String
    @Binding var modelName: String
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.alert(
            "Rename Model",
            isPresented: Binding(get: { model != nil }, set: { if !$0 { model = nil } }),
            presenting: model
        ) { model in
            TextField("Manufacturer", text: $manufacturer)
            TextField("Model", text: $modelName)
            Button("Save") {
                do {
                    try EquipmentLifecycle(context: modelContext)
                        .rename(model, manufacturer: manufacturer, modelName: modelName)
                } catch {
                    assertionFailure("Failed to rename model: \(error)")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("History keeps the captured name.")
        }
    }
}
