import SwiftUI

/// A04 "Your week" (Floodlight ticket 10): the payoff. A scoreboard of the week (sessions · sets ·
/// time) with the families it trains, then each session as its own card — its families sized by
/// their share of its sets, exercise count · sets · minutes, the exercises with sets × reps, and its
/// cardio. Tap a card to edit it (A05). "Save templates" saves every session at once (atomic).
struct AIWeekPreview: View {
    var model: AIRoutineFlowModel
    var gymName: String?
    /// Exercise id → name and muscle group (the request's options).
    var names: [UUID: String]
    var groups: [UUID: String]
    var onOpenDay: (UUID) -> Void
    /// Asks first when the week would be lost (ticket 10, decision 3).
    var onLeave: (AIRoutineLeave) -> Void
    var onSave: () -> Void
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var sessions: [AIRoutineDay] { model.routine?.sessions ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AIWeekSummary(sessions: sessions, gymName: gymName, groups: groups)
                    .padding(.top, 14)
                VStack(spacing: 12) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, day in
                        AIDayCard(day: day, names: names, groups: groups) { onOpenDay(day.id) }
                            .accessibilityIdentifier("routineDay.\(index)")
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed || reduceMotion ? 0 : 28)
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82)
                                .delay(0.12 + Double(index) * 0.09), value: revealed)
                    }
                }
                .padding(.top, look.space.section)
                Button("Change preferences") { onLeave(.changePreferences) }
                    .buttonStyle(.lookSecondary)
                    .padding(.top, 20)
                    .accessibilityIdentifier("routineChangePreferences")
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 24)
        }
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            AITopBar(backLabel: "Equipment", step: 2, onBack: { onLeave(.back) }, onCancel: { onLeave(.close) })
        }
        .safeAreaBar(edge: .bottom) {
            AIBottomBar {
                if let error = model.error {
                    Text(error)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                        .accessibilityIdentifier("routineAIError")
                }
                AIPrimaryButton("Save templates", symbol: "square.on.square", isEnabled: !sessions.isEmpty && !model.saving,
                                identifier: "saveAIRoutine", action: onSave)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.error)
        }
        .onAppear { revealed = true }
    }
}

/// What a discard confirmation leads to.
enum AIRoutineLeave {
    case close, back, changePreferences
}

// MARK: - Week summary (the bold element)

/// Sessions · Sets · Time as the scoreboard, over the week's sets per family.
private struct AIWeekSummary: View {
    var sessions: [AIRoutineDay]
    var gymName: String?
    var groups: [UUID: String]
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let rows = typeSize.isAccessibilitySize
        let sets = sessions.reduce(0) { $0 + AIRoutineReadouts.sets(of: $1) }
        let minutes = sessions.reduce(0) { $0 + AIRoutineReadouts.minutes(of: $1) }
        VStack(alignment: .leading, spacing: 16) {
            if let gymName {
                Label(gymName, systemImage: look.gymSymbol)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .padding(.bottom, -6)
            }
            let layout = rows ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            layout {
                cell("Sessions", rows: rows, first: true, hugs: true) {
                    CountUpText(sessions.count, duration: 0.6)
                        .font(look.font.bigNumber).foregroundStyle(look.textPrimary)
                }
                LookDivider(vertical: !rows)
                cell("Sets", rows: rows, hugs: true) {
                    CountUpText(sets, duration: 0.8)
                        .font(look.font.bigNumber).foregroundStyle(look.textPrimary)
                }
                LookDivider(vertical: !rows)
                cell("Time", rows: rows) {
                    DurationFigure(minutes: minutes, numberFont: look.font.bigNumber,
                                   unitFont: .system(.footnote, weight: .bold),
                                   numberColor: look.textPrimary, unitColor: look.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            LookDivider()
            FamilyTallyGroup(counts: AIRoutineReadouts.weekFamilyCounts(sessions, groups: groups),
                             mapSize: 50, showsNames: false, appearDelay: 0.35, stagger: 0.07)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .lookSurface(.panel)
        .accessibilityIdentifier("routineWeekSummary")
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

/// One generated session. Its families lead the card, ordered and sized by their share of its sets,
/// each with its set count; then its figures, exercises and cardio. The whole card opens the editor.
struct AIDayCard: View {
    var day: AIRoutineDay
    var names: [UUID: String]
    var groups: [UUID: String]
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shares = AIRoutineReadouts.familyShares(of: day, groups: groups)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    AIShareMaps(shares: shares)
                    Spacer(minLength: 8)
                    Image(systemName: "pencil")
                        .font(.system(.footnote, weight: .bold))
                        .foregroundStyle(look.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(look.surfaceRaised, in: Circle())
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 12)
                Text(day.name.aiWrapFriendly)
                    .font(look.font.cardTitle)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                figures.padding(.top, 8)
                LookDivider().padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(day.strength) { itemRow($0) }
                }
                if !day.cardio.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(day.cardio) { AICardioBlock(activity: $0.activity, minutes: $0.minutes) }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.tile)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit session")
    }

    private var figures: some View {
        let exercises = day.strength.count
        let sets = AIRoutineReadouts.sets(of: day)
        let minutes = AIRoutineReadouts.minutes(of: day)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { figureViews(exercises, sets, minutes) }
            VStack(alignment: .leading, spacing: 4) { figureViews(exercises, sets, minutes) }
        }
    }

    @ViewBuilder private func figureViews(_ exercises: Int, _ sets: Int, _ minutes: Int) -> some View {
        AIInlineFigure(number: exercises, label: exercises.aiPlural("exercise"), numberFont: look.font.fieldNumber)
        AIInlineFigure(number: sets, label: sets.aiPlural("set"), numberFont: look.font.fieldNumber)
        AIInlineFigure(number: minutes, label: "min", numberFont: look.font.fieldNumber)
    }

    private func itemRow(_ item: AIRoutineStrength) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(names[item.exerciseID] ?? "Exercise")
                .font(look.font.subhead)
                .foregroundStyle(look.textPrimary)
                .multilineTextAlignment(.leading)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text("\(item.sets) × \(item.reps)")
                .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(look.textSecondary)
        }
    }
}

/// The session's family maps, dominant first, each sized by its share of the sets (the largest at
/// full size) with its set count under it.
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
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(shares) { share in
                let fraction = CGFloat(share.sets) / CGFloat(top)
                VStack(spacing: 2) {
                    MuscleMap(family: share.family, lit: true, size: min(full, 64) * (0.62 + 0.38 * fraction) * scale)
                    Text("\(share.sets)")
                        .font(fraction >= 1 && shares.contains(where: { $0.sets < top })
                              ? look.font.fieldNumber : Font.system(.footnote, weight: .bold).width(.expanded))
                        .foregroundStyle(fraction >= 1 ? look.textPrimary : look.textSecondary)
                        .monospacedDigit()
                        .fixedSize()
                }
            }
        }
        .fixedSize()
    }
}

/// A planned cardio block: activity glyph · name · minutes, on the raised inner surface.
struct AICardioBlock: View {
    var activity: CardioActivity
    var minutes: Int
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: activity.aiSymbol)
                .font(.system(.body, weight: .semibold))
                .frame(width: 24)
            Text(activity.name).font(.system(.subheadline, weight: .semibold))
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(minutes)").font(look.font.fieldNumber)
                Text("min").font(.system(.caption, weight: .semibold)).foregroundStyle(look.textSecondary)
            }
        }
        .foregroundStyle(look.textPrimary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(look.surfaceRaised, in: RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Saved

/// After "Save templates" (ticket 10, decision 2): the week's family ring, the count, and the new
/// templates as tiles (tap one: the flow closes and that template opens). "Done" closes the flow.
struct AISavedStep: View {
    var templates: [WorkoutTemplate]
    var runs: [RingRun]
    var gymName: String?
    var onOpenTemplate: (WorkoutTemplate) -> Void
    var onDone: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The tile title (Expanded Heavy headline) cannot hold "Day 1 — Fitness" in a half-width
    /// tile; one size down it fits, so the name never splits at its dash.
    private var tileLook: Look {
        var copy = look
        copy.font.tileTitle = Font.system(.subheadline, weight: .heavy).width(.expanded)
        return copy
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    FinishStatusRing(segments: runs, size: 132)
                        .padding(.top, 24)
                    Text("\(templates.count) \(templates.count == 1 ? "template" : "templates") saved")
                        .font(look.font.title)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 22)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("routineSavedTitle")
                    if let gymName {
                        Label(gymName, systemImage: look.gymSymbol)
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                            .padding(.top, 6)
                    }
                    // Two per row; an odd last tile spans the row.
                    let columns = typeSize.isAccessibilitySize ? 1 : 2
                    Grid(horizontalSpacing: look.space.grid, verticalSpacing: look.space.grid) {
                        ForEach(Array(stride(from: 0, to: templates.count, by: columns)), id: \.self) { start in
                            GridRow(alignment: .top) {
                                ForEach(start..<min(start + columns, templates.count), id: \.self) { i in
                                    tile(templates[i])
                                        .gridCellColumns(columns == 2 && start + 1 >= templates.count ? 2 : 1)
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
            AIBottomBar { AIPrimaryButton("Done", symbol: "checkmark", identifier: "routineSavedDone", action: onDone) }
        }
    }

    private func tile(_ template: WorkoutTemplate) -> some View {
        let items = WorkoutTemplateService.orderedItems(of: template)
        let names = items.compactMap { $0.exercise?.name } + template.plannedCardio.map { $0.activity.name }
        return TemplateTile(name: template.name.aiWrapFriendly,
                            families: MuscleFamily.families(of: items.map { $0.exercise?.muscleGroup }),
                            exercises: names, lastDone: nil, now: .now) { onOpenTemplate(template) }
            .environment(\.look, tileLook)
            .accessibilityIdentifier("routineSavedTemplate.\(template.name)")
    }
}
