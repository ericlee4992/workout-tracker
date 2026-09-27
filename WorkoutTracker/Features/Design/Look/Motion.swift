import SwiftUI

// Motion helpers. Every animation answers an action or a live state and has a
// still alternative under Reduce Motion (crossfade / none).

// MARK: - Press feedback

/// How a pressable reacts while held, per look:
/// A/B scale (0.97); C's primary sinks into its hard shadow; C's other pressables darken.
/// Under Reduce Motion every look dips opacity instead. `.none`: the caller draws its own
/// pressed state (a fill change), so nothing else happens.
struct PressFeedback: ViewModifier {
    enum Kind { case scale, sink, darken, none }
    var isPressed: Bool
    var kind: Kind
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let pressed = isPressed
        if kind == .none {
            content
        } else if reduceMotion {
            content.opacity(pressed ? look.motion.reducedPressOpacity : 1)
        } else {
            switch kind {
            case .scale:
                content
                    .scaleEffect(pressed ? look.motion.pressScale : 1)
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: pressed)
            case .sink:
                content
                    .offset(x: pressed ? look.motion.pressSink : 0, y: pressed ? look.motion.pressSink : 0)
                    .animation(.easeOut(duration: 0.09), value: pressed)
            case .darken:
                content
                    .brightness(pressed ? (look.isDark ? 0.06 : -0.05) : 0)
                    .animation(.easeOut(duration: 0.09), value: pressed)
            case .none:
                content
            }
        }
    }
}

extension View {
    func pressFeedback(_ isPressed: Bool, _ kind: PressFeedback.Kind = .scale) -> some View {
        modifier(PressFeedback(isPressed: isPressed, kind: kind))
    }
}

/// The default pressable style for cards, tiles and rows: the look's press behaviour, no chrome.
struct LookPressableStyle: ButtonStyle {
    @Environment(\.look) private var look
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .pressFeedback(configuration.isPressed, look.id.isPaperClub ? .darken : .scale)
    }
}

extension ButtonStyle where Self == LookPressableStyle {
    static var lookPressable: LookPressableStyle { LookPressableStyle() }
}

// MARK: - Count-up numerals

/// A number that counts up from 0 (or from its previous value) when it appears or changes.
/// Reduce Motion shows the final value at once.
struct CountUpText: View {
    var value: Double
    var format: (Double) -> String
    var duration: Double = 0.9
    /// false: start at the value (only later changes count).
    var countsFromZero = true

    @State private var shown: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ value: Double, duration: Double = 0.9, countsFromZero: Bool = true, format: @escaping (Double) -> String) {
        self.value = value
        self.format = format
        self.duration = duration
        self.countsFromZero = countsFromZero
    }

    /// Integer convenience: grouped ("18,450").
    init(_ value: Int, duration: Double = 0.9, countsFromZero: Bool = true) {
        self.init(Double(value), duration: duration, countsFromZero: countsFromZero) { LookFormat.grouped($0) }
    }

    var body: some View {
        EmptyView()
            .modifier(CountingNumber(value: shown ?? (countsFromZero && !reduceMotion ? 0 : value), format: format))
            .onAppear {
                guard !reduceMotion else { shown = value; return }
                if shown == nil && countsFromZero {
                    shown = 0
                    withAnimation(.easeOut(duration: duration)) { shown = value }
                } else {
                    shown = value
                }
            }
            .onChange(of: value) { _, newValue in
                if reduceMotion { shown = newValue } else {
                    withAnimation(.easeOut(duration: min(duration, 0.6))) { shown = newValue }
                }
            }
            .accessibilityLabel(format(value))
    }
}

/// Animates the number itself (the label re-renders each frame).
private struct CountingNumber: ViewModifier, Animatable {
    var value: Double
    var format: (Double) -> String
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    func body(content: Content) -> some View {
        Text(format(value))
    }
}

// MARK: - Celebrate

extension View {
    /// A one-shot celebration when `trigger` changes: a spring bump (A: overshoot
    /// "stamp", B: pop, C: thunk). Reduce Motion: nothing moves.
    func celebrate<T: Equatable>(_ trigger: T) -> some View {
        modifier(CelebrateModifier(trigger: trigger))
    }
}

private struct CelebrateModifier<T: Equatable>: ViewModifier {
    var trigger: T
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            let peak: CGFloat = 1.25
            content.keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(peak, duration: 0.14)
                    SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                }
            }
        }
    }
}

// MARK: - Appear-once helper

/// Drives entry animations (lighting maps, drawing rings) once; Reduce Motion starts complete.
struct AppearProgress: ViewModifier {
    var delay: Double
    var duration: Double
    @Binding var progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.onAppear {
            guard progress < 1 else { return }
            if reduceMotion { progress = 1; return }
            withAnimation(.easeOut(duration: duration).delay(delay)) { progress = 1 }
        }
    }
}

extension View {
    func appearProgress(_ progress: Binding<Double>, delay: Double = 0, duration: Double = 0.7) -> some View {
        modifier(AppearProgress(delay: delay, duration: duration, progress: progress))
    }
}

// MARK: - Beating heart

/// Heart glyph that beats at the live bpm while samples are fresh. Stale: grey, still.
/// Reduce Motion: a still heart.
struct BeatingHeart: View {
    var bpm: Int?
    var isFresh: Bool
    var font: Font = .body

    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let color = isFresh ? look.heartRate : look.textTertiary
        let animate = isFresh && !reduceMotion && (bpm ?? 0) > 0
        Group {
            if animate, let bpm {
                TimelineView(.animation) { context in
                    // A beats on a fixed 1.1 s; B and C beat at the live bpm.
                    let period = look.id == .floodlight ? 1.1 : 60.0 / Double(max(30, bpm))
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    Image(systemName: "heart.fill")
                        .scaleEffect(Self.beatScale(phase))
                }
            } else {
                Image(systemName: "heart.fill")
            }
        }
        .font(font)
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }

    /// A quick lub: up to 1.22 in the first 16 % of the period, back by 34 %.
    static func beatScale(_ phase: Double) -> CGFloat {
        if phase < 0.16 { return 1 + 0.22 * CGFloat(phase / 0.16) }
        if phase < 0.34 { return 1.22 - 0.22 * CGFloat((phase - 0.16) / 0.18) }
        return 1
    }
}
