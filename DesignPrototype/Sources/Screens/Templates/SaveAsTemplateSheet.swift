import SwiftUI

// PROTOTYPE — T04: Save as Template (from Finish or a History workout). It was an alert with a
// text field and a message that contradicted what gets saved. Now: the name, with the one
// consequence line pinned right under it (above the keyboard), then a preview of the template
// it makes (families, exercises, "N sets · r, r reps", cardio targets). The field is the name,
// so the preview carries no second heading. Saving stamps a check and shows the new tile;
// tapping the tile opens the template. Variants: `saved` (the confirmation), `empty` (the name
// cleared: Save disabled).

struct SaveAsTemplateSheet: View {
    let workoutID: UUID
    @Environment(Router.self) private var router

    // The capture override (`-axl YES`) wraps the content, so its own type-size reads see it.
    var body: some View {
        TemplatesSaveAsContent(workoutID: workoutID)
            .modifier(TemplatesTypeOverride(size: router.dynamicTypeOverride))
    }
}

struct TemplatesSaveAsContent: View {
    let workoutID: UUID
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var name = ""
    @State private var loaded = false
    @State private var savedID: UUID?
    @State private var stamp = false
    @State private var savedHeight: CGFloat = 520
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty && store.canSaveAsTemplate(workoutID: workoutID) }

    var body: some View {
        VStack(spacing: 0) {
            if let savedID, let template = store.template(savedID) {
                saved(template)
                    .transition(.opacity)
            } else {
                entry
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: savedID)
        .lookSheetGround()
        // Entry takes the full height (name + preview); the confirmation shrinks to its content.
        .presentationDetents(savedID == nil ? [.large] : [.height(savedHeight + 4), .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: savedID)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        name = router.variant == "empty" ? "" : store.defaultTemplateName(workoutID: workoutID)
        if router.variant == "saved" {
            save()
        } else {
            // Focus once the sheet has risen; again a beat later if the first came too early.
            for delay in [0.5, 1.2] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { if !nameFocused { nameFocused = true } } }
        }
    }

    private func save() {
        guard canSave, let id = store.saveAsTemplate(workoutID: workoutID, name: trimmed) else { return }
        nameFocused = false
        savedID = id
        if reduceMotion { stamp = true } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { stamp = true }
            }
        }
    }

    // MARK: Entry

    private var entry: some View {
        VStack(spacing: 0) {
            // AX sizes: the title leaves the bar and becomes the first content line.
            SheetHeader(cancel: { dismiss() }, title: typeSize.isAccessibilitySize ? "" : "Save as Template",
                        commit: save, commitEnabled: canSave)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if typeSize.isAccessibilitySize {
                        Text("Save as Template")
                            .font(look.font.title2)
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, -8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        nameField
                        if let workout = store.workout(workoutID) { consequence(workout) }
                    }
                    if let workout = store.workout(workoutID) { preview(workout) }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var nameField: some View {
        HStack(spacing: 8) {
            // A long name (or AccessibilityL) wraps instead of scrolling out of sight; Return saves.
            TextField("Template name", text: TemplatesSingleLine.binding($name, onReturn: save),
                      prompt: Text("Template name").foregroundStyle(look.textTertiary), axis: .vertical)
                .lineLimit(1...3)
                .font(look.font.title3)
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .focused($nameFocused)
                .submitLabel(.done)
                .padding(.vertical, 12)
            if !name.isEmpty {
                Button { name = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(look.textTertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 2)
        .frame(minHeight: 56)
        .lookSurface(.field, radius: look.radius.row + 2)
    }

    private func preview(_ workout: Workout) -> some View {
        let template = Derived.template(from: workout, name: trimmed.isEmpty ? "Template name" : trimmed)
        let families = store.templatesFamilies(items: template.items)
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                if look.id.isPaperClub, !families.isEmpty {
                    FamilyBand(families: families, height: 64)
                    Rectangle().fill(look.hairline).frame(height: look.stroke.hairline)
                }
                VStack(alignment: .leading, spacing: 12) {
                    // The field above is the name: the preview leads with what it trains.
                    HStack(spacing: 12) {
                        if !look.id.isPaperClub, !families.isEmpty { FamilyStrip(families: families, size: 34) }
                        if !template.templatesSummary.isEmpty {
                            Text(template.templatesSummary)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(template.items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { LookDivider() }
                            itemRow(item)
                        }
                        ForEach(template.cardio) { plan in
                            LookDivider()
                            HStack(spacing: 10) {
                                Image(systemName: plan.activity.symbol).font(.system(.subheadline, weight: .semibold)).frame(width: 22)
                                Text(plan.activity.name).font(.system(.subheadline, weight: .semibold))
                                Spacer(minLength: 8)
                                Text(plan.templatesSummary).font(look.font.subhead).monospacedDigit()
                                    .foregroundStyle(look.textSecondary)
                            }
                            .foregroundStyle(look.textPrimary)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous))
            .lookSurface(.panel)
        }
    }

    /// What a template keeps (PROPOSED; two variants, with and without cardio).
    private func consequence(_ workout: Workout) -> some View {
        Text(workout.hasCardio
             ? "Saves exercises, sets, target reps and cardio minutes — not weights or rest times."
             : "Saves exercises, sets and target reps — not weights or rest times.")
            .font(look.font.footnote)
            .foregroundStyle(look.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private func itemRow(_ item: TemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(store.exercise(item.exerciseID)?.name ?? "Exercise")
                .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textPrimary)
            Text(Format.targets(item.targetReps))
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Saved

    private func saved(_ template: Template) -> some View {
        let names = template.items.compactMap { store.exercise($0.exerciseID)?.name } + template.cardio.map(\.activity.name)
        return ScrollView {
            VStack(spacing: 22) {
                stampView
                    .padding(.top, 30)
                // The tile below carries the name, so the headline stays one clean line.
                Text("Saved as template")
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Saved as template “\(template.name)”")
                    .accessibilityAddTraits(.isHeader)
                TemplateTile(name: template.name, families: store.families(ofTemplate: template.id), exercises: names,
                             lastDone: nil, now: store.now) {
                    open(template.id)
                }
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 280)
                .scaleEffect(stamp || reduceMotion ? 1 : 0.9)
                .opacity(stamp || reduceMotion ? 1 : 0)
                PrimaryButton("Done") { dismiss() }
                    .padding(.top, 6)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 16)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { savedHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// The look's "done" mark, stamped in (A a lit stamp, B a pearl pop, C an inked rubber stamp).
    private var stampView: some View {
        let side: CGFloat = 92
        return ZStack {
            Circle().fill(look.done)
            if look.id.isPaperClub {
                Circle().strokeBorder(look.onDone, lineWidth: 2.5).padding(6)
            }
            Image(systemName: "checkmark")
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(look.onDone)
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(stamp || reduceMotion ? (look.id.isPaperClub ? -8 : 0) : look.motion.stampRotation))
        .scaleEffect(stamp || reduceMotion ? 1 : look.motion.stampScale)
        .opacity(stamp || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func open(_ id: UUID) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.push(.templateDetail(templateID: id)) }
    }
}
