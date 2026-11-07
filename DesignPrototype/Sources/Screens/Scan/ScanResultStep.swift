import SwiftUI

// S04–S06 — the answer, beside the photo it came from. The outcome is the hero, not a footer:
// a stamped disc with the state named beside it in the look's title face, then the identity.
//   S04 specific   → a lit (A/B) or inked (C) check, "Matches catalog", the model name, a nearly
//                    full confidence meter, and the name plate the AI read lifted out of the
//                    photo (the loupe).
//   S05 ambiguous  → an open ring with the count, "3 matches" with its one consequence line;
//                    the photo steps back so the candidate list (each with its own meter) is the
//                    decision. Picking one keeps the ring and lands a small check on it
//                    ("picked", never the confident check); the hero then names the pick once.
//                    "None of these" is a choice in the same list.
//   S06 generic    → a hollow "?" ring, the machine's name in bold and the real consequence line.
//   (new model     → the dashed "make one" edge with "+".)
// Choosing generic never throws the AI's answer away: it is a selection kept in this view until
// Add, reversible with one tap ("Use catalog match" / "Use new model" / pick a candidate), so a
// mis-tap never costs another identification. Name and exercises are editable; "Add to <gym>" is
// the one filled command. At accessibility sizes only it stays pinned; "Take another photo"
// ends the scroll content. The sheet's last step (confirmed) stamps the new machine.

struct ScanResultStep: View {
    var gymName: String
    var photoSpace: Namespace.ID
    var onCancel: () -> Void
    var onChangeExercises: () -> Void
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScanReduceMotion private var reduceMotion
    @State private var arrivals = 0
    @State private var picks = 0
    /// The user chose "no model" (Use generic identity / None of these). The AI's answer stays
    /// in the store until Add, so the choice can be undone.
    @State private var genericChosen = false
    @State private var appliedVariant = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        if let result = store.scan.result {
            content(result)
        }
    }

    private func content(_ r: ScanResult) -> some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanPagedScroll(page: router.scanCapturePage) {
                VStack(alignment: .leading, spacing: 22) {
                    ScanInlineTitle(title: "Scan Machine")
                    hero(r)
                    if r.kind == .ambiguous { candidates(r) }
                    nameField(r)
                    exercises(r)
                    if typeSize.isAccessibilitySize { retakeButton }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 24)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Add to \(gymName)", symbol: "plus", enabled: canAdd(r)) { add() }
                    if !typeSize.isAccessibilitySize && !nameFocused { retakeButton }
                }
            }
        }
        .onAppear {
            arrivals += 1
            applyVariant()
        }
        .sensoryFeedback(arrivalFeedback(r), trigger: arrivals)
        .sensoryFeedback(.selection, trigger: picks)
    }

    private var retakeButton: some View {
        Button("Take another photo") {
            withAnimation(stepSpring) { store.scanRetake() }
        }
        .buttonStyle(.lookSecondary)
    }

    private func applyVariant() {
        guard !appliedVariant else { return }
        appliedVariant = true
        if router.scanVariant("generic") || router.scanVariant("none") { genericChosen = true }
        if router.scanVariant("editing") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { nameFocused = true }
        }
    }

    private var stepSpring: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.82)
    }

    private func canAdd(_ r: ScanResult) -> Bool {
        !r.label.trimmingCharacters(in: .whitespaces).isEmpty && !r.exerciseIDs.isEmpty
    }

    private func add() {
        nameFocused = false
        withAnimation(stepSpring) {
            if genericChosen { store.scanUseGeneric() }
            _ = store.scanConfirm()
        }
    }

    private func arrivalFeedback(_ r: ScanResult) -> SensoryFeedback {
        r.kind == .specific || r.kind == .newModel ? .success : .impact(weight: .light)
    }

    /// Catalog models supply their own exercises (D24), so the list is editable only when no
    /// catalog model is claimed.
    private func exercisesEditable(_ r: ScanResult) -> Bool {
        if genericChosen { return true }
        switch r.kind {
        case .specific: return false
        case .ambiguous: return r.selectedCandidate?.catalogModelID == nil
        case .newModel, .generic: return true
        }
    }

    /// Back from "no model" to the AI's answer (its exercises come back with it).
    private func restoreAnswer(_ r: ScanResult) {
        picks += 1
        withAnimation(stepSpring) {
            genericChosen = false
            if r.kind != .ambiguous, let id = r.candidates.first?.id { store.scanSelectCandidate(id) }
        }
    }

    private func chooseGeneric() {
        picks += 1
        withAnimation(stepSpring) {
            genericChosen = true
            if store.scan.result?.kind == .ambiguous { store.scanSelectCandidate(nil) }
        }
    }

    // MARK: Hero

    private func outcome(_ r: ScanResult) -> ScanOutcome {
        if genericChosen { return .generic }
        switch r.kind {
        case .specific: return .matched
        case .ambiguous: return r.selectedCandidate == nil ? .choose(r.candidates.count) : .picked(r.candidates.count)
        case .newModel: return .newModel
        case .generic: return .generic
        }
    }

    private func stateLabel(_ o: ScanOutcome) -> String {
        switch o {
        case .matched: "Matches catalog"
        case .choose(let n), .picked(let n): "\(n) matches"
        case .newModel: "New model"
        case .generic, .failed: "Generic"
        }
    }

    /// The ambiguous answer leads with its candidate list, so its photo steps back.
    private func photoHeight(_ r: ScanResult) -> CGFloat {
        let choosing = r.kind == .ambiguous
        return typeSize.isAccessibilitySize ? (choosing ? 150 : 190) : (choosing ? 172 : 236)
    }
    private var discSize: CGFloat { typeSize.isAccessibilitySize ? 52 : 58 }

    /// The model this result would claim (nil when none is claimed).
    private func claimed(_ r: ScanResult) -> ScanCandidate? {
        genericChosen ? nil : r.selectedCandidate
    }

    private func hero(_ r: ScanResult) -> some View {
        let o = outcome(r)
        let sharedMaker = Set(r.candidates.map(\.manufacturer)).count == 1 ? r.candidates.first?.manufacturer : nil
        let showsLoupe = !genericChosen && r.kind != .generic
        return VStack(alignment: .leading, spacing: 0) {
            ScanPhotoTile(plateText: store.scan.demoKind.scanPlateText, plateHighlight: look.onSlab,
                          loupeText: showsLoupe ? r.visibleText : nil, cornerRadius: 0)
                .matchedGeometryEffect(id: "scanPhoto", in: photoSpace)
                .frame(height: photoHeight(r))
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                // The outcome: stamp and state, centred on each other.
                HStack(alignment: .center, spacing: 14) {
                    ScanOutcomeDisc(outcome: o, size: discSize)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stateLabel(o))
                            .font(look.font.navTitle)
                            .foregroundStyle(look.textPrimary)
                            .contentTransition(.opacity)
                        if case .choose = o {
                            Text("Saved without a model unless you pick one")
                                .font(look.font.subhead)
                                .foregroundStyle(look.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)

                identity(r, outcome: o, sharedMaker: sharedMaker)

                if let dup = duplicate(r) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "square.on.square")
                            .font(.system(.footnote, weight: .bold))
                            .accessibilityHidden(true)
                        Text("Already at \(gymName) as “\(dup.label)”")
                            .font(.system(.subheadline, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(look.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(look.id.isPaperClub ? look.pressedFill : look.surfaceRaised,
                                in: RoundedRectangle(cornerRadius: look.radius.field, style: .continuous))
                    .accessibilityElement(children: .combine)
                }

                genericToggle(r)
            }
            .padding(look.space.panelPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
        .animation(stepSpring, value: r.selectedCandidateID)
        .animation(stepSpring, value: genericChosen)
    }

    @ViewBuilder
    private func identity(_ r: ScanResult, outcome o: ScanOutcome, sharedMaker: String?) -> some View {
        switch o {
        case .generic:
            // Nothing claimed: the machine's own name is the answer, with what that means.
            VStack(alignment: .leading, spacing: 4) {
                Text(r.label.isEmpty ? "Machine" : r.label)
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Saved as this gym’s machine, with no model claimed.")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .transition(.opacity)
        case .choose:
            if let sharedMaker {
                Text(sharedMaker)
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
            }
        case .picked:
            if let pick = r.selectedCandidate {
                makerAndModel(pick)
                    .transition(.opacity)
            }
        default:
            if let model = claimed(r) {
                makerAndModel(model)
                if let category = model.category { categoryChip(category) }
                ScanConfidenceMeter(value: model.confidence)
            }
        }
    }

    private func makerAndModel(_ c: ScanCandidate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(c.manufacturer)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            Text(c.modelName)
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// S04 / new model: the chip that sets the answer aside, and the one that brings it back.
    @ViewBuilder
    private func genericToggle(_ r: ScanResult) -> some View {
        if r.kind == .specific || r.kind == .newModel {
            if genericChosen {
                Chip(r.kind == .newModel ? "Use new model" : "Use catalog match", symbol: "arrow.uturn.backward") {
                    restoreAnswer(r)
                }
                .transition(.opacity)
            } else {
                Chip("Use generic identity", symbol: "circle.dashed") { chooseGeneric() }
                    .transition(.opacity)
            }
        }
    }

    private func categoryChip(_ category: EquipmentCategory) -> some View {
        Text(category.label)
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textSecondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .overlay { Capsule().strokeBorder(look.hairline, lineWidth: look.id.isPaperClub ? 1.5 : 1) }
    }

    /// A machine at this gym already on the claimed model.
    private func duplicate(_ r: ScanResult) -> Machine? {
        guard let modelID = claimed(r)?.catalogModelID, let gymID = store.scan.gymID else { return nil }
        return ScanDuplicate.existing(store: store, gymID: gymID, modelID: modelID)
    }

    // MARK: Candidates (S05)

    private func candidates(_ r: ScanResult) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(r.candidates.enumerated()), id: \.element.id) { index, candidate in
                if index > 0 { LookDivider().padding(.leading, 56) }
                candidateRow(candidate, selected: !genericChosen && r.selectedCandidateID == candidate.id,
                             showsMaker: Set(r.candidates.map(\.manufacturer)).count > 1)
            }
            LookDivider().padding(.leading, 56)
            Button {
                if genericChosen { restoreAnswer(r) } else { chooseGeneric() }
            } label: {
                HStack(spacing: 14) {
                    ScanRadio(selected: genericChosen)
                    Text("None of these")
                        .font(.system(.body, weight: .semibold))
                        .fontDesign(look.id == .anatomy ? .rounded : nil)
                        .foregroundStyle(look.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(genericChosen ? selectedFill : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
            .accessibilityAddTraits(genericChosen ? .isSelected : [])
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
    }

    private var selectedFill: Color { look.id.isPaperClub ? look.pressedFill : look.selectionFill }

    private func candidateRow(_ c: ScanCandidate, selected: Bool, showsMaker: Bool) -> some View {
        Button {
            picks += 1
            withAnimation(stepSpring) {
                genericChosen = false
                store.scanSelectCandidate(selected ? nil : c.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ScanRadio(selected: selected)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        if showsMaker {
                            Text(c.manufacturer)
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                        }
                        Text(c.modelName)
                            .font(look.id.isPaperClub ? look.font.cardTitle : .system(.body, weight: .semibold))
                            .fontDesign(look.id == .anatomy ? .rounded : nil)
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ScanConfidenceMeter(value: c.confidence)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selected ? selectedFill : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Name

    private func nameField(_ r: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .padding(.leading, 4)
            HStack(spacing: 12) {
                LookIcon(LookIcon.machine, style: .body)
                    .foregroundStyle(look.textSecondary)
                TextField("Machine name", text: Binding(get: { store.scan.result?.label ?? "" },
                                                         set: { store.scanSetLabel($0) }))
                    .font(look.font.title3)
                    .foregroundStyle(look.textPrimary)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }
                Image(systemName: "pencil")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 54)
            .lookSurface(.field)
            .overlay {
                // Focused: the field takes the selection edge.
                RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                    .strokeBorder(look.id.isPaperClub ? look.actionText : look.selection, lineWidth: 2)
                    .opacity(nameFocused ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = true }
            .animation(.easeOut(duration: 0.15), value: nameFocused)
        }
        .id("scanName")
    }

    // MARK: Exercises

    private func exercises(_ r: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LookList {
                ForEach(r.exerciseIDs, id: \.self) { id in
                    if let exercise = store.exercise(id) {
                        LookRow(exercise.name, value: exercise.muscleGroup?.label, showsChevron: false)
                    }
                }
                if exercisesEditable(r) {
                    LookRow("Change exercises", symbol: "slider.horizontal.3", action: onChangeExercises)
                }
            }
        }
    }
}

/// A radio mark: open ring, or the look's selection filled with a check.
struct ScanRadio: View {
    var selected: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 26

    var body: some View {
        ZStack {
            if selected {
                Circle().fill(look.id.isPaperClub ? look.action : look.selection)
                Image(systemName: "checkmark")
                    .font(.system(size: side * 0.46, weight: .heavy))
                    .foregroundStyle(look.id.isPaperClub ? look.onAction : look.onDone)
            } else {
                Circle().strokeBorder(look.id.isPaperClub ? look.outline : look.textTertiary, lineWidth: 2)
            }
        }
        .frame(width: side, height: side)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selected)
        .accessibilityHidden(true)
    }
}

/// A minimal wrapping row layout for chips.
struct ScanFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let w = min(size.width, width)
            if x > 0 && x + w > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += w + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let w = min(size.width, bounds.width)
            if x > bounds.minX && x + w > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: w, height: size.height))
            x += w + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Confirmed

/// The machine was added: the check stamps in with the look's finish-stamp motion (and its
/// ring runs out once), the new machine is shown as a card with the photo it came from, and the
/// gym's machine count ticks up (16 → 17), so the scan visibly changed something. Short content
/// sits centred. Reduce Motion: all of it is simply there.
struct ScanConfirmedStep: View {
    var gymName: String
    var photoSpace: Namespace.ID
    var onDone: () -> Void
    var onScanAnother: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScanReduceMotion private var reduceMotion
    @State private var landed = 0
    @State private var countShown: Int?

    var body: some View {
        let machine = store.machine(store.scan.confirmedMachineID)
        let exerciseIDs = machine.map { store.exerciseIDs(of: $0) } ?? []
        let count = machine.map { store.gymStats($0.gymID).machineCount } ?? 0
        VStack(spacing: 0) {
            ScanPagedScroll(page: nil, centered: true) {
                VStack(spacing: 18) {
                    ScanOutcomeDisc(outcome: .matched, size: typeSize.isAccessibilitySize ? 72 : 88, delay: 0.1, ripple: true)
                    Text("Added to \(gymName)")
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let machine {
                        card(machine, exerciseIDs: exerciseIDs)
                            .padding(.top, 6)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            CountUpText(Double(countShown ?? count), duration: 0.5, countsFromZero: false) { Format.grouped($0) }
                                .font(look.font.bigNumber)
                                .monospacedDigit()
                                .foregroundStyle(look.textPrimary)
                            Text(count == 1 ? "machine" : "machines")
                                .font(look.font.subhead)
                                .foregroundStyle(look.textSecondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(count) machines at \(gymName)")
                        .onAppear {
                            guard !reduceMotion, count > 0 else { return }
                            countShown = count - 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { countShown = count }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 12)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton("Done", symbol: "checkmark", action: onDone)
                    Button("Scan another machine", action: onScanAnother)
                        .buttonStyle(.lookSecondary)
                }
            }
        }
        .padding(.top, 10)
        .onAppear { landed += 1 }
        .sensoryFeedback(.success, trigger: landed)
    }

    private func card(_ machine: Machine, exerciseIDs: [UUID]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScanPhotoTile(plateText: store.scan.demoKind.scanPlateText, cornerRadius: 0)
                .matchedGeometryEffect(id: "scanPhoto", in: photoSpace)
                .frame(height: typeSize.isAccessibilitySize ? 150 : 176)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    LookIcon(LookIcon.machine, style: .headline)
                        .foregroundStyle(look.textSecondary)
                    Text(machine.label)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let model = store.modelName(of: machine) {
                    Text(model)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(exerciseIDs.compactMap { store.exercise($0)?.name }.joined(separator: ", "))
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(look.space.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
        .accessibilityElement(children: .combine)
    }
}
