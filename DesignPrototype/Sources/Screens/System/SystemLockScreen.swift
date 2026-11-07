import SwiftUI

// PROTOTYPE — the Lock Screen and Dynamic Island stages (Z01) and the rest-complete
// notifications (Z03). The clock, wallpaper, notification platter and island shape are system
// chrome and identical in every look; the app's Live Activity and icon carry the look.

enum SystemScrollAnchor: Hashable {
    case page2, page3, end
}

/// A section label between system stages, in the look's section type.
struct SystemSectionLabel: View {
    var title: String
    @Environment(\.look) private var look

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(look.font.sectionTitle)
            .foregroundStyle(look.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, look.space.margin)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Lock Screen

struct SystemLockScreen<Content: View>: View {
    var now: Date
    /// The stage fills this height (Z03: the rest of the sheet).
    var minHeight: CGFloat = 580
    @ViewBuilder var content: Content

    var body: some View {
        SystemMinHeightLayout(minHeight: max(580, minHeight)) {
            VStack(spacing: 0) {
                clock
                content
                    .padding(.top, 30)
                Spacer(minLength: 32)
                quickActions
            }
            .frame(maxWidth: .infinity)
        }
        .background { SystemWallpaper() }
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
    }

    private var clock: some View {
        VStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 17, weight: .semibold))
                .padding(.bottom, 6)
            Text(SystemFormat.lockDate(now))
                .font(.system(size: 21, weight: .semibold))
            Text(SystemFormat.lockTime(now))
                .font(.system(size: 104, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.top, -10)
        }
        .foregroundStyle(.white.opacity(0.94))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        .padding(.top, 26)
        .accessibilityElement(children: .combine)
    }

    private var quickActions: some View {
        HStack {
            quickAction("flashlight.off.fill")
            Spacer()
            quickAction("camera.fill")
        }
        .padding(.horizontal, 46)
        .padding(.bottom, 30)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    private func quickAction(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .glassEffect(.regular, in: Circle())
    }
}

// MARK: - Notification banner (system platter; the icon is the app's)

struct SystemNotificationBanner: View {
    var lookID: LookStyle
    var title: String
    var message: String
    var onOpen: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Banners drop in from above and settle; Reduce Motion: a fade.
    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity
            : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.94, anchor: .top)),
                          removal: .opacity)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: 11) {
                SystemAppIcon(lookID: lookID, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text("now")
                            .font(.system(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    Text(message)
                        .font(.system(.subheadline))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .environment(\.colorScheme, .dark) // the Lock Screen's platters are dark over this wallpaper
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the workout")
    }
}

// MARK: - Z01 page: Lock Screen, then the Dynamic Island

struct SystemLiveActivityPage: View {
    var model: SystemActivityModel
    var actions: SystemActivityActions
    var now: Date
    /// When rest runs out while this page is open, its notification lands under the activity.
    var banner: SystemRestResult? = nil
    /// The visible height under the sheet's header: the island section fills exactly one screen,
    /// so its page starts on a section edge.
    var viewport: CGFloat = 700
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            SystemLockScreen(now: now) {
                VStack(spacing: 10) {
                    SystemLiveActivityCard(model: model, actions: actions)
                    if let banner {
                        SystemNotificationBanner(lookID: look.id, title: banner.notificationTitle,
                                                 message: banner.notificationBody, onOpen: actions.open)
                            .transition(SystemNotificationBanner.transition(reduceMotion: reduceMotion))
                    }
                }
                .padding(.horizontal, 16)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.46, dampingFraction: 0.78),
                           value: banner)
            }
            SystemMinHeightLayout(minHeight: viewport) {
                VStack(spacing: 0) {
                    SystemSectionLabel("Dynamic Island")
                        .padding(.top, look.space.section)
                    SystemIslandBoard(model: model, actions: actions)
                        .padding(.top, look.space.header)
                        .frame(maxHeight: .infinity)
                }
            }
            .id(SystemScrollAnchor.page2)
        }
    }
}

/// The island's three presentations as specimens on one panel of wallpaper (the top of the
/// screen, where the island lives). The panel takes the height the screen leaves, and the gaps
/// between the specimens share it.
struct SystemIslandBoard: View {
    var model: SystemActivityModel
    var actions: SystemActivityActions
    @Environment(\.look) private var look

    var body: some View {
        VStack(spacing: 0) {
            specimen("Compact") { SystemIslandCompact(model: model) }
            Spacer(minLength: 26)
            specimen("Minimal") { SystemIslandMinimal(model: model) }
            Spacer(minLength: 26)
            specimen("Expanded") { SystemIslandExpanded(model: model, actions: actions) }
                .id(SystemScrollAnchor.page3)
            Color.clear.frame(height: 20)
        }
        .padding(.top, 11)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { SystemWallpaper() }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 40, bottomLeadingRadius: 28,
                                          bottomTrailingRadius: 28, topTrailingRadius: 40, style: .continuous))
    }

    private func specimen<Content: View>(_ caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content()
            Text(caption)
                .font(look.font.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Z03 page: rest complete on the Lock Screen

struct SystemNotificationPage: View {
    var result: SystemRestResult
    var model: SystemActivityModel
    var actions: SystemActivityActions
    var now: Date
    var viewport: CGFloat = 700
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SystemLockScreen(now: now, minHeight: viewport - 16) {
            VStack(spacing: 10) {
                SystemLiveActivityCard(model: model, actions: actions)
                SystemNotificationBanner(lookID: look.id, title: result.notificationTitle, message: result.notificationBody,
                                         onOpen: actions.open)
                    .id(result)
                    .transition(SystemNotificationBanner.transition(reduceMotion: reduceMotion))
            }
            .padding(.horizontal, 16)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.46, dampingFraction: 0.78), value: result)
        }
    }
}
