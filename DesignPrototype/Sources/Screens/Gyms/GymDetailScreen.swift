import SwiftUI

// G03 Gym Detail. A place, not a settings form: identity, the gym's use (visits as distinct
// days, last visit, machines), Scan Machine as the one filled command, then the machines grouped
// by body area (or exercise, or A–Z) with a glyph per equipment type. Each row carries its best
// in the look's best mark and its last use after the History glyph. Rows open the machine;
// swipe left to delete (confirmed). Add Machine… and Deleted machines close the list; Edit
// Gym… is the pencil in the bar.
//
// Capture variants (G03): "az", "exercise" (groupings), "empty" (Hotel Gym, no machines),
// "swipe" (Chest Press 2's delete tile open), "delete" (its confirmation), "added" (a machine
// just added: scrolled to and flashed), "p2", "p3".

struct GymDetailScreen: View {
    let gymID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var grouping = GymsMachineGrouping.bodyArea.rawValue
    @State private var openRowID: String?
    @State private var pendingDelete: Machine?
    @State private var deletedCount = 0
    @State private var highlightID: UUID?
    @State private var highlightHold: Double = 1.6
    @State private var titleVisible = false
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var knownMachineIDs: Set<UUID> = []
    /// Capture variant "empty" shows Hotel Gym on this page.
    @State private var captureGymID: UUID?
    @State private var appeared = false

    private var shownGymID: UUID { captureGymID ?? gymID }
    private var groupingValue: GymsMachineGrouping { GymsMachineGrouping(rawValue: grouping) ?? .bodyArea }

    var body: some View {
        Group {
            if let gym = store.gym(shownGymID) {
                content(gym)
            } else {
                Color.clear.lookScreenBackground()
            }
        }
        .onAppear(perform: appear)
    }

    private func content(_ gym: Gym) -> some View {
        let stats = store.gymsVisitStats(gym.id)
        let groups = store.gymsMachineGroups(gymID: gym.id, grouping: groupingValue)
        return ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    hero(gym, stats: stats)
                    machinesSection(gym, stats: stats, groups: groups)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollPosition($scroll)
            .gymsCapturePaging(GymsCapture.variant(.g03, store: store, router: router), position: $scroll)
            .gymsScrolledPast(64, into: $titleVisible)
            .onScrollPhaseChange { _, phase in
                // Scrolling closes an open delete tile, as a table does.
                if phase == .interacting, openRowID != nil {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86)) { openRowID = nil }
                }
            }
            .onChange(of: store.activeMachines(gymID: gym.id).map(\.id)) { _, ids in
                // A machine added by a scan or the picker: bring it into view and flash it once.
                let added = Set(ids).subtracting(knownMachineIDs)
                knownMachineIDs = Set(ids)
                guard let new = added.first, added.count == 1,
                      let group = store.gymsMachineGroups(gymID: gym.id, grouping: groupingValue)
                        .first(where: { $0.machines.contains { $0.id == new } }) else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { highlightID = new }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                    reader.scrollTo(Self.rowKey(group.id, new), anchor: .center)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + highlightHold) {
                    withAnimation(.easeOut(duration: 0.6)) { if highlightID == new { highlightID = nil } }
                }
            }
        }
        .lookScreenBackground()
        .gymsInlineTitle(gym.name, visible: titleVisible)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.editGym(gymID: gym.id)) } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Gym…")
            }
        }
        .alert(deleteTitle, isPresented: deleteAlertShown, presenting: pendingDelete) { machine in
            Button("Delete Machine", role: .destructive) { delete(machine) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("It disappears from this gym. Workouts you already logged with it keep it.")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: deletedCount)
        .sensoryFeedback(.success, trigger: highlightID) { _, new in new != nil }
    }

    // MARK: Hero

    private func hero(_ gym: Gym, stats: GymStats) -> some View {
        let subtitle = store.gymsSubtitle(gym)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                GymsMonogram(name: gym.name, size: typeSize.isAccessibilitySize ? 48 : 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gym.name)
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if !subtitle.isEmpty { subtitleText(subtitle) }
                }
                Spacer(minLength: 0)
            }
            GymsStatStrip(stats: statItems(stats))
            GymsPrimaryCapsule(title: "Scan Machine", symbol: "camera.viewfinder") {
                store.scanBegin(gymID: gym.id)
                router.present(.scan(gymID: gym.id))
            }
        }
    }

    private func subtitleText(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, weight: look.id == .floodlight ? .regular : .semibold))
            .foregroundStyle(look.textSecondary)
    }

    private func statItems(_ stats: GymStats) -> [GymsStat] {
        var items = [GymsStat.count(stats.visits, stats.visits == 1 ? "Visit" : "Visits")]
        if let last = stats.lastVisit {
            items.append(GymsStat(value: GymsDate.label(last, now: store.now), label: "Last visit", isWord: true))
        }
        items.append(GymsStat.count(stats.machineCount, stats.machineCount == 1 ? "Machine" : "Machines"))
        return items
    }

    // MARK: Machines

    @ViewBuilder
    private func machinesSection(_ gym: Gym, stats: GymStats, groups: [GymsMachineGroup]) -> some View {
        VStack(alignment: .leading, spacing: look.space.header + 4) {
            header(showsGrouping: stats.machineCount > 1)
            if stats.machineCount > 1 && !typeSize.isAccessibilitySize {
                SegmentedPills(GymsMachineGrouping.allCases.map(\.title), selection: $grouping)
                    .sensoryFeedback(.selection, trigger: grouping)
            }
            if groups.isEmpty {
                EmptyStateView(symbol: LookIcon.machine, title: "No machines yet")
                    .padding(.vertical, -8)
            } else {
                VStack(alignment: .leading, spacing: look.space.group + 8) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            if let title = group.title {
                                GymsGroupHeader(title: title, family: group.family,
                                                showsSwatch: groupingValue == .bodyArea, count: group.machines.count)
                            }
                            LookList(separatorInset: 66) {
                                ForEach(group.machines) { machine in
                                    row(machine, group: group)
                                }
                            }
                        }
                    }
                }
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: grouping)
            }
            GymsMakeRow(title: "Add Machine…") {
                GymsPickerContext.gymID = gym.id
                router.present(.modelPicker(machineID: nil))
            }
            if stats.deletedMachineCount > 0 {
                LookList {
                    LookRow("Deleted machines", symbol: "trash", value: "\(stats.deletedMachineCount)") {
                        router.push(.deletedMachines(gymID: gym.id))
                    }
                    .celebrate(stats.deletedMachineCount)
                }
            }
        }
    }

    /// "Machines"; at AX sizes the grouping choice is a compact menu beside it (the pills would
    /// truncate, and three stacked rows pushed every machine below the fold).
    @ViewBuilder
    private func header(showsGrouping: Bool) -> some View {
        if typeSize.isAccessibilitySize && showsGrouping {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Machines", level: .page)
                GymsGroupingMenu(titles: GymsMachineGrouping.allCases.map(\.title), selection: $grouping,
                                 accessibilityName: "Group Machines By")
            }
        } else {
            SectionHeader("Machines", level: .page)
        }
    }

    private func row(_ machine: Machine, group: GymsMachineGroup) -> some View {
        let key = Self.rowKey(group.id, machine.id)
        return GymsSwipeRow(id: key, openID: $openRowID, onDelete: { pendingDelete = machine }) {
            GymsMachineRow(machine: machine, exerciseID: group.exerciseID, highlighted: highlightID == machine.id) {
                router.push(.machineDetail(machineID: machine.id))
            }
        }
        .id(key)
        .transition(.opacity)
    }

    private static func rowKey(_ groupID: String, _ machineID: UUID) -> String { "\(groupID)|\(machineID.uuidString)" }

    // MARK: Appear and capture variants

    private func appear() {
        GymsPickerContext.gymID = shownGymID
        guard !appeared else { return }
        appeared = true
        guard gymID == store.screenTarget.gymID, let variant = GymsCapture.take(.g03, store: store, router: router) else {
            knownMachineIDs = Set(store.activeMachines(gymID: shownGymID).map(\.id))
            return
        }
        let chest = SampleData.machineID("Iron Temple", "Chest Press 2")
        switch variant {
        case "empty":
            captureGymID = SampleData.gymID("Hotel Gym")
            GymsPickerContext.gymID = captureGymID
        case "az": grouping = GymsMachineGrouping.alphabetical.rawValue
        case "exercise": grouping = GymsMachineGrouping.exercise.rawValue
        case "swipe":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { openRowID = Self.rowKey("f-chest", chest) }
            }
        case "delete":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pendingDelete = store.machine(chest) }
        case "added":
            highlightHold = 12
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                let model = SampleData.modelID("Hammer Strength Plate Loaded Hack Squat")
                if let m = store.model(model) {
                    store.addMachine(gymID: gymID, label: store.gymsDefaultLabel(for: m), modelID: m.id)
                }
            }
        default: break
        }
        knownMachineIDs = Set(store.activeMachines(gymID: shownGymID).map(\.id))
    }

    // MARK: Delete

    private var deleteTitle: String { pendingDelete.map { "Delete \($0.label)?" } ?? "Delete machine?" }

    private var deleteAlertShown: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func delete(_ machine: Machine) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            openRowID = nil
            store.deleteMachine(machine.id)
        }
        deletedCount += 1
        pendingDelete = nil
    }
}

// MARK: - Machine row

/// Equipment glyph · movement label (+ unit override) · model on one line each; trailing, the
/// best in the look's best mark over its last use after the History glyph. Assisted bests carry
/// the Assisted tag (lower is better). Under Exercise grouping the numbers are that exercise's
/// on this machine. A machine never used shows no numbers (missing is not zero). AX: the names
/// wrap and the numbers drop under them.
struct GymsMachineRow: View {
    var machine: Machine
    var exerciseID: UUID?
    var highlighted = false
    var action: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let use = store.gymsMachineUse(machine, exerciseID: exerciseID)
        Button(action: action) {
            HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
                GymsEquipmentDisc(category: store.gymsCategory(of: machine), size: 40)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        names
                        numbers(use, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                } else {
                    names
                    Spacer(minLength: 8)
                    numbers(use, alignment: .trailing)
                }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(highlighted ? look.selectionFill : .clear)
            .overlay {
                if highlighted {
                    Rectangle().strokeBorder(look.id.isPaperClub ? look.actionText : look.selection, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GymsRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(use))
        .accessibilityAddTraits(.isButton)
    }

    private var names: some View {
        let ax = typeSize.isAccessibilitySize
        let model = store.model(machine.modelID)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(machine.label)
                    .font(titleFont)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(ax ? nil : 1)
                if let unit = machine.defaultUnit { GymsTag(unit.label) }
            }
            // The model without its maker: the full name is on the machine's page and in VoiceOver.
            Text(model?.modelName ?? "No model")
                .font(look.font.footnote)
                .foregroundStyle(model == nil ? look.textTertiary : look.textSecondary)
                .lineLimit(ax ? nil : 1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private func numbers(_ use: GymsMachineUse, alignment: HorizontalAlignment) -> some View {
        if use.best != nil || use.lastUsed != nil {
            VStack(alignment: alignment, spacing: 3) {
                if let best = use.best {
                    GymsBestValue(text: Format.set(best.value, loadType: best.loadType), font: numberFont, prominent: false)
                }
                HStack(spacing: 6) {
                    if let best = use.best, best.loadType == .assisted { GymsTag(best.loadType.badge) }
                    if let last = use.lastUsed { GymsLastUsed(date: last, now: store.now) }
                }
            }
            .fixedSize()
        }
    }

    private var titleFont: Font {
        switch look.id {
        case .floodlight: .system(.body, weight: .semibold)
        case .anatomy: .system(.body, design: .rounded, weight: .bold)
        case .paper, .carbon: .system(.body, weight: .bold)
        }
    }

    private var numberFont: Font {
        switch look.id {
        case .floodlight: Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit()
        case .anatomy: .system(.subheadline, design: .rounded, weight: .heavy).monospacedDigit()
        case .paper, .carbon: Font.system(.subheadline, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }

    private func accessibilityText(_ use: GymsMachineUse) -> String {
        var parts = [machine.label, store.modelName(of: machine) ?? "No model"]
        if let unit = machine.defaultUnit { parts.append(unit.label) }
        if let best = use.best {
            parts.append("Best \(best.exerciseName) \(Format.set(best.value, loadType: best.loadType))")
            if best.loadType == .assisted { parts.append(best.loadType.badge) }
        }
        if let last = use.lastUsed { parts.append("Last used \(GymsDate.label(last, now: store.now))") }
        return parts.joined(separator: ", ")
    }
}
