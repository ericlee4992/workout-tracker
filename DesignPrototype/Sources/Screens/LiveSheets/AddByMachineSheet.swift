import SwiftUI

// PROTOTYPE — L07 Add by Machine. The machines at the workout's gym, grouped by the body area
// they train. Each row is the movement label, and a model caption only when it tells machines
// apart (the gym's dominant brand and series are dropped, and a model that only repeats the
// label is hidden). A leading glyph appears only where the hardware differs from its section
// (plate-loaded, cable). The trailing mark says one thing: plus (adds now), chevron (pick its
// exercise) or a lit check (already in this workout). A machine with several exercises opens
// its page: the machine card (full model name, times used, last used) over its exercises with
// your best on this machine or First time, each with the same plus. A machine with no model or
// exercises opens the whole catalog ("Pick Exercise"). Scan Machine sits on top as the "make
// one" row. Variants: "empty" (a gym with no machines — "No machines yet", Scan Machine the one
// filled command, Add Exercise quiet under it), "machine" (the Pec Deck page), "added" (the
// check popped on the row just tapped, before the sheet closes; with "machine" on the page).

struct AddByMachineSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var environmentTypeSize
    /// The sheet root sits outside its own `.dynamicTypeSize` override, so it resolves the
    /// prototype override itself.
    private var typeSize: DynamicTypeSize { router.dynamicTypeOverride ?? environmentTypeSize }

    @State private var openMachineID: UUID?
    @State private var query = ""
    @State private var page: Int?
    @State private var emptyVariant = false
    @State private var justAdded: UUID?
    @State private var addCount = 0
    @State private var detent: PresentationDetent = .large

    private var gymID: UUID? {
        emptyVariant ? SampleData.gymID(SampleData.hotel) : (store.session?.gymID ?? store.selectedGymID)
    }
    private var gym: Gym? { store.gym(gymID) }
    private var machines: [Machine] { store.activeMachines(gymID: gymID) }

    var body: some View {
        ZStack {
            if let id = openMachineID, let machine = store.machine(id) {
                exerciseList(for: machine)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            } else {
                machineList
                    .transition(reduceMotion ? .opacity : .move(edge: .leading))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .liveSheetsPresentation(look)
        .presentationDetents([.medium, .large], selection: $detent)
        .sensoryFeedback(.success, trigger: addCount)
        .onAppear(perform: applyVariant)
    }

    // MARK: Machine list

    private var machineList: some View {
        VStack(spacing: 0) {
            LiveSheetsHeader(title: "Add by Machine", subtitle: gym?.name, leading: .cancel { router.dismissSheet() })
            if machines.isEmpty {
                emptyState
            } else {
                LiveSheetsScroll(page: page) {
                    VStack(alignment: .leading, spacing: 24) {
                        scanRow
                        ForEach(groups, id: \.title) { group in
                            let glyphs = LiveSheetsGlyphKind.exceptions(group.machines.map {
                                LiveSheetsGlyphKind.of(store.model($0.modelID)?.category)
                            })
                            let reserves = glyphs.contains { $0 != nil }
                            VStack(alignment: .leading, spacing: 8) {
                                LiveSheetsSectionHeader(title: group.title, family: group.family)
                                LookList(separatorInset: reserves ? 54 : 16) {
                                    ForEach(Array(group.machines.enumerated()), id: \.element.id) { index, machine in
                                        machineRow(machine, glyph: glyphs[index], reservesGlyph: reserves)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
            }
        }
    }

    /// No machines here yet: Scan Machine is the one filled command; Add Exercise (the whole
    /// catalog, logged on free weights) stays one quiet tap away so the set is never blocked.
    private var emptyState: some View {
        ScrollView {
        VStack(spacing: 12) {
            EmptyStateView(symbol: LookIcon.machine, title: "No machines yet")
            VStack(spacing: 10) {
                PrimaryButton("Scan Machine", symbol: "camera.viewfinder", action: scan)
                Button("Add Exercise") { router.present(.exercisePicker) }
                    .buttonStyle(.lookSecondary)
            }
            .padding(.horizontal, look.space.margin)
        }
        .padding(.top, 4)
        .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Machines grouped by the body area they train, head to toe. A station that serves three
    /// or more families (the cable station) is not "a chest machine": it goes under its catalog
    /// category ("Cable & functional") after the families.
    private var groups: [(title: String, family: MuscleFamily?, machines: [Machine])] {
        func group(of machine: Machine) -> (rank: Int, title: String, family: MuscleFamily?) {
            let muscleGroups = store.exerciseIDs(of: machine).compactMap { store.exercise($0)?.muscleGroup }
            let families = Set(muscleGroups.compactMap(\.family))
            if families.count >= 3 {
                let category = store.model(machine.modelID)?.category
                return (8, category?.label ?? EquipmentTag.machine.label, nil)
            }
            let groupOf = muscleGroups.first
            if let family = groupOf?.family {
                return (MuscleFamily.allCases.firstIndex(of: family) ?? 0, family.label, family)
            }
            if let groupOf { return (10 + (MuscleGroup.allCases.firstIndex(of: groupOf) ?? 0), groupOf.label, nil) }
            return (99, "Uncategorized", nil)
        }
        let keyed = machines.map { (key: group(of: $0), machine: $0) }
        let titles = Dictionary(grouping: keyed, by: { $0.key.title })
        return titles.map { title, items in
            (title: title, rank: items[0].key.rank, family: items[0].key.family, machines: items.map(\.machine))
        }
        .sorted { $0.rank < $1.rank }
        .map { (title: $0.title, family: $0.family, machines: $0.machines) }
    }

    private var scanRow: some View {
        Button(action: scan) {
            HStack(spacing: 12) {
                IconDisc(symbol: "camera.viewfinder", size: 34, context: .make)
                Text("Scan Machine").font(.system(.body, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: look.radius.row,
                           lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [6, 4])
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }

    private func machineRow(_ machine: Machine, glyph: LiveSheetsGlyphKind?, reservesGlyph: Bool) -> some View {
        let exerciseCount = store.exerciseIDs(of: machine).count
        let inWorkout = store.liveSheetsMachineInSession(machine.id)
        return LiveSheetsMachineRow(
            title: machine.label,
            subtitle: store.liveSheetsModelCaption(machine, gymID: gymID),
            glyph: glyph,
            reservesGlyph: reservesGlyph,
            unit: machine.defaultUnit,
            inWorkout: inWorkout,
            opensList: exerciseCount != 1,
            isAdded: justAdded == machine.id
        ) {
            if exerciseCount == 1 {
                if store.addByMachine(machine.id) != nil { didAdd(machine.id) }
            } else {
                push(machine.id)
            }
        }
    }

    // MARK: A machine's exercises

    private func exerciseList(for machine: Machine) -> some View {
        let linked = store.exerciseIDs(of: machine).compactMap { store.exercise($0) }
        let isCatalog = linked.isEmpty
        let catalog = store.exerciseSections(query: query).flatMap(\.exercises)
        return VStack(spacing: 0) {
            LiveSheetsHeader(title: isCatalog ? "Pick Exercise" : machine.label,
                             subtitle: isCatalog ? machine.label : gym?.name,
                             leading: .back("Add by Machine") { pop() })
            if isCatalog {
                SearchFieldView(text: $query, prompt: "Search exercises")
                    .padding(.horizontal, look.space.margin)
                    .padding(.bottom, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !isCatalog { machineCard(machine) }
                    LookList(separatorInset: 16) {
                        ForEach(isCatalog ? catalog : linked) { exercise in
                            exerciseRow(exercise, machine: machine, isCatalog: isCatalog)
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// The machine you opened: its model (the hardware, in full) and its use so far, so the
    /// page answers "which one is this, and have I been here before?".
    private func machineCard(_ machine: Machine) -> some View {
        let stats = store.machineStats(machine.id)
        let model = store.model(machine.modelID)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                LiveSheetsGlyphDisc(kind: .machine)
                VStack(alignment: .leading, spacing: 3) {
                    // No model: the header already names the machine, so the card says nothing
                    // rather than "No model".
                    if let model {
                        Text(model.displayName)
                            .font(.system(.headline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let detail = [model?.category?.label, machine.defaultUnit?.label].compactMap({ $0 }).joined(separator: " · ").liveSheetsNilIfEmpty {
                        Text(detail)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if stats.timesUsed > 0 {
                LookDivider()
                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    machineStat(Format.grouped(stats.timesUsed), label: "Times used")
                    if let last = stats.lastUsed {
                        machineStat(look.lastDoneLabel(last, now: store.now), label: "Last used")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(look.space.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    private func machineStat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(look.font.smallNumber)
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
    }

    /// One exercise on this machine: its muscle and load type, and your best on this machine
    /// with the day you last logged it here (the whole catalog shows the last time at this gym).
    private func exerciseRow(_ exercise: Exercise, machine: Machine, isCatalog: Bool) -> some View {
        let last = isCatalog ? store.liveSheetsLastLog(exerciseID: exercise.id, gymID: gymID)
                             : store.liveSheetsLastOnMachine(exerciseID: exercise.id, machineID: machine.id)
        let best = last?.best.map { look.previousLabel($0, rowUnit: store.defaultUnit(machine: machine, gymID: gymID),
                                                        loadType: exercise.loadType) }
        return LiveSheetsExerciseRow(
            title: exercise.name,
            subtitle: [exercise.muscleGroup?.label, exercise.loadType == .weighted ? nil : exercise.loadType.badge]
                .compactMap { $0 }.joined(separator: " · "),
            glyph: nil,
            trailing: last.map { look.lastDoneLabel($0.date, now: store.now) } ?? (isCatalog ? nil : "First time"),
            trailingValue: best,
            inWorkout: store.liveSheetsExerciseInSession(exercise.id),
            isAdded: justAdded == exercise.id,
            showsAdd: true
        ) {
            if store.addByMachine(machine.id, exerciseID: exercise.id) != nil { didAdd(exercise.id) }
        }
    }

    // MARK: Actions

    private func push(_ id: UUID) {
        query = ""
        if reduceMotion { openMachineID = id } else { withAnimation(.snappy(duration: 0.32)) { openMachineID = id } }
        detent = .large
    }

    private func pop() {
        if reduceMotion { openMachineID = nil } else { withAnimation(.snappy(duration: 0.32)) { openMachineID = nil } }
    }

    private func didAdd(_ rowID: UUID) {
        addCount += 1
        if reduceMotion { router.dismissSheet(); return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { justAdded = rowID }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { router.dismissSheet() }
    }

    private func scan() {
        guard let gymID else { return }
        store.scanBegin(gymID: gymID)
        router.present(.scan(gymID: gymID))
    }

    private func applyVariant() {
        let variant = LiveSheetsVariant.consume([.l07], store: store, router: router)
        page = LiveSheetsVariant.page(variant)
        if LiveSheetsVariant.has(variant, "empty") {
            // A workout just started at the Hotel Gym (no machines), so the live workout under
            // the sheet and the sheet agree on the gym.
            let hotel = SampleData.gymID(SampleData.hotel)
            if store.session?.gymID != hotel {
                store.cancelWorkout()
                store.selectGym(hotel)
                store.startLifting()
            }
            emptyVariant = true
        }
        // A gym with no machines: the half-height sheet keeps the live workout in view; at
        // accessibility sizes the empty state needs the full height.
        if machines.isEmpty && openMachineID == nil {
            detent = typeSize.isAccessibilitySize ? .large : .medium
        }
        if LiveSheetsVariant.has(variant, "machine") {
            openMachineID = SampleData.machineID(SampleData.ironTemple, "Pec Deck")
        }
        if LiveSheetsVariant.has(variant, "added") {
            // The moment after a tap: the check has popped in, the sheet has not closed yet.
            if let id = openMachineID, let machine = store.machine(id) {
                justAdded = store.exerciseIDs(of: machine).first
            } else {
                justAdded = SampleData.machineID(SampleData.ironTemple, "Seated Row")
            }
        }
    }
}

// MARK: - Machine row

/// Movement label + the model caption that tells it apart, the machine's own unit when it has
/// one, and one trailing mark: plus (adds now), chevron (pick its exercise) or, when this
/// workout already uses it, a lit check. The glyph shows only where the hardware differs from
/// its section; `reservesGlyph` keeps the column aligned in a section that has one.
struct LiveSheetsMachineRow: View {
    var title: String
    var subtitle: String?
    var glyph: LiveSheetsGlyphKind? = nil
    var reservesGlyph = false
    var unit: WeightUnit?
    var inWorkout: Bool
    var opensList: Bool
    var isAdded: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var mark: CGFloat = 26

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if reservesGlyph {
                    Group {
                        if let glyph { LiveSheetsGlyph(glyph) } else { Color.clear }
                    }
                    .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                    .frame(width: glyphColumn)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.system(.body, design: look.id == .anatomy ? .rounded : .default,
                                          weight: look.id.isPaperClub ? .medium : .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let unit {
                            Text(unit.label)
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(look.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .overlay { Capsule().strokeBorder(look.id.isPaperClub ? look.outline : look.hairline, lineWidth: 1) }
                                .accessibilityLabel("Unit \(unit.label)")
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailingMark
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 54 : 60, alignment: .leading)
        }
        .buttonStyle(LiveSheetsRowPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(inWorkout ? "In this workout" : "")
        .accessibilityHint(opensList ? "Shows its exercises" : "Adds it to the workout")
    }

    @ViewBuilder private var trailingMark: some View {
        if isAdded {
            LiveSheetsAddedCheck()
        } else if inWorkout {
            HStack(spacing: 10) {
                LiveSheetsInWorkoutMark(size: mark)
                if opensList { chevron }
            }
        } else if opensList {
            chevron
        } else {
            Image(systemName: "plus")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                .frame(minWidth: 20)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(.footnote, weight: .bold))
            .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
            .frame(minWidth: 20)
    }
}

/// "Already in this workout": a quiet outlined check, so the lit check that pops in on the row
/// you just tapped stays the one loud mark on the list.
struct LiveSheetsInWorkoutMark: View {
    var size: CGFloat
    @Environment(\.look) private var look
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.42, weight: .heavy))
            .foregroundStyle(look.textSecondary)
            .frame(width: size, height: size)
            .overlay { Circle().strokeBorder(look.id.isPaperClub ? look.textSecondary : look.hairline, lineWidth: 1.5) }
            .accessibilityLabel("In this workout")
    }
}

/// The check that pops in on the row you just tapped, before the sheet closes.
struct LiveSheetsAddedCheck: View {
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 30
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.46, weight: .heavy))
            .foregroundStyle(look.onDone)
            .frame(width: size, height: size)
            .background(look.done, in: Circle())
            .overlay { if look.id.isPaperClub { Circle().strokeBorder(look.outline, lineWidth: 2) } }
            .transition(.scale(scale: 0.3).combined(with: .opacity))
            .accessibilityLabel("Added")
    }
}
