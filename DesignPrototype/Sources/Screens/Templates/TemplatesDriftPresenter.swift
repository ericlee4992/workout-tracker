import SwiftUI

// PROTOTYPE — the start-flow and template-drift prompts, hosted once at the root
// (RootView applies `templateDriftPresenter()` to the tab view):
//  • W05 "A workout is already in progress" when a template Start finds a live workout
//    (store.pendingStart): what runs vs what would start, Finish It & Start New / Resume Workout.
//    If the live workout drifted from its template, the same sheet turns into the drift choice
//    (store.pendingReplacementDrift, cancel "Keep Current Workout").
//  • T03 after a finish (store.pendingDrift), once the finish receipt has closed.
// The drift choice is a visual diff: each change shows the template's rep targets after the
// selected resolution (rows in ink = written, dimmed = left alone), so the options explain themselves.

extension View {
    func templateDriftPresenter() -> some View { modifier(TemplatesPromptPresenter()) }
}

enum TemplatesPrompt: String, Identifiable, Hashable {
    case start, finishDrift
    var id: String { rawValue }
}

struct TemplatesPromptPresenter: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @State private var shown: TemplatesPrompt?
    @State private var lastShown: TemplatesPrompt?
    @State private var scheduled: TemplatesPrompt?
    /// What closing the sheet should do: an action chosen in it, or nothing (a state change).
    @State private var closeAction: (() -> Void)?
    @State private var closingProgrammatically = false

    private var wanted: TemplatesPrompt? {
        if store.pendingStart != nil { return .start }
        let coverUp = store.session != nil && store.isSessionPresented
        if store.pendingDrift != nil, router.sheet == nil, !router.showFinishAfterCover, !coverUp, !router.aiRoutinePresented {
            return .finishDrift
        }
        return nil
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: wanted, initial: true) { _, new in sync(new) }
            .onAppear {
                if router.pendingDialog == .w05 || router.pendingDialog == .t03 { router.pendingDialog = nil }
                // `-screen W05 -variant drift`: open straight in the replacement drift choice
                // (as if "Finish It & Start New" was tapped), so the capture never races the tap.
                if router.variant?.hasPrefix("drift") == true, store.currentScreen == .w05, store.pendingReplacementDrift == nil {
                    store.confirmPendingStart()
                }
            }
            .sheet(item: $shown, onDismiss: didDismiss) { prompt in
                Group {
                    switch prompt {
                    case .start: TemplatesStartConflictSheet(close: close)
                    case .finishDrift: TemplatesFinishDriftSheet(close: close)
                    }
                }
                .look(look)
                .modifier(TemplatesTypeOverride(size: router.dynamicTypeOverride))
            }
    }

    /// Runs `action` once the sheet has gone (so a live cover can rise cleanly).
    private func close(_ action: @escaping () -> Void) {
        closeAction = action
        shown = nil
    }

    private func sync(_ new: TemplatesPrompt?) {
        if let new {
            if let shown, shown != new {
                closingProgrammatically = true
                self.shown = nil
                return
            }
            guard shown == nil, scheduled == nil else { return }
            scheduled = new
            // Present only once the state has held for a beat (checked twice), so a live cover
            // closing or the finish receipt about to rise always goes first.
            DispatchQueue.main.asyncAfter(deadline: .now() + (new == .start ? 0.25 : 0.5)) {
                guard wanted == new else { scheduled = nil; sync(wanted); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scheduled = nil
                    guard shown == nil else { return }
                    if let current = wanted, current == new {
                        lastShown = current
                        shown = current
                    } else {
                        sync(wanted)
                    }
                }
            }
        } else if shown != nil, closeAction == nil {
            closingProgrammatically = true
            shown = nil
        }
    }

    private func didDismiss() {
        if let action = closeAction {
            closeAction = nil
            action()
        } else if closingProgrammatically {
            closingProgrammatically = false
        } else {
            // Swiped away: nothing starts and the template stays as it is.
            switch lastShown {
            case .start: store.cancelPendingStart()
            case .finishDrift: store.dismissDrift()
            case nil: break
            }
        }
        DispatchQueue.main.async { sync(wanted) }
    }
}

// MARK: - W05: a workout is already in progress

struct TemplatesStartConflictSheet: View {
    var close: (@escaping () -> Void) -> Void
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var conflictHeight: CGFloat = 540

    var body: some View {
        Group {
            if let drift = store.pendingReplacementDrift {
                TemplatesDriftContent(drift: drift, mode: .replacement, close: close)
                    .transition(.opacity)
            } else {
                conflict
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.pendingReplacementDrift != nil)
        .lookSheetGround()
        // The conflict is compact (exactly its content); the drift choice takes the full height.
        .presentationDetents(fullHeight ? [.large] : [.height(conflictHeight + 4)])
        .presentationDragIndicator(.visible)
        .onAppear {
            // W05 "drift" opened from the screen index (the launch path is handled by the presenter).
            if router.variant?.hasPrefix("drift") == true, store.currentScreen == .w05, store.pendingReplacementDrift == nil {
                store.confirmPendingStart()
            }
        }
    }

    private var fullHeight: Bool { store.pendingReplacementDrift != nil || typeSize.isAccessibilitySize }

    private var pendingTemplate: Template? { store.template(store.pendingStart?.templateID) }

    private var conflict: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A workout is already in progress")
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 8) {
                    liveCard
                    Image(systemName: "arrow.down")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(look.textSecondary)
                        .accessibilityHidden(true)
                    nextCard
                }
                Text("Completed sets and recorded cardio are kept.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    PrimaryButton("Finish It & Start New", symbol: "flag.checkered") { finishAndStart() }
                    Button("Resume Workout") { close { store.resumeInsteadOfPending() } }
                        .buttonStyle(.lookSecondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { conflictHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func finishAndStart() {
        if !store.settings.suppressTemplatePrompts && store.liveDrift != nil {
            // The live workout drifted from its template: ask how to save it first (same sheet).
            store.confirmPendingStart()
        } else {
            close { store.confirmPendingStart() }
        }
    }

    private var liveCard: some View {
        let s = store.session
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TemplatesLiveDot(color: look.live, size: 9)
                    Text(store.sessionTitle)
                        .font(look.font.tileTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let s, s.totalSetCount > 0 {
                    SetsRingLabel(done: s.completedSetCount, total: s.totalSetCount)
                }
            }
            Spacer(minLength: 8)
            Text(Format.elapsed(store.sessionElapsed))
                .font(look.font.timer)
                .monospacedDigit()
                .foregroundStyle(look.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .fixedSize()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
    }

    private var nextCard: some View {
        let t = pendingTemplate
        // AX sizes: the maps sit above the name so the name never squeezes.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                                  : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            if let t {
                FamilyStrip(families: store.families(ofTemplate: t.id), size: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(t?.name ?? "Workout")
                    .font(look.font.tileTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let t, !t.templatesSummary.isEmpty {
                    Text(t.templatesSummary).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: look.radius.panel,
                       lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: look.id.isPaperClub ? [6, 4] : [5, 4])
        .accessibilityElement(children: .combine)
    }
}

/// A small live pulse (the running workout).
struct TemplatesLiveDot: View {
    var color: Color
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripple = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle().stroke(color, lineWidth: 1.5)
                    .scaleEffect(ripple ? 2.6 : 1)
                    .opacity(ripple ? 0 : 0.8)
            }
            Circle().fill(color)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { ripple = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - T03: after a finish

struct TemplatesFinishDriftSheet: View {
    var close: (@escaping () -> Void) -> Void
    @Environment(Store.self) private var store

    var body: some View {
        Group {
            if let drift = store.pendingDrift {
                TemplatesDriftContent(drift: drift, mode: .finish, close: close)
            } else {
                Color.clear
            }
        }
        .lookSheetGround()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - The drift choice (shared)

struct TemplatesDriftContent: View {
    enum Mode { case finish, replacement }
    let drift: TemplateDrift
    let mode: Mode
    var close: (@escaping () -> Void) -> Void

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var choice: DriftResolution
    @State private var dontAsk = false
    @State private var committed = false

    init(drift: TemplateDrift, mode: Mode, close: @escaping (@escaping () -> Void) -> Void) {
        self.drift = drift
        self.mode = mode
        self.close = close
        _choice = State(initialValue: Self.safeDefault(drift: drift, mode: mode))
    }

    /// The preselected option never shrinks a template by accident: a workout abandoned for
    /// another one (W05) or one that skipped exercises preselects Keep Original; a normal
    /// finish that only added to the plan preselects Update Template.
    static func safeDefault(drift: TemplateDrift, mode: Mode) -> DriftResolution {
        if mode == .replacement { return .keepOriginal }
        let shrinks = drift.changes.contains { change in
            switch change.kind {
            case .removed: true
            case .setCount(let from, let to): to < from
            default: false
            }
        }
        return shrinks ? .keepOriginal : .updateTemplate
    }

    private struct Row: Identifiable {
        var change: DriftChange
        var before: [Int]?
        /// The template's targets for this exercise after each resolution (nil = not in it).
        /// `-1` is a set whose reps are not known before the workout is saved.
        var after: [DriftResolution: TemplatesTargets]
        var id: UUID { change.id }
    }

    var body: some View {
        let rows = makeRows()
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                choices(rows)
                diff(rows)
                LookToggleRow("Don't ask again", isOn: $dontAsk)
                    .lookSurface(.panel)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 32)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
        .modifier(TemplatesVariantScroll(variant: router.variant, active: store.currentScreen == .t03 || store.currentScreen == .w05))
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        // Content scrolled past the top fades into the sheet's ground under the grabber
        // (the title starts below the fade at rest).
        .overlay(alignment: .top) {
            LinearGradient(stops: [.init(color: look.groundSheet, location: 0), .init(color: look.groundSheet, location: 0.55),
                                   .init(color: look.groundSheet.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 34)
                .allowsHitTesting(false)
        }
        .clipShape(Rectangle())
        .sensoryFeedback(.selection, trigger: choice)
        .sensoryFeedback(.success, trigger: committed)
        .onAppear {
            // `-variant template|values|both|keep` (T03, W05 drift-…): open with that option chosen.
            let tokens = Set((router.variant ?? "").split(separator: "-").map(String.init))
            if tokens.contains("template") { choice = .updateTemplate }
            if tokens.contains("values") { choice = .updateValuesOnly }
            if tokens.contains("both") { choice = .updateBoth }
            if tokens.contains("keep") { choice = .keepOriginal }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Update workout template?")
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                FamilyStrip(families: store.families(ofTemplate: drift.templateID), size: 26)
                Text(drift.templateName)
                    .font(look.font.tileTitle)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if mode == .replacement, let next = store.template(store.pendingStart?.templateID) {
                // What starts once this one is saved: an arrow, not a sentence.
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(look.textTertiary)
                        .frame(width: 26)
                    FamilyStrip(families: store.families(ofTemplate: next.id), size: 22)
                    Text(next.name)
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Next: \(next.name)")
            }
        }
    }

    // MARK: Diff

    /// One row per change. A row the chosen option writes is in ink; a row it leaves alone is
    /// dimmed and shows the template as it stays. Strikethrough is kept for an exercise the
    /// option removes.
    private func diff(_ rows: [Row]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { LookDivider().padding(.leading, 14) }
                diffRow(row)
            }
        }
        .lookSurface(.panel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: choice)
    }

    private var rowTitleFont: Font {
        switch look.id {
        case .floodlight: Font.system(.headline, weight: .heavy).width(.expanded)
        case .anatomy: .system(.headline, design: .rounded, weight: .bold)
        case .paper, .carbon: .system(.headline, design: .serif, weight: .heavy)
        }
    }

    private func applies(_ row: Row, _ resolution: DriftResolution) -> Bool {
        row.after[resolution]?.reps != row.before
    }

    private func diffRow(_ row: Row) -> some View {
        let after = row.after[choice]?.reps
        let applied = applies(row, choice)
        let removesExercise = applied && row.before != nil && after == nil
        let ink = applied ? look.textPrimary : look.textTertiary
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.change.exerciseName)
                    .font(rowTitleFont)
                    .foregroundStyle(removesExercise ? look.textSecondary : ink)
                    .strikethrough(removesExercise, color: look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if !isReps(row.change) { badge(row.change.badge, applied: applied) }
            }
            TemplatesFlowLayout(spacing: 4, lineSpacing: 6) {
                ForEach(Array(pills(row, after: after, applied: applied).enumerated()), id: \.offset) { _, pill in
                    TemplatesRepPill(reps: pill.reps, style: pill.style)
                }
            }
            if case .reps(let from, let to) = row.change.kind { repsLine(from: from, to: to, applied: applied) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.change.exerciseName), \(row.change.badge)")
        .accessibilityValue(applied ? "Changes the template" : "Template stays")
    }

    /// "12, 12, 10, 10 → 12, 12, 8, 10": the old targets faint, the new ones in ink when they
    /// are written (all faint when the option leaves them).
    private func repsLine(from: [Int], to: [Int], applied: Bool) -> some View {
        let font = Font.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold).monospacedDigit()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { repsText(from, to, applied: applied, font: font) }
            VStack(alignment: .leading, spacing: 2) { repsText(from, to, applied: applied, font: font) }
        }
    }

    @ViewBuilder private func repsText(_ from: [Int], _ to: [Int], applied: Bool, font: Font) -> some View {
        Text(from.map(String.init).joined(separator: ", "))
            .font(font)
            .foregroundStyle(look.textTertiary)
        HStack(spacing: 6) {
            Image(systemName: "arrow.right").font(.system(.caption, weight: .bold))
                .foregroundStyle(look.textTertiary)
            Text(to.map(String.init).joined(separator: ", "))
                .font(font)
                .foregroundStyle(applied ? look.textPrimary : look.textTertiary)
        }
    }

    private func isReps(_ change: DriftChange) -> Bool {
        if case .reps = change.kind { return true }
        return false
    }

    /// The change's badge ("+1 set", "Removed", "New"): inked when written, outlined and faint
    /// when the option leaves it.
    private func badge(_ text: String, applied: Bool) -> some View {
        Text(text)
            .font(.system(.caption, design: look.id == .anatomy ? .rounded : .default, weight: .heavy))
            .foregroundStyle(applied ? look.onDone : look.textTertiary)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background { if applied { Capsule().fill(look.done) } }
            .overlay { if !applied { Capsule().strokeBorder(look.textTertiary, lineWidth: 1) } }
            .fixedSize()
    }

    private struct Pill { var reps: Int?; var style: TemplatesRepPill.Style }

    private func pills(_ row: Row, after: [Int]?, applied: Bool) -> [Pill] {
        func value(_ r: Int) -> Int? { r < 0 ? nil : r }
        guard applied else {
            // Left alone: the template as it stays (a new exercise stays out: its empty slots).
            if let before = row.before { return before.map { Pill(reps: $0, style: .dim) } }
            if case .added(let sets) = row.change.kind { return Array(repeating: Pill(reps: nil, style: .removed), count: max(1, sets)) }
            return []
        }
        switch (row.before, after) {
        case (nil, nil):
            return []
        case (let b?, nil):
            return b.map { Pill(reps: $0, style: .removed) }
        case (nil, let a?):
            return a.map { Pill(reps: value($0), style: .added) }
        case (let b?, let a?):
            var result: [Pill] = []
            for i in 0..<max(a.count, b.count) {
                if i < a.count {
                    let style: TemplatesRepPill.Style = i >= b.count ? .added : (a[i] != b[i] ? .changed : .plain)
                    result.append(Pill(reps: value(a[i]), style: style))
                } else {
                    result.append(Pill(reps: b[i], style: .removed))
                }
            }
            return result
        }
    }

    // MARK: Choices

    /// The four resolutions as equal tiles (2 × 2; rows at AX sizes), each with how many of the
    /// workout's changes it writes, then the chosen one's consequence. The diff below redraws
    /// for the chosen resolution.
    private func choices(_ rows: [Row]) -> some View {
        let all = DriftResolution.allCases
        return VStack(alignment: .leading, spacing: 10) {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) { ForEach(all) { choiceTile($0, rows: rows) } }
            } else {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow { choiceTile(all[0], rows: rows); choiceTile(all[1], rows: rows) }
                    GridRow { choiceTile(all[2], rows: rows); choiceTile(all[3], rows: rows) }
                }
            }
            // Every consequence stacked, only the chosen one visible: the height never jumps.
            ZStack(alignment: .topLeading) {
                ForEach(all) { r in
                    Text(r.consequence)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(r == choice ? 1 : 0)
                        .accessibilityHidden(r != choice)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func choiceTile(_ resolution: DriftResolution, rows: [Row]) -> some View {
        let selected = resolution == choice
        let count = rows.filter { applies($0, resolution) }.count
        let shape = RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous)
        let ax = typeSize.isAccessibilitySize
        return Button {
            if reduceMotion { choice = resolution } else { withAnimation(.snappy(duration: 0.25)) { choice = resolution } }
        } label: {
            Group {
                if ax {
                    // AX sizes: one line per option (mark · title · count), about 56 pt tall.
                    HStack(alignment: .center, spacing: 10) {
                        mark(selected)
                        tileTitle(resolution)
                        Spacer(minLength: 6)
                        Text("\(count)")
                            .font(look.font.smallNumber)
                            .monospacedDigit()
                            .foregroundStyle(count > 0 ? look.textPrimary : look.textTertiary)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 6) {
                            tileTitle(resolution)
                            Spacer(minLength: 0)
                            mark(selected)
                        }
                        Spacer(minLength: 0)
                        // The number of the workout's changes this option writes, scoreboard-style.
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(count)")
                                .font(look.font.smallNumber)
                                .monospacedDigit()
                                .foregroundStyle(count > 0 ? look.textPrimary : look.textTertiary)
                            Text(count == 1 ? "change" : "changes")
                                .font(.system(.caption, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                        }
                    }
                    .padding(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { if selected { shape.fill(selectedFill) } }
            .lookSurface(.tile)
            .overlay { if selected { shape.strokeBorder(selectionMark, lineWidth: look.id.isPaperClub ? 2.5 : 1.5) } }
            .contentShape(shape)
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resolution.title)
        .accessibilityValue(Format.count(count, "change"))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func tileTitle(_ resolution: DriftResolution) -> some View {
        Text(resolution.title)
            .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
            .foregroundStyle(look.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func mark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(selected ? selectionMark : look.textTertiary)
            .contentTransition(.symbolEffect(.replace))
    }

    /// Selection is a state, not the action: A floodlight, B pearl, C cobalt (C's selection colour).
    private var selectionMark: Color { look.id.isPaperClub ? look.actionText : look.textPrimary }
    private var selectedFill: Color {
        switch look.id {
        case .floodlight: look.surfaceRaised
        case .anatomy: look.selectionFill
        case .paper, .carbon: look.pressedFill
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button { commit() } label: {
                HStack(spacing: 8) {
                    if committed { Image(systemName: "checkmark").font(.body.weight(.bold)).transition(.scale.combined(with: .opacity)) }
                    Text(choice.title).contentTransition(.opacity)
                }
            }
            .buttonStyle(.lookPrimary)
            .celebrate(committed)
            .disabled(committed)
            if mode == .replacement {
                Button("Keep Current Workout") { close { store.keepCurrentWorkout() } }
                    .buttonStyle(.lookSecondary)
                    .disabled(committed)
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background { TemplatesBarFade() }
    }

    private func commit() {
        let resolution = choice, dontAskAgain = dontAsk
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) { committed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            switch mode {
            case .finish: close { store.resolveDrift(resolution, dontAskAgain: dontAskAgain) }
            case .replacement: close { store.resolveReplacementDrift(resolution, dontAskAgain: dontAskAgain) }
            }
        }
    }

    // MARK: Rows

    private func makeRows() -> [Row] {
        let template = store.template(drift.templateID)
        let beforeByExercise = Dictionary((template?.items ?? []).map { ($0.exerciseID, $0.targetReps) }, uniquingKeysWith: { a, _ in a })
        // Exact results when the workout is saved (after a finish); rules otherwise (a live workout).
        var exact: [DriftResolution: [UUID: [Int]]]?
        if let template, let workout = store.workout(drift.workoutID) {
            var map: [DriftResolution: [UUID: [Int]]] = [:]
            for r in DriftResolution.allCases {
                map[r] = Dictionary(Derived.resolve(r, template: template, workout: workout).items.map { ($0.exerciseID, $0.targetReps) },
                                    uniquingKeysWith: { a, _ in a })
            }
            exact = map
        }
        return drift.changes.map { change in
            let before = beforeByExercise[change.exerciseID]
            var after: [DriftResolution: TemplatesTargets] = [:]
            for r in DriftResolution.allCases {
                if let exact {
                    after[r] = TemplatesTargets(reps: exact[r]?[change.exerciseID])
                } else {
                    after[r] = TemplatesTargets(reps: Self.approximate(r, change: change, before: before))
                }
            }
            return Row(change: change, before: before, after: after)
        }
    }

    /// The same rules as `Derived.resolve`, from the change alone (reps not yet known = -1).
    private static func approximate(_ r: DriftResolution, change: DriftChange, before: [Int]?) -> [Int]? {
        let structural = r == .updateTemplate || r == .updateBoth
        switch change.kind {
        case .added(let sets):
            return structural ? Array(repeating: -1, count: max(1, sets)) : nil
        case .removed:
            return structural ? nil : before
        case .setCount(_, let to):
            guard let before else { return nil }
            guard structural else { return before }
            return Array(before.prefix(to)) + Array(repeating: -1, count: max(0, to - before.count))
        case .reps(_, let to):
            return (r == .updateValuesOnly || r == .updateBoth) ? to : before
        }
    }
}

/// A template row's targets after a resolution (nil = the exercise is not in the template).
struct TemplatesTargets: Hashable {
    var reps: [Int]?
}

/// The pinned action bar's ground: opaque, with a short fade above so content slides under it.
struct TemplatesBarFade: View {
    @Environment(\.look) private var look
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [look.groundSheet.opacity(0), look.groundSheet], startPoint: .top, endPoint: .bottom)
                .frame(height: 32)
                .offset(y: -32)
                .padding(.bottom, -32)
            look.groundSheet
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}
