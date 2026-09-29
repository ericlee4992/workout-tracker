import SwiftData
import SwiftUI

/// What the picker starts: an activity, or one of the workout's planned targets (D57).
enum CardioChoice: Hashable {
    case activity(CardioActivity)
    case plan(PlannedCardio)

    static func == (a: CardioChoice, b: CardioChoice) -> Bool {
        switch (a, b) {
        case (.activity(let x), .activity(let y)): x == y
        case (.plan(let x), .plan(let y)): x.id == y.id
        default: false
        }
    }
    func hash(into hasher: inout Hasher) {
        switch self {
        case .activity(let activity): hasher.combine(activity)
        case .plan(let plan): hasher.combine(plan.id)
        }
    }

    var activity: CardioActivity {
        switch self {
        case .activity(let activity): activity
        case .plan(let plan): plan.activity
        }
    }
}

/// C01 — Choose Cardio (Floodlight ticket 12). The nine activities as tiles (Gym: six, Outdoors:
/// three), each with what was last done with it. A tap SELECTS; nothing starts until the pinned
/// Start capsule (the user's decision 1, 2026-09-28 — explicit Start, as for planned targets).
/// The workout's unstarted planned targets come first. The default choice is the first planned
/// target, else the activity done most recently; while a segment records nothing is preselected
/// (one tap on an armed Start would end it) and the consequence line sits above Start.
struct CardioActivityPicker: View {
    /// The activity recording now in this workout, if any (its tile carries the live dot).
    var recording: CardioActivity?
    /// Unstarted planned targets that can start now.
    var plans: [PlannedCardio] = []
    var select: (CardioChoice) -> Void

    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CardioSegment.startedAt, order: .reverse) private var segments: [CardioSegment]
    @State private var choice: CardioChoice?
    @State private var didSetDefault = false

    init(recording: CardioActivity? = nil, plans: [PlannedCardio] = [], select: @escaping (CardioChoice) -> Void) {
        self.recording = recording
        self.plans = plans
        self.select = select
    }

    private var endsCurrentSegment: Bool { recording != nil }

    var body: some View {
        let lastDone = CardioReadout.lastDone(in: segments)
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: look.space.section) {
                    if !plans.isEmpty {
                        VStack(alignment: .leading, spacing: look.space.header) {
                            SectionHeader("Planned cardio")
                            ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                                CardioPlanRow(plan: plan, selected: choice == .plan(plan)) { choice = .plan(plan) }
                                    .accessibilityIdentifier("cardioPlanOption.\(index)")
                            }
                        }
                    }
                    section("Gym", CardioActivity.allCases.filter { !$0.isOutdoor }, lastDone: lastDone)
                    section("Outdoors", CardioActivity.allCases.filter(\.isOutdoor), lastDone: lastDone)
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) { startBar }
        }
        .lookSheetGround()
        .sensoryFeedback(.selection, trigger: choice)
        .onAppear { setDefault(lastDone: lastDone) }
    }

    // MARK: Header

    /// Cancel · title. At accessibility sizes the title leaves the bar and becomes the first line.
    @ViewBuilder private var header: some View {
        let title = Text("Choose Cardio").foregroundStyle(look.textPrimary).accessibilityAddTraits(.isHeader)
        let cancel = GlassCapsuleButton("Cancel") { dismiss() }.accessibilityIdentifier("cardioPickerCancel")
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                cancel
                title.font(look.font.title2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, look.space.margin)
            .padding(.vertical, 14)
        } else {
            ZStack {
                title.font(look.font.navTitle).lineLimit(1).padding(.horizontal, 110)
                HStack { cancel; Spacer() }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
    }

    // MARK: Grid

    private func section(_ title: String, _ activities: [CardioActivity],
                         lastDone: [CardioActivity: CardioSegment]) -> some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader(title)
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    ForEach(activities) { tile($0, last: lastDone[$0], row: true) }
                }
            } else {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(Array(stride(from: 0, to: activities.count, by: 3)), id: \.self) { start in
                        GridRow {
                            ForEach(activities[start..<min(start + 3, activities.count)]) {
                                tile($0, last: lastDone[$0], row: false)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tile(_ activity: CardioActivity, last: CardioSegment?, row: Bool) -> some View {
        CardioActivityTile(
            activity: activity,
            lastDistance: last.flatMap { segment in
                segment.distanceMeters.map { "\(CardioFormat.distance($0, segment.unit)) \(segment.unit.rawValue)" }
            },
            lastWhen: last.map { ExerciseDates.relative($0.startedAt, now: .now) },
            recording: recording == activity,
            selected: choice == .activity(activity),
            asRow: row
        ) { choice = .activity(activity) }
        .accessibilityIdentifier("cardioActivity.\(activity.rawValue)")
    }

    // MARK: Start

    private var startBar: some View {
        let chosen = choice?.activity
        return VStack(alignment: .leading, spacing: 12) {
            if endsCurrentSegment {
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
            StartCapsule(title: chosen.map { "Start \($0.name)" } ?? "Start Cardio",
                         symbol: chosen?.symbol ?? "figure.run") { start() }
                .frame(maxWidth: .infinity)
                .disabled(choice == nil)
                .opacity(choice == nil ? 0.45 : 1)
                .accessibilityIdentifier("startSelectedCardio")
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background {
            look.groundSheet
                .overlay(alignment: .top) { LookDivider() }
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: chosen)
    }

    private func setDefault(lastDone: [CardioActivity: CardioSegment]) {
        guard !didSetDefault else { return }
        didSetDefault = true
        guard !endsCurrentSegment else { return }
        if let plan = plans.first {
            choice = .plan(plan)
        } else if let recent = lastDone.values.max(by: { $0.startedAt < $1.startedAt })?.activity {
            choice = .activity(recent)
        }
    }

    private func start() {
        guard let choice else { return }
        select(choice)
        dismiss()
    }
}

// MARK: - Tiles

private struct CardioActivityTile: View {
    var activity: CardioActivity
    var lastDistance: String?
    var lastWhen: String?
    var recording: Bool
    var selected: Bool
    var asRow: Bool
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .title3) private var disc: CGFloat = 46

    var body: some View {
        Button(action: action) {
            Group { if asRow { row } else { column } }
                .lookSurface(.tile)
                .cardioSelected(selected, radius: look.radius.tile, look: look)
                .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    /// Disc and check on top, the name (two lines reserved, so a row's names and what follows line
    /// up), what was last done, and at the foot what it records. Tiles in a row share one height.
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
            .font(.system(.subheadline, weight: .bold))
            .foregroundStyle(look.textPrimary)
            .lineLimit(asRow ? 4 : 2, reservesSpace: !asRow)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// What it records: a GPS route (outdoor) or distance, and heart rate; the live dot on the
    /// segment recording now.
    private var records: some View {
        HStack(spacing: 8) {
            Image(systemName: activity.isOutdoor ? "location.fill" : CardioFormat.distanceSymbol)
            Image(systemName: "heart.fill").foregroundStyle(look.heartRate)
            if recording { CardioPulseDot(color: look.done, size: 7) }
        }
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(look.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((activity.isOutdoor ? "Records a GPS route and heart rate" : "Records distance and heart rate")
                            + (recording ? ", recording now" : ""))
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
                .foregroundStyle(look.ground, look.selection)
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
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(look.textPrimary)
                    Text(plan.summary)
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                }
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.title3, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(look.ground, look.selection)
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

extension View {
    /// A selected tile: the selection colour as a 2 pt edge over a light tint.
    func cardioSelected(_ selected: Bool, radius: CGFloat, look: Look) -> some View {
        overlay {
            if selected {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                ZStack {
                    shape.fill(look.segmentFill.opacity(0.5))
                    shape.strokeBorder(look.selection, lineWidth: 2)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
