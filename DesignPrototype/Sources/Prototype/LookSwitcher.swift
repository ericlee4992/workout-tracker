import SwiftUI
import UIKit

// PROTOTYPE CHROME — not part of any design. A floating pill that stays above every sheet and
// cover (it lives in its own window): ◀ look ▶ cycles the looks, the sun / moon flips the
// ★ final look between Light and Dark (its Appearance setting), the grid opens the Screens
// index. Drag it anywhere; the chevron shrinks it to a small dot. The pill itself is always
// dark glass, so it stays legible over both finishes.

/// A window that only takes touches on the pill (or while the Screens index / gallery is up).
/// SwiftUI answers hit tests at its hosting view, so the pill reports its frame instead.
final class PassthroughWindow: UIWindow {
    var interactiveRect: CGRect = .zero

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        if rootViewController?.presentedViewController != nil { return hit }
        // "Now" covers the app with a still capture: nothing underneath takes touches.
        if Proposal.shared.showNow { return hit }
        return interactiveRect.insetBy(dx: -6, dy: -6).contains(point) ? hit : nil
    }
}

@MainActor
enum SwitcherOverlay {
    static var window: PassthroughWindow?

    static func install(store: Store, router: Router, lookModel: LookModel) {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                install(store: store, router: router, lookModel: lookModel)
            }
            return
        }
        let overlay = PassthroughWindow(windowScene: scene)
        overlay.windowLevel = .alert + 1
        let host = UIHostingController(rootView:
            LookSwitcherOverlay()
                .environment(store)
                .environment(router)
                .environment(lookModel))
        host.view.backgroundColor = .clear
        overlay.rootViewController = host
        overlay.isHidden = false
        window = overlay
    }
}

struct LookSwitcherOverlay: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(LookModel.self) private var lookModel
    /// The overlay window is not forced into a scheme, so this is the device's own.
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage("prototype.switcher.collapsed") private var collapsed = false
    @AppStorage("prototype.switcher.x") private var savedX: Double = 0
    @AppStorage("prototype.switcher.y.2026-11") private var savedY: Double = -1
    @State private var drag: CGSize = .zero
    @State private var showIndex = false
    @State private var showGallery = false

    @State private var proposal = Proposal.shared

    var body: some View {
        ZStack {
            NowCaptureLayer(dark: (lookModel.appearance.colorScheme ?? systemScheme) == .dark,
                            large: router.dynamicTypeOverride != nil)
                .animation(.easeInOut(duration: 0.2), value: proposal.showNow)
            pillLayer
        }
    }

    private var pillLayer: some View {
        GeometryReader { geo in
            pill
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                    SwitcherOverlay.window?.interactiveRect = rect
                }
                .offset(x: savedX + drag.width, y: effectiveY(geo) + drag.height)
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { drag = $0.translation }
                        .onEnded { value in
                            savedX = clamp(savedX + value.translation.width, geo.size.width / 2 - 40)
                            savedY = min(max(effectiveY(geo) + value.translation.height, 0), geo.size.height - 40)
                            drag = .zero
                        }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 2)
        }
        .sheet(isPresented: $showIndex) {
            ScreenIndex(showGallery: $showGallery)
                .environment(store)
                .environment(router)
                .environment(lookModel)
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryHost(model: lookModel)
        }
    }

    private func clamp(_ x: Double, _ limit: Double) -> Double { min(max(x, -limit), limit) }

    /// First launch: just above the bottom bars (clear of every top bar); then wherever it was dragged.
    private func effectiveY(_ geo: GeometryProxy) -> Double { savedY < 0 ? geo.size.height - 168 : savedY }

    @ViewBuilder private var pill: some View {
        if collapsed {
            Button {
                withAnimation(.snappy) { collapsed = false }
            } label: {
                Text(lookModel.id.shortLabel)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            // A dark scrim under the material keeps the pill legible over the light finish too.
            .background { Circle().fill(.black.opacity(0.42)).background(.ultraThinMaterial, in: Circle()) }
            .overlay(Circle().strokeBorder(.white.opacity(0.25)))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            .environment(\.colorScheme, .dark)
            .accessibilityLabel("Show look switcher")
        } else {
            HStack(spacing: 2) {
                nowNewToggle
                if proposal.currentKey == "live" || proposal.currentKey == "cardio" {
                    chromeButton(proposal.finishAtBottom ? "arrow.down.to.line" : "arrow.up.to.line",
                                 label: proposal.finishAtBottom ? "Finish at the bottom" : "Finish at the top") {
                        withAnimation(.snappy) { proposal.finishAtBottom.toggle() }
                    }
                    .contentTransition(.symbolEffect(.replace))
                }
                accentButton
                chromeButton(router.dynamicTypeOverride == nil ? "textformat.size.smaller" : "textformat.size.larger",
                             label: router.dynamicTypeOverride == nil ? "Large text" : "Default text") {
                    router.dynamicTypeOverride = router.dynamicTypeOverride == nil ? .accessibility1 : nil
                }
                if lookModel.id.followsAppearance {
                    let dark = (lookModel.appearance.colorScheme ?? systemScheme) == .dark
                    chromeButton(dark ? "sun.max.fill" : "moon.fill", label: dark ? "Light appearance" : "Dark appearance") {
                        withAnimation(.easeInOut(duration: 0.25)) { lookModel.toggleLightDark(system: systemScheme) }
                    }
                    .contentTransition(.symbolEffect(.replace))
                }
                Divider().frame(height: 18).overlay(.white.opacity(0.3))
                chromeButton("square.grid.2x2", label: "Screens") { showIndex = true }
                chromeButton("chevron.up", label: "Hide switcher") {
                    withAnimation(.snappy) { collapsed = true }
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 36)
            .background { Capsule().fill(.black.opacity(0.42)).background(.ultraThinMaterial, in: Capsule()) }
            .overlay(Capsule().strokeBorder(.white.opacity(0.22)))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .environment(\.colorScheme, .dark)
        }
    }

    /// Cycles the proposal's accent: Mono → Sand → Violet (today's).
    private var accentButton: some View {
        let accent = lookModel.accent
        let swatch = accent.colors(dark: true)?.action ?? Color(hex: 0xB25CFF)
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { lookModel.accent = accent.next }
        } label: {
            HStack(spacing: 4) {
                Circle().fill(swatch).frame(width: 10, height: 10)
                    .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
                Text(accent.label)
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize()
            }
            .padding(.horizontal, 6)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accent \(accent.label.lowercased()), change")
    }

    /// NOW (the shipped app's capture) | NEW (the proposal, live).
    private var nowNewToggle: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { isNew in
                let on = proposal.showNow != isNew
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { proposal.showNow = !isNew }
                } label: {
                    Text(isNew ? "NEW" : "NOW")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(on ? Color.black : Color.white.opacity(0.75))
                        .frame(width: 44, height: 26)
                        .background { if on { Capsule().fill(isNew ? Color.white : Color.yellow) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isNew ? "Show the proposal" : "Show today's app")
            }
        }
        .padding(.leading, 4)
    }

    private func chromeButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ delta: Int) {
        let all = LookID.allCases
        let i = all.firstIndex(of: lookModel.id) ?? 0
        let next = all[(i + delta + all.count) % all.count]
        withAnimation(.easeInOut(duration: 0.25)) { lookModel.id = next }
    }
}

/// The component gallery with a close button (opened from the Screens index).
private struct GalleryHost: View {
    @Bindable var model: LookModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ComponentGallery(model: model, page: 0)
            .overlay(alignment: .bottomTrailing) {
                Button("Close") { dismiss() }
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(20)
            }
    }
}
