import SwiftUI

// PROTOTYPE — the live screen's own versions of the kept skeleton pieces: the glass top bar,
// the header line (gym · clock with seconds · N/M sets), the vitals strip, the exercise card's
// title line and its equipment row. They follow the foundation components (LivePieces) and add
// the review fixes the foundation does not have yet (promote them):
// - the gym is a label, not a button (the real app's chip is not tappable);
// - the header stays on one line past an hour (the clock steps down a size, then "sets" goes);
// - AX vitals: heart rate on its own row, then Active calories | Total volume side by side, so
//   the header and vitals stay near a third of the screen (the next set shows above the slab);
// - A's sets ring counts at a glance (LiveSetsRing) and A's card buttons sit in discs;
// - B's zone meter is five equal steps rising in lightness (no signal-strength bars);
// - AX card titles keep the chart and "…" buttons beside their first line in every look;
// - the equipment row's model line wraps instead of truncating.

// MARK: - Top bar

/// Glass chrome over the list: minimise (+ Cancel in A and B, one glass capsule) · the workout
/// name with its pencil (tap to rename) · Finish. At AX sizes the name moves into the list.
struct LiveCoverTopBar: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 8) {
            leading.layoutPriority(1)
            Spacer(minLength: 4)
            if !typeSize.isAccessibilitySize {
                Button {
                    model.beginRename(store: store)
                } label: {
                    HStack(spacing: 6) {
                        Text(store.sessionTitle).font(look.font.navTitle).lineLimit(1).minimumScaleFactor(0.8)
                        Image(systemName: "pencil").font(.system(.caption, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                    }
                    .foregroundStyle(look.textPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel(store.sessionTitle)
                .accessibilityHint("Edits the workout name")
                Spacer(minLength: 4)
            }
            if model.reordering {
                GlassCapsuleButton("Done") {
                    withAnimation(.snappy) { model.reordering = false }
                }
                .layoutPriority(1)
            } else if !Proposal.shared.finishAtBottom {
                GlassCapsuleButton("Finish") { model.finishTapped(store: store, router: router) }
                    .layoutPriority(1)
            } else {
                // PROPOSAL: Finish lives at the thumb (the bottom bar); this keeps the title centred.
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.bottom, 6)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { model.topBarBottom = $0 }
    }

    /// As shipped (the user's 2026-10-10 choice): minimise + a red Cancel at the top left.
    @ViewBuilder private var leading: some View {
        LiveMinimiseCancelGroup(onMinimise: minimise) {
            model.endEditing()
            model.confirmDiscard = true
        }
    }

    private func minimise() {
        model.endEditing()
        model.closeMenu()
        store.minimise()
    }
}

/// A §13 / B §10: minimise and Cancel share ONE glass capsule (iOS 26 groups adjacent bar
/// items), split by a hairline. A's Cancel is danger red-orange; B's has no hue.
private struct LiveMinimiseCancelGroup: View {
    var onMinimise: () -> Void
    var onCancel: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onMinimise) {
                Image(systemName: "chevron.down")
                    .font(.system(.body, weight: .semibold))
                    .imageScale(.large)
                    .foregroundStyle(look.textPrimary)
                    .frame(width: height + 2, height: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Minimize workout")
            .accessibilityShowsLargeContentViewer { Label("Minimize workout", systemImage: "chevron.down") }
            Rectangle().fill(look.textPrimary.opacity(0.16)).frame(width: 1, height: height * 0.45)
            Button(action: onCancel) {
                Text("Cancel")
                    .font(look.id == .anatomy ? look.font.button : .system(.body, weight: .semibold))
                    .foregroundStyle(look.destructive)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 14).padding(.trailing, 18)
                    .frame(minHeight: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Discards this workout")
            .accessibilityShowsLargeContentViewer { Text("Cancel") }
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// At AX sizes the workout name leaves the bar and joins the header, which packs into two lines
/// when it can — the name and the clock, then the gym and N/M sets — so the header and vitals stay
/// near a third of the screen. When a long name (or a very large size) cannot share a line, it
/// takes its own line and the header follows as before: clock and sets, then the gym.
struct LiveAXHeader: View {
    var gym: String
    var elapsed: Int
    var done: Int
    var total: Int
    var showsSets = true
    @Environment(\.look) private var look

    var body: some View {
        ViewThatFits(in: .horizontal) {
            packed(clockFont: look.font.timer)
            // A's wide Expanded faces: the clock steps down one size before the name moves out.
            packed(clockFont: look.font.statNumber)
            VStack(alignment: .leading, spacing: 8) {
                LiveTitleButton().frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    clock(look.font.timer)
                    Spacer(minLength: 8)
                    if showsSets { LiveSetsRingLabel(done: done, total: total, showsWord: true) }
                }
                LiveGymTag(name: gym)
            }
        }
    }

    private func packed(clockFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                LiveTitleButton().fixedSize()
                Spacer(minLength: 8)
                clock(clockFont).fixedSize()
            }
            HStack(spacing: 10) {
                LiveGymTag(name: gym).fixedSize()
                Spacer(minLength: 8)
                if showsSets { LiveSetsRingLabel(done: done, total: total, showsWord: true).fixedSize() }
            }
        }
    }

    private func clock(_ font: Font) -> some View {
        Text(Format.elapsed(elapsed))
            .font(font)
            .foregroundStyle(look.textPrimary)
            .contentTransition(.numericText(countsDown: false))
            .lineLimit(1)
            .accessibilityLabel("Elapsed \(Format.spokenElapsed(elapsed))")
    }
}

/// The workout name with its pencil (tap to rename), as a list line at AX sizes.
struct LiveTitleButton: View {
    @Environment(Store.self) private var store
    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look

    var body: some View {
        Button { model.beginRename(store: store) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.sessionTitle).font(look.font.title2).foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.leading)
                Image(systemName: "pencil").font(.body.weight(.semibold)).foregroundStyle(look.textSecondary)
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint("Edits the workout name")
    }
}

// MARK: - Header line

/// Gym · clock with seconds · N/M sets on ONE line. Past an hour the clock steps down one size,
/// then the word "sets" goes, before anything wraps. AX: two lines (A the gym first; B and C the
/// clock and ring first, as their SPECs say).
struct LiveHeaderBar: View {
    var gym: String
    var elapsed: Int
    var done: Int
    var total: Int
    var showsSets = true
    /// AX sizes: false when the title row above already carries the gym.
    var showsGym = true
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            twoLines
        } else {
            ViewThatFits(in: .horizontal) {
                line(clockFont: look.font.timer, word: true)
                line(clockFont: look.font.statNumber, word: true)
                line(clockFont: look.font.statNumber, word: false)
                twoLines
            }
        }
    }

    private func line(clockFont: Font, word: Bool) -> some View {
        HStack(spacing: 8) {
            LiveGymTag(name: gym).fixedSize()
            clock(clockFont).fixedSize()
            Spacer(minLength: 4)
            if showsSets { LiveSetsRingLabel(done: done, total: total, showsWord: word).fixedSize() }
        }
    }

    private var twoLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsGym && look.id == .floodlight { LiveGymTag(name: gym) }
            HStack {
                clock(look.font.timer)
                Spacer(minLength: 8)
                if showsSets { LiveSetsRingLabel(done: done, total: total, showsWord: true) }
            }
            if showsGym && look.id != .floodlight { LiveGymTag(name: gym) }
        }
    }

    private func clock(_ font: Font) -> some View {
        Text(Format.elapsed(elapsed))
            .font(font)
            .foregroundStyle(look.textPrimary)
            .contentTransition(.numericText(countsDown: false))
            .lineLimit(1)
            .accessibilityLabel("Elapsed \(Format.spokenElapsed(elapsed))")
    }
}

/// The gym as a label (not a button: the chip opens nothing). C draws it as information — a soft
/// rule — so it never wears the "you can press this" outline.
struct LiveGymTag: View {
    var name: String
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: look.gymSymbol)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
            Text(name)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: height)
        .background(look.id.isPaperClub ? look.surface : look.chipFill, in: Capsule())
        .overlay { Capsule().strokeBorder(look.hairline, lineWidth: look.id.isPaperClub ? 1.5 : 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gym, \(name)")
    }
}

/// "7/18 sets" beside its ring. `showsWord: false` drops "sets" when the line is tight.
struct LiveSetsRingLabel: View {
    var done: Int
    var total: Int
    var showsWord = true
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 7) {
            LiveSetsRing(done: done, total: total)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(done)/\(total)")
                    .font(numberFont)
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: Double(done)))
                    .celebrate(done)
                if showsWord {
                    Text("sets").font(look.font.subhead).foregroundStyle(look.textSecondary)
                }
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) sets")
    }

    private var numberFont: Font {
        switch look.id {
        case .floodlight, .paper, .carbon: Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit()
        case .anatomy: .system(.title3, design: .rounded, weight: .heavy).monospacedDigit()
        }
    }
}

// MARK: - Vitals

/// Heart rate · Active calories · Total volume in one strip. Missing facts are absent, never 0.
/// AX sizes: heart rate on one row; calories and volume share the next row (each ≥ 44 pt).
struct LiveVitals: View {
    var hr: Int?
    var zone: HeartRateZone?
    var isStale = false
    var staleSeconds: Int?
    var activeCal: Int?
    var volume: Double
    var unit: WeightUnit
    var onHeartRate: () -> Void

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { rows } else { strip }
        }
        .fixedSize(horizontal: false, vertical: true)
        .lookSurface(.stat, radius: look.id == .anatomy ? 20 : 16)
    }

    // MARK: Default: one strip

    private var strip: some View {
        HStack(spacing: 0) {
            if let hr {
                Button(action: onHeartRate) { heartCell(hr) }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("Edits zones")
                LookDivider(vertical: true)
            }
            if let activeCal {
                cell(value: { Text("\(activeCal)") }, unit: "cal", label: "Active calories")
                LookDivider(vertical: true)
            }
            cell(value: { volumeText }, unit: unit.label, label: "Total volume")
        }
    }

    private func heartCell(_ hr: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                BeatingHeart(bpm: hr, isFresh: !isStale, font: .system(.footnote, weight: .bold))
                Text("\(hr)").font(vitalsFont).foregroundStyle(heartValueColor)
                    .contentTransition(.numericText(value: Double(hr)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("bpm").font(unitFont).foregroundStyle(look.textSecondary)
            }
            HStack(spacing: 6) {
                LiveZoneMeter(zone: isStale ? nil : zone)
                ViewThatFits(in: .horizontal) {
                    zoneText(zoneLine)
                    if let staleAge { zoneText(staleAge) }
                }
            }
        }
        .padding(.horizontal, look.id.isPaperClub ? 12 : 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heartSpoken(hr))
    }

    private func cell<V: View>(@ViewBuilder value: () -> V, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                value().font(vitalsFont).foregroundStyle(look.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text(unit).font(unitFont).foregroundStyle(look.textSecondary)
            }
            Text(label)
                .font(labelFont)
                .foregroundStyle(look.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, look.id.isPaperClub ? 12 : 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: AX: rows

    private var rows: some View {
        VStack(spacing: 0) {
            if let hr {
                Button(action: onHeartRate) {
                    row(value: {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            BeatingHeart(bpm: hr, isFresh: !isStale, font: .system(.footnote, weight: .bold))
                            Text("\(hr)").font(vitalsFont).foregroundStyle(heartValueColor)
                            Text("bpm").font(unitFont).foregroundStyle(look.textSecondary)
                        }
                    }, label: {
                        HStack(spacing: 6) {
                            LiveZoneMeter(zone: isStale ? nil : zone)
                            Text(zoneLine).font(labelFont).foregroundStyle(zoneLabelColor)
                        }
                    })
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(heartSpoken(hr))
                .accessibilityHint("Edits zones")
                LookDivider()
            }
            // Active calories and Total volume share one row (two halves, value over label), so
            // the header and vitals stay near a third of the screen and the next set shows.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    if let activeCal {
                        axHalf(value: "\(activeCal)", unit: "cal", label: "Active calories")
                        LookDivider(vertical: true)
                    }
                    axHalf(value: nil, unit: unit.label, label: "Total volume")
                }
                .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    if let activeCal {
                        axHalf(value: "\(activeCal)", unit: "cal", label: "Active calories")
                        LookDivider()
                    }
                    axHalf(value: nil, unit: unit.label, label: "Total volume")
                }
            }
        }
    }

    /// One AX half: the value (with its small unit) over its label. `value == nil` = the volume.
    private func axHalf(value: String?, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let value { Text(value).font(vitalsFont).foregroundStyle(look.textPrimary) } else {
                    volumeText.font(vitalsFont).foregroundStyle(look.textPrimary)
                }
                Text(unit).font(unitFont).foregroundStyle(look.textSecondary)
            }
            .lineLimit(1)
            .fixedSize()
            Text(label).font(labelFont).foregroundStyle(look.textSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Value leading, label trailing on one line; if a very large size cannot fit both, the label
    /// drops under the value rather than truncating.
    private func row<V: View, L: View>(@ViewBuilder value: () -> V, @ViewBuilder label: () -> L) -> some View {
        let v = value(), l = label()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                v.lineLimit(1).fixedSize()
                Spacer(minLength: 8)
                l.lineLimit(1).fixedSize()
            }
            VStack(alignment: .leading, spacing: 2) { v; l }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: Pieces

    private var volumeText: some View {
        // A and B count the volume up; C also bumps it (1.25×).
        CountUpText(volume, countsFromZero: false) { Format.grouped($0) }
            .celebrate(look.id.isPaperClub ? volume : 0)
    }

    private var heartValueColor: Color {
        isStale ? look.textTertiary : (look.id.isPaperClub ? look.textPrimary : look.heartRate)
    }

    private var zoneLabelColor: Color { look.id.isPaperClub ? look.textPrimary : look.textSecondary }

    private var zoneLine: String {
        let base = zone?.label ?? "Set up zones"
        if let staleAge { return "\(base) · \(staleAge)" }
        return base
    }

    /// B only: "12s ago" while the feed is stale (B SPEC §5).
    private var staleAge: String? {
        guard isStale, look.id == .anatomy, let staleSeconds else { return nil }
        return "\(staleSeconds)s ago"
    }

    private func heartSpoken(_ hr: Int) -> String {
        "Heart rate \(hr) beats per minute\(zone.map { ", \($0.label)" } ?? "")"
            + (isStale ? ", \(staleSeconds ?? 0) seconds ago" : "")
    }

    private func zoneText(_ text: String) -> some View {
        Text(text).font(labelFont).foregroundStyle(zoneLabelColor).lineLimit(1)
    }

    /// B's rounded figures fit at Title 2; the wider Expanded faces (A, C) use Title 3.
    private var vitalsFont: Font { look.id == .anatomy ? look.font.statNumber : look.font.smallNumber }

    private var unitFont: Font {
        .system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: look.id == .anatomy ? .bold : .medium)
    }

    private var labelFont: Font {
        look.id.isPaperClub ? .system(.caption, weight: .semibold) : .system(.footnote, weight: look.id == .anatomy ? .semibold : .regular)
    }
}

/// Five equal steps; the steps up to the current zone light in the zone ramp, which rises in
/// lightness (C: heart colour). Never rising bars — that reads as phone signal strength.
struct LiveZoneMeter: View {
    var zone: HeartRateZone?
    @Environment(\.look) private var look

    var body: some View {
        let level = zone?.rawValue ?? 0
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { step in
                let lit = step <= level
                switch look.id {
                case .floodlight:
                    Capsule().fill(lit ? look.zoneRamp[step] : look.ringTrack).frame(width: 8, height: 4)
                case .anatomy:
                    Capsule().fill(lit ? look.zoneRamp[step] : Color.white.opacity(0.14)).frame(width: 7, height: 5)
                case .paper, .carbon:
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(lit ? look.heartRate : look.textSecondary.opacity(0.25))
                        .frame(width: 5, height: 10)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Exercise card title line

/// The title (wraps, never truncates) with the superset letter / done chip, B's Target caption,
/// and the previous-performance and "…" buttons. Default: the buttons centre on the title block.
/// AX (every look): they stay top-trailing beside the title's first line.
struct LiveCardHeader: View {
    var entryID: UUID
    var title: String
    var subtitle: String?
    var letter: String?
    var isDone: Bool
    var onPrevious: () -> Void
    var onOptions: () -> Void

    @Environment(LiveScreenModel.self) private var model
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The centre of the title's first line (where the chip sits).
    @ScaledMetric(relativeTo: .title3) private var chipCenter: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var chipHalf: CGFloat = 12

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        HStack(alignment: ax ? .top : .center, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                if letter != nil || isDone {
                    LiveSupersetChip(letter: letter, done: isDone)
                        .padding(.top, max(0, chipCenter - chipHalf))
                        .animation(.easeOut(duration: 0.25), value: isDone)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(look.font.cardTitle)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(look.font.subhead)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: look.id.isPaperClub ? 10 : 12) {
                LiveCardIconButton(look.previousPerformanceSymbol, accessibilityLabel: "Previous performance", action: onPrevious)
                LiveCardIconButton("ellipsis", accessibilityLabel: "Options", action: onOptions)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        model.anchors[.entry(entryID)] = frame
                    }
            }
            .padding(.top, ax ? 4 : 0)
        }
    }
}

// MARK: - Equipment row

/// The machine / equipment row inside an exercise card. The model line wraps (up to three lines)
/// rather than truncating, in every look and size.
struct LiveEquipmentRow: View {
    var title: String
    var subtitle: String?
    var symbol: String
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LookIcon(symbol, style: .body)
                    .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                    .frame(width: glyphColumn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(look.id.isPaperClub ? look.font.caption : look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
            }
            .padding(.horizontal, look.id.isPaperClub ? 12 : 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: look.id.isPaperClub ? 54 : 52, alignment: .leading)
            .lookSurface(.raised)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityHint("Changes the equipment")
    }

    private var titleFont: Font {
        switch look.id {
        case .floodlight: .system(.body, weight: .semibold)
        case .anatomy: .system(.body, design: .rounded, weight: .bold)
        case .paper, .carbon: .system(.subheadline, weight: .bold)
        }
    }
}
