import SwiftUI

// PROTOTYPE — L08 Equipment for one live entry. The choice is staged, then committed with
// Done, so the sheet can say what Done will do before it happens. The card on top carries only
// the delta and the numbers: a staged change as "from → to" ("No preset → Narrow grip"), your
// best on the staged equipment and when you last used it, or First time. The selected row
// below carries the machine name (and its model only when that tells machines apart, as on
// Add by Machine). On an entry with a completed set the locked
// line lights up as soon as a change is staged ("…continues in a new entry").
// Machines at this gym that serve the exercise come first; every free weight has its own
// glyph; a dumbbell counterpart replaces the Dumbbell row ("Log as … instead", D51).
// Variants: "counterpart" (Lateral Raise, not started), "change" (a staged preset change on
// the frozen chest entry), "firstTime" (a staged switch to a barbell never used for it).

enum LiveSheetsEquipmentChoice: Hashable {
    case none
    case machine(UUID)
    case tag(EquipmentTag)
    case counterpart
}

struct EquipmentSheet: View {
    let entryID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var environmentTypeSize
    /// The sheet root sits outside its own `.dynamicTypeSize` override, so it resolves the
    /// prototype override itself.
    private var typeSize: DynamicTypeSize { router.dynamicTypeOverride ?? environmentTypeSize }

    @State private var overrideID: UUID?
    @State private var choice: LiveSheetsEquipmentChoice = .none
    @State private var presetID: UUID?
    @State private var loaded = false
    @State private var showsAllMachines = false
    @State private var page: Int?

    private var id: UUID { overrideID ?? entryID }
    private var entry: LiveEntry? { store.liveEntry(id) }
    private var exercise: Exercise? { store.exercise(entry?.exerciseID) }
    private var gymID: UUID? { store.session?.gymID }
    private var counterpart: Exercise? { entry.flatMap { store.dumbbellCounterpart(of: $0.exerciseID) } }

    private var currentChoice: LiveSheetsEquipmentChoice {
        guard let entry else { return .none }
        if let m = entry.machineID { return .machine(m) }
        if let t = entry.freeWeightTag { return .tag(t) }
        return .none
    }
    private var hasChange: Bool {
        guard let entry else { return false }
        return choice != currentChoice || (choice != .counterpart && presetID != entry.presetID)
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveSheetsHeader(title: "Equipment", subtitle: exercise?.name,
                             leading: .cancel { router.dismissSheet() },
                             trailing: .commit("Done", enabled: entry != nil, action: commit))
            LiveSheetsScroll(page: page) {
                VStack(alignment: .leading, spacing: 22) {
                    summaryCard
                    if entry?.isFrozen == true {
                        LiveSheetsNotice(symbol: "lock.fill",
                                         text: "A completed set locks equipment; a change continues in a new entry.",
                                         emphasized: hasChange)
                            .animation(reduceMotion ? nil : .snappy, value: hasChange)
                    }
                    if let exercise, !exercise.presets.isEmpty, choice != .counterpart { presets(exercise) }
                    machinesSection
                    freeWeightsSection
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 48)
            }
        }
        .liveSheetsPresentation(look)
        .presentationDetents([.large])
        .sensoryFeedback(.selection, trigger: choice)
        .sensoryFeedback(.selection, trigger: presetID)
        .onAppear(perform: load)
    }

    // MARK: Summary (what Done will log on)

    private var summary: (glyph: LiveSheetsGlyphKind, title: String, detail: String?) {
        switch choice {
        case .machine(let m):
            let machine = store.machine(m)
            return (.machine, machine?.label ?? "Machine", store.modelName(of: machine))
        case .tag(let t):
            return (LiveSheetsGlyphKind.of(t), t.label, nil)
        case .counterpart:
            return (.symbol("dumbbell"), counterpart?.name ?? EquipmentTag.dumbbell.label, EquipmentTag.dumbbell.label)
        case .none:
            return (.symbol("questionmark"), "Choose equipment", nil)
        }
    }

    /// What you logged on the staged equipment before (same preset): its best set and when.
    private var stagedHistory: (best: SetValue?, last: Date?, loadType: LoadType)? {
        guard entry != nil, let exercise else { return nil }
        let performance: PreviousPerformance?
        switch choice {
        case .machine(let m):
            performance = store.previousPerformance(exerciseID: exercise.id, machineID: m, tag: nil, presetID: presetID, gymID: gymID)
        case .tag(let t):
            performance = store.previousPerformance(exerciseID: exercise.id, machineID: nil, tag: t, presetID: presetID, gymID: gymID)
        case .counterpart:
            guard let counterpart else { return nil }
            performance = store.previousPerformance(exerciseID: counterpart.id, machineID: nil, tag: .dumbbell, presetID: nil, gymID: gymID)
        case .none:
            return nil
        }
        guard let layer = performance?.layers.first(where: { $0.kind == .thisEquipment }) else { return nil }
        let loadType = performance?.loadType ?? exercise.loadType
        // Today's sets count on the equipment and preset they were logged with, so a set that
        // just beat the record (110 × 8 over Sep 17's 105 × 8) is the best shown here too.
        if choice == currentChoice, let entry, presetID == entry.presetID, let today = liveSheetsTodayBest(entry, loadType: loadType),
           layer.best.map({ Records.outranks(today, $0, loadType: loadType) }) ?? true {
            return (today, store.now, loadType)
        }
        return (layer.best, layer.sessions.first?.date, loadType)
    }

    /// The entry's best completed working set today.
    private func liveSheetsTodayBest(_ entry: LiveEntry, loadType: LoadType) -> SetValue? {
        let values = entry.sets.filter { $0.isCompleted && $0.type.countsTowardRecords }.compactMap { set -> SetValue? in
            guard let reps = set.reps else { return nil }
            return SetValue(weight: entry.total(of: set), unit: set.unit, reps: reps, bar: entry.barWeight)
        }
        return Records.best(values, loadType: loadType)
    }

    /// A staged change as "from → to": the equipment when that changes ("Chest Press 2 →
    /// Barbell"), else the preset ("No preset → Narrow grip").
    private var delta: (from: String, to: String)? {
        guard let entry, hasChange else { return nil }
        if choice != currentChoice {
            let from: String? = switch currentChoice {
            case .machine(let m): store.machine(m)?.label
            case .tag(let t): t.label
            case .counterpart, .none: nil
            }
            return from.map { ($0, summary.title) }
        }
        func name(_ id: UUID?) -> String { exercise?.presets.first { $0.id == id }?.name ?? "No preset" }
        return (name(entry.presetID), name(presetID))
    }

    /// The bold element: what you did before on the staged equipment (the best set big, the
    /// last time small), or First time; a staged change adds its "from → to" line on top.
    private var summaryCard: some View {
        let s = summary
        let history = stagedHistory
        return HStack(alignment: .center, spacing: 14) {
            // At accessibility sizes the numbers need the width; the selected row below
            // already carries the glyph.
            if !typeSize.isAccessibilitySize {
                LiveSheetsGlyphDisc(kind: s.glyph)
                    .id(s.title)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            }
            VStack(alignment: .leading, spacing: 4) {
                if let delta {
                    deltaLine(delta)
                        .transition(.opacity)
                }
                if let history, let best = history.best {
                    Text(Format.set(best, loadType: history.loadType))
                        .font(look.font.bigNumber)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    HStack(spacing: 6) {
                        Text("Best")
                        if let last = history.last {
                            Text("·")
                            Text(Calendar.current.isDate(last, inSameDayAs: store.now) ? "Today" : look.lastDoneLabel(last, now: store.now))
                        }
                    }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                } else if history != nil {
                    NewBestBadge(kind: .firstTime)
                        .padding(.vertical, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(look.space.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: choice)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: presetID)
        .accessibilityElement(children: .combine)
    }

    /// "Chest Press 2 → Barbell": wraps as a whole phrase at accessibility sizes.
    private func deltaLine(_ delta: (from: String, to: String)) -> some View {
        (Text(delta.from).foregroundStyle(look.textSecondary)
         + Text("  \(Image(systemName: "arrow.right"))  ").foregroundStyle(look.textSecondary)
         + Text(delta.to).foregroundStyle(look.textPrimary))
            .font(.system(.subheadline, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(delta.from) to \(delta.to)")
    }

    // MARK: Presets

    private func presets(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            LiveSheetsFlow(spacing: 8, lineSpacing: 0) {
                Chip("No preset", isSelected: presetID == nil) { select(preset: nil) }
                ForEach(exercise.presets) { preset in
                    Chip(preset.name, isSelected: presetID == preset.id) { select(preset: preset.id) }
                }
            }
        }
    }

    // MARK: Machines

    private var machinesSection: some View {
        let all = store.activeMachines(gymID: gymID)
        let serving = entry.map { e in all.filter { store.exerciseIDs(of: $0).contains(e.exerciseID) } } ?? []
        let selectedMachine: UUID? = if case .machine(let m) = choice { m } else { nil }
        var shown = (showsAllMachines || serving.isEmpty) ? all : serving
        if let selectedMachine, !shown.contains(where: { $0.id == selectedMachine }), let m = store.machine(selectedMachine) {
            shown.insert(m, at: 0)
        }
        let hidden = all.count - shown.count
        return Group {
            if let gym = store.gym(gymID), !all.isEmpty {
                LookList(header: "Machines at \(gym.name)", separatorInset: 54) {
                    ForEach(shown) { machine in
                        LiveSheetsOptionRow(glyph: .machine, title: machine.label,
                                            subtitle: store.liveSheetsModelCaption(machine, gymID: gymID),
                                            badge: machine.defaultUnit?.label,
                                            isSelected: choice == .machine(machine.id)) {
                            select(.machine(machine.id))
                        }
                    }
                    if hidden > 0 {
                        Button {
                            if reduceMotion { showsAllMachines = true } else { withAnimation(.snappy) { showsAllMachines = true } }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "ellipsis")
                                    .font(.system(.body, weight: .semibold))
                                    .frame(width: 26)
                                Text("Show all machines")
                                    .font(.system(.subheadline, weight: .semibold))
                                Spacer(minLength: 8)
                                Text("\(hidden)").font(look.font.subhead).monospacedDigit()
                            }
                            .foregroundStyle(look.textSecondary)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        }
                        .buttonStyle(LiveSheetsRowPressStyle())
                    }
                }
            }
        }
    }

    // MARK: Free weights

    private var freeWeightsSection: some View {
        let tags: [EquipmentTag] = [.barbell, .dumbbell, .cable, .smith, .bodyweight]
        return LookList(header: "Free weights", separatorInset: 54) {
            ForEach(tags) { tag in
                if tag == .dumbbell, let counterpart {
                    LiveSheetsOptionRow(glyph: .symbol("dumbbell"), title: "Log as \(counterpart.name) instead",
                                        isSelected: choice == .counterpart, trailingSymbol: "arrow.turn.down.right") {
                        select(.counterpart)
                    }
                } else {
                    LiveSheetsOptionRow(glyph: LiveSheetsGlyphKind.of(tag), title: tag.label,
                                        isSelected: choice == .tag(tag)) {
                        select(.tag(tag))
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func select(_ next: LiveSheetsEquipmentChoice) {
        let apply = {
            choice = next
            // D38: a machine's usual preset is preselected, unless the entry is frozen (the preset follows).
            if case .machine(let m) = next, entry?.isFrozen == false, let usual = store.machine(m)?.defaultPresetID {
                presetID = usual
            }
        }
        if reduceMotion { apply() } else { withAnimation(.snappy(duration: 0.22)) { apply() } }
    }

    private func select(preset: UUID?) {
        if reduceMotion { presetID = preset } else { withAnimation(.snappy(duration: 0.22)) { presetID = preset } }
    }

    private func commit() {
        guard let entry, hasChange else { router.dismissSheet(); return }
        if choice == .counterpart {
            store.logAsCounterpart(entryID: id)
            router.dismissSheet()
            return
        }
        var target = id
        if choice != currentChoice {
            switch choice {
            case .machine(let m): store.chooseEquipment(machineID: m, tag: nil, entryID: id)
            case .tag(let t): store.chooseEquipment(machineID: nil, tag: t, entryID: id)
            case .none, .counterpart: break
            }
            // A frozen entry keeps its completed rows; the change continues in the entry right after it.
            if entry.isFrozen, let entries = store.session?.entries, let i = entries.firstIndex(where: { $0.id == id }),
               i + 1 < entries.count {
                target = entries[i + 1].id
            }
        }
        if store.liveEntry(target)?.presetID != presetID {
            store.choosePreset(presetID, entryID: target)
        }
        router.dismissSheet()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let variant = LiveSheetsVariant.consume([.l08], store: store, router: router)
        page = LiveSheetsVariant.page(variant)
        if LiveSheetsVariant.has(variant, "counterpart"), let other = store.screenTarget.secondaryEntryID {
            overrideID = other
        }
        choice = currentChoice
        presetID = entry?.presetID
        if LiveSheetsVariant.has(variant, "change"), let first = exercise?.presets.first {
            presetID = first.id
        }
        if LiveSheetsVariant.has(variant, "firstTime") { choice = .tag(.barbell) }
    }
}
