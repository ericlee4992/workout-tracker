import SwiftUI

/// Public beta ticket 02 (spec Q8b): the guided tour — coach marks over the real screens, one highlighted control
/// at a time. This file is the tour's own machinery: the steps, the controller, the anchors that report where a
/// control is, and the overlay that dims everything else.
///
/// Anchors report their frame in the *global* coordinate space into the controller rather than through a
/// preference: preferences do not leave toolbar items (the Settings gear) or full-screen covers, and the tour has
/// to reach both.
struct TourStep: Identifiable, Hashable {
    enum Tab: Hashable { case workout, history, gyms, exercises }

    let id: String
    /// The `tourAnchor` this step highlights.
    let anchor: String
    /// The tab the tour selects before showing the step.
    let tab: Tab
    /// One line (the user's wording, 2026-10-02).
    let caption: String
    /// A non-interactive picture in the caption card: the tour never opens a workout (it would reach HealthKit,
    /// the Live Activity and notifications — ticket 02, isolation), so logging is shown, not entered.
    var picture: OnboardingIllustration.Kind? = nil

    static let all: [TourStep] = [
        TourStep(id: "gym", anchor: "tour.gymPicker", tab: .workout,
                 caption: "Pick the gym you're at. Each gym keeps its own machines and numbers."),
        TourStep(id: "start", anchor: "tour.start", tab: .workout,
                 caption: "Start a workout here — lifting or cardio.", picture: .logging),
        TourStep(id: "templates", anchor: "tour.templates", tab: .workout,
                 caption: "Templates are your routines, ready at any gym."),
        TourStep(id: "askAI", anchor: "tour.askAI", tab: .workout,
                 caption: "Ask AI builds a week of templates from your goals."),
        TourStep(id: "gyms", anchor: "tour.gymsList", tab: .gyms,
                 caption: "Your gyms. Open one to add its machines or scan one."),
        TourStep(id: "history", anchor: "tour.historyList", tab: .history,
                 caption: "Every workout, with your records and new bests."),
        TourStep(id: "exercises", anchor: "tour.exercisesList", tab: .exercises,
                 caption: "Every exercise, with its history on each machine."),
        TourStep(id: "settings", anchor: "tour.settings", tab: .workout,
                 caption: "Units, appearance, AI and backups — and this tour again."),
    ]
}

@Observable
final class TourController {
    let steps: [TourStep]
    private(set) var index: Int?
    /// Global frames of the anchors currently on screen.
    var frames: [String: CGRect] = [:]
    private let onEnd: () -> Void

    init(steps: [TourStep] = TourStep.all, onEnd: @escaping () -> Void = {}) {
        self.steps = steps
        self.onEnd = onEnd
    }

    var current: TourStep? { index.map { steps[$0] } }
    var isActive: Bool { index != nil }

    func start() { index = 0 }

    func next() {
        guard let index else { return }
        if index + 1 < steps.count { self.index = index + 1 } else { end() }
    }

    func end() {
        index = nil
        onEnd()
    }
}

// MARK: Anchors

private struct TourAnchorModifier: ViewModifier {
    let id: String
    @Environment(TourController.self) private var tour: TourController?

    func body(content: Content) -> some View {
        if let tour {
            content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { tour.frames[id] = $0 }
        } else {
            content
        }
    }
}

extension View {
    /// Marks a control the guided tour can highlight. Does nothing unless a tour is in the environment.
    func tourAnchor(_ id: String) -> some View { modifier(TourAnchorModifier(id: id)) }

    /// Marks this view only when `condition` holds (the first row of a list).
    @ViewBuilder func tourAnchor(_ id: String, when condition: Bool) -> some View {
        if condition { modifier(TourAnchorModifier(id: id)) } else { self }
    }
}

// MARK: Overlay

/// The tour's layer, above an inert app: dims the screen except the current step's control and shows its caption
/// with Next and Skip Tour. It is present for the whole tour — before an anchor has reported its frame it dims
/// everything and still offers the caption and Skip — and it is the only accessible content (an accessibility modal).
struct TourOverlay: View {
    @Environment(TourController.self) private var tour: TourController?
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @AccessibilityFocusState private var captionFocused: Bool
    @State private var captionHeight: CGFloat = 180

    var body: some View {
        GeometryReader { proxy in
            if let tour, let step = tour.current {
                let origin = proxy.frame(in: .global).origin
                let target = tour.frames[step.anchor]
                    .map { $0.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -8, dy: -8) }
                ZStack(alignment: .topLeading) {
                    dimming(cutout: target, size: proxy.size)
                        .contentShape(Rectangle())
                        .onTapGesture { }  // swallows every tap outside the highlight
                    if let target {
                        Color.clear
                            .contentShape(RoundedRectangle(cornerRadius: 14))
                            .frame(width: target.width, height: target.height)
                            .offset(x: target.minX, y: target.minY)
                            .onTapGesture { advance(tour) }
                            .accessibilityHidden(true)
                    }
                    caption(step, tour: tour, target: target, size: proxy.size)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step.id)
                .onAppear { captionFocused = true }
                .onChange(of: step.id) { captionFocused = true }
            }
        }
        .ignoresSafeArea()
    }

    private func advance(_ tour: TourController) {
        if reduceMotion { tour.next() } else { withAnimation(.easeInOut(duration: 0.25)) { tour.next() } }
    }

    /// With no frame yet (or ever), the whole screen is dimmed: the barrier never depends on geometry.
    private func dimming(cutout: CGRect?, size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let cutout { path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 14, height: 14)) }
        }
        .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
        .overlay {
            if let cutout {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(look.action, lineWidth: 2)
                    .frame(width: cutout.width, height: cutout.height)
                    .position(x: cutout.midX, y: cutout.midY)
            }
        }
        .accessibilityHidden(true)
    }

    private func caption(_ step: TourStep, tour: TourController, target: CGRect?, size: CGSize) -> some View {
        let number = (tour.index ?? 0) + 1
        let below = (target?.midY ?? 0) < size.height * 0.55
        return VStack(alignment: .leading, spacing: 12) {
            Text("\(number) of \(tour.steps.count)")
                .font(look.font.caption)
                .foregroundStyle(look.textSecondary)
            Text(step.caption)
                .font(look.font.headline)
                .foregroundStyle(look.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($captionFocused)
            // Decorative; left out at accessibility sizes so the caption and its buttons stay on screen.
            if let picture = step.picture, !typeSize.isAccessibilitySize {
                OnboardingIllustration(kind: picture)
                    .allowsHitTesting(false)
            }
            HStack {
                // Labels carry their own 44-pt frame and content shape: the whole drawn button is the hit region
                // (codex-review-02 #2).
                Button { tour.end() } label: {
                    Text("Skip Tour")
                        .font(look.font.subhead.weight(.semibold))
                        .foregroundStyle(look.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("tourSkip")
                Spacer()
                Button { advance(tour) } label: {
                    Text(number == tour.steps.count ? "Done" : "Next")
                        .font(look.font.subhead.weight(.semibold))
                        .padding(.horizontal, 20)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(look.action, in: Capsule())
                        .foregroundStyle(look.onAction)
                        .contentShape(Capsule())
                }
                .accessibilityIdentifier("tourNext")
            }
        }
        .padding(16)
        .background(look.surface, in: RoundedRectangle(cornerRadius: look.radius.panel))
        .overlay(RoundedRectangle(cornerRadius: look.radius.panel).stroke(look.hairline))
        .padding(.horizontal, look.space.margin)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { captionHeight = $0 }
        .offset(y: target.map { below ? min($0.maxY + 14, size.height - captionHeight - 24)
                                      : max($0.minY - 14 - captionHeight, 60) }
                   ?? (size.height - captionHeight) / 2)
    }
}
