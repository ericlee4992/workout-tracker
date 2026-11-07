import SwiftUI

// PROTOTYPE — L10 Previous performance for one live entry. One layer at a time, picked with a
// compact three-segment control (This machine / Same model / Any equipment; a menu at
// accessibility sizes): the best set and 1RM big on top, then the rep-best ladder 1–12 as bars,
// then the last sessions. Today's sets appear only on the layers that contain today's
// equipment (This machine, Any equipment). When today beats the layer's record, today's set
// becomes the hero (with the look's New best mark on This machine, 1RM recomputed) and the old
// record steps down to a "was 105 lb × 8 · Sep 17" line; in the ladder that rep count's bar
// rises to today's value with the new-best treatment. An empty layer shows its real one-line
// message and, under it, the layers that do have a best, one tap away. Done closes.
// Variants: "same", "any", "empty" / "noHistory" (an entry whose layer has no history), "assisted" (Assisted
// Pull-Up: the lower-is-better ladder), "reps10" (the 10-rep column selected).

struct PreviousPerformanceSheet: View {
    let entryID: UUID

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var environmentTypeSize
    /// The sheet root sits outside its own `.dynamicTypeSize` override, so it resolves the
    /// prototype override itself (children read the environment as usual).
    private var typeSize: DynamicTypeSize { router.dynamicTypeOverride ?? environmentTypeSize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var overrideID: UUID?
    @State private var layerKind: PerformanceLayerKind = .thisEquipment
    @State private var selectedReps: Int?
    @State private var page: Int?
    @State private var loaded = false
    @State private var wantsEmptyLayer = false

    private var id: UUID { overrideID ?? entryID }
    private var entry: LiveEntry? { store.liveEntry(id) }
    private var performance: PreviousPerformance? { store.previousPerformance(entryID: id) }
    private var layer: PerformanceLayer? {
        performance?.layers.first { $0.kind == layerKind } ?? performance?.layers.first
    }
    private var unit: WeightUnit {
        entry?.sets.first?.unit ?? store.defaultUnit(machine: store.machine(entry?.machineID), gymID: store.session?.gymID)
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveSheetsHeader(title: performance?.exerciseName ?? "Previous performance",
                             subtitle: subtitle,
                             trailing: .done { router.dismissSheet() })
            if let performance {
                layerControl(performance)
                LookDivider()
                LiveSheetsScroll(page: page) {
                    VStack(alignment: .leading, spacing: 26) {
                        if let layer {
                            if layer.sessions.isEmpty || (layer.best == nil && layer.mostReps == nil) {
                                emptyLayer(layer)
                            }
                            if !layer.sessions.isEmpty {
                                if layer.best != nil || layer.mostReps != nil { hero(layer, loadType: performance.loadType) }
                                if performance.loadType != .bodyweight && !layer.repBests.isEmpty {
                                    ladder(layer, loadType: performance.loadType)
                                }
                                sessions(layer)
                            }
                        }
                    }
                    .id(layerKind)
                    .transition(.opacity)
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 18)
                    .padding(.bottom, 48)
                }
            }
        }
        .liveSheetsPresentation(look)
        .presentationDetents([.large])
        .sensoryFeedback(.selection, trigger: layerKind)
        .sensoryFeedback(.selection, trigger: selectedReps)
        .onAppear(perform: load)
        .onChange(of: store.session?.id) { if wantsEmptyLayer { pickEmptyLayer() } }
    }

    private var subtitle: String? {
        guard let entry else { return nil }
        return [store.liveSheetsEquipmentLabel(entry), performance?.presetName].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Layer control

    private func glyph(_ kind: PerformanceLayerKind) -> String {
        switch kind {
        case .thisEquipment:
            if entry?.machineID != nil { return LookIcon.machine }
            return entry?.freeWeightTag == .dumbbell ? "dumbbell" : "scalemass"
        case .sameModelElsewhere: return "building.2"
        case .anyEquipment: return "square.stack.3d.up"
        }
    }

    /// The segment label: the layer's own title, "Same model" for the long one.
    private func shortTitle(_ layer: PerformanceLayer) -> String {
        layer.kind == .sameModelElsewhere ? "Same model" : layer.title
    }

    /// Three equal segments in one row (icon + short label, the icon drops before the label
    /// would shrink). At accessibility sizes the three would not fit, so it becomes a menu.
    @ViewBuilder
    private func layerControl(_ performance: PreviousPerformance) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                layerMenu(performance)
            } else {
                LiveSheetsLayerSegments(items: performance.layers.map { item in
                    LiveSheetsLayerSegments.Item(kind: item.kind, title: shortTitle(item), symbol: glyph(item.kind),
                                                 isEmpty: item.sessions.isEmpty)
                }, selection: layer?.kind ?? .thisEquipment, onSelect: select)
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, 12)
    }

    private func layerMenu(_ performance: PreviousPerformance) -> some View {
        Menu {
            Picker("Layer", selection: Binding(get: { layer?.kind ?? .thisEquipment }, set: { select($0) })) {
                ForEach(performance.layers) { item in
                    Text(item.title).tag(item.kind)
                }
            }
        } label: {
            HStack(spacing: 10) {
                if let layer { LookIcon(glyph(layer.kind), style: .body) }
                Text(layer?.title ?? "")
                    .font(.system(.body, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(.footnote, weight: .bold))
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .lookSurface(.tile, radius: look.radius.row)
        }
    }

    // MARK: Hero: best set + 1RM

    /// Today's best completed working set in this entry, nil before the first one.
    private func todayBest(loadType: LoadType) -> SetValue? {
        Records.best(Array(todayByReps.values), loadType: loadType)
    }

    /// Today's sets belong on a layer only when that layer includes today's equipment.
    private func includesToday(_ layer: PerformanceLayer) -> Bool { layer.kind != .sameModelElsewhere }

    /// Today's best when it beats this layer's record (or the layer has none yet).
    private func todayRecord(_ layer: PerformanceLayer, loadType: LoadType) -> SetValue? {
        guard includesToday(layer), loadType != .bodyweight, let today = todayBest(loadType: loadType) else { return nil }
        guard let best = layer.best else { return today }
        return Records.outranks(today, best, loadType: loadType) ? today : nil
    }

    private func hero(_ layer: PerformanceLayer, loadType: LoadType) -> some View {
        let promoted = todayRecord(layer, loadType: loadType)
        let best = promoted ?? layer.best
        let recordDate: Date? = layer.best.flatMap { b in layer.repBests.first { $0.reps == b.reps && $0.value == b }?.date }
        let bestDate: Date? = promoted != nil ? store.now : recordDate
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
        let today = includesToday(layer) ? todayBest(loadType: loadType) : nil
        return VStack(alignment: .leading, spacing: 14) {
            layout {
                heroFigures(layer, loadType: loadType, best: best, bestDate: bestDate, promoted: promoted != nil)
            }
            if let promoted, let old = layer.best {
                LookDivider()
                wasLine(old, layer: layer, loadType: loadType)
                    .accessibilityLabel("Previous best \(Format.set(old, loadType: loadType))")
            } else if promoted == nil, let today {
                LookDivider()
                todayLine(today, loadType: loadType)
            }
        }
        .padding(look.space.panelPadding + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    /// The record today's set just beat, demoted: "was 105 lb × 8 · Sep 17".
    private func wasLine(_ old: SetValue, layer: PerformanceLayer, loadType: LoadType) -> some View {
        let date = layer.repBests.first { $0.reps == old.reps && $0.value == old }?.date
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("was")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            Text(Format.set(old, loadType: loadType))
                .font(.system(.subheadline, weight: .bold).monospacedDigit())
                .foregroundStyle(look.textSecondary)
                .strikethrough(look.id.isPaperClub, color: look.textSecondary)
            if let date {
                Text("· \(Format.shortDate(date))")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textTertiary)
            }
        }
    }

    /// "Today 110 lb × 8" under a record it has not beaten.
    private func todayLine(_ today: SetValue, loadType: LoadType) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            LiveSheetsTodayMark()
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 1 }
            Text("Today")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            Text(Format.set(today, loadType: loadType))
                .font(look.font.smallNumber)
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func heroFigures(_ layer: PerformanceLayer, loadType: LoadType, best: SetValue?, bestDate: Date?,
                             promoted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                label(loadType == .bodyweight ? "Most reps" : "Best")
                // The New best mark belongs to the exact equipment (This machine).
                if promoted && layer.kind == .thisEquipment {
                    NewBestBadge(kind: .newBest).celebrate(promoted)
                }
            }
            if loadType == .bodyweight, let reps = layer.mostReps {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(reps)").font(look.font.heroNumber).foregroundStyle(look.textPrimary)
                    Text("reps").font(unitFont).foregroundStyle(look.textSecondary)
                }
            } else if let best {
                bestFigure(best, loadType: loadType)
            }
            if let bestDate {
                Text(promoted ? "Today" : Format.shortDate(bestDate))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if let kg = oneRepMaxKg(layer, promoted: promoted ? best : nil, loadType: loadType) {
            // Plain conversion into the unit the best set was entered in, so the two
            // figures side by side never mix kg and lb (Gangnam's 45 kg × 8 → 56.7 kg).
            let oneRMUnit = best?.unit ?? unit
            if typeSize.isAccessibilitySize { LookDivider() } else { LookDivider(vertical: true).padding(.horizontal, 14) }
            VStack(alignment: .leading, spacing: 6) {
                label("1RM")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Format.number((oneRMUnit.fromKg(kg) * 10).rounded() / 10))
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text(oneRMUnit.label).font(unitFont).foregroundStyle(look.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The layer's 1RM, recomputed with today's set when today holds the record (weighted only).
    private func oneRepMaxKg(_ layer: PerformanceLayer, promoted: SetValue?, loadType: LoadType) -> Double? {
        guard loadType == .weighted else { return layer.oneRepMaxKg }
        let todays = promoted.flatMap { v in v.kg.flatMap { Records.brzyckiKg(kg: $0, reps: v.reps) } }
        return [layer.oneRepMaxKg, todays].compactMap { $0 }.max()
    }

    private func bestFigure(_ value: SetValue, loadType: LoadType) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if loadType.takesWeight, let w = value.weight {
                Text(Format.weight(w)).font(look.font.heroNumber).foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: w))
                Text(value.unit.label).font(unitFont).foregroundStyle(look.textSecondary)
                Text("× \(value.reps)").font(look.font.statNumber).foregroundStyle(look.textPrimary)
            } else {
                Text("\(value.reps)").font(look.font.heroNumber).foregroundStyle(look.textPrimary)
                Text("reps").font(unitFont).foregroundStyle(look.textSecondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var unitFont: Font {
        .system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
    }

    // MARK: Rep-best ladder

    private func recordsTitle(_ loadType: LoadType) -> String {
        switch loadType {
        case .weighted: "Weight records"
        case .assisted: "Assistance records"
        case .bodyweightPlus: "Added-weight records"
        case .bodyweight: "Bodyweight record"
        }
    }

    private var entryLoadType: LoadType { performance?.loadType ?? .weighted }

    /// Today's completed working sets in this entry, best per rep count (lower wins when assisted).
    private var todayByReps: [Int: SetValue] {
        guard let entry else { return [:] }
        var result: [Int: SetValue] = [:]
        for set in entry.sets where set.isCompleted && set.type.countsTowardRecords {
            guard let reps = set.reps, (1...Records.repRecordCap).contains(reps) else { continue }
            let value = SetValue(weight: entry.total(of: set), unit: set.unit, reps: reps, bar: entry.barWeight)
            if let current = result[reps], !Records.outranks(value, current, loadType: entryLoadType) { continue }
            result[reps] = value
        }
        return result
    }

    private func ladder(_ layer: PerformanceLayer, loadType: LoadType) -> some View {
        let today = includesToday(layer) ? todayByReps : [:]
        let records = Dictionary(uniqueKeysWithValues: layer.repBests.map { ($0.reps, $0) })
        // Rep counts where today's set beats the record (or sets the first one).
        let beaten = Set(today.compactMap { reps, value -> Int? in
            guard let record = records[reps] else { return reps }
            return Records.outranks(value, record.value, loadType: loadType) ? reps : nil
        })
        let promoted = todayRecord(layer, loadType: loadType)
        let selected = selectedReps.flatMap { records[$0] != nil || today[$0] != nil ? $0 : nil }
            ?? promoted?.reps ?? layer.best?.reps ?? layer.repBests.first?.reps
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(recordsTitle(loadType), trailing: loadType == .assisted ? "Lower is better" : nil)
            VStack(alignment: .leading, spacing: 14) {
                LiveSheetsRepLadder(records: records, today: today, beaten: beaten, selected: selected,
                                    higherIsBetter: loadType.higherIsBetter) { reps in
                    if reduceMotion { selectedReps = reps } else { withAnimation(.snappy(duration: 0.22)) { selectedReps = reps } }
                }
                if let selected {
                    ladderDetail(reps: selected, record: records[selected], today: today[selected],
                                 isNewBest: beaten.contains(selected) && layer.kind == .thisEquipment,
                                 beats: beaten.contains(selected), loadType: loadType)
                }
            }
            .padding(look.space.panelPadding)
            .lookSurface(.panel)
        }
    }

    /// The selected rep count: its record and date. When today beat it, today's value leads
    /// (with the New best mark on This machine) and the old record reads "was …".
    private func ladderDetail(reps: Int, record: RepBest?, today: SetValue?, isNewBest: Bool, beats: Bool,
                              loadType: LoadType) -> some View {
        func weight(_ v: SetValue) -> String {
            Format.set(v, loadType: loadType).replacingOccurrences(of: " × \(reps)", with: "")
        }
        let lead = HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Format.reps(reps))
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(look.textPrimary)
            if beats, let today {
                Text(weight(today))
                    .font(.system(.subheadline, weight: .heavy).monospacedDigit())
                    .foregroundStyle(look.textPrimary)
                Text("Today").font(look.font.footnote).foregroundStyle(look.textTertiary)
            } else if let record {
                Text(weight(record.value))
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(look.textPrimary)
                Text(Format.shortDate(record.date))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textTertiary)
            }
        }
        let trailing = Group {
            if beats {
                HStack(spacing: 8) {
                    if let record {
                        Text("was \(weight(record.value))")
                            .font(.system(.footnote, weight: .semibold).monospacedDigit())
                            .foregroundStyle(look.textSecondary)
                    }
                    if isNewBest { NewBestBadge(kind: .newBest) }
                }
            } else if let today {
                HStack(spacing: 5) {
                    LiveSheetsTodayMark()
                    Text("Today \(weight(today))")
                        .font(.system(.footnote, weight: .semibold).monospacedDigit())
                        .foregroundStyle(look.textSecondary)
                }
            }
        }
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { lead; trailing }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) { lead; Spacer(minLength: 4); trailing }
                    VStack(alignment: .leading, spacing: 6) { lead; trailing }
                }
            }
        }
        .contentTransition(.numericText())
        .accessibilityElement(children: .combine)
    }

    // MARK: Sessions

    private func sessions(_ layer: PerformanceLayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("History")
            LookList(separatorInset: 16) {
                ForEach(layer.sessions) { session in sessionRow(session, loadType: performance?.loadType ?? .weighted) }
            }
        }
    }

    /// The equipment without its model ("Chest Press 2", not "Chest Press 2 · Life Fitness …").
    private func shortEquipment(_ label: String?) -> String? {
        label.flatMap { $0.components(separatedBy: " · ").first }
    }

    private func sessionRow(_ session: PerformanceSession, loadType: LoadType) -> some View {
        var working = 0
        let markers: [String] = session.types.map { type in
            if let marker = type.marker { return marker }
            working += 1
            return "\(working)"
        }
        let showGym = layerKind != .thisEquipment
        let bestIndex: Int? = {
            // Once today holds the layer's record, no past chip is "the best" any more.
            guard let current = layer, todayRecord(current, loadType: loadType) == nil,
                  let best = layer?.best,
                  let record = layer?.repBests.first(where: { $0.reps == best.reps && $0.value == best }),
                  Calendar.app.isDate(record.date, inSameDayAs: session.date) else { return nil }
            return session.sets.firstIndex(of: best)
        }()
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        let chips = Array(zip(session.sets.indices, session.sets))
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.day(session.date))
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(look.textPrimary)
                Text([showGym ? session.gymName : nil, layerKind == .anyEquipment ? shortEquipment(session.equipmentLabel) : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .lineLimit(2)
            }
            // A fixed grid (2 × 2 for four sets) so no chip is orphaned on its own line.
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<((chips.count + columns - 1) / columns), id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { col in
                            let i = row * columns + col
                            if i < chips.count {
                                let (index, value) = chips[i]
                                LiveSheetsSetChip(marker: index < markers.count ? markers[index] : "",
                                                  kind: index < session.types.count ? session.types[index] : .working,
                                                  text: look.previousLabel(value, rowUnit: unit, loadType: loadType),
                                                  isBest: index == bestIndex)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Empty

    private func emptyLayer(_ layer: PerformanceLayer) -> some View {
        VStack(spacing: 12) {
            LookIcon(glyph(layer.kind), style: .title2)
                .foregroundStyle(look.textSecondary)
                .frame(width: 60, height: 60)
                .background {
                    switch look.id {
                    case .floodlight: Circle().fill(look.surfaceRaised)
                    case .anatomy: Circle().fill(look.controlFill)
                    case .paper, .carbon: Circle().strokeBorder(look.outline, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    }
                }
            Text(layer.emptyMessage ?? "No history for this exercise yet.")
                .font(look.font.body)
                .foregroundStyle(look.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .lookSurface(.panel)
        .modifier(LiveSheetsEmptyLayerJumps(others: otherLayers(than: layer), loadType: performance?.loadType ?? .weighted,
                                            glyph: glyph, onSelect: select))
    }

    /// The other layers that do have a best, so an empty layer points to where the numbers are.
    private func otherLayers(than layer: PerformanceLayer) -> [PerformanceLayer] {
        (performance?.layers ?? []).filter { $0.kind != layer.kind && ($0.best != nil || $0.mostReps != nil) }
    }

    // MARK: Actions

    private func select(_ kind: PerformanceLayerKind) {
        let apply = { layerKind = kind; selectedReps = nil }
        if reduceMotion { apply() } else { withAnimation(.snappy(duration: 0.25)) { apply() } }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let variant = LiveSheetsVariant.consume([.l10], store: store, router: router)
        page = LiveSheetsVariant.page(variant)
        if LiveSheetsVariant.has(variant, "same") { layerKind = .sameModelElsewhere }
        if LiveSheetsVariant.has(variant, "any") { layerKind = .anyEquipment }
        if LiveSheetsVariant.has(variant, "reps10") { selectedReps = 10 }
        if LiveSheetsVariant.has(variant, "assisted") {
            // Assisted Pull-Up on the Assist Dip/Chin: the ladder where less assistance wins.
            overrideID = store.addExercise(SampleData.exerciseID("Assisted Pull-Up"))
        }
        if LiveSheetsVariant.has(variant, "empty") || LiveSheetsVariant.has(variant, "noHistory") {
            wantsEmptyLayer = true
            pickEmptyLayer()
        }
    }

    /// The first live entry with a layer that has no history (Incline Chest Press: no other
    /// gym). The live workout's own "empty" variant may restart the session after this sheet
    /// appears, so it re-runs on a new session and adds Incline Chest Press when needed.
    private func pickEmptyLayer() {
        func search() -> Bool {
            for candidate in store.session?.entries ?? [] {
                if let empty = store.previousPerformance(entryID: candidate.id)?.layers.first(where: { $0.sessions.isEmpty }) {
                    overrideID = candidate.id
                    layerKind = empty.kind
                    return true
                }
            }
            return false
        }
        if !search(), store.addExercise(SampleData.exerciseID("Incline Chest Press")) != nil { _ = search() }
    }
}

// MARK: - Rep ladder

/// Best set per rep count, 1–12, as zero-based bars (heaviest wins; assisted: least wins, so
/// the bar is the assistance). Today's sets are ticks on the same scale; where today beats the
/// record the bar itself rises to today's value with the new-best treatment. Tap a column to
/// read it. At accessibility sizes it becomes one row per rep count.
struct LiveSheetsRepLadder: View {
    var records: [Int: RepBest]
    var today: [Int: SetValue]
    var beaten: Set<Int> = []
    var selected: Int?
    var higherIsBetter: Bool
    var onSelect: (Int) -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown: Double = 0

    private var top: Double {
        max(1, (records.values.map { $0.value.kg ?? 0 } + today.values.map { $0.kg ?? 0 }).max() ?? 1)
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { rows } else { columns }
        }
        .appearProgress($grown, delay: 0.1, duration: 0.6)
    }

    private func barColor(_ reps: Int) -> Color {
        reps == selected ? look.selection : look.textPrimary.opacity(look.id.isPaperClub ? 0.28 : 0.30)
    }

    /// The value a column's bar shows: today's set where it beat the record, else the record.
    private func shown(_ reps: Int) -> SetValue? {
        beaten.contains(reps) ? today[reps] : records[reps]?.value
    }

    @ViewBuilder
    private func bar(_ reps: Int, height: CGFloat, horizontal: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: look.id == .anatomy ? 5 : 3, style: .continuous)
        if beaten.contains(reps) {
            // New best: C's highlighter bar with its ink edge; A / B the selection fill ringed
            // with the new-best outline.
            if look.id.isPaperClub {
                shape.fill(look.positive).overlay { shape.strokeBorder(look.onPositive, lineWidth: 1.5) }
            } else {
                shape.fill(reps == selected ? look.selection : look.positive.opacity(0.32))
                    .overlay { shape.strokeBorder(look.positive, lineWidth: 2) }
            }
        } else {
            shape.fill(barColor(reps))
        }
    }

    private var columns: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(1...Records.repRecordCap, id: \.self) { reps in
                column(reps)
            }
        }
        .frame(height: 170)
    }

    private func column(_ reps: Int) -> some View {
        let value = shown(reps)
        let isBeaten = beaten.contains(reps)
        let todayValue = isBeaten ? nil : today[reps]
        let isSelected = reps == selected
        return Button {
            if value != nil || todayValue != nil { onSelect(reps) }
        } label: {
            VStack(spacing: 5) {
                GeometryReader { geo in
                    let h = geo.size.height - 34
                    let barH = value.map { max(4, h * (($0.kg ?? 0) / top) * grown) } ?? 0
                    let tickH = todayValue.map { h * (($0.kg ?? 0) / top) * grown }
                    let labelLift = max(barH, (tickH ?? 0) + 2)
                    ZStack(alignment: .bottom) {
                        if value != nil {
                            bar(reps, height: barH).frame(height: barH)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(look.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                .frame(height: 10)
                        }
                        if let tickH {
                            LiveSheetsTodayTick()
                                .padding(.horizontal, -2)
                                .offset(y: -max(0, tickH - 3))
                        }
                        if let label = (value ?? todayValue)?.weight.map(Format.weight) {
                            VStack(spacing: 1) {
                                if isBeaten && !look.id.isPaperClub {
                                    Image(systemName: look.id == .anatomy ? "star.fill" : "burst.fill")
                                        .font(.system(.caption2, weight: .bold))
                                        .foregroundStyle(look.positive)
                                }
                                Text(label)
                                    .font(.system(.caption2, weight: isSelected || isBeaten ? .heavy : .semibold).monospacedDigit())
                                    .foregroundStyle(isSelected || isBeaten ? look.textPrimary : look.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .fixedSize()
                                    .padding(.horizontal, isBeaten && look.id.isPaperClub ? 3 : 0)
                                    .background {
                                        if isBeaten && look.id.isPaperClub {
                                            RoundedRectangle(cornerRadius: 3).fill(look.positive)
                                        }
                                    }
                            }
                            .alignmentGuide(.bottom) { d in d[.bottom] }
                            .offset(y: -(labelLift + 4))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                Text("\(reps)")
                    .font(.system(.caption2, weight: isSelected ? .heavy : .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? look.textPrimary : look.textTertiary)
                    .frame(minWidth: 18, minHeight: 18)
                    .background {
                        if isSelected {
                            Capsule().fill(look.id.isPaperClub ? look.actionText.opacity(0.16) : look.selectionFill)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility(reps))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(1...Records.repRecordCap, id: \.self) { reps in
                if let value = shown(reps) {
                    Button { onSelect(reps) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(Format.reps(reps)).font(look.font.subhead).foregroundStyle(look.textSecondary)
                                if beaten.contains(reps) { NewBestBadge(kind: .newBest) }
                                Spacer(minLength: 8)
                                Text(Format.weight(value.weight ?? 0, value.unit))
                                    .font(.system(.body, weight: .bold).monospacedDigit())
                                    .foregroundStyle(look.textPrimary)
                            }
                            GeometryReader { geo in
                                bar(reps, height: 8)
                                    .frame(width: max(6, geo.size.width * ((value.kg ?? 0) / top) * grown))
                            }
                            .frame(height: 10)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibility(reps))
                }
            }
        }
    }

    private func accessibility(_ reps: Int) -> String {
        var parts = [Format.reps(reps)]
        if let record = records[reps] { parts.append(Format.weight(record.value.weight ?? 0, record.value.unit)) }
        if let t = today[reps], let w = t.weight { parts.append("Today \(Format.weight(w, t.unit))") }
        if beaten.contains(reps) { parts.append("New best") }
        return parts.joined(separator: ", ")
    }
}

/// Today's mark in the hero and the ladder detail: the look's live dot; in B, where the live
/// colour is the same pearl as a selected bar, an open ring so "today" stays separate.
struct LiveSheetsTodayMark: View {
    @Environment(\.look) private var look
    var body: some View {
        Group {
            if look.id == .anatomy {
                Circle().strokeBorder(look.live, lineWidth: 2)
            } else {
                Circle().fill(look.live)
            }
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
}

/// Today's set on a ladder column: a live tick across it (B: an open outlined bar with the
/// sheet colour inside, so it never merges into a pearl bar).
struct LiveSheetsTodayTick: View {
    @Environment(\.look) private var look
    var body: some View {
        if look.id == .anatomy {
            Capsule().fill(look.surfaceSheet)
                .overlay { Capsule().strokeBorder(look.live, lineWidth: 2) }
                .frame(height: 7)
        } else {
            Capsule().fill(look.live).frame(height: 4)
        }
    }
}

/// The layer switcher: three equal segments in one row, icon + short label (the icon drops
/// before a label would shrink). An empty layer reads dimmer but stays tappable.
struct LiveSheetsLayerSegments: View {
    struct Item: Identifiable {
        var kind: PerformanceLayerKind
        var title: String
        var symbol: String
        var isEmpty: Bool
        var id: PerformanceLayerKind { kind }
    }
    var items: [Item]
    var selection: PerformanceLayerKind
    var onSelect: (PerformanceLayerKind) -> Void
    @Namespace private var namespace
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let selected = item.kind == selection
                Button { onSelect(item.kind) } label: {
                    ViewThatFits(in: .horizontal) {
                        label(item, selected: selected, showsIcon: true)
                        label(item, selected: selected, showsIcon: false)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: height)
                    .background {
                        if selected {
                            Capsule().fill(look.id.isPaperClub ? look.action : look.segmentFill)
                                .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.outline, lineWidth: 1.5) } }
                                .matchedGeometryEffect(id: "layer", in: namespace)
                        }
                    }
                    .opacity(item.isEmpty && !selected ? 0.55 : 1)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(look.id.isPaperClub ? look.ground : look.surface, in: Capsule())
        .overlay { if look.id.isPaperClub { Capsule().strokeBorder(look.hairline, lineWidth: 1.5) } }
    }

    private func label(_ item: Item, selected: Bool, showsIcon: Bool) -> some View {
        let color = selected ? (look.id.isPaperClub ? look.onAction : look.selection) : look.textSecondary
        return HStack(spacing: 5) {
            if showsIcon { LookIcon(item.symbol, style: .footnote) }
            Text(item.title)
                .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .fixedSize()
    }
}

// MARK: - Set chip (a logged set in a session line)

/// "W 45 × 12", "2 105 × 8": the marker and the value as entered. The layer's best is lit.
struct LiveSheetsSetChip: View {
    var marker: String
    var kind: SetType
    var text: String
    var isBest: Bool
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 6) {
            Text(marker)
                .font(.system(.caption2, weight: .heavy))
                .foregroundStyle(markerColor)
                .frame(minWidth: 16)
            Text(text)
                .font(.system(.footnote, weight: isBest ? .bold : .semibold).monospacedDigit())
                .foregroundStyle(isBest && look.id.isPaperClub ? look.onPositive : look.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            if isBest && look.id.isPaperClub {
                shape.fill(look.positive)
            } else if isBest {
                shape.strokeBorder(look.positive, lineWidth: 1.5)
            } else {
                shape.fill(look.id.isPaperClub ? look.groundSheet : look.surfaceRaised)
            }
        }
        .opacity(kind == .warmup ? 0.72 : 1)
    }

    private var markerColor: Color {
        if look.id == .anatomy {
            switch kind {
            case .warmup: return look.warmup
            case .drop: return look.drop
            case .failure: return look.failure
            case .working: return look.textSecondary
            }
        }
        if isBest && look.id.isPaperClub { return look.onPositive }
        return look.textSecondary
    }
}

// MARK: - Empty layer: where the numbers are

/// Under an empty layer's message: each other layer that has a best, as a row that switches to
/// it ("This machine  80 lb × 10  ›"), so the empty state is one tap from real numbers.
struct LiveSheetsEmptyLayerJumps: ViewModifier {
    var others: [PerformanceLayer]
    var loadType: LoadType
    var glyph: (PerformanceLayerKind) -> String
    var onSelect: (PerformanceLayerKind) -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content
            if !others.isEmpty {
                LookList(separatorInset: 54) {
                    ForEach(others) { layer in
                        Button { onSelect(layer.kind) } label: {
                            HStack(spacing: 12) {
                                LookIcon(glyph(layer.kind), style: .body)
                                    .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                                    .frame(width: 26)
                                // At accessibility sizes the value moves under the title.
                                let layout = typeSize.isAccessibilitySize
                                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                                    : AnyLayout(HStackLayout(spacing: 8))
                                layout {
                                    Text(layer.title)
                                        .font(.system(.body, design: look.id == .anatomy ? .rounded : .default,
                                                      weight: look.id.isPaperClub ? .medium : .semibold))
                                        .foregroundStyle(look.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                                    Text(value(layer))
                                        .font(.system(.subheadline, weight: .heavy).monospacedDigit())
                                        .foregroundStyle(look.textPrimary)
                                        .lineLimit(1)
                                }
                                if typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                                Image(systemName: "chevron.right")
                                    .font(.system(.footnote, weight: .bold))
                                    .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        }
                        .buttonStyle(LiveSheetsRowPressStyle())
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func value(_ layer: PerformanceLayer) -> String {
        if let best = layer.best, loadType != .bodyweight { return Format.set(best, loadType: loadType) }
        if let reps = layer.mostReps { return Format.reps(reps) }
        return ""
    }
}
