import SwiftData
import SwiftUI

/// One set in the live workout (Floodlight redesign, the Paper-structure live look): the round
/// set marker (a menu of set types), last time's value with a New best / First time mark, the
/// weight and reps fields in pencil→ink boxes (dashed while a draft, inked once logged), and the
/// round check that stamps the set done.
///
/// The behaviour is the pre-redesign row's, unchanged: keystrokes live here and reach the store
/// only on commit (end-editing or completion — SPEC's durability boundary); the check is live
/// only once the row says something true (A1); prefill comes only from the same history the
/// PREVIOUS column shows (D1/D11); swipe left (or the row's menu) deletes; bar mode takes the
/// plates on ONE end (D39/D40).
struct LiveSetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var set: SetRecord
    /// The working-set number the marker shows (ignored for W / F / D).
    var index: Int
    /// The entry's load type — decides which fields this row must carry before it may be logged (A1).
    var loadType: LoadType
    /// The next set to do in the whole workout.
    var isNextUp: Bool
    /// A rest is running (the next set's check waits, the rest slab leads).
    var isResting: Bool
    var badge: SetBadge?
    /// Called after either completion direction so the rest timer can start, replace, or cancel.
    var onCompletionChanged: (Bool) -> Void
    var onDelete: () -> Void

    @State private var weightText: String
    @State private var repsText: String
    @State private var previous: PreviousSetValue?
    @State private var isDirty = false
    /// Swipe-to-delete: how far the row is pulled left (≤ 0) and whether it has settled open.
    /// Only an open row's button is tappable, so a half-swipe can never delete anything.
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeOpen = false
    /// Increments on completion: drives the stamp, the ripple and the unboxing.
    @State private var stamp = 0
    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .body) private var gridScale: CGFloat = 1

    private static let swipeDeleteWidth: CGFloat = 88
    private enum Field { case weight, reps }

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }
    private var metrics: SetGridMetrics { .make(look, scale: gridScale) }

    init(set: SetRecord, index: Int, loadType: LoadType, isNextUp: Bool, isResting: Bool, badge: SetBadge?,
         onCompletionChanged: @escaping (Bool) -> Void, onDelete: @escaping () -> Void) {
        self.set = set
        self.index = index
        self.loadType = loadType
        self.isNextUp = isNextUp
        self.isResting = isResting
        self.badge = badge
        self.onCompletionChanged = onCompletionChanged
        self.onDelete = onDelete
        _weightText = State(initialValue: Self.weightFieldText(for: set))
        _repsText = State(initialValue: set.reps.map(String.init) ?? "")
    }

    private var isCompleted: Bool { !self.set.isDeleted && self.set.completedAt != nil }
    private var barWeight: Double? { self.set.isDeleted ? nil : self.set.barWeightValue }
    private var unit: WeightUnit { self.set.isDeleted ? .kg : self.set.weightUnit }

    /// The two facts that define what the weight field means. Watching only the numeric bar value
    /// misses 15 lb → 15 kg, even though that unit change must invalidate the old plate input.
    private struct BarInputContext: Equatable {
        var weight: Double?
        var unit: WeightUnit
    }

    private var barInputContext: BarInputContext {
        BarInputContext(weight: set.isDeleted ? nil : set.barWeightValue, unit: unit)
    }

    /// What the weight field shows: the plates on one end in bar mode, the total otherwise.
    /// Through `WeightMath.displayNumber` (2 decimals): halving an odd total puts a second decimal
    /// there (47.5 → 23.75 a side), and the field's text becomes the stored value on the check.
    private static func weightFieldText(for set: SetRecord) -> String {
        guard let bar = set.barWeightValue else {
            return set.weightValue.map { WeightMath.displayNumber($0) } ?? ""
        }
        guard let total = set.weightValue,
              let perSide = BarbellMath.platesPerSide(total: total, barWeight: bar)
        else { return "" }
        return WeightMath.displayNumber(perSide)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if swipeOffset < 0 { swipeDeleteButton }
            rowContent
                // Opaque while swiped, so the delete tile stays hidden until the swipe pulls it out.
                .background(swipeOffset < 0 ? look.surface : Color.clear)
                .offset(x: swipeOffset)
                .gesture(swipeToDelete)
        }
        .onChange(of: focusedField) { previous, _ in
            // Field commit on end-editing (SPEC durability boundary).
            switch previous {
            case .weight: commitWeight()
            case .reps: commitReps()
            case nil: break
            }
        }
        .onChange(of: weightText) { _, _ in if focusedField == .weight { isDirty = true } }
        .onChange(of: repsText) { _, _ in if focusedField == .reps { isDirty = true } }
        // Picking or clearing a bar changes what the field MEANS, so the text is re-read.
        .onChange(of: barInputContext) { _, _ in
            guard !set.isDeleted else { return }
            weightText = Self.weightFieldText(for: set)
        }
        // Preset/equipment changes select a different history context. The session clears
        // untouched inherited values in the model; mirror that before stale values can be logged.
        .onChange(of: prefillTaskID) { _, _ in
            guard !set.isDeleted, !isDirty else { return }
            weightText = Self.weightFieldText(for: set)
            repsText = set.reps.map(String.init) ?? ""
        }
        .task(id: prefillTaskID) { loadPreviousAndPrefill() }
        .onChange(of: isCompleted) { _, done in if done { stamp += 1 } }
        .sensoryFeedback(.setComplete, trigger: isCompleted) { _, completed in completed }
        .sensoryFeedback(.success, trigger: badge) { old, new in old == nil && new == .newBest }
        // B3: decimalPad/numberPad have no return key. Only the focused row contributes a bar.
        .toolbar {
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .accessibilityIdentifier("keyboardDone")
                }
            }
        }
        .contextMenu {
            Button("Delete Set", systemImage: "trash", role: .destructive) { onDelete() }
        }
    }

    // MARK: Layout

    @ViewBuilder private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize { twoLine } else { oneLine }
    }

    private var oneLine: some View {
        let m = metrics
        return HStack(spacing: m.spacing) {
            marker(side: m.markerSide).frame(width: m.marker)
            previousColumn.frame(maxWidth: .infinity, alignment: .leading)
            weightInput.frame(width: m.weight)
            repsInput.frame(width: m.reps)
            checkButton
        }
        .frame(minHeight: 48)
        .padding(.vertical, 2)
    }

    /// AX sizes: marker, previous and the check on one line; the two fields under it.
    private var twoLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                marker(side: nil)
                previousColumn
                Spacer(minLength: 4)
                checkButton
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    columnLabel(weightTitle)
                    weightInput
                }
                VStack(alignment: .leading, spacing: 2) {
                    columnLabel("REPS")
                    repsInput
                }
                .frame(maxWidth: 120)
            }
        }
        .padding(.vertical, 6)
    }

    private var weightTitle: String {
        if barWeight != nil { return "PER SIDE" }
        return loadType == .assisted ? "ASSIST" : "WEIGHT"
    }

    private func columnLabel(_ text: String) -> some View {
        Text(text).font(look.font.columnHeader).tracking(look.columnTracking).foregroundStyle(look.textSecondary)
    }

    // MARK: Marker → set type

    /// E5: the marker is a menu of named set types (W / # / F / D keep their footprint).
    private func marker(side: CGFloat?) -> some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button { apply(type) } label: {
                    if !set.isDeleted, set.type == type {
                        Label(type.displayName, systemImage: "checkmark")
                    } else {
                        Text(type.displayName)
                    }
                }
            }
        } label: {
            SetMarker(kind: set.isDeleted ? .working : set.type, number: index, done: isCompleted,
                      isNextUp: isNextUp, side: side)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("setRow.setType")
        .accessibilityLabel("Set type: \(set.isDeleted ? "" : set.type.displayName.lowercased())")
    }

    // MARK: Previous

    private var previousColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(previousText)
                .font(.system(.subheadline))
                .monospacedDigit()
                .foregroundStyle(look.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                // Spoken in full, unit included ("60 lb × 10"): the short form leans on the row.
                .accessibilityLabel(previous?.displayLabel ?? "No previous set")
                .accessibilityIdentifier("setRow.previous")
            if let badge {
                NewBestBadge(kind: badge)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.5).combined(with: .opacity))
                    .accessibilityIdentifier("setRow.badge")
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6), value: badge)
    }

    /// Last time's set: "105 × 8" when it matches this row's unit, "105 lb × 8" when not; the
    /// full label otherwise (bar breakdowns, reps only), "—" with no history.
    private var previousText: String {
        guard let previous else { return "—" }
        if previous.weightUnit == unit, previous.barWeight == nil, let weight = previous.weightValue, loadType.takesWeight {
            return "\(WeightMath.displayNumber(weight)) × \(previous.reps)"
        }
        return previous.displayLabel
    }

    // MARK: Fields

    /// Pencil → ink: a completed set's values stand inked (the box dissolves); a value the user
    /// typed sits in a soft-ruled box; a draft (empty, or carried forward untouched) is dashed.
    private func fieldStyle(hasValue: Bool) -> SetFieldBackground.Style {
        if isCompleted { return .done }
        if isDirty { return .typed }
        return hasValue ? .draft : .empty
    }

    private var weightInput: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // Sized to its number so the unit sits beside it ("110 lb"); the whole box focuses it.
                TextField("–", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .font(look.font.fieldNumber)
                    .foregroundStyle(look.textPrimary)
                    .tint(look.actionText)
                    .disabled(isCompleted)
                    .accessibilityIdentifier("setRow.weight")
                Button { toggleUnit() } label: {
                    Text(unit.label)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(look.unit(unit))
                        .padding(.vertical, 12)
                        .padding(.trailing, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // The unit follows the selected bar; input remains plates per side.
                .disabled(barWeight != nil || isCompleted)
                .accessibilityIdentifier("setRow.unit")
                .accessibilityLabel(unit.label)
                .accessibilityHint(barWeight == nil ? "Switches the unit" : "The unit follows the bar. Change the bar to log in the other unit.")
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background { SetFieldBackground(style: fieldStyle(hasValue: !weightText.isEmpty), stamp: stamp).padding(.vertical, 2) }
            .contentShape(Rectangle())
            .onTapGesture { if !isCompleted { focusedField = .weight } }
            if let totalCaption {
                Text(totalCaption)
                    .font(.system(.caption2, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(look.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("setRow.total")
            }
        }
    }

    private var repsInput: some View {
        TextField("–", text: $repsText)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: .reps)
            .multilineTextAlignment(.center)
            .font(look.font.fieldNumber)
            .foregroundStyle(look.textPrimary)
            .tint(look.actionText)
            .disabled(isCompleted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background { SetFieldBackground(style: fieldStyle(hasValue: !repsText.isEmpty), stamp: stamp).padding(.vertical, 2) }
            .accessibilityIdentifier("setRow.reps")
    }

    /// Bar mode: the running total before logging ("= 135 lb"), or the bar alone.
    private var totalCaption: String? {
        guard let barWeight else { return nil }
        guard let perSide = WorkoutSession.weightValue(from: weightText) else {
            return "\(WeightMath.displayNumber(barWeight)) \(unit.rawValue) bar"
        }
        return BarbellMath.totalLabel(barWeight: barWeight, platesPerSide: perSide, unit: unit)
    }

    // MARK: Check

    /// A1: live only once the row says something true — judged on what is on screen, since the
    /// fields commit on end-editing and the tap itself is the commit. A completed row stays
    /// tappable so it can always be un-completed.
    private var canComplete: Bool {
        isCompleted || WorkoutSession.isLoggable(weightText: weightText, repsText: repsText, loadType: loadType)
    }

    private var checkButton: some View {
        Button { toggleCompletion() } label: {
            SetCheck(done: isCompleted, warmup: !set.isDeleted && set.type == .warmup,
                     isNextUp: isNextUp && canComplete, isResting: isResting, stamp: stamp)
                .opacity(canComplete ? 1 : 0.45)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canComplete)
        .accessibilityIdentifier("setRow.complete")
        .accessibilityLabel("Complete set")
        .accessibilityValue(isCompleted ? "Completed" : "Not completed")
        .accessibilityHint(canComplete ? "" : incompleteHint)
    }

    private var incompleteHint: String {
        loadType == .bodyweight
            ? "Enter reps to log this set"
            : "Enter \(loadType == .assisted ? "assistance" : "weight") and reps to log this set"
    }

    // MARK: Swipe to delete

    private var swipeToDelete: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                // Vertical drags belong to the scroll view.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                swipeOffset = settledOffset(after: value.translation.width)
            }
            .onEnded { value in
                setSwipeOpen(settledOffset(after: value.translation.width) < -Self.swipeDeleteWidth / 2)
            }
    }

    private func settledOffset(after translation: CGFloat) -> CGFloat {
        let base: CGFloat = isSwipeOpen ? -Self.swipeDeleteWidth : 0
        return min(0, max(-Self.swipeDeleteWidth, base + translation))
    }

    private func setSwipeOpen(_ open: Bool) {
        isSwipeOpen = open
        withAnimation(reduceMotion ? nil : .snappy) { swipeOffset = open ? -Self.swipeDeleteWidth : 0 }
    }

    /// The delete tile: the destructive double rule with a solid trash disc.
    private var swipeDeleteButton: some View {
        Button(role: .destructive) {
            setSwipeOpen(false)
            onDelete()
        } label: {
            let shape = RoundedRectangle(cornerRadius: look.radius.row, style: .continuous)
            Image(systemName: "trash").font(.system(.footnote, weight: .bold))
                .foregroundStyle(look.surface)
                .frame(width: 30, height: 30)
                .background(look.destructive, in: Circle())
                .frame(width: Self.swipeDeleteWidth - 10, height: 44)
                .background(look.surface, in: shape)
                .overlay { shape.strokeBorder(look.destructive, lineWidth: 2) }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isSwipeOpen)
        .accessibilityIdentifier("setRow.swipeDelete")
        .accessibilityLabel("Delete set")
    }

    // MARK: Commits

    /// One commit path for the weight field, whatever it currently means: `commitPerSide`
    /// computes the total from the row's bar, and falls through to the total without one.
    private func commitWeight() {
        guard !set.isDeleted else { return }
        do { try session.commitPerSide(weightText, for: set) }
        catch { assertionFailure("Failed to commit weight: \(error)") }
    }

    private func commitReps() {
        guard !set.isDeleted else { return }
        do { try session.commitReps(repsText, for: set) }
        catch { assertionFailure("Failed to commit reps: \(error)") }
    }

    private func toggleUnit() {
        guard !set.isDeleted else { return }
        isDirty = true
        do {
            // Commit any in-progress weight text first so the toggle applies to what is on screen.
            try session.commitPerSide(weightText, for: set)
            try session.toggleUnit(of: set)
        } catch {
            assertionFailure("Failed to toggle unit: \(error)")
        }
    }

    private func apply(_ type: SetType) {
        guard !set.isDeleted else { return }
        do { try session.setType(type, of: set) }
        catch { assertionFailure("Failed to set the set type: \(error)") }
    }

    private func toggleCompletion() {
        guard !set.isDeleted, canComplete else { return }
        do {
            // Completion is a commit boundary: on-screen values first.
            try session.commitPerSide(weightText, for: set)
            try session.commitReps(repsText, for: set)
            try session.toggleCompletion(of: set)
        } catch WorkoutSessionError.setNotLoggable {
            // A1: the button is disabled until the row is loggable, so this is unreachable.
        } catch {
            assertionFailure("Failed to toggle completion: \(error)")
        }
        let completed = set.completedAt != nil
        if completed { focusedField = nil }
        onCompletionChanged(completed)
    }

    /// Snapshot-keyed ticket-11 query. PREVIOUS always shows the selected historical row;
    /// values are applied only while this draft remains untouched, so a delayed refresh can
    /// never clobber typing.
    private func loadPreviousAndPrefill() {
        guard !set.isDeleted else { return }
        do {
            let history = PerformanceHistory(context: modelContext)
            guard let candidate = try history.prefill(for: set) else {
                previous = nil
                return
            }
            previous = candidate
            guard try history.applyPrefill(candidate, to: set, isDirty: isDirty) else { return }
            // Read the field back off the row: the prefill carries the bar too, so in bar mode
            // the field must show the plates it implies, not last session's total.
            weightText = Self.weightFieldText(for: set)
            repsText = String(candidate.reps)
        } catch {
            assertionFailure("Failed to load previous performance: \(error)")
        }
    }

    /// Changing equipment, preset, set type, or type-relative order selects a new candidate.
    private var prefillTaskID: String {
        let entry = set.entry
        return [
            set.id.uuidString,
            String(set.order),
            set.type.rawValue,
            entry?.machine?.id.uuidString ?? "no-machine",
            entry?.freeWeightTag?.rawValue ?? "no-tag",
            entry?.preset?.id.uuidString ?? "no-preset",
        ].joined(separator: "|")
    }
}
