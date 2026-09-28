import SwiftUI

/// A02 Ask AI step 2 (Floodlight ticket 10): which gym, its saved machines (with Scan Machine), the
/// free-weight / station checklist, available cardio, and the routine consent with the Ask AI row.
/// "Generate week" is the one filled command, pinned at the thumb above a live readout of what the
/// AI may use (the families it can train · exercises · cardio).
struct AIEquipmentStep: View {
    @Bindable var model: AIRoutineFlowModel
    var gyms: [Gym]
    var gym: Gym?
    var machines: [MachineInstance]
    var options: [RoutineExerciseOption]
    @Binding var consent: Bool
    /// The fixture skips the consent gate (`TerraAccess.bypassesConsent`).
    var consentBypassed: Bool
    var keyHint: String?
    var onSelectGym: (Gym?) -> Void
    var onAddGym: () -> Void
    var onScan: (Gym) -> Void
    var onOpenSettings: () -> Void
    var onGenerate: () -> Void
    var onCancel: () -> Void

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var glyphBox: CGFloat = 28
    @State private var flashConsent = false

    private var permitted: Bool { consent || consentBypassed }
    private var canGenerate: Bool { permitted && model.hasGoals && (!options.isEmpty || !model.cardio.isEmpty) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    gymMenu.padding(.top, 14)
                    machineStrip.padding(.top, 12)
                    equipment.padding(.top, look.space.section).id("equipment")
                    cardio.padding(.top, look.space.section)
                    consentBlock.padding(.top, look.space.section).id("consent")
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 24)
            }
            .background(look.ground.ignoresSafeArea())
            .safeAreaBar(edge: .top) {
                AITopBar(backLabel: "Goals", step: 1, onBack: model.back, onCancel: onCancel)
            }
            .safeAreaBar(edge: .bottom) { bottomBar(proxy) }
        }
    }

    // MARK: Gym

    private var gymMenu: some View {
        Menu {
            Picker("Gym", selection: Binding(get: { gym?.id }, set: { id in onSelectGym(gyms.first { $0.id == id }) })) {
                ForEach(gyms) { Text($0.name).tag(Optional($0.id)) }
                Text("No gym").tag(UUID?.none)
            }
            Divider()
            Button("Add Gym…", systemImage: "plus", action: onAddGym)
                .accessibilityIdentifier("routineAddGym")
        } label: {
            AIGymLabel(name: gym?.name ?? "No gym", city: gym?.city, isEmpty: gym == nil)
        }
        .tint(look.textPrimary)
        .accessibilityLabel("Gym, \(gym?.name ?? "No gym")")
        .accessibilityIdentifier("routineGym")
    }

    // MARK: Machines

    @ViewBuilder private var machineStrip: some View {
        if let gym {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(machines.count)")
                        .font(look.font.statNumber)
                        .foregroundStyle(look.textPrimary)
                        .contentTransition(.numericText(value: Double(machines.count)))
                        .animation(.snappy, value: machines.count)
                    Text(machines.count == 1 ? "saved machine" : "saved machines")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(machines.count) saved \(machines.count == 1 ? "machine" : "machines")")
                .accessibilityIdentifier("routineMachineCount")
                // The machines are information (what the AI will use), drawn as plain chips; the one
                // thing to press is the dashed Scan Machine chip at the head.
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        AIScanChip { onScan(gym) }
                        ForEach(machines) { AIMachineChip(label: $0.label) }
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

    // MARK: Equipment

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
        let on = model.extras.contains(item)
        return AISelectTile(isSelected: on, minHeight: 92, alignment: .topLeading) {
            if on { model.extras.remove(item) } else { model.extras.insert(item) }
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    AIEquipmentIcon(kind: item)
                    Spacer(minLength: 4)
                    AICheckMark(isOn: on)
                }
                Text(item.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel(item.name)
        .accessibilityIdentifier("routineEquipment.\(item.rawValue)")
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
        let on = model.cardio.contains(activity)
        return AISelectTile(isSelected: on, minHeight: compact ? 76 : 56, alignment: compact ? .topLeading : .leading) {
            if on { model.cardio.remove(activity) } else { model.cardio.insert(activity) }
        } content: {
            if compact {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Image(systemName: activity.aiSymbol).font(.system(.title3, weight: .semibold))
                            .frame(width: glyphBox, height: glyphBox, alignment: .leading)
                        Spacer(minLength: 2)
                        AICheckMark(isOn: on)
                    }
                    Text(activity.name)
                        .font(.system(.footnote, weight: .semibold))
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
        .accessibilityIdentifier("routineCardio.\(activity.rawValue)")
    }

    // MARK: Consent + Ask AI

    private var consentBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            LookList {
                Toggle(isOn: $consent) {
                    Text("Allow sending routine details to OpenAI")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(look.textPrimary)
                }
                .toggleStyle(AISwitchStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 50)
                .accessibilityIdentifier("allowAIRoutine")
                // Same label as the Settings row (X01).
                LookRow("Ask AI", symbol: "key", value: keyHint ?? "No key", action: onOpenSettings)
                    .accessibilityIdentifier("routineAskAIRow")
            }
            .overlay {
                // Points at the switch after a tap on the off Generate.
                RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
                    .strokeBorder(look.textPrimary, lineWidth: 2.5)
                    .opacity(flashConsent ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: flashConsent)
                    .allowsHitTesting(false)
            }
            if !consent {
                // One consequence line (was three sentences). It names everything the request sends.
                Text("Sends your goals, schedule, optional profile and exercise list — not Health data or history.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                    .transition(.opacity)
                Link(destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!) {
                    HStack(spacing: 4) {
                        Text("OpenAI data policies")
                        Image(systemName: "arrow.up.right").font(.system(.caption, weight: .bold))
                    }
                }
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .frame(minHeight: 44)
                .padding(.horizontal, 4)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: consent)
    }

    // MARK: Bottom bar

    private func bottomBar(_ proxy: ScrollViewProxy) -> some View {
        let families = AIRoutineReadouts.eligibleFamilies(options)
        return AIBottomBar {
            if keyHint == nil && !TerraAccess.fixture {
                Text("Add your OpenAI API key to create routines.")
                    .font(look.font.footnote)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    familyStrip(families)
                    Spacer(minLength: 6)
                    counts
                }
                counts
            }
            .accessibilityElement(children: .combine)
            if keyHint == nil && !TerraAccess.fixture {
                // No key yet: the one thing to do.
                AIPrimaryButton("Ask AI Settings", symbol: "key", identifier: "routineAISettings", action: onOpenSettings)
            } else {
                AIPrimaryButton("Generate week", symbol: "sparkles", isEnabled: canGenerate, identifier: "generateAIRoutine",
                                onDisabledTap: { pointAtMissing(proxy) }, action: onGenerate)
            }
        }
    }

    /// Generate is off: bring the reason into view — the consent switch (outlined for a moment),
    /// else the equipment.
    private func pointAtMissing(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
            proxy.scrollTo(permitted ? "equipment" : "consent", anchor: .center)
        }
        guard !permitted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { flashConsent = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { flashConsent = false }
    }

    private func familyStrip(_ lit: Set<MuscleFamily>) -> some View {
        HStack(spacing: 1) {
            ForEach(MuscleFamily.allCases) { family in
                FamilySticker(family: family, lit: lit.contains(family), size: 28)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: lit.contains(family))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trains " + MuscleFamily.allCases.filter { lit.contains($0) }.map(\.label).joined(separator: ", "))
    }

    private var counts: some View {
        HStack(spacing: 12) {
            AIInlineFigure(number: options.count, label: options.count.aiPlural("exercise"), numberFont: look.font.fieldNumber)
            AIInlineFigure(number: model.cardio.count, label: "cardio", numberFont: look.font.fieldNumber)
        }
        .animation(.snappy, value: options.count)
        .animation(.snappy, value: model.cardio.count)
        .accessibilityIdentifier("routineReadout")
    }
}

// MARK: - Gym label (the menu's face)

private struct AIGymLabel: View {
    var name: String
    var city: String?
    var isEmpty: Bool
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            IconDisc(symbol: look.gymSymbol, size: disc, context: .onSurface)
                .background { Circle().fill(look.surfaceRaised) }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(isEmpty ? look.textSecondary : look.textPrimary)
                if let city, !city.isEmpty {
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
        .lookSurface(.tile, radius: 16)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Machine strip

/// A saved machine: information, not a toggle — no fill, the information edge, one line.
private struct AIMachineChip: View {
    var label: String
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 6) {
            LookIcon(LookIcon.machine, style: .footnote)
                .foregroundStyle(look.textSecondary)
            Text(label)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .overlay { Capsule().strokeBorder(look.hairline, lineWidth: 1) }
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
                Image(systemName: "camera.viewfinder").font(.system(.footnote, weight: .bold))
                Text("Scan Machine").font(.system(.footnote, weight: .bold)).lineLimit(1)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .overlay { Capsule().strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
            .contentShape(Capsule())
            .padding(.vertical, 2)
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("Scan Machine")
        .accessibilityIdentifier("routineScanMachine")
    }
}
