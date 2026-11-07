import SwiftUI

// PROTOTYPE — A04 "Your week": the payoff. A scoreboard of the week (sessions · sets · time)
// with the families it trains, then each session as its own card — family maps (C: its washed
// band), exercise count · sets · minutes, the exercises with sets × reps, and its cardio block.
// Tap a card to edit it (A05). "Save templates" saves every session at once (atomic), then the
// saved state celebrates with the look's status ring and the new template tiles.

struct AIWeekPreviewView: View {
    var initialPage: Int?
    var actions: AIFlowActions

    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var confirmsDiscard = false
    /// What the discard confirmation leads to: Cancel (close) or Back (to Equipment).
    @State private var discardLeavesFlow = true

    var body: some View {
        AIPagedScrollView(initialPage: initialPage) {
            VStack(alignment: .leading, spacing: 0) {
                AIWeekSummary()
                    .padding(.top, 14)
                VStack(spacing: 12) {
                    ForEach(Array(store.ai.days.enumerated()), id: \.element.id) { index, day in
                        AIDayCard(day: day) { actions.openDay(day.id) }
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 28)
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82)
                                .delay(0.12 + Double(index) * 0.09), value: revealed)
                    }
                }
                .padding(.top, look.space.section)
                Button("Change preferences", action: actions.changePreferences)
                    .buttonStyle(.lookSecondary)
                    .padding(.top, 20)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 24)
        }
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            // PROPOSED: Back returns to Equipment with the week kept until Generate runs again.
            AITopBar(backLabel: "Equipment", step: 2, onBack: { leave(closing: false) },
                     onCancel: { leave(closing: true) })
        }
        .safeAreaBar(edge: .bottom) {
            AIBottomBar {
                if let error = store.ai.error {
                    Text(error)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
                AIPrimaryButton("Save templates", symbol: "square.on.square", isEnabled: !store.ai.days.isEmpty,
                                action: actions.save)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: store.ai.error)
        }
        // PROPOSED: a week edited by hand is not thrown away by one tap on Cancel.
        .confirmationDialog("Discard this week?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard Week", role: .destructive) {
                if discardLeavesFlow { actions.close() } else { actions.back() }
            }
            Button("Keep Editing", role: .cancel) {}
        }
        .onAppear {
            revealed = true
            // Capture variant "discard": a hand-edited week, Cancel tapped.
            if store.currentScreen == .a04, router.variant == "discard", !confirmsDiscard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    AIWeekEdits.edited = true
                    leave(closing: true)
                }
            }
        }
    }

    /// A hand-edited week asks first; an untouched one leaves at once (as today).
    private func leave(closing: Bool) {
        if AIWeekEdits.edited {
            discardLeavesFlow = closing
            confirmsDiscard = true
        } else if closing {
            actions.close()
        } else {
            actions.back()
        }
    }
}

// MARK: - Week summary (the bold element)

/// Sessions · Sets · Time as the look's scoreboard, over the week's working sets per family.
private struct AIWeekSummary: View {
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let rows = typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 16) {
            if let gym = store.gym(store.ai.request.gymID) {
                Label(gym.name, systemImage: look.gymSymbol)
                    .font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .padding(.bottom, -6)
            }
            let layout = rows ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            layout {
                cell("Sessions", rows: rows, first: true, hugs: true) {
                    CountUpText(store.ai.days.count, duration: 0.6)
                        .font(look.font.bigNumber).foregroundStyle(look.textPrimary)
                }
                LookDivider(vertical: !rows)
                cell("Sets", rows: rows, hugs: true) {
                    CountUpText(store.aiWeekSets, duration: 0.8)
                        .font(look.font.bigNumber).foregroundStyle(look.textPrimary)
                }
                LookDivider(vertical: !rows)
                cell("Time", rows: rows) {
                    DurationFigure(minutes: store.aiWeekMinutes, numberFont: look.font.bigNumber,
                                   unitFont: .system(.footnote, weight: .bold),
                                   numberColor: look.textPrimary, unitColor: look.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            LookDivider()
            families
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .lookSurface(.panel)
    }

    @ViewBuilder private var families: some View {
        let counts = store.aiWeekFamilyCounts
        switch look.id {
        case .floodlight:
            FamilyTallyGroup(counts: counts, mapSize: 50, showsNames: false, appearDelay: 0.35, stagger: 0.07)
        case .anatomy:
            if typeSize.isAccessibilitySize {
                axRows(counts)
            } else {
                FamilyTallyGroup(counts: counts, mapSize: 56, appearDelay: 0.3, stagger: 0.09, spacing: 0)
            }
        case .paper, .carbon:
            if typeSize.isAccessibilitySize {
                axRows(counts)
            } else {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(counts) { count in
                        VStack(spacing: 6) {
                            FamilySticker(family: count.family, lit: count.sets > 0, size: 50)
                            Text("\(count.sets)")
                                .font(look.font.smallNumber)
                                .foregroundStyle(count.sets > 0 ? look.textPrimary : look.textSecondary)
                            Text(count.family.label)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(look.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(count.family.label), \(count.sets) sets")
                    }
                }
            }
        }
    }

    /// Accessibility sizes (B, C): one row per family — map · name · "{n} sets" — the same words
    /// as at default size (planned sets have no warmups, so "working" would add nothing).
    private func axRows(_ counts: [FamilyCount]) -> some View {
        VStack(spacing: 8) {
            ForEach(counts) { count in
                HStack(spacing: 12) {
                    FamilySticker(family: count.family, lit: count.sets > 0, size: 44)
                    Text(count.family.label)
                        .font(look.font.body)
                        .foregroundStyle(look.textPrimary)
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(count.sets)").font(look.font.smallNumber)
                        Text(count.sets.aiPlural("set")).font(look.font.footnote).foregroundStyle(look.textSecondary)
                    }
                    .foregroundStyle(count.sets > 0 ? look.textPrimary : look.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(count.family.label), \(count.sets) sets")
            }
        }
    }

    @ViewBuilder
    private func cell<V: View>(_ label: String, rows: Bool, first: Bool = false, hugs: Bool = false,
                               @ViewBuilder value: () -> V) -> some View {
        if rows {
            HStack(alignment: .firstTextBaseline) {
                value()
                Spacer(minLength: 8)
                Text(label).font(look.font.footnote).foregroundStyle(look.textSecondary)
            }
            .padding(.vertical, 8)
        } else {
            // Sessions and Sets hug their figures so "1 h 57 min" gets the room it needs.
            VStack(alignment: .leading, spacing: 2) {
                value()
                Text(label).font(look.font.footnote).foregroundStyle(look.textSecondary)
            }
            .frame(minWidth: hugs ? 64 : nil, maxWidth: hugs ? nil : .infinity, alignment: .leading)
            .fixedSize(horizontal: hugs, vertical: false)
            .padding(.leading, first ? 0 : 16)
            .padding(.trailing, hugs ? 16 : 0)
        }
    }
}

// MARK: - Day card

/// One generated session. What sets it apart leads the card: its families ordered and sized by
/// their share of the session's sets, each with its set count (A/B maps; C a washed band whose
/// segments are as wide as their share), then its figures, exercises and cardio. The whole card
/// opens the day editor.
struct AIDayCard: View {
    var day: AIRoutineDay
    var action: () -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shares = store.aiFamilyShares(of: day)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                if look.id.isPaperClub && !shares.isEmpty {
                    AIShareBand(shares: shares, height: typeSize.isAccessibilitySize ? 96 : 74)
                    Rectangle().fill(look.outline).frame(height: look.stroke.pressable)
                }
                VStack(alignment: .leading, spacing: 0) {
                    if !look.id.isPaperClub {
                        HStack(alignment: .top) {
                            AIShareMaps(shares: shares)
                            Spacer(minLength: 8)
                            editMark
                        }
                        .padding(.bottom, 12)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(day.name.aiWrapFriendly)
                            .font(look.font.cardTitle)
                            .foregroundStyle(look.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if look.id.isPaperClub {
                            Spacer(minLength: 8)
                            editMark
                        }
                    }
                    figures
                        .padding(.top, 8)
                    LookDivider()
                        .padding(.vertical, 12)
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(day.items) { item in itemRow(item) }
                    }
                    if !day.cardio.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(day.cardio) { cardio in AICardioBlock(cardio: cardio) }
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
            .lookSurface(.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit session")
    }

    private var editMark: some View {
        Image(systemName: "pencil")
            .font(.system(.footnote, weight: .bold))
            .foregroundStyle(look.textPrimary)
            .frame(width: 32, height: 32)
            .background {
                switch look.id {
                case .floodlight: Circle().fill(look.surfaceRaised)
                case .anatomy: Circle().fill(look.controlFill)
                case .paper, .carbon: Circle().strokeBorder(look.outline, lineWidth: 1.5)
                }
            }
            .accessibilityHidden(true)
    }

    private var figures: some View {
        let exercises = day.items.count
        let sets = day.setCount
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { figureViews(exercises, sets) }
            VStack(alignment: .leading, spacing: 4) { figureViews(exercises, sets) }
        }
    }

    @ViewBuilder private func figureViews(_ exercises: Int, _ sets: Int) -> some View {
        AIInlineFigure(number: exercises, label: exercises.aiPlural("exercise"), numberFont: look.font.fieldNumber)
        AIInlineFigure(number: sets, label: sets.aiPlural("set"), numberFont: look.font.fieldNumber)
        AIInlineFigure(number: day.estimatedMinutes, label: "min", numberFont: look.font.fieldNumber)
    }

    private func itemRow(_ item: AIRoutineItem) -> some View {
        let name = store.exercise(item.exerciseID)?.name ?? "Exercise"
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(name)
                .font(look.id == .anatomy ? .system(.subheadline, weight: .medium) : look.font.subhead)
                .foregroundStyle(look.textPrimary)
                .multilineTextAlignment(.leading)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text("\(item.sets) × \(item.reps)")
                .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold).monospacedDigit())
                .foregroundStyle(look.textSecondary)
        }
    }
}

/// A and B: the session's family maps, dominant first, each sized by its share of the sets
/// (the largest family at full size) with its set count under it.
struct AIShareMaps: View {
    var shares: [FamilyCount]
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var full: CGFloat = 46

    var body: some View {
        // Steps the maps down rather than squeezing a count out of the row (AX sizes).
        ViewThatFits(in: .horizontal) {
            row(scale: 1)
            row(scale: 0.8)
            row(scale: 0.62)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shares.map { "\($0.family.label) \($0.sets)" }.joined(separator: ", "))
    }

    private func row(scale: CGFloat) -> some View {
        let top = max(1, shares.map(\.sets).max() ?? 1)
        return HStack(alignment: .bottom, spacing: look.id == .anatomy ? 8 : 6) {
            ForEach(shares) { share in
                let fraction = CGFloat(share.sets) / CGFloat(top)
                VStack(spacing: 2) {
                    MuscleMap(family: share.family, lit: true, size: min(full, 64) * (0.62 + 0.38 * fraction) * scale)
                    Text("\(share.sets)")
                        .font(fraction >= 1 && shares.count > 1 && shares.contains(where: { $0.sets < top })
                              ? look.font.fieldNumber : .system(.footnote, weight: .bold).width(look.id == .floodlight ? .expanded : .standard))
                        .foregroundStyle(fraction >= 1 ? look.textPrimary : look.textSecondary)
                        .monospacedDigit()
                        .fixedSize()
                }
            }
        }
        .fixedSize()
    }
}

/// C: the washed band, one segment per family as wide as its share of the session's sets,
/// dominant first, the map centred and the set count in the corner.
struct AIShareBand: View {
    var shares: [FamilyCount]
    var height: CGFloat
    @Environment(\.look) private var look

    var body: some View {
        let total = CGFloat(max(1, shares.reduce(0) { $0 + $1.sets }))
        GeometryReader { geo in
            let rules = 1.5 * CGFloat(max(0, shares.count - 1))
            let width = geo.size.width - rules
            HStack(spacing: 0) {
                ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                    if index > 0 { Rectangle().fill(look.hairline).frame(width: 1.5) }
                    let w = width * CGFloat(share.sets) / total
                    ZStack(alignment: .bottomTrailing) {
                        MuscleMap(family: share.family, lit: true, size: max(16, min(height * 0.8, w * 0.9, 64)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text("\(share.sets)")
                            .font(.system(.caption, weight: .heavy).width(.expanded))
                            .foregroundStyle(look.textPrimary)
                            .padding(.trailing, 6)
                            .padding(.bottom, 4)
                    }
                    .frame(width: w)
                    .background(look.familyTint(share.family))
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shares.map { "\($0.family.label) \($0.sets)" }.joined(separator: ", "))
    }
}

/// A planned cardio block: activity glyph · name · minutes, on the look's inner surface.
struct AICardioBlock: View {
    var cardio: PlannedCardio
    @Environment(\.look) private var look

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.row, style: .continuous)
        HStack(spacing: 10) {
            Image(systemName: cardio.activity.aiSymbol)
                .font(.system(.body, weight: .semibold))
                .frame(width: 24)
            Text(cardio.activity.name)
                .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(cardio.minutes)").font(look.font.fieldNumber)
                Text("min").font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
            }
        }
        .foregroundStyle(look.textPrimary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            switch look.id {
            case .floodlight: shape.fill(look.surfaceRaised)
            case .anatomy: shape.fill(look.controlFill)
            case .paper, .carbon: shape.fill(look.ground)
            }
        }
        .overlay { if look.id.isPaperClub { shape.strokeBorder(look.hairline, lineWidth: 1.5) } }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Saved

/// After "Save templates": the look's status ring drawn from the week's families, the count,
/// and the new templates as tiles (tap one to open it). "Done" closes the flow.
struct AISavedStepView: View {
    var actions: AIFlowActions
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    /// A's tile title (Expanded Heavy headline) cannot hold "Day 1 — Fitness" in a half-width
    /// tile; one size down it fits on one line, so the name never splits at its dash.
    private var tileLook: Look {
        guard look.id == .floodlight else { return look }
        var copy = look
        copy.font.tileTitle = .system(.subheadline, weight: .heavy).width(.expanded)
        return copy
    }

    var body: some View {
        let templates = store.ai.savedTemplateIDs.compactMap { store.template($0) }
        let counts = store.aiWeekFamilyCounts
        // The celebration sits in the middle of the screen when it fits (no dead band above
        // Done); it scrolls from the top when it does not (AX sizes, many sessions).
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 0) {
                FinishStatusRing(segments: counts, size: 132)
                    .padding(.top, 24)
                Text("\(templates.count) \(templates.count == 1 ? "template" : "templates") saved")
                    .font(look.font.title)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
                    .accessibilityAddTraits(.isHeader)
                if let gym = store.gym(store.ai.request.gymID) {
                    Label(gym.name, systemImage: look.gymSymbol)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .padding(.top, 6)
                }
                // Two per row; an odd last tile spans the row (no empty half-row).
                let columns = typeSize.isAccessibilitySize ? 1 : 2
                Grid(horizontalSpacing: look.space.grid, verticalSpacing: look.space.grid) {
                    ForEach(Array(stride(from: 0, to: templates.count, by: columns)), id: \.self) { start in
                        GridRow(alignment: .top) {
                            ForEach(start..<min(start + columns, templates.count), id: \.self) { i in
                                let t = templates[i]
                                TemplateTile(name: t.name.aiWrapFriendly, families: store.families(ofTemplate: t.id),
                                             exercises: t.items.compactMap { store.exercise($0.exerciseID)?.name },
                                             lastDone: nil, now: store.now) { actions.openTemplate(t.id) }
                                    .gridCellColumns(columns == 2 && start + 1 >= templates.count ? 2 : 1)
                                    .environment(\.look, tileLook)
                            }
                        }
                    }
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 24)
            .frame(minHeight: geo.size.height, alignment: .center)
        }
        }
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .bottom) {
            AIBottomBar { AIPrimaryButton("Done", symbol: "checkmark", action: actions.close) }
        }
    }
}
