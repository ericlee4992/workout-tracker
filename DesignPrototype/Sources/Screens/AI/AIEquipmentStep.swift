import SwiftUI

// PROTOTYPE — A02 Ask AI step 2: which gym, its saved machines (with Scan Machine), the
// free-weight / station checklist, available cardio, and the routine consent with the Ask AI
// settings link. "Generate week" is the one filled command, pinned at the thumb above a live
// readout of what the AI may use (families it can train · exercises · cardio).

struct AIEquipmentStepView: View {
    var initialPage: Int?
    var actions: AIFlowActions

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title3) private var glyphBox: CGFloat = 28
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// A section to bring into view (tapping the disabled Generate points at what is missing).
    @State private var scrollTarget: String?
    @State private var flashConsent = false
    @State private var launched = false

    private var request: AIRoutineRequest { store.ai.request }
    private var gym: Gym? { store.gym(request.gymID) }

    var body: some View {
        AIPagedScrollView(initialPage: initialPage, scrollTarget: $scrollTarget) {
            VStack(alignment: .leading, spacing: 0) {
                gymMenu
                    .padding(.top, 14)
                machines
                    .padding(.top, 12)
                equipment
                    .padding(.top, look.space.section)
                    .id("equipment")
                cardio
                    .padding(.top, look.space.section)
                consent
                    .padding(.top, look.space.section)
                    .id("consent")
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 24)
        }
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) { AITopBar(backLabel: "Goals", step: 1, onBack: actions.back, onCancel: actions.close) }
        .safeAreaBar(edge: .bottom) { bottomBar }
        .onAppear {
            // Capture variants: "consentOff" / "nothing" open with the pointer already shown.
            guard !launched else { return }
            launched = true
            guard store.currentScreen == .a02, let variant = router.variant else { return }
            if variant == "consentOff" || variant == "nothing" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pointAtMissing(holds: true) }
            }
        }
    }

    // MARK: Gym

    private var gymBinding: Binding<UUID?> {
        Binding(get: { store.ai.request.gymID },
                set: { id in store.aiUpdateRequest { $0.gymID = id } })
    }

    private var gymMenu: some View {
        Menu {
            Picker("Gym", selection: gymBinding) {
                ForEach(store.activeGyms) { gym in
                    Text(gym.name).tag(Optional(gym.id))
                }
                Text("No gym").tag(UUID?.none)
            }
            Divider()
            Button("Add Gym…", systemImage: "plus") { router.present(.editGym(gymID: nil)) }
        } label: {
            AIGymLabel(name: gym?.name ?? "No gym", city: gym?.city, isEmpty: gym == nil)
        }
        .tint(look.textPrimary)
        .accessibilityLabel("Gym, \(gym?.name ?? "No gym")")
    }

    // MARK: Machines

    @ViewBuilder private var machines: some View {
        if let gym {
            let list = store.activeMachines(gymID: gym.id)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(list.count)")
                        .font(look.font.statNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText(value: Double(list.count)))
                        .animation(.snappy, value: list.count)
                    Text(list.count == 1 ? "saved machine" : "saved machines")
                        .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                .accessibilityElement(children: .combine)
                // The machines are information (what the AI will use), drawn as plain chips; the
                // one thing to press here is the dashed Scan Machine chip at the head.
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        AIScanChip {
                            store.scanBegin(gymID: gym.id)
                            router.present(.scan(gymID: gym.id))
                        }
                        ForEach(list) { machine in
                            AIMachineChip(label: machine.label)
                        }
                    }
                    .padding(.horizontal, look.space.margin)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .padding(.horizontal, -look.space.margin)
            }
        } else {
            Text("Choose or add a gym to save scanned machines.")
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: Equipment checklist

    private var equipment: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Available equipment")
            let items = RoutineEquipment.allCases
            let columns = typeSize.isAccessibilitySize ? 1 : 2
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                    GridRow {
                        ForEach(start..<min(start + columns, items.count), id: \.self) { i in
                            equipmentTile(items[i])
                        }
                    }
                }
            }
        }
    }

    private func equipmentTile(_ item: RoutineEquipment) -> some View {
        let on = request.equipment.contains(item)
        return AISelectTile(isSelected: on, minHeight: 92, alignment: .topLeading) {
            store.aiUpdateRequest { r in
                if r.equipment.contains(item) { r.equipment.remove(item) } else { r.equipment.insert(item) }
            }
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    AIEquipmentIcon(kind: item)
                    Spacer(minLength: 4)
                    AICheckMark(isOn: on)
                }
                Text(item.label)
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel(item.label)
    }

    // MARK: Cardio

    private var cardio: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Available cardio")
            let items = CardioActivity.allCases
            let columns = typeSize.isAccessibilitySize ? 1 : 3
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                    GridRow {
                        ForEach(start..<min(start + columns, items.count), id: \.self) { i in
                            cardioTile(items[i], compact: columns > 1)
                        }
                    }
                }
            }
        }
    }

    private func cardioTile(_ activity: CardioActivity, compact: Bool) -> some View {
        let on = request.cardio.contains(activity)
        return AISelectTile(isSelected: on, minHeight: compact ? 76 : 56, alignment: compact ? .topLeading : .leading) {
            store.aiUpdateRequest { r in
                if r.cardio.contains(activity) { r.cardio.remove(activity) } else { r.cardio.insert(activity) }
            }
        } content: {
            if compact {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        // A fixed glyph box, so every label in a row starts on the same line.
                        Image(systemName: activity.aiSymbol).font(.system(.title3, weight: .semibold))
                            .frame(width: glyphBox, height: glyphBox, alignment: .leading)
                        Spacer(minLength: 2)
                        AICheckMark(isOn: on)
                    }
                    Text(activity.name)
                        .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: activity.aiSymbol).font(.system(.title3, weight: .semibold))
                        .frame(width: glyphBox)
                    Text(activity.name).font(.system(.subheadline, weight: .semibold))
                    Spacer(minLength: 4)
                    AICheckMark(isOn: on)
                }
            }
        }
        .accessibilityLabel(activity.name)
    }

    // MARK: Consent + Ask AI settings

    private var consent: some View {
        VStack(alignment: .leading, spacing: 6) {
            LookList {
                Toggle(isOn: Binding(get: { store.ai.request.consent },
                                     set: { on in store.aiUpdateRequest { $0.consent = on } })) {
                    Text("Allow sending routine details to OpenAI")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(look.textPrimary)
                }
                .toggleStyle(AISwitchStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 50)
                // Same label as the Settings row (X01).
                LookRow("Ask AI", symbol: "key",
                        value: store.settings.aiKeySaved ? store.settings.aiKeyHint : "No key") {
                    router.present(.aiSettings)
                }
            }
            .overlay {
                // Points at the switch after a tap on the disabled Generate.
                RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
                    .strokeBorder(look.textPrimary, lineWidth: 2.5)
                    .opacity(flashConsent ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: flashConsent)
                    .allowsHitTesting(false)
            }
            if !request.consent {
                // PROPOSED one consequence line (replaces the real three-sentence footnote).
                Text("Sends your goals and exercise list, not Health data or history.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                    .transition(.opacity)
                if let url = URL(string: "https://openai.com/policies/api-data-usage-policies") {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("OpenAI data policies")
                            Image(systemName: "arrow.up.right").font(.system(.caption, weight: .bold))
                        }
                    }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .underline(look.id.isPaperClub)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: request.consent)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        let exerciseCount = store.aiEligibleExerciseIDs.count
        let cardioCount = request.cardio.count
        let families = store.aiEligibleFamilies
        return AIBottomBar {
            if !store.settings.aiKeySaved {
                Text("Add your OpenAI API key to create routines.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else if let error = store.ai.error {
                Text(error)
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    familyStrip(families)
                    Spacer(minLength: 6)
                    counts(exerciseCount, cardioCount)
                }
                counts(exerciseCount, cardioCount)
            }
            .accessibilityElement(children: .combine)
            if store.settings.aiKeySaved {
                AIPrimaryButton("Generate week", symbol: "sparkles", isEnabled: store.aiCanGenerate,
                                onDisabledTap: pointAtMissing, action: actions.generate)
            } else {
                // No key yet (today's "Add your OpenAI API key…" state): the one thing to do.
                AIPrimaryButton("Ask AI Settings", symbol: "key") { router.present(.aiSettings) }
            }
        }
    }

    /// Generate is off: bring the reason into view — the consent switch (outlined for a moment),
    /// else the equipment. `holds` keeps the outline (capture variant).
    private func pointAtMissing() { pointAtMissing(holds: false) }

    private func pointAtMissing(holds: Bool) {
        if !request.consent {
            scrollTarget = "consent"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { flashConsent = true }
            if !holds { DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { flashConsent = false } }
        } else {
            scrollTarget = "equipment"
        }
    }

    private func familyStrip(_ lit: Set<MuscleFamily>) -> some View {
        HStack(spacing: look.id.isPaperClub ? 4 : 1) {
            ForEach(MuscleFamily.allCases) { family in
                FamilySticker(family: family, lit: lit.contains(family), size: look.id.isPaperClub ? 26 : 28)
                    .animation(.easeOut(duration: 0.25), value: lit.contains(family))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trains " + MuscleFamily.allCases.filter { lit.contains($0) }.map(\.label).joined(separator: ", "))
    }

    private func counts(_ exercises: Int, _ cardio: Int) -> some View {
        HStack(spacing: 12) {
            AIInlineFigure(number: exercises, label: exercises.aiPlural("exercise"), numberFont: look.font.fieldNumber)
            AIInlineFigure(number: cardio, label: "cardio", numberFont: look.font.fieldNumber)
        }
        .animation(.snappy, value: exercises)
        .animation(.snappy, value: cardio)
    }
}

// MARK: - Gym label (the Menu's face)

/// The routine's gym: pin disc · name · city · ⌃⌄, as the look's pressable card.
private struct AIGymLabel: View {
    var name: String
    var city: String?
    var isEmpty: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            IconDisc(symbol: look.gymSymbol, size: disc, context: .onSurface)
                .background { if look.id == .floodlight { Circle().fill(look.surfaceRaised) } }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.body, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                    .foregroundStyle(isEmpty ? look.textSecondary : look.textPrimary)
                if let city {
                    Text(city).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textSecondary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .lookSurface(.tile, radius: look.id == .anatomy ? look.radius.panel : 16)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Machine strip

/// A saved machine: information, not a toggle — no tile fill, the information edge, one line.
private struct AIMachineChip: View {
    var label: String
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 6) {
            LookIcon(LookIcon.machine, style: .footnote)
                .foregroundStyle(look.textSecondary)
            Text(label)
                .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .overlay {
            Capsule().strokeBorder(look.hairline, lineWidth: look.id.isPaperClub ? look.stroke.hairline : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// The dashed "make one" chip at the head of the strip: Scan Machine.
private struct AIScanChip: View {
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(.footnote, weight: .bold))
                Text("Scan Machine")
                    .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .overlay {
                Capsule().strokeBorder(look.id.isPaperClub ? look.outline : look.dash,
                                       style: StrokeStyle(lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [5, 4]))
            }
            .contentShape(Capsule())
            .padding(.vertical, 2)
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("Scan Machine")
    }
}
