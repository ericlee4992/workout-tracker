import SwiftData
import SwiftUI

// Milestone 8, ticket 03 — correcting one logged record. Floodlight redesign ticket 05: big
// number boxes with − / + for one-handed nudges, the set type as pills, and Delete Set visible
// (confirmed). The same sheet reads "Add Set" for a set just added from History.
//
// Only the numbers are editable. There is deliberately no path here to the
// entry's snapshot fields (exercise name, machine, gym, load type): D23 froze
// those so the past cannot be restated by today's catalog, and an edit screen
// that quietly re-resolved them would be that drift with a friendlier face.

struct EditLoggedSetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Named `record`, not `set`: inside a computed property body the parser
    /// reads a bare `set` as the start of a setter definition.
    let record: SetRecord
    /// A set just created by Add Set / Add Exercise: titled "Add Set", no Delete (Cancel removes
    /// it — the presenter's job, on dismiss).
    var isNew = false
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var unit: WeightUnit = .kg
    @State private var setType: SetType = .working
    @State private var loaded = false
    @State private var confirmingDelete = false
    @State private var bumps = 0

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(cancel: { dismiss() }, title: isNew ? "Add Set" : "Edit Set",
                        commit: save, commitEnabled: isValid, commitIdentifier: "saveEditedSet")
            if !record.isDeleted {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        context
                        typePicker
                        VStack(alignment: .leading, spacing: 18) {
                            figures
                            if loadType.takesWeight { unitRow }
                        }
                        Text("The workout will be marked as edited.")
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                        if !isNew {
                            DestructiveRowButton("Delete Set") { confirmingDelete = true }
                                .accessibilityIdentifier("deleteEditedSet")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            } else {
                Spacer()
            }
        }
        .lookSheetGround()
        .presentationDetents([.large])
        .presentationBackground(look.groundSheet)
        .sensoryFeedback(.selection, trigger: bumps)
        .onAppear(perform: load)
        .confirmationDialog("Delete this set?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Set", role: .destructive, action: deleteSet)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(HistoryDeleteCopy.set(record))
        }
    }

    private var loadType: LoadType {
        record.isDeleted ? .weighted : WorkoutSession.loadType(of: record)
    }

    // MARK: Sections

    private var context: some View {
        let entry = record.isDeleted ? nil : record.entry
        let sets = entry.map { WorkoutSession.orderedSets(of: $0).filter { $0.completedAt != nil } } ?? []
        let number = sets.prefix { $0.id != record.id }.filter { $0.type != .warmup }.count + 1
        let date = entry?.workout?.startedAt ?? record.completedAt ?? .now
        return VStack(alignment: .leading, spacing: 6) {
            Text(entry?.snapshotExerciseName ?? "Set")
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let entry {
                Text(entry.snapshotEquipmentLabel)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                SetMarker(kind: setType, number: number, done: true)
                Text(HistoryFormat.dayTitle(date))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(setType == .working ? "Set \(number)" : setType.displayName), \(HistoryFormat.dayTitle(date))")
            .padding(.top, 6)
        }
    }

    @ViewBuilder private var typePicker: some View {
        let options = SetType.allCases
        if typeSize.isAccessibilitySize {
            Picker("Set type", selection: $setType) {
                ForEach(options, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(look.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .lookSurface(.tile)
        } else {
            SegmentedPills(options.map(\.displayName), selection: Binding(
                get: { options.firstIndex(of: setType) ?? 0 },
                set: { setType = options[$0]; bumps += 1 }))
        }
    }

    /// Weight × Reps as two equal boxes on one line (the "×" on their centre line); stacked at
    /// accessibility sizes; reps alone for plain bodyweight.
    @ViewBuilder private var figures: some View {
        let weightTitle = loadType == .assisted ? "Assistance" : "Weight"
        let step = unit == .lb ? 5.0 : 2.5
        let weight = HistoryNumberDial(title: weightTitle, text: $weightText, suffix: unit.rawValue, step: step,
                                       decimal: true, identifier: "editSetWeight") { bumps += 1 }
        let reps = HistoryNumberDial(title: "Reps", text: $repsText, suffix: nil, step: 1, decimal: false,
                                     identifier: "editSetReps") { bumps += 1 }
        if !loadType.takesWeight {
            reps
        } else if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 18) { weight; reps }
        } else {
            HStack(alignment: .historyBoxCentre, spacing: 8) {
                weight.frame(maxWidth: .infinity)
                Text("×")
                    .font(look.font.title2)
                    .foregroundStyle(look.textSecondary)
                    .alignmentGuide(.historyBoxCentre) { $0[VerticalAlignment.center] }
                    .accessibilityHidden(true)
                reps.frame(maxWidth: .infinity)
            }
        }
    }

    /// The unit is a relabel, as in the live table: the number stays as typed. The bar
    /// breakdown shows while the total still carries the bar (D39).
    private var unitRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Unit").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                SegmentedPills(WeightUnit.allCases.map(\.rawValue), selection: Binding(
                    get: { WeightUnit.allCases.firstIndex(of: unit) ?? 0 },
                    set: { unit = WeightUnit.allCases[$0]; bumps += 1 }))
                    .frame(maxWidth: 170)
            }
            if let bar = barCaption {
                Label(bar, systemImage: "equal.circle")
                    .font(look.font.footnote)
                    .monospacedDigit()
                    .foregroundStyle(look.textSecondary)
            }
        }
    }

    private var barCaption: String? {
        guard !record.isDeleted, let bar = record.barWeightValue, unit == record.weightUnit,
              let total = parsedWeight, total >= bar else { return nil }
        return BarbellMath.breakdownLabel(barWeight: bar, total: total, unit: unit)
    }

    // MARK: Values

    private var parsedReps: Int? { Int(repsText.trimmingCharacters(in: .whitespaces)) }

    private var parsedWeight: Double? {
        let text = weightText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : Double(text.replacingOccurrences(of: ",", with: "."))
    }

    /// Mirrors the store's own rule, so Save can never enable on input the
    /// store will then refuse (the same guard the active workout uses).
    private var isValid: Bool {
        WorkoutSession.isLoggable(
            reps: parsedReps, weightValue: loadType.takesWeight ? parsedWeight : nil, loadType: loadType)
    }

    private func load() {
        guard !loaded, !record.isDeleted else { return }
        repsText = record.reps.map(String.init) ?? ""
        weightText = record.weightValue.map { Format.weight($0) } ?? ""
        unit = record.weightUnit
        setType = record.type
        loaded = true
    }

    private func save() {
        let edit = HistoryEditing.SetEdit(
            reps: parsedReps, weightValue: loadType.takesWeight ? parsedWeight : nil,
            weightUnit: unit, setType: setType)
        guard HistoryEditing.apply(edit, to: record) else { return }
        do { try modelContext.save() }
        catch { assertionFailure("Failed to save edited set: \(error)") }
        dismiss()
    }

    private func deleteSet() {
        guard !record.isDeleted else { return }
        let entry = HistoryEditing.deleteSet(record, in: modelContext)
        if let entry { HistoryEditing.pruneIfEmpty(entry, in: modelContext) }
        do { try modelContext.save() }
        catch { assertionFailure("Failed to delete set: \(error)") }
        dismiss()
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

/// Label, a big editable number in the look's field with a small unit, and − / + under it
/// (5 lb / 2.5 kg, or 1 rep). The field hugs its digits, so number and unit sit centred together.
struct HistoryNumberDial: View {
    var title: String
    @Binding var text: String
    var suffix: String?
    var step: Double
    var decimal: Bool
    var identifier: String
    var onStep: () -> Void = {}
    @FocusState private var focused: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .largeTitle) private var boxHeight: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .padding(.leading, 4)
                .accessibilityHidden(true)
            box.alignmentGuide(.historyBoxCentre) { $0[VerticalAlignment.center] }
            HStack(spacing: 8) {
                stepButton("minus", delta: -step)
                stepButton("plus", delta: step)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var box: some View {
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
                        .accessibilityIdentifier(identifier)
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
        .lookSurface(.field)
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                    .strokeBorder(look.actionText, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func stepButton(_ symbol: String, delta: Double) -> some View {
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
