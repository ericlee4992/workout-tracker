import SwiftUI

// H05 Edit Set (and Add Set for a set just added to a past workout). Only the numbers of the
// logged set change: type, weight and unit, reps. The snapshot exercise and equipment stay as
// they were (D23/D47). Big numbers with − / + for one-handed nudges; Delete Set is visible
// and confirmed. Saving marks the workout Edited.

/// Sets created from History's Add Set / Add Exercise…, so their sheet reads "Add Set" and
/// Cancel removes them again.
@MainActor
enum HistoryNewSetRegistry {
    static var ids: Set<UUID> = []
}

struct EditSetSheet: View {
    let workoutID: UUID
    let entryID: UUID
    let setID: UUID

    init(workoutID: UUID, entryID: UUID, setID: UUID) {
        self.workoutID = workoutID
        self.entryID = entryID
        self.setID = setID
    }

    var body: some View {
        HistoryEditSetContent(workoutID: workoutID, entryID: entryID, setID: setID)
            .historySheetTypeOverride()
    }
}

/// The sheet itself (a child view, so an accessibility type override set on the sheet root
/// reaches its own layout decisions).
struct HistoryEditSetContent: View {
    let workoutID: UUID
    let entryID: UUID
    let setID: UUID
    /// The set on screen (the capture's "add" variant swaps in a set it just added).
    @State private var activeSetID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var unit: WeightUnit = .lb
    @State private var type: SetType = .working
    @State private var loaded = false
    @State private var finished = false
    @State private var confirmDelete = false
    @State private var bumps = 0
    /// Measured height of the sheet's content, for a fitted detent.
    @State private var contentHeight: CGFloat = 540

    init(workoutID: UUID, entryID: UUID, setID: UUID) {
        self.workoutID = workoutID
        self.entryID = entryID
        self.setID = setID
        _activeSetID = State(initialValue: setID)
    }

    private var workout: Workout? { store.workout(workoutID) }
    private var entry: WorkoutEntry? { workout?.entries.first { $0.id == entryID } }
    private var loggedSet: LoggedSet? { entry?.sets.first { $0.id == activeSetID } }
    private var isNew: Bool { HistoryNewSetRegistry.ids.contains(activeSetID) }
    private var loadType: LoadType { entry?.loadType ?? .weighted }

    private var weightValue: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }
    private var repsValue: Int? { Int(repsText.trimmingCharacters(in: .whitespaces)) }

    /// The fields differ from the saved set.
    private func isChanged(_ set: LoggedSet) -> Bool {
        guard loaded else { return false }
        let weight = loadType.takesWeight ? weightValue : nil
        return type != set.type || unit != set.unit || repsValue != set.reps
            || (weight.map { abs($0 - (set.weight ?? -1)) > 0.001 } ?? (set.weight != nil && loadType.takesWeight))
    }

    private var canSave: Bool {
        guard let reps = repsValue, reps > 0 else { return false }
        switch loadType {
        case .bodyweight: return true
        case .weighted: return (weightValue ?? 0) > 0
        case .assisted, .bodyweightPlus: return (weightValue ?? -1) >= 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(cancel: cancel, title: isNew ? "Add Set" : "Edit Set", commit: save, commitEnabled: canSave)
            if let entry, let set = loggedSet {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        context(entry, set)
                        typePicker
                        VStack(alignment: .leading, spacing: 18) {
                            figures
                            if loadType.takesWeight { unitRow }
                        }
                        Text("The workout will be marked as edited.")
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                        if !isNew {
                            DestructiveRowButton("Delete Set") { confirmDelete = true }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            } else {
                Spacer()
            }
        }
        .lookSheetGround()
        .presentationBackground(look.groundSheet)
        // Fitted to its content (no empty lower half); large text gets the full sheet.
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(min(contentHeight + 76, 860)), .large])
        .sensoryFeedback(.selection, trigger: bumps)
        .onAppear {
            if router.variant == "add", store.currentScreen == .h05 {
                // Capture: the Add Set sheet (a set just added from the exercise's menu).
                router.variant = nil
                if let id = store.addLoggedSet(workoutID: workoutID, entryID: entryID) {
                    HistoryNewSetRegistry.ids.insert(id)
                    activeSetID = id
                }
            }
            load()
        }
        .onDisappear(perform: abandonIfNew)
        .confirmationDialog("Delete this set?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Set", role: .destructive, action: deleteSet)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(HistoryDeleteCopy.set(exerciseName: entry?.exerciseName, isOnlySet: entry?.sets.count == 1))
        }
    }

    // MARK: Sections

    private func context(_ entry: WorkoutEntry, _ set: LoggedSet) -> some View {
        let number = entry.sets.prefix { $0.id != set.id }.filter { $0.type == .working }.count + 1
        let outcome = store.bestOutcome(setID: set.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text(entry.exerciseName)
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.equipmentLabel)
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // The set line; its new-best mark moves under it at accessibility sizes.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                // The marker already says which set; the words say when.
                HStack(spacing: 10) {
                    SetMarker(kind: type, number: number, done: true)
                        .animation(.snappy, value: type)
                    Text(Format.day(workout?.startedAt ?? store.now))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(type == .working ? "Set \(number)" : type.displayName), \(Format.day(workout?.startedAt ?? store.now))")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
                // The mark belongs to the saved values: it steps aside while they are changed.
                if !isNew && !isChanged(set) {
                    switch outcome {
                    case .newBest: NewBestBadge(kind: .newBest)
                    case .firstTime: NewBestBadge(kind: .firstTime)
                    case .none: EmptyView()
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder private var typePicker: some View {
        let options = SetType.allCases
        if typeSize.isAccessibilitySize {
            Picker("Set type", selection: $type) {
                ForEach(options) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(look.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .lookSurface(.tile)
        } else {
            SegmentedPills(options.map(\.displayName), selection: Binding(
                get: { options.firstIndex(of: type) ?? 1 },
                set: { type = options[$0]; bumps += 1 }))
        }
    }

    /// Weight × Reps as two equal big boxes on one grid (labels, boxes and − / + rows share
    /// rows, so the "×" sits on the boxes' centre line); stacked at accessibility sizes.
    @ViewBuilder private var figures: some View {
        let weightTitle = loadType == .assisted ? "Assistance" : "Weight"
        let step = unit == .lb ? 5.0 : 2.5
        if !loadType.takesWeight {
            HistoryNumberDial(title: "Reps", text: $repsText, suffix: nil, step: 1, decimal: false, isDraft: isNew) { bumps += 1 }
        } else if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 18) {
                HistoryNumberDial(title: weightTitle, text: $weightText, suffix: unit.label, step: step, decimal: true, isDraft: isNew) { bumps += 1 }
                HistoryNumberDial(title: "Reps", text: $repsText, suffix: nil, step: 1, decimal: false, isDraft: isNew) { bumps += 1 }
            }
        } else {
            // Two equal columns; the "×" rides the boxes' centre line.
            HStack(alignment: .historyBoxCentre, spacing: 8) {
                HistoryNumberDial(title: weightTitle, text: $weightText, suffix: unit.label, step: step, decimal: true, isDraft: isNew) { bumps += 1 }
                    .frame(maxWidth: .infinity)
                Text("×")
                    .font(look.font.title2)
                    .foregroundStyle(look.textSecondary)
                    .alignmentGuide(.historyBoxCentre) { $0[VerticalAlignment.center] }
                    .accessibilityHidden(true)
                HistoryNumberDial(title: "Reps", text: $repsText, suffix: nil, step: 1, decimal: false, isDraft: isNew) { bumps += 1 }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Unit (a relabel, as in the live table: the number stays as typed), then the bar
    /// breakdown while the total still carries the bar.
    private var unitRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Unit").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                SegmentedPills(["kg", "lb"], selection: Binding(
                    get: { unit == .kg ? 0 : 1 },
                    set: { unit = $0 == 0 ? .kg : .lb; bumps += 1 }))
                    .frame(maxWidth: 170)
            }
            if let bar = barCaption {
                Label(bar, systemImage: "equal.circle")
                    .font(look.font.footnote)
                    .monospacedDigit()
                    .foregroundStyle(look.textSecondary)
                    .labelStyle(HistoryTightLabelStyle())
            }
        }
    }

    /// The bar breakdown while the total still carries the bar (as entered).
    private var barCaption: String? {
        guard let set = loggedSet, let bar = set.barWeight, unit == set.unit, let w = weightValue, w >= bar else { return nil }
        return Format.barBreakdown(SetValue(weight: w, unit: unit, reps: repsValue ?? 0, bar: bar))
    }

    // MARK: Actions

    private func load() {
        guard !loaded, let set = loggedSet else { return }
        loaded = true
        weightText = set.weight.map { Format.weight($0) } ?? ""
        repsText = set.reps.map(String.init) ?? ""
        unit = set.unit
        type = set.type
    }

    private func save() {
        guard canSave, var set = loggedSet else { return }
        let weight = loadType.takesWeight ? weightValue : nil
        if let bar = set.barWeight, !(unit == set.unit && (weight ?? 0) >= bar) { set.barWeight = nil }
        set.type = type
        set.weight = weight
        set.unit = unit
        set.reps = repsValue
        store.updateLoggedSet(set, workoutID: workoutID)
        finished = true
        HistoryNewSetRegistry.ids.remove(activeSetID)
        router.dismissSheet()
    }

    private func cancel() {
        abandonIfNew()
        router.dismissSheet()
    }

    /// Cancel (or swipe down) on a set just added removes it again — and its exercise, when that
    /// was the exercise's only set.
    private func abandonIfNew() {
        guard !finished else { return }
        finished = true
        guard isNew else { return }
        HistoryNewSetRegistry.ids.remove(activeSetID)
        let onlySet = entry?.sets.count == 1
        store.deleteLoggedSet(activeSetID, workoutID: workoutID)
        if onlySet { store.removeEntry(entryID, workoutID: workoutID) }
    }

    private func deleteSet() {
        let onlySet = entry?.sets.count == 1
        finished = true
        store.deleteLoggedSet(activeSetID, workoutID: workoutID)
        if onlySet { store.removeEntry(entryID, workoutID: workoutID) }
        router.dismissSheet()
    }
}

// MARK: - Number boxes

extension VerticalAlignment {
    private enum HistoryBoxCentre: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    /// The centre line of the number boxes (the "×" between Weight and Reps sits on it).
    static let historyBoxCentre = VerticalAlignment(HistoryBoxCentre.self)
}

/// The small label over a number box ("Weight", "Reps").
struct HistoryDialLabel: View {
    var title: String
    @Environment(\.look) private var look
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textSecondary)
            .padding(.leading, 4)
    }
}

/// A big editable number in the look's open box, with a small unit. The field hugs its digits
/// (a hidden copy of the text sizes it), so the number and unit sit centred together and the
/// box never widens the sheet.
struct HistoryNumberBox: View {
    var title: String
    @Binding var text: String
    var suffix: String?
    var decimal: Bool
    /// C: a new set is a draft (the open, dashed box); a logged set is inked (solid, ruled).
    var isDraft = false
    @FocusState private var focused: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var boxHeight: CGFloat = 78

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(text.isEmpty ? "0" : text)
                .font(look.font.heroNumber)
                .lineLimit(1)
                .opacity(0)
                .overlay {
                    TextField("0", text: $text)
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                        .tint(look.actionText)
                        .keyboardType(decimal ? .decimalPad : .numberPad)
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .accessibilityLabel(title)
                        .padding(.horizontal, -12)
                }
            if let suffix {
                Text(suffix)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .fixedSize()
            }
        }
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: boxHeight)
        .modifier(HistoryFieldSurface(isDraft: isDraft))
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                    .strokeBorder(look.actionText, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

/// − / + under a number box (one-handed nudges: 5 lb / 2.5 kg, or 1 rep).
struct HistoryStepPair: View {
    var title: String
    @Binding var text: String
    var step: Double
    var decimal: Bool
    var onStep: () -> Void = {}
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 8) {
            button("minus", delta: -step)
            button("plus", delta: step)
        }
    }

    private func button(_ symbol: String, delta: Double) -> some View {
        Button {
            let current = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
            let next = max(0, current + delta)
            text = decimal ? Format.weight(next) : "\(Int(next.rounded()))"
            onStep()
        } label: {
            Image(systemName: symbol)
                .font(.system(.body, weight: .bold))
                .foregroundStyle(look.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .lookSurface(.raised, radius: 22)
                .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(delta < 0 ? "Decrease \(title)" : "Increase \(title)")
    }
}

/// Label, box and − / + stacked (reps-only sets, and accessibility sizes).
struct HistoryNumberDial: View {
    var title: String
    @Binding var text: String
    var suffix: String?
    var step: Double
    var decimal: Bool
    var isDraft = false
    var onStep: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HistoryDialLabel(title)
            HistoryNumberBox(title: title, text: $text, suffix: suffix, decimal: decimal, isDraft: isDraft)
                .alignmentGuide(.historyBoxCentre) { $0[VerticalAlignment.center] }
            HistoryStepPair(title: title, text: $text, step: step, decimal: decimal, onStep: onStep)
        }
        .accessibilityElement(children: .contain)
    }
}

/// The number box's surface. A and B: the look's field. C: the dashed open box only for a
/// draft (Add Set); a logged value is inked — the sheet fill with a solid 1.5 pt rule.
struct HistoryFieldSurface: ViewModifier {
    var isDraft: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        if look.id.isPaperClub && !isDraft {
            let shape = RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
            content
                .background(look.surfaceSheet, in: shape)
                .overlay { shape.strokeBorder(look.outline, lineWidth: 1.5) }
        } else {
            content.lookSurface(.field)
        }
    }
}
