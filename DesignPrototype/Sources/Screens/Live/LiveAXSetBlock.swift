import SwiftUI

// PROTOTYPE — the set row at accessibility sizes (AX1+), a Live copy of the foundation
// SetRowView's two-line block with one fix to promote: the WEIGHT / REPS labels and their
// values share ONE leading edge (the foundation centres the value in each half under a leading
// label, which gives every block two alignment edges). Line 1: marker · previous (+ the look's
// New best / First time mark) · check. Line 2: labelled Weight and Reps wells, values leading.
// The check keeps each look's completion effect (A stamp, B pop + ripple, C stamp + ripple).

struct LiveAXSetBlock: View {
    var kind: SetType
    var number: Int
    var previous: String?
    var weight: Double?
    var unit: WeightUnit
    var reps: Int?
    var state: LiveSetState
    var isNextUp: Bool
    var isResting: Bool
    var badge: SetBadge?
    var weightTitle: String
    /// Bodyweight exercises log reps only.
    var showsWeight = true
    var onCheck: () -> Void
    var onWeight: () -> Void
    var onReps: () -> Void
    var onUnit: () -> Void

    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion
    @State private var stamp = 0

    private var done: Bool { state == .completed }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                SetMarker(kind: kind, number: number, done: done, isNextUp: isNextUp)
                VStack(alignment: .leading, spacing: 3) {
                    Text(previous ?? "—")
                        .font(look.id.isPaperClub ? .system(.subheadline) : look.font.footnote)
                        .monospacedDigit()
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let badge {
                        NewBestBadge(kind: badge)
                            .transition(reduceMotion ? .opacity : .scale(scale: 1.5).combined(with: .opacity))
                    }
                }
                Spacer(minLength: 4)
                Button(action: onCheck) {
                    LiveAXCheck(done: done, warmup: kind == .warmup, isNextUp: isNextUp, isResting: isResting, stamp: stamp)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "Completed" : "Complete set")
            }
            HStack(alignment: .top, spacing: 10) {
                if showsWeight {
                    column(title: weightTitle, value: weight.map { Format.weight($0) }, unit: unit.label,
                           spoken: "Weight", action: onWeight, unitAction: onUnit)
                }
                column(title: "REPS", value: reps.map(String.init), unit: nil, spoken: "Reps", action: onReps, unitAction: nil)
            }
        }
        .padding(.vertical, 6)
        .onChange(of: done) { _, isDone in if isDone { stamp += 1 } }
        .sensoryFeedback(.impact(weight: .medium), trigger: stamp)
    }

    /// A labelled well: the label and the value on one leading edge.
    private func column(title: String, value: String?, unit: String?, spoken: String,
                        action: @escaping () -> Void, unitAction: (() -> Void)?) -> some View {
        let dim = kind == .warmup && done && look.id == .floodlight
        let valueFont = look.id == .floodlight ? Font.system(.title3, weight: .heavy).width(.expanded).monospacedDigit() : look.font.fieldNumber
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).font(look.font.columnHeader).tracking(look.columnTracking).foregroundStyle(look.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value ?? "—")
                    .font(valueFont)
                    .foregroundStyle(value == nil || dim ? look.textSecondary : look.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit, value != nil {
                    Button { unitAction?() } label: {
                        Text(unit).font(.system(.caption, weight: .semibold)).foregroundStyle(look.unit(self.unit))
                            .padding(.vertical, 10).padding(.trailing, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -10).padding(.trailing, -10)
                    .allowsHitTesting(!done && unitAction != nil)
                }
            }
            .padding(.horizontal, done && look.id != .floodlight ? 0 : 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background { well.padding(.vertical, 2) }
            .contentShape(Rectangle())
            .onTapGesture { if !done { action() } }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityValue([value, value == nil ? nil : unit].compactMap { $0 }.joined(separator: " "))
        .accessibilityAddTraits(done ? [] : .isButton)
        .accessibilityAction { if !done { action() } }
        .accessibilityActions {
            if let unitAction, unit != nil, !done { Button("Switch unit", action: unitAction) }
        }
    }

    /// The field's well per look and state (as the foundation row): A cell + draft border, done a
    /// faint lit cell; B well + hairline, done bare; C dashed open box, typed a rule, done inked bare.
    @ViewBuilder private var well: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.field, style: .continuous)
        switch (look.id, state) {
        case (.floodlight, .completed): shape.fill(look.wash(0.045))
        case (.floodlight, _): shape.fill(look.field).overlay { shape.strokeBorder(look.textPrimary.opacity(0.45), lineWidth: 1) }
        case (.anatomy, .completed): Color.clear
        case (.anatomy, _): shape.fill(look.field).overlay { shape.strokeBorder(look.hairline, lineWidth: 1) }
        case (_, .completed): Color.clear
        case (_, .typed): shape.fill(look.field).overlay { shape.strokeBorder(look.hairline, lineWidth: 1.5) }
        case (_, _): shape.fill(look.field).overlay { shape.strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
        }
    }
}

/// The check at AX sizes: the look's face (A Ultra when it is the thing to do now, B the pearl
/// ring breathing, C the cobalt ring) and its completion effect. Reduce Motion: still.
private struct LiveAXCheck: View {
    var done: Bool
    var warmup: Bool
    var isNextUp: Bool
    var isResting: Bool
    var stamp: Int
    @Environment(\.look) private var look
    @Environment(\.liveReduceMotion) private var reduceMotion

    struct Stamp { var scale: CGFloat = 1; var rotation: Double = 0 }
    struct Ripple { var scale: CGFloat = 1; var opacity: Double = 0 }

    var body: some View {
        ZStack {
            if !reduceMotion && look.id != .floodlight {
                Circle().strokeBorder(look.textPrimary, lineWidth: look.id == .anatomy ? 2 : 3)
                    .frame(width: 34, height: 34)
                    .keyframeAnimator(initialValue: Ripple(), trigger: stamp) { view, v in
                        view.scaleEffect(v.scale).opacity(v.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) { MoveKeyframe(0.8); CubicKeyframe(1.9, duration: 0.6) }
                        KeyframeTrack(\.opacity) { MoveKeyframe(0.8); LinearKeyframe(0, duration: 0.6) }
                    }
            }
            face
                .keyframeAnimator(initialValue: Stamp(), trigger: stamp) { view, v in
                    view.scaleEffect(reduceMotion ? 1 : v.scale).rotationEffect(.degrees(reduceMotion ? 0 : v.rotation))
                } keyframes: { _ in
                    let pop = look.id == .anatomy
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(look.motion.stampScale)
                        CubicKeyframe(pop ? 1.16 : 0.9, duration: pop ? 0.29 : 0.2)
                        CubicKeyframe(1, duration: pop ? 0.23 : 0.17)
                    }
                    KeyframeTrack(\.rotation) {
                        MoveKeyframe(look.motion.stampRotation)
                        CubicKeyframe(0, duration: 0.37)
                    }
                }
        }
    }

    @ViewBuilder private var face: some View {
        switch look.id {
        case .floodlight:
            let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
            let now = isNextUp && !isResting
            if done {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(look.onDone)
                    .frame(width: 34, height: 34).background(warmup ? look.textSecondary : look.done, in: shape)
            } else {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(now ? look.action : look.textPrimary.opacity(0.62))
                    .frame(width: 34, height: 34)
                    .overlay { shape.strokeBorder(now ? look.action : look.textPrimary.opacity(0.42), lineWidth: 2) }
            }
        case .anatomy:
            if done {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(look.onDone)
                    .frame(width: 32, height: 32).background(look.done, in: Circle())
            } else if isNextUp {
                Circle().strokeBorder(look.textPrimary, lineWidth: 2).frame(width: 32, height: 32)
                    .phaseAnimator(reduceMotion ? [false] : [false, true]) { view, on in
                        view.shadow(color: look.textPrimary.opacity(on ? 0.35 : 0), radius: on ? 7 : 0)
                    } animation: { _ in .easeInOut(duration: 1.2) }
            } else {
                Circle().strokeBorder(look.textTertiary, lineWidth: 2).frame(width: 32, height: 32)
            }
        case .paper, .carbon:
            if done {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(look.onDone)
                    .frame(width: 34, height: 34).background(look.done, in: Circle())
            } else if isNextUp {
                Circle().fill(look.surface).overlay { Circle().strokeBorder(look.actionText, lineWidth: 2.5) }
                    .frame(width: 34, height: 34)
            } else {
                Circle().strokeBorder(look.textSecondary, lineWidth: 2).frame(width: 34, height: 34)
            }
        }
    }
}
