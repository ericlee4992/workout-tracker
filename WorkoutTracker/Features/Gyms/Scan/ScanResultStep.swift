import SwiftUI
import UIKit

// Floodlight redesign ticket 07 — S04–S06, the answer beside the photo it came from. The outcome
// is the hero, not a footer: a stamped disc with the state named beside it, then the identity.
//   catalog match → the lit check, "Matches catalog", maker over model, its equipment type;
//   new model     → the dashed "+", "New model", maker over model, "Custom";
//   ambiguous     → the count ring, "N matches", "Saved without a model", the matching rows
//                   named as information (D56 keeps it model-less — user decision 3);
//   generic       → the hollow "?", "Generic", the machine's name and what that means.
// "Use generic identity" sets the answer aside and "Use catalog match" / "Use new model" brings
// it back — the answer stays in the sheet until Add, so a mis-tap never costs another
// identification. The name, maker/model (a specific identity) and exercises (when no catalog
// model supplies them) are editable. The commit is the one filled command; at accessibility
// sizes only it stays pinned and "Take another photo" ends the scroll content.

struct ScanResultStep: View {
    @Binding var proposal: EquipmentIdentification
    var photo: UIImage?
    var gym: Gym?
    var isAddMode: Bool
    @Binding var genericChosen: Bool
    var resolution: EquipmentIdentityResolution
    var catalogMatches: [EquipmentModel]
    var effectiveIDs: [UUID]
    var exercises: [Exercise]
    var saveFailure: String?
    var focusedField: FocusState<IdentifyEquipmentSheet.Field?>.Binding
    var onCancel: () -> Void
    var onRetake: () -> Void
    var onCommit: () -> Void
    var onChangeExercises: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrivals = 0
    @State private var picks = 0

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(title: "Scan Machine", onCancel: onCancel)
            ScanPagedScroll {
                VStack(alignment: .leading, spacing: 22) {
                    ScanInlineTitle(title: "Scan Machine")
                    hero
                    if proposal.identity == "uncertain" {
                        Text("AI could not identify this equipment. Try a clearer angle or choose its exercises below.")
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    nameField
                    if showsMakerFields { makerFields }
                    exerciseList
                    if let saveFailure {
                        Text(saveFailure).font(look.font.subhead).foregroundStyle(look.destructive)
                    }
                    if typeSize.isAccessibilitySize { retakeButton }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 24)
            } bar: {
                ScanBottomBar {
                    ScanPrimaryButton(commitTitle, symbol: isAddMode ? "plus" : "checkmark",
                                      enabled: ScanMachine.canConfirm(label: proposal.label, exerciseIDs: effectiveIDs),
                                      action: onCommit)
                        .accessibilityIdentifier("scanUseCandidate")
                    if !typeSize.isAccessibilitySize && focusedField.wrappedValue == nil { retakeButton }
                }
            }
        }
        .onAppear { arrivals += 1 }
        .sensoryFeedback(arrivalFeedback, trigger: arrivals)
        .sensoryFeedback(.selection, trigger: picks)
    }

    private var commitTitle: String {
        isAddMode ? "Add to \(gym?.name ?? "Gym")" : "Use This Machine"
    }

    private var retakeButton: some View {
        Button("Take another photo", action: onRetake)
            .buttonStyle(.lookSecondary)
            .accessibilityIdentifier("scanRescan")
    }

    private var stepSpring: Animation? {
        reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)
    }

    private var arrivalFeedback: SensoryFeedback {
        switch resolution {
        case .catalog, .newModel: .success
        default: .impact(weight: .light)
        }
    }

    // MARK: Outcome

    private var outcome: ScanOutcome {
        if genericChosen { return .generic }
        switch resolution {
        case .catalog: return .matched
        case .newModel: return .newModel
        case .ambiguous: return .several(catalogMatches.count)
        case .generic: return .generic
        }
    }

    private var stateLabel: String {
        switch outcome {
        case .matched: "Matches catalog"
        case .several(let n): "\(n) matches"
        case .newModel: "New model"
        case .generic, .failed: "Generic"
        }
    }

    /// The model this answer would claim, when it claims one.
    private var claimedModel: EquipmentModel? {
        guard !genericChosen, case .catalog(let model) = resolution else { return nil }
        return model
    }

    /// Shown for the AI's specific answer whatever it currently resolves to: clearing a field on
    /// the way to retyping it resolves to generic for a moment, and hiding the editors then would
    /// leave the correction unfinishable (codex-review-07). Only "Use generic identity" hides them.
    private var showsMakerFields: Bool {
        !genericChosen && proposal.identity == "specific"
    }

    private var discSize: CGFloat { typeSize.isAccessibilitySize ? 52 : 58 }

    private var hero: some View {
        let showsText = !genericChosen && !proposal.visibleText.isEmpty && proposal.identity == "specific"
        return VStack(alignment: .leading, spacing: 0) {
            ScanPhotoTile(image: photo, cornerRadius: 0)
                .frame(height: typeSize.isAccessibilitySize ? 190 : 236)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ScanOutcomeDisc(outcome: outcome, size: discSize)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stateLabel)
                            .font(look.font.navTitle)
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                        if case .several = outcome {
                            Text("Saved without a model")
                                .font(look.font.subhead)
                                .foregroundStyle(look.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                identity
                if showsText {
                    Text("Read on the machine: \(proposal.visibleText)")
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                duplicate
                genericToggle
            }
            .padding(look.space.panelPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
        .lookSurface(.panel)
        .animation(stepSpring, value: genericChosen)
    }

    @ViewBuilder private var identity: some View {
        switch outcome {
        case .generic, .failed:
            VStack(alignment: .leading, spacing: 4) {
                Text(proposal.label.trimmingCharacters(in: .whitespaces).isEmpty ? "Machine" : proposal.label)
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Saved as this gym’s machine, with no model claimed.")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        case .several:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(catalogMatches, id: \.id) { model in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        EquipmentTile(category: model.equipmentType, size: 22)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                        Text(model.displayName)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        case .matched:
            if let model = claimedModel {
                makerAndModel(maker: model.manufacturer, model: model.modelName)
                if let type = model.equipmentType { tag(type.label) }
            }
        case .newModel:
            if case .newModel(let maker, let name) = resolution {
                makerAndModel(maker: maker, model: name)
                tag("Custom")
            }
        }
    }

    private func makerAndModel(maker: String, model: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(maker)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            Text(model)
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textSecondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .overlay { Capsule().strokeBorder(look.hairline, lineWidth: 1) }
    }

    @ViewBuilder private var duplicate: some View {
        if let model = claimedModel, let gym, let existing = ScanMachine.existing(modelID: model.id, at: gym) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "square.on.square")
                    .font(.system(.footnote, weight: .bold))
                    .accessibilityHidden(true)
                Text("Already at \(gym.name) as “\(existing.label)”")
                    .font(.system(.subheadline, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: look.radius.field, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("scanDuplicate")
        }
    }

    /// Catalog match / new model: the chip that sets the answer aside, and the one that brings
    /// it back.
    @ViewBuilder private var genericToggle: some View {
        let restorable: String? = switch resolution {
        case .catalog: "Use catalog match"
        case .newModel: "Use new model"
        default: nil
        }
        if let restorable {
            Group {
                if genericChosen {
                    Chip(restorable, symbol: "arrow.uturn.backward") { toggleGeneric() }
                } else {
                    Chip("Use generic identity", symbol: "circle.dashed") { toggleGeneric() }
                }
            }
            .accessibilityIdentifier("scanGenericToggle")
        }
    }

    private func toggleGeneric() {
        picks += 1
        withAnimation(stepSpring) { genericChosen.toggle() }
    }

    // MARK: Name and maker

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Name")
            HStack(spacing: 12) {
                LookIcon(LookIcon.machine, style: .body)
                    .foregroundStyle(look.textSecondary)
                TextField("Machine name", text: Binding(get: { proposal.label },
                                                         set: { proposal.label = $0; proposal.labelWasEdited = true }),
                          axis: .vertical)
                    .font(look.font.title3)
                    .foregroundStyle(look.textPrimary)
                    .focused(focusedField, equals: .label)
                    .accessibilityIdentifier("identifiedMachineLabel")
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
                RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
                    .strokeBorder(look.selection, lineWidth: 2)
                    .opacity(focusedField.wrappedValue == .label ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: focusedField.wrappedValue)
        }
    }

    /// D56's editable proposal: the maker and model the AI read, before Add resolves them.
    private var makerFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Maker and model")
            VStack(spacing: 0) {
                makerField("Manufacturer", text: Binding(get: { proposal.manufacturer }, set: { proposal.manufacturer = $0 }),
                           field: .manufacturer)
                    .accessibilityIdentifier("identifiedManufacturer")
                LookDivider().padding(.leading, 14)
                makerField("Model", text: Binding(get: { proposal.modelName }, set: { proposal.modelName = $0 }),
                           field: .model)
                    .accessibilityIdentifier("identifiedModel")
            }
            .lookSurface(.field)
        }
    }

    private func makerField(_ title: String, text: Binding<String>, field: IdentifyEquipmentSheet.Field) -> some View {
        TextField(title, text: text, axis: .vertical)
            .font(look.font.body)
            .foregroundStyle(look.textPrimary)
            .focused(focusedField, equals: field)
            .accessibilityLabel(title)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(look.textSecondary)
            .padding(.leading, 4)
    }

    // MARK: Exercises

    /// A catalog model supplies its own exercises (D24), so the list is editable only when no
    /// catalog model is claimed.
    private var exercisesEditable: Bool { claimedModel?.exerciseIDs.isEmpty != false }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(look.font.sectionTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LookList {
                ForEach(exercises.filter { effectiveIDs.contains($0.id) }) { exercise in
                    LookRow(exercise.name, value: exercise.muscleGroup, showsChevron: false)
                }
                if exercisesEditable {
                    LookRow("Change exercises", symbol: "slider.horizontal.3", action: onChangeExercises)
                        .accessibilityIdentifier("scanChangeExercises")
                }
            }
        }
    }
}
