import SwiftData
import SwiftUI

// Pieces of the live workout screen (Floodlight redesign; the prototype's Screens/Live). The
// kept skeleton (ticket 16): gym · clock with seconds · N/M sets on one line, then the vitals,
// the exercise cards, the add block, and the rest slab at the thumb.

// MARK: - Header line

/// Gym · clock with seconds · N/M sets ring on ONE line. Past an hour the clock steps down a
/// size, then the word "sets" goes, before anything wraps. AX sizes: two lines (gym, then clock
/// and ring). The ring's fraction equals the count (ticket 18).
struct LiveHeaderLine: View {
    var gym: String
    var startedAt: Date
    var done: Int
    var total: Int
    var showsSets: Bool
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
            let elapsed = max(0, Int(timeline.date.timeIntervalSince(startedAt)))
            if typeSize.isAccessibilitySize {
                twoLines(elapsed)
            } else {
                ViewThatFits(in: .horizontal) {
                    line(elapsed, clockFont: look.font.timer, word: true)
                    line(elapsed, clockFont: look.font.statNumber, word: true)
                    line(elapsed, clockFont: look.font.statNumber, word: false)
                    twoLines(elapsed)
                }
            }
        }
    }

    private func line(_ elapsed: Int, clockFont: Font, word: Bool) -> some View {
        HStack(spacing: 8) {
            LiveGymTag(name: gym).fixedSize()
            clock(elapsed, font: clockFont).fixedSize()
            Spacer(minLength: 4)
            if showsSets { sets(word: word).fixedSize() }
        }
    }

    private func twoLines(_ elapsed: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveGymTag(name: gym)
            HStack {
                clock(elapsed, font: look.font.timer)
                Spacer(minLength: 8)
                if showsSets { sets(word: true) }
            }
        }
    }

    private func clock(_ elapsed: Int, font: Font) -> some View {
        Text(LookFormat.elapsed(elapsed))
            .font(font)
            .foregroundStyle(look.textPrimary)
            .contentTransition(.numericText(countsDown: false))
            .lineLimit(1)
            .accessibilityLabel("Elapsed \(LookFormat.spokenElapsed(elapsed))")
    }

    private func sets(word: Bool) -> some View {
        HStack(spacing: 7) {
            SetsRing(done: done, total: total)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(done)/\(total)")
                    .font(Font.system(.headline, weight: .heavy).width(.expanded).monospacedDigit())
                    .foregroundStyle(look.textPrimary)
                    .contentTransition(.numericText(value: Double(done)))
                    .celebrate(done)
                if word { Text("sets").font(look.font.subhead).foregroundStyle(look.textSecondary) }
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) completed sets, \(total) total")
    }
}

/// The gym as a label (it opens nothing): pin · name in a soft-ruled capsule.
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

// MARK: - Vitals

/// Heart rate · Active calories · Total volume in one strip (D41). Missing facts are absent,
/// never 0. Under it, one quiet line keeps what the old heart-rate bar said: the SOURCE of the
/// number (always named — an unattributed number invites trust the user cannot check), how
/// stale it is, and the way into zone setup (a gate that hides zones ships its own way in, D45).
/// Permission and device states render as their message instead of the heart cell.
struct LiveVitalsStrip: View {
    var monitor: HeartRateMonitor?
    /// Whether this workout records sensor activity at all (no heart cell otherwise).
    var recordsHeartRate: Bool
    /// Weighted volume so far, in `unit`.
    var volume: Double
    var unit: WeightUnit
    var editMaxHeartRate: () -> Void

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    private var liveMonitor: HeartRateMonitor? {
        guard recordsHeartRate, let monitor else { return nil }
        switch monitor.state {
        case .waitingForSensor, .live: return monitor
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if typeSize.isAccessibilitySize { rows } else { strip }
            }
            .fixedSize(horizontal: false, vertical: true)
            .lookSurface(.stat, radius: 16)
            if let liveMonitor { sourceLine(liveMonitor) }
            if recordsHeartRate, let monitor, let text = message(monitor) {
                Label(text.0, systemImage: text.1)
                    .font(look.font.caption)
                    .foregroundStyle(look.textSecondary)
                    .accessibilityIdentifier("hrMessage")
            }
        }
    }

    // MARK: Layouts

    private var strip: some View {
        HStack(spacing: 0) {
            if let liveMonitor {
                Button(action: editMaxHeartRate) { heartCell(liveMonitor) }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("Edits zones")
                LookDivider(vertical: true)
                if let calories = liveMonitor.activeEnergyKilocalories {
                    caloriesCell(calories)
                    LookDivider(vertical: true)
                }
            }
            volumeCell
        }
    }

    /// AX: heart rate on its own row, then calories and volume.
    private var rows: some View {
        VStack(spacing: 0) {
            if let liveMonitor {
                Button(action: editMaxHeartRate) { heartCell(liveMonitor) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edits zones")
                LookDivider()
                if let calories = liveMonitor.activeEnergyKilocalories {
                    caloriesCell(calories)
                    LookDivider()
                }
            }
            volumeCell
        }
    }

    // MARK: Cells

    private func heartCell(_ monitor: HeartRateMonitor) -> some View {
        let stale = monitor.isStale
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                // Not beating when stale: a pulsing heart beside a number that stopped updating
                // is the app performing liveness it does not have.
                BeatingHeart(bpm: monitor.current?.bpm, isFresh: !stale && monitor.current != nil,
                             font: .system(.footnote, weight: .bold))
                if let current = monitor.current {
                    Text("\(current.bpm)").font(look.font.smallNumber)
                        .foregroundStyle(stale ? look.textTertiary : (look.id.isPaperClub ? look.textPrimary : look.heartRate))
                        .contentTransition(.numericText(value: Double(current.bpm)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("bpm").font(unitFont).foregroundStyle(look.textSecondary)
                } else {
                    Text("Looking for a sensor…").font(look.font.footnote).foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("hrBpm")
            .accessibilityLabel(bpmSpoken(monitor))
            if let zone = stale ? nil : monitor.currentZone {
                HStack(spacing: 6) {
                    ZoneMeter(zone: zone)
                    Text(zone.label).font(labelFont).foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("hrZone")
                .accessibilityLabel("\(zone.label), \(zone.descriptionText)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caloriesCell(_ calories: Double) -> some View {
        let value = Int(calories.rounded())
        return cell(value: Text("\(value)"), unit: "cal", label: "Active calories")
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("hrCalories")
            .accessibilityLabel("\(value) active calories")
    }

    private var volumeCell: some View {
        cell(value: CountUpText(volume, countsFromZero: false) { LookFormat.grouped($0) }
                .celebrate(look.id.isPaperClub ? volume : 0),
             unit: unit.label, label: "Total volume")
            .accessibilityIdentifier("liveVolume")
    }

    private func cell<V: View>(value: V, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                value.font(look.font.smallNumber).foregroundStyle(look.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text(unit).font(unitFont).foregroundStyle(look.textSecondary)
            }
            Text(label).font(labelFont).foregroundStyle(look.textSecondary).lineLimit(1).minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Source line

    private func sourceLine(_ monitor: HeartRateMonitor) -> some View {
        HStack(spacing: 6) {
            Text(sourceLabel(monitor))
                .accessibilityIdentifier("hrSource")
            if monitor.isStale, let current = monitor.current {
                // The age, not just the word: it tells the user whether to wait or reseat an earbud.
                Text("· \(Int(current.age(asOf: .now)))s ago")
            }
            if monitor.maxHeartRate == nil {
                // No measured max and no date of birth: D45 shows no zone, and says so here —
                // the absent zone would otherwise look broken, and this is the way in.
                Button(action: editMaxHeartRate) { Text("· set up zones").underline() }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hrZoneSetup")
            } else if monitor.maxHeartRate?.isEstimated == true, monitor.currentZone != nil {
                // The zone is from 220−age; the tap goes to the field that replaces the formula.
                Button(action: editMaxHeartRate) { Text("· edit zones").underline() }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hrZoneEdit")
            }
        }
        .font(look.font.caption)
        .foregroundStyle(look.textSecondary)
        .padding(.horizontal, 4)
    }

    /// The source of the number actually on screen — read from `current`, not from the feed
    /// state, so the label can never name a different sensor than the reading (codex-review 3.3).
    private func sourceLabel(_ monitor: HeartRateMonitor) -> String {
        if let source = monitor.current?.source, !monitor.isStale { return source.label }
        if case .waitingForSensor = monitor.state {
            return monitor.current == nil ? "No sensor reporting" : "Not reporting"
        }
        return monitor.current?.source.label ?? ""
    }

    private func bpmSpoken(_ monitor: HeartRateMonitor) -> String {
        guard let current = monitor.current else { return "Looking for a sensor" }
        return monitor.isStale
            ? "\(current.bpm) beats per minute, \(Int(current.age(asOf: .now))) seconds ago"
            : "\(current.bpm) beats per minute"
    }

    private func message(_ monitor: HeartRateMonitor) -> (String, String)? {
        switch monitor.state {
        case .needsAuthorization: ("Heart rate needs permission in Health", "heart.text.square")
        case .denied: ("Heart rate is off. Turn it on in Settings › Health › Data Access.", "heart.slash")
        case .unavailable: ("This device can't measure heart rate", "heart.slash")
        default: nil
        }
    }

    private var unitFont: Font { .system(.footnote, weight: .medium) }
    private var labelFont: Font {
        look.id.isPaperClub ? .system(.caption, weight: .semibold) : .system(.footnote)
    }
}

// MARK: - Rest slab

/// The pinned rest: draining ring with its hourglass, "Rest" over the time, what is next, +15s
/// and Skip — drawn as the live workout's inverse ink slab (`RestBar`). D46: the beep and
/// notification are scheduled with the system; this only draws the countdown.
struct LiveRestSlab: View {
    var restEnd: Date
    var restTotal: Double
    var next: String?
    var addFifteen: () -> Void
    var skip: () -> Void
    var expired: () -> Void

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var now = Date()
    @Environment(\.look) private var look

    var body: some View {
        let remaining = max(0, Int(restEnd.timeIntervalSince(now).rounded(.up)))
        RestBar(remaining: remaining, total: max(1, Int(restTotal.rounded())), next: next,
                onAdd15: addFifteen, onSkip: skip)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 8)
            .onReceive(tick) { date in
                now = date
                if restEnd <= date { expired() }
            }
    }
}

// MARK: - Add block

/// Add Exercise (the filled command unless a rest is running), Add by Machine and Add Cardio.
/// D1 (ticket 17): with no gym, Add by Machine stays visible, disabled, and says why.
struct LiveAddBlock: View {
    var hasGym: Bool
    var isResting: Bool
    var cardioFocus: Bool
    var addExercise: () -> Void
    var addByMachine: () -> Void
    var addCardio: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if isResting || cardioFocus {
                    Button(action: addExercise) { peerLabel("Add Exercise", symbol: "plus") }
                        .buttonStyle(.lookSecondary)
                } else {
                    PrimaryButton("Add Exercise", symbol: "plus", action: addExercise)
                }
            }
            .accessibilityIdentifier("addExercise")
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) { peers }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { peers }
                    VStack(spacing: 10) { peers }
                }
            }
            if !hasGym {
                Text("Pick a gym to log by machine")
                    .font(look.font.caption)
                    .foregroundStyle(look.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("addByMachineUnavailable")
            }
        }
    }

    @ViewBuilder private var peers: some View {
        Button(action: addByMachine) { peerLabel("Add by Machine", symbol: LookIcon.machine) }
            .buttonStyle(.lookSecondary)
            .disabled(!hasGym)
            .opacity(hasGym ? 1 : 0.4)
            .accessibilityIdentifier("addByMachine")
        Button(action: addCardio) { peerLabel("Add Cardio", symbol: "figure.run") }
            .buttonStyle(.lookSecondary)
            .accessibilityIdentifier("addCardio")
    }

    private func peerLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            IconDisc(symbol: symbol, size: 30, context: .onSurface)
            Text(title)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
        }
        .padding(.horizontal, -12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - Empty workout: recent at this gym

/// An empty workout is not half a screen of nothing: the exercises last done at this gym,
/// newest first, each one tap from a card (the same entry Add Exercise would make).
struct LiveRecentSection: View {
    var gymName: String
    var exercises: [Exercise]
    var add: (Exercise) -> Void
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Recent at \(gymName)")
            LookList {
                ForEach(exercises) { exercise in
                    LookRow(exercise.name, symbol: "plus.circle", showsChevron: false) { add(exercise) }
                        .accessibilityIdentifier("recentExercise.\(exercise.name)")
                }
            }
        }
    }

    /// Distinct exercises from finished workouts at `gym` (by the entry's gym snapshot), newest
    /// first. Live exercise rows only: a deleted exercise cannot be added again.
    static func exercises(at gym: Gym, in context: ModelContext, limit: Int = 5) -> [Exercise] {
        let gymID = gym.id
        let finished = (try? context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt != nil },
            sortBy: [SortDescriptor(\Workout.startedAt, order: .reverse)]))) ?? []
        var seen = Set<UUID>()
        var result: [Exercise] = []
        for workout in finished {
            for entry in WorkoutSession.orderedEntries(of: workout) where entry.snapshotGymID == gymID {
                guard let exercise = entry.exercise, seen.insert(exercise.id).inserted else { continue }
                result.append(exercise)
                if result.count == limit { return result }
            }
        }
        return result
    }
}
