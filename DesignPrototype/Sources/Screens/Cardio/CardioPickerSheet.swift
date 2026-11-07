import SwiftUI

// C01 — Choose Cardio. The nine Apple-Fitness-aligned activities as a 3 × 3 grid of tiles
// (Gym: 6, Outdoors: 3), each with its figure and what you last did with it. A tap SELECTS;
// nothing starts until the explicit Start capsule (the user's icon-disc pattern) is pressed.
// Today's planned target (from the template) sits first when one has not started yet.
// While a segment is recording, the one consequence line sits right above Start and nothing is
// preselected (one tap on an armed Start would end the running segment).
// View-level variants: "replace" previews that line without a session; "planned" opens it over
// Push Day with its 20-min Indoor Run target pending; "p2"/"p3" scroll to the end.

struct CardioPickerSheet: View {
    @Environment(Router.self) private var router
    @Environment(Store.self) private var store

    var body: some View {
        CardioPickerContent()
            .modifier(CardioTypeOverride(size: router.dynamicTypeOverride))
            .environment(\.cardioStill, store.freezeClock)
    }
}

private struct CardioPickerContent: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var choice: Choice?
    @State private var didSetDefault = false

    enum Choice: Hashable {
        case plan(UUID)
        case activity(CardioActivity)
    }

    private static let bottomID = "cardioPicker.bottom"

    private var gym: [CardioActivity] { CardioActivity.allCases.filter { !$0.isOutdoor } }
    private var outdoors: [CardioActivity] { CardioActivity.allCases.filter(\.isOutdoor) }

    var body: some View {
        let plans = store.cardioPendingPlans
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: look.space.section) {
                        if !plans.isEmpty {
                            VStack(alignment: .leading, spacing: look.space.header) {
                                SectionHeader("Planned cardio")
                                ForEach(plans) { plan in
                                    CardioPlanRow(plan: plan, selected: choice == .plan(plan.id)) { select(.plan(plan.id)) }
                                }
                            }
                        }
                        section("Gym", gym)
                        section("Outdoors", outdoors)
                        Color.clear.frame(height: 1).id(Self.bottomID)
                    }
                    .padding(.horizontal, look.space.margin)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard let v = router.variant, v == "p2" || v == "p3" else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { startBar }
        }
        .lookSheetGround()
        .sensoryFeedback(.selection, trigger: choice)
        .onAppear {
            if CardioVariants.tokens(router.variant).contains("planned"), store.session == nil,
               CardioVariants.claim("picker.planned") {
                store.reset(to: .l01)
            }
            setDefault()
        }
    }

    // MARK: Header

    /// Cancel · title. At AX sizes the title leaves the bar and becomes the first line (never truncated).
    @ViewBuilder private var header: some View {
        let title = Text("Choose Cardio")
            .foregroundStyle(look.textPrimary)
            .accessibilityAddTraits(.isHeader)
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                GlassCapsuleButton("Cancel") { router.dismissSheet() }
                title.font(look.font.title2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
            .padding(.bottom, 14)
        } else {
            ZStack {
                title.font(look.font.navTitle)
                    .lineLimit(1)
                    .padding(.horizontal, 110)
                HStack {
                    GlassCapsuleButton("Cancel") { router.dismissSheet() }
                    Spacer()
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
    }

    // MARK: Grid

    private func section(_ title: String, _ activities: [CardioActivity]) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(title)
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    ForEach(activities) { tile($0, row: true) }
                }
            } else {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(Array(stride(from: 0, to: activities.count, by: 3)), id: \.self) { start in
                        GridRow {
                            ForEach(activities[start..<min(start + 3, activities.count)]) { tile($0, row: false) }
                        }
                    }
                }
            }
        }
    }

    private func tile(_ activity: CardioActivity, row: Bool) -> some View {
        let last = store.cardioLastDone(activity)
        return CardioActivityTile(
            activity: activity,
            lastDistance: last.flatMap { l in l.segment.distanceMeters.map { Format.distanceLabel(meters: $0, l.segment.unit) } },
            lastWhen: last.map { look.lastDoneLabel($0.date, now: store.now) },
            recording: store.session?.unfinishedCardio?.activity == activity,
            selected: choice == .activity(activity),
            asRow: row
        ) { select(.activity(activity)) }
    }

    // MARK: Start

    private var chosenActivity: CardioActivity? {
        switch choice {
        case .plan(let id): store.session?.plannedCardio.first { $0.id == id }?.activity
        case .activity(let a): a
        case nil: nil
        }
    }

    private var showsReplaceLine: Bool {
        store.session?.unfinishedCardio != nil || router.variant == "replace"
    }

    private var startBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsReplaceLine {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(look.textPrimary)
                    Text("Starting another activity ends the current cardio segment.")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            StartCapsule(title: chosenActivity.map { "Start \($0.name)" } ?? "Start Cardio",
                         symbol: chosenActivity?.symbol ?? "figure.run") { start() }
                .frame(maxWidth: .infinity)
                .disabled(chosenActivity == nil)
                .opacity(chosenActivity == nil ? 0.45 : 1)
                .id(chosenActivity)
                .transition(.opacity)
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background {
            look.groundSheet
                .overlay(alignment: .top) { LookDivider() }
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(.snappy(duration: 0.2), value: chosenActivity)
    }

    private func select(_ new: Choice) {
        choice = new
    }

    /// Preselect today's unstarted target, else the activity done most recently (still an
    /// explicit Start away). While a segment records, nothing is preselected.
    private func setDefault() {
        guard !didSetDefault else { return }
        didSetDefault = true
        guard !showsReplaceLine else { return }
        if let plan = store.cardioPendingPlans.first {
            choice = .plan(plan.id)
        } else if let recent = store.history.lazy.compactMap({ $0.cardio.last?.activity }).first {
            choice = .activity(recent)
        }
    }

    private func start() {
        guard let choice else { return }
        let coverUp = store.session != nil && store.isSessionPresented
        router.dismissSheet()
        let begin = {
            switch choice {
            case .plan(let id): store.startPlannedCardio(id)
            case .activity(let activity): store.startCardio(activity: activity)
            }
        }
        // From Home the live cover rises after the sheet has gone; over the cover it starts at once.
        if coverUp { begin() } else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { begin() } }
    }
}

// MARK: - Tiles

private struct CardioActivityTile: View {
    var activity: CardioActivity
    var lastDistance: String?
    var lastWhen: String?
    /// This activity is the segment recording now.
    var recording = false
    var selected: Bool
    var asRow: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .title3) private var disc: CGFloat = 46

    var body: some View {
        Button(action: action) {
            Group {
                if asRow { row } else { column }
            }
            .lookSurface(.tile)
            .cardioSelected(selected, radius: look.radius.tile, look: look)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    /// Disc and check on top, the name right under the disc (every name reserves two lines, so
    /// names and what follows line up across a row), what you last did with it, and at the foot
    /// what it records. Tiles in a row share one height (Grid).
    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                CardioActivityDisc(symbol: activity.symbol, size: disc)
                Spacer(minLength: 2)
                check
            }
            name.padding(.top, 12)
            lastLines.padding(.top, 4)
            Spacer(minLength: 10)
            records
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var row: some View {
        HStack(spacing: 14) {
            CardioActivityDisc(symbol: activity.symbol, size: disc)
            VStack(alignment: .leading, spacing: 3) {
                name
                lastLines
                records.padding(.top, 2)
            }
            Spacer(minLength: 4)
            check
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var name: some View {
        Text(activity.name)
            .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
            .foregroundStyle(look.textPrimary)
            .lineLimit(asRow ? 4 : 2, reservesSpace: !asRow)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// What the activity records, as glyphs: GPS route (outdoor) or distance from the phone's
    /// sensors (indoor), heart rate, and — for the segment running now — the recording dot.
    private var records: some View {
        HStack(spacing: 8) {
            Image(systemName: activity.isOutdoor ? "location.fill" : CardioStat.distanceSymbol)
            Image(systemName: "heart.fill").foregroundStyle(look.heartRate)
            if recording {
                CardioPulseDot(color: look.cardioLive, size: 7, ripple: 0.9)
            }
        }
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(look.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activity.isOutdoor ? "Records a GPS route and heart rate" : "Records distance and heart rate")
    }

    @ViewBuilder private var lastLines: some View {
        if let lastDistance {
            Text(lastDistance)
                .font(.system(.caption, weight: .bold).monospacedDigit())
                .foregroundStyle(look.textPrimary)
        }
        if let lastWhen {
            HStack(spacing: 3) {
                Image(systemName: "clock.arrow.circlepath").font(.system(.caption2, weight: .semibold))
                Text(lastWhen).lineLimit(1).minimumScaleFactor(0.85)
            }
            .font(.caption)
            .foregroundStyle(look.textSecondary)
        }
    }

    @ViewBuilder private var check: some View {
        if selected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.title3, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(look.id.isPaperClub ? Color.white : look.ground, look.selection)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

private struct CardioPlanRow: View {
    var plan: PlannedCardio
    var selected: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .title3) private var disc: CGFloat = 46

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CardioActivityDisc(symbol: plan.activity.symbol, size: disc)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.activity.name)
                        .font(.system(.headline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
                        .foregroundStyle(look.textPrimary)
                    Text(CardioFormat.plan(plan))
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.title3, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(look.id.isPaperClub ? Color.white : look.ground, look.selection)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookSurface(.tile)
            .cardioSelected(selected, radius: look.radius.tile, look: look)
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
