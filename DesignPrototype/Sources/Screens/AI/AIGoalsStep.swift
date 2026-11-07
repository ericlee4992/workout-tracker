import SwiftUI

// PROTOTYPE — A01 Ask AI step 1: goals, experience, days, minutes, optional profile.
// The bold element is the week's session count: seven cells that light 1…n (A scoreboard
// bulbs, B pearl-washed cells, C punches). Everything else is a big tappable choice; the
// only typing is the goal (quick phrase chips write into it) and the optional profile.

struct AIGoalsStepView: View {
    var initialPage: Int?
    var actions: AIFlowActions

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focus: Field?
    @State private var launched = false

    private enum Field: Hashable { case goals, heightA, heightB, weight }

    private var request: AIRoutineRequest { store.ai.request }

    var body: some View {
        AIPagedScrollView(initialPage: initialPage) {
            VStack(alignment: .leading, spacing: 0) {
                goalField
                    .padding(.top, 14)
                goalChips
                    .padding(.top, 8)
                experience
                    .padding(.top, look.space.section)
                schedule
                    .padding(.top, look.space.section)
                profile
                    .padding(.top, look.space.section)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) { AITopBar(step: 0, onCancel: actions.close) }
        .safeAreaBar(edge: .bottom) {
            // While typing, the keyboard's Done takes the thumb zone; Next returns with it.
            if focus == nil {
              AIBottomBar {
                // With no goal yet, a tap on the disabled Next puts the cursor in the goal field.
                AIPrimaryButton("Next", symbol: "arrow.right", trailingSymbol: true, isEnabled: request.hasGoals,
                                onDisabledTap: { focus = .goals }) {
                    focus = nil
                    actions.next()
                }
              }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }.fontWeight(.semibold)
            }
        }
        .onAppear {
            // Capture variant "emptyFocus": the goal is blank and the cursor waits in it, as after
            // a tap on the disabled Next.
            guard !launched else { return }
            launched = true
            if store.currentScreen == .a01, router.variant == "emptyFocus" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focus = .goals }
            }
        }
    }

    // MARK: Goal

    private var goalsBinding: Binding<String> {
        Binding(get: { store.ai.request.goals },
                set: { text in store.aiUpdateRequest { $0.goals = text } })
    }

    private var goalField: some View {
        TextField("", text: goalsBinding,
                  prompt: Text("What would you like to work toward?")
                    .foregroundStyle(look.id == .floodlight ? look.textSecondary : look.textTertiary),
                  axis: .vertical)
            .lineLimit(2...6)
            .font(look.id == .anatomy ? .system(.body, design: .rounded, weight: .medium) : .system(.body, weight: .medium))
            .foregroundStyle(look.textPrimary)
            .focused($focus, equals: .goals)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .lookSurface(.field, radius: look.radius.tile - 4)
            .accessibilityLabel("Goals")
    }

    private var goalChips: some View {
        AIFlowLayout(spacing: 8) {
            ForEach(AIGoalPhrase.allCases) { phrase in
                let on = phrase.isIn(request.goals)
                AIGoalChip(title: phrase.rawValue, isSelected: on) {
                    let text = phrase.toggled(in: request.goals)
                    store.aiUpdateRequest { $0.goals = text }
                }
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
        ForEach(Array(AIExperience.allCases.enumerated()), id: \.element) { index, level in
            let selected = request.experience == level
            AISelectTile(isSelected: selected, minHeight: 84) {
                store.aiUpdateRequest { $0.experience = level }
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        AIExperienceBars(level: index + 1, lit: barLit(selected), unlit: barLit(selected).opacity(0.28))
                        Spacer(minLength: 8)
                        AICheckMark(isOn: selected)
                    }
                    Text(level.label)
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default,
                                      weight: selected ? .bold : .semibold))
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(level.label)
        }
    }

    private func barLit(_ selected: Bool) -> Color {
        AISelectionPaint(look: look, isSelected: selected).foreground
    }

    // MARK: Days and minutes (the bold element)

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 0) {
            figure(request.daysPerWeek, request.daysPerWeek == 1 ? "day per week" : "days per week")
            AIDayCountPicker(count: request.daysPerWeek) { n in
                store.aiUpdateRequest { $0.daysPerWeek = n }
            }
            .padding(.top, 14)
            LookDivider()
                .padding(.vertical, 18)
            figure(request.minutesPerSession, "minutes per session")
            AIMinutesControl(value: Binding(get: { store.ai.request.minutesPerSession },
                                            set: { m in store.aiUpdateRequest { $0.minutesPerSession = m } }))
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
                .contentTransition(.numericText(value: Double(number)))
                .animation(.snappy, value: number)
            Text(label)
                .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
        .accessibilityElement(children: .combine)
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
                .font(.system(.body, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textPrimary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 8) { fields() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    private var usCustomary: Bool { store.settings.unitSystem == .usCustomary }

    @ViewBuilder private var heightFields: some View {
        if usCustomary {
            let parts = request.heightCm.map { AIProfileUnits.feetInches(cm: $0) }
            AIProfileField(text: Binding(
                get: { parts.map { "\($0.feet)" } ?? "" },
                set: { text in
                    let feet = AIProfileUnits.parse(text)
                    let inches = store.ai.request.heightCm.map { AIProfileUnits.feetInches(cm: $0).inches } ?? 0
                    store.aiUpdateRequest { $0.heightCm = feet.map { AIProfileUnits.centimetres(feet: $0, inches: inches) } }
                }), unit: "ft", accessibility: "Height, feet", focus: $focus, field: .heightA)
            AIProfileField(text: Binding(
                get: { parts.map { "\($0.inches)" } ?? "" },
                set: { text in
                    let inches = min(11, AIProfileUnits.parse(text) ?? 0)
                    let feet = store.ai.request.heightCm.map { AIProfileUnits.feetInches(cm: $0).feet } ?? 0
                    store.aiUpdateRequest { $0.heightCm = AIProfileUnits.centimetres(feet: feet, inches: inches) }
                }), unit: "in", accessibility: "Height, inches", focus: $focus, field: .heightB)
        } else {
            AIProfileField(text: Binding(
                get: { AIProfileUnits.text(store.ai.request.heightCm) },
                set: { text in store.aiUpdateRequest { $0.heightCm = AIProfileUnits.parse(text).map(Double.init) } }),
                unit: "cm", accessibility: "Height, centimetres", focus: $focus, field: .heightA)
        }
    }

    private var weightField: some View {
        let unit = store.displayUnit
        return AIProfileField(text: Binding(
            get: { AIProfileUnits.text(store.ai.request.weightKg.map { unit.fromKg($0) }) },
            set: { text in store.aiUpdateRequest { $0.weightKg = AIProfileUnits.parse(text).map { unit.toKg(Double($0)) } } }),
            unit: unit.label, accessibility: "Weight, \(unit == .lb ? "pounds" : "kilograms")", focus: $focus, field: .weight)
    }
}

// MARK: - Profile field

private struct AIProfileField<F: Hashable>: View {
    @Binding var text: String
    var unit: String
    var accessibility: String
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
            Text(unit)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Days per week (the bold element)

/// Seven cells, 1…7, lit up to the chosen count. A: scoreboard bulbs (flood fills).
/// B: pearl-washed cells with a pearl edge. C: punches (inked discs; dotted when not punched).
struct AIDayCountPicker: View {
    var count: Int
    var onSelect: (Int) -> Void
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 54

    var body: some View {
        HStack(spacing: look.id.isPaperClub ? 4 : 6) {
            ForEach(1...7, id: \.self) { n in
                Button { onSelect(n) } label: { cell(n) }
                    .buttonStyle(.lookPressable)
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
    }

    @ViewBuilder private func cell(_ n: Int) -> some View {
        let lit = n <= count
        let delay = reduceMotion ? 0 : Double(n) * 0.035
        let numeral = Text("\(n)").font(look.font.smallNumber)
        switch look.id {
        case .floodlight:
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            numeral
                .foregroundStyle(lit ? look.onDone : look.textSecondary)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(lit ? look.done : look.surfaceRaised, in: shape)
                .contentShape(shape)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2).delay(delay), value: lit)
        case .anatomy:
            // The flow's selected treatment: pearl lozenge + 2 pt pearl ring (as the tiles below);
            // unchosen days sit flat and dim.
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            numeral
                .foregroundStyle(lit ? look.textPrimary : look.textTertiary)
                .frame(maxWidth: .infinity, minHeight: height)
                .background { shape.fill(look.controlFill); if lit { shape.fill(look.segmentFill) } }
                .overlay { if lit { shape.strokeBorder(look.textPrimary, lineWidth: 2) } }
                .contentShape(shape)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25).delay(delay), value: lit)
        case .paper, .carbon:
            // Punches fit the row on any phone width (≤ 46 pt, always round, never touching).
            numeral
                .foregroundStyle(lit ? look.onDone : look.textSecondary)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: 46, maxHeight: 46)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 1)
                .background { if lit { Circle().fill(look.done) } }
                .overlay {
                    if !lit {
                        Circle().strokeBorder(look.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 3]))
                    }
                }
                .scaleEffect(lit || reduceMotion ? 1 : 0.92)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55).delay(delay), value: lit)
        }
    }
}

// MARK: - Minutes per session

/// A draggable time bar (15…120 min, 5-minute steps) between − and + buttons. The fill is the
/// session length as a picture; each 5-minute step ticks a selection haptic.
struct AIMinutesControl: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 15...120
    var step = 5
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var thumb: CGFloat = 28

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
    }

    @State private var dragAxis: Axis?

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
                Capsule().fill(fillColor).frame(width: thumb / 2 + fraction * usable, height: 10)
                ForEach([30, 60, 90], id: \.self) { mark in
                    let x = thumb / 2 + CGFloat(mark - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound) * usable
                    Capsule().fill(mark <= value ? look.ground.opacity(0.55) : look.textTertiary.opacity(0.6))
                        .frame(width: 2, height: 6)
                        .offset(x: x - 1)
                }
                thumbView
                    .offset(x: fraction * usable)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            // A tap sets the time; a drag sets it only once it is clearly sideways, so a scroll
            // that starts on the track still scrolls the page.
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
            .animation(.snappy(duration: 0.18), value: value)
        }
        .frame(height: 44)
    }

    @ViewBuilder private var thumbView: some View {
        switch look.id {
        case .floodlight, .anatomy:
            Circle().fill(look.textPrimary)
                .overlay { Circle().strokeBorder(look.surface, lineWidth: 4) }
                .frame(width: thumb, height: thumb)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        case .paper, .carbon:
            Circle().fill(look.surface)
                .overlay { Circle().strokeBorder(look.outline, lineWidth: 2.5) }
                .frame(width: thumb, height: thumb)
        }
    }

    private var fillColor: Color { look.id == .floodlight ? look.done : look.textPrimary }

    private func roundButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(enabled ? look.textPrimary : look.textTertiary.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(look.id.isPaperClub ? look.surface : look.controlFill, in: Circle())
                .overlay { if look.id.isPaperClub { Circle().strokeBorder(look.outline, lineWidth: 1.5) } }
                .contentShape(Circle())
        }
        .buttonStyle(.lookPressable)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
