import SwiftUI

// S07 — Correct Model (D10: a correction asks whether it applies to future workouts only or to
// past ones too). Order follows the decision: what the model should be, then how far back it
// reaches. The header card names the machine; once a new model is picked it becomes the
// before → after (the old model struck, the new one inked) — until then the current model is
// shown once, as the "Current" row. The two scope tiles are the bold element: each carries its
// own timeline — one dot per past workout on this machine, a "Today" tick, then workouts to
// come — lit where the new model will show; the past tile states what it rewrites
// ("8 workouts · 33 sets"). Picking a model scrolls the tiles into view above the pinned
// button. "Correct Model" is a neutral, disabled capsule until the model changes; with past
// workouts chosen it asks once (a system confirmation) before rewriting them.
// Variants: "picked" (a new model and past workouts chosen, scrolled to the tiles), "confirm"
// (picked, with the confirmation open), "search" (the catalog search page), "p2" / "p3".

struct ModelCorrectionSheet: View {
    let machineID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var choice: ScanModelChoice?
    @State private var scope: CorrectionScope = .futureOnly
    @State private var path: [ScanCorrectionPage] = []
    @State private var commits = 0
    @State private var picks = 0
    @State private var appliedVariant = false
    @State private var scopeFocus = 0
    @State private var confirmingPast = false

    private var machine: Machine? { store.machine(machineID) }
    /// This view sits above its own `scanTypeOverride`, so it reads the override directly.
    private var isAX: Bool {
        (router.dynamicTypeOverride ?? typeSize).isAccessibilitySize
    }
    private var currentModelID: UUID? { machine?.modelID }

    /// The model the machine would have after the correction.
    private var targetModelID: UUID? {
        switch choice {
        case .model(let id): id
        case .noModel: nil
        case nil: currentModelID
        }
    }
    private var changes: Bool { choice != nil && targetModelID != currentModelID }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScanTopBar(title: "Correct Model", onCancel: { router.dismissSheet() })
                ScanPagedScroll(page: router.scanCapturePage, focusID: "scanScope", focusTick: scopeFocus) {
                    VStack(alignment: .leading, spacing: 22) {
                        ScanInlineTitle(title: "Correct Model")
                        header
                        modelList
                        scopeTiles
                            .id("scanScope")
                    }
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                } bar: {
                    ScanBottomBar {
                        ScanPrimaryButton("Correct Model", symbol: "checkmark", enabled: changes, action: commit)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ScanCorrectionPage.self) { _ in
                ScanModelSearchPage(selectedID: targetModelID, onBack: { path.removeLast() }) { id in
                    pick(id.map(ScanModelChoice.model) ?? .noModel)
                    path.removeLast()
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .lookSheetGround()
        .environment(\.scanForcedReduceMotion, router.scanVariant("rm"))
        .scanTypeOverride(router.dynamicTypeOverride)
        .presentationDetents([.large])
        .onAppear(perform: applyVariant)
        .confirmationDialog(pastQuestion, isPresented: $confirmingPast, titleVisibility: .visible) {
            Button(CorrectionScope.applyToPast.title) { apply() }
            Button("Cancel", role: .cancel) {}
        }
        .sensoryFeedback(.selection, trigger: picks)
        .sensoryFeedback(.success, trigger: commits)
    }

    private func applyVariant() {
        guard !appliedVariant else { return }
        appliedVariant = true
        if router.scanVariant("picked") || router.scanVariant("confirm"), let first = suggestions.first {
            choice = .model(first.id)
            scope = .applyToPast
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { scopeFocus += 1 }
        }
        if router.scanVariant("confirm") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { confirmingPast = true }
        }
        if router.scanVariant("search") { path = [.search] }
    }

    /// "Change the model in 8 past workouts?"
    private var pastQuestion: String {
        let n = store.correctionImpact(machineID: machineID).workouts
        return "Change the model in \(n) past \(n == 1 ? "workout" : "workouts")?"
    }

    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8) }

    private func pick(_ newChoice: ScanModelChoice) {
        picks += 1
        withAnimation(motion) {
            // Choosing the current model again means "no change".
            if case .model(let id) = newChoice, id == currentModelID { choice = nil } else { choice = newChoice }
        }
        // The next decision is how far back it reaches: bring the tiles up above the button.
        if changes { scopeFocus += 1 }
    }

    private func commit() {
        guard changes else { return }
        if scope == .applyToPast && store.correctionImpact(machineID: machineID).workouts > 0 {
            confirmingPast = true
        } else {
            apply()
        }
    }

    private func apply() {
        guard changes else { return }
        commits += 1
        store.correctModel(machineID: machineID, to: targetModelID, scope: scope)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.dismissSheet() }
    }

    // MARK: Header: the machine, and its model before → after

    private var header: some View {
        let oldName = store.model(currentModelID)?.displayName
        let newName = store.model(targetModelID)?.displayName
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ScanGlyphDisc(symbol: LookIcon.machine, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(machine?.label ?? "Machine")
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let gym = store.gym(machine?.gymID) {
                        Text(gym.name)
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if changes {
                LookDivider()
                VStack(alignment: .leading, spacing: 6) {
                    ScanModelLine(name: oldName, struck: true)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(look.id.isPaperClub ? look.actionText : look.selection)
                            .accessibilityHidden(true)
                        ScanModelLine(name: newName, struck: false, emphasised: true)
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

    // MARK: Models

    /// Other models that serve this machine's exercises (the likely corrections): models named
    /// for the machine's movement first ("Lat Pulldown"), then those sharing the most exercises,
    /// then A–Z.
    private var suggestions: [EquipmentModel] {
        guard let machine else { return [] }
        let served = Set(store.exerciseIDs(of: machine))
        let movement = machine.label.lowercased()
        func rank(_ m: EquipmentModel) -> (Int, Int) {
            (m.modelName.lowercased().contains(movement) ? 0 : 1, -served.intersection(m.exerciseIDs).count)
        }
        return store.models
            .filter { $0.id != currentModelID && !served.isDisjoint(with: $0.exerciseIDs) }
            .sorted { a, b in
                let ra = rank(a), rb = rank(b)
                return ra != rb ? ra < rb : a.displayName < b.displayName
            }
    }

    private var modelList: some View {
        LookList(separatorInset: 56) {
            if let current = store.model(currentModelID) {
                modelRow(current, tag: "Current")
            }
            ForEach(suggestions) { model in modelRow(model, tag: nil) }
            // A model the search picked that is not among the suggestions.
            if case .model(let id) = choice, id != currentModelID, !suggestions.contains(where: { $0.id == id }),
               let picked = store.model(id) {
                modelRow(picked, tag: nil)
            }
            Button { pick(.noModel) } label: {
                HStack(spacing: 14) {
                    ScanRadio(selected: choice == .noModel || (choice == nil && currentModelID == nil))
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
            .accessibilityAddTraits(choice == .noModel ? .isSelected : [])
            LookRow("Catalog Model", symbol: "magnifyingglass", value: Format.grouped(SampleData.catalogModelCount)) {
                path.append(.search)
            }
        }
    }

    private func modelRow(_ model: EquipmentModel, tag: String?) -> some View {
        let selected = model.id == targetModelID && choice != .noModel
        let ax = isAX
        return Button { pick(.model(model.id)) } label: {
            HStack(spacing: 14) {
                ScanRadio(selected: selected)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.manufacturer)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    Text(model.modelName)
                        .font(.system(.body, weight: .semibold))
                        .fontDesign(look.id == .anatomy ? .rounded : nil)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // At accessibility sizes the tag drops under the name instead of squeezing it.
                    if let tag, ax { tagView(tag).padding(.top, 4) }
                }
                Spacer(minLength: 8)
                if let tag, !ax { tagView(tag) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(look.font.badge)
            .foregroundStyle(look.textSecondary)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .overlay { Capsule().strokeBorder(look.hairline, lineWidth: look.id.isPaperClub ? 1.5 : 1) }
    }

    // MARK: Scope (the bold element)

    private var scopeTiles: some View {
        let impact = store.correctionImpact(machineID: machineID)
        let layout = isAX ? AnyLayout(VStackLayout(spacing: 10))
                                                  : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            ForEach(CorrectionScope.allCases) { option in
                ScanScopeTile(option: option, pastCount: impact.workouts, setCount: impact.sets,
                              selected: scope == option) {
                    picks += 1
                    withAnimation(motion) { scope = option }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The correction target: a catalog/user model, or no model at all.
enum ScanModelChoice: Hashable {
    case model(UUID)
    case noModel
}

enum ScanCorrectionPage: Hashable {
    case search
}

/// A model name, struck through once it is being replaced.
private struct ScanModelLine: View {
    var name: String?
    var struck: Bool
    var emphasised = false
    @Environment(\.look) private var look

    var body: some View {
        Text(name ?? "None")
            // A's title face is Expanded Black; a long model name reads better at standard width.
            .font(emphasised ? (look.id == .floodlight ? .system(.title3, weight: .heavy) : look.font.title3)
                             : .system(.body, weight: .semibold))
            .foregroundStyle(emphasised ? look.textPrimary : (struck ? look.textTertiary : look.textPrimary))
            .strikethrough(struck, color: look.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A scope choice: glyph, radio and the real title over its own timeline. The selected tile takes
/// the selection treatment (A a white edge on a raised fill, B a pearl edge, C a cobalt edge on
/// the pressed fill) and its dots light; the other tile's dots stay dim.
private struct ScanScopeTile: View {
    var option: CorrectionScope
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
                    .fontDesign(look.id == .anatomy ? .rounded : nil)
                    .multilineTextAlignment(.leading)
                    .lineLimit(typeSize.isAccessibilitySize ? 6 : 2, reservesSpace: !typeSize.isAccessibilitySize)
                    .fixedSize(horizontal: false, vertical: true)
                ScanCorrectionTimeline(pastCount: pastCount, includesPast: option == .applyToPast, lit: selected)
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
            .background(fill, in: RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous)
                    .strokeBorder(edge, lineWidth: edgeWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityValue(option == .applyToPast
                            ? "Rewrites \(pastCount) past workouts, \(setCount) sets" : "Past workouts keep the old model")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var fill: Color {
        switch look.id {
        case .floodlight: selected ? look.surfaceRaised : look.surfaceSheet
        case .anatomy: look.surfaceSheet
        case .paper, .carbon: selected ? look.pressedFill : look.surface
        }
    }
    private var edge: Color {
        switch look.id {
        case .floodlight: selected ? look.done : look.hairline
        case .anatomy: selected ? look.selection : look.hairline
        case .paper, .carbon: selected ? look.actionText : look.outline
        }
    }
    private var edgeWidth: CGFloat {
        switch look.id {
        case .floodlight, .anatomy: selected ? 2 : 1
        case .paper, .carbon: selected ? 3 : 2
        }
    }
}

/// One dot per past workout on this machine (at most 10), a "Today" tick, then three workouts
/// to come. Dots the new model reaches are filled — in the selection colour when the tile is
/// chosen, dim otherwise; dots it leaves alone are open rings. The past dots light right to
/// left (most recent first). Reduce Motion: they switch at once.
struct ScanCorrectionTimeline: View {
    var pastCount: Int
    var includesPast: Bool
    var lit: Bool
    @Environment(\.look) private var look
    @ScanReduceMotion private var reduceMotion
    @State private var tickX: CGFloat = 0

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
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("scanTimeline")).midX } action: { tickX = $0 }
                HStack(spacing: 4) {
                    ForEach(0..<futureCount, id: \.self) { _ in dotView(filled: true) }
                }
                Spacer(minLength: 0)
            }
            Text("Today")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(look.textSecondary)
                .fixedSize()
                .alignmentGuide(.leading) { d in d.width / 2 - tickX }
        }
        .coordinateSpace(.named("scanTimeline"))
        .accessibilityHidden(true)
    }

    @ViewBuilder private func dotView(filled: Bool) -> some View {
        if filled {
            Circle()
                .fill(lit ? (look.id.isPaperClub ? look.actionText : look.selection) : look.textTertiary.opacity(0.55))
                .frame(width: dot, height: dot)
                .scaleEffect(lit || reduceMotion ? 1 : 0.85)
        } else {
            Circle()
                .strokeBorder(look.textTertiary.opacity(0.7), lineWidth: 1.5)
                .frame(width: dot, height: dot)
        }
    }
}

// MARK: - Catalog search

/// "Catalog Model": search every model, filter by equipment type, pick one (or None).
private struct ScanModelSearchPage: View {
    var selectedID: UUID?
    var onBack: () -> Void
    var onPick: (UUID?) -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @State private var query = ""
    @State private var category: EquipmentCategory?

    var body: some View {
        let results = store.searchModels(query: query, category: category)
        VStack(spacing: 0) {
            ZStack {
                Text("Catalog Model")
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    GlassIconButton("chevron.left", accessibilityLabel: "Back", action: onBack)
                    Spacer()
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
            .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SearchFieldView(text: $query, prompt: "Search manufacturer or model")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Chip("All types", isSelected: category == nil) { category = nil }
                            ForEach(EquipmentCategory.allCases) { c in
                                Chip(c.label, isSelected: category == c) { category = category == c ? nil : c }
                            }
                        }
                        .padding(.horizontal, look.space.margin)
                    }
                    .padding(.horizontal, -look.space.margin)
                    LookList(separatorInset: 16) {
                        Button { onPick(nil) } label: {
                            HStack {
                                Text("None").font(.system(.body, weight: .semibold)).foregroundStyle(look.textPrimary)
                                Spacer()
                                if selectedID == nil { ScanRadio(selected: true) }
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.lookPressable)
                        ForEach(results) { model in
                            Button { onPick(model.id) } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.displayName)
                                            .font(.system(.body, weight: .medium))
                                            .foregroundStyle(look.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(subline(model))
                                            .font(look.font.footnote)
                                            .foregroundStyle(look.textSecondary)
                                    }
                                    Spacer(minLength: 8)
                                    if model.id == selectedID { ScanRadio(selected: true) }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minHeight: 60)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.lookPressable)
                        }
                    }
                    if results.isEmpty {
                        Text("No models match")
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .lookSheetGround()
    }

    /// "Custom · Plate-loaded · Quads" — one separator, in the catalog's order.
    private func subline(_ model: EquipmentModel) -> String {
        var parts: [String] = []
        if !model.isSeeded { parts.append("Custom") }
        if let c = model.category { parts.append(c.label) }
        let groups = model.exerciseIDs.compactMap { store.exercise($0)?.muscleGroup?.label }
        var seen = Set<String>()
        parts.append(contentsOf: groups.filter { seen.insert($0).inserted })
        return parts.joined(separator: " · ")
    }
}
