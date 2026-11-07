import SwiftUI
import UIKit

// PROTOTYPE — Live area helpers: the screen's transient UI state, read-only Store readouts the
// live screen needs that the Model does not offer yet, capture variants, and small shared pieces.
// Everything is area-prefixed so the integrator can promote it. Nothing here mutates the Store
// except through its public methods.

// MARK: - Screen UI state

/// Which numeric field of a set row is being typed into.
enum LiveEntryField: Hashable { case weight, reps }

struct LiveEditTarget: Hashable {
    var entryID: UUID
    var setID: UUID
    var field: LiveEntryField
}

/// What a floating menu belongs to: an exercise's "…" or a set row's marker (set type).
enum LiveMenuTarget: Hashable {
    case entry(UUID)
    case setType(entryID: UUID, setID: UUID)
}

/// An open menu and the global frame of the control it drops from.
struct LiveMenuState: Equatable {
    var target: LiveMenuTarget
    var anchor: CGRect
}

/// Where a set row sits: inside its card (to aim a scroll) and on screen (to know if it is visible).
struct LiveRowPlacement: Equatable {
    var entryID: UUID
    var midInCard: CGFloat
    var cardHeight: CGFloat
    var globalMid: CGFloat
    /// The row's own height (a two-line block at AX sizes).
    var height: CGFloat = 48
}

/// A rest that just ran out, recovered or hit the cap: the slab holds a short "done" moment.
struct LiveRestEnd: Equatable {
    var outcome: RestOutcome
    var at: Date
    /// How long the moment stays up (the clock ticks at 1 Hz).
    static let duration: TimeInterval = 3
}

/// Transient UI state of the live screen (menus, typing, dialogs). Session data lives in the Store.
@Observable
final class LiveScreenModel {
    /// The field being typed into (nil = keyboard down).
    var editing: LiveEditTarget?
    /// Keys typed since the field gained focus. "" = nothing yet, so the row keeps its value
    /// until the first key replaces it (like select-all).
    var entryText = ""
    /// The floating menu that is open ("…" or set type).
    var menu: LiveMenuState?
    /// The set row swiped open to show Delete (one at a time).
    var swipedSetID: UUID?
    /// "Delete {exercise}?" confirmation.
    var deleteEntryID: UUID?
    var renaming = false
    var renameText = ""
    var confirmDiscard = false
    var confirmFinish = false
    /// Reorder mode: the cards fold to one line each with drag handles.
    var reordering = false
    /// The short moment after a rest ends by itself.
    var restEnd: LiveRestEnd?
    /// A scroll the list should perform (menus and dialogs opened from a capture state bring
    /// their control into view first).
    var scrollRequest: LiveScrollRequest?
    /// Where the edited row sits, so the list can bring it above the number pad.
    var editPlacement = LiveEditPlacement()

    /// Global frames of the menu triggers ("…" buttons, set markers), kept current as the list
    /// scrolls. Not observed: a menu reads its anchor once, when it opens.
    @ObservationIgnored var anchors: [LiveMenuTarget: CGRect] = [:]
    /// Placement of every rendered set row (setID → placement), for aimed scrolls.
    @ObservationIgnored var rows: [UUID: LiveRowPlacement] = [:]
    /// The keyboard's top edge (global), from the system's frame notifications; nil = down.
    @ObservationIgnored var keyboardTop: CGFloat?
    /// The entry bar's measured height (it rides above the keyboard).
    @ObservationIgnored var entryBarHeight: CGFloat = 64
    /// The global top of what floats at the thumb (rest slab / entry bar); nil = not measured.
    @ObservationIgnored var dockTop: CGFloat?
    /// The list's own scroll view (found by `LiveScrollProbe`), for exact aimed scrolls.
    @ObservationIgnored weak var scrollView: UIScrollView?
    /// The glass top bar's bottom edge (global): the top of the list's clear band.
    @ObservationIgnored var topBarBottom: CGFloat = 110
    /// Global frames of the list's rows (cards and fixed rows), for choosing a scroll anchor.
    @ObservationIgnored var rowFrames: [AnyHashable: CGRect] = [:]
    /// DEBUG (capture variant "debug"): the aim's measurements.
    var debugLines: [String] = []

    func openMenu(_ target: LiveMenuTarget) {
        endEditing()
        swipedSetID = nil
        menu = LiveMenuState(target: target, anchor: anchors[target] ?? .zero)
    }

    func closeMenu() { menu = nil }

    func isMenuOpen(_ target: LiveMenuTarget) -> Bool { menu?.target == target }
}

struct LiveScrollRequest: Equatable {
    var id: AnyHashable
    var anchor: UnitPoint
    var token = UUID()
}

struct LiveEditPlacement: Equatable {
    var fraction: CGFloat = 0.5
    var globalMidY: CGFloat = .infinity
}

/// Launch-state memory: capture variants (p2/p3, L02's open menu and swipe…) and the one-time
/// template-order fix are applied once per live session, not every time the cover reappears.
@MainActor
enum LiveLaunchMemory {
    static var appliedSessionIDs: Set<UUID> = []
    static var scrolledSessionIDs: Set<UUID> = []
}

// MARK: - Store readouts

extension Store {
    /// The title a blank rename falls back to: template → "First +N" → "Workout".
    var liveDerivedTitle: String {
        guard let s = session else { return "" }
        if let t = s.templateName { return t }
        let names = s.entries.compactMap { exercise($0.exerciseID)?.name } + s.cardio.map(\.activity.name)
        guard let first = names.first else { return "Workout" }
        return names.count > 1 ? "\(first) +\(names.count - 1)" : first
    }

    /// New best / First time for each completed set of an entry, judged in completion order
    /// against history and the session's earlier sets in the same record scope (the same
    /// rule `completeSet` uses, so a badge never contradicts the celebration).
    func liveBadges(entryID: UUID) -> [UUID: SetBadge] {
        guard let s = session, let entry = liveEntry(entryID) else { return [:] }
        let loadType = loadType(entryID: entryID)
        struct Done { var at: Date; var entryID: UUID; var setID: UUID; var value: SetValue; var type: SetType }
        var done: [Done] = []
        for e in s.entries where e.scope == entry.scope {
            for set in e.sets {
                guard let at = set.completedAt, let reps = set.reps else { continue }
                let value = SetValue(weight: loadType.takesWeight ? e.total(of: set) : nil, unit: set.unit,
                                     reps: reps, bar: e.barWeight)
                done.append(Done(at: at, entryID: e.id, setID: set.id, value: value, type: set.type))
            }
        }
        done.sort { $0.at < $1.at }
        var earlier: [SetValue] = []
        var result: [UUID: SetBadge] = [:]
        for d in done {
            let outcome = Derived.liveOutcome(value: d.value, type: d.type, loadType: loadType, scope: entry.scope,
                                              history: workouts, sessionEarlier: earlier)
            if d.entryID == entryID {
                switch outcome {
                case .newBest: result[d.setID] = .newBest
                case .firstTime: result[d.setID] = .firstTime
                case .none: break
                }
            }
            if d.type.countsTowardRecords { earlier.append(d.value) }
        }
        return result
    }

    /// The rest bar's next line, per look: "Next · Set 3 · 110 lb × 8", "Next · Drop · 100 × 12",
    /// or "Next · Incline Chest Press" when the next set belongs to another exercise.
    func liveNextLabel(_ look: Look) -> String? {
        guard let n = nextSet else { return nil }
        if n.isNewExercise { return look.nextExerciseLabel(n.exerciseName) }
        let rowUnit = liveEntry(n.entryID)?.sets.first { $0.id == n.setID }?.unit ?? displayUnit
        if let number = Int(setMarker(entryID: n.entryID, setID: n.setID)) {
            return look.nextSetLabel(number: number, value: n.value, rowUnit: rowUnit, loadType: n.loadType)
        }
        guard let v = n.value else { return "Next · \(n.setLabel)" }
        return "Next · \(n.setLabel) · \(look.previousLabel(v, rowUnit: rowUnit, loadType: n.loadType))"
    }

    /// The equipment row: machine label + model (+ preset), a free-weight tag, or "Choose equipment".
    func liveEquipment(entryID: UUID) -> (title: String, subtitle: String?, symbol: String) {
        guard let entry = liveEntry(entryID) else { return ("Choose equipment", nil, "dumbbell") }
        let preset = exercise(entry.exerciseID)?.presets.first { $0.id == entry.presetID }?.name
        if let m = machine(entry.machineID) {
            let sub = [modelName(of: m), preset].compactMap { $0 }.joined(separator: " · ")
            return (m.label, sub.isEmpty ? nil : sub, LookIcon.machine)
        }
        if let tag = entry.freeWeightTag {
            return (tag.label, preset, Self.liveSymbol(tag))
        }
        return ("Choose equipment", preset, "dumbbell")
    }

    /// Free-weight glyphs: the machine glyph means a machine, dumbbell/cable mark free weights
    /// (the model's `gearshape.2` / strength-figure glyphs read as settings / a person).
    static func liveSymbol(_ tag: EquipmentTag) -> String {
        switch tag {
        case .machine, .smith: LookIcon.machine
        case .barbell, .dumbbell: "dumbbell"
        case .cable: "cable.connector"
        case .bodyweight: "figure.core.training"
        }
    }

    /// Stepper increment for the weight FIELD (per side in bar mode).
    func liveWeightStep(entryID: UUID, setID: UUID) -> Double {
        guard let entry = liveEntry(entryID), let set = entry.sets.first(where: { $0.id == setID }) else { return 5 }
        switch (entry.isBarMode, set.unit) {
        case (false, .lb): return 5
        case (false, .kg): return 2.5
        case (true, .lb): return 2.5
        case (true, .kg): return 1.25
        }
    }

    /// The entry has a following entry ("Superset with next" is offered only then).
    func liveHasNextEntry(_ entryID: UUID) -> Bool {
        guard let s = session, let i = s.entries.firstIndex(where: { $0.id == entryID }) else { return false }
        return i + 1 < s.entries.count
    }

    /// Where a superset member sits in its run (its card joins the neighbouring member's).
    func liveSupersetPosition(_ entryID: UUID) -> LiveSupersetPosition? {
        guard let s = session, let i = s.entries.firstIndex(where: { $0.id == entryID }),
              let group = s.entries[i].supersetGroup, supersetLabel(entryID: entryID) != nil else { return nil }
        let prev = i > 0 && s.entries[i - 1].supersetGroup == group
        let next = i + 1 < s.entries.count && s.entries[i + 1].supersetGroup == group
        switch (prev, next) {
        case (false, true): return .first
        case (true, true): return .middle
        case (true, false): return .last
        case (false, false): return nil
        }
    }

    /// Active calories while they are real (≥ 1); nil = absent, never "0".
    var liveActiveCalories: Int? {
        guard let cal = session?.activeCalories, cal >= 1 else { return nil }
        return Int(cal)
    }

    /// The reading a heart-rate rest started from (the ring drains from it toward the target):
    /// the highest of the recovery start and the logged 15 s buckets around the rest's start.
    func liveRestPeakBPM(_ rest: RestState) -> Int? {
        guard let s = session else { return heartRate.recoveryFrom }
        let log = s.heartRate
        let index = Int(rest.startedAt.timeIntervalSince(s.startedAt) / 15)
        let window = max(0, index - 1)...max(0, index)
        let logged = window.compactMap { log.high.indices.contains($0) ? log.high[$0] : nil }.filter { $0 > 0 }.max()
        return [heartRate.recoveryFrom, logged].compactMap { $0 }.max()
    }

    /// Completed / planned sets of one entry ("3/4").
    func liveProgress(entryID: UUID) -> (done: Int, total: Int) {
        guard let e = liveEntry(entryID) else { return (0, 0) }
        return (e.sets.filter(\.isCompleted).count, e.sets.count)
    }

    /// The first row typed but not ticked (the finish notice scrolls to it).
    var liveFirstUnloggedSet: (entryID: UUID, setID: UUID)? {
        guard let s = session else { return nil }
        for e in s.entries {
            if let set = e.sets.first(where: { $0.state == .typed }) { return (e.id, set.id) }
        }
        return nil
    }

    /// PROTOTYPE seed fix (promote into `SampleData`/`buildLivePushDay`): the seeded Push Day puts
    /// Machine Shoulder Press first; the shared scenario and every Live mockup show the template
    /// order, with Seated Chest Press first. Restores template order (entries the template does
    /// not know keep their place after it). No-op for sessions already in order.
    func liveRestoreTemplateOrder() {
        guard let s = session, let t = template(s.templateID) else { return }
        let order = t.items.map(\.exerciseID)
        func rank(_ e: LiveEntry) -> Int { order.firstIndex(of: e.exerciseID) ?? Int.max }
        let target = s.entries.enumerated().sorted { a, b in
            let ra = rank(a.element), rb = rank(b.element)
            return ra == rb ? a.offset < b.offset : ra < rb
        }.map(\.element.id)
        for (i, id) in target.enumerated() {
            guard let current = session?.entries.firstIndex(where: { $0.id == id }), current != i else { continue }
            moveEntries(fromOffsets: IndexSet(integer: current), toOffset: current > i ? i : i + 1)
        }
    }
}

enum LiveSupersetPosition { case first, middle, last }

// MARK: - Capture variants

/// View-level capture variants (`-variant a+b`), applied once per session when the cover opens.
/// Store-level ones ("stale", "noSensor", "degraded") are applied by the shell.
@MainActor
enum LiveVariants {
    static func tokens(_ variant: String?) -> Set<String> {
        Set((variant ?? "").split(separator: "+").map(String.init))
    }

    /// Changes the session itself (before the list lays out).
    static func applySessionVariants(_ tokens: Set<String>, store: Store, router: Router, model: LiveScreenModel) {
        if tokens.contains("empty") || tokens.contains("noGym") {
            // A fresh workout: empty, or Push Day with no gym (no machines, Add by Machine off).
            store.cancelWorkout()
            if tokens.contains("noGym") { store.selectGym(nil) }
            store.startLifting(templateID: tokens.contains("noGym") ? SampleData.templateID("Push Day") : nil)
            if tokens.contains("noSensor") { store.setSensor(.none) }
        }
        if tokens.contains("idle") || tokens.contains("first") || tokens.contains("loads") {
            store.skipRest()
        }
        if tokens.contains("done") {
            // The timer ran out (simulated moment): "Rest complete" and what is next.
            store.skipRest()
            model.restEnd = LiveRestEnd(outcome: .timerDone, at: store.now)
        }
        if tokens.contains("cap") {
            // The 4:00 cap ran out before the heart rate reached the target (simulated moment).
            store.skipRest()
            model.restEnd = LiveRestEnd(outcome: .cap, at: store.now)
        }
        if tokens.contains("recovered") {
            // The heart rate fell below the target (simulated moment, as Z03's 108 bpm).
            store.skipRest()
            model.restEnd = LiveRestEnd(outcome: .recovered(bpm: 108), at: store.now)
        }
        if tokens.contains("long") {
            // More than 24 planned sets: A's ring becomes one continuous arc.
            for entry in store.session?.entries ?? [] { _ = store.addSet(entryID: entry.id); _ = store.addSet(entryID: entry.id) }
        }
        if tokens.contains("first") {
            // A first-ever set: "First time", never a new best.
            if let id = store.addExercise(SampleData.exerciseID("Landmine Press")),
               let set = store.liveEntry(id)?.sets.first {
                store.updateWeight(25, entryID: id, setID: set.id)
                store.updateReps(10, entryID: id, setID: set.id)
                store.completeSet(entryID: id, setID: set.id)
                store.skipRest()
            }
        }
        if tokens.contains("loads") {
            // Assisted (ASSIST, less is better) typed in kg at an lb gym (PREVIOUS keeps its "lb"),
            // BW + added, and bodyweight (reps only).
            if let id = store.addExercise(SampleData.exerciseID("Assisted Pull-Up")),
               let set = store.liveEntry(id)?.sets.first {
                store.toggleUnit(entryID: id, setID: set.id)
                store.updateWeight(32.5, entryID: id, setID: set.id)
            }
            _ = store.addExercise(SampleData.exerciseID("Dip"))
            let pushUp = store.exercises.first { $0.name == "Push-Up" }?.id
                ?? store.createExercise(name: "Push-Up", loadType: .bodyweight, muscleGroup: nil, tags: [.bodyweight])
            if let id = store.addExercise(pushUp), let set = store.liveEntry(id)?.sets.first {
                store.updateReps(15, entryID: id, setID: set.id)
            }
        }
        if tokens.contains("reorder") { model.reordering = true }
        if tokens.contains("lifting") {
            // C02 / C03 / C05 seen from the lifting side: planned cardio Recording / Paused / Done.
            if store.session?.focus == .cardio { store.setFocus(.lifting) }
            // C05 raises its distance sheet together with the cover. A dismissal while that
            // presentation is still in flight is dropped (and leaves the sheet up), so close it
            // only once, after the cover and the sheet have settled.
            if router.sheet != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { router.dismissSheet() }
            }
        }
    }
}

// MARK: - Parsing typed numbers

enum LiveNumberEntry {
    /// "112.5", "112,5", "112." → 112.5 / 112; "" → nil.
    static func weight(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned != "." else { return nil }
        return Double(cleaned.hasSuffix(".") ? String(cleaned.dropLast()) : cleaned)
    }

    static func reps(_ text: String) -> Int? {
        guard !text.isEmpty else { return nil }
        return Int(text.filter(\.isNumber))
    }

    /// Stepper label: "+5", "−2.5", "+1".
    static func stepLabel(_ step: Double, up: Bool) -> String {
        "\(up ? "+" : "−")\(Format.weight(step))"
    }
}

// MARK: - Shared visual pieces

/// The rest bar's floating background, per look (the same treatment as the foundation RestBar:
/// A glass + Ultra, B Liquid Glass over graphite, C the ink slab).
struct LiveSlabBackground: View {
    @Environment(\.look) private var look

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.bar, style: .continuous)
        switch look.id {
        case .floodlight:
            shape.fill(look.slab)
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1) }
                .shadow(color: look.floatShadow(0.6), radius: 20, x: 0, y: 16)
        case .anatomy:
            Color.clear
                .glassEffect(.regular.tint(look.slab), in: shape)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1) }
                .shadow(color: .black.opacity(0.55), radius: 20, x: 0, y: -6)
        case .paper, .carbon:
            shape.fill(look.slab)
                .overlay { shape.strokeBorder(look.slabEdge, lineWidth: 1.5) }
        }
    }
}

/// The rest-bar pills (+15s, Skip, the entry bar's steppers). The foundation `PillButtonStyle`
/// plus `fill` (AX sizes: equal full-width halves, the label centred in the capsule) and a type
/// cap so the floating bar stays within about 22 % of the screen.
struct LivePillStyle: ButtonStyle {
    var prominent = false
    var fill = false
    @ScaledMetric(relativeTo: .subheadline) private var heightAB: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var heightC: CGFloat = 48
    @Environment(\.look) private var look

    func makeBody(configuration: Configuration) -> some View {
        let isC = look.id.isPaperClub
        let pressed = configuration.isPressed
        let height = min(isC ? heightC : heightAB, 56)
        let label = configuration.label
            .font(look.id == .anatomy ? .system(.callout, design: .rounded, weight: .heavy)
                  : .system(.callout, weight: prominent || isC ? .bold : .semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, prominent ? 18 : 14)
            .frame(minWidth: 56, maxWidth: fill ? .infinity : nil, minHeight: height)
        Group {
            switch (look.id, prominent) {
            case (.floodlight, true), (.anatomy, true):
                label.foregroundStyle(look.onAction).background(look.action, in: Capsule())
            case (.floodlight, false):
                label.foregroundStyle(look.textPrimary)
                    .background(look.pillFill, in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            case (.anatomy, false):
                label.foregroundStyle(look.textPrimary)
                    .glassEffect(.regular.tint(look.slab), in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            case (_, true):
                label.foregroundStyle(look.onAction)
                    .background(look.action, in: Capsule())
                    .overlay { Capsule().fill(Color.black.opacity(pressed ? 0.18 : 0)) }
                    .overlay { Capsule().strokeBorder(look.onSlab, lineWidth: 2) }
            case (_, false):
                label.foregroundStyle(look.onSlab)
                    .background(look.onSlab.opacity(pressed ? 0.16 : 0), in: Capsule())
                    .overlay { Capsule().strokeBorder(look.pillEdge, lineWidth: 2) }
            }
        }
        .contentShape(Capsule())
        .pressFeedback(pressed, isC ? .none : .scale)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// A small capsule command on a card (planned cardio "Start"): A raised fill, B white 8 %,
/// C outlined and darkening while pressed. Never used on a slab.
struct LiveSmallCapsuleStyle: ButtonStyle {
    @Environment(\.look) private var look
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(minHeight: height)
            .background(fill(pressed), in: Capsule())
            .overlay {
                if look.id.isPaperClub { Capsule().strokeBorder(look.outline, lineWidth: look.stroke.pressable) }
                else { Capsule().strokeBorder(look.pillEdge, lineWidth: 1) }
            }
            .opacity(isEnabled ? 1 : 0.45)
            .padding(.vertical, max(0, (44 - height) / 2))
            .contentShape(Capsule())
            .pressFeedback(pressed, look.id.isPaperClub ? .none : .scale)
    }

    private func fill(_ pressed: Bool) -> Color {
        switch look.id {
        case .floodlight: look.surfaceRaised
        case .anatomy: look.controlFill
        case .paper, .carbon: pressed ? look.pressedFill : look.surface
        }
    }
}

/// The chip beside an exercise title: the superset letter ("A", "B"), and/or done. It lights
/// when every set of the exercise is ticked — A a floodlight square, B a pearl lozenge, C an
/// ink disc (the look's "done" fill); a finished exercise outside a superset shows a check.
/// Never a family colour.
struct LiveSupersetChip: View {
    var letter: String?
    var done = false
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var side: CGFloat = 24

    var body: some View {
        let content = Group {
            if let letter {
                Text(letter).font(.system(.footnote, design: look.id == .anatomy ? .rounded : .default, weight: .heavy))
            } else {
                Image(systemName: "checkmark").font(.system(.caption, weight: .heavy))
            }
        }
        .frame(width: side, height: side)
        Group {
            switch look.id {
            case .floodlight:
                let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                content.foregroundStyle(done ? look.onDone : look.textPrimary)
                    .background { if done { shape.fill(look.done) } }
                    .overlay { if !done { shape.strokeBorder(look.textPrimary, lineWidth: 1.5) } }
            case .anatomy:
                // B's checks are circles: a finished exercise is a pearl disc; a letter a lozenge.
                let shape = RoundedRectangle(cornerRadius: letter == nil ? side / 2 : 8, style: .continuous)
                content.foregroundStyle(done ? look.onDone : look.textPrimary)
                    .background(done ? look.done : look.positive.opacity(0.14), in: shape)
            case .paper, .carbon:
                content.foregroundStyle(done ? look.onDone : look.textPrimary)
                    .background { if done { Circle().fill(look.done) } }
                    .overlay { if !done { Circle().strokeBorder(look.outline, lineWidth: 1.5) } }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([letter.map { "Superset \($0)" }, done ? "All sets done" : nil].compactMap { $0 }.joined(separator: ", "))
    }
}

/// The live dot: breathing while recording (still under Reduce Motion). A and C use the live
/// colour; B has no hue for commands or state (red is heart rate only), so its dot is pearl.
struct LiveRecordingDot: View {
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        Circle().fill(look.id == .anatomy ? look.textPrimary : look.live)
            .frame(width: 8, height: 8)
            .phaseAnimator(reduceMotion ? [false] : [false, true]) { view, on in
                view.opacity(on ? 0.35 : 1)
            } animation: { _ in .easeInOut(duration: 0.8) }
            .accessibilityHidden(true)
    }
}

/// An exercise card's surface with optional joined edges: superset members sit on one shared
/// backing, split by a hairline seam, so the pair reads as one group inside the 20 pt margin.
struct LiveCardSurface: ViewModifier {
    var joinTop = false
    var joinBottom = false
    var highlighted = false
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        let r = look.radius.panel
        let j: CGFloat = 5
        let shape = UnevenRoundedRectangle(topLeadingRadius: joinTop ? j : r, bottomLeadingRadius: joinBottom ? j : r,
                                           bottomTrailingRadius: joinBottom ? j : r, topTrailingRadius: joinTop ? j : r,
                                           style: .continuous)
        content
            .background(look.surface, in: shape)
            .overlay {
                switch look.id {
                case .floodlight, .paper, .carbon:
                    shape.strokeBorder(look.hairline, lineWidth: look.stroke.hairline)
                case .anatomy:
                    ZStack {
                        shape.strokeBorder(look.hairline, lineWidth: 1)
                        shape.inset(by: 1).stroke(
                            LinearGradient(colors: [look.innerHighlight, .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.08)),
                            lineWidth: 1)
                    }
                }
            }
            .overlay {
                // B: the current exercise card is marked by a brighter neutral hairline (pearl 22 %).
                if highlighted { shape.strokeBorder(look.textPrimary.opacity(0.22), lineWidth: 1) }
            }
    }
}

/// C's quiet destructive row: a single pressable rule and an outlined trash disc, so "Discard
/// Workout…" never outweighs Add Exercise above it.
struct LiveQuietDestructiveButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 50
    @ScaledMetric(relativeTo: .headline) private var disc: CGFloat = 30

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(.footnote, weight: .bold))
                    .frame(width: disc, height: disc)
                    .overlay { Circle().strokeBorder(look.destructive, lineWidth: 1.5) }
                Text(title).font(.system(.body, weight: .semibold))
            }
            // Paper / Carbon: destructive is the ink (no hue). The final look's Floodlight skin
            // keeps Floodlight's red-orange here, as its Cancel does.
            .foregroundStyle(look.destructive)
            .frame(maxWidth: .infinity, minHeight: height)
            .overlay { Capsule().strokeBorder(look.destructive, lineWidth: 1.5) }
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
    }
}

/// The exercise card's title buttons. B and C use the foundation `CardIconButton`. A's bare
/// glyphs read as a signal meter, so A draws both in a cell-filled disc (visual 38, hit 44) and
/// uses the line chart for Previous performance.
struct LiveCardIconButton: View {
    var symbol: String
    var accessibilityLabel: String
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 38

    init(_ symbol: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        if look.id == .floodlight {
            let outset = max(0, (44 - disc) / 2)
            Button(action: action) {
                Image(systemName: symbol == "chart.bar.xaxis" ? "chart.line.uptrend.xyaxis" : symbol)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(look.textPrimary)
                    .frame(width: disc, height: disc)
                    .background(look.surfaceRaised, in: Circle())
                    .padding(outset)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
            .padding(-outset)
            .accessibilityLabel(accessibilityLabel)
        } else {
            CardIconButton(symbol, accessibilityLabel: accessibilityLabel, action: action)
        }
    }
}

/// The header's "N/M sets" ring. B and C use the foundation `SetsRing`. A's segments must count
/// at a glance: lit segments are full floodlight white and thicker, unlit ones a visible grey
/// (about 2.1:1 on the ground) with a small gap; above 24 sets it is one continuous arc.
struct LiveSetsRing: View {
    var done: Int
    var total: Int
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion

    var body: some View {
        if look.id == .floodlight {
            let side: CGFloat = 34
            // Lit segments are full floodlight white; unlit ones a dim stand grey (white 26 % on
            // night ≈ 2.1:1), so the lit run reads as one bright arc with its count ticks.
            let width = side * 0.17
            let unlit = look.textPrimary.opacity(0.26)
            Group {
                if total > 0 && total <= 24 {
                    ZStack {
                        ForEach(0..<total, id: \.self) { index in
                            let step = 1.0 / Double(total)
                            let gap = step * 0.18
                            RingArc(start: Double(index) * step + gap / 2, end: Double(index + 1) * step - gap / 2)
                                .stroke(index < done ? look.done : unlit, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: done)
                        }
                    }
                } else {
                    let fraction = total > 0 ? min(1, Double(done) / Double(total)) : 0
                    ZStack {
                        Circle().stroke(unlit, lineWidth: width)
                        RingArc(start: 0, end: fraction)
                            .stroke(look.done, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: fraction)
                    }
                }
            }
            .padding(width / 2)
            .frame(width: side, height: side)
            .accessibilityHidden(true)
        } else {
            SetsRing(done: done, total: total)
        }
    }
}

// MARK: - Scroll view probe

/// Finds the scroll view that hosts the list (the first scrolling ancestor of a row) so the
/// screen can move it by an exact, measured distance.
struct LiveScrollProbe: UIViewRepresentable {
    var model: LiveScreenModel

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onFind = { [weak model] scroll in model?.scrollView = scroll }
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        var onFind: ((UIScrollView) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView { onFind?(scroll); return }
                ancestor = view.superview
            }
        }
    }
}

// MARK: - Reduce Motion

extension EnvironmentValues {
    /// The live screen's Reduce Motion: the system setting, or the "rm" capture variant (so a
    /// still of the Reduce Motion alternatives can be captured without changing the simulator).
    @Entry var liveReduceMotion = false
}
