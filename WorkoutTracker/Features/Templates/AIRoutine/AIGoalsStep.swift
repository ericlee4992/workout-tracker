import SwiftUI

/// A01 Ask AI step 1 (Floodlight ticket 10): goals, experience, days, minutes, optional profile.
/// The bold element is the week's session count — seven cells lit 1…N. Everything else is a big
/// tappable choice; the only typing is the goal (phrase chips write into it) and the profile.
struct AIGoalsStep: View {
    @Bindable var model: AIRoutineFlowModel
    /// Height in ft + in and weight in lb (ticket 10, decision 4).
    var usCustomary: Bool
    var onCancel: () -> Void

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: Field?

    private enum Field: Hashable { case goals, heightA, heightB, weight }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                goalField.padding(.top, 14)
                goalChips.padding(.top, 8)
                experience.padding(.top, look.space.section)
                schedule.padding(.top, look.space.section)
                profile.padding(.top, look.space.section)
                if ProfileSample.prefillsAskAI {
                    saveToProfile.padding(.top, look.space.group)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) { AITopBar(step: 0, onCancel: onCancel) }
        .safeAreaBar(edge: .bottom) {
            // While typing, the keyboard's Done takes the thumb zone; Next returns with it.
            if focus == nil {
                AIBottomBar {
                    if let error = model.inputError {
                        Text(error)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("routineAIError")
                    }
                    // With no goal yet, a tap on the off Next puts the cursor in the goal field.
                    AIPrimaryButton("Next", symbol: "arrow.right", trailingSymbol: true, isEnabled: model.hasGoals,
                                    identifier: "routineNext", disabledHint: "Add a goal first.",
                                    onDisabledTap: { focus = .goals }) {
                        focus = nil
                        model.next()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("dismissRoutineKeyboard")
            }
        }
    }

    // MARK: Goal

    private var goalField: some View {
        TextField("", text: $model.goals,
                  prompt: Text("What would you like to work toward?").foregroundStyle(look.textSecondary),
                  axis: .vertical)
            .lineLimit(2...6)
            .font(.system(.body, weight: .medium))
            .foregroundStyle(look.textPrimary)
            .focused($focus, equals: .goals)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .lookSurface(.field, radius: look.radius.tile - 4)
            .accessibilityLabel("Goals")
            .accessibilityIdentifier("routineGoals")
    }

    private var goalChips: some View {
        WrapLayout(spacing: 8) {
            ForEach(Array(AIGoalPhrase.allCases.enumerated()), id: \.element) { index, phrase in
                AIGoalChip(title: phrase.rawValue, isSelected: phrase.isIn(model.goals)) {
                    model.goals = phrase.toggled(in: model.goals)
                }
                .accessibilityIdentifier("routineGoalPhrase.\(index)")
            }
        }
    }

    // MARK: Experience

    private var experience: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Experience")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { experienceTiles }
                VStack(spacing: 8) { experienceTiles }
            }
        }
    }

    @ViewBuilder private var experienceTiles: some View {
        ForEach(Array(AIRoutineFlowModel.experiences.enumerated()), id: \.element) { index, level in
            let selected = model.experience == level
            AISelectTile(isSelected: selected, minHeight: 84) {
                model.experience = level
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        let lit = AISelectionPaint(look: look, isSelected: selected).foreground
                        AIExperienceBars(level: index + 1, lit: lit, unlit: lit.opacity(0.28))
                        Spacer(minLength: 8)
                        AICheckMark(isOn: selected)
                    }
                    Text(level)
                        .font(.system(.subheadline, weight: selected ? .bold : .semibold))
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(level)
            .accessibilityIdentifier("routineExperience.\(level)")
        }
    }

    // MARK: Days and minutes (the bold element)

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 0) {
            figure(model.days, model.days == 1 ? "day per week" : "days per week")
            AIDayCountPicker(count: model.days) { model.days = $0 }
                .padding(.top, 14)
                // The cells reach into the panel's padding so seven of them keep 44 pt targets on a
                // 375–393 pt wide phone (codex-review-10 L3).
                .padding(.horizontal, -10)
            LookDivider().padding(.vertical, 18)
            figure(model.minutes, "minutes per session")
            AIMinutesControl(value: $model.minutes)
                .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .lookSurface(.panel)
    }

    private func figure(_ number: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(look.font.heroNumber)
                .foregroundStyle(look.textPrimary)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(number)))
                .animation(reduceMotion ? nil : .snappy, value: number)
            Text(label)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Save to the training profile (ticket 05 mock: the user decides whether this exists)

    @State private var savesToProfile = true

    private var saveToProfile: some View {
        VStack(alignment: .leading, spacing: 8) {
            LookList(separatorInset: 54) {
                SettingsRow("Save to my training profile", symbol: "person.crop.circle", trailingStaysInline: true) {
                    Toggle(isOn: $savesToProfile) { Text("Save to my training profile") }
                        .toggleStyle(.settings)
                        .fixedSize()
                        .accessibilityIdentifier("routineSaveToProfile")
                }
            }
            SettingsNotice(symbol: "person.text.rectangle", text: "Filled in from your training profile.")
                .padding(.top, 2)
        }
    }

    // MARK: Optional profile

    private var profile: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Optional profile")
            VStack(spacing: 0) {
                profileRow("Height") { heightFields }
                LookDivider().padding(.leading, 16)
                profileRow("Weight") { weightField }
            }
            .lookSurface(.panel)
        }
    }

    private func profileRow<Fields: View>(_ title: String, @ViewBuilder fields: () -> Fields) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(title)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 8) { fields() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    @ViewBuilder private var heightFields: some View {
        if usCustomary {
            let parts = model.heightCm.map { AIProfileUnits.feetInches(cm: $0) }
            AIProfileField(text: Binding(
                get: { parts.map { "\($0.feet)" } ?? "" },
                set: { text in
                    let feet = AIProfileUnits.parse(text)
                    let inches = model.heightCm.map { AIProfileUnits.feetInches(cm: $0).inches } ?? 0
                    model.heightCm = feet.map { AIProfileUnits.centimetres(feet: $0, inches: inches) }
                }), unit: "ft", accessibility: "Height, feet", identifier: "routineHeightFeet", focus: $focus, field: .heightA)
            AIProfileField(text: Binding(
                get: { parts.map { "\($0.inches)" } ?? "" },
                set: { text in
                    let inches = min(11, AIProfileUnits.parse(text) ?? 0)
                    let feet = model.heightCm.map { AIProfileUnits.feetInches(cm: $0).feet } ?? 0
                    model.heightCm = AIProfileUnits.centimetres(feet: feet, inches: inches)
                }), unit: "in", accessibility: "Height, inches", identifier: "routineHeightInches", focus: $focus, field: .heightB)
        } else {
            AIProfileField(text: Binding(
                get: { AIProfileUnits.text(model.heightCm) },
                set: { model.heightCm = AIProfileUnits.parse($0).map(Double.init) }),
                unit: "cm", accessibility: "Height, centimetres", identifier: "routineHeight", focus: $focus, field: .heightA)
        }
    }

    private var weightField: some View {
        AIProfileField(text: Binding(
            get: { AIProfileUnits.text(model.weightKg.map { usCustomary ? AIProfileUnits.pounds(kg: $0) : $0 }) },
            set: { text in
                model.weightKg = AIProfileUnits.parse(text).map {
                    usCustomary ? AIProfileUnits.kilograms(pounds: Double($0)) : Double($0)
                }
            }),
            unit: usCustomary ? "lb" : "kg", accessibility: "Weight, \(usCustomary ? "pounds" : "kilograms")",
            identifier: "routineWeight", focus: $focus, field: .weight)
    }
}

// MARK: - Profile field

private struct AIProfileField<F: Hashable>: View {
    @Binding var text: String
    var unit: String
    var accessibility: String
    var identifier: String
    var focus: FocusState<F?>.Binding
    var field: F
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var width: CGFloat = 58

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            TextField("", text: $text, prompt: Text("–").foregroundStyle(look.textSecondary))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(look.font.fieldNumber)
                .foregroundStyle(look.textPrimary)
                .focused(focus, equals: field)
                .frame(width: width)
                .frame(minHeight: 44)
                .lookSurface(.field)
                .accessibilityLabel(accessibility)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Days per week (the bold element)

/// Seven cells, 1…7, lit up to the chosen count (scoreboard bulbs).
struct AIDayCountPicker: View {
    var count: Int
    var onSelect: (Int) -> Void
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 54

    var body: some View {
        // The widest gap that still leaves every cell 44 pt wide.
        ViewThatFits(in: .horizontal) {
            ForEach([6, 4, 2, 0], id: \.self) { spacing in
                HStack(spacing: CGFloat(spacing)) {
                    ForEach(1...7, id: \.self) { n in
                        Button { onSelect(n) } label: { cell(n) }
                            .buttonStyle(.lookPressable)
                            .frame(minWidth: 44)
                            .accessibilityIdentifier("routineDays.\(n)")
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Days per week")
        .accessibilityValue("\(count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSelect(min(7, count + 1))
            case .decrement: onSelect(max(1, count - 1))
            @unknown default: break
            }
        }
        .accessibilityIdentifier("routineDays")
    }

    private func cell(_ n: Int) -> some View {
        let lit = n <= count
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Text("\(n)").font(look.font.smallNumber)
            .foregroundStyle(lit ? look.onDone : look.textSecondary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(lit ? look.done : look.surfaceRaised, in: shape)
            .contentShape(shape)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2).delay(Double(n) * 0.035), value: lit)
    }
}

// MARK: - Minutes per session

/// A draggable time bar (15…120 min, 5-minute steps) between − and +. The fill is the session
/// length as a picture; each step ticks a selection haptic.
struct AIMinutesControl: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 15...120
    var step = 5
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var thumb: CGFloat = 28
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragAxis: Axis?

    var body: some View {
        HStack(spacing: 10) {
            roundButton("minus", label: "Fewer minutes", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }
            track
            roundButton("plus", label: "More minutes", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Minutes per session")
        .accessibilityValue("\(value) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("routineMinutes")
    }

    private func set(x: CGFloat, usable: CGFloat) {
        let f = min(1, max(0, (x - thumb / 2) / usable))
        let raw = Double(range.lowerBound) + Double(f) * Double(range.upperBound - range.lowerBound)
        let snapped = Int((raw / Double(step)).rounded()) * step
        value = min(range.upperBound, max(range.lowerBound, snapped))
    }

    private var fraction: CGFloat {
        CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
    }

    private var track: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumb)
            ZStack(alignment: .leading) {
                Capsule().fill(look.ringTrack).frame(height: 10)
                Capsule().fill(look.done).frame(width: thumb / 2 + fraction * usable, height: 10)
                ForEach([30, 60, 90], id: \.self) { mark in
                    let x = thumb / 2 + CGFloat(mark - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound) * usable
                    Capsule().fill(mark <= value ? look.ground.opacity(0.55) : look.textTertiary.opacity(0.6))
                        .frame(width: 2, height: 6)
                        .offset(x: x - 1)
                }
                Circle().fill(look.textPrimary)
                    .overlay { Circle().strokeBorder(look.surface, lineWidth: 4) }
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .offset(x: fraction * usable)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            // A tap sets the time; a drag only once it is clearly sideways, so a scroll that
            // starts on the track still scrolls the page.
            .onTapGesture(coordinateSpace: .local) { location in set(x: location.x, usable: usable) }
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { g in
                        if dragAxis == nil {
                            dragAxis = abs(g.translation.width) > abs(g.translation.height) ? .horizontal : .vertical
                        }
                        guard dragAxis == .horizontal else { return }
                        set(x: g.location.x, usable: usable)
                    }
                    .onEnded { _ in dragAxis = nil })
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: value)
        }
        .frame(height: 44)
    }

    private func roundButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(enabled ? look.textPrimary : look.textTertiary.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(look.controlFill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.lookPressable)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
